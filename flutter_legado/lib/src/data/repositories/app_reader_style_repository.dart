import 'dart:convert';

import '../../domain/contracts/reader_style_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/reader_style.dart';
import '../services/app_settings_service.dart';

/// 样式按独立 JSON 格式序列化，共享服务只保存字符串，不引入可变集合状态。— Codex + UI
final class AppReaderStyleRepository implements ReaderStyleRepository {
  AppReaderStyleRepository(this._service);
  final AppSettingsService _service;
  static const _document = (
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
    final raw = snapshot[_document];
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
        styles: styles,
      ).select(map['selectedId'] as String);
    } catch (error) {
      throw FormatException('阅读配色数据无法读取，请恢复有效备份', error);
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

  String _encode(ReaderStyles styles) => jsonEncode({
    'selectedId': styles.selectedId,
    'styles': [
      for (final style in styles.styles)
        {
          'id': style.id,
          'day': {'background': style.day.background, 'text': style.day.text},
          'night': {
            'background': style.night.background,
            'text': style.night.text,
          },
        },
    ],
  });

  @override
  ReaderStyles get current => _decode(_service.current);
  @override
  Stream<ReaderStyles> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<ReaderStyles> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<ReaderStyles> _load() async {
    await _service.load({_document});
    if (_service.current[_document] == null) {
      await _service.reload(_legacyAddresses);
      await _service.update({_document: _encode(current)});
    }
    _loaded = true;
    return current;
  }

  @override
  Future<void> reload() async {
    await _service.reload({_document});
    _loaded = false;
    await load();
  }

  @override
  Future<void> select(String id) =>
      _service.update({_document: _encode(current.select(id))});
  @override
  Future<void> updateColors({
    required bool isNight,
    required ReaderColors Function(ReaderColors colors) update,
  }) {
    final styles = current;
    final selected = styles.selected;
    return _service.update({
      _document: _encode(
        styles.replace(
          selected.withColors(isNight, update(selected.colors(isNight))),
        ),
      ),
    });
  }
}
