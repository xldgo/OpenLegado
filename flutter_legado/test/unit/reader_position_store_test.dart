import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/services/reader_position_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('未标记旧页码不会被解释为原文字符偏移', () async {
    expect(
      await ReaderPositionStore().read(
        'book',
        chapterIndex: 2,
        legacyPageIndex: 5,
      ),
      isNull,
    );
  });
  test('锚点重启后可读，并拒绝外部改变的旧进度与错误坐标格式', () async {
    final store = ReaderPositionStore();
    await store.save(
      'book',
      const ReaderSourceAnchor(
        chapterId: 'chapter-url',
        chapterIndex: 2,
        sourceOffset: 1234,
        legacyPageIndex: 5,
      ),
    );
    final restored = await ReaderPositionStore().read(
      'book',
      chapterIndex: 2,
      legacyPageIndex: 5,
    );
    expect(restored?.sourceOffset, 1234);
    expect(restored?.chapterId, 'chapter-url');
    expect(
      await store.read('book', chapterIndex: 3, legacyPageIndex: 5),
      isNull,
    );
    expect(
      await store.read('book', chapterIndex: 2, legacyPageIndex: 6),
      isNull,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ReaderPositionStore.keyFor('book'),
      jsonEncode({
        'version': 1,
        'sourceOffset': 5,
        'chapterIndex': 2,
        'legacyPageIndex': 5,
      }),
    );
    expect(
      await store.read('book', chapterIndex: 2, legacyPageIndex: 5),
      isNull,
    );
    await prefs.setString(ReaderPositionStore.keyFor('book'), '{');
    expect(
      await store.read('book', chapterIndex: 2, legacyPageIndex: 5),
      isNull,
    );
  });
}
