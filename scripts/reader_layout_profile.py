"""采集独立阅读排版 Profile 包的日志并核对采样完整性，不触发构建或 CI。"""

import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time

PREFIX = "READER_LAYOUT_PROFILE "
PACKAGE = "io.legado.layout_benchmark"


class RecordDecoder:
    """有序分包还原；缺包和进程中途重启立即拒绝，不拼接伪完整结果。"""

    def __init__(self):
        self.next_record = 0
        self.chunks = []
        self.total = 0

    def feed(self, line):
        value = json.loads(line.split(PREFIX, 1)[1])
        if "kind" in value:
            return value
        if value["record"] != self.next_record or value["chunk"] != len(self.chunks):
            raise ValueError("性能日志传输包缺失或乱序")
        if not self.chunks:
            self.total = value["total"]
        if value["total"] != self.total or self.total < 1:
            raise ValueError("性能日志传输包总数不一致")
        self.chunks.append(value["payload"])
        if len(self.chunks) < self.total:
            return None
        encoded = "".join(self.chunks)
        self.chunks = []
        self.next_record += 1
        return json.loads(base64.b64decode(encoded, validate=True).decode("utf-8"))


def summarize(lines):
    records = []
    decoder = RecordDecoder()
    for line in lines:
        if PREFIX in line:
            record = decoder.feed(line)
            if record is not None:
                records.append(record)
    if decoder.chunks:
        raise ValueError("最后一条性能日志传输包不完整")
    if not records or records[0].get("kind") != "environment":
        raise ValueError("缺少采样环境记录")
    environment = records[0]
    if environment.get("mode") != "profile" or environment.get("schema") != 1:
        raise ValueError("只接受 schema=1 的 profile 记录")
    if records[-1].get("kind") != "complete" or any(r.get("kind") == "error" for r in records):
        raise ValueError("采样未成功完成")
    if any(records[-1].get(key) != environment.get(key) for key in ("label", "revision")):
        raise ValueError("采样起止版本不一致")
    samples = [r for r in records if r["kind"] == "sample"]
    results = {}
    for fixture in (r for r in records if r["kind"] == "fixture"):
        name = fixture["case"]
        if name in results:
            raise ValueError(f"{name} 文本夹具重复")
        chunks = [r for r in records if r["kind"] == "fixtureChunk" and r["case"] == name]
        if [r["index"] for r in chunks] != list(range(fixture["chunks"])):
            raise ValueError(f"{name} 文本夹具被截断或乱序")
        source = base64.b64decode("".join(r["base64"] for r in chunks), validate=True)
        if len(source.decode("utf-8").encode("utf-16-le")) // 2 != fixture["utf16"]:
            raise ValueError(f"{name} 原文 UTF-16 长度不匹配")
        rounds = [r for r in samples if r["case"] == name]
        if [r["round"] for r in rounds] != list(range(1, environment["rounds"] + 1)):
            raise ValueError(f"{name} 采样轮次缺失或重复")
        for row in rounds:
            if row["utf16"] != fixture["utf16"]:
                raise ValueError(f"{name} 采样正文长度不匹配")
            if not (0 <= row["firstPageReadyUs"] <= row["firstPageFrameSubmittedUs"] <= row["chapterWallUs"]):
                raise ValueError(f"{name} 首屏和整章计时不合法")
            frames = [r for r in records if r["kind"] == "frame" and r["case"] == name and r["round"] == row["round"]]
            if len(frames) != row["frames"] or not frames:
                raise ValueError(f"{name} 第 {row['round']} 轮帧记录缺失")
        metrics = {}
        for key in rounds[0]:
            if key in {"round", "utf16", "kind", "case", "ffi"}:
                continue
            values = sorted(r[key] for r in rounds)
            if all(isinstance(v, (int, float)) for v in values):
                metrics[key] = {"p50": values[math.ceil(len(values) * .5) - 1],
                                "p95": values[math.ceil(len(values) * .95) - 1]}
        results[name] = {"sourceSha256": hashlib.sha256(source).hexdigest(),
                         "utf16": fixture["utf16"], "metrics": metrics, "samples": rounds}
    if not results or set(r["case"] for r in samples) != set(results) or set(environment["cases"]) != set(results):
        raise ValueError("文本夹具与采样场景不匹配")
    return {"environment": environment, "cases": results,
            "frames": [r for r in records if r["kind"] == "frame"]}


