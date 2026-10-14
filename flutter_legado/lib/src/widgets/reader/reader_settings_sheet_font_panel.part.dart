// 字体设置复用原有字号、字距、缩进、斜体和字重配置。
// 标题字体归入页面布局；简繁转换归入内容处理。
// 本文件与阅读设置主文件共享导入；保存由阅读仓储逐字段执行。
part of 'reader_settings_sheet.dart';

/// 字体与正文排版直接读写共享阅读设置，不持有高级配置编辑副本。— Codex + UI
class ReaderFontPanel extends ConsumerStatefulWidget {
  final bool titleOnly;
  final bool embedded;
  final Widget? fontSizeControl;
  final Widget? lineHeightControl;

  const ReaderFontPanel({
    super.key,
    this.titleOnly = false,
    this.embedded = false,
    this.fontSizeControl,
    this.lineHeightControl,
  });

  @override
  ConsumerState<ReaderFontPanel> createState() => _ReaderFontPanelState();
}

class _ReaderFontPanelState extends ConsumerState<ReaderFontPanel> {
  ReaderTextLayoutSettings get _textLayout =>
      ref.read(readerSettingsRepositoryProvider).current.textLayout;

  String? get _fontLabel => ref
      .read(readerSettingsRepositoryProvider)
      .current
      .fontFamily
      ?.replaceFirst('Custom_', '');

  String get _titleFontLabel {
    final family = ref
        .read(readerSettingsRepositoryProvider)
        .current
        .titleFontFamily;
    return family.isEmpty ? '跟随正文' : family.replaceFirst('Custom_', '');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadFonts());
  }

  Future<void> _loadFonts() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
    } catch (error) {
      debugPrint('字体选择读取失败：$error');
    }
  }

  Future<void> _saveTextLayout(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('阅读排版保存失败，请重试')));
      }
    }
  }

  /// 面板内分组标题行
  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// 字体选择和缩进选择使用相同的设置行。
  Widget _row({required String title, String? value, VoidCallback? onTap}) =>
      SettingTile(title: title, value: value, onTap: onTap);

  Future<void> _selectFont({bool title = false}) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.fonts,
      arguments: title ? 'title' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readerSettingsProvider);
    if (widget.titleOnly) {
      final row = _row(
        title: '标题字体',
        value: _titleFontLabel,
        onTap: () => _selectFont(title: true),
      );
      return widget.embedded
          ? row
          : SettingsGroup(showDividers: false, children: [row]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          showDividers: false,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('正文字体', Icons.font_download_outlined),
                _row(
                  title: context.l10n.readerFont,
                  value: _fontLabel ?? context.l10n.readerDefaultFont,
                  onTap: _selectFont,
                ),
                if (widget.fontSizeControl != null) widget.fontSizeControl!,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.readerFontWeight,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 2,
                            label: Text(
                              context.l10n.readerWeightLight,
                              style: const TextStyle(
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: 0,
                            label: Text(
                              context.l10n.readerWeightRegular,
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text(
                              context.l10n.readerWeightBold,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        selected: {_textLayout.textBold.clamp(0, 2)},
                        onSelectionChanged: (selected) {
                          _saveTextLayout(
                            () => ref
                                .read(readerSettingsRepositoryProvider)
                                .updateTextLayout(textBold: selected.first),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SettingSwitchRow(
                  title: context.l10n.readerItalic,
                  value: _textLayout.italic,
                  onChanged: (value) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(italic: value),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          showDividers: false,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('间距与缩进', Icons.format_line_spacing_outlined),
                _ReaderSliderSetting(
                  title: '字间距',
                  displayValue:
                      '${_textLayout.letterSpacing.toStringAsFixed(2)} em',
                  value: _textLayout.letterSpacing,
                  min: -0.5,
                  max: 1,
                  divisions: 75,
                  onChanged: (value) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(letterSpacing: value),
                    );
                  },
                ),
                if (widget.lineHeightControl != null) widget.lineHeightControl!,
                _ReaderSliderSetting(
                  title: context.l10n.readerParagraphSpacing,
                  displayValue:
                      '${_textLayout.paragraphSpacing.toStringAsFixed(0)} dp',
                  value: _textLayout.paragraphSpacing,
                  min: 0,
                  max: 48,
                  divisions: 16,
                  onChanged: (value) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(paragraphSpacing: value),
                    );
                  },
                ),
                SettingMenuRow<int>(
                  title: '首行缩进',
                  value: _textLayout.paragraphIndent,
                  options: {
                    0: context.l10n.readerIndentNone,
                    1: context.l10n.readerIndentOne,
                    2: context.l10n.readerIndentTwo,
                    3: context.l10n.readerIndentThree,
                  },
                  onChanged: (value) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(paragraphIndent: value),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 间距设置统一为名称、带单位的当前值和整行滑条。
class _ReaderSliderSetting extends StatelessWidget {
  const _ReaderSliderSetting({
    required this.title,
    required this.displayValue,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String displayValue;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: displayValue,
          onChanged: onChanged,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ],
    ),
  );
}
