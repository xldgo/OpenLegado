import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../../models/book.dart';
import '../providers.dart';
import '../webdav_connection_provider.dart';
import 'remote_book_state.dart';
import 'remote_server_provider.dart';

export 'remote_book_state.dart';

/// 远程书库 Riverpod Notifier
///
/// 对齐原版 RemoteBookActivity：WebDAV 服务器切换 + 目录浏览 + 下载导入。
/// 列举：`webdavListDir`；导入：`webdavDownloadFile` → `importLocalBook`。
class RemoteBookNotifier extends Notifier<RemoteBookState> {
  static const _bookExts = {'epub', 'txt', 'mobi', 'pdf', 'azw3', 'umd'};
  static const _archiveExts = {'zip', 'rar', '7z'};

  @override
  RemoteBookState build() => const RemoteBookState();

  /// 初始化：加载服务器列表与当前选中，并拉取目录
  Future<void> init() async {
    final saved = await ref.read(remoteServerRepositoryProvider).load();
    state = state.copyWith(
      servers: saved.servers,
      serverId: saved.selectedId,
      dirStack: const [],
      selectedPaths: {},
      clearError: true,
    );
    await refresh();
  }

  String _normalizedRemoteDir(String value) {
    final dir = value.isEmpty ? '/legado/' : value;
    return dir.endsWith('/') ? dir : '$dir/';
  }

  /// 构建当前服务器的 WebDavConfig JSON
  Future<String?> buildActiveConfigJson() async {
    if (state.serverId == defaultRemoteServerId) {
      final connection = await ref
          .read(webDavConnectionRepositoryProvider)
          .load();
      if (connection.url.isEmpty ||
          connection.username.isEmpty ||
          connection.password.isEmpty) {
        return null;
      }
      return jsonEncode({
        'url': connection.url,
        'username': connection.username,
        'password': connection.password,
        'remote_dir': _normalizedRemoteDir(connection.remoteDir),
      });
    }
    RemoteServerConfig? server;
    for (final s in state.servers) {
      if (s.id == state.serverId) {
        server = s;
        break;
      }
    }
    if (server == null) return null;
    var url = server.url.trim();
    if (url.isEmpty) return null;
    if (!url.endsWith('/')) url = '$url/';
    return jsonEncode({
      'url': url,
      'username': server.username,
      'password': server.password,
      'remote_dir': '',
    });
  }

  Future<void> selectServer(int id) async {
    final saved = await ref.read(remoteServerRepositoryProvider).select(id);
    state = state.copyWith(
      servers: saved.servers,
      serverId: saved.selectedId,
      dirStack: const [],
      selectedPaths: {},
      clearError: true,
    );
    await refresh();
  }

  Future<void> saveServer(RemoteServerConfig server) async {
    final saved = await ref.read(remoteServerRepositoryProvider).save(server);
    state = state.copyWith(servers: saved.servers, serverId: saved.selectedId);
  }

  Future<void> deleteServer(int id) async {
    final saved = await ref.read(remoteServerRepositoryProvider).delete(id);
    final selectionChanged = saved.selectedId != state.serverId;
    state = state.copyWith(
      servers: saved.servers,
      serverId: saved.selectedId,
      dirStack: selectionChanged ? const [] : null,
      selectedPaths: selectionChanged ? {} : null,
    );
    if (state.serverId == defaultRemoteServerId || state.serverId == id) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedPaths: {},
    );
    try {
      final config = await buildActiveConfigJson();
      if (config == null) {
        state = state.copyWith(
          isLoading: false,
          items: const [],
          error: state.serverId == defaultRemoteServerId
              ? '请先在备份设置中配置默认 WebDAV，或在「服务器配置」中添加服务器'
              : '服务器配置无效',
        );
        return;
      }
      final api = ref.read(bookApiProvider);
      final raw = await api.webdavListDir(config, state.listPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw Exception('目录列表格式错误');
      }
      final shelf = await api.bookshelfRepository.getBooks();
      final onShelf = <String>{};
      for (final b in shelf) {
        if (b.origin.startsWith(BookType.webDavTag)) {
          onShelf.add(b.origin.substring(BookType.webDavTag.length));
        }
        onShelf.add(b.name);
        if (b.originName.isNotEmpty) onShelf.add(b.originName);
      }

      final items = <RemoteBookItem>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final name = (map['name'] as String?)?.trim() ?? '';
        if (name.isEmpty || name == '.' || name == '..') continue;
        final isDir = map['is_dir'] == true;
        final ext = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : '';
        if (!isDir && !_bookExts.contains(ext) && !_archiveExts.contains(ext)) {
          continue;
        }
        // 跳过当前目录自身（href 末段与当前路径重合）
        final href = (map['path'] as String?) ?? '';
        final current = state.listPath.trimRight().replaceAll(
          RegExp(r'/+$'),
          '',
        );
        if (href.trimRight().replaceAll(RegExp(r'/+$'), '').endsWith(current) &&
            (href.endsWith('/') || isDir) &&
            name == current.split('/').last) {
          // 宽松跳过：名称等于当前目录名且为目录
          if (state.dirStack.isNotEmpty &&
              name == state.dirStack.last.filename &&
              isDir) {
            continue;
          }
          if (state.dirStack.isEmpty &&
              isDir &&
              (name == 'books' || name.isEmpty)) {
            continue;
          }
        }
        final rel = state.listPath.isEmpty
            ? name
            : '${state.listPath}$name${isDir ? '/' : ''}';
        final size = (map['size'] as num?)?.toInt() ?? 0;
        final last = map['last_modified'] as String?;
        final onBook =
            onShelf.contains(name) || onShelf.any((s) => s.contains(rel));
        items.add(
          RemoteBookItem(
            filename: name,
            relativePath: isDir ? rel : rel,
            size: size,
            lastModified: last,
            isDir: isDir,
            isOnBookShelf: onBook,
          ),
        );
      }

