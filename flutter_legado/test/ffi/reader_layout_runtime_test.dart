@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/errors/reader_layout_cancelled.dart';
import 'package:flutter_legado/src/domain/services/reader_layout_session.dart';
import 'package:flutter_legado/src/data/services/native_reader_layout_transport.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';

import '../helpers/native_reader_layout.dart';

void _golden(Object? actual, Object? expected, String path) {
  if (actual is num && expected is num) {
    expect(
      actual,
      closeTo(expected, 0.0001 + expected.abs() * 0.0000003),
      reason: path,
    );
  } else if (actual is Map && expected is Map) {
    expect(actual.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      _golden(actual[key], expected[key], '$path.$key');
    }
  } else if (actual is List && expected is List) {
    expect(actual.length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      _golden(actual[i], expected[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  setUpNativeReaderLayout();
  test('真实会话达到容量上限，取消与失败后立即归还名额', () async {
    const transport = NativeReaderLayoutTransport();
    final config = <String, Object?>{
      'chapterIndex': 0,
      'chapterTitle': '容量测试',
      'viewportWidthPx': 320,
      'viewportHeightPx': 480,
      'paddingLeftPx': 0,
      'paddingRightPx': 0,
      'paddingTopPx': 0,
      'paddingBottomPx': 0,
      'lineHeightPx': 24,
      'baselineOffsetPx': 18,
    };
    final handles = <Object>[];
    try {
      for (var i = 0; i < 8; i++) {
        handles.add((await transport.begin(config)).sessionId);
      }
      await expectLater(transport.begin(config), throwsA(isA<AppException>()));
      await transport.cancel(handles.removeLast());
      final replacement = (await transport.begin(config)).sessionId;
      handles.add(replacement);
      await expectLater(
        transport.push(
          replacement,
          List.generate(33, (_) => {'type': 'pageBreak'}),
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('超过32'),
          ),
        ),
      );
      // 失败释放Rust许可；显式cancel也释放Dart持有的Opaque引用。
      await transport.cancel(handles.removeLast());
      final next = (await transport.begin(config)).sessionId;
      handles.add(next);
      expect((await transport.finish(next)).pages, isEmpty);
      handles.remove(next);
    } finally {
      for (final handle in handles) {
        await transport.cancel(handle);
      }
    }
  });
  test('代表性文本与行内内容穿过正式FRB后保持字段和字形数据', () async {
    final fixture = jsonDecode(
      File('../rust/legado-ffi/tests/fixtures/layout_transport.json')
          .readAsStringSync(),
    ) as Map;
    final reference = jsonDecode(
      utf8.decode(
        gzip.decode(
          File('../rust/legado-layout/tests/fixtures/md3.json.gz')
              .readAsBytesSync(),
        ),
      ),
    ) as Map;
    final expected = {
      for (final c in reference['cases'] as List) c['name']: c['expected'],
    };
    // 全量260组算法样例由Rust测试覆盖；这里只验证两种代表载荷的跨语言映射。
    for (final c in (fixture['cases'] as List).take(2)) {
      final input = c['input'] as Map;
      final session = ReaderLayoutSession(
        transport: const NativeReaderLayoutTransport(),
        config: Map<String, Object?>.from(input['config'] as Map),
      );
      try {
        final pages = <Map<String, dynamic>>[];
        final blocks = (input['blocks'] as List)
            .map((b) => Map<String, Object?>.from(b as Map))
            .toList();
        for (var i = 0; i < blocks.length; i += 32) {
          pages.addAll(
            (await session.push(
              blocks.sublist(i, (i + 32).clamp(0, blocks.length)),
            )).pages,
          );
        }
        pages.addAll((await session.finish()).pages);
        _golden(pages, expected[c['name']], c['name'] as String);
        expect(session.closed, isTrue, reason: c['name'] as String);
      } finally {
        await session.cancel();
      }
    }
  });
  test('异步创建前取消及完成后重复取消正确释放句柄', () async {
    final config = <String, Object?>{
      'chapterIndex': 0,
      'chapterTitle': '测试',
      'viewportWidthPx': 320,
      'viewportHeightPx': 480,
      'paddingLeftPx': 10,
      'paddingTopPx': 10,
      'paddingRightPx': 10,
      'paddingBottomPx': 10,
      'lineHeightPx': 24,
      'baselineOffsetPx': 18,
    };
    for (var i = 0; i < 2; i++) {
      final session = ReaderLayoutSession(
        config: config,
        transport: const NativeReaderLayoutTransport(),
      );
      if (i.isEven) {
        await session.cancel();
        await expectLater(
          session.push([]),
          throwsA(isA<ReaderLayoutCancelled>()),
        );
      } else {
        await session.finish();
        await session.cancel();
      }
    }
  });
}
