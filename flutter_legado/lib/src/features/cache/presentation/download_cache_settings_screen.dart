import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/request_settings.dart';
import '../../../domain/models/download_settings.dart';
import '../../../l10n/app_localization.dart';
import '../../../providers/config_settings_provider.dart';
import '../../../providers/download_settings_provider.dart';
import '../../../services/cache_service.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_settings_sheet.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/legado_app_bar.dart';
import '../../../widgets/settings_widgets.dart';
import '../application/download_cache_settings.dart';

/// 参照上游DownloadCacheConfig分组，独立承载已有下载/缓存偏好。— Codex + UI
class DownloadCacheSettingsScreen extends ConsumerStatefulWidget {
  const DownloadCacheSettingsScreen({super.key});

  @override
  ConsumerState<DownloadCacheSettingsScreen> createState() =>
      _DownloadCacheSettingsScreenState();
}

class _DownloadCacheSettingsScreenState
    extends ConsumerState<DownloadCacheSettingsScreen> {
  bool _busy = false;
  bool _editingSetting = false;

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editThreads() async {
    if (_busy || _editingSetting) return;
    // 模态弹层已阻止背景交互，仅防重入，不改变设置行外观。
    _editingSetting = true;
    final repository = ref.read(requestSettingsRepositoryProvider);
    try {
      try {
        await repository.reload();
        if (!mounted) return;
        ref.invalidate(requestSettingsProvider);
      } catch (_) {
        _toast('并发设置读取失败，请重试');
        return;
      }
      if (!mounted) return;
      final count = await AppBottomSheet.showContent<int>(
        context: context,
        builder: (_) => _IntegerSettingSheet(
          initial: repository.current.threadCount,
          title: '更新和搜索线程数',
          label: '线程数',
          minimum: RequestSettings.minThreadCount,
          maximum: RequestSettings.maxThreadCount,
        ),
      );
      if (count == null ||
          !mounted ||
          count == repository.current.threadCount) {
        return;
      }
      try {
        await repository.update(
          (settings) => settings.copyWith(threadCount: count),
        );
      } catch (_) {
        _toast('并发设置保存失败，请重试');
      }
    } finally {
      _editingSetting = false;
    }
  }

  Future<void> _editPreDownload({required bool previous}) async {
    if (_busy || _editingSetting) return;
    _editingSetting = true;
    final repository = ref.read(downloadSettingsRepositoryProvider);
    try {
      try {
        await repository.reload();
        if (!mounted) return;
        ref.invalidate(downloadSettingsProvider);
      } catch (_) {
        _toast('预下载设置读取失败，请重试');
        return;
      }
      if (!mounted) return;
      final count = await AppBottomSheet.showContent<int>(
        context: context,
        builder: (_) => _IntegerSettingSheet(
          initial: previous
              ? repository.current.preDownloadNumPrev
              : repository.current.preDownloadNum,
          title: previous
              ? context.l10n.preDownloadPrevious
              : context.l10n.preDownloadNext,
          label: '章节数',
          minimum: DownloadSettings.minChapters,
          maximum: DownloadSettings.maxChapters,
        ),
      );
      if (count == null || !mounted) return;
      try {
        await repository.update(
          (settings) => previous
              ? settings.copyWith(preDownloadNumPrev: count)
              : settings.copyWith(preDownloadNum: count),
        );
      } catch (_) {
        _toast('预下载设置保存失败，请重试');
      }
    } finally {
      _editingSetting = false;
    }
  }

  Future<void> _maintain({required bool shrink}) async {
    if (_busy || _editingSetting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(shrink ? '压缩数据库' : '清理缓存'),
        content: Text(shrink ? '压缩数据库？' : '清除已下载正文及章节缓存标记？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(shrink ? context.l10n.confirm : '清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    final actions = ref.read(downloadCacheActionsProvider);
    try {
      if (shrink) {
        final freed = await actions.shrinkDatabase();
        _toast(
          freed > 0 ? '压缩完成，释放 ${CacheService.formatSize(freed)}' : '无需压缩或压缩失败',
        );
      } else {
        await actions.clearBookCache();
        _toast('成功清理缓存');
      }
    } catch (error) {
      _toast('${shrink ? '压缩失败' : '清理失败'}：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(requestSettingsProvider);
    final download = ref.watch(downloadSettingsProvider);
    final downloadSnapshot = download.asData?.value;
    final pending = ref.watch(pendingDownloadSettingsProvider);
    final snapshot = pending.asData?.value;
    String description(String? value) =>
        '${value ?? (pending.hasError ? '读取失败' : '读取中…')}\n待实现';
    return AppScaffold(
      topBar: LegadoAppBar(title: Text(context.l10n.downloadAndCache)),
      body: SettingsBody(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            if (pending.hasError)
              SettingTile(
                title: '下载偏好读取失败',
                subtitle: '点按重试',
                onTap: () => ref.invalidate(pendingDownloadSettingsProvider),
              ),
            SettingsGroup(
              title: context.l10n.httpCache,
              children: [
                SettingTile(
                  title: context.l10n.coverCache,
                  subtitle: context.l10n.featurePending,
                  enabled: false,
                ),
                SettingTile(
                  title: context.l10n.mangaCache,
                  subtitle: context.l10n.featurePending,
                  enabled: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.downloadSettings,
              children: [
                SettingTile(
                  title: '更新和搜索线程数',
                  value: request.hasError
                      ? '读取失败'
                      : '${ref.read(requestSettingsRepositoryProvider).current.threadCount}',
                  subtitle: request.hasError ? '读取失败，点按重试' : '线程数太多会卡顿',
                  enabled: !_busy,
                  onTap: _busy ? null : _editThreads,
                ),
                SettingTile(
                  title: context.l10n.cacheBookThreadCount,
                  subtitle: context.l10n.featurePending,
                  enabled: false,
                ),
                SettingTile(
                  title: context.l10n.preDownloadNext,
                  value: download.hasError
                      ? '读取失败'
                      : downloadSnapshot == null
                      ? '读取中…'
                      : '${downloadSnapshot.preDownloadNum}',
                  subtitle: '预下载当前章节之后的正文，0 表示关闭',
                  enabled: !_busy,
                  onTap: _busy ? null : () => _editPreDownload(previous: false),
                ),
                SettingTile(
                  title: context.l10n.preDownloadPrevious,
                  value: download.hasError
                      ? '读取失败'
                      : downloadSnapshot == null
                      ? '读取中…'
                      : '${downloadSnapshot.preDownloadNumPrev}',
                  subtitle: '预下载当前章节之前的正文，0 表示关闭',
                  enabled: !_busy,
                  onTap: _busy ? null : () => _editPreDownload(previous: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.imageCache,
              children: [
                SettingTile(
                  title: context.l10n.advancedBitmapCache,
                  subtitle: description(
                    snapshot == null
                        ? null
                        : '当前最大缓存 ${snapshot.bitmapCacheSize} MB',
                  ),
                  enabled: false,
                ),
                SettingTile(
                  title: context.l10n.advancedMangaRetention,
                  subtitle: description(
                    snapshot == null
                        ? null
                        : '保留已读章节数量 ${snapshot.imageRetainNum}',
                  ),
                  enabled: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.networkSettings,
              children: [
                SettingTile(
                  title: context.l10n.advancedUserAgent,
                  subtitle: description(
                    snapshot == null
                        ? null
                        : snapshot.userAgent.isEmpty
                        ? context.l10n.readerDefault
                        : snapshot.userAgent,
                  ),
                  enabled: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.otherSettings,
              children: [
                SettingTile(
                  title: context.l10n.advancedClearCache,
                  subtitle: '清除已下载正文及章节缓存标记',
                  enabled: !_busy,
                  onTap: _busy ? null : () => _maintain(shrink: false),
                ),
                SettingTile(
                  title: context.l10n.advancedShrinkDatabase,
                  subtitle: context.l10n.advancedShrinkDatabaseDescription,
                  enabled: !_busy,
                  onTap: _busy ? null : () => _maintain(shrink: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 复用公共设置Sheet，数值校验只影响编辑态，不提前保存。— Codex + UI
class _IntegerSettingSheet extends StatefulWidget {
  const _IntegerSettingSheet({
    required this.initial,
    required this.title,
    required this.label,
    required this.minimum,
    required this.maximum,
  });
  final int initial;
  final String title;
  final String label;
  final int minimum;
  final int maximum;
  @override
  State<_IntegerSettingSheet> createState() => _IntegerSettingSheetState();
}

class _IntegerSettingSheetState extends State<_IntegerSettingSheet> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_text.text.trim());
    if (value == null || value < widget.minimum || value > widget.maximum) {
      setState(() => _error = '请输入 ${widget.minimum}～${widget.maximum} 之间的整数');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: widget.title,
    onSave: _save,
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: TextField(
      controller: _text,
      keyboardType: TextInputType.number,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
    ),
  );
}
