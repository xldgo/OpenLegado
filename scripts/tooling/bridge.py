"""分开执行 Dart 和 FRB 生成；隔离复核不改写原工作区。"""

import os
from pathlib import Path
import re
import shutil
import tempfile

from .common import ToolError, read_text, run_command
from .contracts import bridge_contract, runtime_version, unique_match
from .fingerprint import tree_fingerprint
from .toolchains import dart_environment, find_tool, rust_environment


def generate_dart(root: Path):
    dart, env = dart_environment(dict(os.environ))
    app = root / "flutter_legado"
    run_command([dart, "pub", "get", "--enforce-lockfile"], app, env)
    run_command([dart, "run", "build_runner", "build"], app, env)


def validate_config(root: Path):
    app = root / "flutter_legado"
    text = read_text(app / "flutter_rust_bridge.yaml")
    # 此入口保护当前固定输出边界；新增自定义输出配置需先扩展隔离与差异检查。
    expected = {"rust_root": root / "rust" / "legado-ffi", "dart_output": app / "lib" / "src" / "bridge"}
    for key, destination in expected.items():
        value = unique_match(rf"^{key}:[ \t]*([^\r\n#]+)[ \t]*(?:#.*)?$", text, "FRB " + key).strip().strip("'\"")
        if (Path(value).is_absolute() or (app / value).resolve() != destination.resolve()
                or not destination.resolve().is_relative_to(root.resolve())):
            raise ToolError(f"FRB {key} 必须使用当前工程的相对路径，防止隔离生成写入原工作区。")
    if re.search(r"^(rust_output|c_output|duplicated_c_output|dart_root):", text, re.MULTILINE):
        raise ToolError("当前隔离生成尚不支持自定义 Rust/C/Dart 输出配置。")
    for key in ("auto_upgrade_dependency", "dart_fix"):
        if unique_match(rf"^{key}:[ \t]*(true|false)[ \t]*$", text, "FRB " + key) != "false":
            raise ToolError(f"FRB {key} 必须为 false，避免生成时升级依赖或修复无关文件。")


def generated_manifest(root: Path) -> dict[str, bytes]:
    bridge = root / "flutter_legado" / "lib" / "src" / "bridge"
    paths = list(bridge.rglob("*")) if bridge.exists() else []
    paths.append(root / "rust" / "legado-ffi" / "src" / "frb_generated.rs")
    paths.append(root / "rust" / "legado-ffi" / "src" / "lib.rs")
    result = {}
    for path in paths:
        if path.is_file():
            # 与 Git 的文本存储口径一致；源码指纹仍严格使用实际字节。
            result[path.relative_to(root).as_posix()] = path.read_bytes().replace(b"\r\n", b"\n")
    return result


def copy_inputs(root: Path, isolated: Path):
    for relative in ("rust", "flutter_legado/lib"):
        source = root / relative
        tree_fingerprint(source, excluded_dirs=("target", "__pycache__"))
        shutil.copytree(source, isolated / relative, ignore=shutil.ignore_patterns("target", "__pycache__"))
    third_party = root / "third_party"
    if third_party.is_dir():
        tree_fingerprint(third_party, excluded_dirs=("target", "__pycache__"))
        shutil.copytree(third_party, isolated / "third_party", ignore=shutil.ignore_patterns("target", "__pycache__"))
    app = isolated / "flutter_legado"
    for name in ("pubspec.yaml", "pubspec.lock", "flutter_rust_bridge.yaml", "build.yaml", "analysis_options.yaml"):
        source = root / "flutter_legado" / name
        if source.exists():
            shutil.copyfile(source, app / name)


