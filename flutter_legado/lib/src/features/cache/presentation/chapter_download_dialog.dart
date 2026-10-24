import 'package:material_ui/material_ui.dart';

import '../../../domain/contracts/cache_download_service.dart';
import '../../../widgets/app_settings_form.dart';
import '../../../widgets/app_snack_bar.dart';

/// 文本/漫画共用章节范围，实际下载与失败判定交给同一领域服务。— Codex + UI
Future<void> showChapterDownloadDialog(
  BuildContext context, {
  required CacheDownloadService downloads,
  required String bookUrl,
  required int currentChapterIndex,
  required int totalChapters,
  VoidCallback? onOpenQueue,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ChapterDownloadDialog(
    downloads: downloads,
    bookUrl: bookUrl,
    currentChapterIndex: currentChapterIndex,
    totalChapters: totalChapters,
    onOpenQueue: onOpenQueue,
    pageContext: context,
  ),
);

class _ChapterDownloadDialog extends StatefulWidget {
  const _ChapterDownloadDialog({
    required this.downloads,
    required this.bookUrl,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.pageContext,
    this.onOpenQueue,
  });
  final CacheDownloadService downloads;
  final String bookUrl;
  final int currentChapterIndex, totalChapters;
  final VoidCallback? onOpenQueue;
  final BuildContext pageContext;

  @override
  State<_ChapterDownloadDialog> createState() => _ChapterDownloadDialogState();
}

class _ChapterDownloadDialogState extends State<_ChapterDownloadDialog> {
  late final _start = TextEditingController(
    text: '${widget.currentChapterIndex + 1}',
  );
  late final _end = TextEditingController(text: '${widget.totalChapters}');

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final start = int.tryParse(_start.text) ?? 1;
    final end = int.tryParse(_end.text) ?? widget.totalChapters;
    final downloads = widget.downloads;
    final bookUrl = widget.bookUrl;
    final pageContext = widget.pageContext;
    final openQueue = widget.onOpenQueue;
    Navigator.pop(context);
    if (start < 1 || end > widget.totalChapters || start > end) {
      showAppSnackBar(pageContext, '章节范围无效');
      return;
    }
    try {
      await downloads.cacheDownloadStart(bookUrl, start - 1, end - 1);
      if (!pageContext.mounted) return;
      showAppSnackBar(
        pageContext,
        '已加入缓存队列：${end - start + 1} 章（可在书籍菜单「缓存管理」查看进度）',
        action: openQueue == null
            ? null
            : SnackBarAction(label: '查看队列', onPressed: openQueue),
      );
    } catch (error) {
      if (!pageContext.mounted) return;
      showAppSnackBar(pageContext, '缓存启动失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('离线缓存'),
    content: AppSettingsForm(
      children: [
        TextField(
          controller: _start,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '起始章节序号'),
        ),
        TextField(
          controller: _end,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '结束章节序号',
            helperText: '共 ${widget.totalChapters} 章',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _download, child: const Text('开始缓存')),
    ],
  );
}
