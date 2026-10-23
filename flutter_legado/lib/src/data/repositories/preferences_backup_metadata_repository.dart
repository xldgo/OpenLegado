import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/backup_metadata_repository.dart';
import '../../domain/models/backup_metadata.dart';
import '../../services/settings_write_queue.dart';

/// 安装身份与成功记录保存在一个本机键，避免部分元数据写入。
final class PreferencesBackupMetadataRepository
    implements BackupMetadataRepository {
  static const key = 'backup_local_metadata';
  final _queue = SettingsWriteQueue();
  Future<BackupMetadata> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      return BackupMetadata(
        deviceId: value['deviceId'] as String,
        lastBackupMs: value['lastBackupMs'] as int,
        remoteScope: value['remoteScope'] as String,
        seenRemote: value['seenRemote'] as String,
      );
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final value = BackupMetadata(deviceId: id);
    await _save(value);
    return value;
  }

  Future<void> _save(BackupMetadata value) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(key);
    try {
      if (!await prefs.setString(
        key,
        jsonEncode({
          'deviceId': value.deviceId,
          'lastBackupMs': value.lastBackupMs,
          'remoteScope': value.remoteScope,
          'seenRemote': value.seenRemote,
        }),
      )) {
        throw StateError('状态写入被拒绝');
      }
    } catch (_) {
      if (previous == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
      throw StateError('备份状态保存失败');
    }
  }

  @override
  Future<BackupMetadata> load() async {
    late BackupMetadata value;
    await _queue.run(() async {
      value = await _load();
    });
    return value;
  }

  @override
  Future<void> save(BackupMetadata value) => _queue.run(() => _save(value));
}
