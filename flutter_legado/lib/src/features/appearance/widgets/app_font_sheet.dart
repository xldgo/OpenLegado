import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/settings_widgets.dart';
import '../app_font_provider.dart';
import '../appearance_settings_provider.dart';

/// 应用界面字体与阅读字体分别选择，资产目录复用。— Codex + UI
class AppFontSheet extends ConsumerStatefulWidget {
  const AppFontSheet({super.key});
  @override
  ConsumerState<AppFontSheet> createState() => _AppFontSheetState();
}

class _AppFontSheetState extends ConsumerState<AppFontSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _select(String family) => _run(() async {
    await ref.read(appFontServiceProvider).select(family);
    ref.invalidate(appFontFamilyProvider);
  });

  Future<void> _import() => _run(() async {
    await ref.read(appFontServiceProvider).importFont();
    if (!mounted) return;
    ref.invalidate(availableAppFontsProvider);
    ref.invalidate(appFontFamilyProvider);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '字体设置失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(availableAppFontsProvider);
    final settings =
        ref.watch(appearanceSettingsProvider).value ??
        ref.read(appearanceSettingsRepositoryProvider).current;
    final runtime = ref.watch(appFontFamilyProvider);
    return AppBottomSheet(
      title: context.l10n.themeFontSettings,
      trailing: IconButton(
        tooltip: context.l10n.close,
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            context.l10n.themeFontPreview,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: runtime.hasError ? '' : runtime.value ?? '',
              height: 1.6,
            ),
          ),
        ),
        if (_error != null || runtime.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error ?? '已选字体无法加载，暂用默认字体',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _fontRow(context.l10n.readerDefaultFont, '', settings.fontFamily),
        if (available.isLoading) const LinearProgressIndicator(),
        if (available.hasError)
          SettingTile(
            title: '字体列表读取失败',
            value: '重试',
            onTap: () => ref.invalidate(availableAppFontsProvider),
          ),
        for (final font in available.value?.fonts ?? [])
          _fontRow(font.label, font.family, settings.fontFamily),
        if (available.value?.missing.isNotEmpty ?? false)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('部分字体文件缺失或无法加载，请重新导入'),
          ),
        SettingTile(
          title: context.l10n.themeFontImport,
          subtitle: 'TTF / OTF',
          icon: Icons.file_download_outlined,
          enabled: !_saving,
          onTap: _import,
        ),
        if (_saving) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _fontRow(String label, String family, String selected) => ListTile(
    enabled: !_saving,
    title: Text(label, style: TextStyle(fontFamily: family)),
    trailing: family == selected ? const Icon(Icons.check) : null,
    selected: family == selected,
    onTap: () => _select(family),
  );
}
