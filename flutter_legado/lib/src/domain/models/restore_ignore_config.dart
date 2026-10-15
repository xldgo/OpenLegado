/// 恢复忽略策略的不可变快照，键及顺序沿用原配置。— connection_migration + UI
final class RestoreIgnoreConfig {
  RestoreIgnoreConfig([Map<String, Object?> values = const {}])
    : values = Map.unmodifiable({
        for (final key in keys) key: values[key] == true,
      });

  static const keys = <String>[
    'readConfig',
    'themeMode',
    'themeConfig',
    'coverConfig',
    'bookshelfLayout',
    'showRss',
    'threadCount',
    'localBook',
  ];

  final Map<String, bool> values;

  bool operator [](String key) => values[key] == true;

  @override
  bool operator ==(Object other) =>
      other is RestoreIgnoreConfig &&
      keys.every((key) => values[key] == other.values[key]);

  @override
  int get hashCode => Object.hashAll(keys.map((key) => values[key]));
}
