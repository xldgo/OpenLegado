import '../providers/rss_repository_provider.dart';
import '../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

/// RSS 源调试页面
///
/// 对标安卓原版 RssSourceDebugActivity：输入 RSS 源 URL，经 BookApi
/// 逐步执行「查源 → 抓取文章」链路，实时输出调试日志
///（REFACTORING_REMAINING_PLAN §4.3 P2-2⑤）。
/// 架构合规（§0.2 铁律）：全部经RSS源和文章仓储，
/// 不直调 bridge。
class RssSourceDebugScreen extends ConsumerStatefulWidget {
  /// 可选：外部传入 RSS 源 URL 预填
  final String? sourceUrl;

  const RssSourceDebugScreen({super.key, this.sourceUrl});

  @override
  ConsumerState<RssSourceDebugScreen> createState() =>
      _RssSourceDebugScreenState();
}

class _RssSourceDebugScreenState extends ConsumerState<RssSourceDebugScreen> {
  final _sourceUrlCtrl = TextEditingController();
  final _logScrollCtrl = ScrollController();

  bool _running = false;
  final List<_DebugLogEntry> _logs = [];

  /// 当前启用的日志级别过滤器（全部启用时显示全部）
  final Set<_DebugLogLevel> _enabledLevels = _DebugLogLevel.values.toSet();

  @override
  void initState() {
    super.initState();
    if (widget.sourceUrl != null) {
      _sourceUrlCtrl.text = widget.sourceUrl!;
    }
  }

  @override
  void dispose() {
    _sourceUrlCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  /// 按当前过滤器筛选日志
  List<_DebugLogEntry> get _filteredLogs =>
      _logs.where((log) => _enabledLevels.contains(log.level)).toList();

  void _appendLog(
    String message, {
    _DebugLogLevel level = _DebugLogLevel.info,
  }) {
    if (!mounted) return;
    setState(
      () => _logs.add(
        _DebugLogEntry(time: DateTime.now(), message: message, level: level),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.jumpTo(_logScrollCtrl.position.maxScrollExtent);
      }
    });
  }

