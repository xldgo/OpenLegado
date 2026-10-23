import 'dart:convert';
import 'dart:io';

import 'package:flutter_legado/src/domain/contracts/read_aloud_planner.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';

/// 迁移前录制的输入/范围快照；这里只查表，不实现切分算法。
class FixtureReadAloudPlanner implements ReadAloudPlanner {
  static final _cases = (jsonDecode(
    File('test/fixtures/read_aloud_partition_cases.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  @override
  Future<List<ReadAloudUnit>> plan(
    String content, {
    ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
    String symbols = defaultReadAloudSplitSymbols,
    List<ReadAloudPageRange> pages = const [],
  }) async {
    final matching = _cases.where(
      (c) =>
          c['kind'] == 'plan' &&
          c['text'] == content &&
          c['mode'] == mode.name &&
          (mode != ReadAloudSplitMode.symbols || c['symbols'] == symbols) &&
          (mode != ReadAloudSplitMode.page ||
              jsonEncode(c['pages']) ==
                  jsonEncode([
                    for (final p in pages) {'start': p.start, 'end': p.end},
                  ])),
    );
    if (matching.isEmpty) {
      throw StateError(
        '缺少朗读计划夹具: ${jsonEncode([content, mode.name, symbols, pages.toString()])}',
      );
    }
    final c = matching.first;
    if (c.containsKey('error')) throw StateError(c['error'] as String);
    return [
      for (final u in c['units'] as List)
        ReadAloudUnit(
          start: u['start'] as int,
          text: content.substring(u['start'] as int, u['end'] as int),
          sourceParagraphIndex: u['paragraph'] as int,
          isParagraphEnd: u['last'] as bool,
        ),
    ];
  }

  @override
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  ) async {
    final limits = await MockCloudTtsRepository().speechLimits(provider);
    return [
      for (final text in texts)
        _parts(text, limits.maxUtf16Units, limits.maxUtf8Bytes),
    ];
  }

  List<SpeechRequestPart> _parts(String text, int limit, int? bytes) {
    final matching = _cases.where(
      (c) =>
          c['kind'] == 'partition' &&
          c['text'] == text &&
          c['limit'] == limit &&
          c['bytes'] == bytes,
    );
    if (matching.isEmpty) {
      throw StateError('缺少请求分片夹具: ${jsonEncode([text, limit, bytes])}');
    }
    final c = matching.first;
    if (c.containsKey('error')) throw StateError(c['error'] as String);
    return [
      for (final r in c['ranges'] as List)
        (
          start: r['start'] as int,
          text: text.substring(r['start'] as int, r['end'] as int),
        ),
    ];
  }
}
