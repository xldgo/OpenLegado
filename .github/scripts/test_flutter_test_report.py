"""用真实协议事件夹具验证并发、装载和失败报告；不读取生产代码文本。"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import flutter_test_report as report


def event(kind, time, **fields):
    return json.dumps({"type": kind, "time": time, **fields})


class ReportTests(unittest.TestCase):
    def fixture(self, failed=False):
        return [
            event("start", 0),
            event("suite", 0, suite={"id": 0, "path": "/repo/flutter_legado/test/a_test.dart"}),
            event("testStart", 0, test={"id": 1, "suiteID": 0, "name": "loading a"}),
            event("suite", 10, suite={"id": 2, "path": "/repo/flutter_legado/test/b_test.dart"}),
            event("testStart", 10, test={"id": 3, "suiteID": 2, "name": "loading b"}),
            event("testDone", 100, testID=1, result="success", hidden=True, skipped=False),
            event("testStart", 110, test={"id": 4, "suiteID": 0, "name": "中文|用例"}),
            event("testDone", 150, testID=3, result="success", hidden=True, skipped=False),
            event("testStart", 160, test={"id": 5, "suiteID": 2, "name": "普通用例"}),
            event("testDone", 210, testID=4, result="failure" if failed else "success", hidden=False, skipped=False),
            event("testDone", 360, testID=5, result="success", hidden=False, skipped=False),
            event("done", 400, success=not failed),
        ]

    def test_parallel_loading_execution_and_wall_time_are_separate(self):
        result = report.summarize(self.fixture())
        self.assertTrue(result["complete"])
        self.assertTrue(result["success"])
        self.assertEqual(result["elapsed_ms"], 400)
        self.assertEqual([(s["load_ms"], s["execution_ms"], s["tests"]) for s in result["suites"]],
                         [(140, 200, 1), (100, 100, 1)])
        self.assertEqual(result["cases"][0]["name"], "普通用例")
        self.assertEqual(len(result["cases"]), 2)

    def test_failure_and_markdown_escaping(self):
        result = report.summarize(self.fixture(failed=True))
        self.assertFalse(result["success"])
        self.assertEqual(sum(s["failed"] for s in result["suites"]), 1)
        rendered = report.markdown(result, "fast")
        self.assertIn("中文\\|用例", rendered)
        self.assertIn("failure", rendered)

    def test_interrupted_run_identifies_unfinished_test(self):
        result = report.summarize(self.fixture()[:-3])
        self.assertFalse(result["complete"])
        self.assertIsNone(result["success"])
        self.assertEqual(len(result["unfinished"]), 2)
        self.assertIn("报告未完成", report.markdown(result, "native"))

    def test_failed_loader_is_counted_and_not_a_business_test(self):
        result = report.summarize([
            event("suite", 0, suite={"id": 0, "path": "test/failed.dart"}),
            event("testStart", 0, test={"id": 1, "suiteID": 0, "name": "loading failed"}),
            event("testDone", 120, testID=1, result="error", hidden=True),
            event("done", 121, success=False),
        ])
        self.assertEqual(result["suites"][0]["failed"], 1)
        self.assertEqual(result["suites"][0]["tests"], 0)
        self.assertEqual(result["cases"], [])

    def test_visible_test_named_loading_is_not_a_loader(self):
        result = report.summarize([
            event("suite", 0, suite={"id": 0, "path": "test/a.dart"}),
            event("testStart", 0, test={"id": 1, "suiteID": 0, "name": "loading 内容切换"}),
            event("testDone", 30, testID=1, result="success", hidden=False),
            event("done", 31, success=True),
        ])
        self.assertEqual(result["suites"][0]["load_ms"], 0)
        self.assertEqual(result["suites"][0]["execution_ms"], 30)
        self.assertEqual(result["suites"][0]["tests"], 1)

    def test_skip_and_hook_are_not_counted_as_normal_execution_cases(self):
        result = report.summarize([
            event("suite", 0, suite={"id": 0, "path": "test/a.dart"}),
            event("testStart", 0, test={"id": 1, "suiteID": 0, "name": "setUpAll"}),
            event("testDone", 50, testID=1, result="success", hidden=True),
            event("testStart", 50, test={"id": 2, "suiteID": 0, "name": "skip"}),
            event("testDone", 50, testID=2, result="success", skipped=True),
            event("done", 51, success=True),
        ])
        self.assertEqual(result["suites"][0]["execution_ms"], 50)
        self.assertEqual(result["suites"][0]["tests"], 1)
        self.assertEqual(result["suites"][0]["skipped"], 1)

    def test_cli_writes_reports_and_job_summary_without_masking_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            events = root / "events.jsonl"
            events.write_text("\n".join(self.fixture(failed=True)), encoding="utf-8")
            summary = root / "job-summary.md"
            output = root / "reports"
            result = subprocess.run([sys.executable, str(Path(report.__file__)), str(events),
                                     "--group", "fast", "--output", str(output)],
                                    env=dict(os.environ, GITHUB_STEP_SUMMARY=str(summary), PYTHONIOENCODING="utf-8"),
                                    capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(json.loads((output / "timings.json").read_text(encoding="utf-8"))["success"])
            self.assertEqual(summary.read_text(encoding="utf-8"), (output / "summary.md").read_text(encoding="utf-8"))
            missing = subprocess.run([sys.executable, str(Path(report.__file__)), str(root / "missing"),
                                      "--group", "fast", "--output", str(output)], capture_output=True)
            self.assertEqual(missing.returncode, 1)


if __name__ == "__main__":
    unittest.main()
