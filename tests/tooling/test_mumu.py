"""MuMu设备识别、构建委托、日志与启动结果验证。"""

from argparse import Namespace
import io
import json
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
        self.manager = self.root / "MuMu 中文 安装" / "nx_main" / "MuMuManager.exe"
        self.manager_lookup = patch.object(mumu, "find_mumu_manager", return_value=None)
        self.manager_lookup.start()
        self.addCleanup(self.manager_lookup.stop)
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

    def info(self, *ports):
        return json.dumps({str(index): {"is_process_started": True, "is_android_started": True,
                                       "adb_host_ip": "127.0.0.1", "adb_port": port}
                           for index, port in enumerate(ports)})

    def test_connects_running_instance_using_reported_endpoint_and_selected_adb(self):
        log = io.StringIO()
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", side_effect=[self.info(23167), "connected"]) as connect, \
                patch.object(mumu, "run_command", side_effect=["", "127.0.0.1:23167 device\n",
                                                              "mumu", "x86_64"]) as run:
            self.assertEqual(mumu.select_mumu_device(self.root, self.adb, {}, log=log), "127.0.0.1:23167")
        self.assertEqual(connect.call_args_list[0].args[0], [self.manager, "info", "-v", "all"])
        self.assertEqual(connect.call_args_list[1].args[0], [self.adb, "connect", "127.0.0.1:23167"])
        self.assertIn("自动连接MuMu：127.0.0.1:23167", log.getvalue())
        self.assertEqual(run.call_args_list[-1].args[0][2], "127.0.0.1:23167")

    def test_already_connected_instance_does_not_connect_again(self):
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", return_value=self.info(23167)) as connect, \
                patch.object(mumu, "run_command", side_effect=["127.0.0.1:23167 device\n", "mumu", "x86_64"]):
            self.assertEqual(mumu.select_mumu_device(self.root, self.adb, {}), "127.0.0.1:23167")
        self.assertEqual(connect.call_count, 1)

    def test_multiple_running_instances_require_selection_even_if_one_is_connected(self):
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", return_value=self.info(23167, 24599)) as connect, \
                patch.object(mumu, "run_command", return_value="127.0.0.1:23167 device\n"):
            with self.assertRaisesRegex(ToolError, "多个MuMu.*23167.*24599"):
                mumu.select_mumu_device(self.root, self.adb, {})
        self.assertEqual(connect.call_count, 1)

    def test_explicit_unconnected_running_instance_is_connected_without_touching_other(self):
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", side_effect=[self.info(23167, 24599), "connected"]) as connect, \
                patch.object(mumu, "run_command", side_effect=["127.0.0.1:23167 device\n",
                    "127.0.0.1:23167 device\n127.0.0.1:24599 device\n", "mumu", "x86_64"]):
            self.assertEqual(mumu.select_mumu_device(self.root, self.adb, {}, "127.0.0.1:24599"),
                             "127.0.0.1:24599")
        self.assertEqual(connect.call_args_list[-1].args[0], [self.adb, "connect", "127.0.0.1:24599"])

    def test_explicit_unknown_target_is_not_connected(self):
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", return_value=self.info(23167)) as connect, \
                patch.object(mumu, "run_command", return_value=""):
            with self.assertRaisesRegex(ToolError, "未在线"):
                mumu.select_mumu_device(self.root, self.adb, {}, "192.168.1.2:5555")
        self.assertEqual(connect.call_count, 1)

    def test_connection_must_become_online_and_pass_marker_and_abi(self):
        for replies, expected in ((["", "127.0.0.1:23167 offline\n"], "连接后仍未在线"),
                                  (["", "127.0.0.1:23167 device\n", ""], "标识检查"),
                                  (["", "127.0.0.1:23167 device\n", "mumu", "arm64-v8a"], "x86_64")):
            with self.subTest(expected=expected), \
                    patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                    patch.object(mumu, "_connection_command", side_effect=[self.info(23167), "failed to connect"]), \
                    patch.object(mumu, "run_command", side_effect=replies):
                with self.assertRaisesRegex(ToolError, expected):
                    mumu.select_mumu_device(self.root, self.adb, {})

    def test_connection_timeout_and_failure_include_target(self):
        command = [self.adb, "connect", "127.0.0.1:23167"]
        with patch.object(mumu.subprocess, "run", side_effect=mumu.subprocess.TimeoutExpired(command, 10)):
            with self.assertRaisesRegex(ToolError, "23167.*超过10秒"):
                mumu._connection_command(command, self.root, {})
        failed = mumu.subprocess.CompletedProcess(command, 1, "", "连接被拒绝")
        with patch.object(mumu.subprocess, "run", return_value=failed) as run:
            with self.assertRaisesRegex(ToolError, "23167.*连接被拒绝"):
                mumu._connection_command(command, self.root, {})
        self.assertEqual(run.call_args.args[0], [str(arg) for arg in command])
        self.assertEqual(run.call_args.kwargs["timeout"], 10)
        self.assertIs(run.call_args.kwargs["shell"], False)

    def test_running_info_ignores_stopped_and_starting_instances_and_deduplicates_endpoints(self):
        info = json.loads(self.info(23167, 23167, 24599, 25000))
        info["2"]["is_android_started"] = False
        info["3"]["is_process_started"] = False
        with patch.object(mumu, "_connection_command", return_value=json.dumps(info)):
            self.assertEqual(mumu.running_mumu_endpoints(self.root, self.manager, {}), ["127.0.0.1:23167"])

    def test_invalid_info_and_nonlocal_endpoints_are_rejected(self):
        replies = ["broken", "[]", '{"0": 1}']
        for host, port in (("192.168.1.2", 23167), ("localhost", 23167), ("127.0.0.1", True),
                           ("127.0.0.1", 0), ("127.0.0.1", 65536)):
            info = json.loads(self.info(23167))
            info["0"].update(adb_host_ip=host, adb_port=port)
            replies.append(json.dumps(info))
        for reply in replies:
            with self.subTest(reply=reply), patch.object(mumu, "_connection_command", return_value=reply):
                with self.assertRaises(ToolError):
                    mumu.running_mumu_endpoints(self.root, self.manager, {})

    def test_no_running_instance_does_not_attempt_connection(self):
        info = json.loads(self.info(23167))
        info["0"]["is_android_started"] = False
        with patch.object(mumu, "find_mumu_manager", return_value=self.manager), \
                patch.object(mumu, "_connection_command", return_value=json.dumps(info)) as connect, \
                patch.object(mumu, "run_command", return_value=""):
            with self.assertRaisesRegex(ToolError, "先启动模拟器"):
                mumu.select_mumu_device(self.root, self.adb, {})
        self.assertEqual(connect.call_count, 1)

    def test_manager_lookup_uses_path_then_registered_install_location(self):
        self.manager.parent.mkdir(parents=True)
        self.manager.touch()
        # 本用例直接调用原实现，其他用例不访问测试宿主的安装信息。
        self.manager_lookup.stop()
        with patch.object(mumu.shutil, "which", return_value=str(self.manager)), \
                patch.object(mumu, "_mumu_install_locations") as locations:
            self.assertEqual(mumu.find_mumu_manager({"PATH": "工具目录"}), self.manager)
        locations.assert_not_called()
        with patch.object(mumu.shutil, "which", return_value=None), \
                patch.object(mumu, "_mumu_install_locations", return_value=["", str(self.manager.parent.parent)]):
            self.assertEqual(mumu.find_mumu_manager({}), self.manager)

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
