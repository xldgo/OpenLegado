import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../screens/reader_config_panel.dart';
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
  final ReaderAdvancedConfig config;
  final ValueChanged<ReaderAdvancedConfig>? onChanged;
  final bool embedded;
  final ReaderTipSection section;
  final bool showStatusBar;
  final Widget? titleFont;

  const ReaderTipConfigSheet({
    super.key,
    required this.config,
    this.onChanged,
    this.embedded = false,
    this.section = ReaderTipSection.all,
    this.showStatusBar = true,
    this.titleFont,
  });

  static Future<void> show(
    BuildContext context, {
    required ReaderAdvancedConfig config,
    ValueChanged<ReaderAdvancedConfig>? onChanged,
  }) {
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
          child: ReaderTipConfigSheet(config: config, onChanged: onChanged),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderTipConfigSheet> createState() =>
      _ReaderTipConfigSheetState();
}

class _ReaderTipConfigSheetState extends ConsumerState<ReaderTipConfigSheet> {
  late ReaderAdvancedConfig _config = widget.config.copy();

  static const _tipOptions = [
    ReadTipOption(0, '无'),
    ReadTipOption(7, '书名'),
    ReadTipOption(1, '章节名'),
    ReadTipOption(2, '时间'),
    ReadTipOption(3, '电量图标'),
    ReadTipOption(10, '电量百分比'),
    ReadTipOption(4, '页码'),
    ReadTipOption(5, '阅读进度'),
    ReadTipOption(11, '章节进度'),
    ReadTipOption(6, '页码+进度'),
    ReadTipOption(8, '时间+电量'),
    ReadTipOption(9, '时间+电量%'),
  ];

  static const _modeOptions = {0: '状态栏显示时隐藏', 1: '显示', 2: '隐藏'};

  @override
  void didUpdateWidget(covariant ReaderTipConfigSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _config = widget.config.copy();
  }

  void _commit() {
    if (widget.onChanged != null) {
      widget.onChanged!(_config.copy());
    } else {
      unawaited(_config.save());
    }
    ref.read(readerAdvConfigProvider.notifier).apply(_config.copy());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
        if (!widget.embedded) const Center(child: IosGrabber()),
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
    title: '章节标题',
    children: [
      SettingMenuRow<int>(
        title: '显示与对齐',
        value: _config.titleMode.clamp(0, 2),
        options: const {0: '居左', 1: '居中', 2: '隐藏'},
        onChanged: (value) {
          _config.titleMode = value;
          _commit();
        },
      ),
      if (_config.titleMode != 2) ...[
        if (widget.titleFont != null) widget.titleFont!,
        _stepRow('标题字号增量', _config.titleSize, 0, 20, (value) {
          _config.titleSize = value;
          _commit();
        }, showPlus: true),
        const Divider(height: 16, indent: 16, endIndent: 16),
        _stepRow('标题上间距', _config.titleTopSpacing, 0, 100, (value) {
          _config.titleTopSpacing = value;
          _commit();
        }),
        _stepRow('标题下间距', _config.titleBottomSpacing, 0, 100, (value) {
          _config.titleBottomSpacing = value;
          _commit();
        }),
        const Divider(height: 16, indent: 16, endIndent: 16),
      ],
    ],
  );

  Widget _edgeGroup({required bool header}) {
    final mode = header ? _config.headerMode : _config.footerMode;
    final label = header ? '页眉' : '页脚';
    return SettingsGroup(
      showDividers: false,
      title: label,
      children: [
        SettingMenuRow<int>(
          title: '显示模式',
          value: mode.clamp(0, 2),
          options: _modeOptions,
          onChanged: (value) {
            if (header) {
              _config.headerMode = value;
            } else {
              _config.footerMode = value;
            }
            _commit();
          },
        ),
        if (mode != 2) ...[
          _tipRow(
            '左侧提示',
            header ? _config.tipHeaderLeft : _config.tipFooterLeft,
            (value) {
              if (header) {
                _config.tipHeaderLeft = value;
              } else {
                _config.tipFooterLeft = value;
              }
              _commit();
            },
          ),
          _tipRow(
            '中间提示',
            header ? _config.tipHeaderMiddle : _config.tipFooterMiddle,
            (value) {
              if (header) {
                _config.tipHeaderMiddle = value;
              } else {
                _config.tipFooterMiddle = value;
              }
              _commit();
            },
          ),
          _tipRow(
            '右侧提示',
            header ? _config.tipHeaderRight : _config.tipFooterRight,
            (value) {
              if (header) {
                _config.tipHeaderRight = value;
              } else {
                _config.tipFooterRight = value;
              }
              _commit();
            },
          ),
          ReaderPaddingConfigSheet(
            config: _config.copy(),
            embedded: true,
            region: header ? PaddingRegion.header : PaddingRegion.footer,
            onChanged: (config) {
              _config = config.copy();
              _commit();
            },
          ),
          SettingSwitchRow(
            title: '显示分隔线',
            value: header ? _config.showHeaderLine : _config.showFooterLine,
            onChanged: (value) {
              if (header) {
                _config.showHeaderLine = value;
              } else {
                _config.showFooterLine = value;
              }
              _commit();
            },
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
        value: _config.showBattery,
        onChanged: (value) {
          _config.showBattery = value;
          _commit();
        },
      ),
      SettingSwitchRow(
        title: '显示时间',
        value: _config.showTime,
        onChanged: (value) {
          _config.showTime = value;
          _commit();
        },
      ),
      SettingSwitchRow(
        title: '显示进度',
        value: _config.showProgress,
        onChanged: (value) {
          _config.showProgress = value;
          _commit();
        },
      ),
      SettingSwitchRow(
        title: '显示章节名',
        value: _config.showChapterName,
        onChanged: (value) {
          _config.showChapterName = value;
          _commit();
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
