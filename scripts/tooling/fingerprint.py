"""按实际文件字节计算源码树指纹；不归一化换行。"""

import hashlib
import os
from pathlib import Path
import stat

from .common import ToolError, sha256_file
from .input_scopes import RUST_DRIVERS, native_paths


ALGORITHM = "rust-tree-sha256-v2"


def source_files(root: Path, excluded_dirs=(), excluded_suffixes=(), excluded_paths=()) -> tuple[str, ...]:
    if not root.is_dir():
        raise ToolError(f"指纹目录不存在：{root}")
    files = []

    def visit(directory):
        # 不接受链接输入，避免 Cargo 使用外部内容而指纹无法追踪；兼容 Python 3.11 junction。
        with os.scandir(directory) as entries:
            for entry in entries:
                path = Path(entry.path)
                relative = path.relative_to(root).as_posix()
                if relative in excluded_paths:
                    continue
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
                    if any(char in relative for char in "\t\r\n\\"):
                        raise ToolError(f"指纹不支持含制表符、换行或反斜杠的文件名：{relative!r}")
                    files.append(relative)
                else:
                    raise ToolError(f"指纹不支持此文件类型：{path}")

    visit(root)
    return tuple(files)


def files_fingerprint(root: Path, paths: tuple[str, ...]) -> str:
    records = []
    for relative in paths:
        parts = relative.split("/")
        if not relative or any(part in ("", ".", "..") for part in parts) or any(
            char in relative for char in "\t\r\n\\:"
        ):
            raise ToolError(f"指纹输入路径不合法：{relative!r}")
        path = root
        for part in parts:
            path = path / part
            info = path.stat(follow_symlinks=False)
            if path.is_symlink() or getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
                raise ToolError(f"指纹不接受符号链接或重解析点：{path}")
        if not stat.S_ISREG(info.st_mode):
            raise ToolError(f"指纹不支持此文件类型：{path}")
        try:
            records.append(f"{relative}\t{sha256_file(path)}\n".encode("utf-8"))
        except UnicodeError as exc:
            raise ToolError(f"文件名无法按 UTF-8 编码：{relative!r}") from exc
    return hashlib.sha256(b"".join(sorted(records))).hexdigest()


def tree_fingerprint(root: Path, excluded_dirs=(), excluded_suffixes=(), excluded_paths=()) -> str:
    return files_fingerprint(root, source_files(root, excluded_dirs, excluded_suffixes, excluded_paths))


def tooling_fingerprint(root: Path, platform: str) -> str:
    available = tuple("scripts/tooling/" + path for path in source_files(
        root / "scripts" / "tooling", excluded_dirs=("__pycache__",), excluded_suffixes=(".pyc", ".pyo")))
    return files_fingerprint(root, native_paths(platform, available))


def rust_fingerprint(root: Path) -> str:
    return tree_fingerprint(root, excluded_dirs=("target",),
                            excluded_paths=tuple(path.removeprefix("rust/") for path in RUST_DRIVERS))
