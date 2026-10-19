import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/book.dart';
import '../../features/bookshelf/bookshelf_repositories.dart';
import '../../features/privacy/privacy_gate.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../widgets/error_view.dart';

/// URI只带稳定书籍身份时，先恢复书籍，再经原隐私门禁激活阅读会话。— Codex + UI
class ReaderRouteEntry extends ConsumerStatefulWidget {
  const ReaderRouteEntry({
    super.key,
    this.bookUrl,
    this.snapshot,
    this.builder,
  });
  final String? bookUrl;
  final Book? snapshot;
  final WidgetBuilder? builder;
  @override
  ConsumerState<ReaderRouteEntry> createState() => _ReaderRouteEntryState();
}

class _ReaderRouteEntryState extends ConsumerState<ReaderRouteEntry> {
  late Future<Book?> _book;
  @override
  void initState() {
    super.initState();
    _book = _resolve();
  }

  @override
  void didUpdateWidget(covariant ReaderRouteEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookUrl != widget.bookUrl) _book = _resolve();
  }

  Future<Book?> _resolve() async {
    final current = ref.read(readerNotifierProvider).currentBook;
    final url = widget.bookUrl;
    if (url == null || url.isEmpty || current?.bookUrl == url) return current;
    if (widget.snapshot?.bookUrl == url) return widget.snapshot;
    final book = await ref.read(bookshelfRepositoryProvider).getBook(url);
    if (book == null) throw StateError('书籍不存在');
    return book;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Book?>(
    future: _book,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorView(
          message: '无法打开书籍：${snapshot.error}',
          onRetry: () => setState(() => _book = _resolve()),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      final book = snapshot.data;
      return PrivacyBookGate(
        book: book,
        builder: (_) => _ReaderActivation(
          key: ValueKey(book?.bookUrl),
          book: book,
          builder: widget.builder,
        ),
      );
    },
  );
}

class _ReaderActivation extends ConsumerStatefulWidget {
  const _ReaderActivation({super.key, this.book, this.builder});
  final Book? book;
  final WidgetBuilder? builder;
  @override
  ConsumerState<_ReaderActivation> createState() => _ReaderActivationState();
}

class _ReaderActivationState extends ConsumerState<_ReaderActivation> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    final book = widget.book;
    if (book == null ||
        ref.read(readerNotifierProvider).currentBook?.bookUrl == book.bookUrl) {
      _ready = true;
    } else {
      Future.microtask(() {
        if (!mounted) return;
        unawaited(ref.read(readerNotifierProvider.notifier).openBook(book));
        setState(() => _ready = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => !_ready
      ? const SizedBox.shrink()
      : widget.builder?.call(context) ?? const ReaderScreen();
}
