import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/audio/application/audio_notifier.dart';
import '../../features/bookmarks/bookmarks.dart';
import '../../providers/highlight_repository_provider.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../../routes.dart';
import '../../l10n/app_localization.dart';
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/models/book_highlight.dart';
import '../dict_dialog.dart';
import 'reader_selection_controller.dart';
import 'reader_selection_menu_config.dart';

const List<Color> kHighlightColors = [
  Color(0xFFFFE082),
  Color(0xFFA5D6A7),
  Color(0xFF90CAF9),
  Color(0xFFF48FB1),
  Color(0xFFFFCC80),
];

/// 选区动作只调用已有服务，异步操作固定使用点击时的原文与章节快照。
class ReaderSelectionActions {
  ReaderSelectionActions({
    required this.context,
    required this.ref,
    required this.selection,
  });

  final BuildContext context;
  final WidgetRef ref;
  final ReaderTextSelection selection;
  static Color _lastHighlightColor = kHighlightColors.first;

  void _toast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> run(
    ReaderSelectionAction action,
    Future<void> Function() dismiss,
  ) async {
    // 消费 WidgetRef 的操作必须在菜单移除之前完成；只捕获当前动作所需依赖。
    final needsBook = switch (action) {
      ReaderSelectionAction.bookmark ||
      ReaderSelectionAction.highlight ||
      ReaderSelectionAction.aloud ||
      ReaderSelectionAction.searchContent => true,
      _ => false,
    };
    final state = needsBook ? ref.read(readerNotifierProvider) : null;
    final bookmark = action == ReaderSelectionAction.bookmark
        ? ref.read(bookmarkNotifierProvider.notifier)
        : null;
    final audio = action == ReaderSelectionAction.aloud
        ? ref.read(audioNotifierProvider.notifier)
        : null;
    final highlights = action == ReaderSelectionAction.highlight
        ? ref.read(highlightRepositoryProvider)
        : null;
    final navigator = Navigator.of(context, rootNavigator: true);
    final size = MediaQuery.sizeOf(context);
    final shareOrigin = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
    await dismiss();
    if (!context.mounted) return;
    if (needsBook && state?.currentBook == null) {
      _toast('无法${action.label}：未打开书籍');
      return;
    }
    try {
      switch (action) {
        case ReaderSelectionAction.copy:
          await Clipboard.setData(ClipboardData(text: selection.text));
          _toast('已复制到剪贴板');
        case ReaderSelectionAction.share:
          await SharePlus.instance.share(
            ShareParams(text: selection.text, sharePositionOrigin: shareOrigin),
          );
        case ReaderSelectionAction.browser:
          final text = selection.text.trim();
          if (RegExp(r'^https?://\S+$').hasMatch(text)) {
            await navigator.pushNamed(AppRoutes.browser, arguments: text);
          } else if (!await launchUrl(
            Uri.https('www.bing.com', '/search', {'q': text}),
            mode: LaunchMode.externalApplication,
          )) {
            _toast('无法打开浏览器');
          }
        case ReaderSelectionAction.aloud:
          await audio!.startReadAloud(
            bookUrl: state!.currentBook!.bookUrl,
            bookName: state.currentBook!.name,
            chapterIndex: state.currentChapterIndex,
            startChapterPos: selection.start,
            startParagraphText: selection.text,
          );
        case ReaderSelectionAction.bookmark:
          final saved = await BookmarkNoteSheet.show(
            context: context,
            bookText: selection.text,
            chapterName: state!.currentChapter?.title ?? '',
            onSave: (note) async {
              await bookmark!.addBookmark(
                bookName: state.currentBook!.name,
                bookAuthor: state.currentBook!.author,
                chapterIndex: state.currentChapterIndex,
                chapterPos: selection.start,
                chapterName: state.currentChapter?.title ?? '',
                bookText: selection.text,
                content: note,
              );
            },
          );
          if (saved == true && context.mounted) {
            _toast(context.l10n.bookmarkAdded);
          }
        case ReaderSelectionAction.highlight:
          await _highlight(state!, highlights!);
        case ReaderSelectionAction.dictionary:
          await showDictDialog(context, word: selection.text.trim());
        case ReaderSelectionAction.replace:
          await navigator.pushNamed(
            AppRoutes.replaceRules,
            arguments: selection.text,
          );
        case ReaderSelectionAction.searchContent:
          await navigator.pushNamed(
            AppRoutes.searchContent,
            arguments: {'book': state!.currentBook!, 'query': selection.text},
          );
      }
    } catch (error) {
      _toast('${action.label}失败：$error');
    }
  }

  Future<void> _highlight(
    ReaderState state,
    HighlightRepository repository,
  ) async {
    var note = '';
    var selectedColor = _lastHighlightColor;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('高亮', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('样式颜色', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (_, setColorState) => Row(
                  children: [
                    for (final c in kHighlightColors)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () => setColorState(() => selectedColor = c),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c == selectedColor
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).dividerColor,
                                width: c == selectedColor ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => note = value,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '笔记（可选）'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('保存高亮'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    final chosen = selectedColor;
    if (ok != true || !context.mounted) return;
    final book = state.currentBook!;
    final chapter = state.currentChapter;
    await repository.highlightAdd(
      BookHighlight(
        bookUrl: book.bookUrl,
        chapterUrl: chapter?.url ?? '',
        bookName: book.name,
        bookAuthor: book.author,
        chapterIndex: state.currentChapterIndex,
        chapterPos: selection.start,
        chapterPosEnd: selection.end,
        layoutTitleLength: 0,
        chapterName: chapter?.title ?? '',
        bookText: selection.text,
        style: jsonEncode({
          'type': 'background',
          'color':
              '#${chosen.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
        }),
        note: note.trim(),
      ),
    );
    _lastHighlightColor = chosen;
    _toast(note.trim().isEmpty ? '已添加高亮' : '已添加高亮与笔记');
  }
}
