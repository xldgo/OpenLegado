import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';

/// 可控制读写完成时机，用于复现迟到快照及保存失败。— Codex + UI
class HomeSettingsStorage implements SettingsStorage {
  final values = <String, Object?>{};
  final reads = <String>[];
  final writes = <(String, Object?)>[];
  Completer<void>? readBarrier;
  bool readFailure = false;
  bool writeFailure = false;
  Future<void> Function(String, Object?)? beforeWrite;

  @override
  Future<Object?> read(String key) async {
    reads.add(key);
    final value = values[key];
    await readBarrier?.future;
    if (readFailure) throw StateError('模拟读取失败');
    return value;
  }

  @override
  Future<void> write(String key, Object? value) async {
    writes.add((key, value));
    await beforeWrite?.call(key, value);
    if (writeFailure) throw StateError('模拟保存失败');
    values[key] = value;
  }
}