def collect(adb, device, log, timeout):
    def run(*args):
        return subprocess.run([adb, "-s", device, *args], check=True, capture_output=True,
                              text=True, encoding="utf-8").stdout.strip()

    run("shell", "am", "force-stop", PACKAGE)
    messages = queue.Queue()
    process = subprocess.Popen([adb, "-s", device, "logcat", "-T", "1", "-v", "raw", "-s", "flutter:I"],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding="utf-8", errors="replace")

    def read_output():
        for line in process.stdout:
            messages.put(line)
        messages.put(None)

    threading.Thread(target=read_output, daemon=True).start()
    started = False
    capturing = False
    decoder = RecordDecoder()
    lines = []
    try:
        launch = run("shell", "am", "start", "-W", "-n", f"{PACKAGE}/io.legado.flutter.MainActivity")
        if "Status: ok" not in launch:
            raise ValueError(f"基准包启动失败：{launch}")
        deadline = time.monotonic() + timeout
        with log.open("w", encoding="utf-8") as output:
            while time.monotonic() < deadline:
                try:
                    line = messages.get(timeout=1)
                except queue.Empty:
                    continue
                if line is None:
                    raise ValueError("ADB 日志流提前结束")
                if PREFIX not in line:
                    continue
                if not capturing:
                    packet = json.loads(line.split(PREFIX, 1)[1])
                    if packet.get("record") != 0 or packet.get("chunk") != 0:
                        continue
                    capturing = True
                output.write(line)
                output.flush()
                lines.append(line)
                record = decoder.feed(line)
                if record is None:
                    continue
                if record["kind"] == "environment":
                    if started:
                        raise ValueError("采样进程在测试中重启")
                    started = True
                if not started:
                    continue
                if record["kind"] == "sample":
                    print(f"{record['case']} / {record['round']}：整章 {record['chapterWallUs'] / 1000:.2f} ms", flush=True)
                if record["kind"] == "error":
                    raise ValueError(f"设备采样失败：{record['error']}")
                if record["kind"] == "complete":
                    return summarize(lines)
        raise ValueError(f"采样在 {timeout} 秒内未完成，原始日志：{log}")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdout.close()


def compare(baseline, current):
    """只有环境和输入一致才计算前后差值，页数差异保留供规则审查。"""
    keys = ("mode", "os", "processors", "devicePixelRatio", "displayRefreshRate",
            "width", "height", "firstHeight", "fontSize", "lineHeight",
            "paragraphSpacing", "indent", "textScale", "warmups", "rounds", "cases")
    if any(baseline["environment"].get(key) != current["environment"].get(key) for key in keys):
        raise ValueError("前后采样环境或排版配置不同，不能比较")
    if baseline["cases"].keys() != current["cases"].keys():
        raise ValueError("前后采样场景不同，不能比较")
    result = {}
    for name, case in current["cases"].items():
        original = baseline["cases"][name]
        if (case["sourceSha256"], case["utf16"]) != (original["sourceSha256"], original["utf16"]):
            raise ValueError(f"{name} 前后正文不同，不能比较")
        metrics = {}
        for key, values in case["metrics"].items():
            if key not in original["metrics"]:
                continue
            before, after = original["metrics"][key]["p50"], values["p50"]
            metrics[key] = {"beforeP50": before, "afterP50": after,
                            "delta": after - before,
                            "deltaPercent": (after / before - 1) * 100 if before else None}
        result[name] = metrics
    return {"baselineRevision": baseline["environment"]["revision"], "cases": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True, help="保存原始采样日志；与 --device 一起使用时新建")
    parser.add_argument("--output", type=Path, required=True, help="结构化汇总 JSON")
    parser.add_argument("--device", help="明确指定 ADB 设备；省略时只读取已有日志")
    parser.add_argument("--adb", default=shutil.which("adb"), help="ADB 可执行文件")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--baseline", type=Path, help="前一次完整采样 JSON；先校验环境与文本再比较")
    args = parser.parse_args()
    try:
        if args.baseline and args.baseline.resolve() in {args.output.resolve(), args.log.resolve()}:
            raise ValueError("输出路径不能覆盖迁移前基线")
        baseline = json.loads(args.baseline.read_text(encoding="utf-8")) if args.baseline else None
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.device:
            if not args.adb:
                raise ValueError("请通过 --adb 指定 ADB，或将其加入 PATH")
            args.log.parent.mkdir(parents=True, exist_ok=True)
            result = collect(args.adb, args.device, args.log, args.timeout)
        else:
            result = summarize(args.log.read_text(encoding="utf-8").splitlines())
        if baseline is not None:
            result["comparison"] = compare(baseline, result)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"完整 profile 采样已保存：{args.output}")
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"错误：{exc}\n")


if __name__ == "__main__":
    main()
