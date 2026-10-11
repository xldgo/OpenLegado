"""保护旧指纹格式、文件集合和跨系统字节语义。"""

import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from support import write
from tooling.common import ToolError
from tooling.fingerprint import rust_fingerprint


class FingerprintTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="指纹 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_known_utf8_fixture_and_creation_order(self):
        # 预先计算的常量固定协议，防止测试与实现一起改变排序或换行。
        files = [("src/中文.rs", b"utf8\r\n"), ("Cargo.toml", b"cargo\n"),
                 ("src/space name.rs", b"space\n"), ("assets/raw.bin", bytes(range(8)))]
        for path, content in files:
            write(self.root / path, content)
        self.assertEqual(rust_fingerprint(self.root),
                         "204c176e55fa69798024c6191b6ab70dab76164bfd113e7867d9fb09120827a1")
        # 不在文件系统枚举结果上依赖创建顺序。
        for path, _ in files:
            (self.root / path).unlink()
        for path, content in reversed(files):
            write(self.root / path, content)
        self.assertEqual(rust_fingerprint(self.root), "204c176e55fa69798024c6191b6ab70dab76164bfd113e7867d9fb09120827a1")

    def test_empty_tree(self):
        self.assertEqual(rust_fingerprint(self.root), hashlib.sha256(b"").hexdigest())

    def test_nested_target_excluded_but_similar_names_included(self):
        write(self.root / "src" / "lib.rs", "源码\n")
        original = rust_fingerprint(self.root)
        write(self.root / "target" / "out.bin", b"ignored")
        write(self.root / "crate" / "target" / "out.bin", b"ignored")
        self.assertEqual(rust_fingerprint(self.root), original)
        write(self.root / "targeted" / "input.bin", b"included")
        self.assertNotEqual(rust_fingerprint(self.root), original)

    def test_content_path_and_line_endings_matter(self):
        path = self.root / "source.rs"
        write(path, b"line\n")
        lf = rust_fingerprint(self.root)
        write(path, b"line\r\n")
        crlf = rust_fingerprint(self.root)
        self.assertNotEqual(crlf, lf)
        path.rename(self.root / "renamed.rs")
        self.assertNotEqual(rust_fingerprint(self.root), crlf)

    def test_utf8_byte_order_includes_supplementary_characters(self):
        files = {"\ue000.rs": b"a", "\U00010000.rs": b"b"}
        for name, content in files.items():
            write(self.root / name, content)
        expected = b"".join(f"{name}\t{hashlib.sha256(files[name]).hexdigest()}\n".encode()
                            for name in sorted(files, key=lambda name: name.encode("utf-8")))
        self.assertEqual(rust_fingerprint(self.root), hashlib.sha256(expected).hexdigest())

    def test_symbolic_links_rejected_without_following(self):
        write(self.root / "real.rs", "真实文件")
        try:
            (self.root / "link.rs").symlink_to(self.root / "real.rs")
            (self.root / "loop").symlink_to(self.root, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"宿主不允许创建符号链接：{exc}")
        with self.assertRaisesRegex(ToolError, "符号链接"):
            rust_fingerprint(self.root)

    def test_io_failure_is_not_silently_ignored(self):
        write(self.root / "source.rs", "源码")
        with patch("tooling.fingerprint.sha256_file", side_effect=PermissionError("不可读")):
            with self.assertRaises(PermissionError):
                rust_fingerprint(self.root)

    def test_missing_directory(self):
        with self.assertRaisesRegex(ToolError, "不存在"):
            rust_fingerprint(self.root / "missing")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "宿主不支持 FIFO")
    def test_nonregular_file_rejected_without_reading(self):
        os.mkfifo(self.root / "pipe")
        with self.assertRaisesRegex(ToolError, "文件类型"):
            rust_fingerprint(self.root)

    @unittest.skipIf(os.name == "nt", "Windows 文件名不允许这些分隔字符")
    def test_ambiguous_path_separators_rejected(self):
        for name in ("tab\tname.rs", "line\nname.rs", "back\\slash.rs"):
            path = self.root / name
            write(path, b"input")
            with self.subTest(name=name), self.assertRaisesRegex(ToolError, "文件名"):
                rust_fingerprint(self.root)
            path.unlink()


if __name__ == "__main__":
    unittest.main()