  /// 执行调试链路：查源 → 抓取文章
  Future<void> _runDebug() async {
    final l10n = context.l10n;
    final sourceUrl = _sourceUrlCtrl.text.trim();
    if (sourceUrl.isEmpty) {
      _appendLog(l10n.debugRssUrlRequired, level: _DebugLogLevel.error);
      return;
    }
    setState(() => _running = true);
    _appendLog(l10n.debugRssStarting);
    _appendLog(l10n.debugSourceAddress(sourceUrl));

    try {
      // 1. 查询已注册的 RSS 源
      _appendLog(l10n.debugRssQuery);
      final sources = await ref
          .read(rssSourceRepositoryProvider)
          .getRssSources();
      final source = sources.where((s) => s.sourceUrl == sourceUrl).firstOrNull;
      if (source == null) {
        _appendLog(l10n.debugRssUnregistered, level: _DebugLogLevel.warn);
      } else {
        _appendLog(
          l10n.debugSourceName(source.sourceName),
          level: _DebugLogLevel.success,
        );
      }

      // 2. 抓取文章列表
      _appendLog(l10n.debugRssFetch);
      final articles = await ref
          .read(rssArticleRepositoryProvider)
          .getRssArticles(sourceUrl);
      if (articles.isEmpty) {
        _appendLog(l10n.debugRssNoArticles, level: _DebugLogLevel.warn);
      } else {
        _appendLog(
          l10n.debugRssArticlesFound(articles.length),
          level: _DebugLogLevel.success,
        );
        for (var i = 0; i < articles.length && i < 10; i++) {
          final a = articles[i];
          _appendLog(
            '  [$i] ${a.title.isEmpty ? l10n.untitledArticle : a.title}',
          );
          if (a.url.isNotEmpty) {
            _appendLog(l10n.debugArticleLink(a.url));
          }
        }
        if (articles.length > 10) {
          _appendLog(l10n.debugRssArticlesOmitted(articles.length - 10));
        }
      }

      _appendLog(l10n.debugFinished, level: _DebugLogLevel.success);
    } catch (e) {
      _appendLog(
        l10n.debugException(e.toString()),
        level: _DebugLogLevel.error,
      );
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredLogs = _filteredLogs;

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(context.l10n.rssSourceDebugTitle),
        actions: [
          IconButton(
            icon: const Icon(Symbols.delete_rounded),
            tooltip: context.l10n.clearDebugLogs,
            onPressed: _logs.isEmpty
                ? null
                : () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // 输入区域
          Padding(
            // [LAYOUT_PLAN P2] 页面水平边距 16dp；输入区纵向 12dp
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sourceUrlCtrl,
                    // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme（不显式 border）
                    decoration: InputDecoration(
                      labelText: context.l10n.editorSourceUrl,
                      hintText: context.l10n.rssSourceUrlHint,
                      prefixIcon: const Icon(Symbols.rss_feed_rounded),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _runDebug(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _running ? null : _runDebug,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.play_arrow_rounded),
                  label: Text(
                    _running
                        ? context.l10n.debugRunning
                        : context.l10n.debugAction,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 日志级别过滤栏
          Padding(
            // [LAYOUT_PLAN P2] 组内行 vertical12/horizontal8（页面水平边距 16dp 由此保证）
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SingleChildScrollView(
              // 窄屏下 4 个级别 chip 一行放不下：横向滚动（宽屏无滚动条，视觉不变）
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Symbols.filter_alt_rounded, size: 18),
                  const SizedBox(width: 6),
                  for (final level in _DebugLogLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(level.label(context.l10n)),
                        selected: _enabledLevels.contains(level),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _enabledLevels.add(level);
                            } else {
                              _enabledLevels.remove(level);
                            }
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        selectedColor: level
                            .chipColor(theme)
                            .withValues(alpha: 0.25),
                        checkmarkColor: level.chipColor(theme),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 日志输出区
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Text(
                      _logs.isEmpty
                          ? context.l10n.debugRssEmptyHint
                          : context.l10n.debugNoMatchingLogs,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollCtrl,
                    // [LAYOUT_PLAN P2] 日志区边距统一 16dp（全局标尺）
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final timeStr =
                          '${_pad(log.time.hour)}:${_pad(log.time.minute)}:${_pad(log.time.second)}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        // [LAYOUT_PLAN P2] 状态色走 tonal（见 bgColor：各级别 container 底）
                        decoration: BoxDecoration(
                          color: log.level.bgColor(theme),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[$timeStr] ',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(
                                  color: log.level.color(theme),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 两位数补零
  String _pad(int v) => v.toString().padLeft(2, '0');
}

/// 日志级别
enum _DebugLogLevel {
  info,
  success,
  warn,
  error;

  /// 显示标签
  String label(AppLocalizations l10n) {
    switch (this) {
      case _DebugLogLevel.info:
        return 'INFO';
      case _DebugLogLevel.success:
        return l10n.debugLogSuccess;
      case _DebugLogLevel.warn:
        return 'WARN';
      case _DebugLogLevel.error:
        return 'ERROR';
    }
  }

  /// 文字颜色
  ///
  /// [UI_MD3_ALIGNMENT_PLAN.md Batch B B2] 状态语义色走 tonal role：
  /// 成功=primary、警告=tertiary、错误=error，亮暗自适应
  Color color(ThemeData theme) {
    switch (this) {
      case _DebugLogLevel.info:
        return theme.colorScheme.onSurface;
      case _DebugLogLevel.success:
        return theme.colorScheme.primary;
      case _DebugLogLevel.warn:
        return theme.colorScheme.tertiary;
      case _DebugLogLevel.error:
        return theme.colorScheme.error;
    }
  }

  /// 背景颜色
  Color bgColor(ThemeData theme) {
    switch (this) {
      case _DebugLogLevel.info:
        return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      case _DebugLogLevel.success:
        return theme.colorScheme.primaryContainer.withValues(alpha: 0.4);
      case _DebugLogLevel.warn:
        return theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4);
      case _DebugLogLevel.error:
        return theme.colorScheme.errorContainer.withValues(alpha: 0.4);
    }
  }

  /// 过滤芯片选中颜色
  ///
  /// [审计修复 §3.2] 作为选中背景与白色标签搭配，按亮暗选 shade 保证对比度 — Qoder
  /// [UI_MD3_ALIGNMENT_PLAN.md Batch B B2] 改走 tonal container role
  Color chipColor(ThemeData theme) {
    switch (this) {
      case _DebugLogLevel.info:
        return theme.colorScheme.outline;
      case _DebugLogLevel.success:
        return theme.colorScheme.primary;
      case _DebugLogLevel.warn:
        return theme.colorScheme.tertiary;
      case _DebugLogLevel.error:
        return theme.colorScheme.error;
    }
  }
}

/// 调试日志条目
class _DebugLogEntry {
  final DateTime time;
  final String message;
  final _DebugLogLevel level;

  _DebugLogEntry({
    required this.time,
    required this.message,
    this.level = _DebugLogLevel.info,
  });
}
