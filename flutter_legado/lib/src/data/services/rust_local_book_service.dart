import '../bridge/rust_errors.dart';

import 'dart:typed_data';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/local_book_service.dart';
import '../../models/book.dart';
import '../bridge/file_dto_mapping.dart';
import '../bridge/entity_dto_mapping.dart';

/// 导入/读页均委托 Rust，CBZ 原始字节直接返回。— Codex + Bridge
final class RustLocalBookService implements LocalBookService {
  const RustLocalBookService();
  @override
  Future<Book> importLocalBook(String filePath) async {
    final result = await rustFuture(
      () => bridge.importLocalBook(filePath: filePath),
      operation: 'importLocalBook',
    );
    requireFileSuccess(result.success, result.error, 'importLocalBook');
    final book = result.book;
    if (book == null) throw const FormatException('导入成功但缺少书籍数据');
    return bookFromDto(book);
  }

  @override
  Future<Uint8List> cbzReadPage({
    required String path,
    required String entry,
  }) async => rustFuture(
    () => bridge.cbzReadPage(path: path, entry: entry),
    operation: 'cbzReadPage',
  );
}
