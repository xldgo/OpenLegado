"""覆盖陈旧、缺失、错配产物，确保只读校验遇到不确定输入就失败。"""

import json
from pathlib import Path
import tempfile
import unittest

from support import artifact, fixture, write
from tooling.common import ToolError, sha256_file
from tooling.ffi_metadata import bridge_contract, verify_android


class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="FFI 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.library, self.meta_path, self.meta = artifact(self.root)

    def verify(self, **kwargs):
        return verify_android(self.root, "debug", ("arm64-v8a",), **kwargs)

    def save_meta(self):
        write(self.meta_path, json.dumps(self.meta))

    def test_valid_artifact_and_negative_content_hash(self):
        result = self.verify()
        self.assertEqual(result[0].abi, "arm64-v8a")
        self.assertFalse(result[0].source_checked)

    def test_each_supported_abi_profile(self):
        for abi, profile in (("arm64-v8a", "release"), ("x86_64", "debug"),
                             ("x86_64", "release"), ("armeabi-v7a", "release")):
            with self.subTest(abi=abi, profile=profile):
                artifact(self.root, abi, profile)
                self.assertEqual(verify_android(self.root, profile, (abi,))[0].abi, abi)

    def test_hash_or_generated_version_mismatch(self):
        path = self.root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart"
        original = path.read_text()
        for old, new in (("-123456", "123456"), ("2.13.0", "2.12.0"),
                         ("-123456", "2147483648")):
            with self.subTest(new=new):
                write(path, original.replace(old, new))
                with self.assertRaises(ToolError):
                    self.verify()
        write(path, original)

    def test_runtime_version_mismatch_and_unpinned_version(self):
        path = self.root / "rust" / "legado-ffi" / "Cargo.toml"
        for value in ("=2.12.0", "2.13.0", "^2.13.0"):
            write(path, f'[dependencies]\nflutter_rust_bridge = "{value}"\n')
            with self.subTest(value=value), self.assertRaisesRegex(ToolError, "精确固定"):
                bridge_contract(self.root)

    def test_generated_loader_must_target_the_cargo_library(self):
        path = self.root / "flutter_legado/lib/src/bridge/frb_generated.dart"
        original = path.read_text()
        for stem in ("UNKNOWN", "another_library"):
            with self.subTest(stem=stem):
                write(path, original.replace("legado_ffi", stem))
                with self.assertRaisesRegex(ToolError, "原生库名错误"):
                    bridge_contract(self.root)
        write(path, original)
        self.assertEqual(bridge_contract(self.root).version, "2.13.0")
        manifest = self.root / "rust/legado-ffi/Cargo.toml"
        write(manifest, manifest.read_text() + '\n[lib]\nname = "custom_ffi"\n')
        write(path, original.replace("legado_ffi", "custom_ffi"))
        self.assertEqual(bridge_contract(self.root).version, "2.13.0")

    def test_pubspec_requires_a_pinned_runtime_dependency(self):
        path = self.root / "flutter_legado" / "pubspec.yaml"
        for text in ("dev_dependencies:\n  flutter_rust_bridge: 2.13.0\n",
                     "dependencies:\n  flutter_rust_bridge: ^2.13.0\n",
                     "dependencies:\n  flutter_rust_bridge: '2.13.0\n",
                     "dependencies:\n  flutter_rust_bridge: 2.13.0\n  flutter_rust_bridge: 2.12.0\n"):
            write(path, text)
            with self.subTest(text=text), self.assertRaises(ToolError):
                bridge_contract(self.root)
        for value in ("2.13.0", "'2.13.0'", '"2.13.0"'):
            write(path, f"dependencies:\n  flutter_rust_bridge: {value} # 固定版本\n")
            self.assertEqual(bridge_contract(self.root).version, "2.13.0")

    def test_missing_or_duplicated_generated_declaration(self):
        path = self.root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart"
        original = path.read_text()
        for value in ("", original + original):
            write(path, value)
            with self.subTest(value=value), self.assertRaisesRegex(ToolError, "明确声明"):
                bridge_contract(self.root)

    def test_business_source_changed_without_contract_change(self):
        path = self.root / "rust" / "legado-ffi" / "src" / "business.rs"
        write(path, "业务修改，接口未变\n")
        with self.assertRaisesRegex(ToolError, "rustFingerprint"):
            self.verify()

    def test_tooling_change_invalidates_build_inputs(self):
        path = self.root / "scripts" / "tooling" / "android.py"
        write(path, path.read_bytes() + b"\n# change\n")
        with self.assertRaisesRegex(ToolError, "buildInputsSha256"):
            self.verify()

    def test_python_bytecode_cache_does_not_change_build_inputs(self):
        tooling = self.root / "scripts" / "tooling"
        write(tooling / "__pycache__" / "cached.pyc", b"cache")
        write(tooling / "unused.pyc", b"cache")
        write(tooling / "unused.pyo", b"cache")
        self.assertEqual(len(self.verify()), 1)

    def test_policy_change_invalidates_build_inputs(self):
        path = self.root / "scripts" / "tooling" / "android-policy.json"
        policy = json.loads(path.read_text())
        policy["ndkVersion"] = "changed-version"
        write(path, json.dumps(policy))
        with self.assertRaisesRegex(ToolError, "buildInputsSha256"):
            self.verify()

    def test_library_byte_changed(self):
        write(self.library, self.library.read_bytes() + b"changed")
        with self.assertRaisesRegex(ToolError, "packagedSha256"):
            self.verify()

    def test_missing_and_empty_library(self):
        self.library.unlink()
        with self.assertRaisesRegex(ToolError, "库不存在或为空"):
            self.verify()
        write(self.library, b"")
        with self.assertRaisesRegex(ToolError, "库不存在或为空"):
            self.verify()

    def test_missing_metadata_is_not_created(self):
        self.meta_path.unlink()
        with self.assertRaises(ToolError):
            self.verify()
        self.assertFalse(self.meta_path.exists())

    def test_bad_json_duplicate_keys_nonfinite_and_nonobject(self):
        for value in ("", "{bad", "[]", "null", '{"a":1,"a":2}', '{"a":NaN}', '{"a":Infinity}'):
            write(self.meta_path, value)
            with self.subTest(value=value), self.assertRaises(ToolError):
                self.verify()

    def test_all_required_fields_missing(self):
        original = self.meta.copy()
        for field in original:
            self.meta = {key: value for key, value in original.items() if key != field}
            self.save_meta()
            with self.subTest(field=field), self.assertRaises(ToolError):
                self.verify()

    def test_legacy_schema_rejected(self):
        write(self.meta_path, json.dumps({"contentHash": -123456, "mode": "debug", "quickjs": True}))
        with self.assertRaisesRegex(ToolError, "schemaVersion"):
            self.verify()

    def test_wrong_identity_mode_feature_version_and_algorithm(self):
        original = self.meta.copy()
        changes = {"schemaVersion": 3, "contentHash": 123456, "frbCodegenVersion": "2.12.0",
                   "targetTriple": "x86_64-linux-android", "abi": "x86_64", "profile": "release",
                   "features": [], "fingerprintAlgorithm": "unknown", "buildInputsAlgorithm": "unknown"}
        for field, value in changes.items():
            self.meta = {**original, field: value}
            self.save_meta()
            with self.subTest(field=field), self.assertRaisesRegex(ToolError, field):
                self.verify()

    def test_invalid_field_types_and_values(self):
        original = self.meta.copy()
        changes = (("schemaVersion", True), ("schemaVersion", 2.0), ("contentHash", True),
                   ("contentHash", 2147483648), ("contentHash", "-123456"),
                   ("rustFingerprint", "a" * 63), ("packagedSha256", "A" * 64),
                   ("sourceSha256", 0), ("features", "quickjs"), ("features", [True]),
                   ("features", ["quickjs", "quickjs"]), ("builtAt", "not-a-date"),
                   ("builtAt", "2026-10-10T00:00:00"), ("builtAt", "2026-10-10T00:00:00+08:00"))
        for field, value in changes:
            self.meta = {**original, field: value}
            self.save_meta()
            with self.subTest(field=field, value=value), self.assertRaisesRegex(ToolError, field):
                self.verify()

    def test_wrong_elf_architecture_or_invalid_header_even_with_matching_digest(self):
        original = self.library.read_bytes()
        for offset, value in ((0, 0), (4, 1), (5, 2), (16, 2), (18, 62)):
            content = bytearray(original)
            content[offset] = value
            write(self.library, content)
            self.meta["packagedSha256"] = sha256_file(self.library)
            self.save_meta()
            with self.subTest(offset=offset), self.assertRaisesRegex(ToolError, "ELF"):
                self.verify()

    def test_source_and_packaged_hashes_can_differ(self):
        cargo = self.root / "rust" / "target"
        self.library, self.meta_path, self.meta = artifact(self.root, cargo_dir=cargo)
        self.assertNotEqual(self.meta["sourceSha256"], self.meta["packagedSha256"])
        self.assertTrue(self.verify(cargo_target_dir=cargo)[0].source_checked)

    def test_explicit_source_missing_or_changed_rejected(self):
        cargo = self.root / "custom target"
        self.library, self.meta_path, self.meta = artifact(self.root, cargo_dir=cargo)
        source = cargo / self.meta["targetTriple"] / "debug" / self.library.name
        write(source, source.read_bytes() + b"changed")
        with self.assertRaisesRegex(ToolError, "sourceSha256"):
            self.verify(cargo_target_dir=cargo)
        source.unlink()
        with self.assertRaisesRegex(ToolError, "Cargo 源库不存在"):
            self.verify(cargo_target_dir=cargo)

    def test_verify_never_modifies_library_or_metadata(self):
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in (self.library, self.meta_path)}
        self.verify()
        for path, expected in before.items():
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), expected)
        self.meta["profile"] = "release"
        self.save_meta()
        failed_before = self.meta_path.read_bytes()
        with self.assertRaises(ToolError):
            self.verify()
        self.assertEqual(self.meta_path.read_bytes(), failed_before)

    def test_multi_abi_failure_does_not_report_partial_success(self):
        artifact(self.root, "x86_64")
        write(self.library, self.library.read_bytes() + b"changed")
        with self.assertRaises(ToolError):
            verify_android(self.root, "debug", ("x86_64", "arm64-v8a"))


if __name__ == "__main__":
    unittest.main()
