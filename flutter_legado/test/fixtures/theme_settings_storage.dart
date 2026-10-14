import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';

/// 控制真实共享服务的读写边界，不模拟 Notifier 内部实现。
class ThemeSettingsStorage implements SettingsStorage {
  ThemeSettingsStorage([Map<String, Object?> initial = const {}])
    : values = Map.of(initial);

  final Map<String, Object?> values;
  final List<(String, Object?)> writes = [];
  Completer<void>? readGate;
  Completer<void>? writeGate;
  String? failKey;
  bool failNext = false;

  @override
  Future<Object?> read(String key) async {
    final value = values[key];
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(String key, Object? value) async {
    writes.add((key, value));
    await writeGate?.future;
    if (failNext || key == failKey) {
      failNext = false;
      throw StateError('模拟主题偏好保存失败');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
