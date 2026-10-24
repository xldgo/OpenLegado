"""Windows 来源校验和失败阻断；PE fixture 不代表真实编译或运行验收。"""

import json
import os
from pathlib import Path
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch

from support import fixture, write
from tooling.common import CommandError, ToolError
from tooling import windows as win
from tooling import windows_app as app


def pe(payload=b"fixture"):
    header = bytearray(90)
    header[:2] = b"MZ"
    struct.pack_into("<I", header, 60, 64)
    header[64:68] = b"PE\0\0"
    struct.pack_into("<H", header, 68, 0x8664)
    struct.pack_into("<H", header, 86, 0x2000)
    struct.pack_into("<H", header, 88, 0x20B)
    return bytes(header) + payload


class WindowsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Windows 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.calls = []
        self.fail = False
        self.omit = False
        for replacement in (
            patch.object(win.sys, "platform", "win32"),
            patch.dict(os.environ, {"CARGO_TARGET_DIR": str(self.root / "rust" / "target")}),
            patch.object(win, "find_tool", side_effect=lambda name, env: self.root / name),
            patch.object(win, "run_command", side_effect=self.execute),
            patch.object(app, "run_command", side_effect=self.execute),
        ):
            replacement.start()
            self.addCleanup(replacement.stop)

    def execute(self, args, cwd, env, capture=False):
        args = [str(value) for value in args]
        self.calls.append((args, env.copy()))
        if args[1:] == ["-Vv"]:
            return f"rustc fixture\nhost: {win.TARGET}\n"
        if args[1:] == ["-V"]:
            return "cargo fixture\n"
        if args[1] == "clean":
            return ""
        if args[1] == "build" and "--target-dir" in args:
            if self.fail:
                raise CommandError("cargo", 9)
            profile = "release" if "--release" in args else "debug"
            source = Path(args[args.index("--target-dir") + 1]) / win.TARGET / profile / "legado_ffi.dll"
            write(source, pe(b"current"))
            return json.dumps({"reason": "compiler-artifact", "target": {"name": "legado_ffi"},
                               "filenames": [] if self.omit else [str(source)]}) + "\n"
        profile = "release" if "--release" in args else "debug"
        bundle = app.bundle_directory(self.root, profile)
        write(bundle / "flutter_legado.exe", b"new-executable")
        shutil.copyfile(Path(env["LEGADO_RUST_FFI_DIR"]) / profile / "legado_ffi.dll", bundle / "legado_ffi.dll")
        return ""

    def test_build_publishes_current_source_and_strict_metadata(self):
        library = win.build_windows_ffi(self.root, "debug")
        self.assertEqual(win.verify_windows_ffi(self.root, "debug"), library)
        args = next(args for args, _ in self.calls if "--target-dir" in args)
        self.assertIn("--locked", args)
        self.assertEqual(args[args.index("--features") + 1], "quickjs")
        self.assertEqual(args[args.index("--target") + 1], win.TARGET)

    def test_stale_source_changes_reject_library_without_api_change(self):
        win.build_windows_ffi(self.root, "debug")
        write(self.root / "rust" / "legado-ffi" / "src" / "business.rs", "业务变化\n")
        with self.assertRaises(ToolError):
            win.verify_windows_ffi(self.root, "debug")

    def test_metadata_missing_source_missing_or_dll_changed_rejected(self):
        for problem in ("meta", "source", "binary"):
            library = win.build_windows_ffi(self.root, "debug")
            if problem == "meta":
                library.with_suffix(".dll.meta").unlink()
            elif problem == "source":
                (library.parents[1] / win.TARGET / "debug" / library.name).unlink()
            else:
                library.write_bytes(library.read_bytes() + b"changed")
            with self.subTest(problem=problem), self.assertRaises(ToolError):
                win.verify_windows_ffi(self.root, "debug")

    def test_cargo_failure_keeps_old_files_and_does_not_retry_without_quickjs(self):
        library = win.build_windows_ffi(self.root, "debug")
        before = (library.read_bytes(), library.with_suffix(".dll.meta").read_bytes())
        self.calls.clear()
        self.fail = True
        with self.assertRaises(CommandError) as failure:
            win.build_windows_ffi(self.root, "debug")
        self.assertEqual(failure.exception.code, 9)
        self.assertEqual(sum("--target-dir" in args for args, _ in self.calls), 1)
        self.assertEqual((library.read_bytes(), library.with_suffix(".dll.meta").read_bytes()), before)

    def test_missing_cargo_artifact_message_does_not_accept_old_dll(self):
        win.build_windows_ffi(self.root, "debug")
        self.omit = True
        with self.assertRaisesRegex(ToolError, "Cargo 未确认"):
            win.build_windows_ffi(self.root, "debug")

    def test_explicit_stub_is_debug_only_and_not_accepted_as_quickjs(self):
        win.build_windows_ffi(self.root, "debug", quickjs=False)
        win.verify_windows_ffi(self.root, "debug", quickjs=False)
        with self.assertRaises(ToolError):
            win.verify_windows_ffi(self.root, "debug")
        with self.assertRaisesRegex(ToolError, "Release"):
            win.build_windows_ffi(self.root, "release", quickjs=False)

    def test_nonwindows_build_rejected_before_tools_are_invoked(self):
        with patch.object(win.sys, "platform", "linux"), self.assertRaisesRegex(ToolError, "Windows 宿主"):
            win.build_windows_ffi(self.root, "debug")
        self.assertEqual(self.calls, [])

    def test_invalid_pe_architecture_rejected(self):
        path = self.root / "wrong.dll"
        content = bytearray(pe())
        struct.pack_into("<H", content, 68, 0x14C)
        write(path, content)
        with self.assertRaisesRegex(ToolError, "x64"):
            win.verify_pe(path)

    def test_locked_dll_gives_manual_close_hint_without_killing_processes(self):
        with patch.object(win.os, "replace", side_effect=PermissionError("locked")):
            with self.assertRaisesRegex(ToolError, "手动关闭应用"):
                win.build_windows_ffi(self.root, "debug")

    def test_app_build_copies_requested_release_dll(self):
        with patch.object(app, "flutter_command", return_value=(["flutter"], {})):
            executable = app.build_windows_app(
                self.root, "release", build_name="2.0.439", build_number="10009",
                dart_defines=("OPENLEGADO_CHANNEL=alpha", "OPENLEGADO_COMMIT=abc123"))
        self.assertTrue(executable.is_file())
        source = win.verify_windows_ffi(self.root, "release")
        self.assertEqual(source.read_bytes(), (executable.parent / source.name).read_bytes())
        command, env = self.calls[-1]
        self.assertEqual(command, ["flutter", "build", "windows", "--release",
                                   "--build-name", "2.0.439", "--build-number", "10009",
                                   "--dart-define=OPENLEGADO_CHANNEL=alpha",
                                   "--dart-define=OPENLEGADO_COMMIT=abc123"])
        self.assertEqual(env["LEGADO_RUST_FFI_DIR"], str(source.parent.parent))

    def test_run_builds_via_flutter_run_once_without_preceding_flutter_build(self):
        with patch.object(app, "flutter_command", return_value=(["flutter"], {})):
            app.build_windows_app(self.root, "debug", run=True)
        commands = [args for args, _ in self.calls if args[0] == "flutter"]
        self.assertEqual(commands, [["flutter", "run", "-d", "windows", "--debug"]])


if __name__ == "__main__":
    unittest.main()
