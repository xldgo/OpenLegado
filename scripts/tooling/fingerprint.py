"""按实际文件字节计算源码树指纹；不归一化换行。"""

import hashlib
import os
from pathlib import Path
import stat

from .common import ToolError, sha256_file


ALGORITHM = "rust-tree-sha256-v1"


def tree_fingerprint(root: Path, excluded_dirs=(), excluded_suffixes=()) -> str:
    if not root.is_dir():
        raise ToolError(f"指纹目录不存在：{root}")
    records = []

    def visit(directory):
        # 不接受链接输入，避免 Cargo 使用外部内容而指纹无法追踪；兼容 Python 3.11 junction。
        with os.scandir(directory) as entries:
            for entry in entries:
                path = Path(entry.path)
                if entry.name in excluded_dirs and entry.is_dir(follow_symlinks=False):
                    continue
                attributes = getattr(entry.stat(follow_symlinks=False), "st_file_attributes", 0)
                if entry.is_symlink() or attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
                    raise ToolError(f"指纹不接受符号链接或重解析点：{path}")
                if entry.is_dir(follow_symlinks=False):
                    visit(path)
                elif entry.is_file(follow_symlinks=False):
                    if path.suffix in excluded_suffixes:
                        continue
                    relative = path.relative_to(root).as_posix()
                    if any(char in relative for char in "\t\r\n\\"):
                        raise ToolError(f"指纹不支持含制表符、换行或反斜杠的文件名：{relative!r}")
                    try:
                        record = f"{relative}\t{sha256_file(path)}\n".encode("utf-8")
                    except UnicodeError as exc:
                        raise ToolError(f"文件名无法按 UTF-8 编码：{relative!r}") from exc
                    records.append(record)
                else:
                    raise ToolError(f"指纹不支持此文件类型：{path}")

    visit(root)
    return hashlib.sha256(b"".join(sorted(records))).hexdigest()


def rust_fingerprint(root: Path) -> str:
    return tree_fingerprint(root, excluded_dirs=("target",))
