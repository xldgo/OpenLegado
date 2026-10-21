import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/reader_page_layout_settings.dart';

/// 页面布局的键、解码与局部写入映射；不持有状态或执行IO。— Codex + UI
final class ReaderPageLayoutCodec {
  const ReaderPageLayoutCodec();
  static const _defaults = ReaderPageLayoutSettings();
  static const _keys = [
    'page_margin_top',
    'page_margin_bottom',
    'page_margin_left',
    'page_margin_right',
    'double_horizontal_page',
    'title_mode',
    'title_size',
    'title_top_spacing',
    'title_bottom_spacing',
    'header_padding_top',
    'header_padding_bottom',
    'header_padding_left',
    'header_padding_right',
    'header_mode',
    'header_show_line',
    'header_tip_left',
    'header_tip_middle',
    'header_tip_right',
    'footer_padding_top',
    'footer_padding_bottom',
    'footer_padding_left',
    'footer_padding_right',
    'footer_mode',
    'footer_show_line',
    'footer_tip_left',
    'footer_tip_middle',
    'footer_tip_right',
  ];
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: 'reader_$key');
  Set<SettingsAddress> get addresses => {
    for (final key in _keys) _address(key),
  };

  double _double(
    AppSettingsSnapshot snapshot,
    String key,
    double fallback,
    double max,
  ) {
    final value = snapshot[_address(key)];
    return (value is double ? value : fallback).clamp(0.0, max);
  }

  int _int(AppSettingsSnapshot snapshot, String key, int fallback, {int? max}) {
    final value = snapshot[_address(key)];
    final decoded = value is int ? value : fallback;
    return max == null ? decoded : decoded.clamp(0, max);
  }

  bool _bool(AppSettingsSnapshot snapshot, String key, bool fallback) {
    final value = snapshot[_address(key)];
    return value is bool ? value : fallback;
  }

  ReaderPagePadding _padding(
    AppSettingsSnapshot snapshot,
    String prefix,
    ReaderPagePadding defaults,
  ) => ReaderPagePadding(
    top: _double(snapshot, '${prefix}_top', defaults.top, 400),
    bottom: _double(snapshot, '${prefix}_bottom', defaults.bottom, 400),
    left: _double(snapshot, '${prefix}_left', defaults.left, 100),
    right: _double(snapshot, '${prefix}_right', defaults.right, 100),
  );
  ReaderPageEdgeSettings _edge(
    AppSettingsSnapshot snapshot,
    ReaderPageEdge edge,
  ) {
    final defaults = edge == ReaderPageEdge.header
        ? _defaults.header
        : _defaults.footer;
    final prefix = edge.name;
    return ReaderPageEdgeSettings(
      padding: _padding(snapshot, '${prefix}_padding', defaults.padding),
      mode: _int(
        snapshot,
        '${prefix}_mode',
        defaults.mode,
        max: edge == ReaderPageEdge.header ? 2 : 1,
      ),
      showLine: _bool(snapshot, '${prefix}_show_line', defaults.showLine),
      leftTip: _int(snapshot, '${prefix}_tip_left', defaults.leftTip),
      middleTip: _int(snapshot, '${prefix}_tip_middle', defaults.middleTip),
      rightTip: _int(snapshot, '${prefix}_tip_right', defaults.rightTip),
    );
  }

  ReaderPageLayoutSettings decode(AppSettingsSnapshot snapshot) =>
      ReaderPageLayoutSettings(
        bodyPadding: _padding(snapshot, 'page_margin', _defaults.bodyPadding),
        doubleHorizontalPage: _int(
          snapshot,
          'double_horizontal_page',
          0,
          max: 3,
        ),
        title: ReaderTitleSettings(
          mode: _int(snapshot, 'title_mode', _defaults.title.mode, max: 2),
          size: _int(snapshot, 'title_size', _defaults.title.size, max: 20),
          topSpacing: _int(
            snapshot,
            'title_top_spacing',
            _defaults.title.topSpacing,
            max: 100,
          ),
          bottomSpacing: _int(
            snapshot,
            'title_bottom_spacing',
            _defaults.title.bottomSpacing,
            max: 100,
          ),
        ),
        header: _edge(snapshot, ReaderPageEdge.header),
        footer: _edge(snapshot, ReaderPageEdge.footer),
      );

  Map<SettingsAddress, Object?> _paddingPatch(
    String prefix, {
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) => {
    _address('${prefix}_top'): ?top?.clamp(0.0, 400.0),
    _address('${prefix}_bottom'): ?bottom?.clamp(0.0, 400.0),
    _address('${prefix}_left'): ?left?.clamp(0.0, 100.0),
    _address('${prefix}_right'): ?right?.clamp(0.0, 100.0),
  };
  Map<SettingsAddress, Object?> pagePatch({
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? doubleHorizontalPage,
  }) => {
    ..._paddingPatch(
      'page_margin',
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    ),
    _address('double_horizontal_page'): ?doubleHorizontalPage?.clamp(0, 3),
  };
  Map<SettingsAddress, Object?> edgePatch(
    ReaderPageEdge edge, {
    required ReaderPageLayoutSettings current,
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? mode,
    bool? showLine,
    int? leftTip,
    int? middleTip,
    int? rightTip,
  }) {
    final patch = <SettingsAddress, Object?>{
      ..._paddingPatch(
        '${edge.name}_padding',
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      ),
      _address('${edge.name}_mode'): ?mode?.clamp(
        0,
        edge == ReaderPageEdge.header ? 2 : 1,
      ),
      _address('${edge.name}_show_line'): ?showLine,
      _address('${edge.name}_tip_left'): ?leftTip,
      _address('${edge.name}_tip_middle'): ?middleTip,
      _address('${edge.name}_tip_right'): ?rightTip,
    };
    final slots = <SettingsAddress, int>{
      for (final (region, settings) in [
        (ReaderPageEdge.header, current.header),
        (ReaderPageEdge.footer, current.footer),
      ])
        for (final (position, tip) in [
          ('left', settings.leftTip),
          ('middle', settings.middleTip),
          ('right', settings.rightTip),
        ])
          _address('${region.name}_tip_$position'): tip,
    };
    // 只处理本次明确选择的提示；同类型移到新槽位，0允许出现在多处。— Codex + UI
    for (final (position, selected) in [
      ('left', leftTip),
      ('middle', middleTip),
      ('right', rightTip),
    ]) {
      if (selected == null) continue;
      final target = _address('${edge.name}_tip_$position');
      if (selected != 0) {
        for (final slot in slots.keys) {
          if (slot != target && slots[slot] == selected) {
            slots[slot] = 0;
            patch[slot] = 0;
          }
        }
      }
      slots[target] = selected;
      patch[target] = selected;
    }
    return patch;
  }

  Map<SettingsAddress, Object?> titlePatch({
    int? mode,
    int? size,
    int? topSpacing,
    int? bottomSpacing,
  }) => {
    _address('title_mode'): ?mode?.clamp(0, 2),
    _address('title_size'): ?size?.clamp(0, 20),
    _address('title_top_spacing'): ?topSpacing?.clamp(0, 100),
    _address('title_bottom_spacing'): ?bottomSpacing?.clamp(0, 100),
  };
}
