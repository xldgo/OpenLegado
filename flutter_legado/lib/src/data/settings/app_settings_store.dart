import 'dart:async';

import '../../domain/models/app_settings_snapshot.dart';

/// 一次待保存差量的身份，旧失败不能撤销后来写入。— Codex + UI
final class SettingsMutation {
  SettingsMutation._(Map<SettingsAddress, Object?> values)
    : values = Map.unmodifiable(values);

  final Map<SettingsAddress, Object?> values;
}

/// 纯状态核心：生效快照 = 已读取/保存的基底 + 按顺序叠加的待保存差量。
final class AppSettingsStore {
  final _committed = <SettingsAddress, Object?>{};
  final _pending = <SettingsMutation>[];
  final _changes = StreamController<AppSettingsSnapshot>.broadcast();
  AppSettingsSnapshot _current = AppSettingsSnapshot(const {});

  AppSettingsSnapshot get current => _current;

  /// 先注册再发送当前值，订阅期间不会漏掉变更；每个消费者独立取消。
  Stream<AppSettingsSnapshot> watch() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.add(_current);
    controller.onCancel = subscription.cancel;
  });

  void hydrate(Map<SettingsAddress, Object?> values) {
    _committed.addAll(AppSettingsSnapshot(values).values);
    _rebuild();
  }

  SettingsMutation stage(Map<SettingsAddress, Object?> values) {
    for (final value in values.values) {
      if (value != null &&
          value is! String &&
          value is! bool &&
          value is! int &&
          value is! double &&
          value is! SettingsStringList) {
        throw ArgumentError('普通设置只接受标量或不可变StringList配置值');
      }
    }
    final mutation = SettingsMutation._(values);
    _pending.add(mutation);
    _rebuild();
    return mutation;
  }

  /// 每个成功写入都成为事实；后续键失败时不能假装整批回滚。
  void markPersisted(SettingsMutation mutation, SettingsAddress address) {
    _committed[address] = mutation.values[address];
  }

  /// 成功和失败都只移除本次差量，后来操作仍优先。
  void finish(SettingsMutation mutation) {
    _pending.remove(mutation);
    _rebuild();
  }

  void _rebuild() {
    final values = {..._committed};
    for (final mutation in _pending) {
      values.addAll(mutation.values);
    }
    final previous = _current.values;
    if (previous.length == values.length &&
        values.entries.every(
          (e) => previous.containsKey(e.key) && previous[e.key] == e.value,
        )) {
      return;
    }
    _current = AppSettingsSnapshot(values);
    if (!_changes.isClosed) {
      _changes.add(_current);
    }
  }

  Future<void> dispose() => _changes.close();
}
