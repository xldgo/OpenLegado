"""Windows Rust DLL 与 Flutter 应用编排；生成代码不属于构建副作用。"""

from contextlib import contextmanager
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import sys
import tempfile

from .common import ToolError, cargo_artifact, output_directory, read_json, run_command, sha256_file
from .contracts import bridge_contract, validate_schema
from .fingerprint import ALGORITHM, rust_fingerprint, tooling_fingerprint
from .toolchains import find_tool, rust_environment


TARGET = "x86_64-pc-windows-msvc"
INPUTS_ALGORITHM = "windows-ffi-inputs-sha256-v2"


def validate_windows_profile(profile: str, quickjs=True):
    if profile not in ("debug", "release"):
        raise ToolError("Windows profile 只能是 debug 或 release。")
    if not quickjs and profile != "debug":
        raise ToolError("无 QuickJS 的 stub 仅允许显式 Debug 开发，Release 必须启用 QuickJS。")


def require_windows(profile: str, quickjs=True):
    validate_windows_profile(profile, quickjs)
    if sys.platform != "win32":
        raise ToolError("Windows 构建与运行需要 Windows 宿主及 MSVC 工具链。")


def windows_inputs(root: Path, profile: str, quickjs: bool) -> dict:
    contract = bridge_contract(root)
    inputs = {
        "algorithm": INPUTS_ALGORITHM,
        "rustFingerprint": rust_fingerprint(root / "rust"),
        "contentHash": contract.content_hash,
        "frbCodegenVersion": contract.version,
        "targetTriple": TARGET,
        "profile": profile,
        "features": ["quickjs"] if quickjs else [],
        "toolingFingerprint": tooling_fingerprint(root, "windows"),
    }
    digest = hashlib.sha256(json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"fingerprintAlgorithm": ALGORITHM, "buildInputsAlgorithm": INPUTS_ALGORITHM,
            "abi": "x86_64", "buildInputsSha256": digest,
            **{key: inputs[key] for key in ("rustFingerprint", "contentHash", "frbCodegenVersion",
                                           "targetTriple", "profile", "features")}}


def verify_pe(library: Path):
    if not library.is_file() or library.stat().st_size == 0:
        raise ToolError(f"Windows DLL 不存在或为空：{library}")
    with library.open("rb") as stream:
        header = stream.read(64)
        if len(header) != 64 or header[:2] != b"MZ":
            raise ToolError(f"{library}：不是 Windows PE 库。")
        offset = struct.unpack_from("<I", header, 60)[0]
        if offset < 64:
            raise ToolError(f"{library}：PE 头偏移不合法。")
        stream.seek(offset)
        pe = stream.read(26)
    if (len(pe) != 26 or pe[:4] != b"PE\0\0" or struct.unpack_from("<H", pe, 4)[0] != 0x8664
            or not struct.unpack_from("<H", pe, 22)[0] & 0x2000
            or struct.unpack_from("<H", pe, 24)[0] != 0x20B):
        raise ToolError(f"{library}：要求 x64 PE32+ DLL。")


def verify_windows_ffi(root: Path, profile: str, cargo_target_dir: Path | None = None,
                       quickjs=True) -> Path:
    validate_windows_profile(profile, quickjs)
    output = output_directory(root, cargo_target_dir)
    library = output / profile / "legado_ffi.dll"
    verify_pe(library)
    meta = read_json(library.with_suffix(".dll.meta"))
    validate_schema(meta, "Windows x64")
    expected = windows_inputs(root, profile, quickjs)
    expected["packagedSha256"] = sha256_file(library)
    for key, value in expected.items():
        if meta[key] != value:
            raise ToolError(f"Windows DLL：{key} 不匹配，需要按当前配置重编。")
    source = output / TARGET / profile / library.name
    verify_pe(source)
    if sha256_file(source) != meta["sourceSha256"] or meta["sourceSha256"] != meta["packagedSha256"]:
        raise ToolError("Windows DLL：Cargo 源库、复制库与元数据摘要不同。")
    return library


@contextmanager
def windows_lock(root: Path):
    directory = root / "rust" / "target"
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / ".python-windows-ffi.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ToolError(f"已有 Windows 构建锁 {lock}；确认无相关构建后才可手动移除。") from exc
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(str(os.getpid()))
        yield
    finally:
        lock.unlink()


def build_windows_ffi(root: Path, profile: str, cargo_target_dir: Path | None = None,
                      quickjs=True, clean=False) -> Path:
    require_windows(profile, quickjs)
    env = rust_environment(root, os.environ.copy())
    cargo, rustc = find_tool("cargo", env), find_tool("rustc", env)
    env["RUSTC"] = str(rustc)
    rust_version = run_command([rustc, "-Vv"], root / "rust", env, capture=True).strip()
    if f"host: {TARGET}" not in rust_version.splitlines():
        raise ToolError(f"当前 Windows 构建仅支持 Rust host {TARGET}，不自动安装或切换工具链。")
    output = output_directory(root, cargo_target_dir)
    with windows_lock(root):
        inputs = windows_inputs(root, profile, quickjs)
        if not quickjs:
            print("显式 Debug stub：关闭 QuickJS，书源 JavaScript 能力不可用于功能验收。")
        if clean:
            run_command([cargo, "clean", "-p", "legado-ffi", "--target", TARGET, "--target-dir", output],
                        root / "rust", env)
        args = [cargo, "build", "--locked", "-p", "legado-ffi", "--no-default-features",
                "--target", TARGET, "--target-dir", output, "--message-format=json-render-diagnostics"]
        if profile == "release":
            args.append("--release")
        if quickjs:
            args.extend(["--features", "quickjs"])
        source = cargo_artifact(run_command(args, root / "rust", env, capture=True),
                                output / TARGET / profile / "legado_ffi.dll")
        verify_pe(source)
        if windows_inputs(root, profile, quickjs) != inputs:
            raise ToolError("构建期间源码、工具或 FRB 契约改变，拒绝发布 DLL 元数据。")
        destination = output / profile / "legado_ffi.dll"
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Cargo 目标目录内临时复制；仅替换明确的 DLL 与元数据，不递归删除或移动目录。
        with tempfile.TemporaryDirectory(prefix=".tmp_windows_ffi_", dir=destination.parent) as temporary:
            staged = Path(temporary) / destination.name
            shutil.copyfile(source, staged)
            digest = sha256_file(staged)
            if digest != sha256_file(source):
                raise ToolError("Windows DLL 复制后摘要不一致。")
            metadata = {"schemaVersion": 2, **inputs, "sourceSha256": digest, "packagedSha256": digest,
                        "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        "toolchain": {"rustc": rust_version,
                                      "cargo": run_command([cargo, "-V"], root / "rust", env, capture=True).strip()}}
            meta = Path(temporary) / "legado_ffi.dll.meta"
            meta.write_text(json.dumps(metadata, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            try:
                os.replace(staged, destination)
                os.replace(meta, destination.with_suffix(".dll.meta"))
            except PermissionError as exc:
                raise ToolError("Windows DLL 被占用或不可写；请手动关闭应用后重试，不会强制结束进程。") from exc
        return verify_windows_ffi(root, profile, output, quickjs)
