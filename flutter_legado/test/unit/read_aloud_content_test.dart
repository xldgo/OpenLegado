import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';

void main() {
  test('UTF-8 字节分片保持原文与 UTF-16 范围，不拆组合字符', () {
    final text = '${'甲' * 340}😀${'乙' * 400} é 👨‍👩‍👧‍👦 English words。末尾';
    final parts = splitSpeechRequests(text, limit: 4000, maxUtf8Bytes: 1024);
    expect(parts.map((p) => p.text).join(), text);
    final boundaries = {0};
    var offset = 0;
    for (final cluster in text.characters) {
      offset += cluster.length;
      boundaries.add(offset);
    }
    for (final part in parts) {
      expect(utf8.encode(part.text).length, lessThanOrEqualTo(1024));
      expect(
        text.substring(part.start, part.start + part.text.length),
        part.text,
      );
      expect(boundaries.contains(part.start), isTrue);
      expect(boundaries.contains(part.start + part.text.length), isTrue);
    }
    expect(parts.first.text, '${'甲' * 340}😀');
    expect(parts[1].start, 342);
  });
  test('同时满足字符与字节上限，非法字节上限和超长字形簇明确失败', () {
    final ascii = splitSpeechRequests(
      'x' * 2000,
      limit: 4000,
      maxUtf8Bytes: 1024,
    );
    expect(ascii.map((p) => p.text.length), [1024, 976]);
    final both = splitSpeechRequests('甲乙丙丁', limit: 2, maxUtf8Bytes: 5);
    expect(both.map((p) => p.text), ['甲', '乙', '丙', '丁']);
    expect(
      () => splitSpeechRequests('甲', limit: 4000, maxUtf8Bytes: 0),
      throwsArgumentError,
    );
    expect(
      () => splitSpeechRequests(
        'e${'\u0301' * 600}',
        limit: 4000,
        maxUtf8Bytes: 1024,
      ),
      throwsStateError,
    );
  });

  test('默认整段与符号单元保留连续标点和原文UTF-16起点', () {
    const text = ' 甲😀？！乙。\r\n 丙；丁 ';
    final full = splitReadAloudContent(text);
    expect(full.map((p) => p.text), ['甲😀？！乙。', '丙；丁']);
    final units = splitReadAloudContent(
      text,
      mode: ReadAloudSplitMode.symbols,
      symbols: '？！。；',
    );
    expect(units.map((p) => p.text), ['甲😀？！', '乙。', '丙；', '丁']);
    for (final p in units) {
      expect(text.substring(p.start, p.start + p.text.length), p.text);
    }
    expect(
      splitReadAloudContent(
        '甲。乙',
        mode: ReadAloudSplitMode.symbols,
        symbols: '',
      ).length,
      2,
    );
  });
  test('页面单元只消费完整真实范围，空白间隙允许，缺页或重叠拒绝', () {
    const text = '甲😀乙\n丙丁';
    final units = splitReadAloudContent(
      text,
      mode: ReadAloudSplitMode.page,
      pages: [(start: 0, end: 4), (start: 5, end: 7)],
    );
    expect(units, [(start: 0, text: '甲😀乙'), (start: 5, text: '丙丁')]);
    expect(
      () => splitReadAloudContent(text, mode: ReadAloudSplitMode.page),
      throwsStateError,
    );
    expect(
      () => splitReadAloudContent(
        text,
        mode: ReadAloudSplitMode.page,
        pages: [(start: 0, end: 4)],
      ),
      throwsStateError,
    );
    expect(
      () => splitReadAloudContent(
        text,
        mode: ReadAloudSplitMode.page,
        pages: [(start: 0, end: 4), (start: 3, end: 7)],
      ),
      throwsStateError,
    );
  });
  test('长度分片优先句末与结束引号，再词边界，超长词才截断', () {
    expect(splitSpeechRequests('甲乙。丙丁戊己庚', limit: 5).map((p) => p.text), [
      '甲乙。',
      '丙丁戊己庚',
    ]);
    expect(splitSpeechRequests('“甲。”乙丙丁戊', limit: 6).first.text, '“甲。”');
    expect(
      splitSpeechRequests('alpha beta gamma', limit: 12).first.text,
      'alpha beta ',
    );
    expect(splitSpeechRequests('abcdefgh', limit: 3).map((p) => p.text), [
      'abc',
      'def',
      'gh',
    ]);
  });
  test('各种长度下代理对、组合字符、ZWJ均完整，分片范围没有漏字重复', () {
    final text = '${'甲😀é👨‍👩‍👧‍👦。 English word! ' * 8}尾文';
    for (var limit = 12; limit < 60; limit++) {
      final parts = splitSpeechRequests(text, limit: limit);
      expect(parts.map((p) => p.text).join(), text);
      for (final part in parts) {
        expect(part.text.length, lessThanOrEqualTo(limit));
        expect(
          text.substring(part.start, part.start + part.text.length),
          part.text,
        );
      }
    }
    expect(() => splitSpeechRequests('甲', limit: 0), throwsArgumentError);
    expect(() => splitSpeechRequests('😀', limit: 1), throwsStateError);
  });
}
