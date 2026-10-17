import '../../../providers/chapter_cache_provider.dart';
import '../../../domain/models/cache_download_task.dart';
import '../../../widgets/error_view.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../widgets/custom_refresh_indicator.dart';
import '../../../widgets/loading_indicator.dart';

/// 缓存下载队列页（对齐原版 CacheActivity 进度列表）
///
/// 轮询下载服务 展示批量缓存下载任务：
/// 任务状态（下载中/已完成/已取消/失败）、已完成/总数进度条、取消按钮。
/// [UI-fix v2.0.16 | 2026-08-10] 此前无下载队列页，且阅读页缓存按钮仅登记
/// 内存任务不执行下载 — Reasonix
class CacheDownloadScreen extends ConsumerStatefulWidget {
  const CacheDownloadScreen({super.key});

  @override
  ConsumerState<CacheDownloadScreen> createState() =>
      _CacheDownloadScreenState();
}

class _CacheDownloadScreenState extends ConsumerState<CacheDownloadScreen> {
  List<CacheDownloadTask> _tasks = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // 任务轮询（2s，页面可见期间保持实时；原版经 EventBus 实时刷新，
    // 重构版无事件总线，以轻量本地查询轮询等价实现）
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final tasks = await ref
          .read(cacheDownloadServiceProvider)
          .cacheDownloadList();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      // 查询失败保留最近一次成功结果，首次失败提供重试。
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '缓存下载队列加载失败';
      });
    }
  }

  Future<void> _cancel(int taskId) async {
    try {
      final downloads = ref.read(cacheDownloadServiceProvider);
      await downloads.cacheDownloadCancel(taskId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('取消失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: const Text('缓存下载队列'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Symbols.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null && _tasks.isEmpty
          ? ErrorView(message: _error!, onRetry: _refresh)
          : _tasks.isEmpty
          ? _buildEmpty(cs)
          // [LAYOUT_PLAN P4 收尾] 下拉 M3 化：裸 RefreshIndicator → CustomRefreshIndicator
          : CustomRefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                // [LAYOUT_PLAN P1] 列表边距统一 horizontal16（全局标尺）
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tasks.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) => _buildTaskTile(_tasks[index]),
              ),
            ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.download_done_rounded,
            size: 64,
            color: cs.outlineVariant,
          ),
          const SizedBox(height: 12),
          const Text('暂无缓存下载任务'),
          const SizedBox(height: 4),
          Text(
            '阅读页顶栏「缓存」按钮可发起批量缓存下载',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'running' => '下载中',
    'completed' => '已完成',
    'cancelled' => '已取消',
    'failed' => '失败',
    'notFound' => '已失效',
    _ => status,
  };

  Widget _buildTaskTile(CacheDownloadTask task) {
    final cs = Theme.of(context).colorScheme;
    final progress = task.total > 0 ? task.completed / task.total : 0.0;
    final color = switch (task.status) {
      'running' => cs.primary,
      // [UI_MD3_ALIGNMENT_PLAN.md Batch B B8] 完成态走 tonal
      'completed' => cs.tertiary,
      'cancelled' => cs.onSurfaceVariant,
      'failed' => cs.error,
      _ => cs.outline,
    };
    return ListTile(
      leading: Icon(
        task.isRunning
            ? Symbols.cloud_download_rounded
            : Symbols.cloud_done_rounded,
        color: color,
      ),
      title: Text(
        task.bookUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // [LAYOUT_PLAN P1] 标题字级走 titleSmall
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(
            '${_statusLabel(task.status)} · ${task.completed}/${task.total}'
            '${task.failed > 0 ? ' · 失败 ${task.failed}' : ''}',
            // [LAYOUT_PLAN P1] 元信息字级走 labelSmall
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      trailing: task.isRunning
          ? TextButton(
              onPressed: () => _cancel(task.taskId),
              child: const Text('取消'),
            )
          : null,
    );
  }
}
