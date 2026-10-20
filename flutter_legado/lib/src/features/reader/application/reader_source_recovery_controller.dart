import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/reader_settings_repository.dart';
import '../../../domain/contracts/source_switch_service.dart';
import '../../../models/book.dart';
import '../../../models/book_source.dart';
import 'reader_state.dart';

/// 页面提供当前会话、重开动作与可见提示，控制器不持有Ref或Context。— Codex + UI
final class ReaderSourceRecoveryHost {
  const ReaderSourceRecoveryHost({
    required this.readState,
    required this.openBook,
    required this.notify,
  });

  final ReaderState Function() readState;
  final Future<void> Function(Book) openBook;
  final void Function(String) notify;
}

/// 自动换源沿用既有候选顺序及重试限制，登录页仍由页面打开。— Codex + UI
final class ReaderSourceRecoveryController {
  ReaderSourceRecoveryController({
    required this._host,
    required this._settings,
    required this._sources,
    required this._switchSource,
  });

  final ReaderSourceRecoveryHost _host;
  final ReaderSettingsRepository _settings;
  final BookSourceRepository _sources;
  final SourceSwitchService _switchSource;
  bool _disposed = false;
  bool _switching = false;
  String? _attemptBookUrl;
  int _attempts = 0;

  bool _isCurrent(Book book) {
    if (_disposed) return false;
    final current = _host.readState().currentBook;
    return current?.bookUrl == book.bookUrl && current?.origin == book.origin;
  }

  bool _isLocal(Book book) =>
      book.origin == BookType.localTag ||
      book.origin.startsWith(BookType.webDavTag);

  Future<BookSource?> findLoginSource(Book book) async {
    if (_disposed || _isLocal(book)) return null;
    try {
      final sources = await _sources.getBookSources();
      if (!_isCurrent(book)) return null;
      return sources
          .where((source) => source.bookSourceUrl == book.origin)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> onChapterError(ReaderState state) async {
    if (_disposed || _switching || !_settings.current.autoChangeSource) return;
    final book = state.currentBook;
    if (book == null || _isLocal(book)) return;
    if (_attemptBookUrl != book.bookUrl) {
      _attemptBookUrl = book.bookUrl;
      _attempts = 0;
    }
    if (_attempts >= 3) return;
    _attempts++;
    _switching = true;
    try {
      final matches = await _switchSource.searchSource(book.name, book.author);
      if (!_isCurrent(book)) return;
      final target = matches
          .where(
            (match) =>
                match.sourceUrl.isNotEmpty && match.sourceUrl != book.origin,
          )
          .firstOrNull;
      if (target == null) {
        _host.notify('自动换源：无可用替代书源');
        return;
      }
      final switched = await _switchSource.switchSource(
        book.bookUrl,
        target.sourceUrl,
        target.bookUrl,
      );
      if (!_isCurrent(book)) return;
      final updated = switched.copyWith(
        durChapterIndex: book.durChapterIndex,
        durChapterPos: book.durChapterPos,
        durChapterTitle: book.durChapterTitle,
      );
      await _host.openBook(updated);
      if (_disposed ||
          _host.readState().currentBook?.bookUrl != updated.bookUrl) {
        return;
      }
      _host.notify('章节加载失败，已自动换源：${target.sourceName}');
      _attempts = 0;
    } catch (error) {
      if (_isCurrent(book)) _host.notify('自动换源失败: $error');
    } finally {
      _switching = false;
    }
  }

  void dispose() => _disposed = true;
}
