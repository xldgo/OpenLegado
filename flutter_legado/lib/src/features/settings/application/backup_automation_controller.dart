import 'dart:async';

import '../../../data/services/backup_service.dart';
import '../../../data/services/backup_file_policy.dart';

final class BackupAutomationState {
  const BackupAutomationState({
    this.newBackup,
    this.error,
    this.running = false,
  });
  final String? newBackup, error;
  final bool running;
}

/// 只在启动/恢复前台检查，不建立后台定时器或重复的任务框架。
final class BackupAutomationController {
  BackupAutomationController(this.service);
  final BackupService service;
  final _changes = StreamController<BackupAutomationState>.broadcast(
    sync: true,
  );
  BackupAutomationState _state = const BackupAutomationState();
  BackupAutomationState get state => _state;
  Stream<BackupAutomationState> get changes => _changes.stream;
  bool _running = false, _disposed = false;
  void _publish(BackupAutomationState value) {
    if (_disposed) return;
    _state = value;
    _changes.add(value);
  }

  Future<void> onForeground() async {
    if (_disposed || _running || service.isBusy) return;
    _running = true;
    var found = _state.newBackup;
    final errors = <String>[];
    _publish(BackupAutomationState(newBackup: found, running: true));
    try {
      final settings = await service.settings.load();
      final connection = await service.connections.load();
      final metadata = await service.metadata.load();
      final configured =
          connection.url.isNotEmpty &&
          connection.username.isNotEmpty &&
          connection.password.isNotEmpty;
      if (settings.autoCheckNewBackup && configured) {
        try {
          final scope = BackupFilePolicy.scope(
            connection.url,
            connection.username,
            connection.remoteDir,
          );
          final latest =
              (await service.listRemoteBackups(
                    connection,
                    newerThanMs: metadata.lastBackupMs,
                  ))
                  .where(
                    (name) => !BackupFilePolicy(
                      connection.deviceName,
                      metadata.deviceId,
                    ).owns(name),
                  )
                  .firstOrNull;
          found =
              latest != null &&
                  (metadata.remoteScope != scope ||
                      metadata.seenRemote != latest)
              ? latest
              : null;
        } catch (_) {
          errors.add('云端新备份检查失败，可在备份页重试');
        }
      } else {
        found = null;
      }
      final due =
          service.clock().millisecondsSinceEpoch - metadata.lastBackupMs >=
          Duration(days: settings.autoBackupIntervalDays).inMilliseconds;
      if (settings.autoBackup && due && !service.isBusy && !_disposed) {
        if (settings.backupPath.isEmpty) {
          errors.add('自动备份未执行：请先设置本地备份路径');
        } else if (settings.autoBackupWebDav && !configured) {
          errors.add('自动备份未执行：请先配置WebDAV');
        } else {
          try {
            final result = await service.createBackup(
              settings.backupPath,
              uploadConnection: settings.autoBackupWebDav ? connection : null,
            );
            errors.addAll(result.warnings);
          } catch (_) {
            errors.add('自动备份失败，可在备份页重试');
          }
        }
      }
    } catch (_) {
      errors.add('备份设置或执行状态读取失败');
    } finally {
      _running = false;
      _publish(
        BackupAutomationState(
          newBackup: found,
          error: errors.isEmpty ? null : errors.join('\n'),
        ),
      );
    }
  }

  Future<void> dismiss() async {
    final name = _state.newBackup;
    if (name == null || service.isBusy) return;
    try {
      await service.markRemoteSeen(await service.connections.load(), name);
      _publish(BackupAutomationState(error: _state.error));
    } catch (_) {
      _publish(BackupAutomationState(newBackup: name, error: '已查看备份记录保存失败'));
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_changes.close());
  }
}
