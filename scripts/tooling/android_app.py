"""Android APK 编排：严格校验原生库，再打包并按需安装。"""

from collections import Counter
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import zipfile

from .android import build_android_ffi
from .common import ToolError, output_directory, run_command, sha256_file
from .ffi_metadata import verify_android
from .policy import load_policy, select_target
from .android_toolchain import discover_ndk
from .toolchains import find_tool, flutter_command, property_value


PACKAGE = "io.legado.flutter_legado"
ACTIVITY = "io.legado.flutter.MainActivity"


def verify_apk_signature(root: Path, apk: Path, expected: str):
    """使用SDK自带apksigner检查最终APK签名与发行证书，不改写包。"""
    wanted = expected.strip().replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", wanted):
        raise ToolError("发行证书SHA-256指纹必须为64位十六进制，可包含冒号分隔。")
    env = os.environ.copy()
    sdk = env.get("ANDROID_SDK_ROOT") or env.get("ANDROID_HOME")
    local = root / "flutter_legado/android/local.properties"
    if not sdk and local.is_file():
        sdk = property_value(local, "sdk.dir")
    if not sdk:
        raise ToolError("找不到Android SDK，请设置ANDROID_SDK_ROOT或android/local.properties。")
    tools = Path(sdk) / "build-tools"
    jars = [(tuple(map(int, directory.name.split("."))), directory / "lib/apksigner.jar")
            for directory in tools.iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", directory.name)
            and (directory / "lib/apksigner.jar").is_file()] if tools.is_dir() else []
    if not jars:
        raise ToolError("Android SDK缺少Build Tools/apksigner.jar。")
    # 直接执行JAR，避免Windows批处理与Shell参数转义差异。
    output = run_command([find_tool("java", env), "-jar", max(jars)[1], "verify", "--print-certs", apk],
                         root, env, capture=True)
    certificates = re.findall(r"^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F:]+)\s*$",
                              output, re.MULTILINE)
    if len(certificates) != 1 or certificates[0].replace(":", "").lower() != wanted:
        raise ToolError(f"{apk.name}：APK签名证书与预期发行证书不匹配。")


def verify_android_apk(root: Path, apk: Path, profile: str, abis: tuple[str, ...],
                       ndk_path: Path | None = None, cargo_target_dir: Path | None = None,
                       signing_cert_sha256: str | None = None):
    """只读检查 APK；strip 仅作用于临时副本，接受 Gradle 合法去符号。"""
    verify_android(root, profile, abis, cargo_target_dir)
    if not apk.is_file() or apk.stat().st_size == 0:
        raise ToolError(f"APK 不存在或为空：{apk}")
    if signing_cert_sha256 is not None:
        verify_apk_signature(root, apk, signing_cert_sha256)
    env = os.environ.copy()
    policy = load_policy(root)
    ndk = discover_ndk(root, policy, env, ndk_path)
    libraries = root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs"
    expected = {f"lib/{abi}/liblegado_ffi.so": abi for abi in abis}
    try:
        with zipfile.ZipFile(apk) as archive, tempfile.TemporaryDirectory(prefix="legado-apk-") as temporary:
            members = [name for name in archive.namelist()
                       if name.startswith("lib/") and name.endswith("/liblegado_ffi.so")]
            if Counter(members) != Counter(expected.keys()):
                raise ToolError(f"{apk.name}：Rust 库缺失、重复或 ABI 不符合请求 {','.join(abis)}。")
            for member, abi in expected.items():
                packaged = Path(temporary) / f"{abi}-apk.so"
                source = Path(temporary) / f"{abi}-jni.so"
                with archive.open(member) as stream, packaged.open("wb") as output:
                    shutil.copyfileobj(stream, output)
                shutil.copyfile(libraries / abi / "liblegado_ffi.so", source)
                copies = [packaged, source]
                if cargo_target_dir is not None:
                    triple = select_target(policy, abi, profile)["targetTriple"]
                    cargo_copy = Path(temporary) / f"{abi}-cargo.so"
                    shutil.copyfile(cargo_target_dir / triple / profile / "liblegado_ffi.so", cargo_copy)
                    copies.append(cargo_copy)
                for library in copies:
                    if library.stat().st_size == 0:
                        raise ToolError(f"{abi}：APK、jniLibs 或 Cargo 库为空。")
                    run_command([ndk.tool("llvm-strip"), "--strip-unneeded", library], root, env)
                    if library.stat().st_size == 0:
                        raise ToolError(f"{abi}：NDK strip 后库为空。")
                if len({sha256_file(library) for library in copies}) != 1:
                    raise ToolError(f"{abi}：APK、已校验 jniLibs 或 Cargo 库的 strip 正规化摘要不同。")
    except (zipfile.BadZipFile, RuntimeError) as exc:
        raise ToolError(f"无法读取 APK {apk}：{exc}") from exc


