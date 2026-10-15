import 'dart:convert';

import '../../domain/contracts/backup_repository.dart';

import 'dart:io';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/rust_api_exception.dart';

/// 本地备份访问沿用原方法行为。— Codex + Bridge
final class RustBackupRepository implements BackupRepository {
  const RustBackupRepository();
  // ========== 备份操作 ==========

  /// 备份数据（委托 Rust backup_create：收集全量数据写入 JSON 文件）
  ///
  /// 在 [dirPath] 下生成时间戳命名的备份文件，返回实际备份文件路径。
  @override
  Future<String> backup(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName =
        'legado_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final filePath = '$dirPath${Platform.pathSeparator}$fileName';
    return bridge.backupCreate(path: filePath);
  }

  /// 恢复数据（委托 Rust backup_restore：从备份文件导入）
  @override
  Future<void> restore(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw RustApiException(
        'Backup file not found: $backupPath',
        operation: 'restore',
      );
    }
    await bridge.backupRestore(path: backupPath);
  }

  /// 导入旧版数据（委托 Rust import_old_data）
  @override
  Future<String> importOldData(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw RustApiException('目录不存在: $dirPath', operation: 'importOldData');
    }
    return bridge.importOldData(dir: dirPath);
  }

  @override
  Future<List<String>> backupList(String dir) async {
    final json = await bridge.backupList(dir: dir);
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }
}
