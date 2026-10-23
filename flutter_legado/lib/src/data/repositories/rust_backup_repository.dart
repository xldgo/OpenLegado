import 'dart:convert';

import '../../domain/models/backup_restore_result.dart';
import '../bridge/rust_errors.dart';
import '../../domain/models/old_data_import_result.dart';
import '../../domain/models/backup_restore_stats.dart';
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
  Future<String> backup(
    String dirPath, {
    Map<String, dynamic> preferences = const {},
    Map<String, String> files = const {},
    Map<String, dynamic> sensitive = const {},
    String? password,
    String? fileName,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final name =
        fileName ??
        'legado_backup_${DateTime.now().microsecondsSinceEpoch}.zip';
    if (name.contains('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        !name.endsWith('.zip')) {
      throw const FormatException('无效备份文件名');
    }
    final filePath = '$dirPath${Platform.pathSeparator}$name';
    return rustFuture(
      () => bridge.backupCreate(
        path: filePath,
        preferencesJson: jsonEncode(preferences),
        filesJson: jsonEncode(files),
        sensitiveJson: jsonEncode(sensitive),
        password: password,
      ),
      operation: 'backupCreate',
    );
  }

  /// 恢复数据（委托 Rust backup_restore：从备份文件导入）
  @override
  Future<BackupRestoreResult> restore(
    String backupPath, {
    String? password,
    Set<String> ignore = const {},
  }) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw AppException(
        'Backup file not found: $backupPath',
        operation: 'restore',
      );
    }
    final result = await rustFuture(
      () => bridge.backupRestore(
        path: backupPath,
        password: password,
        ignoreJson: jsonEncode(ignore.toList()..sort()),
      ),
      operation: 'backupRestore',
    );
    final stats = result.stats;
    return BackupRestoreResult(
      stats: BackupRestoreStats(
        books: stats.books.toInt(),
        bookmarks: stats.bookmarks.toInt(),
        replaceRules: stats.replaceRules.toInt(),
        bookSources: stats.bookSources.toInt(),
        rssSources: stats.rssSources.toInt(),
        readRecords: stats.readRecords.toInt(),
        additional: Map.unmodifiable(
          stats.additional.map((key, value) => MapEntry(key, value.toInt())),
        ),
      ),
      preferences: Map.unmodifiable(
        jsonDecode(result.preferencesJson) as Map<String, dynamic>,
      ),
      sensitive: Map.unmodifiable(
        jsonDecode(result.sensitiveJson) as Map<String, dynamic>,
      ),
      warnings: List.unmodifiable(result.warnings),
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
