import '../../../../providers/chapter_cache_provider.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../../models/models.dart';
import '../../../cache/presentation/chapter_download_dialog.dart';
import '../../application/reader_notifier.dart';

/// 阅读器「离线缓存」章节范围选择对话框（两个阅读顶栏共享实现）
///
/// [P2-27 | 2026-09-28] 统一菜单面板顶栏与工具栏顶栏的下载入口行为：
/// 点击下载图标弹出「离线缓存」范围对话框（对齐原版
/// BaseReadBookActivity.showBookDownloadDialog / 参考版 DownloadSheet），
/// 不再存在「直接缓存当前章」的快捷行为（当前章保留为默认起始值）。
///
/// 语义对齐原版：
/// - 标题 = offline_cache（离线缓存）
/// - 默认起始 = 当前章（1-based = currentChapterIndex + 1，
///   对应原版 book.durChapterIndex + 1）
/// - 默认结束 = 总章数（已加载目录 chapters.length）
/// - 确认时转 0-based 含端点索引（契约 §2.43.3：Rust 侧超界自动截断）
///
/// 保留既有校验（与顶栏原 _showCacheDialog 一致）：
/// - 空输入：起始 → 1，结束 → 总章数
/// - start < 1 || end > 总章数 || start > end →「章节范围无效」
void showReaderOfflineCacheDialog(BuildContext context, WidgetRef ref) {
  final state = ref.read(readerNotifierProvider);
  final book = state.currentBook;
  final chapters = state.chapters;
  if (book == null || chapters.isEmpty) return;
  if (book.origin == BookType.localTag) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('本地书籍无需缓存')));
    return;
  }
  showChapterDownloadDialog(
    context,
    downloads: ref.read(cacheDownloadServiceProvider),
    bookUrl: book.bookUrl,
    currentChapterIndex: state.currentChapterIndex,
    totalChapters: chapters.length,
  );
}
