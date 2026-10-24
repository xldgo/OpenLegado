"""MuMu快捷安装：探测设备，委托现有构建入口，保存日志并检查启动。"""

import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from .android_app import PACKAGE, find_adb
from .common import ToolError, run_command
from .ffi_metadata import verify_android


def _mumu_install_locations(env: dict):
    """通过Windows卸载信息查找安装目录，不固定盘符或MuMu版本。"""
    if sys.platform != "win32":
        yield from _wsl_install_locations(env)
        return
    import winreg

    uninstall = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    for hive in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
        for view in (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
            try:
                with winreg.OpenKey(hive, uninstall, 0, winreg.KEY_READ | view) as parent:
                    for index in range(winreg.QueryInfoKey(parent)[0]):
                        try:
                            with winreg.OpenKey(parent, winreg.EnumKey(parent, index)) as entry:
                                name = winreg.QueryValueEx(entry, "DisplayName")[0]
                                if "mumu" in str(name).lower():
                                    yield winreg.QueryValueEx(entry, "InstallLocation")[0]
                        except OSError:
                            continue
            except OSError:
                continue


def _wsl_powershell(env: dict) -> Path | None:
    """appendWindowsPath=false时，从挂载的系统目录定位互操作入口。"""
    if not env.get("WSL_INTEROP"):
        return None
    found = shutil.which("powershell.exe", path=env.get("PATH", ""))
    if found:
        return Path(found)
    return next((path for path in Path("/mnt").glob(
        "[a-z]/Windows/System32/WindowsPowerShell/v1.0/powershell.exe") if path.is_file()), None)


def _wsl_install_locations(env: dict):
    powershell = _wsl_powershell(env)
    if powershell is None:
        return
    # 仅查询Windows安装信息；UTF-8输出保留中文安装路径，不修改Windows/WSL配置。
    query = r"""[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
 Where-Object { $_.DisplayName -match 'MuMu' } |
 ForEach-Object { $_.InstallLocation } | Where-Object { $_ } | Select-Object -Unique) |
 ConvertTo-Json -Compress"""
    root = Path.cwd()
    output = _connection_command([powershell, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", query], root, env)
    if not output.strip():
        return
    try:
        locations = json.loads(output.lstrip("\ufeff"))
    except ValueError as exc:
        raise ToolError("Windows的MuMu安装信息不是有效JSON。") from exc
    if isinstance(locations, str):
        locations = [locations]
    if not isinstance(locations, list) or any(not isinstance(item, str) for item in locations):
        raise ToolError("Windows的MuMu安装信息格式不正确。")
    for location in locations:
        if location.strip():
            yield _connection_command(["wslpath", "-u", location], root, env).strip()


def find_mumu_manager(env: dict) -> Path | None:
    """优先使用PATH，其次使用本机已登记的安装位置。"""
    found = shutil.which("MuMuManager.exe", path=env.get("PATH", ""))
    if found:
        return Path(found)
    for location in _mumu_install_locations(env):
        if isinstance(location, str) and location.strip():
            candidate = Path(location) / "nx_main" / "MuMuManager.exe"
            if candidate.is_file():
                return candidate
    return None


def _connection_command(args, root: Path, env: dict) -> str:
    """实例查询和连接最多等待10秒，不干预共享ADB服务。"""
    command = [str(arg) for arg in args]
    try:
        result = subprocess.run(command, cwd=root, env=env, shell=False,
                                capture_output=True, text=True, encoding="utf-8", errors="replace",
                                timeout=10)
    except subprocess.TimeoutExpired as exc:
        raise ToolError(f"{' '.join(command)}：等待超过10秒。") from exc
    except OSError as exc:
        raise ToolError(f"无法执行 {command[0]}：{exc}") from exc
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise ToolError(f"{' '.join(command)} 执行失败（{result.returncode}）：{detail}")
    return result.stdout


def running_mumu_endpoints(root: Path, manager: Path, env: dict) -> list[str]:
    """只读取已启动实例的本机ADB端点，不按实例编号推算端口。"""
    output = _connection_command([manager, "info", "-v", "all"], root, env)
    try:
        instances = json.loads(output.lstrip("\ufeff"))
    except ValueError as exc:
        raise ToolError("MuMuManager实例信息不是有效JSON。") from exc
    if not isinstance(instances, dict) or any(not isinstance(item, dict) for item in instances.values()):
        raise ToolError("MuMuManager实例信息格式不正确。")
    endpoints = set()
    for index, item in instances.items():
        if item.get("is_android_started") is not True or item.get("is_process_started") is not True:
            continue
        host, port = item.get("adb_host_ip"), item.get("adb_port")
        try:
            address = ipaddress.ip_address(host) if isinstance(host, str) else None
        except ValueError:
            address = None
        if address is None or not address.is_loopback or type(port) is not int or not 1 <= port <= 65535:
            raise ToolError(f"MuMu实例 {index} 的本机ADB端点无效：{host}:{port}。")
        endpoints.add(f"[{address}]:{port}" if address.version == 6 else f"{address}:{port}")
    return sorted(endpoints)


def _online_devices(root: Path, adb: Path, env: dict) -> list[str]:
    listing = run_command([adb, "devices"], root, env, capture=True)
    return [parts[0] for line in listing.splitlines()
            if len(parts := line.split()) == 2 and parts[1] == "device"]


def _is_mumu(root: Path, adb: Path, env: dict, serial: str) -> bool:
    marker = run_command([adb, "-s", serial, "shell",
                          "if [ -f /system/bin/nemuinit ]; then echo mumu; fi"],
                         root, env, capture=True).strip()
    return marker == "mumu"


def select_mumu_device(root: Path, adb: Path, env: dict, explicit: str | None = None, *, log=None) -> str:
    """自动连接唯一已启动实例；明确指定且在线的目标直接复用。"""
    if explicit is not None and (not explicit.strip() or explicit.startswith("-")):
        raise ToolError("--device 必须为有效设备编号。")
    online = _online_devices(root, adb, env)
    endpoints = []
    if explicit is not None and explicit in online:
        matches = [explicit] if _is_mumu(root, adb, env, explicit) else []
    else:
        manager = find_mumu_manager(env)
        endpoints = running_mumu_endpoints(root, manager, env) if manager else []
        if explicit is not None:
            if explicit not in endpoints:
                raise ToolError(f"指定设备 {explicit} 未在线，且不属于查询到的已启动MuMu实例。")
            matches = [explicit]
        elif endpoints:
            matches = endpoints
        else:
            matches = [serial for serial in online if _is_mumu(root, adb, env, serial)]
    if not matches:
        raise ToolError("未找到在线MuMu，请先启动模拟器；自动连接需要可用的MuMuManager安装信息或PATH。")
    if len(matches) > 1:
        raise ToolError(f"检测到多个MuMu，请使用 --device 指定：{', '.join(matches)}")
    serial = matches[0]
    if serial not in online:
        message = f"自动连接MuMu：{serial}（ADB：{adb}）"
        print(message, flush=True)
        if log is not None:
            log.write(message + "\n")
        response = _connection_command([adb, "connect", serial], root, env).strip()
        print(response, flush=True)
        if log is not None:
            log.write(response + "\n")
        if serial not in _online_devices(root, adb, env):
            raise ToolError(f"MuMu {serial} 连接后仍未在线：{response}。")
        if not _is_mumu(root, adb, env, serial):
            raise ToolError(f"设备 {serial} 未通过MuMu标识检查。")
    elif explicit is None and endpoints and not _is_mumu(root, adb, env, serial):
        raise ToolError(f"设备 {serial} 未通过MuMu标识检查。")
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
            serial = select_mumu_device(root, adb, env, args.device, log=log)
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
