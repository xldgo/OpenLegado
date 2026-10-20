import '../bridge/rust_errors.dart';
import '../../domain/models/old_data_import_result.dart';
import '../../domain/contracts/backup_repository.dart';

import 'dart:io';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/errors/app_exception.dart';

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
    return rustFuture(
      () => bridge.backupCreate(path: filePath),
      operation: 'backupCreate',
    );
  }

  /// 恢复数据（委托 Rust backup_restore：从备份文件导入）
  @override
  Future<void> restore(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw AppException(
        'Backup file not found: $backupPath',
        operation: 'restore',
      );
    }
    await rustFuture(
      () => bridge.backupRestore(path: backupPath),
      operation: 'backupRestore',
    );
  }

  /// 导入旧版数据（委托 Rust import_old_data）
  @override
  Future<OldDataImportResult> importOldData(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw AppException('目录不存在: $dirPath', operation: 'importOldData');
    }
    final value = await rustFuture(
      () => bridge.importOldData(dir: dirPath),
      operation: 'importOldData',
    );
    return OldDataImportResult(
      books: value.books.toInt(),
      bookSources: value.bookSources.toInt(),
      replaceRules: value.replaceRules.toInt(),
      messages: List.unmodifiable(value.messages),
    );
  }

  @override
  Future<List<String>> backupList(String dir) async {
    final files = await rustFuture(
      () => bridge.backupList(dir: dir),
      operation: 'backupList',
    );
    // 保留既有领域接口的文件描述文本，文件内容与恢复统计不在此处编码。
    return files
        .map(
          (v) => {
            'modified': v.modified,
            'name': v.name,
            'path': v.path,
            'size': v.size.toInt(),
          }.toString(),
        )
        .toList();
  }
}
