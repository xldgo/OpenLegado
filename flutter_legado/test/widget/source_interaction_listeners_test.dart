import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/verification_service.dart';
import 'package:flutter_legado/src/domain/contracts/webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/models/verification_request.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';
import 'package:flutter_legado/src/providers/source_interaction_provider.dart';
import 'package:flutter_legado/src/widgets/verification_code_listener.dart';
import 'package:flutter_legado/src/widgets/webview_bridge_listener.dart';

class _Verification implements VerificationService {
  final events = StreamController<VerificationRequest>(sync: true);
  final submitted = <(String, String)>[];
  final cancelled = <String>[];
  Object? submitError;
  @override
  Stream<VerificationRequest> verificationRequestStream() => events.stream;
  @override
  Future<bool> submitVerificationResult(String key, String code) async {
    if (submitError case final error?) throw error;
    submitted.add((key, code));
    return true;
  }

  @override
  Future<bool> cancelVerificationRequest(String key) async {
    cancelled.add(key);
    return true;
  }
}

class _Web implements WebViewBridgeService {
  final events = StreamController<WebViewRequest>(sync: true);
  final results = <(String, String, Map<String, String>)>[];
  final errors = <(String, String)>[];
  final cancelled = <String>[];
  @override
  Future<bool> completeWebviewRequest(
    String key,
    WebViewExecutionResult response,
  ) async {
    if (response.error case final error?) {
      errors.add((key, error));
    } else {
      results.add((key, response.result, response.cookies));
    }
    return true;
  }

  @override
  Stream<WebViewRequest> webviewRequestStream() => events.stream;
  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    Map<String, String> cookies,
  ) async {
    results.add((key, result, cookies));
    return true;
  }

  @override
  Future<bool> submitWebviewResult(String key, String result) async {
    errors.add((key, result));
    return true;
  }

  @override
  Future<bool> cancelWebviewRequest(String key) async {
    cancelled.add(key);
    return true;
  }
}

class _Executor implements WebViewRequestExecutor {
  final started = <String>[];
  final stopped = <String>[];
  @override
  Future<void> cancel(String key) async {
    stopped.add(key);
  }

  final pending = <String, Completer<WebViewExecutionResult>>{};
  @override
  Future<WebViewExecutionResult> execute(WebViewRequest request) {
    started.add(request.key);
    return (pending[request.key] = Completer<WebViewExecutionResult>()).future;
  }

  void complete(String key) => pending[key]!.complete(
    WebViewExecutionResult(
      result: 'result-$key',
      cookies: {'source.test': 'sid=$key'},
    ),
  );
}

