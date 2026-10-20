import 'package:characters/characters.dart';

import 'dart:convert';

/// 用户划分粒度与服务商请求长度分片分别建模。— Codex + UI
enum ReadAloudSplitMode { paragraph, symbols, page }

const readAloudSplitSymbols = '。！？…；，、：.!?;,:';
final _latinWord = RegExp(r'[A-Za-z0-9]');
final _decimalDigit = RegExp(r'^[0-9]$');

const defaultReadAloudSplitSymbols = '。！？…';
typedef ReadAloudUnit = ({int start, String text});
typedef ReadAloudPageRange = ({int start, int end});

/// 页面模式必须使用当前章节的完整真实分页范围，不猜测页宽或字数。
List<ReadAloudUnit> splitReadAloudContent(
  String content, {
  ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
  String symbols = defaultReadAloudSplitSymbols,
  List<ReadAloudPageRange>? pages,
}) {
  if (mode == ReadAloudSplitMode.page) {
    if (pages == null || pages.isEmpty) {
      throw StateError('请先在阅读器完成本章分页，再使用整页朗读');
    }
    final boundaries = <int>{0};
    var offset = 0;
    for (final cluster in content.characters) {
      offset += cluster.length;
      boundaries.add(offset);
    }
    var previous = 0;
    final units = <ReadAloudUnit>[];
    for (final page in pages) {
      if (page.start < previous ||
          page.end < page.start ||
          page.end > content.length ||
          !boundaries.contains(page.start) ||
          !boundaries.contains(page.end) ||
          content.substring(previous, page.start).trim().isNotEmpty) {
        throw StateError('朗读页面范围与当前章节不一致');
      }
      _appendTrimmed(units, content, page.start, page.end);
      previous = page.end;
    }
    if (content.substring(previous).trim().isNotEmpty) {
      throw StateError('本章分页尚未完成');
    }
    return units;
  }
  final paragraphs = <ReadAloudUnit>[];
  var start = 0;
  for (final separator in RegExp(
    r'\r\n|[\r\n\u2028\u2029]',
  ).allMatches(content)) {
    _appendTrimmed(paragraphs, content, start, separator.start);
    start = separator.end;
  }
  _appendTrimmed(paragraphs, content, start, content.length);
  if (mode != ReadAloudSplitMode.symbols) return paragraphs;
  final selected = symbols
      .split('')
      .where(readAloudSplitSymbols.contains)
      .toSet();
  if (selected.isEmpty) selected.addAll(defaultReadAloudSplitSymbols.split(''));
  return [for (final p in paragraphs) ..._splitSymbols(p, selected)];
}

void _appendTrimmed(
  List<ReadAloudUnit> units,
  String content,
  int start,
  int end,
) {
  final raw = content.substring(start, end);
  final text = raw.trim();
  if (text.isNotEmpty) {
    units.add((start: start + raw.indexOf(text), text: text));
  }
}

List<ReadAloudUnit> _splitSymbols(ReadAloudUnit unit, Set<String> symbols) {
  final result = <ReadAloudUnit>[];
  var start = 0, index = 0;
  while (index < unit.text.length) {
    if (!symbols.contains(unit.text[index])) {
      index++;
      continue;
    }
    var end = index + 1;
    while (end < unit.text.length && symbols.contains(unit.text[end])) {
      end++;
    }
    // 与上游一致：连续选中标点保留在前一个单元，不额外裁剪偏移。
    result.add((
      start: unit.start + start,
      text: unit.text.substring(start, end),
    ));
    start = end;
    index = end;
  }
  if (start < unit.text.length) {
    result.add((start: unit.start + start, text: unit.text.substring(start)));
  }
  return result;
}

/// 分片携带文本中的UTF-16范围，拼接严格还原输入；先句末、再词边界、最后字形簇。
List<ReadAloudUnit> splitSpeechRequests(
  String text, {
  required int limit,
  int? maxUtf8Bytes,
}) {
  if (maxUtf8Bytes != null && maxUtf8Bytes < 1) {
    throw ArgumentError.value(maxUtf8Bytes, 'maxUtf8Bytes');
  }
  if (limit < 1) throw ArgumentError.value(limit, 'limit');
  final clusters = text.characters.toList();
  final offsets = <int>[0];
  final byteOffsets = <int>[0];
  for (final c in clusters) {
    if (c.length > limit) throw StateError('单个字形簇超过云端朗读长度限制');
    offsets.add(offsets.last + c.length);
    if (maxUtf8Bytes != null) {
      final bytes = utf8.encode(c).length;
      if (bytes > maxUtf8Bytes) throw StateError('单个字形簇超过云端朗读字节限制');
      byteOffsets.add(byteOffsets.last + bytes);
    }
  }
  final result = <ReadAloudUnit>[];
  var start = 0;
  while (start < clusters.length) {
    var end = start;
    while (end < clusters.length &&
        offsets[end + 1] - offsets[start] <= limit &&
        (maxUtf8Bytes == null ||
            byteOffsets[end + 1] - byteOffsets[start] <= maxUtf8Bytes)) {
      end++;
    }
    var cut = end;
    if (end < clusters.length) {
      int? sentence, word;
      for (var i = start + 1; i <= end; i++) {
        final left = clusters[i - 1], right = clusters[i];
        var punctuation = i - 1;
        while (punctuation >= start &&
            '”’」』）)]'.contains(clusters[punctuation])) {
          punctuation--;
        }
        if (punctuation >= start &&
            '。！？…!?；;.'.contains(clusters[punctuation]) &&
            !'。！？…!?；;.”’」』）)]'.contains(right) &&
            !(clusters[punctuation] == '.' &&
                punctuation > start &&
                _decimalDigit.hasMatch(clusters[punctuation - 1]) &&
                _decimalDigit.hasMatch(right))) {
          sentence = i;
        }
        if (!'。！？…!?；;.”’」』）)]'.contains(right) &&
            (left.trim().isEmpty ||
                right.trim().isEmpty ||
                (!_latinWord.hasMatch(left) && !_latinWord.hasMatch(right)))) {
          word = i;
        }
      }
      cut = sentence ?? word ?? end;
    }
    result.add((
      start: offsets[start],
      text: text.substring(offsets[start], offsets[cut]),
    ));
    start = cut;
  }
  return result;
}