def collect_android_apks(root: Path, profile: str, abis: tuple[str, ...], output_dir: Path,
                         ndk_path: Path | None = None, cargo_target_dir: Path | None = None,
                         signing_cert_sha256: str | None = None) -> list[Path]:
    """收集已构建的分 ABI APK；全部校验及临时复制成功后才发布，不构建或安装。"""
    if not abis or len(abis) != len(set(abis)):
        raise ToolError("收集 APK 必须指定非空且不重复的 ABI 列表。")
    policy = load_policy(root)
    for abi in abis:
        select_target(policy, abi, profile)
    source_dir = (root / "flutter_legado" / "build" / "app" / "outputs" / "flutter-apk").resolve()
    destination = output_dir.resolve()
    repository = root.resolve()
    if destination == repository or not destination.is_relative_to(repository):
        raise ToolError("APK 收集目录必须是仓库内的专用子目录。")
    if destination.relative_to(repository).parts[0] in (".git", ".agents", ".codex", "rust", "scripts"):
        raise ToolError("APK 收集目录不能位于 Rust/工具源码或仓库/Agent 配置目录。")
    if source_dir.is_relative_to(destination) or destination.is_relative_to(source_dir):
        raise ToolError("APK 收集目录不能覆盖、包含或嵌套在 Flutter APK 输入目录中。")
    apks = [source_dir / f"app-{abi}-{profile}.apk" for abi in abis]
    names = {apk.name for apk in apks}
    if destination.exists():
        if not destination.is_dir():
            raise ToolError("APK 收集路径已存在且不是目录。")
        if any(path.name not in names or not path.is_file() or path.is_symlink() for path in destination.iterdir()):
            raise ToolError("APK 收集目录存在本次文件集以外的内容，请指定空目录；不会清理无关文件。")
    cargo_dir = output_directory(root, cargo_target_dir)
    digests = []
    for abi, apk in zip(abis, apks):
        if not apk.is_file() or apk.stat().st_size == 0:
            raise ToolError(f"APK 不存在或为空：{apk}")
        before = sha256_file(apk)
        verify_android_apk(root, apk, profile, (abi,), ndk_path, cargo_dir, signing_cert_sha256)
        if sha256_file(apk) != before:
            raise ToolError(f"{apk.name}：APK 在校验期间改变，拒绝收集。")
        digests.append(before)
    destination.parent.mkdir(parents=True, exist_ok=True)
    # 临时目录位于已经核对的仓库子路径；只发布明确请求的文件，不递归清理用户目录。
    with tempfile.TemporaryDirectory(prefix=".tmp_apk_collect_", dir=destination.parent) as temporary:
        staged = [Path(temporary) / apk.name for apk in apks]
        for apk, copy, before in zip(apks, staged, digests):
            shutil.copyfile(apk, copy)
            if sha256_file(copy) != before or sha256_file(apk) != before:
                raise ToolError(f"{apk.name}：APK 在收集期间改变或复制摘要不匹配。")
        # 暂存包完整摘要与已校验原件一致，无需再次解包/strip；发布前再核对全部 native 输入。
        verify_android(root, profile, abis, cargo_dir)
        destination.mkdir(exist_ok=True)
        for copy in staged:
            os.replace(copy, destination / copy.name)
    return [destination / apk.name for apk in apks]


