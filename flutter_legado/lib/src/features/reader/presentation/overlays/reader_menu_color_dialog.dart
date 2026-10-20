import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localization.dart';

/// 菜单颜色使用独立日夜值；零值表示沿用默认颜色。
class ReaderMenuColorDialog extends StatefulWidget {
  const ReaderMenuColorDialog({
    super.key,
    required this.title,
    required this.value,
    required this.fallback,
  });

  final String title;
  final int value;
  final Color fallback;

  @override
  State<ReaderMenuColorDialog> createState() => _ReaderMenuColorDialogState();
}

class _ReaderMenuColorDialogState extends State<ReaderMenuColorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: (widget.value == 0 ? widget.fallback.toARGB32() : widget.value)
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(text)) {
      setState(() => _error = context.l10n.readerMenuColorInvalid);
      return;
    }
    // 菜单实色不能靠透明值替代毛玻璃；透明度由现有模糊设置控制。
    final color = int.parse(text, radix: 16) | 0xFF000000;
    Navigator.pop(context, color);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final presets = <Color>{
      widget.fallback,
      colors.primary,
      Colors.white,
      Colors.black,
      const Color(0xFFF5EEDB),
      const Color(0xFFCCE8CF),
      const Color(0xFF6750A4),
      const Color(0xFF006A6A),
    };
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in presets)
                Tooltip(
                  message:
                      '#${color.toARGB32().toRadixString(16).toUpperCase()}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() {
                      _controller.text = color
                          .toARGB32()
                          .toRadixString(16)
                          .padLeft(8, '0')
                          .toUpperCase();
                      _error = null;
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.outline),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: context.l10n.readerMenuColorHex,
              hintText: 'RRGGBB',
              prefixText: '#',
              errorText: _error,
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: Text(context.l10n.readerMenuColorDefault),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: _confirm,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
