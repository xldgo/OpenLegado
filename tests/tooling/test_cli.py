"""真实子进程覆盖命令入口、退出码、任意工作目录与只读边界。"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from support import artifact, fixture, write
from tooling.fingerprint import rust_fingerprint


class CliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="CLI 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.cwd = self.root / "unrelated directory"
        self.cwd.mkdir()

    def run_cli(self, *args):
        env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
        return subprocess.run([sys.executable, str(self.root / "scripts" / "dev.py"), *args],
                              cwd=self.cwd, env=env, text=True, encoding="utf-8",
                              capture_output=True, timeout=30)

    def test_fingerprint_from_other_working_directory(self):
        result = self.run_cli("fingerprint", "rust")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, rust_fingerprint(self.root / "rust") + "\n")
        self.assertEqual(result.stderr, "")
        self.assertFalse(list(self.root.rglob("__pycache__")))

    def test_valid_verify_and_explicit_source_directory_with_spaces(self):
        cargo = self.root / "Cargo outputs"
        artifact(self.root, cargo_dir=cargo)
        result = self.run_cli("verify", "ffi", "android", "--profile", "debug", "--abis", "arm64-v8a",
                              "--cargo-target-dir", str(cargo))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("源库摘要已核对", result.stdout)
        self.assertFalse(list(self.root.rglob("__pycache__")))

    def test_android_cli_does_not_import_unrelated_platform_modules(self):
        artifact(self.root)
        for name in ("ios.py", "ios_bundle.py", "windows.py", "windows_app.py"):
            write(self.root / "scripts" / "tooling" / name, "raise RuntimeError('不得导入其他平台')\n")
        result = self.run_cli("verify", "ffi", "android", "--profile", "debug", "--abis", "arm64-v8a")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("校验通过", result.stdout)

    def test_cli_uses_utf8_when_parent_encoding_is_cp1252(self):
        artifact(self.root)
        env = {**os.environ, "PYTHONIOENCODING": "cp1252"}
        result = subprocess.run([sys.executable, str(self.root / "scripts" / "dev.py"),
                                 "verify", "ffi", "android", "--profile", "debug", "--abis", "arm64-v8a"],
                                cwd=self.cwd, env=env, text=True, encoding="utf-8", capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("校验通过", result.stdout)
        self.assertEqual(result.stderr, "")

    def test_validation_failure_exit_1_without_creating_metadata(self):
        artifact(self.root)[1].unlink()
        result = self.run_cli("verify", "ffi", "android", "--profile", "debug", "--abis", "arm64-v8a")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn(".so.meta", result.stderr)
        self.assertFalse(list(self.root.rglob("*.meta")))

    def test_actions_failure_keeps_diagnostic_annotation(self):
        env = {**os.environ, "GITHUB_ACTIONS": "true", "PYTHONIOENCODING": "utf-8"}
        result = subprocess.run([sys.executable, str(self.root / "scripts" / "dev.py"),
                                 "verify", "ffi", "android", "--profile", "debug", "--abis", "unknown"],
                                cwd=self.cwd, env=env, text=True, encoding="utf-8", capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::未知 Android ABI", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_bad_arguments_exit_2_and_unsupported_target_exit_1(self):
        for args in (("verify", "ffi", "android"),
                     ("verify", "ffi", "android", "--profile", "profile", "--abis", "arm64-v8a"),
                     ("verify", "ffi", "android", "--profile", "debug", "--abis", "arm64-v8a,"),
                     ("verify", "ffi", "android", "--profile", "debug", "--abis", "x86_64,x86_64"),
                     ("build", "ffi", "ios")):
            with self.subTest(args=args):
                self.assertEqual(self.run_cli(*args).returncode, 2)
        for abi in ("unknown", "armeabi-v7a"):
            result = self.run_cli("verify", "ffi", "android", "--profile", "debug", "--abis", abi)
            self.assertEqual(result.returncode, 1)
            self.assertIn(abi, result.stderr)

    def test_ios_rejects_incomplete_unknown_or_debug_formal_target_arguments(self):
        for args in (("build", "ffi", "ios", "--target", "device"),
                     ("build", "ffi", "ios", "--target", "intel", "--profile", "release"),
                     ("build", "ffi", "ios", "--target", "device", "--profile", "debug"),
                     ("verify", "app", "ios", "--target", "simulator", "--profile", "release")):
            with self.subTest(args=args):
                self.assertEqual(self.run_cli(*args).returncode, 2)

    def test_mumu_shortcut_defaults_and_rejects_conflicting_options(self):
        write(self.root / "scripts/tooling/mumu.py",
              "def build_mumu_app(root, args):\n"
              "    print(args.profile, args.skip_rust, args.device)\n"
              "    return 0\n")
        result = self.run_cli("build", "android", "--emulator", "mumu", "--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "debug False None\n")
        result = self.run_cli("build", "android", "--emulator", "mumu", "--install",
                              "--skip-rust", "--device", "local:99")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "debug True local:99\n")
        for extra in ([], ["--install", "--abis", "arm64-v8a"], ["--install", "--emulator", "other"]):
            with self.subTest(extra=extra):
                self.assertEqual(self.run_cli("build", "android", "--emulator", "mumu", *extra).returncode, 2)
        self.assertEqual(self.run_cli("build", "android", "--install").returncode, 2)

    def test_no_tests_is_not_reported_as_success(self):
        result = self.run_cli("test", "tooling")
        self.assertEqual(result.returncode, 1)
        self.assertIn("测试目录不存在", result.stderr)
        self.assertNotIn("OK", result.stderr)

    def test_collect_requires_output_and_rejects_unknown_or_duplicate_abis(self):
        for args in (("--profile", "release", "--abis", "arm64-v8a"),
                     ("--profile", "release", "--abis", "arm64-v8a,arm64-v8a", "--output-dir", "out")):
            with self.subTest(args=args):
                self.assertEqual(self.run_cli("collect", "apk", "android", *args).returncode, 2)
        result = self.run_cli("collect", "apk", "android", "--profile", "release", "--abis", "unknown",
                              "--output-dir", str(self.root / "release-apk"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("未知 Android ABI", result.stderr)
        self.assertFalse((self.root / "release-apk").exists())

    def test_ios_bundle_commands_require_explicit_paths_and_one_icon_input(self):
        for args in (("verify", "icons", "ios"),
                     ("verify", "icons", "ios", "--assets", "assets", "--app", "app"),
                     ("verify", "ipa", "ios"),
                     ("prepare", "icons", "ios", "--assets", "assets"),
                     ("package", "ios", "--app", "app"),
                     ("export", "plist", "ios", "--app", "app")):
            with self.subTest(args=args):
                self.assertEqual(self.run_cli(*args).returncode, 2)

    def test_readonly_icon_log_check_from_other_directory_does_not_create_outputs(self):
        result = self.run_cli("verify", "icons", "ios", "--build-log", str(self.root / "missing.log"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("无法读取", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "flutter_legado" / "build").exists())


if __name__ == "__main__":
    unittest.main()
