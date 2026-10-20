"""拒绝截断、缺帧、错误模式或版本混杂的性能证据。"""

import base64
import copy
import json
import unittest

from reader_layout_profile import PREFIX, RecordDecoder, compare, summarize


class ReaderLayoutProfileTests(unittest.TestCase):
    def setUp(self):
        self.records = [
            {"kind": "environment", "schema": 1, "mode": "profile", "rounds": 1,
             "cases": ["text"], "label": "baseline", "revision": "abc"},
            {"kind": "fixture", "case": "text", "chunks": 1, "utf16": 4},
            {"kind": "fixtureChunk", "case": "text", "index": 0,
             "base64": base64.b64encode("甲😀乙".encode()).decode()},
            {"kind": "sample", "case": "text", "round": 1, "utf16": 4,
             "frames": 1, "firstPageReadyUs": 10, "firstPageFrameSubmittedUs": 20,
             "chapterWallUs": 30, "ffi": None},
            {"kind": "frame", "case": "text", "round": 1,
             "buildUs": 4, "rasterUs": 5, "totalSpanUs": 9},
            {"kind": "complete", "label": "baseline", "revision": "abc"},
        ]

    def summary(self, records=None):
        return summarize([PREFIX + json.dumps(r) for r in (records or self.records)])

    def test_valid_profile_preserves_input_digest_and_raw_frames(self):
        result = self.summary()
        self.assertEqual(result["cases"]["text"]["utf16"], 4)
        self.assertEqual(len(result["cases"]["text"]["sourceSha256"]), 64)
        self.assertEqual(result["frames"][0]["rasterUs"], 5)

    def test_debug_is_rejected(self):
        self.records[0]["mode"] = "debug"
        with self.assertRaisesRegex(ValueError, "profile"):
            self.summary()

    def test_incomplete_or_error_run_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "未成功完成"):
            self.summary(self.records[:-1])
        self.records.insert(-1, {"kind": "error"})
        with self.assertRaisesRegex(ValueError, "未成功完成"):
            self.summary()

    def test_truncated_or_duplicate_fixture_is_rejected(self):
        for index in (1, 2):
            with self.subTest(index=index):
                records = copy.deepcopy(self.records)
                records.insert(index, records[index])
                with self.assertRaises(ValueError):
                    self.summary(records)
        self.records[1]["chunks"] = 2
        with self.assertRaisesRegex(ValueError, "截断"):
            self.summary()

    def test_missing_round_or_frame_is_rejected(self):
        self.records[0]["rounds"] = 2
        with self.assertRaisesRegex(ValueError, "轮次"):
            self.summary()
        self.records[0]["rounds"] = 1
        with self.assertRaisesRegex(ValueError, "帧记录"):
            self.summary([r for r in self.records if r["kind"] != "frame"])

    def test_mismatched_revision_or_coordinates_are_rejected(self):
        self.records[-1]["revision"] = "changed"
        with self.assertRaisesRegex(ValueError, "版本"):
            self.summary()
        self.records[-1]["revision"] = "abc"
        self.records[1]["utf16"] = 3
        with self.assertRaisesRegex(ValueError, "UTF-16"):
            self.summary()

    def test_inconsistent_timestamps_are_rejected(self):
        self.records[3]["firstPageFrameSubmittedUs"] = 9
        with self.assertRaisesRegex(ValueError, "计时"):
            self.summary()

    def test_missing_case_is_rejected(self):
        self.records[0]["cases"].append("missing")
        with self.assertRaisesRegex(ValueError, "场景"):
            self.summary()

    def test_transport_decodes_unicode_and_detects_missing_chunk(self):
        encoded = base64.b64encode(json.dumps({"kind": "text", "text": "甲😀乙"}, ensure_ascii=False).encode()).decode()
        packets = [PREFIX + json.dumps({"record": 0, "chunk": index, "total": 2, "payload": payload})
                   for index, payload in enumerate((encoded[:20], encoded[20:]))]
        decoder = RecordDecoder()
        self.assertIsNone(decoder.feed(packets[0]))
        self.assertEqual(decoder.feed(packets[1])["text"], "甲😀乙")
        with self.assertRaisesRegex(ValueError, "缺失或乱序"):
            RecordDecoder().feed(packets[1])

    def test_compare_keeps_real_delta(self):
        baseline = self.summary()
        current = copy.deepcopy(baseline)
        current["environment"]["revision"] = "new"
        current["cases"]["text"]["metrics"]["chapterWallUs"]["p50"] = 15
        metric = compare(baseline, current)["cases"]["text"]["chapterWallUs"]
        self.assertEqual(metric["delta"], -15)
        self.assertEqual(metric["deltaPercent"], -50)

    def test_compare_rejects_different_geometry_or_text(self):
        baseline = self.summary()
        current = copy.deepcopy(baseline)
        current["environment"]["width"] = 999
        with self.assertRaisesRegex(ValueError, "配置不同"):
            compare(baseline, current)
        current = copy.deepcopy(baseline)
        current["cases"]["text"]["sourceSha256"] = "different"
        with self.assertRaisesRegex(ValueError, "正文不同"):
            compare(baseline, current)


if __name__ == "__main__":
    unittest.main()
