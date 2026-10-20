"""签名证书输出解析及实际验签命令边界，不读取生产源码作为断言。"""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from support import write
from tooling import android_app as app
from tooling.common import CommandError, ToolError


CERTIFICATE = "0123456789abcdef" * 4
OTHER = "fedcba9876543210" * 4


class ApkSignatureTests(unittest.TestCase):
    def test_real_36_and_37_output_fixtures_have_same_certificate(self):
        folder = Path(__file__).parent / "fixtures/apksigner"
        expected = {"05e682223d6c00f3d6ccbeeb4460a14c99916f1ff4a74e44e2d23abf76298466"}
        for version in ("36", "37"):
            with self.subTest(version=version):
                output = (folder / f"build-tools-{version}.txt").read_text(encoding="utf-8")
                self.assertEqual(app.parse_apk_signer_certificates(output), expected)

    def test_old_and_new_signer_prefixes_have_same_identity(self):
        # 摘要使用测试值；行格式取自旧版本输出及用户提供的37版本诊断。
        for prefix in ("Signer #1", "V1.0 Signer:", "V2 Signer:", "V3.0 Signer:", "V3.1 Signer:"):
            with self.subTest(prefix=prefix):
                output = (f"{prefix} certificate DN: CN=测试\r\n"
                          f"{prefix} certificate SHA-256 digest: {CERTIFICATE}\r\n"
                          f"{prefix} public key SHA-256 digest: {OTHER}\r\n")
                self.assertEqual(app.parse_apk_signer_certificates(output), {CERTIFICATE})

    def test_deduplicates_schemes_and_normalizes_case_and_colons(self):
        formatted = ":".join(CERTIFICATE[i:i + 2] for i in range(0, 64, 2)).upper()
        output = (f"V2 Signer: certificate SHA-256 digest: {formatted}\n"
                  f"V3.0 Signer: certificate SHA-256 digest: {CERTIFICATE}\n")
        self.assertEqual(app.parse_apk_signer_certificates(output), {CERTIFICATE})

    def test_source_stamp_and_public_key_are_not_apk_signer_identity(self):
        output = (f"Source Stamp Signer certificate SHA-256 digest: {OTHER}\n"
                  f"Signer #1 public key SHA-256 digest: {OTHER}\n"
                  f"Source Stamp Signer: certificate SHA-256 digest: {OTHER}\n")
        with self.assertRaisesRegex(ToolError, "未解析到"):
            app.parse_apk_signer_certificates(output)
        self.assertEqual(app.parse_apk_signer_certificates(
            output + f"V3.0 Signer: certificate SHA-256 digest: {CERTIFICATE}\n"), {CERTIFICATE})

    def test_missing_and_malformed_digests_fail_closed(self):
        for output in ("", "Verified successfully\n"):
            with self.subTest(output=output), self.assertRaisesRegex(ToolError, "未解析到"):
                app.parse_apk_signer_certificates(output)
        for value in ("", CERTIFICATE[:-1], CERTIFICATE + "0", "g" * 64, CERTIFICATE + " extra"):
            with self.subTest(value=value), self.assertRaisesRegex(ToolError, "格式无效"):
                app.parse_apk_signer_certificates(
                    f"Signer #1 certificate SHA-256 digest: {CERTIFICATE}\n"
                    f"V2 Signer: certificate SHA-256 digest: {value}\n")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="APK签名 中文 空格 ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sdk = self.root / "Android SDK"
        for version in ("36.0.0", "37.0.0", "38.0.0-rc1"):
            write(self.sdk / "build-tools" / version / "lib/apksigner.jar", b"fixture")
        self.apk = self.root / "测试.apk"

    def verify(self, output, expected=CERTIFICATE):
        with patch.dict(os.environ, {"ANDROID_SDK_ROOT": str(self.sdk)}), \
                patch.object(app, "find_tool", return_value=Path("java")), \
                patch.object(app, "run_command", return_value=output) as run:
            app.verify_apk_signature(self.root, self.apk, expected)
        return run

    def test_verifier_uses_highest_stable_jar_and_accepts_same_cert_in_multiple_schemes(self):
        output = (f"V2 Signer: certificate SHA-256 digest: {CERTIFICATE}\n"
                  f"V3.0 Signer: certificate SHA-256 digest: {CERTIFICATE}\n")
        formatted = ":".join(CERTIFICATE[i:i + 2] for i in range(0, 64, 2)).upper()
        run = self.verify(output, formatted)
        self.assertEqual(run.call_args.args[0], [Path("java"), "-jar",
            self.sdk / "build-tools/37.0.0/lib/apksigner.jar", "verify", "--print-certs", self.apk])

    def test_mismatch_and_multiple_distinct_signers_are_rejected_with_actual_fingerprints(self):
        for output in (f"V2 Signer: certificate SHA-256 digest: {OTHER}\n",
                       f"Signer #1 certificate SHA-256 digest: {CERTIFICATE}\n"
                       f"Signer #2 certificate SHA-256 digest: {OTHER}\n"):
            with self.subTest(output=output), self.assertRaisesRegex(ToolError, "不匹配") as error:
                self.verify(output)
            self.assertIn(CERTIFICATE, str(error.exception))
            self.assertIn(OTHER, str(error.exception))

    def test_missing_certificate_reports_parser_and_jar_instead_of_mismatch(self):
        with self.assertRaisesRegex(ToolError, "未解析到") as error:
            self.verify("Verified successfully")
        self.assertNotIn("不匹配", str(error.exception))
        self.assertIn("37.0.0", str(error.exception))

    def test_apksigner_failure_is_not_replaced_by_parser_error(self):
        with patch.dict(os.environ, {"ANDROID_SDK_ROOT": str(self.sdk)}), \
                patch.object(app, "find_tool", return_value=Path("java")), \
                patch.object(app, "run_command", side_effect=CommandError("java", 7)):
            with self.assertRaises(CommandError) as error:
                app.verify_apk_signature(self.root, self.apk, CERTIFICATE)
        self.assertEqual(error.exception.code, 7)

    def test_invalid_expected_fingerprint_is_rejected_before_invoking_java(self):
        with patch.object(app, "run_command") as run, self.assertRaisesRegex(ToolError, "64位"):
            app.verify_apk_signature(self.root, self.apk, "invalid")
        run.assert_not_called()