def find_adb(root: Path, env: dict, explicit: Path | None = None) -> Path:
    if explicit is not None:
        adb = explicit.resolve()
        if not adb.is_file():
            raise ToolError(f"指定的 adb 不存在：{adb}")
        return adb
    found = shutil.which("adb", path=env.get("PATH", ""))
    if found:
        return Path(found).resolve()
    sdk = env.get("ANDROID_SDK_ROOT") or env.get("ANDROID_HOME")
    local = root / "flutter_legado" / "android" / "local.properties"
    if not sdk and local.is_file():
        sdk = property_value(local, "sdk.dir")
    if sdk:
        adb = Path(sdk) / "platform-tools" / ("adb.exe" if sys.platform == "win32" else "adb")
        if adb.is_file():
            return adb.resolve()
    raise ToolError("找不到 adb；请配置 PATH/Android SDK，或通过 --adb 指定。")


def install_android_apk(root: Path, apks: list[Path], device: str, env: dict,
                        adb_path: Path | None = None):
    adb = find_adb(root, env, adb_path)
    state = run_command([adb, "-s", device, "get-state"], root, env, capture=True).strip()
    if state != "device":
        raise ToolError(f"设备 {device} 未在线：{state}。")
    if len(apks) == 1:
        apk = apks[0]
    else:
        abi = run_command([adb, "-s", device, "shell", "getprop", "ro.product.cpu.abi"],
                          root, env, capture=True).strip()
        matches = [path for path in apks if path.name.startswith(f"app-{abi}-")]
        if len(matches) != 1:
            raise ToolError(f"设备 ABI {abi} 不在本次 APK 列表中。")
        apk = matches[0]
    result = run_command([adb, "-s", device, "install", "-r", apk], root, env, capture=True)
    if "Success" not in result.splitlines():
        raise ToolError(f"设备 {device} 未确认 APK 安装成功：{result.strip()}。")
    result = run_command([adb, "-s", device, "shell", "am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}"],
                         root, env, capture=True)
    if "Status: ok" not in [line.strip() for line in result.splitlines()]:
        raise ToolError(f"设备 {device} 未确认应用启动成功：{result.strip()}。")
    print(f"已安装并启动：{device}；{apk}")


def build_android_app(root: Path, profile: str, abis: tuple[str, ...],
                      ndk_path: Path | None = None, cargo_target_dir: Path | None = None,
                      skip_rust=False, clean=False, split_per_abi=False,
                      install=False, device: str | None = None, adb_path: Path | None = None) -> list[Path]:
    if install and (not device or not device.strip() or device.startswith("-")):
        raise ToolError("--install 必须同时明确指定 --device，先用 adb devices 确认设备。")
    if not install and (device is not None or adb_path is not None):
        raise ToolError("--device/--adb 只能与 --install 同时使用。")
    if not abis or len(abis) != len(set(abis)):
        raise ToolError("必须指定非空且不重复的 ABI 列表。")
    policy = load_policy(root)
    platforms = [select_target(policy, abi, profile)["flutterPlatform"] for abi in abis]
    env = {**os.environ, "PYTHON": sys.executable}
    if env.get("LEGADO_SKIP_RUST_BUILD") == "1":
        raise ToolError("真实 APK 编排不接受 LEGADO_SKIP_RUST_BUILD=1；已有库请使用 --skip-rust 严格校验。")
    discover_ndk(root, policy, env, ndk_path)
    flutter, env = flutter_command(env)
    app = root / "flutter_legado"
    if clean:
        run_command([*flutter, "clean"], app, env)
    if skip_rust:
        verify_android(root, profile, abis, cargo_target_dir)
    else:
        cargo_target_dir = build_android_ffi(root, profile, abis, ndk_path, cargo_target_dir)
    output = app / "build" / "app" / "outputs" / "flutter-apk"
    apks = ([output / f"app-{abi}-{profile}.apk" for abi in abis] if split_per_abi
            else [output / f"app-{profile}.apk"])
    # 只移除本次命令明确请求的旧输出，防止成功退出却未生成新 APK 时复用残留。
    for apk in apks:
        apk.unlink(missing_ok=True)
    args = [*flutter, "build", "apk", f"--{profile}", "--target-platform", ",".join(platforms)]
    if split_per_abi:
        args.append("--split-per-abi")
    run_command(args, app, env)
    for index, apk in enumerate(apks):
        verify_android_apk(root, apk, profile, (abis[index],) if split_per_abi else abis,
                           ndk_path, cargo_target_dir)
    if install:
        install_android_apk(root, apks, device, env, adb_path)
    return apks
