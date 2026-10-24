"""发布输入与真实文件产物测试，不读取workflow源码作断言。"""

from pathlib import Path
import os
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import release_metadata as release


class ReleaseTests(unittest.TestCase):
    def test_tag_validation_and_shared_build_identity(self):
        stable = release.release_plan("2.0.439", 8, "refs/tags/v2.0.439")
        self.assertEqual((stable["channel"], stable["publish"], stable["build_number"]),
                         ("stable", "true", "10008"))
        alpha = release.release_plan("2.0.439", 9, "refs/heads/dev", publish=True)
        self.assertEqual(alpha["tag"], "v2.0.439-alpha.10009")
        self.assertEqual(release.release_plan("2.0.439", 10, "refs/heads/dev")["publish"], "false")
        manual_tag = release.release_plan("2.0.439", 11, "refs/tags/v2.0.439",
                                         event_name="workflow_dispatch")
        self.assertEqual((manual_tag["channel"], manual_tag["publish"]), ("alpha", "false"))
        for ref in ("refs/tags/v2.0.440", "refs/tags/v2.0.439-beta.1"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                release.release_plan("2.0.439", 11, ref)

    def test_staged_packages_share_version_and_preserve_contents(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apks = root / "release-apk"
            apks.mkdir()
            for abi in release.ANDROID_ABIS:
                (apks / f"app-{abi}-release.apk").write_bytes(abi.encode())
            destination = root / "release-dist"
            release.stage(root, "android", "2.0.439", "10009", destination)
            for abi in release.ANDROID_ABIS:
                self.assertEqual((destination / release.artifact_name(
                    "2.0.439", "10009", f"android-{abi}.apk")).read_bytes(), abi.encode())
            bundle = root / "flutter_legado/build/windows/x64/runner/Release"
            (bundle / "data/flutter_assets").mkdir(parents=True)
            (bundle / "flutter_legado.exe").write_bytes(b"exe")
            (bundle / "data/flutter_assets/example").write_bytes(b"asset")
            release.stage(root, "windows", "2.0.439", "10009", destination)
            with zipfile.ZipFile(destination / "OpenLegado-2.0.439+10009-windows-x64.zip") as archive:
                self.assertEqual(archive.read("data/flutter_assets/example"), b"asset")
                self.assertEqual(archive.read("flutter_legado.exe"), b"exe")

    def test_prepare_rejects_existing_tag_for_other_source_before_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "flutter_legado").mkdir()
            (root / "flutter_legado/pubspec.yaml").write_text("version: 2.0.439+440\n")
            output = root / "output"
            env = {"GITHUB_REF": "refs/tags/v2.0.439", "GITHUB_RUN_NUMBER": "9",
                   "GITHUB_EVENT_NAME": "push", "GITHUB_SHA": "current",
                   "GITHUB_OUTPUT": str(output)}
            with patch.object(release, "ROOT", root), patch.dict(os.environ, env), \
                    patch("sys.argv", ["release_metadata.py", "prepare"]), \
                    patch.object(release.subprocess, "check_output", return_value="old\trefs/tags/v2.0.439\n") as remote:
                with self.assertRaisesRegex(ValueError, "其他提交"):
                    release.main()
                self.assertFalse(output.exists())
                remote.return_value = "tag-object\trefs/tags/v2.0.439\ncurrent\trefs/tags/v2.0.439^{}\n"
                release.main()
            self.assertIn("build_number=10009\n", output.read_text())

    def test_missing_abi_cannot_produce_partial_android_stage(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "release-apk").mkdir()
            (root / "release-apk/app-arm64-v8a-release.apk").write_bytes(b"apk")
            destination = root / "release-dist"
            with self.assertRaises(ValueError):
                release.stage(root, "android", "2.0.439", "10009", destination)
            self.assertEqual(list(destination.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