def invoke_bridge(root: Path, codegen: Path, dart: Path, env: dict):
    app = root / "flutter_legado"
    protected = [root / "rust" / "Cargo.lock", app / "pubspec.yaml", app / "pubspec.lock"]
    before = {path: path.read_bytes() for path in protected}
    run_command([dart, "pub", "get", "--enforce-lockfile"], app, env)
    run_command([codegen, "generate", "--config-file", "flutter_rust_bridge.yaml"], app, env)
    changed = [str(path) for path, content in before.items() if not path.is_file() or path.read_bytes() != content]
    if changed:
        raise ToolError("生成过程改动依赖声明或锁文件，需要单独处理：\n" + "\n".join(changed))
    bridge_contract(root)


def input_snapshot(root: Path):
    """记录复制输入；拒绝在生成期间覆盖调用方的新修改。"""
    trees = ("rust", "flutter_legado/lib", "third_party")
    result = {name: tree_fingerprint(root / name, excluded_dirs=("target", "__pycache__"))
              for name in trees if (root / name).exists()}
    for name in ("pubspec.yaml", "pubspec.lock", "flutter_rust_bridge.yaml", "build.yaml", "analysis_options.yaml"):
        path = root / "flutter_legado" / name
        result[name] = path.read_bytes() if path.exists() else None
    return result


def replace_output(path: Path, content: bytes | None):
    """单文件原子替换，临时文件始终留在目标目录。"""
    if content is None:
        path.unlink()
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".frb-", delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(content)
        except BaseException:
            output.close()
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def publish_outputs(root: Path, before: dict, after: dict, differences: list[str]):
    """只发布 FRB 自有生成物，失败时恢复本次已改动的文件。"""
    rust_output = "rust/legado-ffi/src/frb_generated.rs"
    marker = b"@generated by `flutter_rust_bridge`"
    for relative in differences:
        if relative == rust_output:
            continue
        # rust_lib.dart 等手写入口与 lib.rs 不能被生成器顺带改写。
        contents = [manifest[relative] for manifest in (before, after) if relative in manifest]
        if not contents or not all(marker in content[:512] for content in contents):
            raise ToolError("生成器改动了非 FRB 自有文件，未发布任何输出：" + relative)
    originals = {relative: (root / relative).read_bytes() if (root / relative).exists() else None
                 for relative in differences}
    touched = []
    try:
        for relative in differences:
            touched.append(relative)
            replace_output(root / relative, after.get(relative))
    except BaseException:
        for relative in reversed(touched):
            content = originals[relative]
            path = root / relative
            if content is not None or path.exists():
                replace_output(path, content)
        raise


def generate_bridge(root: Path, check=False):
    version = runtime_version(root)
    validate_config(root)
    env = rust_environment(root, dict(os.environ))
    dart, env = dart_environment(env)
    codegen = find_tool("flutter_rust_bridge_codegen", env)
    find_tool("cargo-expand", env)  # 禁止生成器因缺失依赖而隐式安装最新版。
    actual = run_command([codegen, "--version"], root / "flutter_legado", env, capture=True).strip()
    if actual != f"flutter_rust_bridge_codegen {version}":
        raise ToolError(f"FRB 生成器必须为 {version}；请运行 cargo install flutter_rust_bridge_codegen --version {version} --locked。")
    # 复制当前工作区而不是 HEAD，包含尚未提交的输入；不创建 Git worktree。
    snapshot = input_snapshot(root)
    with tempfile.TemporaryDirectory(prefix="legado-bridge-") as name:
        isolated = Path(name).resolve()
        copy_inputs(root, isolated)
        before = generated_manifest(isolated)
        env = {**env, "CARGO_TARGET_DIR": str(isolated / "rust" / "target")}
        # 只读复核也不能由 Cargo 在原树或全局默认输出目录产生构建残留。
        invoke_bridge(isolated, codegen, dart, env)
        after = generated_manifest(isolated)
        differences = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
        if check and differences:
            raise ToolError("FRB 生成物与当前输入不一致（新增、删除或内容改变）：\n" + "\n".join(differences))
        if input_snapshot(root) != snapshot:
            raise ToolError("生成期间原工作区输入发生变化，未发布任何输出；请重新生成。")
        if not check:
            publish_outputs(root, before, after, differences)
