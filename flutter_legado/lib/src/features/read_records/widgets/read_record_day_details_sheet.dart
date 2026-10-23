import '../../privacy/privacy_gate.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/book_cover.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../read_record_day_details_provider.dart';
import '../read_record_screen.dart' show formatDuring;

/// 日历日期明细只展示当天记录，不直接跳转阅读器。— Codex + UI
Future<void> showReadRecordDayDetails(BuildContext context, DateTime date) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReadRecordDayDetailsSheet(date: date),
    );

class ReadRecordDayDetailsSheet extends ConsumerWidget {
  final DateTime date;

  const ReadRecordDayDetailsSheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(readRecordDayDetailsProvider(date));
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: AppBottomSheet(
        contentPadding: const EdgeInsets.all(16),
        title: '${date.year}年${date.month}月${date.day}日 阅读明细',
        trailing: IconButton(
          tooltip: '关闭',
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        children: details.when(
          skipLoadingOnRefresh: false,
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (error, stack) => [
            const Text('阅读明细加载失败'),
            TextButton(
              onPressed: () =>
                  ref.invalidate(readRecordDayDetailsProvider(date)),
              child: const Text('重试'),
            ),
          ],
          data: (books) => [
            if (books.isEmpty)
              const Center(child: Text('当天没有阅读记录'))
            else ...[
              Text(
                '${books.length}本 · ${formatDuring(books.fold<int>(0, (sum, book) => sum + book.readTimeMs))}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              for (final book in books)
                PrivacyMaskedContent(
                  bookName: book.bookName,
                  author: book.author,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 40,
                      height: 56,
                      child: BookCover(
                        coverUrl: book.coverUrl,
                        borderRadius: 6,
                      ),
                    ),
                    title: Text(book.bookName),
                    subtitle: book.author.isEmpty ? null : Text(book.author),
                    trailing: Text(formatDuring(book.readTimeMs)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
