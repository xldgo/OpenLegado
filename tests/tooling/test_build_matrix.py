"""固定当前 CI 已明确的 ABI、模式与 QuickJS 策略。"""

import argparse
import unittest

from support import ROOT
from tooling.common import ToolError
from tooling.policy import load_policy, parse_abis, select_target


class MatrixTests(unittest.TestCase):
    def setUp(self):
        self.policy = load_policy(ROOT)

    def test_approved_matrix(self):
        expected = {
            "arm64-v8a": ("aarch64-linux-android", {"debug": ["quickjs"], "release": ["quickjs"]}),
            "x86_64": ("x86_64-linux-android", {"debug": ["quickjs"], "release": ["quickjs"]}),
            "armeabi-v7a": ("armv7-linux-androideabi", {"release": []}),
        }
        self.assertEqual(set(self.policy["targets"]), set(expected))
        self.assertEqual((self.policy["clangApiLevel"], self.policy["maxPageSize"]), (21, 16384))
        for abi, (triple, features) in expected.items():
            with self.subTest(abi=abi):
                self.assertEqual(self.policy["targets"][abi]["targetTriple"], triple)
                self.assertEqual(self.policy["targets"][abi]["features"], features)

    def test_armv7_debug_and_unknown_abi_profile_rejected(self):
        for abi, profile in (("armeabi-v7a", "debug"), ("unknown", "release"), ("arm64-v8a", "profile")):
            with self.subTest(abi=abi, profile=profile), self.assertRaises(ToolError):
                select_target(self.policy, abi, profile)

    def test_empty_duplicate_abis_rejected(self):
        for value in ("", ",", "arm64-v8a,", "arm64-v8a,arm64-v8a", "arm64-v8a,   "):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                parse_abis(value)
        self.assertEqual(parse_abis(" arm64-v8a, x86_64 "), ("arm64-v8a", "x86_64"))


if __name__ == "__main__":
    unittest.main()
