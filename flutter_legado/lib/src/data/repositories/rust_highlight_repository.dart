import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/models/book_highlight.dart';
import '../bridge/rust_json_decode.dart';

/// 正式标注直接使用现有FRB，传输JSON不进入页面。— Codex + Bridge
final class RustHighlightRepository implements HighlightRepository {
  const RustHighlightRepository();

  List<BookHighlight> _decode(String json) =>
      decodeRustJsonList(json, 'highlight').indexed.map((entry) {
        final (index, value) = entry;
        if (value is! Map<String, dynamic>) {
          throw FormatException('标注列表第${index + 1}项必须是对象');
        }
        try {
          return BookHighlight.fromJson(value);
        } on TypeError catch (error) {
          throw FormatException('标注列表第${index + 1}项字段类型无效：$error');
        }
      }).toList();

  @override
  Future<int> highlightAdd(BookHighlight highlight) async {
    final time = await bridge.highlightAdd(
      highlightJson: jsonEncode(highlight.toJson()),
    );
    if (time <= 0) throw StateError('保存标注未返回有效主键');
    return time;
  }

  @override
  Future<bool> highlightDelete({required int time}) =>
      bridge.highlightDelete(time: time);

  @override
  Future<int> highlightDeleteByBook({required String bookUrl}) =>
      bridge.highlightDeleteByBook(bookUrl: bookUrl);

  @override
  Future<List<BookHighlight>> highlightListByBook({
    required String bookUrl,
  }) async => _decode(await bridge.highlightListByBook(bookUrl: bookUrl));

  @override
  Future<List<BookHighlight>> highlightListByChapter({
    required String bookUrl,
    required int chapterIndex,
  }) async => _decode(
    await bridge.highlightListByChapter(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    ),
  );

  @override
  Future<List<BookHighlight>> highlightSearch({
    required String keyword,
  }) async => _decode(await bridge.highlightSearch(keyword: keyword));

  @override
  Future<List<BookHighlight>> highlightListAll() async =>
      _decode(await bridge.highlightListAll());
}
