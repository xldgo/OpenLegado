"""图标与 IPA 的规则及失败分支；合成文件不代表真实 Apple 构建。"""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import plistlib
import shutil
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from support import write
from tooling.common import CommandError, ToolError
from tooling.ios_bundle import (ICON_NAMES, LEGACY_SIZES, export_ios_plist, package_ios_ipa,
                               prepare_bundle_icons, verify_bundle_icons, verify_icon_assets,
                               verify_icon_build_log, verify_ios_ipa)


class IOSBundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "含空格的 工程"
        self.app = self.root / "flutter_legado/build/ios/iphoneos/Runner.app"
        self.assets = self.root / "flutter_legado/ios/Runner/Assets.xcassets"
        self.ipa = self.app.parent / "app-signed.ipa"
        self.data = {"CFBundleIdentifier": "io.legado.flutter_legado", "CFBundleExecutable": "Runner"}
        for section in ("CFBundleIcons", "CFBundleIcons~ipad"):
            self.data[section] = {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"},
                                  "CFBundleAlternateIcons": {name: {"CFBundleIconName": name}
                                                             for name in ICON_NAMES}}
        self.save_plist()
        write(self.app / "Runner", b"fixture-runner")
        for name in ICON_NAMES:
            directory = self.assets / f"{name}.appiconset"
            images = [{"filename": f"{name}_{size}.png"} for size, _ in LEGACY_SIZES]
            write(directory / "Contents.json", json.dumps({"images": images}))
            for image in images:
                write(directory / image["filename"], b"fixture-png")
        write(self.assets / "AppIcon.appiconset/Icon-App-60x60@3x.png", b"fixture-primary")

    def save_plist(self):
        write(self.app / "Info.plist", plistlib.dumps(self.data))

    def prepare(self):
        with redirect_stdout(io.StringIO()) as messages:
            prepare_bundle_icons(self.root, self.assets, self.app)
        return messages.getvalue()

    def archive(self, *, runner=b"fixture-runner", plist=None, omit=None, duplicate=False, symlink=False):
        with zipfile.ZipFile(self.ipa, "w", compression=zipfile.ZIP_STORED) as archive:
            if omit != "plist":
                archive.writestr("Payload/Runner.app/Info.plist", plist if plist is not None else plistlib.dumps(self.data))
            if omit != "runner":
                entry = zipfile.ZipInfo("Payload/Runner.app/Runner")
                entry.create_system = 3
                entry.external_attr = ((stat.S_IFLNK if symlink else stat.S_IFREG) | 0o755) << 16
                archive.writestr(entry, runner)
            if duplicate:
                archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(self.data))

    def test_assets_resolve_referenced_filenames_with_spaces(self):
        directory = self.assets / "launcher1.appiconset"
        write(directory / "含空格的 图标.png", b"fixture")
        write(directory / "Contents.json", json.dumps({"images": [{"filename": "含空格的 图标.png"}, {}]}))
        verify_icon_assets(self.assets)

    def test_missing_referenced_asset_and_malformed_slot_fail(self):
        directory = self.assets / "launcher1.appiconset"
        for content in ('{"images":[{"filename":"missing.png"}]}', '{"images":[]}',
                        '{"images":[null]}', '{"images":[{"filename":"../escape.png"}]}', '{broken'):
            with self.subTest(content=content):
                write(directory / "Contents.json", content)
                with self.assertRaises(ToolError):
                    verify_icon_assets(self.assets)

    def test_actool_warning_has_line_numbers_and_missing_log_fails(self):
        log = self.root / "build.log"
        write(log, "正常输出\nunassigned children in launcher1\n")
        with self.assertRaisesRegex(ToolError, "2: unassigned children"):
            verify_icon_build_log(log)
        write(log, "正常输出\n")
        verify_icon_build_log(log)
        with self.assertRaises(ToolError):
            verify_icon_build_log(self.root / "missing.log")

    def test_prepare_copies_exact_legacy_sizes_and_keeps_primary_and_bundle_fields(self):
        self.assertIn("转换 12 个", self.prepare())
        verify_bundle_icons(self.app)
        result = plistlib.loads((self.app / "Info.plist").read_bytes())
        self.assertEqual(result["CFBundleIdentifier"], self.data["CFBundleIdentifier"])
        for section, size in (("CFBundleIcons", "60x60"), ("CFBundleIcons~ipad", "76x76")):
            self.assertEqual(result[section]["CFBundlePrimaryIcon"], self.data[section]["CFBundlePrimaryIcon"])
            for name in ICON_NAMES:
                self.assertEqual(result[section]["CFBundleAlternateIcons"][name], {"CFBundleIconFiles": [name + size]})
        self.assertEqual(len(list(self.app.glob("launcher*.png"))), 24)
        self.assertEqual((self.app / "AppIcon60x60@3x.png").read_bytes(), b"fixture-primary")

    def test_optional_ipad_section_keeps_six_entry_conversion_and_warning(self):
        del self.data["CFBundleIcons~ipad"]
        self.save_plist()
        self.assertIn("::warning::", self.prepare())
        verify_bundle_icons(self.app)

    def test_missing_source_rejected_before_any_copy_or_plist_change(self):
        original = (self.app / "Info.plist").read_bytes()
        (self.assets / "launcher6.appiconset/launcher6_180.png").unlink()
        with self.assertRaisesRegex(ToolError, "散文件缺失"):
            self.prepare()
        self.assertEqual((self.app / "Info.plist").read_bytes(), original)
        self.assertFalse(list(self.app.glob("launcher*.png")))

    def test_already_converted_bundle_is_not_silently_reconverted(self):
        self.prepare()
        original = (self.app / "Info.plist").read_bytes()
        with self.assertRaisesRegex(ToolError, "至少需要 6"):
            self.prepare()
        self.assertEqual((self.app / "Info.plist").read_bytes(), original)

    def test_empty_reference_asset_name_and_incomplete_alternate_set_fail(self):
        self.prepare()
        valid = (self.app / "Info.plist").read_bytes()
        for alteration in ("empty", "asset-name", "missing-alternate", "bad-ipad", "unsafe-filename"):
            with self.subTest(alteration=alteration):
                data = plistlib.loads(valid)
                alternates = data["CFBundleIcons"]["CFBundleAlternateIcons"]
                if alteration == "empty":
                    alternates["launcher1"]["CFBundleIconFiles"] = []
                elif alteration == "asset-name":
                    alternates["launcher1"]["CFBundleIconName"] = "launcher1"
                elif alteration == "missing-alternate":
                    del alternates["launcher6"]
                elif alteration == "bad-ipad":
                    data["CFBundleIcons~ipad"] = []
                else:
                    alternates["launcher1"]["CFBundleIconFiles"] = ["../outside"]
                write(self.app / "Info.plist", plistlib.dumps(data))
                with self.assertRaises(ToolError):
                    verify_bundle_icons(self.app)

    def test_missing_both_phone_scale_files_fails(self):
        self.prepare()
        for scale in (2, 3):
            (self.app / f"launcher160x60@{scale}x.png").unlink()
        with self.assertRaisesRegex(ToolError, "图标资源缺失"):
            verify_bundle_icons(self.app)

    def test_binary_plist_supported_and_invalid_xml_is_a_clear_error(self):
        write(self.app / "Info.plist", plistlib.dumps(self.data, fmt=plistlib.FMT_BINARY))
        self.prepare()
        write(self.app / "Info.plist", b"<?xml version='1.0'?><plist><dict>")
        with self.assertRaisesRegex(ToolError, "plist 无法解析"):
            verify_bundle_icons(self.app)

    def test_valid_ipa_verification_does_not_rewrite_archive(self):
        self.archive()
        original = self.ipa.read_bytes()
        verify_ios_ipa(self.ipa)
        self.assertEqual(self.ipa.read_bytes(), original)

    def test_missing_empty_symlink_runner_and_invalid_plist_fail(self):
        cases = ({"omit": "runner"}, {"omit": "plist"}, {"runner": b""}, {"symlink": True},
                 {"plist": b"bad-plist"}, {"plist": plistlib.dumps([])})
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ToolError):
                self.archive(**case)
                verify_ios_ipa(self.ipa)

    def test_duplicate_entries_and_crc_corruption_fail(self):
        with self.assertWarns(UserWarning):
            self.archive(duplicate=True)
        with self.assertRaisesRegex(ToolError, "重复"):
            verify_ios_ipa(self.ipa)
        self.archive()
        content = self.ipa.read_bytes().replace(b"fixture-runner", b"fixture-broken", 1)
        self.ipa.write_bytes(content)
        with self.assertRaisesRegex(ToolError, "CRC"):
            verify_ios_ipa(self.ipa)

    def test_export_keeps_source_bytes_and_only_icon_keys_in_json(self):
        original = (self.app / "Info.plist").read_bytes()
        output = self.app.parent.parent / "device-plist"
        export_ios_plist(self.root, self.app, output)
        self.assertEqual((self.app / "Info.plist").read_bytes(), original)
        self.assertEqual((output / "Info.plist").read_bytes(), original)
        self.assertEqual(set(json.loads((output / "icon-section.json").read_text())), {"CFBundleIcons", "CFBundleIcons~ipad"})

    def test_export_rejects_source_overlap_and_source_project_output(self):
        for output in (self.app, self.app / "diagnostic", self.app.parent, self.assets):
            with self.subTest(output=output), self.assertRaises(ToolError):
                export_ios_plist(self.root, self.app, output)

    def test_prepare_cannot_modify_source_project_or_external_bundle(self):
        for app in (self.assets, self.root.parent / "Runner.app"):
            with self.subTest(app=app), self.assertRaises(ToolError):
                prepare_bundle_icons(self.root, self.assets, app)

    def test_packaging_failure_keeps_previous_ipa_and_does_not_modify_source(self):
        write(self.ipa, b"previous-ipa")
        original = (self.app / "Info.plist").read_bytes()
        with patch("tooling.ios_bundle.sys.platform", "darwin"), \
             patch("tooling.ios_bundle.find_tool", side_effect=lambda name, env: Path("/usr/bin") / name), \
             patch("tooling.ios_bundle.run_command", side_effect=CommandError("cp", 9)), \
             self.assertRaises(CommandError):
            package_ios_ipa(self.root, self.app, self.ipa)
        self.assertEqual(self.ipa.read_bytes(), b"previous-ipa")
        self.assertEqual((self.app / "Info.plist").read_bytes(), original)
        self.assertFalse(list(self.app.parent.glob(".legado-ipa-*")))

    def test_packaging_uses_fresh_payload_native_zip_and_publishes_only_valid_archive(self):
        write(self.app.parent / "Payload/stale-file", b"old")
        write(self.ipa, b"previous-ipa")
        calls = []

        def command(args, cwd, env):
            calls.append(args)
            if Path(args[0]).name == "cp":
                self.assertEqual(args[1], "-r")
                shutil.copytree(args[2], Path(args[3]) / "Runner.app")
            else:
                self.assertEqual(args[1], "-qry")
                with zipfile.ZipFile(args[2], "w") as archive:
                    for file in (cwd / "Payload").rglob("*"):
                        if file.is_file():
                            archive.write(file, file.relative_to(cwd))

        with patch("tooling.ios_bundle.sys.platform", "darwin"), \
             patch("tooling.ios_bundle.find_tool", side_effect=lambda name, env: Path("/usr/bin") / name), \
             patch("tooling.ios_bundle.run_command", side_effect=command):
            self.assertEqual(package_ios_ipa(self.root, self.app, self.ipa), self.ipa.resolve())
        verify_ios_ipa(self.ipa)
        with zipfile.ZipFile(self.ipa) as archive:
            self.assertNotIn("Payload/stale-file", archive.namelist())
        self.assertEqual(len(calls), 2)

    def test_invalid_staged_archive_keeps_previous_ipa(self):
        write(self.ipa, b"previous-ipa")

        def command(args, cwd, env):
            if Path(args[0]).name == "zip":
                write(args[2], b"invalid-zip")

        with patch("tooling.ios_bundle.sys.platform", "darwin"), \
             patch("tooling.ios_bundle.find_tool", side_effect=lambda name, env: Path("/usr/bin") / name), \
             patch("tooling.ios_bundle.run_command", side_effect=command), self.assertRaises(ToolError):
            package_ios_ipa(self.root, self.app, self.ipa)
        self.assertEqual(self.ipa.read_bytes(), b"previous-ipa")

    def test_package_rejects_other_hosts_and_outputs_inside_source_app(self):
        with patch("tooling.ios_bundle.sys.platform", "win32"), self.assertRaisesRegex(ToolError, "macOS"):
            package_ios_ipa(self.root, self.app, self.ipa)
        with patch("tooling.ios_bundle.sys.platform", "darwin"), self.assertRaises(ToolError):
            package_ios_ipa(self.root, self.app, self.app / "bad.ipa")


if __name__ == "__main__":
    unittest.main()
