import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/models/webdav_connection.dart';
import '../../models/book.dart';
import '../../models/misc.dart';
import '../providers.dart';
import '../backup_settings_provider.dart';
import '../sync_metadata_provider.dart';
import '../webdav_connection_provider.dart';
import 'sync_state.dart';

export 'sync_state.dart';

/// WebDAV 云同步 Riverpod Notifier
///
/// 对接真实的 BookApi WebDAV 契约（webdavFullSync / importBookSources），
/// 对齐 Android 原版 BackupConfigFragment 的 WebDAV 设置组
/// （服务器地址/账号/密码/子目录/设备名/同步书籍进度）。
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    // 原 SyncProvider 构造不自动加载，配置由页面 initState 触发 loadConfig()
    final repository = ref.watch(backupSettingsRepositoryProvider);
    final subscription = repository.watch().listen((settings) {
      if (ref.mounted) {
        state = state.copyWith(
          syncBookProgress: settings.syncBookProgress,
          autoSync: settings.autoSync,
          syncBookProgressPlus: settings.syncBookProgressPlus,
        );
      }
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return SyncState(
      syncBookProgress: repository.current.syncBookProgress,
      autoSync: repository.current.autoSync,
      syncBookProgressPlus: repository.current.syncBookProgressPlus,
    );
  }

  /// 远端子目录（保证以 '/' 结尾；Rust WebDavClient 拼接
  /// full_url = url + remote_dir + path，直接拼接 path）
  /// [Task #52 | 2026-08-10] — Qoder
  String get normalizedRemoteDir {
    final dir = state.remoteDir.isEmpty ? '/legado/' : state.remoteDir;
    return dir.endsWith('/') ? dir : '$dir/';
  }

  /// 构建 Rust 侧 WebDavConfig 期望的 JSON（{url, username, password, remote_dir}）
  ///
  /// [Task #52 | 2026-08-10] 补齐 remote_dir（legado-net WebDavConfig 必需字段，
  /// 缺失会导致 Rust 侧配置解析失败） — Qoder
  String buildConfigJson() => jsonEncode({
    'url': state.webDavUrl,
    'username': state.webDavUsername,
    'password': state.webDavPassword,
    'remote_dir': normalizedRemoteDir,
  });

  // ===== 配置管理 =====

  /// 保存 WebDAV 配置
  Future<void> saveConfig(
    String url,
    String username,
    String password,
    String dir, {
    String deviceName = '',
  }) async {
    final saved = await ref
        .read(webDavConnectionRepositoryProvider)
        .save(
          WebDavConnection(
            url: url,
            username: username,
            password: password,
            remoteDir: dir,
            deviceName: deviceName,
          ),
        );
    if (!ref.mounted) return;
    state = state.copyWith(
      webDavUrl: saved.url,
      webDavUsername: saved.username,
      webDavPassword: saved.password,
      remoteDir: saved.remoteDir,
      deviceName: saved.deviceName,
    );
  }

  /// 加载已保存的 WebDAV 配置
  Future<void> loadConfig() async {
    final backup = await ref.read(backupSettingsRepositoryProvider).load();
    final connection = await ref
        .read(webDavConnectionRepositoryProvider)
        .load();
    final lastSyncTime = await ref.read(syncMetadataRepositoryProvider).load();
    state = state.copyWith(
      webDavUrl: connection.url,
      webDavUsername: connection.username,
      webDavPassword: connection.password,
      remoteDir: connection.remoteDir,
      deviceName: connection.deviceName,
      syncBookProgress: backup.syncBookProgress,
      syncBookProgressPlus: backup.syncBookProgressPlus,
      autoSync: backup.autoSync,
      lastSyncTime: lastSyncTime,
    );
  }

  /// 设置「同步书籍进度」开关
  Future<void> setSyncBookProgress(bool enabled) async {
    final repository = ref.read(backupSettingsRepositoryProvider);
    final saving = repository.update(syncBookProgress: enabled);
    state = state.copyWith(
      syncBookProgress: repository.current.syncBookProgress,
    );
    try {
      await saving;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          syncBookProgress: repository.current.syncBookProgress,
        );
      }
    }
  }

  // ===== 单书进度拉取 / 覆盖（对齐 AppWebDav.getBookProgress / uploadBookProgress）=====

  /// 进度文件相对路径：`bookProgress/{name}_{author}.json`
  String bookProgressRemotePath(String name, String author) =>
      'bookProgress/${_progressFileName(name, author)}';

  /// 上传当前书籍进度到 WebDAV（对齐 menu_cover_progress）
  Future<void> uploadBookProgress(Book book) async {
    if (!state.isConfigured) {
      throw StateError('请先配置 WebDAV');
    }
    if (!state.syncBookProgress) {
      throw StateError('未开启「同步书籍进度」');
    }
    final progress = BookProgress(
      name: book.name,
      author: book.author,
      durChapterIndex: book.durChapterIndex,
      durChapterPos: book.durChapterPos,
      durChapterTime: book.durChapterTime,
      durChapterTitle: book.durChapterTitle,
    );
    final api = ref.read(bookApiProvider);
    await api.webdavUpload(
      buildConfigJson(),
      bookProgressRemotePath(book.name, book.author),
      jsonEncode(progress.toJson()),
    );
  }

  /// 拉取远程进度；无文件 / 解析失败返回 null
  Future<BookProgress?> fetchBookProgress(Book book) async {
    if (!state.isConfigured) return null;
    try {
      final api = ref.read(bookApiProvider);
      final jsonStr = await api.webdavDownload(
        buildConfigJson(),
        bookProgressRemotePath(book.name, book.author),
      );
      if (jsonStr.trim().isEmpty) return null;
      final map = jsonDecode(jsonStr);
      if (map is! Map<String, dynamic>) return null;
      return BookProgress.fromJson(map);
    } catch (e) {
      debugPrint('SyncNotifier.fetchBookProgress: $e');
      return null;
    }
  }

  /// 对齐 ReadBook.syncProgress：云端更快 → 回调；本地更快或缺云端 → 上传
  ///
  /// 返回值：`cloud`=云端更新、`uploaded`=已上传本地、`same`=一致、`skipped`=开关关闭
  Future<String> syncBookProgressForBook(
    Book book, {
    required Future<void> Function(BookProgress cloud) onCloudNewer,
  }) async {
    if (!state.syncBookProgress) return 'skipped';
    if (!state.isConfigured) {
      throw StateError('请先配置 WebDAV');
    }
    final cloud = await fetchBookProgress(book);
    if (cloud == null ||
        cloud.durChapterIndex < book.durChapterIndex ||
        (cloud.durChapterIndex == book.durChapterIndex &&
            cloud.durChapterPos < book.durChapterPos)) {
      await uploadBookProgress(book);
      return 'uploaded';
    }
    if (cloud.durChapterIndex > book.durChapterIndex ||
        cloud.durChapterPos > book.durChapterPos) {
      await onCloudNewer(cloud);
      return 'cloud';
    }
    return 'same';
  }

  static String _progressFileName(String name, String author) {
    // 对齐 Kotlin：normalizeFileName + UrlUtil.replaceReservedChar
    var base = '${name}_$author'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    const reserved = {
      '%': '%25',
      ' ': '%20',
      '"': '%22',
      '#': '%23',
      '&': '%26',
      '(': '%28',
      ')': '%29',
      '+': '%2B',
      ',': '%2C',
      '/': '%2F',
      ':': '%3A',
      ';': '%3B',
      '<': '%3C',
      '=': '%3D',
      '>': '%3E',
      '?': '%3F',
      '@': '%40',
      '\\': '%5C',
    };
    final buf = StringBuffer();
    for (final rune in base.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(reserved[ch] ?? ch);
    }
    return '${buf.toString()}.json';
  }

  // ===== 同步操作（真实 BookApi 调用） =====

  /// 备份到 WebDAV（上传本地书架 + 书源）
  ///
  /// 调用真实 webdavFullSync，对齐原版 web_dav_backup。
  Future<void> backupToWebDav() async {
    if (!state.isConfigured) {
      _setError('请先配置 WebDAV 服务器信息');
      return;
    }
    _setStatus(SyncStatus.syncing);
    try {
      final api = ref.read(bookApiProvider);
      final (localBooks, localSources) = await _collectLocalData();
      await api.webdavFullSync(buildConfigJson(), localBooks, localSources);
      await _markSyncSuccess();
    } catch (e) {
      _setError('备份失败: $e');
    }
  }

  /// 从 WebDAV 恢复（获取远端数据并回写书源）
  ///
  /// 调用真实 webdavFullSync 取得远端合并数据，书源经 importBookSources 回写；
  /// 书架批量回写受限于 BookApi 暂无批量导入契约，登记为跨轨需求。
  /// 返回用于展示的结果描述。
  Future<String> restoreFromWebDav() async {
    if (!state.isConfigured) {
      _setError('请先配置 WebDAV 服务器信息');
      return '请先配置 WebDAV 服务器信息';
    }
    _setStatus(SyncStatus.syncing);
    try {
      final api = ref.read(bookApiProvider);
      final (localBooks, localSources) = await _collectLocalData();
      final result = await api.webdavFullSync(
        buildConfigJson(),
        localBooks,
        localSources,
      );
      var imported = 0;
      final remote = jsonDecode(result) as Map<String, dynamic>;
      final remoteSources = remote['sources']?.toString() ?? '';
      if (remoteSources.isNotEmpty && remoteSources != '[]') {
        imported = await api.bookSourceRepository.importBookSources(
          remoteSources,
        );
      }
      await _markSyncSuccess();
      return '恢复完成，回写 $imported 条书源';
    } catch (e) {
      _setError('恢复失败: $e');
      return '恢复失败: $e';
    }
  }

  // ===== Internal helpers =====

  /// 序列化本地书架 + 书源为 JSON（供 webdavFullSync 上传）
  Future<(String, String)> _collectLocalData() async {
    final api = ref.read(bookApiProvider);
    final books = await api.bookshelfRepository.getBooks();
    final sources = await api.bookSourceRepository.getBookSources();
    final localBooks = jsonEncode(books.map((e) => e.toJson()).toList());
    final localSources = jsonEncode(sources.map((e) => e.toJson()).toList());
    return (localBooks, localSources);
  }

  Future<void> _markSyncSuccess() async {
    final now = DateTime.now();
    try {
      await ref.read(syncMetadataRepositoryProvider).save(now);
      if (ref.mounted) {
        state = state.copyWith(
          lastSyncTime: now,
          status: SyncStatus.success,
          error: null,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: SyncStatus.success,
          error: '云端同步已完成，但本地同步时间未保存',
        );
      }
    }
  }

  void _setStatus(SyncStatus status) {
    state = state.copyWith(status: status, error: null);
  }

  void _setError(String message) {
    state = state.copyWith(status: SyncStatus.error, error: message);
    debugPrint('SyncNotifier 错误: $message');
  }
}

/// WebDAV 云同步 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(syncNotifierProvider);
/// ref.read(syncNotifierProvider.notifier).backupToWebDav();
/// ```
final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);
