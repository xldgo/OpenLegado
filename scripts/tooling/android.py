"""编译 Android Rust FFI，校验全部 ABI 后一次替换 jniLibs。"""

from contextlib import contextmanager
import datetime
import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid

from .common import ToolError, cargo_artifact, run_command, sha256_file
from .ffi_metadata import bridge_contract, verify_android, verify_elf
from .fingerprint import ALGORITHM, rust_fingerprint, tree_fingerprint
from .policy import INPUTS_ALGORITHM, build_inputs_sha256, load_policy, select_target
from .android_toolchain import android_environment, discover_ndk
from .toolchains import find_tool, rust_environment


@contextmanager
def build_lock(root: Path):
    directory = root / "rust" / "target"
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / ".python-android-ffi.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ToolError(f"已有 Python Android FFI 构建锁：{lock}；确认没有构建进程后才可手动移除。") from exc
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(str(os.getpid()))
        yield
    finally:
        lock.unlink()


def publish_directory(stage: Path, destination: Path, backup: Path, validate):
    had_original = destination.exists()
    if had_original:
        os.replace(destination, backup)
    installed = False
    try:
        os.replace(stage, destination)
        installed = True
        validate()
    except BaseException:
        try:
            if installed:
                os.replace(destination, stage)
            if had_original:
                os.replace(backup, destination)
        except OSError as exc:
            raise ToolError(f"发布及自动恢复失败；原库备份保留在 {backup}，请先检查目录占用。") from exc
        raise


def build_android_ffi(root: Path, profile: str, abis: tuple[str, ...],
                      ndk_path: Path | None = None, cargo_target_dir: Path | None = None):
    if not abis or len(abis) != len(set(abis)):
        raise ToolError("必须指定非空且不重复的 ABI 列表。")
    policy = load_policy(root)
    targets = {abi: select_target(policy, abi, profile) for abi in abis}
    contract = bridge_contract(root)
    env = rust_environment(root, dict(os.environ))
    ndk = discover_ndk(root, policy, env, ndk_path)
    cargo = find_tool("cargo", env)
    rustc = find_tool("rustc", env)
    env["RUSTC"] = str(rustc)
    rustup = find_tool("rustup", env)
    installed = run_command([rustup, "target", "list", "--installed"], root / "rust", env, capture=True).splitlines()
    missing = [target["targetTriple"] for target in targets.values() if target["targetTriple"] not in installed]
    if missing:
        raise ToolError("缺少 Rust target，请运行：rustup target add --toolchain "
                        + env["RUSTUP_TOOLCHAIN"] + " " + " ".join(missing))
    output = cargo_target_dir or Path(env.get("CARGO_TARGET_DIR", root / "rust" / "target"))
    if not output.is_absolute():
        output = root / "rust" / output if cargo_target_dir is None else Path.cwd() / output
    output = output.resolve()
    if output.is_relative_to(root / "rust") and "target" not in output.relative_to(root / "rust").parts:
        raise ToolError("Rust 树内的 Cargo 输出目录必须位于 target 目录下，避免输出污染源码指纹。")
    destination = root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs"
    if not destination.resolve().is_relative_to(root.resolve()):
        raise ToolError("jniLibs 路径越出仓库，拒绝覆盖。")
    with build_lock(root):
        fingerprint = rust_fingerprint(root / "rust")
        inputs = {abi: build_inputs_sha256(root, policy, abi, profile, fingerprint,
                                          contract.content_hash, contract.version) for abi in abis}
        versions = {
            "ndkVersion": ndk.version,
            "rustc": run_command([rustc, "-Vv"], root / "rust", env, capture=True).strip(),
            "cargo": run_command([cargo, "-V"], root / "rust", env, capture=True).strip(),
            "clang": run_command([ndk.tool("clang"), "--version"], root / "rust", env, capture=True).strip(),
        }
        sources = {}
        for abi, target in targets.items():
            print(f"编译 {abi}：{profile}，features={target['features'][profile]}", flush=True)
            command = [cargo, "build", "--locked", "-p", "legado-ffi", "--no-default-features",
                       "--target", target["targetTriple"], "--target-dir", output,
                       "--message-format=json-render-diagnostics"]
            if profile == "release":
                command.append("--release")
            if target["features"][profile]:
                command.extend(["--features", ",".join(target["features"][profile])])
            build_env = android_environment(env, ndk, target, policy)
            result = run_command(command, root / "rust", build_env, capture=True)
            source = cargo_artifact(result, output / target["targetTriple"] / profile / "liblegado_ffi.so")
            verify_elf(source, target)
            sources[abi] = (source, sha256_file(source))
        if rust_fingerprint(root / "rust") != fingerprint or bridge_contract(root) != contract:
            raise ToolError("构建期间 Rust 源码或 FRB 契约变化，拒绝发布库与元数据。")
        for abi in abis:
            if build_inputs_sha256(root, policy, abi, profile, fingerprint,
                                   contract.content_hash, contract.version) != inputs[abi]:
                raise ToolError("构建期间工程工具或策略变化，拒绝发布库与元数据。")
        destination.parent.mkdir(parents=True, exist_ok=True)
        # 临时目录、备份和递归清理都限定在已核对的仓库 jniLibs 父目录内。
        with tempfile.TemporaryDirectory(prefix=".tmp_ffi_stage_", dir=destination.parent) as name:
            directory = Path(name).resolve()
            if not directory.is_relative_to(destination.parent.resolve()):
                raise ToolError("临时产物目录越界。")
            stage = directory / "jniLibs"
            if destination.exists():
                tree_fingerprint(destination)
                shutil.copytree(destination, stage)
            else:
                stage.mkdir()
            for abi, target in targets.items():
                source, source_hash = sources[abi]
                library = stage / abi / source.name
                library.parent.mkdir(exist_ok=True)
                shutil.copyfile(source, library)
                if sha256_file(library) != source_hash:
                    raise ToolError(f"{abi}：复制摘要与 Cargo 本次产物不一致。")
                if profile == "release":
                    run_command([ndk.tool("llvm-strip"), "--strip-unneeded", library], root / "rust", env)
                verify_elf(library, target)
                meta = {
                    "schemaVersion": 2, "fingerprintAlgorithm": ALGORITHM,
                    "buildInputsAlgorithm": INPUTS_ALGORITHM,
                    "contentHash": contract.content_hash, "frbCodegenVersion": contract.version,
                    "rustFingerprint": fingerprint, "buildInputsSha256": inputs[abi],
                    "targetTriple": target["targetTriple"], "abi": abi, "profile": profile,
                    "features": target["features"][profile], "sourceSha256": source_hash,
                    "packagedSha256": sha256_file(library), "toolchain": versions,
                    "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                }
                library.with_suffix(".so.meta").write_text(json.dumps(meta, separators=(",", ":")), encoding="utf-8")
            verify_android(root, profile, abis, output, artifact_dir=stage)
            # 原库备份放在自动清理目录之外；恢复本身失败时不能随临时目录被删除。
            backup = destination.parent / (".tmp_ffi_backup_" + uuid.uuid4().hex)
            publish_directory(stage, destination, backup,
                              lambda: verify_android(root, profile, abis, output))
            if backup.exists():
                if backup.resolve().parent != destination.parent.resolve():
                    raise ToolError("原库备份清理路径越界。")
                shutil.rmtree(backup)
    return output
