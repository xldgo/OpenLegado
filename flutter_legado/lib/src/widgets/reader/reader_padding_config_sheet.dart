import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../screens/reader_config_panel.dart';
import '../settings_widgets.dart';

/// 页面边距配置（对标原版 PaddingConfigDialog + dialog_read_padding.xml）
///
/// - 嵌入分组时直接显示区域，独立入口保留标准分段选择器
/// - 四向 ± 步进（DetailSeekBar 语义：上/下 0-400，左/右 0-100）
/// - 左右联动开关、页眉/页脚显示分隔线开关
class ReaderPaddingConfigSheet extends ConsumerStatefulWidget {
  final ReaderAdvancedConfig config;
  final ValueChanged<ReaderAdvancedConfig>? onChanged;
  final bool embedded;

  /// 指定区域时直接显示对应边距，不再绘制区域切换控件。
  final PaddingRegion? region;

  const ReaderPaddingConfigSheet({
    super.key,
    required this.config,
    this.onChanged,
    this.embedded = false,
    this.region,
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
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: ReaderPaddingConfigSheet(config: config, onChanged: onChanged),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderPaddingConfigSheet> createState() =>
      _ReaderPaddingConfigSheetState();
}

class _ReaderPaddingConfigSheetState
    extends ConsumerState<ReaderPaddingConfigSheet> {
  late ReaderAdvancedConfig _config = widget.config.copy();
  PaddingRegion _region = PaddingRegion.body;
  bool _lockLr = false;

  @override
  void initState() {
    super.initState();
    _region = widget.region ?? PaddingRegion.body;
    _syncLockLrFromRegion();
  }

  void _syncLockLrFromRegion() {
    final left = _paddingFor(_region, _Side.left);
    final right = _paddingFor(_region, _Side.right);
    _lockLr = left == right;
  }

  @override
  void didUpdateWidget(covariant ReaderPaddingConfigSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _config = widget.config.copy();
    if (oldWidget.region != widget.region) {
      _region = widget.region ?? PaddingRegion.body;
      _syncLockLrFromRegion();
    }
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

  double _paddingFor(PaddingRegion region, _Side side) {
    switch (region) {
      case PaddingRegion.header:
        switch (side) {
          case _Side.top:
            return _config.headerPaddingTop;
          case _Side.bottom:
            return _config.headerPaddingBottom;
          case _Side.left:
            return _config.headerPaddingLeft;
          case _Side.right:
            return _config.headerPaddingRight;
        }
      case PaddingRegion.body:
        switch (side) {
          case _Side.top:
            return _config.pageMarginTop;
          case _Side.bottom:
            return _config.pageMarginBottom;
          case _Side.left:
            return _config.pageMarginLeft;
          case _Side.right:
            return _config.pageMarginRight;
        }
      case PaddingRegion.footer:
        switch (side) {
          case _Side.top:
            return _config.footerPaddingTop;
          case _Side.bottom:
            return _config.footerPaddingBottom;
          case _Side.left:
            return _config.footerPaddingLeft;
          case _Side.right:
            return _config.footerPaddingRight;
        }
    }
  }

  void _setPadding(PaddingRegion region, _Side side, double value) {
    switch (region) {
      case PaddingRegion.header:
        switch (side) {
          case _Side.top:
            _config.headerPaddingTop = value;
          case _Side.bottom:
            _config.headerPaddingBottom = value;
          case _Side.left:
            _config.headerPaddingLeft = value;
          case _Side.right:
            _config.headerPaddingRight = value;
        }
      case PaddingRegion.body:
        switch (side) {
          case _Side.top:
            _config.pageMarginTop = value;
          case _Side.bottom:
            _config.pageMarginBottom = value;
          case _Side.left:
            _config.pageMarginLeft = value;
          case _Side.right:
            _config.pageMarginRight = value;
        }
      case PaddingRegion.footer:
        switch (side) {
          case _Side.top:
            _config.footerPaddingTop = value;
          case _Side.bottom:
            _config.footerPaddingBottom = value;
          case _Side.left:
            _config.footerPaddingLeft = value;
          case _Side.right:
            _config.footerPaddingRight = value;
        }
    }
  }

  void _updatePadding(_Side side, double proposedValue) {
    final max = (side == _Side.left || side == _Side.right) ? 100.0 : 400.0;
    final value = proposedValue.clamp(0.0, max);
    _setPadding(_region, side, value);
    if (_lockLr && (side == _Side.left || side == _Side.right)) {
      final other = side == _Side.left ? _Side.right : _Side.left;
      _setPadding(_region, other, value);
    }
    _commit();
  }

  void _resetRegion() {
    for (final side in _Side.values) {
      final key = switch (side) {
        _Side.top => 'top',
        _Side.bottom => 'bottom',
        _Side.left => 'left',
        _Side.right => 'right',
      };
      _setPadding(
        _region,
        side,
        ReaderAdvancedConfig.defaultPaddingFor(_region, key),
      );
    }
    _syncLockLrFromRegion();
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final fixedRegion = widget.region != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) const Center(child: IosGrabber()),
        if (!fixedRegion) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '页面边距',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '恢复默认边距',
                  onPressed: _resetRegion,
                  icon: const Icon(Icons.restore),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<PaddingRegion>(
              segments: const [
                ButtonSegment(value: PaddingRegion.header, label: Text('页眉')),
                ButtonSegment(value: PaddingRegion.body, label: Text('正文')),
                ButtonSegment(value: PaddingRegion.footer, label: Text('页脚')),
              ],
              selected: {_region},
              onSelectionChanged: (selected) {
                setState(() {
                  _region = selected.first;
                  _syncLockLrFromRegion();
                });
              },
            ),
          ),
        ],
        const Divider(height: 16, indent: 16, endIndent: 16),
        _paddingRow('上边距', _Side.top),
        _paddingRow('下边距', _Side.bottom),
        _paddingRow('左边距', _Side.left),
        _paddingRow('右边距', _Side.right),
        const Divider(height: 16, indent: 16, endIndent: 16),
        SettingSwitchRow(
          title: '左右边距联动',
          value: _lockLr,
          onChanged: (v) => setState(() => _lockLr = v),
        ),
        if (fixedRegion)
          IosListTile(
            title: '恢复默认边距',
            trailing: const Icon(Icons.restore),
            showChevron: false,
            onTap: _resetRegion,
          ),
        if (!fixedRegion && _region == PaddingRegion.header)
          _lineSwitch(header: true)
        else if (!fixedRegion && _region == PaddingRegion.footer)
          _lineSwitch(header: false),
      ],
    );
    if (widget.embedded) return content;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: content,
      ),
    );
  }

  Widget _lineSwitch({required bool header}) => SettingSwitchRow(
    title: header ? '显示页眉分隔线' : '显示页脚分隔线',
    value: header ? _config.showHeaderLine : _config.showFooterLine,
    onChanged: (value) {
      if (header) {
        _config.showHeaderLine = value;
      } else {
        _config.showFooterLine = value;
      }
      _commit();
    },
  );

  Widget _paddingRow(String label, _Side side) => SettingStepperRow(
    title: label,
    value: _paddingFor(_region, side),
    min: 0,
    max: side == _Side.left || side == _Side.right ? 100 : 400,
    unit: 'dp',
    onChanged: (value) => _updatePadding(side, value),
  );
}

enum _Side { top, bottom, left, right }
