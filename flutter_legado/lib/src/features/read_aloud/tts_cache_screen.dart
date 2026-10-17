import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../audio/application/audio_notifier.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import 'tts_cache_provider.dart';

/// 展示 Rust 缓存索引与本会话预合成日志。— Codex + UI
class TtsCacheScreen extends ConsumerWidget {
  const TtsCacheScreen({super.key});
  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
  Future<void> _clear(
    BuildContext context,
    WidgetRef ref, {
    String? name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(name == null ? '清空朗读缓存？' : '删除该音频缓存？'),
        content: const Text('正在合成或播放的音频会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(ttsCacheProvider.notifier)
          .clear(name: name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已删除 ${result.removedFiles} 个文件，保留 ${result.skippedFiles} 个活动缓存',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清理失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ttsCacheProvider);
    final logs = ref.read(audioNotifierProvider.notifier).prefetchDiagnostics;
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        topBar: LegadoAppBar(
          title: const Text('朗读缓存'),
          actions: [
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(ttsCacheProvider.notifier).reload(),
            ),
            IconButton(
              tooltip: '清空缓存',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clear(context, ref),
            ),
          ],
        ),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '缓存'),
                Tab(text: '日志'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  entries.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('读取缓存失败：$e')),
                    data: (values) => values.isEmpty
                        ? const Center(child: Text('暂无朗读缓存'))
                        : ListView(
                            children: [
                              ListTile(
                                title: Text(
                                  '${values.length} 个音频 · ${_size(values.fold<int>(0, (n, e) => n + e.sizeBytes))}',
                                ),
                              ),
                              for (final entry in values)
                                ListTile(
                                  title: Text(
                                    entry.contexts.isEmpty
                                        ? entry.name
                                        : '${entry.contexts.first.bookName} · ${entry.contexts.first.chapterTitle}',
                                  ),
                                  subtitle: Text(
                                    '${_size(entry.sizeBytes)}${entry.protected ? ' · 使用中' : ''}${entry.contexts.length > 1 ? ' · ${entry.contexts.length} 处关联' : ''}',
                                  ),
                                  trailing: IconButton(
                                    tooltip: entry.protected
                                        ? '使用中的音频不能删除'
                                        : '删除音频',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: entry.protected
                                        ? null
                                        : () => _clear(
                                            context,
                                            ref,
                                            name: entry.name,
                                          ),
                                  ),
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('音频缓存'),
                                      content: SingleChildScrollView(
                                        child: SelectableText(
                                          '${entry.name}\n${_size(entry.sizeBytes)}\n${DateTime.fromMillisecondsSinceEpoch(entry.modifiedAtMs)}\n\n${entry.contexts.map((v) => '${v.bookName} · ${v.chapterTitle}\n${v.text}').join('\n\n')}',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text('关闭'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  logs.isEmpty
                      ? const Center(child: Text('暂无预合成日志'))
                      : ListView(
                          children: [
                            for (final log in logs) ListTile(title: Text(log)),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
