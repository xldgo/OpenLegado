"""分 ABI APK 收集与失败阻断；合成 ZIP/ELF 不构成真实 Release 验收。"""

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile

from support import artifact, fixture, write
from tooling import android_app as app
from tooling.common import ToolError, sha256_file
from tooling.policy import load_policy, select_target


ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")


class AndroidCollectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="收集 APK 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.cargo = self.root / "rust" / "target"
        self.input = self.root / "flutter_legado" / "build" / "app" / "outputs" / "flutter-apk"
        self.output = self.root / "release-apk"
        self.policy = load_policy(self.root)
        self.apks = []
        for abi in ABIS:
            library, meta_path, meta = artifact(self.root, abi, "release", self.cargo)
            source = self.cargo / select_target(self.policy, abi, "release")["targetTriple"] / "release" / library.name
            write(source, library.read_bytes())
            meta["sourceSha256"] = sha256_file(source)
            write(meta_path, json.dumps(meta))
            apk = self.input / f"app-{abi}-release.apk"
            apk.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr(f"lib/{abi}/liblegado_ffi.so", library.read_bytes())
            self.apks.append(apk)
        ndk = Mock()
        ndk.tool.return_value = Path("llvm-strip")
        for replacement in (
            patch.dict(os.environ, {"CARGO_TARGET_DIR": str(self.cargo)}),
            patch.object(app, "discover_ndk", return_value=ndk),
            patch.object(app, "run_command"),
        ):
            replacement.start()
            self.addCleanup(replacement.stop)

    def collect(self):
        return app.collect_android_apks(self.root, "release", ABIS, self.output)

    def test_all_three_apks_collected_with_original_names_and_identical_bytes(self):
        before = [apk.read_bytes() for apk in self.apks]
        outputs = self.collect()
        self.assertEqual([apk.name for apk in outputs], [apk.name for apk in self.apks])
        self.assertEqual([apk.read_bytes() for apk in outputs], before)
        self.assertEqual([apk.read_bytes() for apk in self.apks], before)
        self.assertEqual(set(self.output.iterdir()), set(outputs))

    def test_missing_last_abi_apk_does_not_publish_partial_output(self):
        self.apks[-1].unlink()
        with self.assertRaisesRegex(ToolError, "APK 不存在"):
            self.collect()
        self.assertFalse(self.output.exists())

    def test_wrong_abi_in_last_apk_does_not_modify_previous_output(self):
        self.collect()
        before = {path.name: path.read_bytes() for path in self.output.iterdir()}
        with zipfile.ZipFile(self.apks[-1], "w") as archive:
            archive.writestr("lib/arm64-v8a/liblegado_ffi.so", b"wrong-library")
        with self.assertRaisesRegex(ToolError, "ABI"):
            self.collect()
        self.assertEqual({path.name: path.read_bytes() for path in self.output.iterdir()}, before)

    def test_missing_cargo_source_is_not_accepted_despite_valid_apk_and_jni(self):
        source = self.cargo / select_target(self.policy, ABIS[-1], "release")["targetTriple"] / "release" / "liblegado_ffi.so"
        source.unlink()
        with self.assertRaisesRegex(ToolError, "Cargo 源库"):
            self.collect()
        self.assertFalse(self.output.exists())

    def test_source_sha_metadata_alone_does_not_replace_canonical_source_comparison(self):
        abi = ABIS[-1]
        source = self.cargo / select_target(self.policy, abi, "release")["targetTriple"] / "release" / "liblegado_ffi.so"
        write(source, source.read_bytes() + b"different-business-binary")
        meta_path = self.root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs" / abi / "liblegado_ffi.so.meta"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        meta["sourceSha256"] = sha256_file(source)
        write(meta_path, json.dumps(meta))
        with self.assertRaisesRegex(ToolError, "strip 正规化摘要不同"):
            self.collect()
        self.assertFalse(self.output.exists())

    def test_legitimate_cargo_strip_difference_is_accepted_without_modifying_source(self):
        for abi in ABIS:
            source = self.cargo / select_target(self.policy, abi, "release")["targetTriple"] / "release" / "liblegado_ffi.so"
            write(source, source.read_bytes() + b"debug-symbols")
            meta_path = self.root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs" / abi / "liblegado_ffi.so.meta"
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta["sourceSha256"] = sha256_file(source)
            write(meta_path, json.dumps(meta))

        def strip(args, *unused, **kwargs):
            path = Path(args[-1])
            write(path, path.read_bytes().removesuffix(b"debug-symbols"))

        with patch.object(app, "run_command", side_effect=strip):
            self.collect()
        for abi in ABIS:
            source = self.cargo / select_target(self.policy, abi, "release")["targetTriple"] / "release" / "liblegado_ffi.so"
            self.assertTrue(source.read_bytes().endswith(b"debug-symbols"))

    def test_unknown_existing_output_is_preserved_and_rejected(self):
        unrelated = self.output / "other-release.apk"
        write(unrelated, b"user-output")
        with self.assertRaisesRegex(ToolError, "文件集以外"):
            self.collect()
        self.assertEqual(unrelated.read_bytes(), b"user-output")
        self.assertEqual(list(self.output.iterdir()), [unrelated])

    def test_output_cannot_overlap_inputs_or_fingerprint_source_trees(self):
        for destination in (self.root, self.root.parent / "outside-artifacts", self.input,
                            self.input.parent, self.input / "nested", self.root / "rust" / "artifacts",
                            self.root / "scripts" / "tooling" / "artifacts", self.root / ".git" / "artifacts"):
            with self.subTest(destination=destination), self.assertRaises(ToolError):
                app.collect_android_apks(self.root, "release", ABIS, destination)

    def test_staged_copy_failure_does_not_replace_existing_output(self):
        self.collect()
        before = {path.name: path.read_bytes() for path in self.output.iterdir()}
        original_copy = app.shutil.copyfile

        def copy(source, destination, *args, **kwargs):
            if Path(destination).name == self.apks[-1].name:
                raise OSError("复制失败 fixture")
            return original_copy(source, destination, *args, **kwargs)

        with patch.object(app.shutil, "copyfile", side_effect=copy), self.assertRaises(OSError):
            self.collect()
        self.assertEqual({path.name: path.read_bytes() for path in self.output.iterdir()}, before)

    def test_changed_apk_during_copy_is_not_published(self):
        original_copy = app.shutil.copyfile

        def copy(source, destination, *args, **kwargs):
            result = original_copy(source, destination, *args, **kwargs)
            if Path(destination).suffix == ".apk":
                write(Path(source), Path(source).read_bytes() + b"changed-during-copy")
            return result

        with patch.object(app.shutil, "copyfile", side_effect=copy), self.assertRaisesRegex(ToolError, "收集期间"):
            self.collect()
        self.assertFalse(self.output.exists())

    def test_empty_duplicate_unknown_abi_and_unsupported_profile_are_rejected(self):
        for profile, abis in (("release", ()), ("release", (ABIS[0], ABIS[0])),
                              ("release", ("unknown",)), ("debug", ("armeabi-v7a",))):
            with self.subTest(profile=profile, abis=abis), self.assertRaises(ToolError):
                app.collect_android_apks(self.root, profile, abis, self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
