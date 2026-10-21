import '../../../app/routing/app_navigation.dart';
import '../../../app/routing/route_arguments.dart';
import '../../privacy/privacy_gate.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localization.dart';
import '../../../models/models.dart';
import '../../bookshelf/bookshelf.dart';
import '../../../app/routing/route_names.dart';
import '../../read_records/read_records.dart';
import '../../read_records/read_record_overview_calculator.dart';
import '../../../utils/book_open_utils.dart';
import '../../../widgets/book_cover.dart';
import '../../../widgets/legado_app_bar.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_bottom_bar_inset.dart';

/// 首页页签（对齐参考版首页布局）
///
/// [UI_SYNC_REFACTOR S6 | 2026-09-08] 差异清单批六：参考版有「首页」页签
/// （最近阅读卡 + 累计阅读统计 + 今日阅读目标表盘），我方此前无此页签 — Qoder
/// 数据源：书架（最近阅读）+ 阅读记录（本书数/总时长/今日时长）。
/// 今日目标分钟数存本地偏好 homeReadGoalMinutes（默认 30，可编辑）。
/// 首页模块管理（自定义集/书源模块）为参考版深功能，登记后续批次。
class HomeTabScreen extends ConsumerStatefulWidget {
  const HomeTabScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends ConsumerState<HomeTabScreen> {
  /// 今日目标分钟数（本地偏好，默认 30 对齐参考版初始值）
  int _goalMinutes = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      unawaitedInit();
    });
  }

  Future<void> unawaitedInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _goalMinutes = prefs.getInt('homeReadGoalMinutes') ?? 30;
      });
    } catch (_) {
      // 偏好读取失败保持默认目标
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _editGoal() async {
    var input = '$_goalMinutes';
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final draft = int.tryParse(input);
          final valid = draft != null && draft >= 1 && draft <= 24 * 60;
          return AlertDialog(
            title: Text(context.l10n.setReadingGoal),
            content: TextFormField(
              initialValue: input,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLines: 1,
              decoration: InputDecoration(
                labelText: context.l10n.readingGoalMinutesLabel,
              ),
              onChanged: (value) => setDialogState(() => input = value),
              onFieldSubmitted: (_) {
                if (valid) Navigator.pop(dialogContext, draft);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(dialogContext, draft)
                    : null,
                child: Text(context.l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
    if (minutes != null && mounted && minutes != _goalMinutes) {
      setState(() => _goalMinutes = minutes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('homeReadGoalMinutes', minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overviewState = ref.watch(homeReadRecordOverviewProvider);
    final dataset = ref.watch(readRecordDatasetProvider);
    final records = dataset.asData?.value.records ?? const <ReadRecord>[];
    final totalMs = overviewState.totalTimeMs;
    final todaySeconds =
        overviewState.allDailyTimes[_dayKey(DateTime.now())] ?? 0;
    final todayLoaded = !overviewState.isLoading;
    final books = ref.watch(bookshelfNotifierProvider.select((s) => s.books));

    // 最近阅读：按阅读记录 lastRead 取最近一本，回书架找同名书（拿完整 Book 对象开书）
    final sorted = [...records]
      ..sort((a, b) => b.lastRead.compareTo(a.lastRead));
    Book? recent;
    if (sorted.isNotEmpty) {
      final top = sorted.first;
      for (final b in books) {
        // 使用记录的真实作者匹配，避免同名书打开错误副本。
        if (b.name == top.bookName &&
            (top.author.isEmpty ||
                ReadRecordOverviewCalculator.authors(top.author)
                    .contains(b.author))) {
          recent = b;
          break;
        }
      }
    }
    final readBooks = records.where((r) => r.readTime > 0).length;
    final totalHours = (totalMs / 3600000).toStringAsFixed(1);
    final goalSeconds = _goalMinutes * 60;
    final progress = goalSeconds <= 0
        ? 0.0
        : (todaySeconds / goalSeconds).clamp(0.0, 1.0);
    final todayMinutes = (todaySeconds / 60).round();

    return AppScaffold(
      topBar: LegadoAppBar(
        showBack: false,
        title: Text(context.l10n.home),
        actions: [
          IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_rounded),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: ListView(
        padding: AppBottomBarInset.padding(
          context,
          const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
        children: [
          // ===== 最近阅读卡 =====
          if (recent case final recentBook?)
            PrivacyMaskedContent(
              book: recent,
              onTap: () => _openBook(recentBook),
              child: Builder(
                builder: (coverContext) => _HomeCard(
                  onTap: () =>
                      _openBook(recentBook, coverContext: coverContext),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 88,
                        child: BookCover(
                          coverUrl: recentBook.coverUrl,
                          width: 64,
                          height: 88,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Symbols.menu_book_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.recentReading,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: cs.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              recentBook.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recentBook.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            if (recentBook.durChapterTitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                recentBook.durChapterTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _progressBadge(recentBook, cs),
                    ],
                  ),
                ),
              ),
            ),
          if (recent != null) const SizedBox(height: 12),
          // ===== 统计双卡 =====
          Row(
            children: [
              Expanded(
                child: _HomeCard(
                  onTap: () =>
                      GoRouter.of(context)
                          .pushAppRoute(AppRoutes.readRecordOverview),
                  child: Row(
                    children: [
                      Icon(Symbols.bar_chart_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      // [FIX 2026-09-19 P2-13②] 数值列限宽 + 省略号截断，防 Row 右溢
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.booksRead,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              context.l10n.bookCount(readBooks),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeCard(
                  onTap: () =>
                      GoRouter.of(context).pushAppRoute(AppRoutes.readRecord),
                  child: Row(
                    children: [
                      Icon(Symbols.schedule_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      // [FIX 2026-09-19 P2-13②] 数值列限宽 + 省略号截断，防 Row 右溢
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.readingDuration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              context.l10n.hourCount(totalHours),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ===== 今日阅读目标表盘 =====
          _HomeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.track_changes_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.todayReadingGoal,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: context.l10n.editReadingGoal,
                      onPressed: _editGoal,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        minimumSize: const Size(40, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: cs.surfaceContainerLow,
                        foregroundColor: cs.onSurfaceVariant,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 240,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AspectRatio(
                        aspectRatio: 2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: todayLoaded ? progress : 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          builder: (context, animatedProgress, child) =>
                              Semantics(
                                label: context.l10n.todayReadingGoal,
                                value: '${(animatedProgress * 100).round()}%',
                                child: CustomPaint(
                                  painter: _GoalDialPainter(
                                    progress: animatedProgress,
                                    trackColor: cs.surfaceContainerHighest,
                                    progressColor: cs.primary,
                                  ),
                                  child: child,
                                ),
                              ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  todayLoaded
                                      ? '$todayMinutes / $_goalMinutes'
                                      : '— / $_goalMinutes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  context.l10n.minutesUnit,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (overviewState.error != null)
            ListTile(
              title: Text(overviewState.error!),
              trailing: IconButton(
                icon: const Icon(Symbols.refresh_rounded),
                tooltip: '重试',
                onPressed: () => ref.invalidate(readRecordDatasetProvider),
              ),
            ),
          // ===== 阅读热力图卡片 =====
          ReadingHeatmapCard.fromStringMap(
            dailySecondsMap: overviewState.allDailyTimes,
            dailyCountsMap: overviewState.allDailyCounts,
            trailing: IconButton(
              tooltip: '阅读总览',
              icon: const Icon(Symbols.chevron_right_rounded),
              onPressed: () =>
                  GoRouter.of(context)
                      .pushAppRoute(AppRoutes.readRecordOverview),
            ),
          ),
          const SizedBox(height: 12),
          // ===== 阅读时长榜卡片 =====
          ReadingRankingCard(
            topBooks: overviewState.topBooks.take(5).toList(),
            onBookTap: (coverContext, ranking) => _openBookByIdentity(
              coverContext,
              ranking.bookName,
              ranking.author,
            ),
            trailing: IconButton(
              tooltip: '更多排行',
              icon: const Icon(Symbols.chevron_right_rounded),
              onPressed: () =>
                  GoRouter.of(context)
                      .pushAppRoute(AppRoutes.readRecordOverview),
            ),
          ),
          const SizedBox(height: 12),
          // ===== 读书日历卡片 =====
          ReadingCalendarCard(
            referenceDate: overviewState.referenceDate,
            dailyTopBook: overviewState.dailyTopBook,
            onDateTap: (date) => showReadRecordDayDetails(context, date),
            trailing: IconButton(
              tooltip: '查看日历',
              icon: const Icon(Symbols.chevron_right_rounded),
              onPressed: () =>
                  GoRouter.of(context)
                      .pushAppRoute(AppRoutes.readRecordOverview),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBadge(Book book, ColorScheme cs) {
    final total = book.totalChapterNum;
    final percent = total > 0
        ? ((book.durChapterIndex + 1) / total * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percent%',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  Future<void> _openBook(Book book, {BuildContext? coverContext}) async {
    // 与阅读记录页同链路：分流编排统一在 BookOpenUtils.openBook
    // （书源类型位解析后直接进入阅读器或播放器）
    await BookOpenUtils.openBook(
      context,
      ref,
      book,
      coverContext: coverContext,
    );
  }

  Future<void> _openBookByIdentity(
    BuildContext coverContext,
    String bookName,
    String author,
  ) async {
    final books = ref.read(bookshelfNotifierProvider).books;
    Book? matched;
    for (final b in books) {
      if (b.name == bookName && (author.isEmpty || b.author == author)) {
        matched = b;
        break;
      }
    }
    if (matched != null) {
      await _openBook(matched, coverContext: coverContext);
    } else {
      await GoRouter.of(
        context,
      ).pushAppRoute(AppRoutes.search, extra: SearchRouteArgs(query: bookName));
    }
  }
}

/// 首页卡片基座（圆角 24 + surfaceContainerLow，与阅读界面弹层卡一致）
class _HomeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HomeCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// 今日目标半圆表盘（对齐参考版半环造型：背景弧 + 进度弧 + 底部缺口）
class _GoalDialPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _GoalDialPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 对齐上游：2:1 画布内绘制上半圆，半个线宽为顶侧留出完整笔画空间。
    const strokeWidth = 14.0;
    final arcSize = (size.width - strokeWidth).clamp(0.0, double.infinity);
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      arcSize,
      arcSize,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    // 半圆：自左侧水平起顺时针扫 180°
    const startAngle = 3.141592653589793;
    const sweep = 3.141592653589793;
    canvas.drawArc(rect, startAngle, sweep, false, track);
    if (progress > 0) {
      canvas.drawArc(rect, startAngle, sweep * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_GoalDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
