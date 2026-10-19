// 真实Android WebView、正式FRB与本地HTTP；不依赖线上书源或用户数据库。— Codex + Bridge
// 运行时必须保留应用：flutter test --no-uninstall integration_test/webview_cookie_order_test.dart -d <实时设备号>
// Flutter test默认会卸载同包应用；共享设备须先保存数据，测试只访问新建的临时数据库。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/services/rust_webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/platform/native_webview_request_executor.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const service = RustWebViewBridgeService();
  late HttpServer server;
  late Directory directory;
  late String base;
  late NativeWebViewRequestExecutor executor;
  String? activeKey;
  Completer<void>? hanging;

  setUpAll(() async {
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    directory = await Directory.systemTemp.createTemp('webview-cookie-order-');
    await runtime.openDatabase('${directory.path}/qa.db');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      if (request.uri.path == '/hang') {
        hanging?.complete();
        return;
      }
      if (request.uri.path == '/redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('Location', '$base/final');
      } else if (request.uri.path == '/final') {
        request.response.headers.contentType = ContentType.html;
        request.response.headers.add(
          'Set-Cookie',
          'redirected=yes; Path=/; HttpOnly',
        );
        request.response.write('<html><body>final</body></html>');
      } else {
        request.response.headers.contentType = ContentType.text;
        request.response.headers.add('Set-Cookie', 'session=rust; Path=/');
        request.response.write(request.headers.value('cookie') ?? '');
      }
      await request.response.close();
    });
    executor = NativeWebViewRequestExecutor(
      dispatch: PlatformBridgeService.instance.dispatchPayloadWithCookies,
      cancel: PlatformBridgeService.instance.cancelWebView,
      pageCall: service.pageCall,
      syncCookies: service.syncCookies,
    );
  });
  tearDownAll(() async {
    await server.close(force: true);
  });

  Future<WebViewExecutionResult> runPage(
    String html,
    String url,
    String js,
  ) async {
    debugPrint('阶段：准备请求');
    activeKey = null;
    final handled = Completer<WebViewExecutionResult>();
    // 立即消费失败，避免平台先报错、Rust父调用稍后返回形成未处理异步错误。
    final guarded = handled.future.then(
      (v) => v,
      onError: (Object e) =>
          WebViewExecutionResult(result: '', error: e.toString()),
    );
    final subscription = service.webviewRequestStream().listen((request) async {
      if (request.action == 'cancel') {
        await executor.cancel(request.key);
        return;
      }
      debugPrint('阶段：收到平台请求 ${request.action}');
      activeKey = request.key;
      try {
        final value = await executor.execute(request);
        debugPrint('阶段：平台执行完成');
        if (!await service.completeWebviewRequest(request.key, value)) {
          throw StateError('请求已取消');
        }
        handled.complete(value);
      } catch (e) {
        if (!handled.isCompleted) handled.completeError(e);
        await service.cancelWebviewRequest(request.key);
      }
    });
    try {
      final source = BookSource(
        bookSourceUrl: base,
        bookSourceName: '本地验证',
        enabledCookieJar: true,
        loginUi: '{"version":2}',
        loginUrl:
            'function loginUi(state){return {rows:[{name:java.webView(${jsonEncode(html)},${jsonEncode(url)},${jsonEncode(js)}),type:"text"}]};}',
      );
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      do {
        debugPrint('阶段：调用Rust来源动作');
        await bridge
            .sourceLoginUiV2(source: bookSourceToDto(source), stateJson: '{}')
            .timeout(const Duration(seconds: 15));
        debugPrint('阶段：Rust来源动作返回');
        if (activeKey != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (DateTime.now().isBefore(deadline));
      final value = await guarded.timeout(const Duration(seconds: 10));
      if (value.error != null) throw StateError(value.error!);
      return value;
    } finally {
      await subscription.cancel();
      final key = activeKey;
      if (key != null) {
        await service.cancelWebviewRequest(key);
        await executor.cancel(key);
      }
    }
  }

  testWidgets('加载Cookie在页内ajax前同步，完成不覆盖Rust响应的新值', (tester) async {
    debugPrint('阶段：创建测试根节点');
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    debugPrint('阶段：测试根节点已创建');
    final url = '$base/echo,{"headers":{"CookieJar":"1"}}';
    final value = await runPage(
      '<html><script>document.cookie="session=page; path=/";</script></html>',
      '$base/start',
      'java.ajax(${jsonEncode(url)})',
    );
    expect(value.result, contains('session=page'));
    expect(
      await bridge.jsEval(script: 'java.getCookie(${jsonEncode(base)})'),
      contains('session=rust'),
    );
    expect(
      await service.syncCookies(activeKey!, {base: 'session=late'}),
      isFalse,
    );
  });

  testWidgets('重定向使用最终地址Cookie，包含原生可读的HttpOnly值', (tester) async {
    final value = await runPage(
      '<html><script>location.replace("$base/redirect")</script></html>',
      '$base/start',
      'java.ajax(${jsonEncode('$base/echo')})',
    );
    expect(value.finalUrl, '$base/final');
    expect(value.result, contains('redirected=yes'));
  });

  testWidgets('取消正在等待的prompt后停止执行且新请求仍可执行', (tester) async {
    hanging = Completer<void>();
    final pending = runPage(
      '<html>waiting</html>',
      '$base/start',
      'java.ajax(${jsonEncode('$base/hang')})',
    );
    final rejected = expectLater(pending, throwsA(anything));
    await hanging!.future.timeout(const Duration(seconds: 10));
    await service.cancelWebviewRequest(activeKey!);
    await executor.cancel(activeKey!);
    await rejected;
    hanging = null;
    final next = await runPage('<html>next</html>', '$base/start', '"next"');
    expect(next.result, 'next');
  });
}
