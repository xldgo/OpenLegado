@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_legado/src/domain/errors/app_exception.dart';

import 'package:flutter_legado/src/data/repositories/rust_backup_repository.dart';
import 'package:flutter_legado/src/data/services/rust_rule_execution_service.dart';
import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/business_dto_mapping.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_article_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_star_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_dict_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_replace_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_search_history_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rule_sub_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_config_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_explore_state_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_app_log_repository.dart';
import 'package:flutter_legado/src/data/services/rust_rule_sub_service.dart';
import 'package:flutter_legado/src/data/services/rust_dictionary_service.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/business_transport_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(() async {
    root = Directory(
      '.dart_tool/business-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await nativeTestRuntime().initialize();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  test('RSS四十四字段经真实wire和SQLite往返，更新不混入书源表', () async {
    const repo = RustRssSourceRepository();
    final source = rssSourceFromDto(
      fixtureRssSourceDto({
        'sourceUrl': 'https://rss.fixture/source',
        'sourceName': '订阅😀',
        'sourceIcon': 'icon',
        'sourceGroup': 'group',
        'sourceComment': 'comment',
        'enabled': false,
        'variableComment': 'variable',
        'jsLib': 'var x=1;',
        'enabledCookieJar': true,
        'concurrentRate': '1000',
        'header': '{"X":"value"}',
        'loginUrl': 'login()',
        'loginUi': '[]',
        'loginCheckJs': 'result',
        'coverDecodeJs': 'result',
        'sortUrl': 'sort',
        'singleUrl': true,
        'articleStyle': 4,
        'ruleArticles': 'article',
        'ruleNextPage': 'next',
        'ruleTitle': 'title',
        'rulePubDate': 'date',
        'ruleDescription': 'description',
        'ruleImage': 'image',
        'ruleLink': 'link',
        'ruleContent': 'content',
        'contentWhitelist': 'allow',
        'contentBlacklist': 'deny',
        'shouldOverrideUrlLoading': 'override',
        'style': 'style',
        'enableJs': false,
        'loadWithBaseUrl': false,
        'injectJs': 'inject',
        'preloadJs': 'preload',
        'startHtml': 'html',
        'startStyle': 'css',
        'startJs': 'js',
        'showWebLog': true,
        'lastUpdateTime': 9007199254740993,
        'customOrder': 7,
        'type': 2,
        'preload': true,
        'cacheFirst': true,
        'searchUrl': 'search',
      }),
    );
    expect(await repo.addRssSource(source), source);
    expect((await repo.getRssSources()).single, source);
    final updated = source.copyWith(
      sourceName: '修改',
      enabledCookieJar: null,
      ruleTitle: null,
    );
    await repo.updateRssSource(updated);
    expect((await repo.getRssSources()).single, updated);
    expect(await bridge.sourceList(), isEmpty);
    await expectLater(
      repo.updateRssSource(source.copyWith(sourceUrl: 'missing')),
      throwsA(anything),
    );
    expect((await repo.getRssSources()).single, updated);
    expect(jsonDecode(await repo.exportRssSources()), [updated.toJson()]);
  });
  test('本机RSS文章、收藏时间和已读记录直接映射，缓存清理不影响身份', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType(
        'application',
        'rss+xml',
        charset: 'utf-8',
      );
      request.response.write(
        '<?xml version="1.0"?><rss version="2.0"><channel><title>源</title><link>http://example.test</link><description>摘要</description><item><title>文章😀</title><link>http://example.test/article</link><description>内容</description><pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate></item></channel></rss>',
      );
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/rss';
    await const RustRssSourceRepository().addRssSource(
      RssSource(sourceUrl: url, sourceName: '本机源'),
    );
    const articles = RustRssArticleRepository();
    final list = await articles.getRssArticles(url);
    expect(list.single.title, '文章😀');
    expect(list.single.url, 'http://example.test/article');
    const stars = RustRssStarRepository();
    await stars.addRssStar(
      RssStar(origin: url, title: '文章😀', link: list.single.url),
    );
    final star = (await stars.getRssStars()).single;
    expect(star.starTime, greaterThan(0));
    expect(star.link, list.single.url);
    const records = RustRssReadRecordRepository();
    await records.rssMarkRead(url, star.title, star.link);
    expect(
      (await records.rssListReadRecordsByOrigin(url)).single.readTime,
      greaterThan(0),
    );
    expect(await records.rssIsRead(star.link), isTrue);
    await articles.rssClearArticles(url);
    expect(await stars.isStarred(star.link), isTrue);
  });
  test('字典与替换规则、历史及排序保留实体字段', () async {
    const rules = RustDictRuleRepository();
    await rules.dictRuleImport(
      jsonOrUrl:
          '[{"name":"离线词典","urlRule":"data:text/plain,中文释义","showRule":""}]',
      kind: 'text',
    );
    final dictionary = (await rules.dictRuleList()).single;
    expect(await rules.dictRuleReorder([dictionary.id]), 1);
    final entry = await const RustDictionaryService().dictLookup('测试');
    expect(entry.word, '测试');
    expect(entry.definitions.single, contains('中文释义'));
    const replace = RustReplaceRuleRepository();
    final added = await replace.addReplaceRule(
      const ReplaceRule(
        name: '替换',
        pattern: 'a',
        replacement: 'b',
        scopeSource: true,
        scopeTitle: true,
        group: '组',
        excludeScope: '排除',
        timeoutMillisecond: 2100,
      ),
    );
    final saved = (await replace.getReplaceRules()).single;
    expect(saved.id, added.id);
    expect(saved.scopeSource, isTrue);
    expect(saved.group, '组');
    expect(saved.timeoutMillisecond, 2100);
    const history = RustSearchHistoryRepository();
    await history.addSearchKeyword('小说😀', '书');
    expect((await history.getSearchHistory()).single.word, '小说😀');
    expect(
      (await history.getSearchHistory()).single.lastUseTime,
      greaterThan(0),
    );
    expect(await history.searchHistoryByPrefix('小'), ['小说😀']);
    const books = RustBookshelfRepository();
    await books.addBook(const Book(bookUrl: 'book', name: '书'));
    await books.reorderBooks([
      {'bookUrl': 'book', 'order': -7},
    ]);
    expect((await books.getBook('book'))!.order, -7);
  });
  test('规则订阅完整保存和真实本机检查应用结果，错误不冒充成功', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('[{"name":"替换","pattern":"a","replacement":"b"}]');
      await request.response.close();
    });
    const repo = RustRuleSubRepository();
    const service = RustRuleSubService();
    final input = RuleSub(
      url: 'http://127.0.0.1:${server.port}/sub',
      name: '订阅',
      subType: RuleSub.replaceRule,
      lastUpdate: 100,
      version: 'v1',
      isEnabled: false,
      createdAt: 99,
      customOrder: 3,
      autoUpdate: true,
      updateInterval: 12,
      silentUpdate: true,
    );
    expect(await repo.ruleSubSave(input), isTrue);
    final saved = (await repo.ruleSubList()).single;
    expect(saved.copyWith(id: 0).toJson(), input.toJson());
    expect(await repo.ruleSubUpdateOrder(ids: [saved.id]), isTrue);
    final checked = await service.ruleSubCheckUpdate(id: saved.id);
    expect(checked.id, saved.id);
    expect(checked.hasUpdate, isTrue);
    expect(checked.error, isNull);
    final applied = await service.ruleSubApplyUpdate(id: saved.id);
    expect(applied.success, isTrue);
    expect(applied.totalItems, 1);
    expect(applied.itemsAdded, 1);
    expect(applied.error, isNull);
    await expectLater(
      service.ruleSubCheckUpdate(id: 999999),
      throwsA(anything),
    );
  });
  test('配置和infoMap不解释值中JSON，日志与备份统计保持真实数据', () async {
    const config = RustConfigRepository();
    await config.setConfig('document', '{"a":true}');
    expect((await config.getAllConfigs())['document'], '{"a":true}');
    const explore = RustExploreStateRepository();
    await explore.put('source', 'key', '{"b":1}');
    expect((await explore.snapshot('source'))['key'], '{"b":1}');
    const logs = RustAppLogRepository();
    await logs.appLogClearAll();
    await logs.appLogPush(level: 'HTTP', message: '本机日志\n下一行');
    final log = (await logs.appLogList(level: 'http')).single;
    expect(log.level, 'http');
    expect(log.message, '本机日志\n下一行');
    expect(log.timestamp, greaterThan(0));
    expect(await logs.appLogExport(), contains('本机日志'));
    const rss = RustRssSourceRepository();
    final originals = await rss.getRssSources();
    final bookCount = (await const RustBookshelfRepository().getBooks()).length;
    final ruleCount =
        (await const RustReplaceRuleRepository().getReplaceRules()).length;
    final path = '${root.absolute.path}/backup.zip';
    expect(
      await bridge.backupCreate(
        path: path,
        preferencesJson: '{}',
        filesJson: '{}',
        sensitiveJson: '{}',
        password: null,
      ),
      path,
    );
    final files = await bridge.backupList(dir: root.absolute.path);
    expect(files.single.name, 'backup.zip');
    expect(
      File(files.single.path).resolveSymbolicLinksSync(),
      File(path).resolveSymbolicLinksSync(),
    );
    expect(files.single.size, BigInt.from(await File(path).length()));
    // 清空目标表后恢复原始备份，防止旧行掩盖字段丢失。
    for (final source in originals) {
      await rss.deleteRssSource(source.sourceUrl);
    }
    expect(await rss.getRssSources(), isEmpty);
    final restoredPackage = await bridge.backupRestore(
      path: path,
      password: null,
      ignoreJson: '[]',
    );
    final stats = restoredPackage.stats;
    expect(stats.books, BigInt.from(bookCount));
    expect(stats.replaceRules, BigInt.from(ruleCount));
    expect(stats.additional['readRecordDaily'], BigInt.zero);
    expect(stats.rssSources, BigInt.from(originals.length));
    final restored = await rss.getRssSources();
    expect(restored, originals);
  });

  test('固定结果经真实FRB往返，文档/部分导入消息和网络失败保持', () async {
    final rules = RustRuleExecutionService(interceptResult: (raw) async => raw);
    final parsed = await rules.parseRule('<p>甲😀</p><p>乙</p>', 'p@text', 'css');
    expect(parsed.results, ['甲😀', '乙']);
    expect(parsed.count, 2);
    final empty = await rules.parseRule('<p>正文</p>', 'span@text', 'css');
    expect(empty.results, isEmpty);
    expect(empty.count, 0);
    final dir = await Directory('${root.path}/legacy-result').create();
    await File('${dir.path}/myBookShelf.json').writeAsString(
      '[{"noteUrl":"https://old-fixed.test/book","bookInfoBean":{"name":"旧版😀"}}]',
    );
    const backup = RustBackupRepository();
    final imported = await backup.importOldData(dir.path);
    expect(imported.books, 1);
    expect(imported.bookSources, 0);
    expect(imported.replaceRules, 0);
    expect(imported.messages, ['成功导入书架1', '未找到 myBookSource.json', '未找到替换规则']);
    expect(
      (await const RustBookshelfRepository().getBook(
        'https://old-fixed.test/book',
      ))?.name,
      '旧版😀',
    );
    expect((await backup.importOldData(dir.path)).books, 0);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <String>[];
    var failUpload = false;
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add('${request.method} ${request.uri.path} $body');
      request.response.headers.contentType = ContentType.text;
      if (failUpload && request.method == 'PUT') {
        request.response.statusCode = HttpStatus.forbidden;
      } else if (request.method == 'GET') {
        request.response.write(
          request.uri.path.endsWith('bookshelf.json')
              ? '远端😀非JSON文档'
              : '{"远端源":"原样"}',
        );
      } else {
        request.response.statusCode = HttpStatus.created;
      }
      await request.response.close();
    });
    final connection = WebDavConnection(
      url: 'http://127.0.0.1:${server.port}',
      username: 'u',
      password: 'p',
      remoteDir: '/books',
    );
    const dav = RustWebDavService();
    final synced = await dav.webdavFullSync(connection, '本地书架😀', '本地书源');
    expect(synced.books, '远端😀非JSON文档');
    expect(synced.sources, '{"远端源":"原样"}');
    expect(requests, [
      'MKCOL /books/ ',
      'PUT /books/bookshelf.json 本地书架😀',
      'PUT /books/sources.json 本地书源',
      'GET /books/bookshelf.json ',
      'GET /books/sources.json ',
    ]);
    failUpload = true;
    await expectLater(
      dav.webdavFullSync(connection, '本地书架😀', '本地书源'),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          '原生错误消息',
          contains('HTTP 403'),
        ),
      ),
    );
  });
}
