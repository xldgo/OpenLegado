part of 'book_info_screen.dart';

// 同一页面的扩展分区只读取所属State的Ref。
// ignore_for_file: invalid_use_of_protected_member

extension _BookInfoLoad on _BookInfoScreenState {
  void _onBridgeRefresh() {
    final signal = PlatformBridgeService.refreshSignal.value;
    if (!mounted || signal == null) return;
    if (signal == 'bookInfo' || signal == 'bookToc') _reload();
  }

  Future<void> _reload() => _loadData();
  Future<void> _loadData() => mounted ? _detailNotifier.load() : Future.value();

  void _onDetailChanged(BookDetailState? previous, BookDetailState next) {
    if (!mounted) return;
    final book = next.data.book;
    if (book != null && book != previous?.data.book) {
      unawaited(_extractCoverSeed(book));
    }
    if (next.completedLoads <= (previous?.completedLoads ?? 0)) return;
    // 首轮完成即消费自动开读机会；目录为空或路由不在栈顶时停留详情。
    final autoStartNow = widget.openReaderImmediately && !_autoStartScheduled;
    _autoStartScheduled = true;
    if (!autoStartNow || next.data.chapters.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final current = _loadedBook;
      if (current != null) {
        unawaited(_openReader(context, current, current.durChapterIndex));
      }
    });
  }

  Future<void> _loadDeleteBookAlert() async {
    try {
      await ref.read(bookshelfSettingsRepositoryProvider).load();
    } catch (error) {
      if (mounted) _snack('删除提醒设置读取失败，请重试');
    }
  }

  String _errMsg(Object error) => detailErrorMessage(error);
  bool _isOnlineBook(Book book) => BookMetadataPolicy.isOnlineBook(book);

  bool _isLocalTxt(Book book) {
    if (_isOnlineBook(book)) return false;
    final name = book.originName.trim();
    return (name.isNotEmpty ? name : book.bookUrl).toLowerCase().endsWith(
      '.txt',
    );
  }

  Future<BookSource?> _findSourceByOrigin(String origin) =>
      ref.read(bookDetailServiceProvider).findSource(origin);
}
