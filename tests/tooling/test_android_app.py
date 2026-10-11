"""APK 包内来源、失败阻断与设备安装行为；不依赖真实 SDK 或设备。"""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import warnings
import zipfile

from support import artifact, fixture, write
from tooling import android_app as app
from tooling.common import CommandError, ToolError
from tooling.toolchains import flutter_command


class AndroidAppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="APK 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        environment = patch.dict(os.environ, {"LEGADO_SKIP_RUST_BUILD": "0"})
        environment.start()
        self.addCleanup(environment.stop)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.library = artifact(self.root)[0]
        self.apk = self.root / "app-debug.apk"
        self.ndk = Mock()
        self.ndk.tool.return_value = Path("llvm-strip")

    def archive(self, entries):
        with warnings.catch_warnings(), zipfile.ZipFile(self.apk, "w") as archive:
            warnings.simplefilter("ignore", UserWarning)
            for name, content in entries:
                archive.writestr(name, content)

    def verify(self, strip=None):
        with patch.object(app, "discover_ndk", return_value=self.ndk), \
                patch.object(app, "run_command", side_effect=strip):
            app.verify_android_apk(self.root, self.apk, "debug", ("arm64-v8a",))

    def test_accepts_same_library_and_does_not_modify_inputs(self):
        content = self.library.read_bytes()
        self.archive([("lib/arm64-v8a/liblegado_ffi.so", content)])
        original_apk = self.apk.read_bytes()
        self.verify()
        self.assertEqual(self.library.read_bytes(), content)
        self.assertEqual(self.apk.read_bytes(), original_apk)

    def test_missing_duplicate_extra_abi_or_changed_library_rejected(self):
        member = "lib/arm64-v8a/liblegado_ffi.so"
        content = self.library.read_bytes()
        cases = ([], [(member, content), (member, content)],
                 [(member, content), ("lib/x86_64/liblegado_ffi.so", content)],
                 [(member, content + b"changed")])
        for entries in cases:
            with self.subTest(entries=entries):
                self.archive(entries)
                with self.assertRaises(ToolError):
                    self.verify()

    def test_allows_legal_strip_difference_using_temporary_copies(self):
        content = self.library.read_bytes()
        self.archive([("lib/arm64-v8a/liblegado_ffi.so", content + b"debug-symbols")])

        def strip(args, *unused, **kwargs):
            path = Path(args[-1])
            path.write_bytes(path.read_bytes().removesuffix(b"debug-symbols"))

        self.verify(strip)
        self.assertEqual(self.library.read_bytes(), content)

    def test_bad_zip_and_missing_metadata_fail(self):
        write(self.apk, b"not-a-zip")
        with self.assertRaisesRegex(ToolError, "无法读取 APK"):
            self.verify()
        self.library.with_suffix(".so.meta").unlink()
        with self.assertRaisesRegex(ToolError, "meta"):
            self.verify()

    def test_skip_rust_does_not_bypass_verification_or_start_flutter_on_failure(self):
        with patch.object(app, "discover_ndk", return_value=self.ndk), \
                patch.object(app, "flutter_command", return_value=(["flutter"], {})), \
                patch.object(app, "build_android_ffi") as build, \
                patch.object(app, "verify_android", side_effect=ToolError("陈旧库")), \
                patch.object(app, "run_command") as run:
            with self.assertRaisesRegex(ToolError, "陈旧库"):
                app.build_android_app(self.root, "debug", ("arm64-v8a",), skip_rust=True)
            build.assert_not_called()
            run.assert_not_called()

    def test_cargo_failure_does_not_package_old_apk(self):
        with patch.object(app, "discover_ndk", return_value=self.ndk), \
                patch.object(app, "flutter_command", return_value=(["flutter"], {})), \
                patch.object(app, "build_android_ffi", side_effect=CommandError("cargo", 7)), \
                patch.object(app, "run_command") as run:
            with self.assertRaises(CommandError) as failure:
                app.build_android_app(self.root, "debug", ("arm64-v8a",))
            self.assertEqual(failure.exception.code, 7)
            run.assert_not_called()

    def test_flutter_success_without_new_output_rejects_old_apk(self):
        old_apk = self.root / "flutter_legado" / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
        write(old_apk, b"old-apk")
        with patch.object(app, "discover_ndk", return_value=self.ndk), \
                patch.object(app, "flutter_command", return_value=(["flutter"], {})), \
                patch.object(app, "build_android_ffi", return_value=self.root / "rust" / "target"), \
                patch.object(app, "verify_android"), \
                patch.object(app, "run_command"):
            with self.assertRaisesRegex(ToolError, "APK 不存在"):
                app.build_android_app(self.root, "debug", ("arm64-v8a",))
            self.assertFalse(old_apk.exists())

    def test_install_requires_explicit_device_and_rejects_unused_device(self):
        for options in ({"install": True}, {"install": True, "device": "-d"}, {"device": "serial"}):
            with self.subTest(options=options), self.assertRaises(ToolError):
                app.build_android_app(self.root, "debug", ("arm64-v8a",), **options)

    def test_install_failure_does_not_launch_application(self):
        with patch.object(app, "find_adb", return_value=Path("adb")), \
                patch.object(app, "run_command", side_effect=["device\n", "Failure\n"]) as run:
            with self.assertRaisesRegex(ToolError, "安装成功"):
                app.install_android_apk(self.root, [self.apk], "serial", {})
            self.assertEqual(run.call_count, 2)

    def test_split_install_selects_device_abi(self):
        apks = [self.root / "app-arm64-v8a-release.apk", self.root / "app-x86_64-release.apk"]
        with patch.object(app, "find_adb", return_value=Path("adb")), \
                patch.object(app, "run_command", side_effect=["device\n", "x86_64\n", "Success\n", "Status: ok\n"]) as run:
            app.install_android_apk(self.root, apks, "serial", {})
            self.assertEqual(run.call_args_list[2].args[0][-1], apks[1])

    def test_windows_flutter_uses_sdk_native_dart_without_shell(self):
        sdk = self.root / "Flutter SDK"
        launcher = sdk / "bin" / "flutter.bat"
        dart = sdk / "bin" / "cache" / "dart-sdk" / "bin" / "dart.exe"
        snapshot = sdk / "bin" / "cache" / "flutter_tools.snapshot"
        packages = sdk / "packages" / "flutter_tools" / ".dart_tool" / "package_config.json"
        for path in (launcher, dart, snapshot, packages):
            write(path, b"fixture")
        with patch("tooling.toolchains.find_tool", return_value=launcher):
            command, env = flutter_command({"PATH": "fixture"})
        self.assertEqual(command, [str(dart), f"--packages={packages}", str(snapshot)])
        self.assertEqual(env["FLUTTER_ROOT"], str(sdk))


if __name__ == "__main__":
    unittest.main()
