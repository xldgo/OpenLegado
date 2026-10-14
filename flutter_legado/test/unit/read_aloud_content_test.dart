import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';

void main() {
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