      state = state.copyWith(isLoading: false, items: items, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        items: const [],
        error: _mapError(e),
      );
    }
  }

  void setFilter(String value) {
    state = state.copyWith(filter: value);
  }

  void setSort(RemoteBookSort key) {
    if (state.sortKey == key) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortKey: key, sortAscending: true);
    }
  }

  void openDir(RemoteBookItem dir) {
    if (!dir.isDir) return;
    state = state.copyWith(
      dirStack: [...state.dirStack, dir],
      selectedPaths: {},
      filter: '',
    );
    refresh();
  }

  bool goBackDir() {
    if (state.dirStack.isEmpty) return false;
    final stack = [...state.dirStack]..removeLast();
    state = state.copyWith(dirStack: stack, selectedPaths: {}, filter: '');
    refresh();
    return true;
  }

  void toggleSelect(RemoteBookItem item) {
    if (item.isDir || item.isOnBookShelf) return;
    final next = {...state.selectedPaths};
    if (!next.add(item.relativePath)) {
      next.remove(item.relativePath);
    }
    state = state.copyWith(selectedPaths: next);
  }

  void selectAllVisible(bool select) {
    if (!select) {
      state = state.copyWith(selectedPaths: {});
      return;
    }
    final next = <String>{};
    for (final e in state.visibleItems) {
      if (!e.isDir && !e.isOnBookShelf) next.add(e.relativePath);
    }
    state = state.copyWith(selectedPaths: next);
  }

  void revertSelection() {
    final checkable = state.visibleItems
        .where((e) => !e.isDir && !e.isOnBookShelf)
        .map((e) => e.relativePath)
        .toSet();
    final next = <String>{};
    for (final p in checkable) {
      if (!state.selectedPaths.contains(p)) next.add(p);
    }
    state = state.copyWith(selectedPaths: next);
  }

  /// 将选中远程文件下载并导入书架
  Future<void> addSelectedToBookshelf() async {
    final selected = state.items
        .where((e) => state.selectedPaths.contains(e.relativePath))
        .toList();
    if (selected.isEmpty) {
      state = state.copyWith(error: '请先选择要导入的书籍');
      return;
    }
    String? config;
    try {
      config = await buildActiveConfigJson();
    } catch (_) {
      state = state.copyWith(
        isImporting: false,
        clearImported: true,
        error: 'WebDAV 配置读取失败，请重试',
      );
      return;
    }
    if (config == null) {
      state = state.copyWith(error: 'WebDAV 未配置');
      return;
    }
    state = state.copyWith(
      isImporting: true,
      clearError: true,
      clearImported: true,
    );
    final api = ref.read(bookApiProvider);
    final dir = Directory('${Directory.systemTemp.path}/legado_remote_books');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var ok = 0;
    String? lastErr;
    for (final item in selected) {
      try {
        final localPath = '${dir.path}/${item.filename}';
        await api.webdavDownloadFile(config, item.relativePath, localPath);
        final book = await api.importLocalBook(localPath);
        // 对齐原版：origin = dav: + 远程路径
        var remoteUrl = item.relativePath;
        if (state.serverId == defaultRemoteServerId) {
          final connection = await ref
              .read(webDavConnectionRepositoryProvider)
              .load();
          remoteUrl =
              '${connection.url}${_normalizedRemoteDir(connection.remoteDir)}${item.relativePath}';
        }
        await api.bookshelfRepository.updateBook(
          book.copyWith(
            origin: BookType.webDavTag + remoteUrl,
            originName: item.filename,
          ),
        );
        ok++;
      } catch (e) {
        lastErr = _mapError(e);
      }
    }
    state = state.copyWith(
      isImporting: false,
      importedCount: ok,
      selectedPaths: {},
      error: ok == 0 ? (lastErr ?? '导入失败') : null,
      clearError: ok > 0,
    );
    if (ok > 0) {
      await refresh();
    }
  }

  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

final remoteBookNotifierProvider =
    NotifierProvider<RemoteBookNotifier, RemoteBookState>(
      RemoteBookNotifier.new,
    );
