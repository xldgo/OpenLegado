// 真实Android资源/导航回调；只使用本地HTTP，不访问用户数据库。— Codex + Bridge
// 必须使用flutter test --no-uninstall运行，结束后恢复普通应用入口。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';
import 'package:flutter_legado/src/services/platform_channel.dart';
import 'package:flutter_legado/src/platform/webview_page_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final service = PlatformBridgeService.instance;
  late HttpServer server;
  late String base;
  var sequence = 0;
  final requests = <String>[];
  final active = <String>{};
  Completer<void>? ready;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      if (request.uri.path == '/decoy' || request.uri.path == '/initial') {
        request.response.write(
          '<html><script>setTimeout(function(){location.href="$base/target"},100)</script></html>',
        );
      } else {
        request.response.write('<html>resource</html>');
      }
      await request.response.close();
      if (request.uri.path == '/ready' && ready?.isCompleted == false) {
        ready!.complete();
      }
    });
  });
  tearDown(() async {
    for (final key in active.toList()) {
      await service.cancelWebView(key);
    }
    active.clear();
    requests.clear();
  });
  tearDownAll(() async => server.close(force: true));

  Future<WebViewEvalOutcome> run({
    required String action,
    required String pattern,
    String? html,
    String? url,
    String js = '',
    String? key,
    WebViewCookieBridge? cookieBridge,
  }) async {
    key ??= 'sniffer-${sequence++}';
    active.add(key);
    try {
      return await service
          .dispatchPayloadWithCookies({
            'key': key,
            'action': action,
            'url': url ?? '$base/page',
            'html': html ?? '<html>local</html>',
            'js': js,
            'sourceRegex': pattern,
            'overrideUrlRegex': pattern,
            'cookieBridge': cookieBridge,
          })
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('本地HTTP实际路径：$requests');
      rethrow;
    } finally {
      await service.cancelWebView(key);
      active.remove(key);
    }
  }

  String resourceAfter(String path, int milliseconds) =>
      'setTimeout(function(){fetch(${jsonEncode('$base$path')})},$milliseconds);';

  testWidgets('持续等待延迟资源，结果地址与所属页面地址分开', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    final value = await run(
      action: 'webViewGetSource',
      pattern: '${RegExp.escape(base)}/late',
      js: resourceAfter('/late', 1600),
    );
    expect(value.result, '$base/late');
    expect(value.finalUrl, '$base/page');
  });

  testWidgets('不把未点击的链接当作加载资源', (tester) async {
    final value = await run(
      action: 'webViewGetSource',
      pattern: '${RegExp.escape(base)}/(?:never|real)',
      html: '<html><a href="$base/never">未加载</a></html>',
      js: resourceAfter('/real', 1600),
    );
    expect(value.result, '$base/real');
    expect(requests, isNot(contains('/never')));
  });

  testWidgets('资源按整串匹配，拒绝URL中的子串', (tester) async {
    final value = await run(
      action: 'webViewGetSource',
      pattern: '${RegExp.escape(base)}/asset',
      js: 'fetch(${jsonEncode('$base/decoy-resource?next=$base/asset')});${resourceAfter('/asset', 1600)}',
    );
    expect(value.result, '$base/asset');
  });

  testWidgets('跳转按整串匹配，命中导航被阻止且不误认初始URL', (tester) async {
    final value = await run(
      action: 'webViewGetOverrideUrl',
      pattern: '${RegExp.escape(base)}/target',
      js: 'location.href=${jsonEncode('$base/decoy?next=$base/target')}',
    );
    expect(value.result, '$base/target');
    expect(requests, contains('/decoy'));
    expect(requests, isNot(contains('/target')));

    final initial = await run(
      action: 'webViewGetOverrideUrl',
      pattern: '${RegExp.escape(base)}/(?:initial|target)',
      url: '$base/initial',
      html: '',
    );
    expect(initial.result, '$base/target');
    expect(requests, contains('/initial'));
  });

  testWidgets('取消嗅探后迟到资源不继续执行，新请求可用', (tester) async {
    ready = Completer<void>();
    const key = 'sniffer-cancel';
    final pending = run(
      key: key,
      action: 'webViewGetSource',
      pattern: '${RegExp.escape(base)}/cancelled',
      js: 'fetch(${jsonEncode('$base/ready')});${resourceAfter('/cancelled', 2000)}',
    );
    final rejected = expectLater(pending, throwsA(anything));
    await ready!.future.timeout(const Duration(seconds: 3));
    await service.cancelWebView(key);
    await rejected;
    ready = null;
    final next = await run(
      action: 'webViewGetSource',
      pattern: '${RegExp.escape(base)}/next',
      js: resourceAfter('/next', 100),
    );
    expect(next.result, '$base/next');
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(requests, isNot(contains('/cancelled')));
  });

  testWidgets('空资源规则保留空结果而非等待超时', (tester) async {
    final value = await run(action: 'webViewGetSource', pattern: '');
    expect(value.result, isEmpty);
  });

  testWidgets('坏正则报告失败而非原生崩溃', (tester) async {
    await expectLater(
      run(action: 'webViewGetSource', pattern: '['),
      throwsA(isA<PlatformException>()),
    );
  });

  group('Flutter公开接口回退', () {
    setUp(() {
      // 只模拟原生Backstage入口不可用；webview_flutter仍使用实际Android插件。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformChannel.webview, (_) async {
            throw MissingPluginException();
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformChannel.webview, null);
    });
    testWidgets('实际performance记录支持延迟资源，不扫描DOM链接或误匹配子串', (tester) async {
      // performance只观察已完成的资源；显式消费响应体，不把流式fetch当原生事件。
      final snapshots = <Map<String, String>>[];
      final value = await run(
        action: 'webViewGetSource',
        pattern: '${RegExp.escape(base)}/(?:never|fallback)',
        cookieBridge: WebViewCookieBridge((snapshot) async {
          snapshots.add(snapshot);
          return true;
        }),
        html:
            '<html><script>document.cookie="observed=yes; path=/";</script><a href="$base/never">未点击</a></html>',
        js: 'fetch(${jsonEncode('$base/decoy-resource?next=$base/fallback')}).then(function(r){return r.text();});setTimeout(function(){fetch(${jsonEncode('$base/fallback')}).then(function(r){return r.text();});},1600);',
      );
      expect(value.result, '$base/fallback');
      expect(snapshots.single['$base/page'], contains('observed=yes'));
      expect(value.finalUrl, '$base/page');
      expect(requests, isNot(contains('/never')));
    });
    testWidgets('实际导航回调允许初始地址加载，捕获后续跳转', (tester) async {
      final value = await run(
        action: 'webViewGetOverrideUrl',
        pattern: '${RegExp.escape(base)}/(?:initial|target)',
        url: '$base/initial',
        html: '',
      );
      expect(value.result, '$base/target');
      expect(requests, contains('/initial'));
      expect(requests, isNot(contains('/target')));
    });
  });
}
