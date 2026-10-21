import '../../../utils/error_message.dart';
import '../../../l10n/app_localization.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../providers/explore/explore_dependencies.dart';
import '../../../domain/contracts/book_source_debug_service.dart';
import '../../../domain/models/book_source_debug_event.dart';
import '../../../widgets/help/help_assets.dart';
import '../../../widgets/help/show_help.dart';

/// 书源调试页面
///
/// 输入书源 URL 和搜索关键词，调用独立书源调试服务，
/// 实时显示调试日志输出，支持按日志级别过滤。
class SourceDebugScreen extends ConsumerStatefulWidget {
  /// 可选：从外部传入书源 URL 预填
  final String? sourceUrl;

  const SourceDebugScreen({super.key, this.sourceUrl});

  @override
  ConsumerState<SourceDebugScreen> createState() => _SourceDebugScreenState();
}

class _SourceDebugScreenState extends ConsumerState<SourceDebugScreen> {
  final _sourceUrlCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _logScrollCtrl = ScrollController();

  bool _running = false;
  int _debugGeneration = 0;
  BookSourceDebugService? _activeDebug;
  StreamIterator<BookSourceDebugEvent>? _debugIterator;
  final List<_DebugLogEntry> _logs = [];

  /// 当前启用的日志级别过滤（全部启用时显示所有）
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
    unawaited(_cancelDebug());
    _sourceUrlCtrl.dispose();
    _keywordCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  void _appendLog(
    String message, {
    _DebugLogLevel level = _DebugLogLevel.info,
  }) {
    if (!mounted) return;
    setState(() {
      _logs.add(
        _DebugLogEntry(time: DateTime.now(), message: message, level: level),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.jumpTo(_logScrollCtrl.position.maxScrollExtent);
      }
    });
  }

  /// 根据过滤条件获取可见日志
  List<_DebugLogEntry> get _filteredLogs {
    return _logs.where((log) => _enabledLevels.contains(log.level)).toList();
  }

  Future<void> _runDebug() async {
    if (_running) return;
    final l10n = context.l10n;
    final sourceUrl = _sourceUrlCtrl.text.trim();
    final keyword = _keywordCtrl.text.trim();

    if (sourceUrl.isEmpty) {
      _appendLog(l10n.debugBookSourceUrlRequired, level: _DebugLogLevel.error);
      return;
    }
    if (keyword.isEmpty) {
      _appendLog(l10n.debugKeywordRequired, level: _DebugLogLevel.error);
      return;
    }

    setState(() {
      _running = true;
      _logs.clear();
    });

    _appendLog(l10n.debugStarting);

    final generation = ++_debugGeneration;
    StreamIterator<BookSourceDebugEvent>? iterator;
    try {
      final service = ref.read(bookSourceDebugServiceProvider);
      _activeDebug = service;
      iterator = StreamIterator(service.debug(sourceUrl, keyword));
      _debugIterator = iterator;
      while (await iterator.moveNext()) {
        if (!mounted || generation != _debugGeneration) break;
        final event = iterator.current;
        if (event.message.isEmpty) continue;
        final level = event.state < 0
            ? _DebugLogLevel.error
            : event.state >= 1000
            ? _DebugLogLevel.success
            : _DebugLogLevel.info;
        _appendLog(event.message, level: level);
      }
    } catch (e) {
      if (generation == _debugGeneration) {
        _appendLog(
          l10n.debugException(errorMessage(e)),
          level: _DebugLogLevel.error,
        );
      }
    } finally {
      await iterator?.cancel();
      if (generation == _debugGeneration) {
        _activeDebug = null;
        _debugIterator = null;
        if (mounted) setState(() => _running = false);
      }
    }
  }

