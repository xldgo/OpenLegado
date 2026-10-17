import 'dart:typed_data';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/local_book_service.dart';
import '../../models/book.dart';
import '../bridge/book_content_decode.dart';

/// 导入/读页均委托 Rust，CBZ 原始字节直接返回。— Codex + Bridge
final class RustLocalBookService implements LocalBookService {
  const RustLocalBookService();
  @override
  Future<Book> importLocalBook(String filePath) async {
    final map = successfulContent(
      await bridge.importLocalBook(filePath: filePath),
      'importLocalBook',
    );
    final book = map['book'];
    if (book is! Map<String, dynamic>) {
      throw const FormatException('导入成功但缺少书籍数据');
    }
    return Book.fromJson(book);
  }

  @override
  Future<Uint8List> cbzReadPage({
    required String path,
    required String entry,
  }) async => bridge.cbzReadPage(path: path, entry: entry);
}
