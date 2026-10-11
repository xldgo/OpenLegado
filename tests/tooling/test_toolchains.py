"""环境发现优先级与 Windows 原生工具路径。"""

import os
from pathlib import Path
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

from support import fixture, write
from tooling.common import ToolError, run_command
from tooling.policy import load_policy
from tooling.android_toolchain import AndroidNdk, android_environment, discover_ndk
from tooling.toolchains import dart_environment, find_tool


class ToolchainTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="环境 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.policy = load_policy(self.root)
        self.sdk = self.root / "SDK 空格"
        self.ndk = self.sdk / "ndk" / self.policy["ndkVersion"]
        write(self.ndk / "source.properties", f"Pkg.Revision = {self.policy['ndkVersion']}\n")
        tag = {"win32": "windows-x86_64", "linux": "linux-x86_64", "darwin": "darwin-x86_64"}[sys.platform]
        self.bin = self.ndk / "toolchains" / "llvm" / "prebuilt" / tag / "bin"
        for name in ("clang", "clang++", "llvm-ar", "llvm-strip"):
            write(self.bin / (name + (".exe" if os.name == "nt" else "")), b"tool")
        self.sysroot = self.bin.parent / "sysroot"
        for target in self.policy["targets"].values():
            (self.sysroot / "usr" / "include" / target["sysrootTriple"]).mkdir(parents=True, exist_ok=True)

    def test_sdk_environment_and_local_properties_discovery(self):
        for key in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
            self.assertEqual(discover_ndk(self.root, self.policy, {key: str(self.sdk)}).root, self.ndk)
        escaped = str(self.sdk).replace("\\", "\\\\")
        write(self.root / "flutter_legado" / "android" / "local.properties", "sdk.dir=" + escaped + "\n")
        self.assertEqual(discover_ndk(self.root, self.policy, {}).root, self.ndk)

    def test_explicit_invalid_ndk_does_not_fall_back_to_valid_sdk(self):
        with self.assertRaises(ToolError):
            discover_ndk(self.root, self.policy, {"ANDROID_HOME": str(self.sdk)}, self.root / "missing")

    def test_ndk_environment_wrong_version_does_not_select_newest(self):
        wrong = self.sdk / "ndk" / "99.0.0"
        write(wrong / "source.properties", "Pkg.Revision = 99.0.0\n")
        with self.assertRaisesRegex(ToolError, "版本不匹配"):
            discover_ndk(self.root, self.policy, {"ANDROID_NDK_HOME": str(wrong), "ANDROID_HOME": str(self.sdk)})

    def test_flags_with_spaces_are_recoverable_and_parent_environment_unchanged(self):
        env = {"PATH": "original", "CC": "old-cc", "RUSTFLAGS": "old flags", "CARGO_ENCODED_RUSTFLAGS": "old"}
        original = env.copy()
        ndk = AndroidNdk(self.ndk, self.policy["ndkVersion"], self.bin, self.sysroot)
        result = android_environment(env, ndk, self.policy["targets"]["arm64-v8a"], self.policy)
        self.assertEqual(env, original)
        self.assertEqual(shlex.split(result["CFLAGS_aarch64_linux_android"]),
                         ["--target=aarch64-linux-android21", f"--sysroot={self.sysroot.as_posix()}"])
        self.assertEqual(result["CC_SHELL_ESCAPED_FLAGS"], "1")
        self.assertEqual(result["CC_aarch64-linux-android"], result["CC_aarch64_linux_android"])
        self.assertNotIn("BINDGEN_EXTRA_CLANG_ARGS", result)
        self.assertIn("BINDGEN_EXTRA_CLANG_ARGS_aarch64-linux-android", result)

    def test_flutter_dart_batch_resolves_native_sdk_without_shell(self):
        sdk = self.root / "Flutter SDK"
        batch = sdk / "bin" / "dart.bat"
        native = sdk / "bin" / "cache" / "dart-sdk" / "bin" / "dart.exe"
        write(batch, b"batch")
        write(native, b"native")
        with patch("tooling.toolchains.find_tool", return_value=batch):
            dart, env = dart_environment({"PATH": "original"})
        self.assertEqual(dart, native)
        self.assertEqual(env["FLUTTER_ROOT"], str(sdk))

    @unittest.skipIf(os.name == "nt", "Rustup 符号链接入口验证需要 POSIX 宿主")
    def test_rustup_symlink_preserves_dispatch_name(self):
        shim = self.root / "rustup"
        write(shim, '#!/bin/sh\nprintf "%s\\n" "${0##*/}"\n')
        shim.chmod(0o755)
        for name in ("cargo", "rustc"):
            alias = self.root / name
            alias.symlink_to(shim)
            tool = find_tool(name, {"PATH": str(self.root)})
            # 实际执行同一文件的两个入口，确认子进程仍收到各自的工具名称。
            result = run_command([tool], self.root, dict(os.environ), capture=True)
            self.assertEqual(result.strip(), name)


if __name__ == "__main__":
    unittest.main()
