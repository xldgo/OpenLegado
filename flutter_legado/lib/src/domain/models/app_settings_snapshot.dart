/// 存储位置只用于数据层路由，不要求迁移既有偏好。— Codex + UI
enum SettingsStorageKind { preferences, rustConfig }

typedef SettingsAddress = ({SettingsStorageKind storage, String key});

/// 保留StringList格式的不可变配置值，不接收实体列表。— Codex + UI
final class SettingsStringList {
  SettingsStringList(Iterable<String> values)
    : values = List<String>.unmodifiable(values);

  final List<String> values;

  @override
  bool operator ==(Object other) =>
      other is SettingsStringList &&
      values.length == other.values.length &&
      values.indexed.every((entry) => entry.$2 == other.values[entry.$1]);

  @override
  int get hashCode => Object.hashAll(values);
}

/// 普通偏好的标量及不可变StringList快照，不包含实体、凭据或可变集合。
final class AppSettingsSnapshot {
  AppSettingsSnapshot(Map<SettingsAddress, Object?> values)
    : values = Map.unmodifiable(
        values.map(
          (address, value) => MapEntry(
            address,
            value is List<String> ? SettingsStringList(value) : value,
          ),
        ),
      );

  final Map<SettingsAddress, Object?> values;

  Object? operator [](SettingsAddress address) => values[address];
}
