import '../../application/reader_settings_provider.dart';
import '../../../../domain/models/reader_page_layout_settings.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../../l10n/app_localization.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../../widgets/bottom_sheet_widget.dart';
import 'reader_padding_config_sheet.dart';

/// 页眉/页脚提示项（对标原版 ReadTipConfig.tipValues）
class ReadTipOption {
  final int value;
  final String label;
  const ReadTipOption(this.value, this.label);
}

/// 章节标题及页眉页脚统一配置正文之外的信息。— Codex + UI
enum ReaderTipSection { all, title, header, footer }

/// 阅读提示信息配置（对标原版 TipConfigDialog + dialog_tip_config.xml）
class ReaderTipConfigSheet extends ConsumerStatefulWidget {
  final bool embedded;
  final ReaderTipSection section;
  final Widget? titleFont;

  const ReaderTipConfigSheet({
    super.key,
    this.embedded = false,
    this.section = ReaderTipSection.all,
    this.titleFont,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      showDragHandle: false,

      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: const ReaderTipConfigSheet(),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderTipConfigSheet> createState() =>
      _ReaderTipConfigSheetState();
}

class _ReaderTipConfigSheetState extends ConsumerState<ReaderTipConfigSheet> {
  ReaderPageLayoutSettings get _layout =>
      ref.read(readerSettingsRepositoryProvider).current.pageLayout;
  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
    } catch (error) {
      debugPrint('页面提示设置读取失败：$error');
    }
  }

  List<ReadTipOption> get _tipOptions => [
    ReadTipOption(0, context.l10n.readerTipNone),
    ReadTipOption(7, context.l10n.readerTipBookName),
    ReadTipOption(1, context.l10n.readerTipChapterName),
    ReadTipOption(2, context.l10n.readerTipTime),
    ReadTipOption(3, context.l10n.readerTipBatteryIcon),
    ReadTipOption(10, context.l10n.readerTipBatteryPercent),
    ReadTipOption(4, context.l10n.readerTipPages),
    ReadTipOption(5, context.l10n.readerTipProgress),
    ReadTipOption(11, '章节进度'),
    ReadTipOption(6, context.l10n.readerTipPagesProgress),
    ReadTipOption(8, context.l10n.readerTipTimeBattery),
    ReadTipOption(9, context.l10n.readerTipTimeBatteryPercent),
  ];

  Map<int, String> get _headerModeOptions => {
    0: context.l10n.readerHideWithStatusBar,
    1: context.l10n.readerShow,
    2: context.l10n.readerHide,
  };

  Map<int, String> get _footerModeOptions => {
    0: context.l10n.readerShow,
    1: context.l10n.readerHide,
  };

