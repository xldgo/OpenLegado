import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localization.dart';
import '../../../models/theme_preset.dart';

/// 命名主题编辑器，输入控制器随对话框离场释放。
class ThemePresetNameDialog extends StatefulWidget {
  const ThemePresetNameDialog({super.key, required this.isNight});
  final bool isNight;

  @override
  State<ThemePresetNameDialog> createState() => _ThemePresetNameDialogState();
}

class _ThemePresetNameDialogState extends State<ThemePresetNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isNight ? '保存夜间主题' : '保存白天主题'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: context.l10n.themeThemeName),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(context.l10n.confirm),
      ),
    ],
  );
}

/// 列表只管理弹层交互；保存完成后再更新列表，失败保留原条目。
class ThemePresetListDialog extends StatefulWidget {
  const ThemePresetListDialog({
    super.key,
    required this.presets,
    required this.onDelete,
    required this.onApply,
    required this.onError,
  });

  final List<ThemePreset> presets;
  final Future<List<ThemePreset>> Function(int index) onDelete;
  final Future<void> Function(ThemePreset preset) onApply;
  final void Function(Object error) onError;

  @override
  State<ThemePresetListDialog> createState() => _ThemePresetListDialogState();
}

class _ThemePresetListDialogState extends State<ThemePresetListDialog> {
  late List<ThemePreset> _presets = List.of(widget.presets);
  bool _busy = false;

  Future<void> _delete(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final presets = await widget.onDelete(index);
      if (mounted) setState(() => _presets = presets);
    } catch (error) {
      if (mounted) widget.onError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(ThemePreset preset) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onApply(preset);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) widget.onError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.themeManagement),
    content: SizedBox(
      width: 320,
      child: _presets.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无保存的主题配置\n可在下方"保存白天/夜间主题"后于此切换'),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _presets.length,
              itemBuilder: (context, index) {
                final preset = _presets[index];
                return ListTile(
                  leading: Icon(
                    preset.isNight
                        ? Symbols.dark_mode_rounded
                        : Symbols.light_mode_rounded,
                  ),
                  title: Text(preset.name),
                  subtitle: Text(preset.isNight ? '夜间主题' : '白天主题'),
                  trailing: IconButton(
                    icon: const Icon(Symbols.delete_rounded),
                    onPressed: _busy ? null : () => _delete(index),
                  ),
                  onTap: _busy ? null : () => _apply(preset),
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.close),
      ),
    ],
  );
}
