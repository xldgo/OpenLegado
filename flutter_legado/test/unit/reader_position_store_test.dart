import 'package:flutter_legado/src/domain/models/reader_source_anchor.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/reader_position_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('未标记旧页码不会被解释为原文字符偏移', () async {
    expect(await ReaderPositionStore().read('book', chapterIndex: 2), isNull);
  });
  test('锚点重启后可读，记录不保存页码，并拒绝错误章节与坐标格式', () async {
    final store = ReaderPositionStore();
    await store.save(
      'book',
      const ReaderSourceAnchor(
        chapterId: 'chapter-url',
        chapterIndex: 2,
        sourceOffset: 1234,
      ),
    );
    final restored = await ReaderPositionStore().read('book', chapterIndex: 2);
    expect(restored?.sourceOffset, 1234);
    expect(restored?.chapterId, 'chapter-url');
    expect(await store.read('book', chapterIndex: 3), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ReaderPositionStore.keyFor('book')),
      isNot(contains('legacyPageIndex')),
    );
    await prefs.setString(
      ReaderPositionStore.keyFor('book'),
      jsonEncode({'version': 1, 'sourceOffset': 5, 'chapterIndex': 2}),
    );
    expect(await store.read('book', chapterIndex: 2), isNull);
    await prefs.setString(ReaderPositionStore.keyFor('book'), '{');
    expect(await store.read('book', chapterIndex: 2), isNull);
  });
}
