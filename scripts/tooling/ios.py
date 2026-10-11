"""iOS 正式 RustFFI 静态库编排；CocoaPods、签名和图标处理仍由现有流程负责。"""

from contextlib import contextmanager
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import sys
import tempfile

from .common import CommandError, ToolError, cargo_artifact, output_directory, read_json, read_text, run_command, sha256_file
from .ffi_metadata import bridge_contract, unique_match, validate_schema
from .fingerprint import ALGORITHM, rust_fingerprint, tree_fingerprint
from .toolchains import find_tool, rust_environment


TARGETS = {
    "device": ("aarch64-apple-ios", "iphoneos"),
    "simulator": ("aarch64-apple-ios-sim", "iphonesimulator"),
}
INPUTS_ALGORITHM = "ios-ffi-inputs-sha256-v1"
PDE_SYMBOL = "frb_pde_ffi_dispatcher_primary"


def select_ios_target(target: str, profile: str) -> tuple[str, str]:
    if target not in TARGETS:
        raise ToolError("iOS target 只能是 device 或 simulator。")
    if profile != "release":
        raise ToolError("iOS 正式静态库仅支持 release，并固定启用 QuickJS；模拟器宿主仍可使用 Debug。")
    return TARGETS[target]


def require_macos():
    if sys.platform != "darwin":
        raise ToolError("iOS 编译与符号校验需要 macOS 宿主及 Xcode，当前平台无法执行。")


def deployment_target(root: Path) -> str:
    ios = root / "flutter_legado" / "ios"
    try:
        with (ios / "Flutter" / "AppFrameworkInfo.plist").open("rb") as stream:
            version = plistlib.load(stream).get("MinimumOSVersion")
    except (ValueError, plistlib.InvalidFileException) as exc:
        raise ToolError("AppFrameworkInfo.plist 无法解析。") from exc
    if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", version):
        raise ToolError("AppFrameworkInfo.plist 缺少有效 MinimumOSVersion。")
    pod = unique_match(r"^\s*platform\s+:ios,\s*['\"]([^'\"]+)['\"]\s*$",
                       read_text(ios / "Podfile"), "Podfile iOS 下限")
    rust_pod = unique_match(r"^\s*s\.ios\.deployment_target\s*=\s*['\"]([^'\"]+)['\"]\s*$",
                            read_text(ios / "RustFFI" / "RustFFI.podspec"), "RustFFI iOS 下限")
    project = re.findall(r"\bIPHONEOS_DEPLOYMENT_TARGET\s*=\s*([\d.]+)\s*;",
                         read_text(ios / "Runner.xcodeproj" / "project.pbxproj"))
    if pod != version or rust_pod != version or not project or set(project) != {version}:
        raise ToolError("iOS 最低版本在 Podfile、RustFFI、Xcode 工程与 AppFrameworkInfo 中不一致。")
    return version


