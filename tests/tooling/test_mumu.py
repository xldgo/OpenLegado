"""MuMu设备识别、构建委托、日志与启动结果验证。"""

from argparse import Namespace
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import support
from tooling import mumu
from tooling.common import CommandError, ToolError


class MumuTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="MuMu 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.adb = self.root / "Android SDK" / "adb.exe"
        self.args = Namespace(profile="debug", device=None, adb=None, ndk=None,
                              cargo_target_dir=None, skip_rust=False, clean=False)

    def test_selects_mumu_and_ignores_offline_or_other_devices(self):
        listing = "List of devices attached\nusb device\nold offline\nlocal:99 device\nbad unauthorized\n"
        with patch.object(mumu, "run_command", side_effect=[listing, "", "mumu\n", "x86_64\n"]) as run:
            self.assertEqual(mumu.select_mumu_device(self.root, self.adb, {}), "local:99")
        self.assertEqual(run.call_args_list[2].args[0][2], "local:99")
        self.assertEqual(run.call_args_list[3].args[0][2], "local:99")

    def test_multiple_mumu_requires_explicit_device(self):
        listing = "a device\nb device\n"
        with patch.object(mumu, "run_command", side_effect=[listing, "mumu", "mumu"]):
            with self.assertRaisesRegex(ToolError, "多个MuMu"):
                mumu.select_mumu_device(self.root, self.adb, {})
        with patch.object(mumu, "run_command", side_effect=[listing, "mumu", "x86_64"]) as run:
            self.assertEqual(mumu.select_mumu_device(self.root, self.adb, {}, "b"), "b")
            self.assertEqual(run.call_args_list[1].args[0][2], "b")

    def test_rejects_missing_non_mumu_and_wrong_abi(self):
        for replies, explicit, expected in (([""], None, "未找到"),
                                            (["a offline\n"], "a", "未在线"),
                                            (["a device\n", ""], "a", "未找到"),
                                            (["a device\n", "mumu", "arm64-v8a"], None, "x86_64")):
            with self.subTest(replies=replies), patch.object(mumu, "run_command", side_effect=replies):
                with self.assertRaisesRegex(ToolError, expected):
                    mumu.select_mumu_device(self.root, self.adb, {}, explicit)

    def build(self, code=0, startup="device ready", args=None, invalid_library=False):
        with patch.object(mumu, "find_adb", return_value=self.adb), \
                patch.object(mumu, "select_mumu_device", return_value="local:99"), \
                patch.object(mumu, "run_logged_build", return_value=code) as build, \
                patch.object(mumu, "verify_android", side_effect=ToolError("旧库") if invalid_library else None), \
                patch.object(mumu.time, "sleep"), \
                patch.object(mumu, "run_command", side_effect=["321\n", startup]) as run:
            result = mumu.build_mumu_app(self.root, args or self.args)
        return result, build, run

    def test_default_reuses_verified_library_through_existing_pipeline(self):
        code, build, run = self.build()
        self.assertEqual(code, 0)
        command = build.call_args.args[0]
        self.assertEqual(command[:6], [sys.executable, "-u", str(self.root / "scripts/dev.py"),
                                      "build", "android", "--profile"])
        self.assertEqual(command[6:], ["debug", "--abis", "x86_64", "--split-per-abi", "--install",
                                      "--device", "local:99", "--adb", str(self.adb), "--skip-rust"])
        self.assertEqual(run.call_args_list[1].args[0][-1], "--pid=321")
        self.assertIn("device ready", (self.root / "build/mumu/build-install.log").read_text(encoding="utf-8"))

    def test_forwards_explicit_build_options_and_resolves_paths(self):
        self.args.skip_rust = self.args.clean = True
        self.args.ndk = Path("SDK NDK")
        self.args.cargo_target_dir = Path("Cargo 输出")
        _, build, _ = self.build()
        command = build.call_args.args[0]
        self.assertIn(str(self.args.ndk.resolve()), command)
        self.assertIn(str(self.args.cargo_target_dir.resolve()), command)
        self.assertEqual(command[-2:], ["--skip-rust", "--clean"])

    def test_invalid_library_automatically_rebuilds_without_skip(self):
        result, build, _ = self.build(invalid_library=True)
        self.assertEqual(result, 0)
        self.assertNotIn("--skip-rust", build.call_args.args[0])
        self.assertIn("将重新编译", (self.root / "build/mumu/build-install.log").read_text(encoding="utf-8"))

    def test_failed_build_keeps_exit_code_and_does_not_check_startup(self):
        result, _, run = self.build(code=7, invalid_library=True)
        self.assertEqual(result, 7)
        run.assert_not_called()

    def test_startup_crash_or_missing_process_fails_and_logs_reason(self):
        with self.assertRaisesRegex(ToolError, "未处理异常"):
            self.build(startup="FATAL EXCEPTION: main")
        with patch.object(mumu, "find_adb", return_value=self.adb), \
                patch.object(mumu, "select_mumu_device", return_value="local:99"), \
                patch.object(mumu, "run_logged_build", return_value=0), \
                patch.object(mumu, "verify_android"), \
                patch.object(mumu.time, "sleep"), \
                patch.object(mumu, "run_command", side_effect=CommandError("adb", 1)):
            with self.assertRaises(CommandError):
                mumu.build_mumu_app(self.root, self.args)
        self.assertIn("失败：", (self.root / "build/mumu/build-install.log").read_text(encoding="utf-8"))

    def test_real_child_output_and_exit_code_are_logged_and_previous_log_is_replaced(self):
        path = self.root / "build.log"
        path.write_text("旧日志", encoding="utf-8")
        with path.open("w", encoding="utf-8") as log:
            code = mumu.run_logged_build([sys.executable, "-u", "-c",
                "import sys; print('构建输出'); print('构建错误', file=sys.stderr); sys.exit(7)"],
                self.root, {**os.environ, "PYTHONIOENCODING": "utf-8"}, log)
        self.assertEqual(code, 7)
        self.assertEqual(path.read_text(encoding="utf-8"), "构建输出\n构建错误\n")
