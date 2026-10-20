import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/contracts/cover_cache_repository.dart';

/// 应用级封面缓存所有者；图片展示和HTTP过期策略仍由原库负责。— Codex + UI
final class CoverCache implements CoverCacheRepository {
  CoverCache({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  static final instance = CoverCache();
  static const maxDecodedEntries = 64;
  static const _index = 'index.json';
  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getTemporaryDirectory()).path}/legado_cover_cache');

  final Future<Directory> Function() _directory;
  final _decoded = <String, Uint8List>{};
  CacheManager? _manager;
  http.Client? _client;
  Future<void>? _clearing;
  bool _disposed = false;
  int _revision = 0;
  int get revision => _revision;
  int get decodedCount => _decoded.length;

  /// 所有封面入口共用此实例，不能修改图片库的全局默认缓存。
  CacheManager get manager {
    if (_disposed) throw StateError('封面缓存已释放');
    return _manager ??= CacheManager(
      Config(
        'legado_cover_cache',
        repo: _CoverIndex(_directory),
        fileSystem: _CoverFileSystem(_directory),
        fileService: HttpFileService(httpClient: _client ??= http.Client()),
      ),
    );
  }

  Future<Uint8List?> readDecoded(String key) async {
    await _prepareDirectory();
    final file = await manager.getFileFromCache('decoded:$key');
    if (file == null || file.validTill.isBefore(DateTime.now())) return null;
    return file.file.readAsBytes();
  }

  Future<void> writeDecoded(String key, Uint8List bytes) async {
    await _prepareDirectory();
    await manager.putFile(
      'decoded:$key',
      bytes,
      key: 'decoded:$key',
      fileExtension: 'image',
    );
  }

  Uint8List? decoded(String key) {
    final bytes = _decoded.remove(key);
    if (bytes != null) _decoded[key] = bytes;
    return bytes;
  }

  void rememberDecoded(String key, Uint8List bytes) {
    _decoded.remove(key);
    _decoded[key] = bytes;
    while (_decoded.length > maxDecodedEntries) {
      _decoded.remove(_decoded.keys.first);
    }
  }

  void clearDecoded() => _decoded.clear();

  Future<void> _prepareDirectory() async {
    final root = await _directory();
    await root.create(recursive: true);
  }

  @override
  Future<int> getSize() async {
    if (_disposed) throw StateError('封面缓存已释放');
    final root = await _directory();
    if (!await root.exists()) return 0;
    var size = 0;
    await for (final entity in root.list(followLinks: false)) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || name == _index || name == '$_index.tmp') continue;
      try {
        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.file) size += stat.size;
      } on FileSystemException catch (error) {
        // 统计期间图片库可能自然淘汰文件，其他存储故障仍向上报告。
        if (error.osError?.errorCode != 2 && error.osError?.errorCode != 3) {
          rethrow;
        }
      }
    }
    return size;
  }

  @override
  Future<void> clear() {
    if (_disposed) return Future.error(StateError('封面缓存已释放'));
    return _clearing ??= _clear();
  }

  Future<void> _clear() async {
    ++_revision;
    _decoded.clear();
    try {
      // 只清已有缓存，正在加载的图片继续完成并可正常写入。
      await _prepareDirectory();
      await manager.emptyCache();
    } finally {
      _clearing = null;
    }
  }

  /// 释放连接及索引句柄，不删除磁盘缓存；应用级实例不随页面销毁。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      if (_clearing case final pending?) await pending;
    } finally {
      _decoded.clear();
      _client?.close();
      await _manager?.dispose();
    }
  }
}

/// 元数据和图片放入同一专属目录；延迟初始化，避免启动时访问平台路径。
final class _CoverIndex extends JsonCacheInfoRepository {
  _CoverIndex(this.directoryProvider);
  final Future<Directory> Function() directoryProvider;
  @override
  Future<bool> open() async {
    final root = await directoryProvider();
    await root.create(recursive: true);
    path = '${root.path}/index.json';
    return super.open();
  }
}

final class _CoverFileSystem implements FileSystem {
  _CoverFileSystem(this.directoryProvider);
  final Future<Directory> Function() directoryProvider;
  @override
  Future<fs.File> createFile(String name) async {
    final root = await directoryProvider();
    await root.create(recursive: true);
    return const LocalFileSystem().directory(root.path).childFile(name);
  }
}