def ios_inputs(root: Path, target: str, profile: str) -> dict:
    triple, sdk = select_ios_target(target, profile)
    contract = bridge_contract(root)
    inputs = {
        "algorithm": INPUTS_ALGORITHM,
        "rustFingerprint": rust_fingerprint(root / "rust"),
        "contentHash": contract.content_hash,
        "frbCodegenVersion": contract.version,
        "targetTriple": triple,
        "profile": profile,
        "features": ["quickjs"],
        "sdk": sdk,
        "deploymentTarget": deployment_target(root),
        "entrypointSha256": sha256_file(root / "scripts" / "dev.py"),
        "toolingFingerprint": tree_fingerprint(root / "scripts" / "tooling",
                                               excluded_dirs=("__pycache__",), excluded_suffixes=(".pyc", ".pyo")),
    }
    digest = hashlib.sha256(json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    # 先报告具体字段变化，再核对包含这些字段的聚合摘要。
    return {"fingerprintAlgorithm": ALGORITHM, "buildInputsAlgorithm": INPUTS_ALGORITHM,
            "abi": "arm64",
            **{key: inputs[key] for key in ("rustFingerprint", "contentHash", "frbCodegenVersion",
                                           "targetTriple", "profile", "features", "sdk", "deploymentTarget")},
            "buildInputsSha256": digest}


def verify_archive(library: Path):
    if not library.is_file() or library.stat().st_size <= 8:
        raise ToolError(f"iOS 静态库不存在或为空：{library}")
    with library.open("rb") as stream:
        if stream.read(8) != b"!<arch>\n":
            raise ToolError(f"{library}：要求常规静态归档库。")


def library_path(root: Path) -> Path:
    library = root / "flutter_legado" / "ios" / "RustFFI" / "libliblegado_ffi.a"
    if not library.parent.resolve().is_relative_to(root.resolve()):
        raise ToolError("RustFFI 输出目录越出仓库，拒绝读写。")
    return library


def has_defined_pde(output: str) -> bool:
    # nm 的 U 表示未定义引用；子串命中或仅有 U 不能证明库导出了分发器。
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[-2] == "T" and fields[-1] in (PDE_SYMBOL, "_" + PDE_SYMBOL):
            return True
    return False


def verify_native_symbols(root: Path, library: Path, xcrun: Path, env: dict):
    arches = run_command([xcrun, "lipo", "-archs", library], root, env, capture=True).split()
    if arches != ["arm64"]:
        raise ToolError(f"{library}：要求单一 arm64 库，实际架构为 {arches}。")
    if not has_defined_pde(run_command([xcrun, "nm", "-g", library], root, env, capture=True)):
        raise ToolError(f"{library}：缺少已定义的 FRB PDE 分发器符号。")


def verify_ios_ffi(root: Path, target: str, profile: str, cargo_target_dir: Path | None = None) -> Path:
    select_ios_target(target, profile)
    require_macos()
    library = library_path(root)
    verify_archive(library)
    meta = read_json(library.with_suffix(".a.meta"))
    validate_schema(meta, f"iOS {target}")
    expected = ios_inputs(root, target, profile)
    expected["packagedSha256"] = sha256_file(library)
    for key, value in expected.items():
        if meta.get(key) != value:
            raise ToolError(f"iOS {target}：{key} 不匹配，需要按当前配置重编。")
    source = output_directory(root, cargo_target_dir) / expected["targetTriple"] / profile / "liblegado_ffi.a"
    verify_archive(source)
    if sha256_file(source) != meta["sourceSha256"] or meta["sourceSha256"] != meta["packagedSha256"]:
        raise ToolError("iOS Cargo 源库、RustFFI 复制库与元数据摘要不同。")
    env = os.environ.copy()
    verify_native_symbols(root, library, find_tool("xcrun", env), env)
    return library


@contextmanager
def ios_lock(root: Path):
    # 设备和模拟器共享同一 CocoaPods 路径；阻止同一工作区内并发覆盖。
    directory = root / "rust" / "target"
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / ".python-ios-ffi.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ToolError(f"已有 iOS 构建锁 {lock}；确认无相关构建后才可手动移除。") from exc
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(str(os.getpid()))
        yield
    finally:
        lock.unlink()


def build_ios_ffi(root: Path, target: str, profile: str, cargo_target_dir: Path | None = None) -> Path:
    triple, sdk = select_ios_target(target, profile)
    require_macos()
    env = rust_environment(root, os.environ.copy())
    cargo, rustc, xcrun = (find_tool(name, env) for name in ("cargo", "rustc", "xcrun"))
    env["RUSTC"] = str(rustc)
    sdk_path = run_command([xcrun, "--sdk", sdk, "--show-sdk-path"], root, env, capture=True).strip()
    if not sdk_path or not Path(sdk_path).is_dir():
        raise ToolError(f"Xcode 未提供可用的 {sdk} SDK。")
    env["SDKROOT"] = sdk_path
    env["IPHONEOS_DEPLOYMENT_TARGET"] = deployment_target(root)
    # 保留正式 CI 的 bindgen 参数；清除上一构建目标残留的覆盖值。
    for key in tuple(env):
        if key == "BINDGEN_EXTRA_CLANG_ARGS" or key.startswith("BINDGEN_EXTRA_CLANG_ARGS_"):
            del env[key]
    if target == "simulator":
        env["BINDGEN_EXTRA_CLANG_ARGS"] = shlex.join(
            ["--target=aarch64-apple-ios-simulator", "-isysroot", sdk_path])
    output = output_directory(root, cargo_target_dir)
    with ios_lock(root):
        inputs = ios_inputs(root, target, profile)
        args = [cargo, "rustc", "--locked", "--release", "--target", triple, "-p", "legado-ffi",
                "--lib", "--crate-type", "staticlib", "--no-default-features", "--features", "quickjs",
                "--target-dir", output, "--message-format=json-render-diagnostics"]
        source = cargo_artifact(run_command(args, root / "rust", env, capture=True),
                                output / triple / profile / "liblegado_ffi.a")
        verify_archive(source)
        verify_native_symbols(root, source, xcrun, env)
        if ios_inputs(root, target, profile) != inputs:
            raise ToolError("构建期间源码、工具、iOS 下限或 FRB 契约改变，拒绝发布静态库元数据。")
        destination = library_path(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".tmp_ios_ffi_", dir=destination.parent) as temporary:
            staged = Path(temporary) / destination.name
            shutil.copyfile(source, staged)
            digest = sha256_file(staged)
            if digest != sha256_file(source):
                raise ToolError("iOS 静态库复制后摘要不一致。")
            metadata = {"schemaVersion": 2, **inputs, "sourceSha256": digest, "packagedSha256": digest,
                        "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        "toolchain": {"rustc": run_command([rustc, "-Vv"], root / "rust", env, capture=True).strip(),
                                      "cargo": run_command([cargo, "-V"], root / "rust", env, capture=True).strip(),
                                      "sdkVersion": run_command([xcrun, "--sdk", sdk, "--show-sdk-version"], root, env, capture=True).strip()}}
            meta = Path(temporary) / "libliblegado_ffi.a.meta"
            meta.write_text(json.dumps(metadata, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            # 两次原子替换间若中断，摘要不匹配会使后续只读校验失败，不补写元数据。
            os.replace(staged, destination)
            os.replace(meta, destination.with_suffix(".a.meta"))
        return verify_ios_ffi(root, target, profile, output)


def verify_ios_app(root: Path, target: str, profile: str, app: Path,
                   cargo_target_dir: Path | None = None):
    verify_ios_ffi(root, target, profile, cargo_target_dir)
    if not app.is_dir():
        raise ToolError(f"iOS 应用目录不存在：{app}")
    env = os.environ.copy()
    xcrun = find_tool("xcrun", env)
    candidates = ("Runner", "Runner.debug.dylib") if target == "simulator" else ("Runner",)
    found = False
    for name in candidates:
        binary = app / name
        if not binary.is_file():
            continue
        try:
            present = has_defined_pde(run_command([xcrun, "nm", "-g", binary], root, env, capture=True))
        except CommandError as exc:
            print(f"{name}：符号读取失败（{exc}）")
            continue
        print(f"{name}：{'存在' if present else '缺少'}已定义的 PDE 分发器符号")
        found |= present
    if not found:
        raise ToolError(f"iOS {target} 应用缺少已定义的 FRB PDE 分发器符号，拒绝交付。")
