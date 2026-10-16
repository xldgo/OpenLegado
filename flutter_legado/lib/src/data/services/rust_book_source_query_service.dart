import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_source_query_service.dart';
import '../../models/models.dart';
import '../bridge/rust_json_decode.dart';

/// 先执行现有平台拦截，再解码正文数据；查询不写数据库。— Codex + Bridge
final class RustBookSourceQueryService implements BookSourceQueryService {
  const RustBookSourceQueryService({required this._interceptResult});
  final Future<String> Function(String) _interceptResult;
  @override
  Future<Book> getBookInfo(BookSource source, String pageUrl) async {
    final map = decodeRustJsonMap(
      await _interceptResult(
        await bridge.webbookInfo(
          sourceJson: jsonEncode(source.toJson()),
          bookUrl: pageUrl,
        ),
      ),
      'webbookInfo',
    );
    return Book.fromJson({
      ...map,
      'bookUrl': map['bookUrl'] ?? map['book_url'] ?? pageUrl,
      'origin': source.bookSourceUrl,
      'originName': source.bookSourceName,
      'coverUrl': map['coverUrl'] ?? map['cover_url'],
      'wordCount': map['wordCount'] ?? map['word_count'],
      'latestChapterTitle': map['latestChapterTitle'] ?? map['last_chapter'],
      'tocUrl': map['tocUrl'] ?? map['toc_url'] ?? '',
    });
  }

  @override
  Future<List<BookChapter>> getChapters(
    BookSource source,
    String pageUrl, {
    required String bookUrl,
    String tocUrl = '',
    String bookName = '',
  }) async {
    final list = decodeRustJsonList(
      await _interceptResult(
        await bridge.webbookChapters(
          sourceJson: jsonEncode(source.toJson()),
          bookUrl: pageUrl,
          tocUrl: tocUrl,
          bookName: bookName,
        ),
      ),
      'webbookChapters',
    );
    return list.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('章节必须是对象');
      }
      return BookChapter.fromJson({
        ...value,
        'bookUrl': bookUrl,
        'isVolume': value['isVolume'] ?? value['is_volume'] ?? false,
        'isVip': value['isVip'] ?? value['is_vip'] ?? false,
        'isPay': value['isPay'] ?? value['is_pay'] ?? false,
        'resourceUrl': value['resourceUrl'] ?? value['resource_url'],
        'wordCount': value['wordCount'] ?? value['word_count'],
      });
    }).toList();
  }
}
