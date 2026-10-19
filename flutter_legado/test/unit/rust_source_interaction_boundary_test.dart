import 'package:flutter_legado/src/bridge/source_tools_dto.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/task_dto.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as controls;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_edit_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_login_v2_service.dart';
import 'package:flutter_legado/src/data/services/rust_verification_service.dart';
import 'package:flutter_legado/src/data/services/rust_webview_bridge_service.dart';
import 'package:flutter_legado/src/data/services/rust_network_service.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/platform/native_webview_request_executor.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';

class _Bridge extends Mock implements RustLibApi {}

class _Request extends Fake implements controls.StreamRequest {
  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  late _Bridge bridge;
  const editor = RustBookSourceEditService();
  const verification = RustVerificationService();
  const web = RustWebViewBridgeService();
  const source = BookSource(
    bookSourceUrl: 'https://source.test',
    bookSourceName: '源',
    loginUi: '{"version":2}',
    loginUrl: 'script',
  );
  setUpAll(() {
    registerFallbackValue(_Request());
    registerFallbackValue(
      const WebViewPageCallDto(
        target: WebViewPageTargetDto.source,
        method: "get",
        args: [],
      ),
    );
    registerFallbackValue(bookSourceToDto(source));
    registerFallbackValue(
      WebViewResponseDto(result: '', finalUrl: '', cookies: const {}),
    );
  });
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    when(() => bridge.crateFfiStreamRequestNew()).thenReturn(_Request());
  });
  tearDown(RustLib.dispose);

  test('页内调用DTO保留目标和null参数，Rust错误直接传播', () async {
    when(
      () => bridge.crateFfiFfiWebviewPageCall(
        key: 'owner',
        call: any(named: 'call'),
      ),
    ).thenAnswer((_) async => 'null');
    expect(
      await web.pageCall(
        'owner',
        WebViewPageCall(
          target: WebViewPageTarget.source,
          method: 'putVariable',
          args: [null],
        ),
      ),
      'null',
    );
    final value =
        verify(
              () => bridge.crateFfiFfiWebviewPageCall(
                key: 'owner',
                call: captureAny(named: 'call'),
              ),
            ).captured.single
            as WebViewPageCallDto;
    expect(value.target, WebViewPageTargetDto.source);
    expect(value.method, 'putVariable');
    expect(value.args, [null]);
    when(
      () => bridge.crateFfiFfiWebviewPageCall(
        key: 'owner',
        call: any(named: 'call'),
      ),
    ).thenThrow(controls.BridgeError(message: '请求已结束'));
    await expectLater(
      web.pageCall(
        'owner',
        WebViewPageCall(
          target: WebViewPageTarget.cache,
          method: 'get',
          args: ['key'],
        ),
      ),
      throwsA(isA<AppException>().having((e) => e.message, '原错误消息', '请求已结束')),
    );
  });

  test('WebView类型化回传保留最终URL、正常空结果与错误，原生拒绝保持false', () async {
    when(
      () => bridge.crateFfiFfiWebviewComplete(
        key: 'w',
        response: any(named: 'response'),
      ),
    ).thenAnswer((_) async => false);
    final accepted = await web.completeWebviewRequest(
      'w',
      WebViewExecutionResult(
        result: '',
        finalUrl: 'https://final.test/',
        error: '加载失败',
        cookies: {'final.test': 'sid=new'},
      ),
    );
    expect(accepted, isFalse);
    final captured =
        verify(
              () => bridge.crateFfiFfiWebviewComplete(
                key: 'w',
                response: captureAny(named: 'response'),
              ),
            ).captured.single
            as WebViewResponseDto;
    expect(captured.result, '');
    expect(captured.finalUrl, 'https://final.test/');
    expect(captured.error, '加载失败');
    expect(captured.cookies, {'final.test': 'sid=new'});
  });

  test('平台执行器传递Header和key，并使用平台最终URL', () async {
    final payloads = <Map<String, dynamic>>[];
    final stopped = <String>[];
    final executor = NativeWebViewRequestExecutor(
      dispatch: (payload) async {
        payloads.add(payload);
        return const WebViewEvalOutcome(
          '',
          '',
          finalUrl: 'https://final.test/',
        );
      },
      cancel: (key) async {
        stopped.add(key);
      },
    );
    final result = await executor.execute(
      const WebViewRequest(
        key: 'owned',
        url: 'https://initial.test/',
        headers: {'X-Test': 'yes'},
      ),
    );
    expect(payloads.single['key'], 'owned');
    expect(payloads.single['headers'], {'X-Test': 'yes'});
    expect(result.finalUrl, 'https://final.test/');
    expect(result.result, '');
    expect(result.error, isNull);
    await executor.cancel('owned');
    expect(stopped, ['owned']);
  });

  test('编辑能力保持原生cURL参数，提取结果保留完整当前脚本', () async {
    when(() => bridge.crateFfiFfiLooksLikeCurl(text: 'curl -L url'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiCurlToAnalyzeUrl(text: 'curl -L url'))
        .thenAnswer((_) async => 'url');
    when(() => bridge.crateFfiFfiAnalyzeUrlToCurl(text: 'url'))
        .thenAnswer((_) async => 'curl -g -L url');
    when(
      () => bridge.crateFfiFfiJsSourceExtract(content: '完整脚本'),
    ).thenAnswer((_) async => bookSourceToDto(source.copyWith(mainJs: '旧内容')));
    expect(await editor.looksLikeCurl('curl -L url'), isTrue);
    expect(await editor.curlToAnalyzeUrl('curl -L url'), 'url');
    expect(await editor.analyzeUrlToCurl('url'), 'curl -g -L url');
    final extracted = await editor.extractJsSource('完整脚本');
    expect(extracted.bookSourceUrl, source.bookSourceUrl);
    expect(extracted.loginUrl, 'script');
    expect(extracted.mainJs, '完整脚本');
  });
  test('语法结果类型化并保留错误行号', () async {
    when(() => bridge.crateFfiFfiJsSourceSyntaxCheck(content: 'bad'))
        .thenAnswer(
          (_) async =>
              const SourceSyntaxDto(valid: false, message: '缺少括号', line: 12),
        );
    final result = await editor.checkJsSourceSyntax('bad');
    expect(result.valid, isFalse);
    expect(result.message, '缺少括号');
    expect(result.line, 12);
  });
  test('提取、语法和原生转换异常保持失败', () async {
    final error = StateError('JS_INVALID');
    when(() => bridge.crateFfiFfiJsSourceExtract(content: 'bad'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiJsSourceSyntaxCheck(content: 'bad'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiCurlToAnalyzeUrl(text: 'bad'))
        .thenThrow(error);
    await expectLater(editor.extractJsSource('bad'), throwsA(same(error)));
    await expectLater(editor.checkJsSourceSyntax('bad'), throwsA(same(error)));
    await expectLater(
      () => editor.curlToAnalyzeUrl('bad'),
      throwsA(same(error)),
    );
  });
  test('V2传入完整书源和状态，平台拦截发生在表单和动作解码之前', () async {
    final intercepted = <String>[];
    final service = RustSourceLoginV2Service(
      interceptResult: (raw) async {
        intercepted.add(raw);
        return raw == 'ui'
            ? '{"rows":[{"type":"text","key":"account","name":"账号","value":"已保存"}]}'
            : '{"state":{"step":2},"error":{"account":"错误"},"login":{"token":"value"},"close":true}';
      },
    );
    final sourceDto = bookSourceToDto(source);
    when(() => bridge.crateFfiFfiSourceIsLoginUiV2(source: sourceDto))
        .thenAnswer((_) async => true);
    when(
      () => bridge.crateFfiFfiSourceLoginUiV2(
        source: sourceDto,
        stateJson: '{"step":1}',
      ),
    ).thenAnswer((_) async => 'ui');
    when(
      () => bridge.crateFfiFfiSourceLoginActionV2(
        source: sourceDto,
        userInputJson: any(named: 'userInputJson'),
      ),
    ).thenAnswer((call) async {
      expect(
        bookSourceFromDto(call.namedArguments[#source] as BookSourceDto),
        source,
      );
      final input =
          jsonDecode(call.namedArguments[#userInputJson] as String) as Map;
      expect(input['action'], 'login');
      expect(jsonDecode(input['stateJson'] as String), {'step': 1});
      expect(input['formJson'], {'account': '账号甲'});
      return 'action';
    });
    expect(await service.isLoginUiV2(source), isTrue);
    final ui = await service.loadUi(source, {'step': 1});
    expect(ui.rows.single.key, 'account');
    expect(ui.rows.single.value, '已保存');
    final action = await service.execute(
      source,
      action: 'login',
      state: {'step': 1},
      form: {'account': '账号甲'},
    );
    expect(action.close, isTrue);
    expect(action.login, {'token': 'value'});
    expect(action.errors, {'account': '错误'});
    expect(action.state, {'step': 2});
    expect(intercepted, ['ui', 'action']);
  });
  test('V2坏响应不当空表单，平台拦截错误不吞掉', () async {
    when(
      () => bridge.crateFfiFfiSourceLoginUiV2(
        source: any(named: 'source'),
        stateJson: '{}',
      ),
    ).thenAnswer((_) async => 'raw');
    final bad = RustSourceLoginV2Service(interceptResult: (_) async => '{}');
    await expectLater(bad.loadUi(source, {}), throwsFormatException);
    final error = StateError('平台执行失败');
    final failed = RustSourceLoginV2Service(
      interceptResult: (_) async => throw error,
    );
    await expectLater(failed.loadUi(source, {}), throwsA(same(error)));
  });
  test('验证码流保留身份、展示与时间字段，提交/取消保持未命中含义', () async {
    when(
      () => bridge.crateFfiFfiVerificationRequestStream(
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        VerificationRequestDto(
          key: 'v1',
          sourceUrl: 's',
          sourceName: '源',
          imageUrl: 'img',
          title: '验证',
          useBrowser: true,
          createdAtMs: BigInt.from(123),
        ),
      ),
    );
    final request = await verification.verificationRequestStream().single;
    expect(request.key, 'v1');
    expect(request.sourceUrl, 's');
    expect(request.sourceName, '源');
    expect(request.imageUrl, 'img');
    expect(request.title, '验证');
    expect(request.useBrowser, isTrue);
    expect(request.createdAtMs, 123);
    when(() => bridge.crateFfiFfiVerificationSubmit(key: 'v1', code: '1234'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiVerificationCancel(key: 'v1'))
        .thenAnswer((_) async => false);
    expect(await verification.submitVerificationResult('v1', '1234'), isTrue);
    expect(await verification.cancelVerificationRequest('v1'), isFalse);
  });
  test('WebView流保留全部执行字段，Cookie直接使用域映射', () async {
    when(
      () => bridge.crateFfiFfiWebviewRequestStream(
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        WebViewRequestDto(
          headers: const {},
          key: 'w',
          action: 'webViewGetSource',
          html: 'html',
          url: 'url',
          js: 'js',
          sourceRegex: 'source',
          overrideUrlRegex: 'override',
          cacheFirst: true,
          delayTime: 50,
          isRule: true,
          result: 'input',
          sourceKey: 'origin',
          cookie: 'sid=x',
          createdAtMs: BigInt.from(456),
        ),
      ),
    );
    final request = await web.webviewRequestStream().single;
    expect(
      [request.key, request.action, request.html, request.url, request.js],
      ['w', 'webViewGetSource', 'html', 'url', 'js'],
    );
    expect(
      [
        request.sourceRegex,
        request.overrideUrlRegex,
        request.sourceKey,
        request.cookie,
        request.result,
      ],
      ['source', 'override', 'origin', 'sid=x', 'input'],
    );
    expect(request.cacheFirst, isTrue);
    expect(request.isRule, isTrue);
    expect(request.delayTime, 50);
    expect(request.createdAtMs, 456);
    when(
      () => bridge.crateFfiFfiWebviewSubmitResultWithCookies(
        key: 'w',
        result: 'out',
        cookies: {'https://source.test': 'sid=y'},
      ),
    ).thenAnswer((_) async => true);
    when(
      () => bridge.crateFfiFfiWebviewSubmitResultWithCookies(
        key: 'w',
        result: 'out',
        cookies: {},
      ),
    ).thenAnswer((_) async => false);
    when(
      () => bridge.crateFfiFfiWebviewSubmit(key: 'w', result: '[ERROR] failed'),
    ).thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiWebviewCancel(key: 'w'))
        .thenAnswer((_) async => false);
    expect(
      await web.submitWebviewResultWithCookies('w', 'out', {
        'https://source.test': 'sid=y',
      }),
      isTrue,
    );
    expect(await web.submitWebviewResultWithCookies('w', 'out', {}), isFalse);
    expect(await web.submitWebviewResult('w', '[ERROR] failed'), isTrue);
    expect(await web.cancelWebviewRequest('w'), isFalse);
  });
  test('两类通道拒绝无身份DTO，不创建无主请求', () async {
    when(
      () => bridge.crateFfiFfiVerificationRequestStream(
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        VerificationRequestDto(
          key: '',
          sourceUrl: '',
          sourceName: '',
          imageUrl: '',
          title: '',
          useBrowser: false,
          createdAtMs: BigInt.zero,
        ),
      ),
    );
    when(
      () => bridge.crateFfiFfiWebviewRequestStream(
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        WebViewRequestDto(
          headers: const {},
          key: '',
          action: '',
          html: '',
          url: '',
          js: '',
          sourceRegex: '',
          overrideUrlRegex: '',
          cacheFirst: false,
          delayTime: 0,
          isRule: false,
          result: '',
          sourceKey: '',
          cookie: '',
          createdAtMs: BigInt.zero,
        ),
      ),
    );
    await expectLater(
      verification.verificationRequestStream().toList(),
      throwsFormatException,
    );
    await expectLater(
      web.webviewRequestStream().toList(),
      throwsFormatException,
    );
  });
  test('Cookie清除走原共享网络入口，原生异常保持', () async {
    const network = RustNetworkService();
    when(() => bridge.crateFfiFfiClearCookie(url: 'https://source.test/path'))
        .thenAnswer((_) async {});
    await network.clearCookie('https://source.test/path');
    verify(() => bridge.crateFfiFfiClearCookie(url: 'https://source.test/path'))
        .called(1);
  });
  test('平台执行器映射全部载荷，并把Cookie回流转为类型化数据', () async {
    final payloads = <Map<String, dynamic>>[];
    final executor = NativeWebViewRequestExecutor(
      dispatch: (payload) async {
        payloads.add(payload);
        return const WebViewEvalOutcome('output', '{"source.test":"sid=new"}');
      },
    );
    final result = await executor.execute(
      const WebViewRequest(
        key: 'w',
        action: 'webViewGetOverrideUrl',
        html: 'html',
        url: 'url',
        js: 'js',
        sourceRegex: 's',
        overrideUrlRegex: 'o',
        cacheFirst: true,
        delayTime: 10,
        isRule: true,
        result: 'raw',
        sourceKey: 'source',
        cookie: 'sid=old',
      ),
    );
    expect(payloads.single, {
      'key': 'w',
      'headers': <String, String>{},
      'action': 'webViewGetOverrideUrl',
      'html': 'html',
      'url': 'url',
      'js': 'js',
      'sourceRegex': 's',
      'overrideUrlRegex': 'o',
      'cacheFirst': true,
      'delayTime': 10,
      'isRule': true,
      'result': 'raw',
      'sourceKey': 'source',
      'cookie': 'sid=old',
    });
    expect(result.result, 'output');
    expect(result.cookies, {'source.test': 'sid=new'});
  });
  test('平台坏Cookie不能当作成功回流', () async {
    final executor = NativeWebViewRequestExecutor(
      dispatch: (_) async => const WebViewEvalOutcome('out', '[]'),
    );
    await expectLater(
      executor.execute(const WebViewRequest(key: 'w')),
      throwsFormatException,
    );
  });
}
