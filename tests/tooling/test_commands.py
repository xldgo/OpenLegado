"""原生子进程保持参数字面值，拒绝 Windows 批处理拼接。"""

import json
import os
import sys
import unittest

from support import ROOT
from tooling.common import CommandError, ToolError, run_command


class CommandTests(unittest.TestCase):
    def test_native_arguments_with_spaces_and_shell_metacharacters(self):
        values = ["中文 空格", "a&b", "%PATH%", "$(echo secret)", 'a"b']
        output = run_command([sys.executable, "-c", "import json,sys;print(json.dumps(sys.argv[1:]))", *values],
                             ROOT, dict(os.environ), capture=True)
        self.assertEqual(json.loads(output), values)

    def test_nonzero_exit_code_preserved(self):
        with self.assertRaises(CommandError) as result:
            run_command([sys.executable, "-c", "raise SystemExit(37)"], ROOT, dict(os.environ))
        self.assertEqual(result.exception.code, 37)

    def test_batch_script_rejected_before_execution(self):
        with self.assertRaisesRegex(ToolError, "批处理"):
            run_command(["unexpected.cmd", "a&b"], ROOT, dict(os.environ))


if __name__ == "__main__":
    unittest.main()
