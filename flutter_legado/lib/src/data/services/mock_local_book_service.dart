import 'dart:typed_data';

import '../../domain/contracts/local_book_service.dart';
import '../../models/book.dart';
import '../repositories/mock_bookshelf_repository.dart';

/// 本地导入共用原Mock书架，CBZ默认空字节供测试覆写。— Codex + Bridge
class MockLocalBookService implements LocalBookService {
  MockLocalBookService({required this._store});
  final MockBookshelfStore _store;
  @override
  Future<Book> importLocalBook(String filePath) async {
    await _store.ensureLoaded();
    // [cbz 批 C | 2026-10-03] 与 Rust `import_local_book` 对齐：`.cbz` 图片
    // 漫画包额外带 image(64) 媒体位（LOCAL|image=0x1040），其余本地格式仅
    // LOCAL；位域语义见 BookType（book.dart），勿用 == 单值比较。
    final isCbz = filePath.toLowerCase().endsWith('.cbz');
    final book = Book(
      bookUrl: 'file://$filePath',
      name: filePath
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'\.\w+$'), ''),
      author: '本地导入',
      bookType: isCbz ? BookType.local | BookType.image : BookType.local,
    );
    _store.books.add(book);
    return book;
  }

  @override
  Future<Uint8List> cbzReadPage({
    required String path,
    required String entry,
  }) async => Uint8List(0);
}
