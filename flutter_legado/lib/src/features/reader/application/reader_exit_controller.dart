import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../domain/contracts/general_settings_repository.dart';
import '../../../domain/services/book_metadata_policy.dart';
import '../../../models/book.dart';

/// 导航与确认交给页面，退出流程只依赖明确的会话动作。— Codex + UI
final class ReaderExitHost {
  const ReaderExitHost({
    required this.readBook,
    required this.isActive,
    required this.confirmAdd,
    required this.addBook,
    required this.saveProgress,
    required this.close,
    required this.notify,
  });

  final Book? Function() readBook;
  final bool Function() isActive;
  final Future<bool> Function(String) confirmAdd;
  final Future<String?> Function(Book) addBook;
  final Future<void> Function() saveProgress;
  final void Function() close;
  final void Function(String) notify;
}

/// 保留在架/未入架三路退出语义，不持有页面或Ref。— Codex + UI
final class ReaderExitController {
  ReaderExitController({
    required this._host,
    required this._bookshelf,
    required this._settings,
  });

  final ReaderExitHost _host;
  final BookshelfRepository _bookshelf;
  final GeneralSettingsRepository _settings;
  bool _pending = false;
  bool _disposed = false;
  bool get _active => !_disposed && _host.isActive();

  Future<void> requestExit() async {
    if (!_active || _pending) return;
    _pending = true;
    try {
      final book = _host.readBook();
      if (book == null) {
        _host.close();
        return;
      }
      var inShelf = false;
      try {
        inShelf = BookMetadataPolicy.isInBookshelf(
          await _bookshelf.getBook(book.bookUrl),
        );
      } catch (_) {
        // 沿用原判定：查询失败按未入架处理。
      }
      if (!_active) return;
      if (inShelf) {
        await _saveAndClose();
        return;
      }
      final bool showAlert;
      try {
        showAlert = (await _settings.load()).showAddToShelfAlert;
      } catch (_) {
        if (_active) _host.notify('读取返回入架设置失败，请重试');
        return;
      }
      if (!_active) return;
      if (!showAlert) {
        await _removeAndClose(book);
        return;
      }
      final confirmed = await _host.confirmAdd(book.name);
      if (!_active) return;
      if (confirmed) {
        final error = await _host.addBook(
          book.copyWith(bookType: book.bookType & ~BookType.notShelf),
        );
        if (!_active) return;
        if (error != null) {
          _host.notify(error);
          return;
        }
        await _saveAndClose();
      } else {
        await _removeAndClose(book);
      }
    } finally {
      _pending = false;
    }
  }

  Future<void> _saveAndClose() async {
    await _host.saveProgress();
    if (_active) _host.close();
  }

  Future<void> _removeAndClose(Book book) async {
    try {
      await _bookshelf.deleteBook(book.bookUrl);
    } catch (_) {
      // 清理临时记录失败不阻断既有退出路径。
    }
    if (_active) _host.close();
  }

  void dispose() => _disposed = true;
}
