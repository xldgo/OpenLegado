import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/request_settings.dart';
import '../../../l10n/app_localization.dart';
import '../../../providers/config_settings_provider.dart';
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

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editThreads() async {
    if (_busy) return;
    setState(() => _busy = true);
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
        builder: (_) =>
            _ThreadCountSheet(initial: repository.current.threadCount),
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _maintain({required bool shrink}) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(shrink ? '压缩数据库' : '清理缓存'),
        content: Text(shrink ? '压缩数据库？' : '清除已下载章节及通用缓存？'),
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
              title: context.l10n.downloadSettings,
              children: [
                SettingTile(
                  title: '更新和搜索线程数（太多会卡顿）',
                  value: request.hasError
                      ? '读取失败'
                      : '${ref.read(requestSettingsRepositoryProvider).current.threadCount}',
                  subtitle: request.hasError ? '点按重试' : '新任务生效，范围 1～256',
                  enabled: !_busy,
                  onTap: _busy ? null : _editThreads,
                ),
                SettingTile(
                  title: context.l10n.advancedPreDownload,
                  subtitle: description(
                    snapshot == null
                        ? null
                        : '预先下载 ${snapshot.preDownloadNum} 章正文',
                  ),
                  enabled: false,
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
                  subtitle: '清除已下载章节及通用缓存',
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
class _ThreadCountSheet extends StatefulWidget {
  const _ThreadCountSheet({required this.initial});
  final int initial;
  @override
  State<_ThreadCountSheet> createState() => _ThreadCountSheetState();
}

class _ThreadCountSheetState extends State<_ThreadCountSheet> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.initial}',
  );
  late int _preview = widget.initial;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_text.text.trim());
    if (value == null ||
        value < RequestSettings.minThreadCount ||
        value > RequestSettings.maxThreadCount) {
      setState(() => _error = '请输入 1～256 之间的整数');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: '更新和搜索线程数',
    onSave: _save,
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _text,
          keyboardType: TextInputType.number,
          onChanged: (text) => setState(() {
            _error = null;
            final parsed = int.tryParse(text.trim());
            if (parsed != null &&
                parsed >= RequestSettings.minThreadCount &&
                parsed <= RequestSettings.maxThreadCount) {
              _preview = parsed;
            }
          }),
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: '线程数',
            helperText: '1～256，新任务生效',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          min: RequestSettings.minThreadCount.toDouble(),
          max: RequestSettings.maxThreadCount.toDouble(),
          divisions:
              RequestSettings.maxThreadCount - RequestSettings.minThreadCount,
          value: _preview.toDouble(),
          label: '$_preview',
          onChanged: (value) => setState(() {
            _preview = value.round();
            _text.text = '$_preview';
            _error = null;
          }),
        ),
      ],
    ),
  );
}
