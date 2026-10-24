"""构造临时工程与 ELF 段；这些 fixture 不代表真实原生编译产物。"""

import json
from pathlib import Path
import shutil
import struct
import sys


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from tooling.common import sha256_file
from tooling.ffi_metadata import bridge_contract
from tooling.fingerprint import ALGORITHM, rust_fingerprint
from tooling.policy import INPUTS_ALGORITHM, build_inputs_sha256, load_policy, select_target


def write(path: Path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content.encode("utf-8") if isinstance(content, str) else content)


def elf(target, payload=b"fixture"):
    is_64_bit = target["elfClass"] == 2
    header_format = "<16sHHIQQQIHHHHHH" if is_64_bit else "<16sHHIIIIIHHHHHH"
    segment_format = "<IIQQQQQQ" if is_64_bit else "<IIIIIIII"
    header_size = struct.calcsize(header_format)
    segment_size = struct.calcsize(segment_format)
    ident = b"\x7fELF" + bytes((target["elfClass"], 1, 1)) + bytes(9)
    header = struct.pack(header_format, ident, 3, target["elfMachine"], 1,
                         0, header_size, 0, 0, header_size, segment_size, 2, 0, 0, 0)
    file_size = header_size + 2 * segment_size + len(payload)
    if is_64_bit:
        load = struct.pack(segment_format, 1, 4, 0, 0, 0, file_size, 16384, 16384)
        relro = struct.pack(segment_format, 0x6474E552, 4, 0, 4096, 0, 0, 12288, 1)
    else:
        load = struct.pack(segment_format, 1, 0, 0, 0, file_size, 16384, 4, 16384)
        relro = struct.pack(segment_format, 0x6474E552, 0, 4096, 0, 0, 12288, 4, 1)
    return header + load + relro + payload


def fixture(root: Path):
    write(root / "scripts" / "dev.py", (ROOT / "scripts" / "dev.py").read_bytes())
    shutil.copytree(ROOT / "scripts" / "tooling", root / "scripts" / "tooling",
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo"))
    write(root / "rust" / "legado-ffi" / "Cargo.toml",
          '[package]\nname = "legado-ffi"\nversion = "0.2.0"\n'
          '[dependencies]\nflutter_rust_bridge = "=2.13.0"\n')
    write(root / "rust" / "rust-toolchain.toml", '[toolchain]\nchannel = "stable"\n')
    write(root / "rust" / "Cargo.lock", "# 测试锁文件\n")
    write(root / "flutter_legado" / "pubspec.lock", "# 测试锁文件\n")
    write(root / "flutter_legado" / "flutter_rust_bridge.yaml",
          'rust_root: ../rust/legado-ffi/\ndart_output: lib/src/bridge/\n'
          'auto_upgrade_dependency: false\ndart_fix: false\n')
    write(root / "rust" / "legado-ffi" / "src" / "frb_generated.rs",
          'pub(crate) const FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "2.13.0";\n'
          'pub(crate) const FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = -123456;\n')
    write(root / "rust" / "legado-ffi" / "src" / "business.rs", "业务实现\n")
    write(root / "flutter_legado" / "pubspec.yaml", "dependencies:\n  flutter_rust_bridge: 2.13.0\n")
    write(root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart",
          "stem: 'legado_ffi',\nString get codegenVersion => '2.13.0';\nint get rustContentHash => -123456;\n")


def artifact(root: Path, abi="arm64-v8a", profile="debug", cargo_dir=None):
    policy = load_policy(root)
    target = select_target(policy, abi, profile)
    contract = bridge_contract(root)
    fingerprint = rust_fingerprint(root / "rust")
    library = root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs" / abi / "liblegado_ffi.so"
    write(library, elf(target))
    source = library
    if cargo_dir is not None:
        source = cargo_dir / target["targetTriple"] / profile / library.name
        write(source, elf(target, b"source-before-strip"))
    meta = {
        "schemaVersion": 2,
        "fingerprintAlgorithm": ALGORITHM,
        "buildInputsAlgorithm": INPUTS_ALGORITHM,
        "contentHash": contract.content_hash,
        "frbCodegenVersion": contract.version,
        "rustFingerprint": fingerprint,
        "targetTriple": target["targetTriple"],
        "abi": abi,
        "profile": profile,
        "features": target["features"][profile],
        "sourceSha256": sha256_file(source),
        "packagedSha256": sha256_file(library),
        "buildInputsSha256": build_inputs_sha256(root, policy, abi, profile, fingerprint,
                                                contract.content_hash, contract.version),
        "builtAt": "2026-10-10T00:00:00+00:00",
    }
    meta_path = library.with_suffix(".so.meta")
    write(meta_path, json.dumps(meta))
    return library, meta_path, meta
