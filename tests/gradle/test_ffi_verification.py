"""使用真实 Gradle 执行薄适配和 Python 校验；不依赖 AGP、不构建 APK。"""

import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "tooling"))
from support import artifact, fixture, write


class GradleFfiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        distribution = os.environ.get("LEGADO_TEST_GRADLE_HOME")
        java = os.environ.get("LEGADO_TEST_JAVA")
        if not distribution or not java:
            raise unittest.SkipTest("需指定 LEGADO_TEST_GRADLE_HOME 与 LEGADO_TEST_JAVA，才能执行真实 Gradle")
        jars = list((Path(distribution) / "lib").glob("gradle-gradle-cli-main-*.jar"))
        if len(jars) != 1:
            raise RuntimeError("Gradle 发行目录不完整")
        cls.launcher = [java, "--enable-native-access=ALL-UNNAMED", "-jar", str(jars[0])]

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Gradle FFI 中文 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.android = self.root / "flutter_legado" / "android"
        write(self.android / "ffi-verification.gradle.kts",
              (ROOT / "flutter_legado" / "android" / "ffi-verification.gradle.kts").read_bytes())
        write(self.android / "settings.gradle.kts", 'rootProject.name = "ffi-adapter-fixture"\ninclude(":app")\n')
        write(self.android / "app" / "build.gradle.kts",
              'apply(from = "../ffi-verification.gradle.kts")\n'
              'listOf("preDebugBuild", "preReleaseBuild", "preProfileBuild").forEach { tasks.register(it) }\n')
        self.env = {**os.environ, "PYTHON": sys.executable, "PYTHONIOENCODING": "utf-8",
                    "CI": "false", "GITHUB_ACTIONS": "false", "LEGADO_SKIP_RUST_BUILD": "0"}
        self.mock = "-Pdart-defines=" + base64.b64encode(b"USE_MOCK=true").decode()

    def run_gradle(self, *args, success=True):
        result = subprocess.run([*self.launcher, "--console=plain", "--max-workers=2", *args],
                                cwd=self.android, env=self.env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, encoding="utf-8", errors="replace", timeout=180)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def libraries(self, profile="debug", abis=("arm64-v8a", "x86_64")):
        for abi in abis:
            artifact(self.root, abi=abi, profile=profile)

    def test_debug_prebuild_runs_verifier_and_cached_graph_rechecks_source(self):
        self.libraries()
        first = self.run_gradle(":app:preDebugBuild", "--configuration-cache")
        self.assertIn("verifyDebugRustFfiLibs", first)
        self.assertIn("arm64-v8a：校验通过", first)
        self.assertIn("x86_64：校验通过", first)
        write(self.root / "rust" / "legado-ffi" / "src" / "business.rs", "源码已改变\n")
        second = self.run_gradle(":app:preDebugBuild", "--configuration-cache", success=False)
        self.assertIn("rustFingerprint 不匹配", second)
        self.assertIn("Reusing configuration cache", second)

    def test_release_and_profile_use_release_matrix(self):
        self.libraries("release", ("arm64-v8a", "x86_64", "armeabi-v7a"))
        for variant in ("Release", "Profile"):
            output = self.run_gradle(f":app:pre{variant}Build")
            self.assertIn(f"verify{variant}RustFfiLibs", output)
            self.assertIn("armeabi-v7a：校验通过（release", output)
            self.assertNotIn("> Task :app:verifyDebugRustFfiLibs", output)

    def test_policy_change_invalidates_cached_abi_selection(self):
        self.libraries()
        self.run_gradle(":app:preDebugBuild", "--configuration-cache")
        path = self.root / "scripts/tooling/android-policy.json"
        policy = json.loads(path.read_text(encoding="utf-8"))
        del policy["targets"]["x86_64"]
        write(path, json.dumps(policy))
        self.libraries(abis=("arm64-v8a",))
        output = self.run_gradle(":app:preDebugBuild", "--configuration-cache")
        self.assertIn("arm64-v8a：校验通过", output)
        self.assertNotIn("x86_64：校验通过", output)

    def test_explicit_target_checks_only_requested_abi(self):
        self.libraries(abis=("arm64-v8a",))
        output = self.run_gradle(":app:preDebugBuild", "-Ptarget-platform=android-arm64")
        self.assertIn("arm64-v8a：校验通过", output)
        self.assertNotIn("x86_64：校验通过", output)

    def test_local_debug_mock_skip_requires_both_explicit_options(self):
        self.env["LEGADO_SKIP_RUST_BUILD"] = "1"
        output = self.run_gradle(":app:preDebugBuild", self.mock)
        self.assertIn("本地 Debug Mock 模式，跳过 Rust FFI 校验", output)
        self.assertNotIn("校验通过", output)
        self.run_gradle(":app:preDebugBuild", success=False)

    def test_skip_is_rejected_for_ci_release_and_profile(self):
        self.env["LEGADO_SKIP_RUST_BUILD"] = "1"
        for variant in ("Release", "Profile"):
            output = self.run_gradle(f":app:pre{variant}Build", self.mock, success=False)
            self.assertIn("Release/Profile/CI 必须校验", output)
        self.env["CI"] = "true"
        output = self.run_gradle(":app:preDebugBuild", self.mock, success=False)
        self.assertIn("Release/Profile/CI 必须校验", output)

    def test_invalid_and_conflicting_mock_definitions_are_rejected(self):
        self.env["LEGADO_SKIP_RUST_BUILD"] = "1"
        conflict = self.mock + "," + base64.b64encode(b"USE_MOCK=false").decode()
        for definition in ("-Pdart-defines=invalid!", conflict):
            self.run_gradle(":app:preDebugBuild", definition, success=False)

    def test_missing_interpreter_and_python_nonzero_fail_gradle(self):
        output = self.run_gradle(":app:preDebugBuild", "-PlegadoPython=" + str(self.root / "missing python.exe"), success=False)
        self.assertIn("Python 3.11+", output)
        write(self.root / "scripts" / "dev.py", "import sys\nsys.exit(37)\n")
        output = self.run_gradle(":app:preDebugBuild", success=False)
        self.assertIn("non-zero exit value 37", output)

    def test_legacy_or_missing_metadata_rejected_without_repair(self):
        self.libraries()
        meta = self.root / "flutter_legado/android/app/src/main/jniLibs/arm64-v8a/liblegado_ffi.so.meta"
        write(meta, '{"contentHash":-123456}')
        output = self.run_gradle(":app:preDebugBuild", success=False)
        self.assertIn("schemaVersion 必须为 2", output)
        self.assertEqual(meta.read_text(encoding="utf-8"), '{"contentHash":-123456}')
        meta.unlink()
        self.run_gradle(":app:preDebugBuild", success=False)
        self.assertFalse(meta.exists())

    def test_unknown_duplicate_and_unsupported_debug_platform_fail(self):
        for platforms in ("android-unknown", "android-arm64,android-arm64", "android-arm64,", "android-arm"):
            with self.subTest(platforms=platforms):
                self.run_gradle(":app:preDebugBuild", "-Ptarget-platform=" + platforms, success=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
