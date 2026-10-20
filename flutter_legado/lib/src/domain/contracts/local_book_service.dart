import 'dart:typed_data';

import '../../models/book.dart';

/// 本地书籍入库与容器读页，不持有阅读会话。— Codex + Bridge
abstract interface class LocalBookService {
  Future<Book> importLocalBook(String filePath);
  Future<Uint8List> cbzReadPage({required String path, required String entry});
}
