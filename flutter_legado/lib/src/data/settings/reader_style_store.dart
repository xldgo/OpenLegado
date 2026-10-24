import 'dart:convert';

import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/reader_style.dart';
import '../services/app_settings_service.dart';
import 'reader_layout_presets.dart';

/// 阅读样式文档的唯一编解码与读改写入口；布局字段由阅读设置映射提供。— Codex + Data
final class ReaderStyleStore {
  ReaderStyleStore(this._service, {required this.layoutAddresses});
  final Set<SettingsAddress> layoutAddresses;
  final AppSettingsService _service;
  static const document = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_styles',
  );
  static const _legacyKeys = {
    'reader_bg_color_index',
    'reader_custom_bg_color',
    'reader_bg_use_custom',
    'reader_adv_custom_text_color',
  };
  static final _legacyAddresses = {
    for (final key in _legacyKeys)
      (storage: SettingsStorageKind.preferences, key: key),
  };
  Future<ReaderStyles>? _loading;
  bool _loaded = false;

  ReaderStyles _decode(AppSettingsSnapshot snapshot) {
    final raw = snapshot[document];
    if (raw == null) return _legacy(snapshot);
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final rows = map['styles'] as List<dynamic>;
      final defaults = ReaderStyles.defaults();
      final styles = defaults.styles.map((style) {
        final row = rows
            .cast<Map<String, dynamic>>()
            .where((row) => row['id'] == style.id)
            .firstOrNull;
        if (row == null) return style;
        ReaderColors colors(String key) {
          final data = row[key] as Map<String, dynamic>;
          return ReaderColors(
            background: data['background'] as int?,
            text: data['text'] as int?,
          );
        }

        return ReaderStyle(
          id: style.id,
          name: style.name,
          day: colors('day'),
          night: colors('night'),
        );
      });
      return ReaderStyles(
        selectedId: 'custom',
        styles: [
          ...styles,
          for (final row in rows.cast<Map<String, dynamic>>())
            if (!defaults.styles.any((style) => style.id == row['id']))
              ReaderStyle(
                id: row['id'] as String,
                name: row['name'] as String,
                day: ReaderColors(
                  background: (row['day'] as Map)['background'] as int?,
                  text: (row['day'] as Map)['text'] as int?,
                ),
                night: ReaderColors(
                  background: (row['night'] as Map)['background'] as int?,
                  text: (row['night'] as Map)['text'] as int?,
                ),
              ),
        ],
        shareLayout: map['shareLayout'] as bool? ?? true,
      ).select(map['selectedId'] as String);
    } catch (error) {
      throw FormatException('阅读样式数据无法读取，请恢复有效备份', error);
    }
  }

  ReaderStyles _legacy(AppSettingsSnapshot snapshot) {
    Object? value(String key) =>
        snapshot[(storage: SettingsStorageKind.preferences, key: key)];
    const backgrounds = [
      0xFFFFFFFF,
      0xFFCCEBCC,
      0xFFD4A574,
      0xFFE8E0C8,
      0xFF1A1A1A,
    ];
    final index = value('reader_bg_color_index');
    final custom = value('reader_custom_bg_color');
    final background = value('reader_bg_use_custom') == true && custom is int
        ? custom
        : index is int && index >= 0 && index < backgrounds.length
        ? backgrounds[index]
        : null;
    final text = value('reader_adv_custom_text_color');
    final colors = ReaderColors(
      background: background,
      text: text is int && text != 0
          ? text
          : value('reader_bg_use_custom') != true &&
                index is int &&
                index >= 0 &&
                index < backgrounds.length
          ? index == 4
                ? 0xFFCCCCCC
                : 0xFF333333
          : null,
    );
    // 已显式选择的颜色仍在两种模式可见；未设置的背景继续分别使用默认值。
    // 原夜间预设在深色模式下仍保留纯黑开关的默认解析。
    final night = index == 4 && value('reader_bg_use_custom') != true
        ? ReaderColors(text: colors.text)
        : colors;
    return ReaderStyles.defaults().replace(
      ReaderStyle(id: 'custom', name: '自定义', day: colors, night: night),
    );
  }

  Map<String, dynamic> _raw(AppSettingsSnapshot snapshot) =>
      snapshot[document] == null
      ? <String, dynamic>{}
      : jsonDecode(snapshot[document] as String) as Map<String, dynamic>;

  Map<String, Object?> _shared(
    AppSettingsSnapshot snapshot,
  ) => Map<String, Object?>.from(
    _raw(snapshot)['sharedLayout'] as Map? ??
        {for (final address in layoutAddresses) address.key: snapshot[address]},
  );

  Map<String, dynamic> _layouts(AppSettingsSnapshot snapshot) =>
      Map<String, dynamic>.from(_raw(snapshot)['layouts'] as Map? ?? const {});

  Map<String, Object?> _initialLayout(String id, Map<String, Object?> shared) =>
      readerStylePresets.any((style) => style.id == id)
      ? {
          for (final address in layoutAddresses) address.key: null,
          if (id == 'wechat') ...wechatReaderLayout,
        }
      : Map<String, Object?>.of(shared);

  String _encode(
    ReaderStyles styles,
    AppSettingsSnapshot snapshot, {
    Map<String, Object?>? shared,
    Map<String, dynamic>? layouts,
  }) => jsonEncode({
    'selectedId': styles.selectedId,
    'shareLayout': styles.shareLayout,
    'sharedLayout': shared ?? _shared(snapshot),
    'layouts': layouts ?? _layouts(snapshot),
    'styles': [
      for (final style in styles.styles)
        {
          'id': style.id,
          'name': style.name,
          'day': {'background': style.day.background, 'text': style.day.text},
          'night': {
            'background': style.night.background,
            'text': style.night.text,
          },
        },
    ],
  });

  /// Codec继续读取原有字段映射，只把有效布局覆盖到不可变快照上。
  AppSettingsSnapshot effective(AppSettingsSnapshot snapshot) {
    final data = _raw(snapshot);
    final shared = _shared(snapshot);
    final active = (data['shareLayout'] as bool? ?? true)
        ? shared
        : (_layouts(snapshot)[data['selectedId']] as Map? ??
              _initialLayout(data['selectedId'] as String, shared));
    return AppSettingsSnapshot({
      ...snapshot.values,
      for (final address in layoutAddresses) address: active[address.key],
    });
  }

  Map<SettingsAddress, Object?> layoutPatch(
    AppSettingsSnapshot snapshot,
    Map<SettingsAddress, Object?> values,
  ) {
    final layout = {
      for (final entry in values.entries)
        if (layoutAddresses.contains(entry.key)) entry.key.key: entry.value,
    };
    if (layout.isEmpty || snapshot[document] == null) return values;
    final styles = _decode(snapshot);
    final shared = _shared(snapshot);
    final layouts = _layouts(snapshot);
    if (styles.shareLayout) {
      shared.addAll(layout);
    } else {
      layouts[styles.selectedId] = {
        ...Map<String, Object?>.from(
          layouts[styles.selectedId] as Map? ??
              _initialLayout(styles.selectedId, shared),
        ),
        ...layout,
      };
    }
    return {
      for (final entry in values.entries)
        if (!layoutAddresses.contains(entry.key)) entry.key: entry.value,
      document: _encode(styles, snapshot, shared: shared, layouts: layouts),
    };
  }

  Future<void> _change(ReaderStyles Function(ReaderStyles) change) =>
      _service.mutate(
        {document, ...layoutAddresses},
        (snapshot) => {document: _encode(change(_decode(snapshot)), snapshot)},
      );

  ReaderStyles get current => _decode(_service.current);
  Stream<ReaderStyles> watch() => _service.watch().map(_decode).distinct();
  Future<ReaderStyles> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<ReaderStyles> _load() async {
    await _service.load({document, ...layoutAddresses});
    if (_service.current[document] == null) {
      await _service.reload(_legacyAddresses);
      await _service.mutate(
        {document, ...layoutAddresses},
        (snapshot) => snapshot[document] == null
            ? {document: _encode(_decode(snapshot), snapshot)}
            : {},
      );
    }
    _loaded = true;
    return current;
  }

  Future<void> reload() async {
    await _service.reload({document});
    _loaded = false;
    await load();
  }

  Future<void> select(String id) {
    current.select(id);
    return _change((styles) => styles.select(id));
  }

  Future<void> setShareLayout(bool enabled) =>
      _service.mutate({document, ...layoutAddresses}, (snapshot) {
        final styles = _decode(snapshot);
        final layouts = _layouts(snapshot);
        if (!enabled) {
          final shared = _shared(snapshot);
          for (final style in styles.styles) {
            if (!style.isPreset) {
              layouts.putIfAbsent(
                style.id,
                () => _initialLayout(style.id, shared),
              );
            }
          }
        }
        return {
          document: _encode(
            styles.withShareLayout(enabled),
            snapshot,
            layouts: layouts,
          ),
        };
      });

  Future<void> updateColors({
    required bool isNight,
    required ReaderColors Function(ReaderColors colors) update,
  }) => _change((styles) {
    final selected = styles.selected;
    return styles.replace(
      selected.withColors(isNight, update(selected.colors(isNight))),
    );
  });

  Future<String> createFromTemplate(String id, String name) async {
    final label = name.trim();
    if (label.isEmpty) throw ArgumentError('样式名称不能为空');
    late String createdId;
    await _service.mutate({document, ...layoutAddresses}, (snapshot) {
      final styles = _decode(snapshot);
      final template = styles.select(id).selected;
      createdId = 'custom-${DateTime.now().microsecondsSinceEpoch}';
      final shared = _shared(snapshot);
      final layouts = _layouts(snapshot);
      layouts[createdId] = styles.shareLayout
          ? Map<String, Object?>.of(shared)
          : Map<String, Object?>.from(
              layouts[id] as Map? ?? _initialLayout(id, shared),
            );
      final next = ReaderStyles(
        selectedId: createdId,
        shareLayout: false,
        styles: [
          ...styles.styles,
          ReaderStyle(
            id: createdId,
            name: label,
            day: template.day,
            night: template.night,
          ),
        ],
      );
      return {document: _encode(next, snapshot, layouts: layouts)};
    });
    return createdId;
  }

  Future<void> restorePreset(String presetId) =>
      _service.mutate({document, ...layoutAddresses}, (snapshot) {
        final preset = readerStylePresets
            .where((style) => style.id == presetId)
            .firstOrNull;
        if (preset == null) throw ArgumentError('阅读预设不存在：$presetId');
        final styles = _decode(snapshot);
        final selected = styles.selected;
        final shared = _shared(snapshot);
        final layout = _initialLayout(presetId, shared);
        final layouts = _layouts(snapshot)..[selected.id] = layout;
        return {
          document: _encode(
            styles.replace(
              ReaderStyle(
                id: selected.id,
                name: selected.name,
                day: preset.day,
                night: preset.night,
              ),
            ),
            snapshot,
            shared: styles.shareLayout ? layout : shared,
            layouts: layouts,
          ),
        };
      });
}
