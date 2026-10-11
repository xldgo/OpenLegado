"""只读校验 Android FFI 契约、来源元数据与库文件。"""

from dataclasses import dataclass
from pathlib import Path
import struct

from .common import ToolError, read_json, sha256_file
from .contracts import bridge_contract, validate_schema
from .fingerprint import ALGORITHM, rust_fingerprint
from .policy import INPUTS_ALGORITHM, build_inputs_sha256, load_policy, select_target


@dataclass(frozen=True)
class Verification:
    abi: str
    source_checked: bool


def verify_elf(path: Path, target: dict):
    with path.open("rb") as stream:
        header = stream.read(64)
    if len(header) < 52 or header[:4] != b"\x7fELF" or header[5:7] != b"\x01\x01":
        raise ToolError(f"{path}：不是有效的小端 ELF 库。")
    if header[4] != target["elfClass"] or (header[4] == 2 and len(header) < 64):
        raise ToolError(f"{path}：ELF 位数与 ABI 不符。")
    elf_type, machine, version = struct.unpack_from("<HHI", header, 16)
    if elf_type != 3 or machine != target["elfMachine"] or version != 1:
        raise ToolError(f"{path}：ELF 类型或架构与 ABI 不符。")
    # 保留 dev 的 16 KB LOAD/RELRO 门禁，不能仅凭 ELF 头与摘要放行。
    is_64_bit = header[4] == 2
    header_format = "<16sHHIQQQIHHHHHH" if is_64_bit else "<16sHHIIIIIHHHHHH"
    segment_format = "<IIQQQQQQ" if is_64_bit else "<IIIIIIII"
    segment_size = struct.calcsize(segment_format)
    fields = struct.unpack_from(header_format, header)
    offset, entry_size, count = fields[5], fields[9], fields[10]
    file_length = path.stat().st_size
    if count == 0 or entry_size < segment_size or offset + entry_size * count > file_length:
        raise ToolError(f"{path}：ELF 程序头表不完整。")
    page_size = 16384
    loads = 0
    with path.open("rb") as stream:
        for index in range(count):
            stream.seek(offset + entry_size * index)
            segment = struct.unpack(segment_format, stream.read(segment_size))
            if is_64_bit:
                kind, _, file_offset, address, _, file_size, memory_size, alignment = segment
            else:
                kind, file_offset, address, _, file_size, memory_size, _, alignment = segment
            if kind == 1:
                loads += 1
                if alignment < page_size or alignment & (alignment - 1):
                    raise ToolError(f"{path}：LOAD 段 {index} 的对齐值不满足 16 KB。")
                if file_offset % alignment != address % alignment:
                    raise ToolError(f"{path}：LOAD 段 {index} 的文件偏移与虚拟地址不一致。")
                if memory_size < file_size or file_offset + file_size > file_length:
                    raise ToolError(f"{path}：LOAD 段 {index} 的大小不合法。")
            elif kind == 0x6474E552 and (address + memory_size) % page_size:
                raise ToolError(f"{path}：RELRO 末尾未按 16 KB 对齐。")
    if not loads:
        raise ToolError(f"{path}：ELF 缺少 LOAD 段。")


def verify_android(root: Path, profile: str, abis: tuple[str, ...],
                   cargo_target_dir: Path | None = None,
                   artifact_dir: Path | None = None) -> list[Verification]:
    if not abis or len(abis) != len(set(abis)):
        raise ToolError("必须指定非空且不重复的 ABI 列表。")
    policy = load_policy(root)
    targets = {abi: select_target(policy, abi, profile) for abi in abis}
    contract = bridge_contract(root)
    fingerprint = rust_fingerprint(root / "rust")
    results = []
    libraries = artifact_dir if artifact_dir is not None else (
        root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs"
    )
    for abi, target in targets.items():
        library = libraries / abi / "liblegado_ffi.so"
        if not library.is_file() or library.stat().st_size == 0:
            raise ToolError(f"{abi}：库不存在或为空：{library}")
        meta_path = library.with_suffix(".so.meta")
        meta = read_json(meta_path)
        validate_schema(meta, abi)
        if "toolchain" in meta:
            tools = meta["toolchain"]
            if type(tools) is not dict or any(type(tools.get(key)) is not str or not tools[key]
                                            for key in ("ndkVersion", "rustc", "cargo", "clang")):
                raise ToolError(f"{abi}：toolchain 记录不完整。")
            if tools["ndkVersion"] != policy["ndkVersion"]:
                raise ToolError(f"{abi}：toolchain.ndkVersion 与构建策略不一致。")
        expected = {
            "fingerprintAlgorithm": ALGORITHM,
            "buildInputsAlgorithm": INPUTS_ALGORITHM,
            "contentHash": contract.content_hash,
            "frbCodegenVersion": contract.version,
            "rustFingerprint": fingerprint,
            "targetTriple": target["targetTriple"],
            "abi": abi,
            "profile": profile,
            "features": target["features"][profile],
            "buildInputsSha256": build_inputs_sha256(root, policy, abi, profile, fingerprint,
                                                    contract.content_hash, contract.version),
            "packagedSha256": sha256_file(library),
        }
        for field, value in expected.items():
            if meta[field] != value:
                raise ToolError(f"{abi}：{field} 不匹配，需要重新构建对应库。")
        verify_elf(library, target)
        if cargo_target_dir is not None:
            source = cargo_target_dir / target["targetTriple"] / profile / library.name
            if not source.is_file() or source.stat().st_size == 0:
                raise ToolError(f"{abi}：显式指定的 Cargo 源库不存在或为空：{source}")
            if sha256_file(source) != meta["sourceSha256"]:
                raise ToolError(f"{abi}：sourceSha256 与 Cargo 源库不匹配。")
            verify_elf(source, target)
        results.append(Verification(abi, cargo_target_dir is not None))
    return results
