"""覆盖固定生成器、生成/构建分离，以及脏工作区的隔离复核。"""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from support import fixture, write
from tooling.bridge import generate_bridge, generate_dart
from tooling.common import ToolError


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="生成 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.commands = []
        self.version = "2.13.0"
        self.tools = patch("tooling.bridge.find_tool", side_effect=lambda name, env: self.root / name)
        self.dart = patch("tooling.bridge.dart_environment", side_effect=lambda env: (self.root / "dart", env))
        self.run = patch("tooling.bridge.run_command", side_effect=self.fake_run)
        for mocked in (self.tools, self.dart, self.run):
            mocked.start()
            self.addCleanup(mocked.stop)

    def fake_run(self, args, cwd, env, capture=False):
        self.commands.append(list(map(str, args)))
        if args[1:] == ["--version"]:
            return "flutter_rust_bridge_codegen " + self.version
        return ""

    def test_generator_version_mismatch_does_not_generate(self):
        self.version = "2.12.0"
        with self.assertRaisesRegex(ToolError, "必须为 2.13.0"):
            generate_bridge(self.root)
        self.assertEqual(len(self.commands), 1)

    def test_generate_bridge_does_not_build_or_close_app(self):
        generate_bridge(self.root)
        self.assertEqual(self.commands[-1][1:], ["generate", "--config-file", "flutter_rust_bridge.yaml"])
        self.assertFalse(any("build" in args or "Stop-Process" in args for args in self.commands))
        self.assertFalse(any("--skip-fvm-install" in args for args in self.commands))

    def test_generate_dart_restores_locked_dependencies(self):
        generate_dart(self.root)
        self.assertEqual([args[1:] for args in self.commands], [["pub", "get", "--enforce-lockfile"], ["run", "build_runner", "build"]])

    def test_generator_lockfile_change_is_reported(self):
        original = self.fake_run

        def mutate_lock(args, cwd, env, capture=False):
            result = original(args, cwd, env, capture)
            if args[1] == "generate":
                write(self.root / "rust" / "Cargo.lock", "生成器不应更新依赖")
            return result

        with patch("tooling.bridge.run_command", side_effect=mutate_lock), self.assertRaisesRegex(ToolError, "锁文件"):
            generate_bridge(self.root)

    def test_check_uses_dirty_and_untracked_inputs_without_modifying_original(self):
        dirty = self.root / "rust" / "legado-ffi" / "src" / "business.rs"
        untracked = dirty.parent / "new_untracked.rs"
        write(dirty, "未提交修改")
        write(untracked, "未跟踪输入")
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in self.root.rglob("*") if path.is_file()}

        def assert_copy(root, codegen, dart, env):
            self.assertNotEqual(root, self.root)
            self.assertEqual((root / dirty.relative_to(self.root)).read_text(encoding="utf-8"), "未提交修改")
            self.assertEqual((root / untracked.relative_to(self.root)).read_text(encoding="utf-8"), "未跟踪输入")
            self.assertTrue(Path(env["CARGO_TARGET_DIR"]).is_relative_to(root))

        with patch("tooling.bridge.invoke_bridge", side_effect=assert_copy):
            generate_bridge(self.root, check=True)
        self.assertEqual({path: (path.read_bytes(), path.stat().st_mtime_ns) for path in before}, before)

    def test_check_detects_added_deleted_and_modified_outputs(self):
        for change in ("added", "deleted", "modified", "module"):
            def mutate(root, *args):
                bridge = root / "flutter_legado" / "lib" / "src" / "bridge"
                path = bridge / "frb_generated.dart"
                if change == "added":
                    write(bridge / "new_generated.dart", "新增")
                elif change == "deleted":
                    path.unlink()
                elif change == "module":
                    write(root / "rust" / "legado-ffi" / "src" / "lib.rs", "mod frb_generated;\n")
                else:
                    write(path, path.read_bytes() + b"// changed\n")
            original = (self.root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart").read_bytes()
            with self.subTest(change=change), patch("tooling.bridge.invoke_bridge", side_effect=mutate), self.assertRaisesRegex(ToolError, "不一致"):
                generate_bridge(self.root, check=True)
            self.assertEqual((self.root / "flutter_legado" / "lib" / "src" / "bridge" / "frb_generated.dart").read_bytes(), original)

    def test_absolute_or_external_outputs_rejected(self):
        config = self.root / "flutter_legado" / "flutter_rust_bridge.yaml"
        original = config.read_text()
        for value in ("/outside", "../../outside"):
            write(config, original.replace("lib/src/bridge/", value))
            with self.subTest(value=value), self.assertRaisesRegex(ToolError, "相对路径"):
                generate_bridge(self.root, check=True)


if __name__ == "__main__":
    unittest.main()
