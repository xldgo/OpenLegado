/// 存储位置只用于数据层路由，不要求迁移既有偏好。— Codex + UI
enum SettingsStorageKind { preferences, rustConfig }

typedef SettingsAddress = ({SettingsStorageKind storage, String key});

/// 只容纳普通偏好的标量快照，不包含实体、凭据或可变集合。
final class AppSettingsSnapshot {
  AppSettingsSnapshot(Map<SettingsAddress, Object?> values)
    : values = Map.unmodifiable(values);

  final Map<SettingsAddress, Object?> values;

  Object? operator [](SettingsAddress address) => values[address];
}
