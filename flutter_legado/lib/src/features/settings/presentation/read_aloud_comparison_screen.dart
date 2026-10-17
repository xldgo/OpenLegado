import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/read_aloud_comparison.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';
import '../../../widgets/settings_widgets.dart';
import '../application/read_aloud_comparison_provider.dart';

/// 用户手动听辨两种队列方式；不改变正式朗读配置。— Codex + UI
class ReadAloudComparisonScreen extends ConsumerStatefulWidget {
  const ReadAloudComparisonScreen({super.key, this.comparison});
  final ReadAloudComparison? comparison;

  @override
  ConsumerState<ReadAloudComparisonScreen> createState() =>
      _ReadAloudComparisonScreenState();
}

class _ReadAloudComparisonScreenState
    extends ConsumerState<ReadAloudComparisonScreen>
    with WidgetsBindingObserver {
  ReadAloudComparison? _comparison;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 手动听辨保持前台，锁屏/后台另作对照，避免混入生命周期差异。
    if (state == AppLifecycleState.paused && !_sharing) {
      unawaited(_comparison?.stop(reason: 'background'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 正式依赖由 autoDispose 释放；注入控制器由调用方持有。
    if (widget.comparison != null) {
      unawaited(_comparison?.stop(reason: 'leave'));
    }
    super.dispose();
  }

  Future<void> _share(File file) async {
    if (_sharing) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导出对照日志失败')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final comparison =
        widget.comparison ??
        ref.watch<ReadAloudComparison>(readAloudComparisonProvider);
    if (!identical(_comparison, comparison)) {
      _comparison = comparison;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(_comparison, comparison) &&
            comparison.fixture == null) {
          unawaited(comparison.prepare());
        }
      });
    }
    return AppScaffold(
      topBar: LegadoAppBar(title: const Text('朗读播放对照')),
      body: ListenableBuilder(
        listenable: comparison,
        builder: (context, _) {
          final enabled =
              !comparison.busy && !_sharing && comparison.fixture != null;
          return SettingsBody(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                const SettingsSectionFooter(
                  '连接同一副蓝牙耳机，保持前台与相同音量。依次播放A、B两组，听到卡顿或重播时立即标记。',
                ),
                SettingsGroup(
                  children: [
                    SettingTile(
                      title: '对照音频',
                      subtitle:
                          comparison.fixture?.label ?? '从最近有足够缓存的章节取6～8段音频',
                    ),
                    SettingTile(
                      title: '重新准备样本',
                      subtitle: '两组共用相同副本，固定1倍速，不发起合成',
                      onTap: comparison.busy || _sharing
                          ? null
                          : comparison.prepare,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: enabled
                                ? () => comparison.start(
                                    ReadAloudComparisonMode.fixed,
                                  )
                                : null,
                            child: const Text('播放A：固定列表'),
                          ),
                          const SizedBox(height: 8),
                          const Text('开始前一次装入全部音频，播放期间不追加或删除。'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: enabled
                                ? () => comparison.start(
                                    ReadAloudComparisonMode.dynamic,
                                  )
                                : null,
                            child: const Text('播放B：动态追加'),
                          ),
                          const SizedBox(height: 8),
                          const Text('先装入3段，自然换段后补充后续音频，保留已播项。'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    SettingTile(
                      title: comparison.status,
                      subtitle: comparison.currentIndex < 0
                          ? null
                          : '${_time(comparison.position)} / ${_time(comparison.duration)}',
                    ),
                    if (comparison.error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          comparison.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (comparison.running) ...[
                      SettingTile(title: '标记刚才的卡顿或重播', onTap: comparison.mark),
                      SettingTile(title: '停止本组并保存日志', onTap: comparison.stop),
                    ],
                    for (final result in comparison.reports.entries)
                      SettingTile(
                        title: result.key == ReadAloudComparisonMode.fixed
                            ? '导出A日志'
                            : '导出B日志',
                        onTap: _sharing || comparison.busy
                            ? null
                            : () => _share(result.value),
                      ),
                  ],
                ),
                const SettingsSectionFooter(
                  '开始对照会停止正文朗读，每组自动开启新的诊断。播放结束后分别导出日志；返回或进入后台会停止，不自动恢复正文。',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
