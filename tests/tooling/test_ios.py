"""iOS 正式目标与失败阻断的 fixture；不替代真实 macOS 编译和运行验收。"""

import json
import os
from pathlib import Path
import plistlib
import shlex
import tempfile
import unittest
from unittest.mock import patch

from support import fixture, write
from tooling.common import CommandError, ToolError
from tooling import ios


class IosTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="iOS 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        native = self.root / "flutter_legado" / "ios"
        write(native / "Flutter" / "AppFrameworkInfo.plist", plistlib.dumps({"MinimumOSVersion": "15.0"}))
        write(native / "Podfile", "platform :ios, '15.0'\n")
        write(native / "RustFFI" / "RustFFI.podspec", "s.ios.deployment_target = '15.0'\n")
        write(native / "Runner.xcodeproj" / "project.pbxproj", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;\n")
        self.calls = []
        self.fail = self.omit = self.mutate = False
        self.arches = "arm64\n"
        self.library_symbols = "0000000000000000 T _frb_pde_ffi_dispatcher_primary\n"
        self.app_symbols = {}
        self.sysroot = self.root / "Rust SDK"
        self.llvm_nm = self.sysroot / "lib" / "rustlib" / "aarch64-apple-darwin" / "bin" / "llvm-nm"
        write(self.llvm_nm, b"tool")
        for sdk in ("iphoneos", "iphonesimulator"):
            (self.root / f"{sdk} SDK").mkdir()
        for replacement in (
            patch.object(ios.sys, "platform", "darwin"),
            patch.dict(os.environ, {"CARGO_TARGET_DIR": str(self.root / "rust" / "target")}),
            patch.object(ios, "find_tool", side_effect=lambda name, env: self.root / name),
            patch.object(ios, "run_command", side_effect=self.execute),
        ):
            replacement.start()
            self.addCleanup(replacement.stop)

    def execute(self, args, cwd, env, capture=False):
        args = [str(value) for value in args]
        self.calls.append((args, env.copy()))
        if "--show-sdk-path" in args:
            return str(self.root / f"{args[args.index('--sdk') + 1]} SDK") + "\n"
        if "--show-sdk-version" in args:
            return "fixture-sdk\n"
        if args[1:] == ["-Vv"]:
            return "fixture-version\nhost: aarch64-apple-darwin\n"
        if args[1:] == ["--print", "sysroot"]:
            return str(self.sysroot) + "\n"
        if Path(args[0]).name == "llvm-nm":
            return self.library_symbols
        if args[1:] == ["-V"]:
            return "fixture-version\n"
        if args[1] == "rustc":
            if self.fail:
                raise CommandError("cargo", 9)
            triple = args[args.index("--target") + 1]
            source = Path(args[args.index("--target-dir") + 1]) / triple / "release" / "liblegado_ffi.a"
            write(source, b"!<arch>\n" + b"current-library")
            if self.mutate:
                write(self.root / "rust" / "legado-ffi" / "src" / "business.rs", "编译期间变化\n")
            return json.dumps({"reason": "compiler-artifact", "target": {"name": "legado_ffi"},
                               "filenames": [] if self.omit else [str(source)]}) + "\n"
        if args[1] == "lipo":
            return self.arches
        if args[1] == "nm":
            file = Path(args[-1])
            if file.suffix == ".a":
                return self.library_symbols
            response = self.app_symbols.get(file.name, "                 U _frb_pde_ffi_dispatcher_primary\n")
            if isinstance(response, Exception):
                raise response
            return response
        raise AssertionError(f"未预期的 fixture 调用：{args}")

    def library(self):
        return self.root / "flutter_legado" / "ios" / "RustFFI" / "libliblegado_ffi.a"

    def test_static_archive_uses_matching_rust_llvm_and_app_uses_xcode_nm(self):
        ios.build_ios_ffi(self.root, "device", "release")
        self.assertTrue(any(Path(args[0]) == self.llvm_nm for args, env in self.calls))
        self.assertFalse(any(args[1] == "nm" for args, env in self.calls))

    def test_missing_rust_llvm_tools_fails_before_cargo_build(self):
        self.llvm_nm.unlink()
        with self.assertRaisesRegex(ToolError, "llvm-tools-preview"):
            ios.build_ios_ffi(self.root, "device", "release")
        self.assertFalse(any(args[1] == "rustc" for args, env in self.calls))

    def test_flutter_removing_template_minimum_does_not_invalidate_native_metadata(self):
        library = ios.build_ios_ffi(self.root, "device", "release")
        template = self.root / "flutter_legado" / "ios" / "Flutter" / "AppFrameworkInfo.plist"
        for contents in ({"CFBundleExecutable": "App"}, {"MinimumOSVersion": "13.0"}):
            with self.subTest(template=contents):
                write(template, plistlib.dumps(contents))
                self.assertEqual(ios.deployment_target(self.root), "15.0")
                self.assertEqual(ios.verify_ios_ffi(self.root, "device", "release"), library)
        write(self.root / "flutter_legado" / "ios" / "Podfile", "platform :ios, '16.0'\n")
        with self.assertRaisesRegex(ToolError, "不一致"):
            ios.verify_ios_ffi(self.root, "device", "release")

    def test_both_formal_targets_build_release_quickjs_with_locked_dependencies(self):
        for target, (triple, sdk) in ios.TARGETS.items():
            with self.subTest(target=target):
                library = ios.build_ios_ffi(self.root, target, "release")
                self.assertEqual(ios.verify_ios_ffi(self.root, target, "release"), library)
                command, env = next(call for call in reversed(self.calls) if call[0][1] == "rustc")
                self.assertIn("--locked", command)
                self.assertIn("--release", command)
                self.assertEqual(command[command.index("--features") + 1], "quickjs")
                self.assertEqual(command[command.index("--crate-type") + 1], "staticlib")
                self.assertEqual(command[command.index("--target") + 1], triple)
                self.assertEqual(env["SDKROOT"], str(self.root / f"{sdk} SDK"))
                self.assertEqual(env["IPHONEOS_DEPLOYMENT_TARGET"], "15.0")
                if target == "simulator":
                    self.assertEqual(shlex.split(env["BINDGEN_EXTRA_CLANG_ARGS"]),
                                     ["--target=aarch64-apple-ios-simulator", "-isysroot", env["SDKROOT"]])

    def test_switching_to_device_clears_inherited_simulator_bindgen_flags(self):
        with patch.dict(os.environ, {"BINDGEN_EXTRA_CLANG_ARGS": "old simulator",
                                     "BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios": "old override"}):
            ios.build_ios_ffi(self.root, "device", "release")
        _, env = next(call for call in self.calls if call[0][1] == "rustc")
        self.assertFalse(any(key.startswith("BINDGEN_EXTRA_CLANG_ARGS") for key in env))

    def test_wrong_target_profile_features_and_digest_metadata_rejected_readonly(self):
        for field, value in (("targetTriple", "aarch64-apple-ios-sim"), ("profile", "debug"),
                             ("features", []), ("packagedSha256", "0" * 64), ("sdk", "iphonesimulator")):
            with self.subTest(field=field):
                library = ios.build_ios_ffi(self.root, "device", "release")
                path = library.with_suffix(".a.meta")
                meta = json.loads(path.read_text(encoding="utf-8"))
                meta[field] = value
                write(path, json.dumps(meta))
                before = path.read_bytes()
                with self.assertRaises(ToolError):
                    ios.verify_ios_ffi(self.root, "device", "release")
                self.assertEqual(path.read_bytes(), before)

    def test_device_library_is_not_accepted_as_simulator(self):
        ios.build_ios_ffi(self.root, "device", "release")
        with self.assertRaises(ToolError):
            ios.verify_ios_ffi(self.root, "simulator", "release")

    def test_business_change_without_contract_change_requires_rebuild(self):
        ios.build_ios_ffi(self.root, "device", "release")
        write(self.root / "rust" / "legado-ffi" / "src" / "business.rs", "业务变化\n")
        with self.assertRaisesRegex(ToolError, "rustFingerprint"):
            ios.verify_ios_ffi(self.root, "device", "release")

    def test_missing_metadata_and_modified_source_or_copy_rejected(self):
        for problem in ("metadata", "source", "copy"):
            with self.subTest(problem=problem):
                library = ios.build_ios_ffi(self.root, "device", "release")
                if problem == "metadata":
                    library.with_suffix(".a.meta").unlink()
                else:
                    path = library if problem == "copy" else self.root / "rust" / "target" / "aarch64-apple-ios" / "release" / "liblegado_ffi.a"
                    write(path, path.read_bytes() + b"changed")
                with self.assertRaises(ToolError):
                    ios.verify_ios_ffi(self.root, "device", "release")
                if problem == "metadata":
                    self.assertFalse(library.with_suffix(".a.meta").exists())

    def test_failed_cargo_does_not_retry_or_publish_old_archive(self):
        library = ios.build_ios_ffi(self.root, "device", "release")
        before = (library.read_bytes(), library.with_suffix(".a.meta").read_bytes())
        self.calls.clear()
        self.fail = True
        with self.assertRaises(CommandError) as failure:
            ios.build_ios_ffi(self.root, "device", "release")
        self.assertEqual(failure.exception.code, 9)
        self.assertEqual(sum(args[1] == "rustc" for args, _ in self.calls), 1)
        self.assertEqual((library.read_bytes(), library.with_suffix(".a.meta").read_bytes()), before)

    def test_missing_artifact_message_rejects_existing_library(self):
        ios.build_ios_ffi(self.root, "device", "release")
        self.omit = True
        with self.assertRaisesRegex(ToolError, "Cargo 未确认"):
            ios.build_ios_ffi(self.root, "device", "release")

    def test_changed_inputs_during_build_are_not_published(self):
        self.mutate = True
        with self.assertRaisesRegex(ToolError, "构建期间"):
            ios.build_ios_ffi(self.root, "device", "release")
        self.assertFalse(self.library().exists())

    def test_archive_missing_defined_symbol_or_wrong_architecture_rejected(self):
        for arches, symbols in (("x86_64\n", self.library_symbols),
                                ("arm64\n", "                 U _frb_pde_ffi_dispatcher_primary\n")):
            with self.subTest(arches=arches, symbols=symbols):
                self.arches, self.library_symbols = arches, symbols
                with self.assertRaises(ToolError):
                    ios.build_ios_ffi(self.root, "device", "release")
                self.assertFalse(self.library().exists())

    def test_simulator_debug_dylib_is_checked_and_undefined_runner_is_insufficient(self):
        ios.build_ios_ffi(self.root, "simulator", "release")
        app = self.root / "Runner.app"
        write(app / "Runner", b"runner-fixture")
        write(app / "Runner.debug.dylib", b"debug-fixture")
        with self.assertRaisesRegex(ToolError, "应用缺少"):
            ios.verify_ios_app(self.root, "simulator", "release", app)
        self.app_symbols["Runner.debug.dylib"] = self.library_symbols
        ios.verify_ios_app(self.root, "simulator", "release", app)

    def test_device_does_not_accept_debug_dylib_in_place_of_release_runner(self):
        ios.build_ios_ffi(self.root, "device", "release")
        app = self.root / "Runner.app"
        write(app / "Runner.debug.dylib", b"debug-fixture")
        self.app_symbols["Runner.debug.dylib"] = self.library_symbols
        with self.assertRaisesRegex(ToolError, "应用缺少"):
            ios.verify_ios_app(self.root, "device", "release", app)

    def test_symbol_read_errors_fail_instead_of_reporting_success(self):
        ios.build_ios_ffi(self.root, "device", "release")
        app = self.root / "Runner.app"
        write(app / "Runner", b"runner-fixture")
        self.app_symbols["Runner"] = CommandError("nm", 1)
        with self.assertRaises(ToolError):
            ios.verify_ios_app(self.root, "device", "release", app)

    def test_deployment_configuration_disagreement_blocks_build(self):
        write(self.root / "flutter_legado" / "ios" / "Podfile", "platform :ios, '13.0'\n")
        with self.assertRaisesRegex(ToolError, "最低版本"):
            ios.build_ios_ffi(self.root, "device", "release")
        self.assertFalse(self.library().exists())

    def test_unsupported_hosts_and_profiles_fail_before_tool_calls(self):
        for host in ("win32", "linux"):
            with patch.object(ios.sys, "platform", host), self.assertRaisesRegex(ToolError, "macOS"):
                ios.build_ios_ffi(self.root, "device", "release")
        with self.assertRaisesRegex(ToolError, "release"):
            ios.build_ios_ffi(self.root, "device", "debug")
        self.assertEqual(self.calls, [])

    def test_symbol_substrings_and_undefined_or_local_symbols_are_rejected(self):
        for symbols in (" U _frb_pde_ffi_dispatcher_primary", "0000 T _frb_pde_ffi_dispatcher_primary_extra",
                        "0000 t _frb_pde_ffi_dispatcher_primary"):
            with self.subTest(symbols=symbols):
                self.assertFalse(ios.has_defined_pde(symbols))
        self.assertTrue(ios.has_defined_pde("0000 T frb_pde_ffi_dispatcher_primary"))


if __name__ == "__main__":
    unittest.main()
