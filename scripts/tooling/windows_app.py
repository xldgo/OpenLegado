"""Windows Flutter 应用编排；应用打包变化不影响 Rust DLL 指纹。"""

import os
from pathlib import Path
import shutil
import sys

from .common import ToolError, run_command, sha256_file
from .toolchains import flutter_command
from .windows import build_windows_ffi, require_windows, verify_pe, verify_windows_ffi


def bundle_directory(root: Path, profile: str) -> Path:
    destination = root / "flutter_legado" / "build" / "windows" / "x64" / "runner" / profile.capitalize()
    if not destination.resolve().is_relative_to(root.resolve()):
        raise ToolError("Windows 应用输出目录越出仓库，拒绝覆盖。")
    return destination


def copy_bundle_dll(source: Path, destination: Path):
    verify_pe(source)
    try:
        shutil.copyfile(source, destination / source.name)
    except PermissionError as exc:
        raise ToolError("应用目录 DLL 被占用；请手动关闭应用后重试。") from exc
    if sha256_file(source) != sha256_file(destination / source.name):
        raise ToolError("应用目录 DLL 与本次已校验源库摘要不同。")


def build_windows_app(root: Path, profile: str, cargo_target_dir: Path | None = None,
                      quickjs=True, clean=False, run=False, *, build_name=None,
                      build_number=None, dart_defines=()) -> Path:
    require_windows(profile, quickjs)
    flutter, env = flutter_command({**os.environ, "PYTHON": sys.executable})
    app = root / "flutter_legado"
    if clean:
        run_command([*flutter, "clean"], app, env)
    source = build_windows_ffi(root, profile, cargo_target_dir, quickjs, clean)
    env["LEGADO_RUST_FFI_DIR"] = str(source.parent.parent)
    destination = bundle_directory(root, profile)
    # 已有目录先同步，锁定 DLL 时先报错；新目录交由 Flutter 生成。
    if destination.is_dir():
        copy_bundle_dll(source, destination)
    executable = destination / "flutter_legado.exe"
    try:
        executable.unlink(missing_ok=True)
    except PermissionError as exc:
        raise ToolError("Windows 应用被占用；请手动关闭应用后重试。") from exc
    if run:
        # flutter run 自身构建应用并执行 CMake INSTALL，保留热重载，不先重复 build。
        command = [*flutter, "run", "-d", "windows", f"--{profile}"]
    else:
        command = [*flutter, "build", "windows", f"--{profile}"]
    if build_name is not None:
        command += ["--build-name", build_name]
    if build_number is not None:
        command += ["--build-number", str(build_number)]
    command += [f"--dart-define={value}" for value in dart_defines]
    run_command(command, app, env)
    if not executable.is_file() or not executable.stat().st_size:
        raise ToolError(f"Flutter 未产生 Windows 应用：{executable}")
    verify_windows_ffi(root, profile, source.parent.parent, quickjs)
    copy_bundle_dll(source, destination)
    return executable
