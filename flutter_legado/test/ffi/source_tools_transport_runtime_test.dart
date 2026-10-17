library;

@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cover_rule_repository.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_edit_service.dart';
import 'package:flutter_legado/src/data/services/rust_cover_search_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_action_service.dart';
import 'package:flutter_legado/src/data/services/rust_audio_book_service.dart';
import 'package:flutter_legado/src/domain/models/cover_rule.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  if (!Platform.isWindows) {
    test('需要Windows DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Directory(
      '.dart_tool/source-tools-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await const NativeRustRuntime().initialize();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  test('封面配置三态Cookie与data规则搜索保持，空配置拒绝', () async {
    const repo = RustCoverRuleRepository();
    const service = RustCoverSearchService();
    for (final cookie in <bool?>[null, false, true]) {
      final rule = CoverRule(
        searchUrl: 'data:text/html,<img src="https://example.test/cover.jpg">',
        coverRule: 'img@src',
        enabledCookieJar: cookie,
      );
      expect(await repo.saveCoverRule(rule), isTrue);
      final read = await repo.getCoverRule();
      expect(read.searchUrl, rule.searchUrl);
      expect(read.coverRule, rule.coverRule);
      expect(read.enabledCookieJar, cookie);
      expect(await service.searchCoverRules('书'), [
        'https://example.test/cover.jpg',
      ]);
    }
    await expectLater(repo.saveCoverRule(const CoverRule()), throwsA(anything));
  });
  test('真实JS提取完整书源与语法诊断，mainJs保留原脚本', () async {
    const script =
        "var config={bookSourceUrl:'https://js.test',bookSourceName:'源😀',loginUrl:'login()',enabledCookieJar:false,header:'{\\\"X\\\":\\\"v\\\"}'};function search(k){return k;}function getChapters(){return [];}function getContent(){return '';}";
    const service = RustBookSourceEditService();
    final source = await service.extractJsSource(script);
    expect(source.bookSourceUrl, 'https://js.test');
    expect(source.bookSourceName, '源😀');
    expect(source.loginUrl, 'login()');
    expect(source.mainJs, script);
    expect(source.enabledCookieJar, isFalse);
    final valid = await service.checkJsSourceSyntax('var x=1;');
    expect(valid.valid, isTrue);
    final invalid = await service.checkJsSourceSyntax('function broken( {');
    expect(invalid.valid, isFalse);
    expect(invalid.message, isNotEmpty);
    await expectLater(
      service.extractJsSource('throw new Error("bad")'),
      throwsA(anything),
    );
  });
  test('本机书源搜索返回封面候选，回调真实动作只回放一次', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write(
        '<li><a href="/book">书</a><img src="/cover.png"></li>',
      );
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}';
    final source = BookSource.fromJson({
      'bookSourceUrl': url,
      'bookSourceName': '本机源',
      'enabled': true,
      'searchUrl': '$url/search',
      'eventListener': true,
      'ruleSearch': {
        'bookList': 'li',
        'name': 'a@text',
        'bookUrl': 'a@href',
        'coverUrl': 'img@src',
      },
      'ruleContent': {
        'callBackJs': "java.copyText('甲');java.copyText('乙');true",
      },
    });
    await RustBookSourceRepository(onSourcesChanged: () {})
        .addBookSource(source);
    final covers = await const RustCoverSearchService().searchCover('书');
    expect(covers.single.url, '$url/cover.png');
    expect(covers.single.width, 0);
    expect(covers.single.height, 0);
    await const RustBookshelfRepository().addBook(
      Book(bookUrl: '$url/book', name: '书', origin: url),
    );
    final dispatches = <List<dynamic>>[];
    final service = RustSourceActionService(
      dispatchActions: (actions) async {
        dispatches.add(actions);
      },
    );
    final result = await service.sourceCallBackBtn(
      event: 'clickCustomButton',
      bookUrl: '$url/book',
    );
    expect(result.handled, isTrue);
    expect(dispatches, hasLength(1));
    expect(dispatches.single, [
      {'action': 'copyText', 'text': '甲'},
      {'action': 'copyText', 'text': '乙'},
    ]);
    await const RustBookshelfRepository().addBook(
      const Book(bookUrl: 'local.txt', name: '本地'),
    );
    final purchase = await service.chapterPayAction(
      bookUrl: 'local.txt',
      chapterIndex: 0,
    );
    expect(purchase.kind, ChapterPurchaseKind.none);
    expect(dispatches, hasLength(1));
  });
  test('闲置导出清理后既有音频进度和播放模式接线保持', () async {
    const audio = RustAudioBookService();
    await audio.saveAudioProgress('audio-book', 7, 9007199254740993);
    expect(await audio.getAudioProgress('audio-book', 7), 9007199254740993);
    final config = await audio.audioWithPlayMode(playMode: 2);
    expect(config.toJson()['playMode'], 2);
  });
}
