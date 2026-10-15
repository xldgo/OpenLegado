"""固定当前 CI 已明确的 ABI、模式与 QuickJS 策略。"""

import argparse
import shlex
import unittest

from support import ROOT
from tooling.common import ToolError
from tooling.policy import load_policy, parse_abis, select_target


class MatrixTests(unittest.TestCase):
    def setUp(self):
        self.policy = load_policy(ROOT)

    def test_approved_matrix(self):
        expected = {
            "arm64-v8a": ("aarch64-linux-android", {"debug": ["quickjs"], "release": ["quickjs"]}),
            "x86_64": ("x86_64-linux-android", {"debug": ["quickjs"], "release": ["quickjs"]}),
            "armeabi-v7a": ("armv7-linux-androideabi", {"release": []}),
        }
        self.assertEqual(set(self.policy["targets"]), set(expected))
        self.assertEqual((self.policy["clangApiLevel"], self.policy["maxPageSize"]), (21, 16384))
        for abi, (triple, features) in expected.items():
            with self.subTest(abi=abi):
                self.assertEqual(self.policy["targets"][abi]["targetTriple"], triple)
                self.assertEqual(self.policy["targets"][abi]["features"], features)

    def test_armv7_debug_and_unknown_abi_profile_rejected(self):
        for abi, profile in (("armeabi-v7a", "debug"), ("unknown", "release"), ("arm64-v8a", "profile")):
            with self.subTest(abi=abi, profile=profile), self.assertRaises(ToolError):
                select_target(self.policy, abi, profile)

    def test_empty_duplicate_abis_rejected(self):
        for value in ("", ",", "arm64-v8a,", "arm64-v8a,arm64-v8a", "arm64-v8a,   "):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                parse_abis(value)
        self.assertEqual(parse_abis(" arm64-v8a, x86_64 "), ("arm64-v8a", "x86_64"))

    def test_ci_consumers_use_shared_build_and_keep_native_matrix(self):
        for workflow, profile, abis in (
            ("android-release.yml", "release", "arm64-v8a,armeabi-v7a,x86_64"),
            ("integration-smoke.yml", "debug", "arm64-v8a,x86_64"),
        ):
            text = (ROOT / ".github" / "workflows" / workflow).read_text(encoding="utf-8-sig")
            with self.subTest(workflow=workflow):
                self.assertIn(f'ndk;{self.policy["ndkVersion"]}', text)
                commands = [shlex.split(line.strip()[5:]) for line in text.splitlines()
                            if line.strip().startswith("run: python3 scripts/dev.py")]
                base = ["python3", "scripts/dev.py"]
                arguments = ["ffi", "android", "--profile", profile, "--abis", abis]
                self.assertIn([*base, "build", *arguments], commands)
                self.assertNotIn("source scripts/rust-fingerprint.sh", text)
                self.assertNotIn("bash scripts/verify-ffi-android.sh", text)

    def test_windows_smoke_uses_shared_build_and_keeps_runtime_test(self):
        text = (ROOT / ".github" / "workflows" / "integration-smoke.yml").read_text(encoding="utf-8-sig")
        self.assertIn("run: python scripts/dev.py build ffi windows --profile debug", text)
        self.assertIn("flutter test integration_test/ffi_smoke_test.dart -d windows", text)

    def test_android_release_uses_shared_apk_collection_and_keeps_publish_contract(self):
        text = (ROOT / ".github" / "workflows" / "android-release.yml").read_text(encoding="utf-8-sig")
        self.assertIn("python3 scripts/dev.py collect apk android --profile release "
                      "--abis arm64-v8a,armeabi-v7a,x86_64 --output-dir release-apk --cargo-target-dir rust/target "
                      '--signing-cert-sha256 "$ANDROID_SIGNING_CERT_SHA256"', " ".join(text.split()))
        self.assertNotIn("canonical_sha256", text)
        self.assertNotIn("NDK_TOOLCHAIN", text)
        self.assertIn("artifact_id: ${{ steps.upload-apk.outputs.artifact-id }}", text)
        self.assertIn("artifact-ids: ${{ needs.build.outputs.artifact_id }}", text)
        self.assertIn("files: release-apk/*-release.apk", text)
        self.assertIn("if: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v') }}", text)

    def test_ios_formal_workflows_use_shared_cli_and_preserve_flutter_host_modes(self):
        for name, target, directory, flutter_build in (
            ("ios-build.yml", "device", "iphoneos", "flutter build ios --release --no-codesign"),
            ("ios-ci.yml", "simulator", "iphonesimulator", "flutter build ios --simulator --debug"),
        ):
            text = (ROOT / ".github" / "workflows" / name).read_text(encoding="utf-8-sig")
            with self.subTest(workflow=name):
                self.assertIn(f"run: python3 scripts/dev.py build ffi ios --target {target} --profile release", text)
                self.assertIn(f"run: python3 scripts/dev.py verify app ios --target {target} --profile release "
                              f"--app flutter_legado/build/ios/{directory}/Runner.app --cargo-target-dir rust/target", text)
                self.assertIn(flutter_build, text)
                self.assertIn("pod install --repo-update", text)
                self.assertIn("DEVELOPER_DIR: /Applications/Xcode_26.6.app/Contents/Developer", text)
                self.assertNotIn("cargo rustc", text)
                self.assertNotIn("XCFramework", text)

    def test_ios_bundle_gates_precede_signing_and_keep_ipa_and_diagnostic_contracts(self):
        text = (ROOT / ".github" / "workflows" / "ios-build.yml").read_text(encoding="utf-8-sig")
        self.assertLess(text.index("prepare icons ios"), text.index("name: Prepare device signing materials"))
        self.assertLess(text.index("codesign -v --strict"), text.index("scripts/dev.py package ios"))
        self.assertIn("id: package", text)
        self.assertIn('if [ -n "$IOS_P12_BASE64" ]; then', text)
        for name in ("app-signed.ipa", "app-unsigned.ipa", "legado-ios-signed-ipa", "legado-ios-unsigned-ipa"):
            self.assertIn(name, text)
        self.assertIn('echo "artifact_name=$ARTIFACT_NAME" >> "$GITHUB_OUTPUT"', text)
        self.assertIn('echo "ipa_path=flutter_legado/build/ios/iphoneos/$IPA_NAME" >> "$GITHUB_OUTPUT"', text)
        self.assertIn("name: ${{ steps.package.outputs.artifact_name }}", text)
        self.assertIn("path: ${{ steps.package.outputs.ipa_path }}", text)
        self.assertIn("run: python3 scripts/dev.py export plist ios", text)
        self.assertEqual(text.count("if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.diagnostics }}"), 4)
        self.assertIn("contents: read", text)
        self.assertNotIn("contents: write", text)
        self.assertNotIn("import plistlib", text)


if __name__ == "__main__":
    unittest.main()
