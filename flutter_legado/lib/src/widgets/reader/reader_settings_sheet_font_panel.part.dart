// 字体设置复用原有字号、字距、缩进、斜体和字重配置。
// 标题字体单独归入标题与信息；简繁转换归入内容与工具栏。
// 本文件与阅读设置主文件共享导入和配置提交方法。
part of 'reader_settings_sheet.dart';

/// 行内字体面板配置提交回调（对标 _commitAdv：持久化 + 推送共享 Provider）
typedef ReaderFontPanelCommit = void Function(ReaderAdvancedConfig config);

/// 字体设置控件，正文与章节标题分别展示，复用现有字体管理与配置保存。
class ReaderFontPanel extends ConsumerStatefulWidget {
  /// 当前高级配置快照（面板修改后经 [onChanged] 回传，主 Sheet 负责提交）
  final ReaderAdvancedConfig config;

  /// 配置变更提交（持久化 + 推送共享 Provider，对标 _commitAdv）
  final ReaderFontPanelCommit? onChanged;

  final bool titleOnly;
  final Widget? fontSizeControl;
  final Widget? lineHeightControl;

  const ReaderFontPanel({
    super.key,
    required this.config,
    this.onChanged,
    this.titleOnly = false,
    this.fontSizeControl,
    this.lineHeightControl,
  });

  @override
  ConsumerState<ReaderFontPanel> createState() => _ReaderFontPanelState();
}

class _ReaderFontPanelState extends ConsumerState<ReaderFontPanel> {
  /// 面板内可编辑配置副本（提交经 onChanged 回传主 Sheet）
  late ReaderAdvancedConfig _config;

  /// 当前正文字体显示名（与 FontScreen 持久化键 reader_font_family 同步，
  /// 读取方式对标 reader_config_panel._loadFontLabel）
  String _fontLabel = '默认字体';

  /// 当前标题字体显示名（与 FontScreen titleFont 键同步；
  /// 空=「跟随正文」，[C3 标题字体]）
  String _titleFontLabel = '跟随正文';

  @override
  void initState() {
    super.initState();
    _config = widget.config.copy();
    unawaited(_loadFontLabel());
    unawaited(_loadTitleFontLabel());
  }

  @override
  void didUpdateWidget(covariant ReaderFontPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 主 Sheet 重建（如切主题分桶重载）时同步外部配置快照
    if (oldWidget.config != widget.config) {
      _config = widget.config.copy();
    }
  }

  /// 从 SharedPreferences 读取当前阅读字体显示名
  Future<void> _loadFontLabel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final family = prefs.getString('reader_font_family');
      if (!mounted || family == null) return;
      setState(() => _fontLabel = family.replaceFirst('Custom_', ''));
    } catch (_) {
      // 读取失败保持默认字体标签
    }
  }

  /// 从 SharedPreferences 读取当前标题字体显示名（空=「跟随正文」）
  Future<void> _loadTitleFontLabel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final family = prefs.getString('titleFont') ?? '';
      if (!mounted) return;
      // 字体管理页已保存新值，回传配置时同步快照，避免旧值覆盖刚选的字体。
      _config.titleFont = family;
      setState(
        () => _titleFontLabel = family.isEmpty
            ? '跟随正文'
            : family.replaceFirst('Custom_', ''),
      );
    } catch (_) {
      // 读取失败保持跟随正文标签
    }
  }

  /// 提交配置（持久化 + 共享 Provider 推送）
  void _commit() {
    widget.onChanged?.call(_config.copy());
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
      ListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: onTap,
      );

  Future<void> _selectFont({bool title = false}) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.fonts,
      arguments: title ? 'title' : null,
    );
    if (!mounted) return;
    if (title) {
      await _loadTitleFontLabel();
    } else {
      await _loadFontLabel();
    }
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.titleOnly) {
      return SettingsGroup(
        children: [
          _row(
            title: '标题字体',
            value: _titleFontLabel,
            onTap: () => _selectFont(title: true),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('正文字体', Icons.font_download_outlined),
                _row(title: '字体', value: _fontLabel, onTap: _selectFont),
                if (widget.fontSizeControl != null) widget.fontSizeControl!,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '字重',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 2,
                            label: Text(
                              '细体',
                              style: TextStyle(fontWeight: FontWeight.w300),
                            ),
                          ),
                          ButtonSegment(
                            value: 0,
                            label: Text(
                              '常规',
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text(
                              '粗体',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        selected: {_config.textBold.clamp(0, 2)},
                        onSelectionChanged: (selected) {
                          _config.textBold = selected.first;
                          _commit();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                SettingSwitchRow(
                  title: '斜体',
                  value: _config.italic,
                  onChanged: (value) {
                    _config.italic = value;
                    _commit();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('间距与缩进', Icons.format_line_spacing_outlined),
                _ReaderSliderSetting(
                  title: '字间距',
                  displayValue:
                      '${_config.letterSpacing.toStringAsFixed(2)} em',
                  value: _config.letterSpacing,
                  min: -0.5,
                  max: 1,
                  divisions: 75,
                  onChanged: (value) {
                    _config.letterSpacing = value;
                    _commit();
                    setState(() {});
                  },
                ),
                if (widget.lineHeightControl != null) widget.lineHeightControl!,
                _ReaderSliderSetting(
                  title: '段间距',
                  displayValue:
                      '${_config.paragraphSpacing.toStringAsFixed(0)} dp',
                  value: _config.paragraphSpacing,
                  min: 0,
                  max: 48,
                  divisions: 16,
                  onChanged: (value) {
                    _config.paragraphSpacing = value;
                    _commit();
                    setState(() {});
                  },
                ),
                _row(
                  title: '首行缩进',
                  value: _indentLabel(_config.paragraphIndent),
                  onTap: () => _showChoiceDialog(
                    title: '首行缩进',
                    current: _config.paragraphIndent,
                    options: const {0: '无缩进', 1: '一字符', 2: '二字符', 3: '三字符'},
                    onPick: (value) {
                      _config.paragraphIndent = value;
                      _commit();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 缩进档位显示文案（对标 reader_config_panel._indentLabel）
  String _indentLabel(int v) {
    const labels = ['无缩进', '一字符', '二字符', '三字符'];
    if (v < 0 || v >= labels.length) return '二字符';
    return labels[v];
  }

  /// 单选对话框（对标原版 selector 交互，形态与既有面板一致）
  void _showChoiceDialog<T>({
    required String title,
    required T current,
    required Map<T, String> options,
    required ValueChanged<T> onPick,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: [
          for (final entry in options.entries)
            ListTile(
              title: Text(entry.value),
              trailing: current == entry.key
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                Navigator.pop(dialogContext);
                onPick(entry.key);
              },
            ),
        ],
      ),
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
