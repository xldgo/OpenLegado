import '../../providers/reader/reader_settings_provider.dart';
import '../../domain/models/reader_page_layout_settings.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../l10n/app_localization.dart';
import '../settings_widgets.dart';

/// 页面边距配置（对标原版 PaddingConfigDialog + dialog_read_padding.xml）
///
/// - 嵌入分组时直接显示区域，独立入口保留标准分段选择器
/// - 四向 ± 步进（DetailSeekBar 语义：上/下 0-400，左/右 0-100）
/// - 左右联动开关、页眉/页脚显示分隔线开关
class ReaderPaddingConfigSheet extends ConsumerStatefulWidget {
  final bool embedded;

  /// 指定区域时直接显示对应边距，不再绘制区域切换控件。
  final PaddingRegion? region;

  const ReaderPaddingConfigSheet({
    super.key,
    this.embedded = false,
    this.region,
  });

  static Future<void> show(BuildContext context) {
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
          child: const ReaderPaddingConfigSheet(),
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
  ReaderPageLayoutSettings get _layout =>
      ref.read(readerSettingsRepositoryProvider).current.pageLayout;
  PaddingRegion _region = PaddingRegion.body;
  bool _lockLr = false;

  @override
  void initState() {
    super.initState();
    _region = widget.region ?? PaddingRegion.body;
    _syncLockLrFromRegion();
    unawaited(_loadSettings());
  }

  void _syncLockLrFromRegion() {
    final left = _paddingFor(_region, _Side.left);
    final right = _paddingFor(_region, _Side.right);
    _lockLr = left == right;
  }

  @override
  void didUpdateWidget(covariant ReaderPaddingConfigSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region != widget.region) {
      _region = widget.region ?? PaddingRegion.body;
      _syncLockLrFromRegion();
    }
  }

  Future<void> _loadSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
      if (mounted) setState(_syncLockLrFromRegion);
    } catch (error) {
      debugPrint('页面边距读取失败：$error');
    }
  }

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

  double _paddingFor(PaddingRegion region, _Side side) {
    final padding = _layout.paddingFor(region);
    return switch (side) {
      _Side.top => padding.top,
      _Side.bottom => padding.bottom,
      _Side.left => padding.left,
      _Side.right => padding.right,
    };
  }

  Future<void> _savePadding({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) => _save(() {
    final repository = ref.read(readerSettingsRepositoryProvider);
    return switch (_region) {
      PaddingRegion.body => repository.updatePageLayout(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      ),
      PaddingRegion.header => repository.updatePageEdge(
        ReaderPageEdge.header,
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      ),
      PaddingRegion.footer => repository.updatePageEdge(
        ReaderPageEdge.footer,
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      ),
    };
  });

  Future<void> _updatePadding(_Side side, double proposedValue) => _savePadding(
    top: side == _Side.top ? proposedValue : null,
    bottom: side == _Side.bottom ? proposedValue : null,
    left: side == _Side.left || (_lockLr && side == _Side.right)
        ? proposedValue
        : null,
    right: side == _Side.right || (_lockLr && side == _Side.left)
        ? proposedValue
        : null,
  );

  Future<void> _resetRegion() async {
    final defaults = ReaderPageLayoutSettings.resetPaddingFor(_region);
    await _savePadding(
      top: defaults.top,
      bottom: defaults.bottom,
      left: defaults.left,
      right: defaults.right,
    );
    if (mounted) setState(_syncLockLrFromRegion);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      readerSettingsProvider.select((value) => value.value?.pageLayout),
    );
    final fixedRegion = widget.region != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) const Center(child: SheetDragHandle()),
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
              segments: [
                ButtonSegment(
                  value: PaddingRegion.header,
                  label: Text(context.l10n.readerHeader),
                ),
                ButtonSegment(
                  value: PaddingRegion.body,
                  label: Text(context.l10n.readerBody),
                ),
                ButtonSegment(
                  value: PaddingRegion.footer,
                  label: Text(context.l10n.readerFooter),
                ),
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
        _paddingRow(context.l10n.readerPaddingTop, _Side.top),
        _paddingRow(context.l10n.readerPaddingBottom, _Side.bottom),
        _paddingRow(context.l10n.readerPaddingLeft, _Side.left),
        _paddingRow(context.l10n.readerPaddingRight, _Side.right),
        const Divider(height: 16, indent: 16, endIndent: 16),
        SettingSwitchRow(
          title: '左右边距联动',
          value: _lockLr,
          onChanged: (v) => setState(() => _lockLr = v),
        ),
        if (fixedRegion)
          SettingTile(
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
    value: header ? _layout.header.showLine : _layout.footer.showLine,
    onChanged: (value) => _save(
      () => ref
          .read(readerSettingsRepositoryProvider)
          .updatePageEdge(
            header ? ReaderPageEdge.header : ReaderPageEdge.footer,
            showLine: value,
          ),
    ),
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
