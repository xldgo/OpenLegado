"""保护失败不降级、不复用旧库，以及整组产物发布与回滚。"""

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from support import artifact, elf, fixture, write
from tooling.android import build_android_ffi, build_lock
from tooling.common import CommandError, ToolError
from tooling.ffi_metadata import verify_android
from tooling.policy import load_policy


class AndroidBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="构建 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.policy = load_policy(self.root)
        self.ndk = self.root / "NDK 空格"
        write(self.ndk / "source.properties", f"Pkg.Revision = {self.policy['ndkVersion']}\n")
        host = {"win32": "windows-x86_64", "linux": "linux-x86_64", "darwin": "darwin-x86_64"}[sys.platform]
        toolchain = self.ndk / "toolchains" / "llvm" / "prebuilt" / host
        for name in ("clang", "clang++", "llvm-ar", "llvm-strip"):
            write(toolchain / "bin" / (name + (".exe" if os.name == "nt" else "")), b"tool")
        for target in self.policy["targets"].values():
            (toolchain / "sysroot" / "usr" / "include" / target["sysrootTriple"]).mkdir(parents=True, exist_ok=True)
        self.calls = []
        self.failure = None
        self.mutate = None
        self.omit_artifact = False
        self.find = patch("tooling.android.find_tool", side_effect=lambda name, env: self.root / name)
        self.run = patch("tooling.android.run_command", side_effect=self.fake_run)
        self.find.start()
        self.run.start()
        self.addCleanup(self.find.stop)
        self.addCleanup(self.run.stop)

    def fake_run(self, args, cwd, env, capture=False):
        args = list(map(str, args))
        self.calls.append((args, env.copy()))
        if args[1:] == ["target", "list", "--installed"]:
            return "\n".join(target["targetTriple"] for target in self.policy["targets"].values())
        if args[1:] in (["-Vv"], ["-V"], ["--version"]):
            return "测试工具版本"
        if args[1] == "--strip-unneeded":
            path = Path(args[2])
            write(path, path.read_bytes() + b"stripped")
            return ""
        self.assertEqual(args[1], "build")
        triple = args[args.index("--target") + 1]
        if triple == self.failure:
            raise CommandError("cargo", 101)
        target = next(target for target in self.policy["targets"].values() if target["targetTriple"] == triple)
        profile = "release" if "--release" in args else "debug"
        source = Path(args[args.index("--target-dir") + 1]) / triple / profile / "liblegado_ffi.so"
        write(source, elf(target, b"current-successful-build"))
        if self.mutate:
            self.mutate()
        if self.omit_artifact:
            return '{"reason":"build-finished","success":true}\n'
        return json.dumps({"reason": "compiler-artifact", "target": {"name": "legado_ffi"}, "filenames": [str(source)]}) + "\n"

    def build(self, profile="debug", abis=("arm64-v8a", "x86_64")):
        return build_android_ffi(self.root, profile, abis, self.ndk)

    def libraries(self):
        return self.root / "flutter_legado" / "android" / "app" / "src" / "main" / "jniLibs"

    def snapshot(self):
        return {path.relative_to(self.libraries()).as_posix(): (path.read_bytes(), path.stat().st_mtime_ns)
                for path in self.libraries().rglob("*") if path.is_file()}

    def test_successful_two_abi_build_and_source_verification(self):
        output = self.build()
        self.assertTrue(all(result.source_checked for result in verify_android(self.root, "debug", ("arm64-v8a", "x86_64"), output)))
        commands = [args for args, _ in self.calls if args[1] == "build"]
        self.assertEqual(len(commands), 2)
        for args in commands:
            self.assertIn("--locked", args)
            self.assertIn("--no-default-features", args)
            self.assertEqual(args[args.index("--features") + 1], "quickjs")
        self.assertFalse((self.root / "rust" / "target" / ".python-android-ffi.lock").exists())

    def test_release_armv7_features_and_strip_only_packaged_copy(self):
        output = self.build("release", ("arm64-v8a", "armeabi-v7a", "x86_64"))
        commands = [args for args, _ in self.calls if args[1] == "build"]
        armv7 = next(args for args in commands if "armv7-linux-androideabi" in args)
        self.assertNotIn("--features", armv7)
        for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
            meta = json.loads((self.libraries() / abi / "liblegado_ffi.so.meta").read_text())
            self.assertNotEqual(meta["sourceSha256"], meta["packagedSha256"])
            source = output / meta["targetTriple"] / "release" / "liblegado_ffi.so"
            self.assertNotIn(b"stripped", source.read_bytes())
        self.assertEqual(len(verify_android(self.root, "release", ("arm64-v8a", "armeabi-v7a", "x86_64"), output)), 3)

    def test_quickjs_failure_with_old_library_keeps_all_original_artifacts(self):
        artifact(self.root)
        artifact(self.root, "x86_64")
        before = self.snapshot()
        self.failure = "x86_64-linux-android"
        with self.assertRaises(CommandError) as error:
            self.build()
        self.assertEqual(error.exception.code, 101)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(len([args for args, _ in self.calls if args[1] == "build"]), 2)

    def test_no_cargo_artifact_message_does_not_reuse_existing_file(self):
        artifact(self.root)
        before = self.snapshot()
        self.omit_artifact = True
        with self.assertRaisesRegex(ToolError, "Cargo 未确认"):
            self.build()
        self.assertEqual(self.snapshot(), before)

    def test_input_change_during_build_rejects_publication(self):
        artifact(self.root)
        before = self.snapshot()
        self.mutate = lambda: write(self.root / "rust" / "legado-ffi" / "src" / "business.rs", "构建中修改")
        with self.assertRaisesRegex(ToolError, "构建期间"):
            self.build()
        self.assertEqual(self.snapshot(), before)

    def test_failure_after_directory_install_rolls_back(self):
        artifact(self.root)
        before = self.snapshot()
        real_verify = verify_android
        count = 0

        def fail_final(*args, **kwargs):
            nonlocal count
            count += 1
            if count == 2:
                raise ToolError("发布后验证失败")
            return real_verify(*args, **kwargs)

        with patch("tooling.android.verify_android", side_effect=fail_final), self.assertRaisesRegex(ToolError, "发布后"):
            self.build()
        self.assertEqual(self.snapshot(), before)

    def test_unselected_native_library_is_preserved(self):
        other = self.libraries() / "x86_64" / "another.so"
        write(other, b"other-native-library")
        self.build(abis=("arm64-v8a",))
        self.assertEqual(other.read_bytes(), b"other-native-library")

    def test_failed_rollback_preserves_original_backup(self):
        artifact(self.root)
        original = self.snapshot()
        replace = os.replace

        def block_publish_and_restore(source, destination):
            if Path(destination) == self.libraries() and Path(source) != self.libraries():
                raise OSError("目录占用")
            return replace(source, destination)

        with patch("tooling.android.os.replace", side_effect=block_publish_and_restore), self.assertRaisesRegex(ToolError, "备份保留"):
            self.build()
        backups = list(self.libraries().parent.glob(".tmp_ffi_backup_*"))
        self.assertEqual(len(backups), 1)
        recovered = {path.relative_to(backups[0]).as_posix(): (path.read_bytes(), path.stat().st_mtime_ns)
                     for path in backups[0].rglob("*") if path.is_file()}
        self.assertEqual(recovered, original)

    def test_existing_lock_rejects_concurrent_builder(self):
        with build_lock(self.root), self.assertRaisesRegex(ToolError, "构建锁"):
            self.build()

    def test_missing_or_wrong_ndk_fails_before_cargo_build(self):
        for path in (self.root / "missing", self.ndk):
            if path == self.ndk:
                write(path / "source.properties", "Pkg.Revision = 27.0.12077973\n")
            with self.subTest(path=path), self.assertRaises(ToolError):
                build_android_ffi(self.root, "debug", ("arm64-v8a",), path)
        self.assertEqual(self.calls, [])

    def test_encoded_flags_match_target_sysroot_and_page_size(self):
        self.build(abis=("arm64-v8a",))
        _, env = next((args, env) for args, env in self.calls if args[1] == "build")
        flags = env["CARGO_ENCODED_RUSTFLAGS"].split("\x1f")
        self.assertIn("link-arg=--target=aarch64-linux-android21", flags)
        self.assertIn("link-arg=-Wl,-z,max-page-size=16384", flags)
        self.assertIn("link-arg=-Wl,-z,common-page-size=16384", flags)
        self.assertEqual(env["RUSTUP_TOOLCHAIN"], "stable")
        self.assertNotIn("RUSTFLAGS", env)

    def test_strip_failure_keeps_original_libraries(self):
        artifact(self.root)
        before = self.snapshot()
        original = self.fake_run

        def fail_strip(args, *rest, **kwargs):
            if str(args[1]) == "--strip-unneeded":
                raise CommandError("llvm-strip", 1)
            return original(args, *rest, **kwargs)

        with patch("tooling.android.run_command", side_effect=fail_strip), self.assertRaises(CommandError):
            self.build("release", ("arm64-v8a",))
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
