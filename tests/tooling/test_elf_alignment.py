"""保护合并后仍拒绝 LOAD 或 RELRO 不满足 16 KB 的 Rust 库。"""

from pathlib import Path
import struct
import tempfile
import unittest

from support import ROOT, elf, write
from tooling.common import ToolError
from tooling.ffi_metadata import verify_elf
from tooling.policy import load_policy


class ElfAlignmentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.library = Path(self.temp.name) / "liblegado_ffi.so"
        self.targets = load_policy(ROOT)["targets"]

    def segment_fixture(self, target, index, field, value):
        data = bytearray(elf(target))
        is_64_bit = target["elfClass"] == 2
        header_size = 64 if is_64_bit else 52
        format = "<IIQQQQQQ" if is_64_bit else "<IIIIIIII"
        offset = header_size + index * struct.calcsize(format)
        values = list(struct.unpack_from(format, data, offset))
        values[field] = value
        struct.pack_into(format, data, offset, *values)
        return data

    def test_each_android_abi_accepts_aligned_load_and_relro(self):
        for abi, target in self.targets.items():
            with self.subTest(abi=abi):
                write(self.library, elf(target))
                verify_elf(self.library, target)

    def test_rejects_small_or_non_power_of_two_load_alignment(self):
        for abi, target in self.targets.items():
            for alignment in (4096, 24576):
                with self.subTest(abi=abi, alignment=alignment):
                    write(self.library, self.segment_fixture(target, 0, 7, alignment))
                    with self.assertRaisesRegex(ToolError, "LOAD"):
                        verify_elf(self.library, target)

    def test_aligned_load_does_not_hide_unaligned_relro(self):
        for abi, target in self.targets.items():
            memory_size_index = 6 if target["elfClass"] == 2 else 5
            with self.subTest(abi=abi):
                write(self.library, self.segment_fixture(target, 1, memory_size_index, 12287))
                with self.assertRaisesRegex(ToolError, "RELRO"):
                    verify_elf(self.library, target)

    def test_rejects_truncated_program_table_and_missing_load(self):
        for abi, target in self.targets.items():
            header_size = 64 if target["elfClass"] == 2 else 52
            cases = (elf(target)[:header_size], self.segment_fixture(target, 0, 0, 0))
            for index, data in enumerate(cases):
                with self.subTest(abi=abi, case=index):
                    write(self.library, data)
                    with self.assertRaisesRegex(ToolError, "程序头|LOAD"):
                        verify_elf(self.library, target)

    def test_rejects_inconsistent_load_offset_and_invalid_memory_size(self):
        for abi, target in self.targets.items():
            is_64_bit = target["elfClass"] == 2
            fields = (2 if is_64_bit else 1, 6 if is_64_bit else 5)
            for field in fields:
                with self.subTest(abi=abi, field=field):
                    write(self.library, self.segment_fixture(target, 0, field, 1))
                    with self.assertRaisesRegex(ToolError, "LOAD"):
                        verify_elf(self.library, target)


if __name__ == "__main__":
    unittest.main()
