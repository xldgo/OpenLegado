import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/domain/contracts/remote_server_repository.dart';
import 'package:flutter_legado/src/domain/contracts/webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/remote_book/remote_book_notifier.dart';
import 'package:flutter_legado/src/providers/remote_book/remote_server_provider.dart';
import 'package:flutter_legado/src/providers/sync/sync_notifier.dart';
import 'package:flutter_legado/src/providers/webdav_connection_provider.dart';

import '../mocks/mocks.dart';

class _MockServerRepository extends Mock implements RemoteServerRepository {}

class _MockConnectionRepository extends Mock
    implements WebDavConnectionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteBookState path helpers', () {
    test('默认服务器 displayPath / listPath', () {
      const state = RemoteBookState(serverId: -1);
      expect(state.displayPath, 'books/');
      expect(state.listPath, 'books/');
    });

    test('进入子目录后拼接路径', () {
      const state = RemoteBookState(
        serverId: -1,
        dirStack: [
          RemoteBookItem(
            filename: 'novels',
            relativePath: 'books/novels/',
            isDir: true,
          ),
        ],
      );
      expect(state.displayPath, 'books/novels/');
      expect(state.listPath, 'books/novels/');
    });

    test('筛选与排序：目录置顶', () {
      const state = RemoteBookState(
        items: [
          RemoteBookItem(filename: 'b.txt', relativePath: 'books/b.txt'),
          RemoteBookItem(
            filename: 'a_dir',
            relativePath: 'books/a_dir/',
            isDir: true,
          ),
          RemoteBookItem(filename: 'a.txt', relativePath: 'books/a.txt'),
        ],
        sortKey: RemoteBookSort.name,
        sortAscending: true,
      );
      final names = state.visibleItems.map((e) => e.filename).toList();
      expect(names.first, 'a_dir');
      expect(names.sublist(1), ['a.txt', 'b.txt']);
    });
  });

  group('RemoteBookNotifier.refresh / import', () {
    late MockRustApi mockApi;
    late ProviderContainer container;

    setUpAll(registerFallbacks);

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'sync_webdav_url': 'https://dav.example.com/',
        'sync_webdav_username': 'u',
        'sync_webdav_password': 'p',
        'sync_webdav_remote_dir': '/legado/',
        'remote_server_id': -1,
        'remote_servers': '[]',
      });
      mockApi = MockRustApi();
      container = ProviderContainer(
        overrides: [bookApiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);
    });

    RemoteBookNotifier readNotifier() =>
        container.read(remoteBookNotifierProvider.notifier);
    RemoteBookState readState() => container.read(remoteBookNotifierProvider);

    void stubEmptyDirectory() {
      when(() => mockApi.webdavListDir(any(), any()))
          .thenAnswer((_) async => '[]');
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenAnswer((_) async => <Book>[]);
    }

    test('默认配置直接从连接仓储读取，不创建同步Notifier', () async {
      final config = jsonDecode(
        (await readNotifier().buildActiveConfigJson())!,
      );
      expect(config, {
        'url': 'https://dav.example.com/',
        'username': 'u',
        'password': 'p',
        'remote_dir': '/legado/',
      });
      expect(container.exists(syncNotifierProvider), isFalse);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_webdav_remote_dir', '/custom');
      expect(
        jsonDecode(
          (await readNotifier().buildActiveConfigJson())!,
        )['remote_dir'],
        '/custom/',
      );
      await prefs.setString('sync_webdav_password', '');
      expect(await readNotifier().buildActiveConfigJson(), isNull);
    });

    test('自定义配置从根目录列举，URL补斜线且不使用默认凭据', () async {
      stubEmptyDirectory();
      const server = RemoteServerConfig(
        id: 1,
        name: '自定义',
        url: ' https://custom.example ',
        password: ' 原样 ',
      );
      await readNotifier().saveServer(server);
      await readNotifier().selectServer(1);
      final config = jsonDecode(
        (await readNotifier().buildActiveConfigJson())!,
      );
      expect(config, {
        'url': 'https://custom.example/',
        'username': '',
        'password': ' 原样 ',
        'remote_dir': '',
      });
      expect(readState().listPath, '');
      expect(readState().displayPath, '/');
      expect(container.exists(syncNotifierProvider), isFalse);
    });

    test('连续新增服务器发布仓储完整列表，不以旧页面副本覆盖', () async {
      await Future.wait([
        readNotifier().saveServer(
          const RemoteServerConfig(
            id: 1,
            name: '一',
            url: 'https://one.example',
          ),
        ),
        readNotifier().saveServer(
          const RemoteServerConfig(
            id: 2,
            name: '二',
            url: 'https://two.example',
          ),
        ),
      ]);
      expect(readState().servers.map((s) => s.id), [1, 2]);
    });

    test('新增选择删除失败不更新投影，成功删除当前项清空目录和选择', () async {
      stubEmptyDirectory();
      const server = RemoteServerConfig(
        id: 1,
        name: '一',
        url: 'https://one.example',
      );
      final repository = _MockServerRepository();
      when(() => repository.load()).thenAnswer(
        (_) async => RemoteServerSnapshot(servers: [server], selectedId: 1),
      );
      when(() => repository.save(server)).thenThrow(StateError('模拟保存失败'));
      when(() => repository.select(defaultRemoteServerId))
          .thenThrow(StateError('模拟选择失败'));
      when(() => repository.delete(1)).thenThrow(StateError('模拟删除失败'));
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          remoteServerRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await readNotifier().init();
      readNotifier().openDir(
        const RemoteBookItem(
          filename: 'child',
          relativePath: 'child/',
          isDir: true,
        ),
      );
      await readNotifier().refresh();
      readNotifier().toggleSelect(
        const RemoteBookItem(
          filename: 'book.epub',
          relativePath: 'child/book.epub',
        ),
      );
      final previous = readState();
      await expectLater(readNotifier().saveServer(server), throwsStateError);
      expect(identical(readState(), previous), isTrue);
      await expectLater(
        readNotifier().selectServer(defaultRemoteServerId),
        throwsStateError,
      );
      expect(identical(readState(), previous), isTrue);
      await expectLater(readNotifier().deleteServer(1), throwsStateError);
      expect(identical(readState(), previous), isTrue);
      when(() => repository.delete(1))
          .thenAnswer((_) async => RemoteServerSnapshot());
      await readNotifier().deleteServer(1);
      expect(readState().serverId, defaultRemoteServerId);
      expect(readState().dirStack, isEmpty);
      expect(readState().selectedPaths, isEmpty);
      expect(readState().listPath, 'books/');
      expect(readState().servers, isEmpty);
    });

    test('服务器初始读取异常向上传递，不伪装已加载目录', () async {
      final repository = _MockServerRepository();
      when(() => repository.load()).thenThrow(StateError('模拟读取失败'));
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          remoteServerRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final previous = readState();
      await expectLater(readNotifier().init(), throwsStateError);
      expect(identical(previous, readState()), isTrue);
      verifyNever(() => mockApi.webdavListDir(any(), any()));
    });

    test('导入前连接读取失败通过状态反馈，不抛未捕获异常', () async {
      stubEmptyDirectory();
      final connection = _MockConnectionRepository();
      when(() => connection.load()).thenAnswer(
        (_) async => const WebDavConnection(
          url: 'https://dav.example',
          username: 'u',
          password: 'p',
        ),
      );
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          webDavConnectionRepositoryProvider.overrideWithValue(connection),
        ],
      );
      addTearDown(container.dispose);
      when(() => mockApi.webdavListDir(any(), any()))
          .thenAnswer((_) async => '[{"name":"book.epub","is_dir":false}]');
      await readNotifier().init();
      readNotifier().toggleSelect(readState().items.single);
      when(() => connection.load()).thenThrow(StateError('模拟读取失败'));
      await readNotifier().addSelectedToBookshelf();
      expect(readState().error, 'WebDAV 配置读取失败，请重试');
      expect(readState().isImporting, isFalse);
      verifyNever(() => mockApi.webdavDownloadFile(any(), any(), any()));
    });

    test('refresh 解析目录并过滤非书籍文件', () async {
      when(() => mockApi.webdavListDir(any(), any())).thenAnswer(
        (_) async => jsonEncode([
          {
            'name': 'novel.epub',
            'path': '/legado/books/novel.epub',
            'size': 12,
            'is_dir': false,
          },
          {
            'name': 'readme.md',
            'path': '/legado/books/readme.md',
            'size': 1,
            'is_dir': false,
          },
          {
            'name': 'folder',
            'path': '/legado/books/folder/',
            'size': 0,
            'is_dir': true,
          },
        ]),
      );
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenAnswer((_) async => <Book>[]);

      await readNotifier().init();

      final items = readState().items;
      expect(items.map((e) => e.filename).toSet(), {'novel.epub', 'folder'});
      verify(() => mockApi.webdavListDir(any(), 'books/')).called(1);
    });

    test('addSelectedToBookshelf 下载并 importLocalBook', () async {
      final connection = _MockConnectionRepository();
      when(() => connection.load()).thenAnswer(
        (_) async => const WebDavConnection(
          url: 'https://dav.example.com/',
          username: 'u',
          password: 'p',
        ),
      );
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          webDavConnectionRepositoryProvider.overrideWithValue(connection),
        ],
      );
      addTearDown(container.dispose);
      when(() => mockApi.webdavListDir(any(), any()))
          .thenAnswer((_) async => jsonEncode([]));
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenAnswer((_) async => <Book>[]);
      when(() => mockApi.webdavDownloadFile(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockApi.importLocalBook(any())).thenAnswer(
        (_) async => const Book(
          bookUrl: '/tmp/novel.epub',
          name: 'novel',
          origin: 'loc:',
          originName: 'novel.epub',
        ),
      );
      when(() => mockApi.bookshelfRepository.updateBook(any()))
          .thenAnswer((_) async {});

      await readNotifier().init();

      // 注入可选中条目
      container.read(remoteBookNotifierProvider.notifier);
      final n = readNotifier();
      // 直接改 state 较难；通过 refresh 数据再选
      when(() => mockApi.webdavListDir(any(), any())).thenAnswer(
        (_) async => jsonEncode([
          {
            'name': 'novel.epub',
            'path': '/legado/books/novel.epub',
            'size': 12,
            'is_dir': false,
          },
        ]),
      );
      await n.refresh();
      final item = readState().items.single;
      n.toggleSelect(item);
      await n.addSelectedToBookshelf();

      expect(readState().importedCount, 1);
      verify(() => mockApi.webdavDownloadFile(any(), 'books/novel.epub', any()))
          .called(1);
      verify(() => mockApi.importLocalBook(any())).called(1);
      final imported =
          verify(() => mockApi.bookshelfRepository.updateBook(captureAny()))
                  .captured
                  .single
              as Book;
      expect(
        imported.origin,
        '${BookType.webDavTag}https://dav.example.com//legado/books/novel.epub',
      );
      expect(imported.originName, 'novel.epub');
      expect(container.exists(syncNotifierProvider), isFalse);

      // 成功后再失败不能继续沿用上一次成功数量，页面据此显示失败提示。
      n.toggleSelect(readState().items.single);
      when(() => connection.load()).thenThrow(StateError('模拟读取失败'));
      await n.addSelectedToBookshelf();
      expect(readState().importedCount, isNull);
      expect(readState().error, 'WebDAV 配置读取失败，请重试');
      expect(readState().isImporting, isFalse);
      verifyNever(() => mockApi.webdavDownloadFile(any(), any(), any()));
    });
  });
}
