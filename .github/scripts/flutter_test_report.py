"""从Flutter JSON事件生成慢测试报告；只统计，不改变测试结果。"""

import argparse
import json
import os
from pathlib import Path
import sys


def summarize(lines):
    suites, tests, cases = {}, {}, []
    elapsed = 0
    finished = False
    success = None
    for line in lines:
        if not line.strip():
            continue
        event = json.loads(line)
        time = event["time"]
        elapsed = max(elapsed, time)
        kind = event["type"]
        if kind == "suite":
            suite = event["suite"]
            suites[suite["id"]] = {"path": suite["path"], "load_ms": 0, "execution_ms": 0,
                                    "tests": 0, "failed": 0, "skipped": 0,
                                    "first_ms": time, "last_ms": time}
        elif kind == "testStart":
            tests[event["test"]["id"]] = {**event["test"], "start_ms": time}
        elif kind == "testDone":
            test = tests.pop(event["testID"])
            suite = suites[test["suiteID"]]
            duration = time - test["start_ms"]
            suite["last_ms"] = max(suite["last_ms"], time)
            if event.get("hidden", False) and test["name"].startswith("loading "):
                suite["load_ms"] += duration
                suite["failed"] += event["result"] != "success"
                continue
            suite["execution_ms"] += duration
            skipped = event.get("skipped", False)
            hidden = event.get("hidden", False)
            suite["tests"] += not hidden
            suite["skipped"] += skipped and not hidden
            suite["failed"] += event["result"] != "success" and not skipped
            if not hidden:
                cases.append({"path": suite["path"], "name": test["name"],
                              "duration_ms": duration, "result": event["result"], "skipped": skipped})
        elif kind == "done":
            finished = True
            success = event["success"]
    return {"elapsed_ms": elapsed, "complete": finished and not tests, "success": success,
            "unfinished": [{"path": suites[test["suiteID"]]["path"], "name": test["name"]}
                           for test in tests.values()],
            "suites": sorted(suites.values(), key=lambda s: s["execution_ms"], reverse=True),
            "cases": sorted(cases, key=lambda c: c["duration_ms"], reverse=True)}


def label(value):
    return str(value).replace("\\", "/").replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def short_path(path):
    return label(path).split("/flutter_legado/")[-1]


def markdown(report, group, limit=20):
    lines = [f"## Flutter测试耗时：{label(group)}", "",
             f"事件记录跨度：{report['elapsed_ms'] / 1000:.2f}s；"
             f"报告完整：{'是' if report['complete'] else '否'}；"
             f"测试结果：{report['success']}。", "",
             "装载含编译、调度等待和进程启动；执行含测试钩子。并发文件耗时不可相加当作整轮耗时，",
             "下表用于定位慢项，不代表设备profile性能。", ""]
    for heading, key in (("装载最慢文件", "load_ms"), ("执行最慢文件", "execution_ms")):
        lines.extend([f"### {heading}", "", "| 文件 | 装载(s) | 执行累计(s) | 用例/失败/跳过 |",
                      "|---|---:|---:|---:|"])
        for suite in sorted(report["suites"], key=lambda s: s[key], reverse=True)[:limit]:
            lines.append(f"| {short_path(suite['path'])} | {suite['load_ms']/1000:.2f} | "
                         f"{suite['execution_ms']/1000:.2f} | "
                         f"{suite['tests']}/{suite['failed']}/{suite['skipped']} |")
        lines.append("")
    lines.extend(["### 执行最慢用例", "", "| 文件 / 用例 | 耗时(s) | 结果 |", "|---|---:|---|"])
    for case in report["cases"][:limit]:
        result = "跳过" if case["skipped"] else case["result"]
        lines.append(f"| {short_path(case['path'])} / {label(case['name'])} | "
                     f"{case['duration_ms']/1000:.2f} | {result} |")
    if not report["complete"]:
        lines.extend(["", "报告未完成（测试可能被中断）；已记录的耗时仅为部分结果。"])
        lines.extend(f"- 未完成：{short_path(t['path'])} / {label(t['name'])}"
                     for t in report["unfinished"])
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("events", type=Path)
    parser.add_argument("--group", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        with args.events.open(encoding="utf-8-sig") as stream:
            report = summarize(stream)
        args.output.mkdir(parents=True, exist_ok=True)
        rendered = markdown(report, args.group)
        (args.output / "timings.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        (args.output / "summary.md").write_text(rendered, encoding="utf-8")
        if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
            with Path(summary).open("a", encoding="utf-8") as stream:
                stream.write(rendered)
        print(rendered)
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"测试耗时报告生成失败：{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