void main() {
  testWidgets('WebView取消移除队列、停止在途页面且拒绝迟到成功', (tester) async {
    final web = _Web();
    final executor = _Executor();
    addTearDown(web.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webViewBridgeServiceProvider.overrideWithValue(web),
          webViewRequestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(
          home: WebViewBridgeListener(child: Scaffold()),
        ),
      ),
    );
    for (var i = 1; i <= 7; i++) {
      web.events.add(WebViewRequest(key: '$i'));
    }
    web.events.add(const WebViewRequest(key: '6', action: 'cancel'));
    web.events.add(const WebViewRequest(key: '1', action: 'cancel'));
    await tester.pump();
    expect(executor.stopped, ['1']);
    executor.complete('1');
    await tester.pump();
    expect(executor.started, ['1', '2', '3', '4', '5', '7']);
    expect(web.results, isEmpty);
    expect(web.errors, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(executor.stopped.toSet(), {'1', '2', '3', '4', '5', '7'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('WebView流关闭停止平台，不再提交迟到结果', (tester) async {
    final web = _Web();
    final executor = _Executor();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webViewBridgeServiceProvider.overrideWithValue(web),
          webViewRequestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(
          home: WebViewBridgeListener(child: Scaffold()),
        ),
      ),
    );
    web.events.add(const WebViewRequest(key: 'a'));
    unawaited(web.events.close());
    await tester.pump();
    expect(executor.stopped, ['a']);
    executor.complete('a');
    await tester.pump();
    expect(web.results, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('应用builder外层监听可弹验证码，回放去重并按FIFO提交/取消', (tester) async {
    final service = _Verification();
    addTearDown(service.events.close);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [verificationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) =>
              VerificationCodeListener(navigatorKey: key, child: child!),
          home: const Scaffold(body: Text('正文')),
        ),
      ),
    );
    service.events.add(const VerificationRequest(key: 'a', title: '第一项验证'));
    service.events.add(const VerificationRequest(key: 'a', title: '重复项'));
    service.events.add(const VerificationRequest(key: 'b', title: '第二项验证'));
    await tester.pumpAndSettle();
    expect(find.text('第一项验证'), findsOneWidget);
    expect(find.text('重复项'), findsNothing);
    await tester.enterText(find.byType(TextField), ' 1234 ');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(service.submitted, [('a', '1234')]);
    expect(find.text('第二项验证'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.cancelled, ['b']);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('验证码提交失败可重试；卸载取消展示与排队请求并释放订阅', (tester) async {
    final service = _Verification();
    addTearDown(service.events.close);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [verificationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) =>
              VerificationCodeListener(navigatorKey: key, child: child!),
          home: const Scaffold(),
        ),
      ),
    );
    service.events.addError(StateError('单条坏消息'));
    service.events.add(const VerificationRequest(key: 'a', title: '验证A'));
    service.events.add(const VerificationRequest(key: 'b', title: '验证B'));
    await tester.pumpAndSettle();
    service.submitError = StateError('提交失败');
    await tester.enterText(find.byType(TextField), 'code');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('验证码提交失败'), findsOneWidget);
    expect(find.text('验证A'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(service.cancelled.toSet(), {'a', 'b'});
    expect(service.events.hasListener, isFalse);
    expect(service.submitted, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('WebView保持五路并行/FIFO与Cookie回传，卸载不再执行队列', (tester) async {
    final web = _Web();
    final executor = _Executor();
    addTearDown(web.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webViewBridgeServiceProvider.overrideWithValue(web),
          webViewRequestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(
          home: WebViewBridgeListener(child: Scaffold()),
        ),
      ),
    );
    for (var i = 1; i <= 7; i++) {
      web.events.add(WebViewRequest(key: '$i'));
    }
    expect(executor.started, ['1', '2', '3', '4', '5']);
    executor.complete('1');
    await tester.pump();
    expect(executor.started, ['1', '2', '3', '4', '5', '6']);
    expect(web.results.single.$1, '1');
    expect(web.results.single.$2, 'result-1');
    expect(web.results.single.$3, {'source.test': 'sid=1'});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(web.cancelled.toSet(), {'2', '3', '4', '5', '6', '7'});
    expect(web.events.hasListener, isFalse);
    for (final k in ['2', '3', '4', '5', '6']) {
      executor.complete(k);
    }
    await tester.pump();
    expect(executor.started, hasLength(6));
    expect(web.results, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('WebView执行错误回传原请求并继续队列，单条流错误不终止订阅', (tester) async {
    final web = _Web();
    final executor = _Executor();
    addTearDown(web.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webViewBridgeServiceProvider.overrideWithValue(web),
          webViewRequestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(
          home: WebViewBridgeListener(child: Scaffold()),
        ),
      ),
    );
    web.events.addError(StateError('坏事件'));
    web.events.add(const WebViewRequest(key: 'bad'));
    executor.pending['bad']!.completeError(StateError('平台失败'));
    await tester.pump();
    expect(web.errors.single.$1, 'bad');
    expect(web.errors.single.$2, contains('平台失败'));
    web.events.add(const WebViewRequest(key: 'good'));
    executor.complete('good');
    await tester.pump();
    expect(web.results.single.$1, 'good');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