  Future<void> _cancelDebug() async {
    _debugGeneration++;
    final service = _activeDebug;
    final iterator = _debugIterator;
    _activeDebug = null;
    _debugIterator = null;
    try {
      await service?.cancel();
    } catch (_) {}
    await iterator?.cancel();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredLogs = _filteredLogs;

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      collapsibleTopBar: false,
      topBar: LegadoAppBar(
        title: Text(context.l10n.bookSourceDebugTitle),
        actions: [
          IconButton(
            icon: const Icon(Symbols.help_rounded),
            tooltip: context.l10n.help,
            onPressed: () => showHelp(context, HelpAssets.debugHelp),
          ),
          // 清除日志按钮
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _sourceUrlCtrl,
                  // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme，不手写边框
                  decoration: InputDecoration(
                    labelText: context.l10n.debugBookSourceUrlLabel,
                    hintText: context.l10n.debugBookSourceUrlHint,
                    prefixIcon: const Icon(Symbols.link_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keywordCtrl,
                        // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme，不手写边框
                        decoration: InputDecoration(
                          labelText: context.l10n.debugKeywordLabel,
                          hintText: context.l10n.debugKeywordHint,
                          prefixIcon: const Icon(Symbols.search_rounded),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _runDebug(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _running ? _cancelDebug : _runDebug,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.play_arrow_rounded),
                      label: Text(
                        _running
                            ? context.l10n.stopAction
                            : context.l10n.debugAction,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 日志级别过滤栏
          Padding(
            // [LAYOUT_PLAN P2] 页面水平边距统一 16dp（全局标尺）
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Symbols.filter_alt_rounded, size: 18),
                const SizedBox(width: 6),
                // 全选/取消全选按钮
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_enabledLevels.length ==
                          _DebugLogLevel.values.length) {
                        _enabledLevels.clear();
                      } else {
                        _enabledLevels
                          ..clear()
                          ..addAll(_DebugLogLevel.values);
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    _enabledLevels.length == _DebugLogLevel.values.length
                        ? context.l10n.deselectAll
                        : context.l10n.selectAll,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 4),
                // 各级别过滤芯片（横向可滚动，避免窄屏右溢出）
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _DebugLogLevel.values.map((level) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
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
                            selectedColor: level.chipColor(theme),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              // 标签使用背景对应的前景色，兼容深色主题和自定义配色。
                              color: _enabledLevels.contains(level)
                                  ? level.chipForeground(theme)
                                  : level.color(theme),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 日志计数
                Text(
                  context.l10n.debugLogCount(filteredLogs.length, _logs.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 日志输出区域
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.debugBookSourceEmptyHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : filteredLogs.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.debugNoMatchingLogs,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollCtrl,
                    // [LAYOUT_PLAN P2] 页面水平边距统一 16dp（全局标尺）
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return _buildLogEntry(log, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建单条日志条目（带左侧色条 + 背景色 + 图标）
  Widget _buildLogEntry(_DebugLogEntry log, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        // [LAYOUT_PLAN P2] 调试行状态色走 tonal container（见 bgColor）
        color: log.level.bgColor(theme),
        // [LAYOUT_PLAN P2] 分组卡圆角统一 16dp（全局标尺）
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: log.level.color(theme), width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 级别图标
          Icon(log.level.icon, size: 14, color: log.level.color(theme)),
          const SizedBox(width: 8),
          // 时间戳
          Text(
            _formatTime(log.time),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: log.level.color(theme).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          // 日志消息
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: log.level.color(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
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
  /// [UI_MD3_ALIGNMENT_PLAN.md Batch B B1] 状态语义色走 tonal role：
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
  /// 与过滤标签前景成对使用。
  Color chipColor(ThemeData theme) {
    switch (this) {
      case _DebugLogLevel.info:
        return theme.colorScheme.secondaryContainer;
      case _DebugLogLevel.success:
        return theme.colorScheme.primary;
      case _DebugLogLevel.warn:
        return theme.colorScheme.tertiary;
      case _DebugLogLevel.error:
        return theme.colorScheme.error;
    }
  }

  Color chipForeground(ThemeData theme) => switch (this) {
    _DebugLogLevel.info => theme.colorScheme.onSecondaryContainer,
    _DebugLogLevel.success => theme.colorScheme.onPrimary,
    _DebugLogLevel.warn => theme.colorScheme.onTertiary,
    _DebugLogLevel.error => theme.colorScheme.onError,
  };

  /// 级别图标
  IconData get icon {
    switch (this) {
      case _DebugLogLevel.info:
        return Symbols.info_rounded;
      case _DebugLogLevel.success:
        return Symbols.check_circle_rounded;
      case _DebugLogLevel.warn:
        return Symbols.warning_amber_rounded;
      case _DebugLogLevel.error:
        return Symbols.error_rounded;
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
