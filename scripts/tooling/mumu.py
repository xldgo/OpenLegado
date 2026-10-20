"""MuMu快捷安装：探测设备，委托现有构建入口，保存日志并检查启动。"""

import os
from pathlib import Path
import re
import subprocess
import sys
import time

from .android_app import PACKAGE, find_adb
from .common import ToolError, run_command
from .ffi_metadata import verify_android


def select_mumu_device(root: Path, adb: Path, env: dict, explicit: str | None = None) -> str:
    """只选择在线MuMu，不依赖端口或可被模拟器伪装的手机型号。"""
    if explicit is not None and (not explicit.strip() or explicit.startswith("-")):
        raise ToolError("--device 必须为有效设备编号。")
    listing = run_command([adb, "devices"], root, env, capture=True)
    online = [parts[0] for line in listing.splitlines()
              if len(parts := line.split()) == 2 and parts[1] == "device"]
    if explicit is not None and explicit not in online:
        raise ToolError(f"指定设备 {explicit} 未在线。")
    matches = []
    for serial in ([explicit] if explicit is not None else online):
        marker = run_command([adb, "-s", serial, "shell",
                              "if [ -f /system/bin/nemuinit ]; then echo mumu; fi"],
                             root, env, capture=True).strip()
        if marker == "mumu":
            matches.append(serial)
    if not matches:
        raise ToolError("未找到在线MuMu，请先启动模拟器并检查 adb devices。")
    if len(matches) > 1:
        raise ToolError(f"检测到多个MuMu，请使用 --device 指定：{', '.join(matches)}")
    serial = matches[0]
    abi = run_command([adb, "-s", serial, "shell", "getprop", "ro.product.cpu.abi"],
                      root, env, capture=True).strip()
    if abi != "x86_64":
        raise ToolError(f"MuMu快捷入口需要x86_64设备，{serial} 实际为 {abi}。")
    return serial


def run_logged_build(command: list[str], root: Path, env: dict, log) -> int:
    """透传子进程输出并写入同一日志，构建失败保留退出码。"""
    with subprocess.Popen(command, cwd=root, env=env, shell=False, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace") as process:
        for line in process.stdout:
            print(line, end="", flush=True)
            log.write(line)
            log.flush()
        return process.wait()


def build_mumu_app(root: Path, args) -> int:
    """固定x86_64分包；已有库校验通过则复用，否则委托原入口重新编译。"""
    env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
    log_path = root / "build" / "mumu" / "build-install.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"本次构建与启动日志：{log_path}", flush=True)
    with log_path.open("w", encoding="utf-8") as log:
        try:
            adb = find_adb(root, env, args.adb)
            serial = select_mumu_device(root, adb, env, args.device)
            log.write(f"设备：{serial}；ABI：x86_64；模式：{args.profile}\n")
            # 子进程不携带--emulator，完整复用普通APK构建、校验、覆盖安装和默认入口启动。
            command = [sys.executable, "-u", str(root / "scripts" / "dev.py"), "build", "android",
                       "--profile", args.profile, "--abis", "x86_64", "--split-per-abi",
                       "--install", "--device", serial, "--adb", str(adb)]
            for flag, value in (("--ndk", args.ndk), ("--cargo-target-dir", args.cargo_target_dir)):
                if value is not None:
                    command.extend((flag, str(value.resolve())))
            reuse = args.skip_rust
            if not reuse:
                try:
                    verify_android(root, args.profile, ("x86_64",), args.cargo_target_dir)
                except ToolError as exc:
                    decision = f"现有Rust库无法复用，将重新编译：{exc}"
                else:
                    reuse = True
                    decision = "现有Rust库校验通过，自动复用。"
                print(decision, flush=True)
                log.write(decision + "\n")
            if reuse:
                command.append("--skip-rust")
            if args.clean:
                command.append("--clean")
            log.flush()
            code = run_logged_build(command, root, env, log)
            if code:
                return code
            # am start -W由原入口检查；短暂等待后检查进程及本进程近期崩溃日志。
            time.sleep(2)
            pid = run_command([adb, "-s", serial, "shell", "pidof", PACKAGE],
                              root, env, capture=True).strip()
            if not re.fullmatch(r"[0-9]+", pid):
                raise ToolError("应用启动后没有有效进程。")
            startup = run_command([adb, "-s", serial, "logcat", "-d", "-t", "200", f"--pid={pid}"],
                                  root, env, capture=True)
            log.write(f"\n启动进程：{pid}\n{startup}")
            if "FATAL EXCEPTION:" in startup or "Unhandled Exception:" in startup:
                raise ToolError("应用启动日志存在未处理异常，请查看本次日志。")
            message = f"MuMu安装及启动检查通过：{serial}；PID {pid}"
            print(message)
            log.write(f"\n{message}\n")
            return 0
        except (ToolError, OSError) as exc:
            log.write(f"\n失败：{exc}\n")
            raise
