"""验证实际原生输入摘要的跨平台隔离、打包隔离与未知输入回退。"""

import tempfile
import unittest

from pathlib import Path
from support import fixture, write
from tooling.contracts import bridge_contract
from tooling.fingerprint import rust_fingerprint, tooling_fingerprint
from tooling.ios import ios_inputs
from tooling.policy import build_inputs_sha256, load_policy
from tooling.windows import windows_inputs


class InputScopeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="平台输入 中文 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        native = self.root / "flutter_legado" / "ios"
        write(native / "Podfile", "platform :ios, '15.0'\n")
        write(native / "RustFFI" / "RustFFI.podspec", "s.ios.deployment_target = '15.0'\n")
        write(native / "Runner.xcodeproj" / "project.pbxproj", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;\n")

    def inputs(self):
        contract = bridge_contract(self.root)
        return {
            "android": build_inputs_sha256(self.root, load_policy(self.root), "arm64-v8a", "debug",
                                            rust_fingerprint(self.root / "rust"), contract.content_hash, contract.version),
            "windows": windows_inputs(self.root, "debug", True)["buildInputsSha256"],
            "ios": ios_inputs(self.root, "device", "release")["buildInputsSha256"],
        }

    def change(self, path):
        target = self.root / path
        write(target, target.read_bytes() + b"\n# changed\n" if target.is_file() else b"new input\n")

    def test_platform_builder_changes_only_its_own_native_inputs(self):
        for platform, path in (
            ("android", "scripts/tooling/android.py"),
            ("android", "scripts/tooling/android_toolchain.py"),
            ("windows", "scripts/tooling/windows.py"),
            ("ios", "scripts/tooling/ios.py"),
        ):
            before = self.inputs()
            self.change(path)
            after = self.inputs()
            with self.subTest(path=path):
                self.assertEqual({name for name in before if before[name] != after[name]}, {platform})

    def test_packaging_codegen_cli_and_test_changes_do_not_invalidate_native_libraries(self):
        before = self.inputs()
        for path in ("scripts/tooling/android_app.py", "scripts/tooling/mumu.py", "scripts/tooling/windows_app.py",
                     "scripts/tooling/ios_bundle.py", "scripts/tooling/bridge.py", "scripts/dev.py",
                     "tests/tooling/new_test.py"):
            self.change(path)
            with self.subTest(path=path):
                self.assertEqual(self.inputs(), before)

    def test_shared_and_unclassified_tool_changes_invalidate_all_platforms(self):
        for path in ("scripts/tooling/common.py", "scripts/tooling/contracts.py",
                     "scripts/tooling/new_builder.py", "scripts/tooling/new_data.json"):
            before = self.inputs()
            self.change(path)
            after = self.inputs()
            with self.subTest(path=path):
                self.assertTrue(all(before[name] != after[name] for name in before))

    def test_known_host_scripts_are_excluded_but_unknown_rust_inputs_and_assets_remain(self):
        before = self.inputs()
        for path in ("rust/scripts/build-ios.sh", "rust/scripts/gen_rar5_fixture.py"):
            self.change(path)
            self.assertEqual(self.inputs(), before)
        for path in ("rust/scripts/new_input.sh", "rust/legado-server/assets/web/help.md",
                     "rust/Cargo.lock", "rust/legado-db/build.rs"):
            before = self.inputs()
            self.change(path)
            after = self.inputs()
            with self.subTest(path=path):
                self.assertTrue(all(before[name] != after[name] for name in before))

    def test_missing_platform_input_blocks_only_that_platform(self):
        self.root.joinpath("scripts/tooling/android.py").unlink()
        with self.assertRaises(FileNotFoundError):
            tooling_fingerprint(self.root, "android")
        for platform in ("windows", "ios"):
            self.assertEqual(len(tooling_fingerprint(self.root, platform)), 64)


if __name__ == "__main__":
    unittest.main()
