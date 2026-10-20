@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

import '../helpers/native_ffi.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cover_rule_repository.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_edit_service.dart';
import 'package:flutter_legado/src/data/services/rust_cover_search_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_action_service.dart';
import 'package:flutter_legado/src/data/services/rust_audio_book_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_login_v2_service.dart';
import 'package:flutter_legado/src/data/services/rust_explore_service.dart';
import 'package:flutter_legado/src/domain/models/cover_rule.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Directory(
      '.dart_tool/source-tools-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await nativeTestRuntime().initialize();
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
  test('发现脚本完整书源直传，标题与动作顺序及刷新标记保持', () async {
    const service = RustExploreService();
    const source = BookSource(
      bookSourceUrl: 'https://explore-wire.test',
      bookSourceName: '发现源😀',
      header: '{"X-Trace":"保留"}',
      enabledCookieJar: false,
    );
    expect(
      await service.evaluateUiJs(
        source: source,
        jsStr: 'source.bookSourceName + source.header',
      ),
      '${source.bookSourceName}${source.header}',
    );
    final result = await service.evaluateAction(
      source: source,
      actionJs: "java.copyText(source.bookSourceName);java.copyText(source.header);java.refreshExplore();'完成'",
    );
    expect(result.raw, '完成');
    expect(result.refreshExplore, isTrue);
    expect(result.actions, [
      {'action': 'copyText', 'text': source.bookSourceName},
      {'action': 'copyText', 'text': source.header},
    ]);
    await expectLater(
      service.evaluateAction(
        source: source,
        actionJs: "throw new Error('脚本失败')",
      ),
      throwsA(anything),
    );
  });
  test('闲置导出清理后既有音频进度和播放模式接线保持', () async {
    const audio = RustAudioBookService();
    await audio.saveAudioProgress('audio-book', 7, 9007199254740993);
    expect(await audio.getAudioProgress('audio-book', 7), 9007199254740993);
    final config = await audio.audioWithPlayMode(playMode: 2);
    expect(config.toJson()['playMode'], 2);
  });
  test('登录V2实体直传，动态状态和表单保真并先持久化登录结果', () async {
    final source = BookSource(
      bookSourceUrl: 'https://login-wire.test',
      bookSourceName: '登录源😀',
      loginUi: '{"version":2}',
      header: '{"X-Trace":"keep"}',
      enabledCookieJar: false,
      mainJs: '''function loginUi(state){return {rows:[{type:'text',key:'account',name:source.bookSourceName,value:source.header}]};}
function loginAction(action,state,form){if(action==='noop')return;return {login:{token:form.account,extra:form.extra},state:{step:state.step,unknown:state.unknown},close:true};}''',
    );
    final intercepted = <String>[];
    final service = RustSourceLoginV2Service(
      interceptResult: (raw) async {
        intercepted.add(raw);
        return raw;
      },
    );
    expect(await service.isLoginUiV2(source), isTrue);
    final ui = await service.loadUi(source, {'step': 1});
    expect(ui.rows.single.name, source.bookSourceName);
    expect(ui.rows.single.value, source.header);
    const unknown = {
      'values': [true, null, '😀'],
    };
    final result = await service.execute(
      source,
      action: 'submit',
      state: {'step': 2, 'unknown': unknown},
      form: {'account': '甲', 'extra': unknown},
    );
    expect(result.close, isTrue);
    expect(result.state, {'step': 2, 'unknown': unknown});
    expect(result.login, {'token': '甲', 'extra': unknown});
    expect(
      jsonDecode(
        await bridge.sourceGetLoginInfo(sourceUrl: source.bookSourceUrl),
      ),
      result.login,
    );
    expect(intercepted, hasLength(2));
    final noop = await bridge.sourceLoginActionV2(
      source: bookSourceToDto(source),
      userInputJson: '{"action":"noop"}',
    );
    expect(noop, isEmpty);
  });
}
