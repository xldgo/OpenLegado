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

  const ReaderFontPanel({
    super.key,
    required this.config,
    this.onChanged,
    this.titleOnly = false,
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

  /// 字体分组容器，与其他设置分组统一。
  Widget _card(Widget child) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  /// 面板内分组标题行
  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  /// 面板内跳转/选择行（标题 + 副标题 + 当前值 + chevron）
  Widget _row({
    required String title,
    String? subtitle,
    String? value,
    VoidCallback? onTap,
    bool disabled = false,
    IconData? leading,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(
                leading,
                size: 20,
                color: disabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: disabled
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: disabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(width: 4),
            if (!disabled)
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.titleOnly) ...[
            // ===== 标题字体（对标原版 #1072 titleFont：空值=跟随正文字体） =====
            // [C3 标题字体 | full-stack-engineer + UI] 我方已有纯 Dart 配置字段
            // ReaderAdvancedConfig.titleFont（不涉 Rust/FFI），行跳转
            // FontScreen(target: 'title')；返回后重读标签并通知主 Sheet 推送
            // 共享配置（ReaderPageView 重读字体并触发重分页）
            _row(
              title: '标题字体',
              subtitle: '章节标题独立字体',
              value: _titleFontLabel,
              leading: Icons.title_outlined,
              onTap: () async {
                await Navigator.pushNamed(
                  context,
                  AppRoutes.fonts,
                  arguments: 'title',
                );
                if (!mounted) return;
                await _loadTitleFontLabel();
                _commit();
              },
            ),
          ] else ...[
            _sectionTitle('正文字体', Icons.font_download_outlined),
            // ===== 正文字体 / 选择字体（既有字体管理页链路，不重写） =====
            _row(
              title: '选择字体',
              subtitle: '正文字体',
              value: _fontLabel,
              leading: Icons.text_fields_outlined,
              onTap: () async {
                await Navigator.pushNamed(context, AppRoutes.fonts);
                if (!mounted) return;
                // 返回后重读字体标签并通知主 Sheet 推送共享配置
                // （ReaderPageView.didUpdateWidget 重读字体配置）
                await _loadFontLabel();
                _commit();
              },
            ),
            // ===== 正文字距（对标原版 dsb_text_letter_spacing，
            // letterSpacing em -0.5~1.0，(p-50)/100 语义） =====
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Text('正文字距', style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: _config.letterSpacing.clamp(-0.5, 1.0),
                      min: -0.5,
                      max: 1.0,
                      divisions: 75,
                      label: _config.letterSpacing.toStringAsFixed(2),
                      onChanged: (v) {
                        _config.letterSpacing = v;
                        _commit();
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _config.letterSpacing.toStringAsFixed(2),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            // ===== 首行缩进（对标原版 tv_text_indent，5 档 无/一/二/三/四字符；
            // 我方既有字段 paragraphIndent 档位 0-3，按我方取值范围取前 4 档） =====
            _row(
              title: '首行缩进',
              value: _indentLabel(_config.paragraphIndent),
              onTap: () => _showChoiceDialog(
                title: '首行缩进',
                current: _config.paragraphIndent,
                options: const {0: '无缩进', 1: '一字符', 2: '二字符', 3: '三字符'},
                onPick: (v) {
                  _config.paragraphIndent = v;
                  _commit();
                  setState(() {});
                },
              ),
            ),
            // ===== 斜体开关 =====
            // [C3 双基准对齐 | Qoder UI] 参考版行内面板含「斜体」开关（原版无此项
            // —— 开源版全仓无斜体配置字段）。按项目双基准口径（原版 + 参考版）补齐：
            // 新增 ReaderAdvancedConfig.italic，并贯通分页测量与渲染两侧
            //（ParagraphConfig.fontStyle → 测量/渲染同源同参，避免分页偏差）。
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('斜体'),
              subtitle: const Text('正文使用倾斜字体'),
              value: _config.italic,
              onChanged: (v) {
                _config.italic = v;
                _commit();
                setState(() {});
              },
            ),
            // ===== 字重（对标原版 TextFontWeightConverter：0中/1粗/2细，
            // 既有字段 ReaderAdvancedConfig.textBold） =====
            Row(
              children: [
                Text('字重', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('中')),
                      ButtonSegment(value: 1, label: Text('粗')),
                      ButtonSegment(value: 2, label: Text('细')),
                    ],
                    selected: {_config.textBold.clamp(0, 2)},
                    onSelectionChanged: (sel) {
                      _config.textBold = sel.first;
                      _commit();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
