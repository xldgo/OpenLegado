"""验证任务范围、Git 差异与汇总门禁，使用标准库和临时 Git 仓库。"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import ci_changes as ci


class RoutingTests(unittest.TestCase):
    def test_module_matrix(self):
        cases = {
            "README.md": set(),
            "docs/development.md": set(),
            "flutter_legado/README.md": set(),
            "rust/DEVELOPMENT.md": set(),
            ".github/scripts/ci_changes.py": {"tooling"},
            ".github/scripts/test_ci_changes.py": {"tooling"},
            ".github/scripts/flutter_test_report.py": {"tooling", "flutter"},
            "flutter_legado/lib/src/features/bookshelf/bookshelf_screen.dart": {"flutter", "ios_build"},
            "flutter_legado/lib/src/features/book_sources/source_screen.dart": {"flutter", "ios_build"},
            "flutter_legado/lib/src/features/search/search_screen.dart": {"flutter", "ios_build"},
            "flutter_legado/lib/src/domain/services/search_result_aggregator.dart": {"flutter", "ios_build"},
            "flutter_legado/test/widget/bookshelf_test.dart": {"flutter"},
            "flutter_legado/assets/updateLog.md": {"flutter", "ios_build"},
            "flutter_legado/android/app/build.gradle.kts": set(),
            "flutter_legado/ios/Runner/AppDelegate.swift": {"ios_build"},
            "flutter_legado/windows/runner/main.cpp": set(),
            "flutter_legado/lib/src/services/rust_api.dart": {"flutter", "ios_build"},
            "flutter_legado/lib/src/services/rust_api_sources.part.dart": {"flutter", "ios_build"},
            "flutter_legado/lib/src/bridge/frb_generated.dart": {"flutter", "ios_build"},
            "flutter_legado/pubspec.lock": {"flutter", "ios_build", "tooling"},
            "rust/legado-core/src/reader.rs": {"rust", "ios_build"},
            "rust/legado-ffi/src/ffi.rs": set(ci.TARGETS) - {"tooling"},
            "rust/legado-core/tests/reader.rs": {"rust"},
            "rust/legado-layout/src/paginator.rs": {"flutter", "rust", "ios_build"},
            "rust/legado-layout/tests/upstream_parity.rs": {"flutter", "rust"},
            "rust/legado-core/src/tests/reader.rs": {"rust", "ios_build"},
            "rust/legado-server/assets/web/help/md/jsHelp.md": {"rust", "ios_build"},
            "rust/Cargo.lock": {"rust", "ios_build"},
            "rust/.cargo/config.toml": {"rust", "ios_build"},
            "rust/rust-toolchain.toml": {"rust", "ios_build"},
            "rust/scripts/build-ios.sh": {"tooling", "ios_build"},
            "rust/scripts/gen_rar5_fixture.py": {"tooling", "rust"},
            "rust/scripts/build-ios-new.sh": {"tooling", "rust", "ios_build"},
            "rust/scripts/new_input.md": {"tooling", "rust", "ios_build"},
            "scripts/emulator_smoke_test.ps1": {"tooling"},
            "scripts/tooling/android_app.py": {"tooling"},
            "scripts/tooling/windows.py": {"tooling"},
            "scripts/tooling/windows_app.py": {"tooling"},
            "scripts/tooling/android.py": {"tooling"},
            "scripts/tooling/android_toolchain.py": {"tooling"},
            "scripts/tooling/ios.py": {"tooling", "ios_build"},
            "scripts/tooling/ios_bundle.py": {"tooling", "ios_build"},
            "scripts/tooling/bridge.py": {"tooling"},
            "tests/tooling/test_ios.py": {"tooling"},
            "scripts/tooling/new_tool.py": {"tooling", "ios_build"},
            "scripts/tooling/new_data.md": {"tooling", "ios_build"},
            "scripts/tooling/contracts.py": {"tooling", "ios_build"},
            "scripts/dev.py": {"tooling", "ios_build"},
            "third_party/quickjs/quickjs.c": set(ci.TARGETS),
            ".github/workflows/flutter-ci.yml": {"tooling", "flutter"},
            ".github/workflows/rust-ci.yml": {"tooling", "rust"},
            ".github/workflows/release.yml": {"tooling"},
            ".github/workflows/ios-build.yml": {"tooling", "ios_build"},
            ".github/workflows/tooling-ci.yml": {"tooling"},
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                selected = ci.classify_paths([path])
                self.assertEqual({key for key, value in selected.items() if value}, expected)

    def test_generation_scope_follows_inputs_not_ordinary_ui(self):
        cases = {
            "flutter_legado/lib/src/features/search/search_screen.dart": (False, False),
            "flutter_legado/lib/src/models/book.dart": (True, False),
            "flutter_legado/lib/src/features/search/search_state.dart": (True, False),
            "flutter_legado/lib/src/features/search/search_state.freezed.dart": (True, False),
            "flutter_legado/lib/src/bridge/frb_generated.dart": (False, True),
            "rust/legado-ffi/src/api/book_api.rs": (False, True),
            "rust/legado-ffi/tests/book_api.rs": (False, False),
            "flutter_legado/pubspec.lock": (True, True),
            "scripts/tooling/bridge.py": (True, True),
        }
        for path, (dart, bridge) in cases.items():
            with self.subTest(path=path):
                self.assertEqual(ci.classify_generation_paths([path]),
                                 {"dart_generate": dart, "bridge_generate": bridge})

    def test_multiple_modules_are_combined(self):
        self.assertEqual(ci.classify_paths([
            "flutter_legado/test/widget/a.dart", "rust/legado-core/src/reader.rs",
        ]), {target: target != "tooling" for target in ci.TARGETS})

    def test_bad_event_or_sha_fails(self):
        with self.assertRaises(ValueError):
            ci.changed_paths(ci.ROOT, "push", {"before": "bad"}, "a" * 40)
        with self.assertRaises(ValueError):
            ci.changed_paths(ci.ROOT, "schedule", {}, "a" * 40)

    def test_manual_missing_null_and_empty_inputs_select_all(self):
        for event in ({}, {"inputs": None}, {"inputs": {}}):
            with self.subTest(event=event):
                self.assertEqual(ci.plan(ci.ROOT, "workflow_dispatch", event, "unused"),
                                 dict.fromkeys(ci.TARGETS, True))

    def test_manual_invalid_inputs_are_rejected(self):
        for inputs in ([], "", False, 1):
            with self.subTest(inputs=inputs), self.assertRaises(ValueError):
                ci.plan(ci.ROOT, "workflow_dispatch", {"inputs": inputs}, "unused")


class SummaryTests(unittest.TestCase):
    def needs(self, selected="true", result="success"):
        return {"changes": {"result": "success", "outputs": {"rust": selected}}, "tests": {"result": result}}

    def test_selected_success_passes(self):
        ci.check_results(self.needs(), {"tests": "rust"})

    def test_unselected_skip_passes(self):
        ci.check_results(self.needs("false", "skipped"), {"tests": "rust"})

    def test_failures_and_unexpected_skip_fail(self):
        for result in ("failure", "cancelled", "skipped", None):
            with self.subTest(result=result), self.assertRaises(ValueError):
                ci.check_results(self.needs(result=result), {"tests": "rust"})

    def test_unselected_failure_fails(self):
        with self.assertRaises(ValueError):
            ci.check_results(self.needs("false", "failure"), {"tests": "rust"})

    def test_detection_failure_or_missing_output_fails(self):
        for result in ("failure", "cancelled", "skipped"):
            needs = self.needs()
            needs["changes"]["result"] = result
            with self.subTest(result=result), self.assertRaises(ValueError):
                ci.check_results(needs, {"tests": "rust"})
        with self.assertRaises(ValueError):
            ci.check_results(self.needs(selected=""), {"tests": "rust"})


class NativeRoutingTests(unittest.TestCase):
    def test_native_inputs(self):
        for path in (
            "rust/legado-net/src/client.rs", "rust/Cargo.lock",
            "rust/legado-layout/tests/fixtures/md3.json.gz",
            "rust/legado-ffi/tests/fixtures/layout_transport.json",
            "flutter_legado/lib/src/data/bridge/rust_runtime.dart",
            "flutter_legado/lib/src/widgets/reader/reader_text_content.dart",
            "flutter_legado/lib/src/features/reader/application/reader_state.dart",
            "flutter_legado/lib/src/features/read_aloud/playback/file_read_aloud_playlist.dart",
            "flutter_legado/lib/src/app/routing/app_router.dart",
            "flutter_legado/lib/src/new_shared_module/service.dart",
            "flutter_legado/pubspec.lock", "flutter_legado/dart_test.yaml",
            "flutter_legado/test/ffi/privacy_runtime_test.dart",
            "flutter_legado/test/helpers/native_ffi.dart",
            ".github/workflows/flutter-ci.yml",
            ".github/actions/setup-flutter-rust/action.yml", "third_party/plugin/lib/native.dart",
        ):
            with self.subTest(path=path):
                self.assertEqual(ci.classify_native_test_paths([path]), {"native_tests": True})

    def test_isolated_ui_docs_and_other_platforms_do_not_build_linux(self):
        for path in (
            "docs/development.md", "rust/README.md", "README.md",
            "flutter_legado/lib/src/widgets/top_bar_button.dart",
            "flutter_legado/lib/src/features/bookshelf/bookshelf_screen.dart",
            "flutter_legado/lib/src/features/settings/presentation/settings_screen.dart",
            "flutter_legado/android/app/build.gradle.kts", "flutter_legado/ios/Runner/Info.plist",
            "rust/legado-net/tests/client.rs", "flutter_legado/assets/updateLog.md",
        ):
            with self.subTest(path=path):
                self.assertEqual(ci.classify_native_test_paths([path]), {"native_tests": False})

    def test_native_input_is_not_hidden_by_unrelated_changes(self):
        self.assertEqual(ci.classify_native_test_paths([
            "README.md", "flutter_legado/lib/src/bridge/frb_generated.dart",
        ]), {"native_tests": True})

    def test_aggregate_rejects_native_failure_or_unexpected_skip(self):
        for result in ("failure", "cancelled", "skipped"):
            with self.subTest(result=result), self.assertRaises(ValueError):
                ci.check_results({
                    "changes": {"result": "success", "outputs": {
                        "flutter_checks": "false", "native_tests": "true",
                    }},
                    "flutter-checks": {"result": "skipped"},
                    "native-tests": {"result": result},
                }, {"flutter-checks": "flutter_checks", "native-tests": "native_tests"})
        ci.check_results({
            "changes": {"result": "success", "outputs": {
                "flutter_checks": "true", "native_tests": "false",
            }},
            "flutter-checks": {"result": "success"},
            "native-tests": {"result": "skipped"},
        }, {"flutter-checks": "flutter_checks", "native-tests": "native_tests"})


class GitDiffTests(unittest.TestCase):
    def setUp(self):
        parent = ci.ROOT / ".tmp_ci_workflow_validation"
        parent.mkdir(exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="ci-routing-", dir=parent)
        self.root = Path(self.directory.name).resolve()
        self.assertTrue(self.root.is_relative_to(parent.resolve()))
        self.addCleanup(self.directory.cleanup)
        self.command("init", "-q", "-b", "master")
        self.command("config", "user.email", "ci-fixture@example.invalid")
        self.command("config", "user.name", "CI 夹具")
        self.write("README.md", "基线\n")
        self.base = self.commit()

    def command(self, *args):
        return ci.git(self.root, *args).strip()

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def commit(self):
        self.command("add", "--all")
        self.command("-c", "commit.gpgsign=false", "commit", "-qm", "夹具")
        return self.command("rev-parse", "HEAD")

    def test_push_covers_all_commits_in_batch(self):
        self.write("flutter_legado/test/中文 空格.dart", "第一项")
        self.commit()
        self.write("rust/legado-core/src/reader.rs", "第二项")
        head = self.commit()
        self.assertEqual(set(ci.changed_paths(self.root, "push", {"before": self.base}, head)), {
            "flutter_legado/test/中文 空格.dart", "rust/legado-core/src/reader.rs",
        })

    def test_ordinary_test_metadata_does_not_require_native(self):
        path = "flutter_legado/test/unit/player_test.dart"
        self.write(path, "import 'package:flutter_test/flutter_test.dart';\nvoid main() {}")
        self.assertFalse(ci.classify_native_test_paths([path], self.root)["native_tests"])
        self.write(path, "@Tags(['native'])\nlibrary;\nvoid main() {}")
        self.assertTrue(ci.classify_native_test_paths([path], self.root)["native_tests"])
        self.write(path, "test('native边界', () {}, tags: ['native']);")
        self.assertTrue(ci.classify_native_test_paths([path], self.root)["native_tests"])

    def test_removed_native_tag_and_deleted_native_test_keep_native_check(self):
        path = "flutter_legado/test/widget/layout_test.dart"
        self.write(path, "@Tags(['native'])\nlibrary;\nvoid main() {}")
        base = self.commit()
        self.write(path, "void main() {}")
        self.commit()
        self.assertTrue(ci.classify_native_test_paths([path], self.root, base)["native_tests"])
        (self.root / path).unlink()
        self.assertTrue(ci.classify_native_test_paths([path], self.root, base)["native_tests"])

    def test_deleted_ordinary_test_and_shared_support_inputs(self):
        path = "flutter_legado/test/widget/button_test.dart"
        self.write(path, "void main() {}")
        base = self.commit()
        (self.root / path).unlink()
        self.assertFalse(ci.classify_native_test_paths([path], self.root, base)["native_tests"])
        for support in ("fixtures/book.dart", "helpers/native_ffi.dart", "mocks/player.dart", "new/data.json"):
            self.assertTrue(ci.classify_native_test_paths(["flutter_legado/test/" + support], self.root, base)["native_tests"])
        self.assertTrue(ci.classify_native_test_paths(["flutter_legado/test/widget/unknown_test.dart"], self.root)["native_tests"])

    def test_manual_flutter_scopes_do_not_change_other_workflows(self):
        for scope, expected in (
            ("fast", {"flutter", "flutter_checks"}),
            ("native", {"native_tests"}),
            ("all", {"flutter", "flutter_checks", "native_tests", "dart_generate", "bridge_generate"}),
        ):
            with self.subTest(scope=scope):
                selected = ci.flutter_manual_plan(self.root, scope, self.base)
                self.assertEqual({k for k, v in selected.items() if v}, expected)
        self.assertEqual(ci.plan(self.root, "workflow_dispatch", {"inputs": {}}, self.base),
                         dict.fromkeys(ci.TARGETS, True))
        with self.assertRaises(ValueError):
            ci.flutter_manual_plan(self.root, "unknown", self.base)

    def test_manual_auto_last_commit_and_explicit_multi_commit_baseline(self):
        self.write("rust/legado-net/src/client.rs", "Rust")
        self.commit()
        self.write("flutter_legado/test/unit/player_test.dart", "void main() {}")
        head = self.commit()
        selected = ci.flutter_manual_plan(self.root, "auto", head)
        self.assertTrue(selected["flutter_checks"])
        self.assertFalse(selected["native_tests"])
        self.assertFalse(selected["bridge_generate"])
        full_range = ci.flutter_manual_plan(self.root, "auto", head, self.base)
        self.assertTrue(full_range["native_tests"])
        for base in ("bad", "0" * 40, head):
            with self.subTest(base=base), self.assertRaises(ValueError):
                ci.flutter_manual_plan(self.root, "auto", head, base)

    def test_manual_auto_root_commit_fails_instead_of_silently_skipping(self):
        with self.assertRaises(subprocess.CalledProcessError):
            ci.flutter_manual_plan(self.root, "auto", self.base)

    def test_manual_auto_fetches_shallow_baseline(self):
        self.write("rust/legado-net/src/client.rs", "Rust")
        self.commit()
        self.write("flutter_legado/test/unit/player_test.dart", "void main() {}")
        head = self.commit()
        clone = self.root / "manual-shallow"
        self.command("clone", "--depth=2", "--no-local", self.root.as_uri(), str(clone))
        self.assertFalse(ci.flutter_manual_plan(clone, "auto", head)["native_tests"])
        self.assertTrue(ci.flutter_manual_plan(clone, "auto", head, self.base)["native_tests"])

    def test_flutter_manual_cli_overrides_only_dispatch(self):
        event = self.root / ".git" / "manual-event.json"
        output = self.root / ".git" / "manual-output.txt"
        event.write_text(json.dumps({"inputs": {"test_scope": "native"}}), encoding="utf-8")
        with patch.object(ci, "ROOT", self.root), patch.object(
            os.sys, "argv", ["ci_changes.py", "changes"],
        ), patch.dict(os.environ, {
            "GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_EVENT_PATH": str(event),
            "GITHUB_OUTPUT": str(output), "GITHUB_SHA": self.base, "CI_FLUTTER_SCOPE": "native",
        }), patch("builtins.print"):
            self.assertEqual(ci.main(), 0)
        values = dict(line.split("=", 1) for line in output.read_text(encoding="utf-8").splitlines())
        self.assertEqual({k for k, v in values.items() if v == "true"}, {"native_tests"})
        with patch.object(os.sys, "argv", ["ci_changes.py", "changes"]), patch.dict(os.environ, {
            "GITHUB_EVENT_NAME": "push", "GITHUB_EVENT_PATH": str(event), "CI_FLUTTER_SCOPE": "fast",
        }), patch("builtins.print"):
            self.assertEqual(ci.main(), 1)

    def test_rename_includes_old_and_new_modules(self):
        old = "flutter_legado/windows/runner/main.cpp"
        new = "flutter_legado/android/main.cpp"
        self.write(old, "相同内容")
        base = self.commit()
        (self.root / new).parent.mkdir(parents=True, exist_ok=True)
        self.command("mv", old, new)
        head = self.commit()
        self.assertEqual(set(ci.changed_paths(self.root, "push", {"before": base}, head)), {old, new})

    def test_new_branch_checks_tracked_tree(self):
        self.assertEqual(ci.changed_paths(self.root, "push", {"before": "0" * 40}, self.base), ["README.md"])

    def test_deleted_branch_has_no_jobs(self):
        self.assertEqual(ci.changed_paths(self.root, "push", {"deleted": True}, self.base), [])

    def test_pr_merge_ignores_changes_already_on_base(self):
        self.command("checkout", "-qb", "feature")
        self.write("flutter_legado/test/a.dart", "PR")
        self.commit()
        self.command("checkout", "master")
        self.write("rust/legado-core/src/reader.rs", "基线后续提交")
        base = self.commit()
        self.command("-c", "commit.gpgsign=false", "merge", "--no-ff", "-qm", "合并夹具", "feature")
        head = self.command("rev-parse", "HEAD")
        event = {"pull_request": {"base": {"sha": base}}}
        self.assertEqual(ci.changed_paths(self.root, "pull_request", event, head), ["flutter_legado/test/a.dart"])

    def test_missing_base_is_fetched_for_shallow_checkout(self):
        self.write("flutter_legado/test/a.dart", "第一次")
        self.commit()
        self.write("flutter_legado/test/b.dart", "第二次")
        head = self.commit()
        clone = self.root / "shallow"
        self.command("clone", "--depth=1", "--no-local", self.root.as_uri(), str(clone))
        self.assertEqual(set(ci.changed_paths(clone, "push", {"before": self.base}, head)), {
            "flutter_legado/test/a.dart", "flutter_legado/test/b.dart",
        })

    def test_cli_writes_manual_outputs_and_rejects_invalid_inputs(self):
        event = self.root / "event.json"
        output = self.root / "outputs.txt"
        event.write_text(json.dumps({"inputs": {}}), encoding="utf-8")
        environment = dict(os.environ, GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_EVENT_PATH=str(event),
                           GITHUB_OUTPUT=str(output), GITHUB_SHA=self.base, PYTHONIOENCODING="utf-8")
        result = subprocess.run([os.sys.executable, str(ci.ROOT / ".github/scripts/ci_changes.py"), "changes"],
                                env=environment, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(dict(line.split("=", 1) for line in output.read_text(encoding="utf-8").splitlines()),
                         dict.fromkeys((*ci.TARGETS, "dart_generate", "bridge_generate", "native_tests", "flutter_checks"), "true"))
        event.write_text(json.dumps({"inputs": []}), encoding="utf-8")
        output.write_text("", encoding="utf-8")
        result = subprocess.run([os.sys.executable, str(ci.ROOT / ".github/scripts/ci_changes.py"), "changes"],
                                env=environment, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 1)
        self.assertIn("手动触发inputs必须为对象或null", result.stderr)
        self.assertEqual(output.read_text(encoding="utf-8"), "")

    def test_automatic_cli_emits_flutter_and_native_groups(self):
        event = self.root / ".git" / "fixture-event.json"
        output = self.root / ".git" / "fixture-outputs.txt"
        for path, expected in (
            ("flutter_legado/lib/src/features/bookshelf/bookshelf_screen.dart", ("true", "false")),
            ("flutter_legado/test/widget/bookshelf_test.dart", ("true", "false")),
            ("rust/legado-net/src/client.rs", ("false", "true")),
            ("rust/legado-ffi/src/api/book.rs", ("true", "true")),
            ("docs/development.md", ("false", "false")),
        ):
            before = self.command("rev-parse", "HEAD")
            self.write(path, "夹具\n")
            head = self.commit()
            event.write_text(json.dumps({"before": before}), encoding="utf-8")
            output.write_text("", encoding="utf-8")
            with self.subTest(path=path), patch.object(ci, "ROOT", self.root), patch.object(
                os.sys, "argv", ["ci_changes.py", "changes"],
            ), patch.dict(os.environ, {
                "GITHUB_EVENT_NAME": "push", "GITHUB_EVENT_PATH": str(event),
                "GITHUB_OUTPUT": str(output), "GITHUB_SHA": head,
            }), patch("builtins.print"):
                self.assertEqual(ci.main(), 0)
            values = dict(line.split("=", 1) for line in output.read_text(encoding="utf-8").splitlines())
            self.assertEqual((values["flutter_checks"], values["native_tests"]), expected)

    def test_manual_cli_accepts_real_no_input_payload(self):
        event = self.root / ".git" / "fixture-event.json"
        output = self.root / ".git" / "fixture-outputs.txt"
        for payload in ({}, {"inputs": None}, {"inputs": {}}):
            event.write_text(json.dumps(payload), encoding="utf-8")
            output.write_text("", encoding="utf-8")
            environment = dict(os.environ, GITHUB_EVENT_NAME="workflow_dispatch",
                               GITHUB_EVENT_PATH=str(event), GITHUB_OUTPUT=str(output),
                               GITHUB_SHA=self.base, PYTHONIOENCODING="utf-8")
            result = subprocess.run([os.sys.executable, str(ci.ROOT / ".github/scripts/ci_changes.py"), "changes"],
                                    env=environment, capture_output=True, text=True, encoding="utf-8")
            with self.subTest(payload=payload):
                self.assertEqual(result.returncode, 0, result.stderr)
                values = dict(line.split("=", 1) for line in output.read_text(encoding="utf-8").splitlines())
                self.assertEqual(set(values), {*ci.TARGETS, "dart_generate", "bridge_generate", "native_tests", "flutter_checks"})
                self.assertEqual(set(values.values()), {"true"})


if __name__ == "__main__":
    unittest.main()
