import 'dart:convert';
import 'dart:io';

import '../../domain/contracts/backup_repository.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/restore_ignore_repository.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../domain/models/webdav_connection.dart';
import '../../domain/models/backup_restore_stats.dart';
import '../../models/book.dart';
import 'backup_preferences_service.dart';

/// 备份恢复编排只依赖注入能力，不持有页面或播放状态。— Codex + Bridge
class BackupService {
  BackupService({
    required this._repository,
    required this._webDav,
    required this._bookshelf,
    required this._sources,
    required this._ignore,
    BackupPreferencesService? preferences,
  }) : _preferences = preferences ?? BackupPreferencesService();

  final BackupRepository _repository;
  final WebDavService _webDav;
  final BookshelfRepository _bookshelf;
  final BookSourceRepository _sources;
  final RestoreIgnoreRepository _ignore;
  final BackupPreferencesService _preferences;

  Future<({String path, Object? preferencesError})> backupLocal(
    String directory,
  ) async {
    final ignore = await _ignore.load();
    final path = await _repository.backup(directory);
    try {
      if (path.toLowerCase().endsWith('.json')) {
        final payload = await _readBackup(path);
        payload[kBackupAppPrefsKey] = await _preferences.collectForBackup(
          ignore.values,
        );
        final temporary = File(
          '$path.prefs-${DateTime.now().microsecondsSinceEpoch}.tmp',
        );
        try {
          await temporary.writeAsString(
            const JsonEncoder.withIndent('  ').convert(payload),
            flush: true,
          );
          await temporary.rename(path);
        } finally {
          if (await temporary.exists()) {
            try {
              await temporary.delete();
            } catch (_) {
              // 清理失败不覆盖偏好备份的实际错误。
            }
          }
        }
      }
      return (path: path, preferencesError: null);
    } catch (error) {
      return (path: path, preferencesError: error);
    }
  }

  Future<({BackupRestoreStats stats, Object? preferencesError})> restoreLocal(
    String path,
  ) async {
    if (!path.toLowerCase().endsWith('.json')) {
      throw const FormatException('暂不支持此备份格式，请选择本项目生成的JSON备份');
    }
    final ignore = await _ignore.load();
    final BackupRestoreStats stats;
    Map<String, dynamic>? prefs;
    File? filtered;
    final payload = await _readBackup(path);
    final rawPrefs = payload[kBackupAppPrefsKey];
    if (rawPrefs != null) {
      if (rawPrefs is! Map<String, dynamic>) {
        throw const FormatException('备份设置必须为JSON对象');
      }
      prefs = rawPrefs;
    }
    final collections = payload['collections'];
    var changed = false;
    final books = collections is Map<String, dynamic>
        ? collections['books']
        : null;
    if (ignore['localBook'] && books is List) {
      collections['books'] = books.where((item) {
        if (item is! Map) return true;
        final origin = item['origin']?.toString() ?? '';
        final value = item['type'];
        final type = value is int ? value : int.tryParse('$value') ?? 0;
        return !(origin == BookType.localTag ||
            origin.startsWith(BookType.webDavTag) ||
            (type & BookType.local) != 0);
      }).toList();
      changed = true;
    }
    final config = payload['config'];
    if (ignore['threadCount'] &&
        config is Map<String, dynamic> &&
        config.containsKey('threadCount')) {
      config.remove('threadCount');
      changed = true;
    }
    if (ignore['coverConfig'] && collections is Map<String, dynamic>) {
      collections['coverRules'] = <dynamic>[];
      changed = true;
    }
    if (changed) {
      filtered = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}legado_restore_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await filtered.writeAsString(jsonEncode(payload));
    }
    try {
      stats = await _repository.restore(filtered?.path ?? path);
    } finally {
      if (filtered != null) {
        try {
          await filtered.delete();
        } catch (_) {
          // 临时文件清理不覆盖业务恢复结果。
        }
      }
    }
    try {
      await _preferences.applyFromBackup(prefs, ignore.values);
      return (stats: stats, preferencesError: null);
    } catch (error) {
      return (stats: stats, preferencesError: error);
    }
  }

  Future<void> backupToWebDav(WebDavConnection connection) async {
    final books = await _bookshelf.getBooks();
    final sources = await _sources.getBookSources();
    await _webDav.webdavFullSync(
      connection,
      jsonEncode(books.map((book) => book.toJson()).toList()),
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }

  Future<({int books, int sources})> restoreFromWebDav(
    WebDavConnection connection,
  ) async {
    int? restoredBooks;
    try {
      final books = await _webDav.webdavDownload(connection, 'bookshelf.json');
      final sources = await _webDav.webdavDownload(connection, 'sources.json');
      final hasBooks = _validateRestoreList(books, 'bookshelf.json', 'bookUrl');
      final hasSources = _validateRestoreList(
        sources,
        'sources.json',
        'bookSourceUrl',
      );
      restoredBooks = hasBooks ? await _bookshelf.importBooks(books) : 0;
      final restoredSources = hasSources
          ? await _sources.importBookSources(sources)
          : 0;
      return (books: restoredBooks, sources: restoredSources);
    } catch (error) {
      throw BackupRestoreException(
        restoredBooks == null
            ? '恢复失败: $error'
            : '恢复未完成，已回写 $restoredBooks 本书籍；书源恢复失败: $error',
      );
    }
  }

  Future<String> importOldData(String directory) async {
    final result = await _repository.importOldData(directory);
    final messages = result.messages;
    if (messages.isNotEmpty) {
      return messages.join('\n');
    }
    return '书架 ${result.books} · 书源 ${result.bookSources} · 替换规则 ${result.replaceRules}';
  }

  Future<Map<String, dynamic>> _readBackup(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份必须为JSON对象');
    }
    return decoded;
  }

  bool _validateRestoreList(String payload, String fileName, String idKey) {
    final dynamic items;
    try {
      items = jsonDecode(payload);
    } on FormatException {
      throw FormatException('$fileName不是有效的JSON');
    }
    if (items is! List) throw FormatException('$fileName必须为JSON数组');
    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$fileName的条目必须为JSON对象');
      }
      final id = item[idKey];
      if (id is! String || id.trim().isEmpty) {
        throw FormatException('$fileName的条目缺少有效$idKey');
      }
    }
    return items.isNotEmpty;
  }
}

final class BackupRestoreException implements Exception {
  const BackupRestoreException(this.message);
  final String message;
  @override
  String toString() => message;
}
