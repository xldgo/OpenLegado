import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localization.dart';
import '../models/models.dart';
import '../providers/bookshelf/bookshelf_notifier.dart';
import '../providers/providers.dart';
import '../providers/read_record/read_record_notifier.dart';
import '../utils/book_open_utils.dart';
import '../utils/error_message.dart';
import '../widgets/book_cover.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/md3_heatmap_calendar.dart';

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

  /// 今日已读秒数（readRecordDailyList 当日项）
  int _todaySeconds = 0;

  /// 是否已加载今日时长（避免日列表未就绪时表盘归零闪烁）
  bool _todayLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      unawaitedLoad();
    });
  }

  /// 拉取阅读记录与今日时长（阅读记录页同源 API）
  Future<void> unawaitedLoad() async {
    unawaitedInit();
    try {
      await ref.read(readRecordNotifierProvider.notifier).load();
      final year = DateTime.now().year;
      final daily = await ref
          .read(bookApiProvider)
          .readRecordDailyList(year)
          .catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      final todayKey = _dayKey(DateTime.now());
      for (final e in daily) {
        final date = (e['date'] ?? '').toString();
        if (date == todayKey) {
          _todaySeconds = (e['seconds'] as num?)?.toInt() ?? 0;
          break;
        }
      }
    } catch (_) {
      // 统计加载失败不阻断首页，表盘保持 0
    }
    if (!mounted) return;
    setState(() => _todayLoaded = true);
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
    var draft = _goalMinutes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.todayReadingGoal),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (draft > 5) {
                        setDialogState(() => draft -= 5);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    context.l10n.minuteCount(draft),
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      if (draft < 480) {
                        setDialogState(() => draft += 5);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              Slider(
                value: draft.clamp(5, 480).toDouble(),
                min: 5,
                max: 480,
                divisions: 95,
                label: '$draft',
                onChanged: (v) => setDialogState(() => draft = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted && draft != _goalMinutes) {
      setState(() => _goalMinutes = draft);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('homeReadGoalMinutes', draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final records = ref.watch(
      readRecordNotifierProvider.select((s) => s.records),
    );
    final totalMs = ref.watch(
      readRecordNotifierProvider.select((s) => s.totalReadTimeMs),
    );
    final books = ref.watch(bookshelfNotifierProvider.select((s) => s.books));

    // 最近阅读：按阅读记录 lastRead 取最近一本，回书架找同名书（拿完整 Book 对象开书）
    final sorted = [...records]
      ..sort((a, b) => b.lastRead.compareTo(a.lastRead));
    Book? recent;
    if (sorted.isNotEmpty) {
      final top = sorted.first;
      for (final b in books) {
        // ReadRecordShow 无 author 字段，按书名匹配（书名+作者唯一性由书架保证）
        if (b.name == top.bookName) {
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
        : (_todaySeconds / goalSeconds).clamp(0.0, 1.0);
    final todayMinutes = (_todaySeconds / 60).round();

    return Scaffold(
      appBar: LegadoAppBar(
        showBack: false,
        title: Text(
          context.l10n.home,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 28),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_rounded),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // ===== 最近阅读卡 =====
          if (recent != null)
            _HomeCard(
              onTap: () => _openBook(recent!),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 88,
                    child: BookCover(
                      coverUrl: recent.coverUrl,
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
                          recent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recent.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (recent.durChapterTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            recent.durChapterTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _progressBadge(recent, cs),
                ],
              ),
            ),
          if (recent != null) const SizedBox(height: 12),
          // ===== 统计双卡 =====
          Row(
            children: [
              Expanded(
                child: _HomeCard(
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
                    // [1-2 ③] 参考版目标图标=同心圆靶形（radar），替换时钟形
                    Icon(Symbols.radar_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.todayReadingGoal,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    // [1-2 ③] 参考版编辑钮=白底圆形浮钮（表面色+投影），替换裸图标
                    _GoalEditFab(onTap: _editGoal),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GoalDialPainter(
                      progress: _todayLoaded ? progress : 0,
                      trackColor: cs.surfaceContainerHighest,
                      progressColor: cs.primary,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _todayLoaded
                                ? '$todayMinutes / $_goalMinutes'
                                : '— / $_goalMinutes',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.l10n.minutesUnit,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HomeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.readingHeatmap,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.dailyReadingDuration,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                const _HeatmapSection(),
              ],
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

  Future<void> _openBook(Book book) async {
    // 与阅读记录页同链路：分流编排统一在 BookOpenUtils.openBook
    // （未读进详情 + 书源类型位解析后按类型进阅读器）
    await BookOpenUtils.openBook(context, ref, book);
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

/// [1-2 ③] 目标卡编辑钮：白底圆形浮钮（参考版量测 ≈40dp 表面色圆 + 投影，
/// 图标 onSurface；替换原裸 IconButton）
class _GoalEditFab extends StatelessWidget {
  final VoidCallback onTap;

  const _GoalEditFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: context.l10n.editReadingGoal,
          icon: const Icon(Icons.edit_rounded, size: 20),
          color: cs.onSurface,
          onPressed: onTap,
        ),
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
    final center = Offset(size.width / 2, size.height * 0.72);
    final radius = (size.width < size.height ? size.width : size.height) * 0.62;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
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

/// 首页阅读热力图：显示时加载每日时长，沿用现有统计 API。
class _HeatmapSection extends ConsumerStatefulWidget {
  const _HeatmapSection();

  @override
  ConsumerState<_HeatmapSection> createState() => _HeatmapSectionState();
}

class _HeatmapSectionState extends ConsumerState<_HeatmapSection> {
  Map<DateTime, int>? _dailySeconds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    try {
      final list = await ref
          .read(bookApiProvider)
          .readRecordDailyList(DateTime.now().year);
      if (!mounted) return;
      final map = <DateTime, int>{};
      for (final e in list) {
        final date = (e['date'] ?? '').toString();
        final seconds = (e['seconds'] as num?)?.toInt() ?? 0;
        if (date.isEmpty) continue;
        final parts = date.split('-');
        if (parts.length != 3) continue;
        map[DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            )] =
            seconds;
      }
      setState(() => _dailySeconds = map);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        context.l10n.dailyDurationLoadFailed(_error!),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      );
    }
    if (_dailySeconds == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return Md3HeatmapCalendar(
      dailySeconds: _dailySeconds!,
      dailyCounts: const {},
      mode: Md3HeatmapMode.duration,
      endDate: DateTime.now(),
    );
  }
}
