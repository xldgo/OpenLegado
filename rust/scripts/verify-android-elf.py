#!/usr/bin/env python3
"""检查 Android Rust 动态库的 16 KB LOAD 与 RELRO 对齐。"""

import argparse
from pathlib import Path
import struct
import sys

PAGE_SIZE = 16384


def verify(path: Path) -> None:
    data = path.read_bytes()
    if len(data) < 16 or data[:4] != b"\x7fELF" or data[4] not in (1, 2) or data[5] != 1:
        raise ValueError("不是有效的 Android 小端 ELF")
    is_64_bit = data[4] == 2
    header_format = "<16sHHIQQQIHHHHHH" if is_64_bit else "<16sHHIIIIIHHHHHH"
    segment_format = "<IIQQQQQQ" if is_64_bit else "<IIIIIIII"
    header_size = struct.calcsize(header_format)
    segment_size = struct.calcsize(segment_format)
    if len(data) < header_size:
        raise ValueError("ELF 文件头不完整")
    header = struct.unpack_from(header_format, data)
    if header[1] != 3 or header[2] not in ((62, 183) if is_64_bit else (40,)):
        raise ValueError("不是支持的 Android ABI 动态库")
    offset, entry_size, count = header[5], header[9], header[10]
    if count == 0 or entry_size < segment_size or offset + entry_size * count > len(data):
        raise ValueError("ELF 程序头表不完整")
    loads = 0
    for index in range(count):
        segment = struct.unpack_from(segment_format, data, offset + entry_size * index)
        if is_64_bit:
            kind, _, file_offset, address, _, file_size, memory_size, alignment = segment
        else:
            kind, file_offset, address, _, file_size, memory_size, _, alignment = segment
        if kind == 1:
            loads += 1
            if alignment < PAGE_SIZE or alignment & (alignment - 1):
                raise ValueError(f"LOAD 段 {index} 的对齐值 {alignment} 不满足 16 KB")
            if file_offset % alignment != address % alignment:
                raise ValueError(f"LOAD 段 {index} 的文件偏移与虚拟地址不一致")
            if memory_size < file_size or file_offset + file_size > len(data):
                raise ValueError(f"LOAD 段 {index} 的大小不合法")
        elif kind == 0x6474E552:
            end = address + memory_size
            if end % PAGE_SIZE:
                raise ValueError(f"RELRO 末尾 0x{end:x} 未按 16 KB 对齐")
    if not loads:
        raise ValueError("缺少 LOAD 段")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("libraries", nargs="+", type=Path, help="待检查的 Android .so 文件")
    parser.add_argument("--quiet", action="store_true", help="仅返回检查退出码")
    args = parser.parse_args()
    failed = False
    for library in args.libraries:
        try:
            verify(library)
        except (OSError, ValueError, struct.error) as error:
            failed = True
            if not args.quiet:
                print(f"[失败] {library}: {error}", file=sys.stderr)
        else:
            if not args.quiet:
                print(f"[通过] {library}: LOAD / RELRO 16 KB 对齐")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