  Future<void> _save(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('页面布局保存失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      readerSettingsProvider.select((value) => value.value?.pageLayout),
    );
    final groups = <Widget>[
      if (widget.section == ReaderTipSection.all ||
          widget.section == ReaderTipSection.title)
        _titleGroup(),
      if (widget.section == ReaderTipSection.all ||
          widget.section == ReaderTipSection.header)
        _edgeGroup(header: true),
      if (widget.section == ReaderTipSection.all ||
          widget.section == ReaderTipSection.footer)
        _edgeGroup(header: false),
    ];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) const Center(child: SheetDragHandle()),
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          groups[i],
        ],
      ],
    );
    if (widget.embedded) return content;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: content,
      ),
    );
  }

  Widget _titleGroup() => SettingsGroup(
    showDividers: false,
    title: context.l10n.readerChapterTitle,
    children: [
      SettingMenuRow<int>(
        title: '显示与对齐',
        value: _layout.title.mode.clamp(0, 2),
        options: {
          0: context.l10n.readerAlignLeft,
          1: context.l10n.readerAlignCenter,
          2: context.l10n.readerHide,
        },
        onChanged: (value) {
          _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(mode: value),
          );
        },
      ),
      if (_layout.title.mode != 2) ...[
        if (widget.titleFont != null) widget.titleFont!,
        SettingSwitchRow(
          title: '标题字号相对正文',
          value: _layout.title.sizeRelative,
          onChanged: (value) => _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(sizeRelative: value),
          ),
        ),
        _stepRow(
          _layout.title.sizeRelative ? '标题字号增量' : '标题字号',
          _layout.title.size,
          _layout.title.sizeRelative ? 0 : 1,
          60,
          (value) {
            _save(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateTitle(size: value),
            );
          },
          showPlus: _layout.title.sizeRelative,
          unit: 'sp',
        ),
        _stepRow(
          '标题字重',
          _layout.title.fontWeight,
          100,
          900,
          (value) {
            _save(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateTitle(fontWeight: value),
            );
          },
          step: 100,
          unit: '',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('标题行距'),
              Expanded(
                child: Slider(
                  value: _layout.title.lineHeight,
                  min: .1,
                  max: 2,
                  divisions: 19,
                  label: '${_layout.title.lineHeight.toStringAsFixed(1)}倍',
                  onChanged: (value) => _save(
                    () => ref
                        .read(readerSettingsRepositoryProvider)
                        .updateTitle(lineHeight: value),
                  ),
                ),
              ),
              Text('${_layout.title.lineHeight.toStringAsFixed(1)}倍'),
            ],
          ),
        ),
        SettingMenuRow<int>(
          title: '标题分段',
          value: _layout.title.segmentType,
          options: const {0: '关闭', 1: '按位置', 2: '按标记', 3: '按正则'},
          onChanged: (value) => _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(segmentType: value),
          ),
        ),
        if (_layout.title.segmentType == 1)
          _stepRow(
            '分段位置',
            _layout.title.segmentPosition,
            1,
            20,
            (value) => _save(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateTitle(segmentPosition: value),
            ),
            unit: '',
          ),
        if (_layout.title.segmentType == 2 || _layout.title.segmentType == 3)
          SettingTile(
            title: '分段规则',
            subtitle: _layout.title.segmentDelimiter.isEmpty
                ? '设置标记或正则表达式'
                : _layout.title.segmentDelimiter,
            onTap: _editTitleRule,
          ),
        _titleSlider(
          '副标题缩放',
          _layout.title.subtitleScale,
          .1,
          2,
          19,
          (value) => _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(subtitleScale: value),
          ),
        ),
        _titleSlider(
          '标题分段间距',
          _layout.title.segmentSpacing,
          -3,
          3,
          60,
          (value) => _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(segmentSpacing: value),
          ),
        ),
        const Divider(height: 16, indent: 16, endIndent: 16),
        _stepRow('标题上间距', _layout.title.topSpacing, 0, 200, (value) {
          _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(topSpacing: value),
          );
        }),
        _stepRow('标题下间距', _layout.title.bottomSpacing, 0, 200, (value) {
          _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(bottomSpacing: value),
          );
        }),
        const Divider(height: 16, indent: 16, endIndent: 16),
      ],
    ],
  );

  Widget _titleSlider(
    String title,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Text(title),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toStringAsFixed(1)}倍',
            onChanged: (v) => onChanged((v * 10).round() / 10),
          ),
        ),
        Text('${value.toStringAsFixed(1)}倍'),
      ],
    ),
  );

  Future<void> _editTitleRule() async {
    final result = await AppBottomSheet.showContent<String>(
      context: context,
      builder: (_) =>
          _TitleRuleEditor(initialText: _layout.title.segmentDelimiter),
    );
    if (!mounted || result == null) return;
    await _save(
      () => ref
          .read(readerSettingsRepositoryProvider)
          .updateTitle(segmentDelimiter: result),
    );
  }

  Widget _edgeGroup({required bool header}) {
    final edge = header ? ReaderPageEdge.header : ReaderPageEdge.footer;
    final settings = header ? _layout.header : _layout.footer;
    final repository = ref.read(readerSettingsRepositoryProvider);
    final label = header
        ? context.l10n.readerHeader
        : context.l10n.readerFooter;
    return SettingsGroup(
      showDividers: false,
      title: label,
      children: [
        SettingMenuRow<int>(
          title: '显示模式',
          value: settings.mode,
          options: header ? _headerModeOptions : _footerModeOptions,
          onChanged: (value) =>
              _save(() => repository.updatePageEdge(edge, mode: value)),
        ),
        if (settings.mode != (header ? 2 : 1)) ...[
          _tipRow(
            '左侧提示',
            settings.leftTip,
            (value) =>
                _save(() => repository.updatePageEdge(edge, leftTip: value)),
          ),
          _tipRow(
            '中间提示',
            settings.middleTip,
            (value) =>
                _save(() => repository.updatePageEdge(edge, middleTip: value)),
          ),
          _tipRow(
            '右侧提示',
            settings.rightTip,
            (value) =>
                _save(() => repository.updatePageEdge(edge, rightTip: value)),
          ),
          ReaderPaddingConfigSheet(
            embedded: true,
            region: header ? PaddingRegion.header : PaddingRegion.footer,
          ),
          SettingSwitchRow(
            title: context.l10n.readerShowDivider,
            value: settings.showLine,
            onChanged: (value) =>
                _save(() => repository.updatePageEdge(edge, showLine: value)),
          ),
        ],
      ],
    );
  }

  Widget _tipRow(String label, int current, ValueChanged<int> onPick) =>
      SettingMenuRow<int>(
        title: label,
        value: current,
        options: {for (final option in _tipOptions) option.value: option.label},
        onChanged: onPick,
      );

  Widget _stepRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    bool showPlus = false,
    double step = 1,
    String unit = 'dp',
  }) => SettingStepperRow(
    title: label,
    value: value.toDouble(),
    min: min.toDouble(),
    max: max.toDouble(),
    unit: unit,
    step: step,
    showPlus: showPlus,
    onChanged: (value) => onChanged(value.round()),
  );
}

/// 输入控制器随弹层销毁，关闭动画期间仍可正常读取。— Codex + UI
class _TitleRuleEditor extends StatefulWidget {
  final String initialText;
  const _TitleRuleEditor({required this.initialText});
  @override
  State<_TitleRuleEditor> createState() => _TitleRuleEditorState();
}

class _TitleRuleEditorState extends State<_TitleRuleEditor> {
  late final _controller = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet.content(
    title: '标题分段规则',
    contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    trailing: TextButton(
      onPressed: () => Navigator.of(context).pop(_controller.text),
      child: const Text('保存'),
    ),
    child: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      decoration: const InputDecoration(hintText: '标记用逗号分隔；正则在匹配结束处断开'),
    ),
  );
}
