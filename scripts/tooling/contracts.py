"""各平台共用的 FRB 契约与原生产物元数据检查。"""

from dataclasses import dataclass
import datetime
from pathlib import Path
import re
import tomllib

from .common import ToolError, read_text


@dataclass(frozen=True)
class BridgeContract:
    content_hash: int
    version: str


def unique_match(pattern: str, text: str, field: str) -> str:
    matches = re.findall(pattern, text, re.MULTILINE)
    if len(matches) != 1:
        raise ToolError(f"{field}：要求一个明确声明，实际找到 {len(matches)} 个。")
    return matches[0]


def _ffi_manifest(root: Path) -> dict:
    try:
        return tomllib.loads(read_text(root / "rust" / "legado-ffi" / "Cargo.toml"))
    except tomllib.TOMLDecodeError as exc:
        raise ToolError("legado-ffi/Cargo.toml 无法解析。") from exc


def runtime_version(root: Path) -> str:
    pubspec = read_text(root / "flutter_legado" / "pubspec.yaml")
    # 仅支持当前工程使用的直接标量版本声明，不假装实现通用 YAML 解析器。
    dependencies = unique_match(r"^dependencies:[ \t]*\n((?:[ \t]+[^\n]*\n|\n)*)", pubspec + "\n", "pubspec dependencies")
    runtime_dart = unique_match(
        r"^  flutter_rust_bridge:[ \t]*(\d+\.\d+\.\d+|'\d+\.\d+\.\d+'|\"\d+\.\d+\.\d+\")[ \t]*(?:#.*)?$",
        dependencies, "pubspec FRB 精确版本",
    ).strip("'\"")
    cargo = _ffi_manifest(root)
    runtime_rust = cargo.get("dependencies", {}).get("flutter_rust_bridge")
    if runtime_rust != f"={runtime_dart}":
        raise ToolError("Dart/Rust FRB runtime 必须精确固定为同一版本。")
    return runtime_dart


def bridge_contract(root: Path) -> BridgeContract:
    dart = read_text(root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart")
    rust = read_text(root / "rust" / "legado-ffi" / "src" / "frb_generated.rs")
    dart_hash = int(unique_match(r"^\s*int get rustContentHash\s*=>\s*(-?\d+)\s*;\s*$", dart, "Dart FRB hash"))
    rust_hash = int(unique_match(r"^.*\bconst FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH\s*:\s*i32\s*=\s*(-?\d+)\s*;\s*$", rust, "Rust FRB hash"))
    if dart_hash != rust_hash or not -(2**31) <= rust_hash < 2**31:
        raise ToolError("Dart/Rust FRB contentHash 不一致或超出 i32 范围。")
    dart_version = unique_match(r"^\s*String get codegenVersion\s*=>\s*['\"]([^'\"]+)['\"]\s*;\s*$", dart, "Dart codegenVersion")
    rust_version = unique_match(r'^.*\bconst FLUTTER_RUST_BRIDGE_CODEGEN_VERSION\s*:\s*&str\s*=\s*"([^"]+)"\s*;\s*$', rust, "Rust codegenVersion")
    runtime_dart = runtime_version(root)
    if dart_version != rust_version or dart_version != runtime_dart:
        raise ToolError("FRB 生成物版本与 Dart/Rust runtime 不一致，需要重新生成绑定。")
    manifest = _ffi_manifest(root)
    expected_stem = manifest.get("lib", {}).get("name") or manifest.get("package", {}).get("name", "").replace("-", "_")
    stem = unique_match(r"^\s*stem:\s*['\"]([^'\"]+)['\"],?\s*$", dart, "FRB 原生库名")
    if not expected_stem or stem != expected_stem:
        raise ToolError(f"FRB 原生库名错误：{stem}，应为 {expected_stem}；请确保 cargo metadata 成功后重新生成绑定。")
    return BridgeContract(rust_hash, dart_version)


def validate_schema(meta: dict, abi: str):
    def reject(message):
        raise ToolError(f"{abi}：{message}")

    if type(meta.get("schemaVersion")) is not int or meta["schemaVersion"] != 2:
        reject("schemaVersion 必须为 2；旧元数据需要由新构建入口重编后生成。")
    for field in ("contentHash",):
        if type(meta.get(field)) is not int or not -(2**31) <= meta[field] < 2**31:
            reject(f"{field} 必须是 i32 整数。")
    for field in ("rustFingerprint", "sourceSha256", "packagedSha256", "buildInputsSha256"):
        if type(meta.get(field)) is not str or not re.fullmatch(r"[0-9a-f]{64}", meta[field]):
            reject(f"{field} 缺失或不是小写 SHA-256。")
    for field in ("fingerprintAlgorithm", "buildInputsAlgorithm", "frbCodegenVersion",
                  "targetTriple", "abi", "profile", "builtAt"):
        if type(meta.get(field)) is not str or not meta[field]:
            reject(f"{field} 缺失或不是非空字符串。")
    if type(meta.get("features")) is not list or any(type(value) is not str for value in meta["features"]):
        reject("features 必须是字符串列表。")
    if meta["features"] != sorted(set(meta["features"])):
        reject("features 必须去重并排序。")
    try:
        timestamp = datetime.datetime.fromisoformat(meta["builtAt"])
        if timestamp.utcoffset() != datetime.timedelta(0):
            reject("builtAt 必须包含 UTC 时区。")
    except ValueError:
        reject("builtAt 必须是 ISO8601 时间。")
