import '../../providers/reader/reader_settings_provider.dart';
import '../../domain/models/reader_status_strip_settings.dart';
import '../../domain/models/reader_page_layout_settings.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../l10n/app_localization.dart';
import '../settings_widgets.dart';
import 'reader_padding_config_sheet.dart';

/// 页眉/页脚提示项（对标原版 ReadTipConfig.tipValues）
class ReadTipOption {
  final int value;
  final String label;
  const ReadTipOption(this.value, this.label);
}

/// 完整页面按布局分组展示；阅读状态条在屏幕与工具栏页单独展示。
enum ReaderTipSection { all, title, header, footer, statusBar }

/// 阅读提示信息配置（对标原版 TipConfigDialog + dialog_tip_config.xml）
class ReaderTipConfigSheet extends ConsumerStatefulWidget {
  final bool embedded;
  final ReaderTipSection section;
  final bool showStatusBar;
  final Widget? titleFont;

  const ReaderTipConfigSheet({
    super.key,
    this.embedded = false,
    this.section = ReaderTipSection.all,
    this.showStatusBar = true,
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
  ReaderStatusStripSettings get _status =>
      ref.read(readerSettingsRepositoryProvider).current.statusStrip;

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

  Future<void> _saveStatus(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('阅读状态条保存失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      readerSettingsProvider.select((value) => value.value?.pageLayout),
    );
    if (widget.section == ReaderTipSection.statusBar ||
        (widget.section == ReaderTipSection.all && widget.showStatusBar)) {
      ref.watch(
        readerSettingsProvider.select((value) => value.value?.statusStrip),
      );
    }
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
      if (widget.section == ReaderTipSection.statusBar ||
          (widget.section == ReaderTipSection.all && widget.showStatusBar))
        _statusGroup(),
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
        _stepRow('标题字号增量', _layout.title.size, 0, 20, (value) {
          _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(size: value),
          );
        }, showPlus: true),
        const Divider(height: 16, indent: 16, endIndent: 16),
        _stepRow('标题上间距', _layout.title.topSpacing, 0, 100, (value) {
          _save(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTitle(topSpacing: value),
          );
        }),
        _stepRow('标题下间距', _layout.title.bottomSpacing, 0, 100, (value) {
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

  Widget _statusGroup() => SettingsGroup(
    title: '阅读状态条',
    titleSuffix: '阅读菜单隐藏时显示',
    showDividers: false,
    children: [
      SettingSwitchRow(
        title: '显示电量',
        value: _status.showBattery,
        onChanged: (value) {
          _saveStatus(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateStatusStrip(showBattery: value),
          );
        },
      ),
      SettingSwitchRow(
        title: '显示时间',
        value: _status.showTime,
        onChanged: (value) {
          _saveStatus(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateStatusStrip(showTime: value),
          );
        },
      ),
      SettingSwitchRow(
        title: '显示进度',
        value: _status.showProgress,
        onChanged: (value) {
          _saveStatus(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateStatusStrip(showProgress: value),
          );
        },
      ),
      SettingSwitchRow(
        title: '显示章节名',
        value: _status.showChapterName,
        onChanged: (value) {
          _saveStatus(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateStatusStrip(showChapterName: value),
          );
        },
      ),
    ],
  );

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
  }) => SettingStepperRow(
    title: label,
    value: value.toDouble(),
    min: min.toDouble(),
    max: max.toDouble(),
    unit: showPlus ? null : 'dp',
    showPlus: showPlus,
    onChanged: (value) => onChanged(value.round()),
  );
}
