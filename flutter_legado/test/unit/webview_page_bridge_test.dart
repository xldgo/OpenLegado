import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';
import 'package:flutter_legado/src/platform/webview_page_bridge.dart';

void main() {
  test('Cookie同步严格校验映射、等待确认，失败保持失败', () async {
    final seen = <Map<String, String>>[];
    final bridge = WebViewCookieBridge((cookies) async {
      seen.add(cookies);
      return true;
    });
    await bridge.sync({'https://page.test/': 'session=page'});
    expect(seen.single, {'https://page.test/': 'session=page'});
    for (final bad in [
      null,
      [],
      {1: 'v'},
      {'url': 1},
    ]) {
      await expectLater(bridge.sync(bad), throwsFormatException);
    }
    expect(seen, hasLength(1));
    await expectLater(
      WebViewCookieBridge((_) async => false).sync({}),
      throwsStateError,
    );
    await expectLater(
      WebViewCookieBridge((_) async => throw StateError('持久化失败')).sync({}),
      throwsStateError,
    );
  });
  test('两路页内信封保留目标、null参数与真实JSON结果', () async {
    final calls = <WebViewPageCall>[];
    final bridge = WebViewPageBridge((call) async {
      calls.add(call);
      return 'null';
    });
    expect(
      jsonDecode(
        await bridge.invoke(
          jsonEncode({
            'target': 'source',
            'method': 'putVariable',
            'args': [null],
          }),
        ),
      ),
      {'value': null},
    );
    expect(calls.single.target, WebViewPageTarget.source);
    expect(calls.single.method, 'putVariable');
    expect(calls.single.args, [null]);
    final response = WebViewPageBridge((_) async => '["中文",false,{}]');
    expect(
      jsonDecode(
        await response.invoke(
          '{"target":"java","method":"getStringList","args":["p@text"]}',
        ),
      ),
      {
        'value': ['中文', false, {}],
      },
    );
  });
  test('坏参数在调用Rust前拒绝，不接受额外来源或请求key', () async {
    var count = 0;
    final bridge = WebViewPageBridge((_) async {
      count++;
      return '""';
    });
    for (final value in [
      null,
      {},
      {
        'target': 'source',
        'method': 'get',
        'args': [1],
      },
      {'target': 'other', 'method': 'get', 'args': []},
      {'target': 'source', 'method': 'get', 'args': [], 'key': 'other'},
      {'target': 'source', 'method': ' ', 'args': []},
    ]) {
      expect(
        jsonDecode(await bridge.invoke(jsonEncode(value))),
        contains('error'),
      );
    }
    expect(count, 0);
  });
  test('正常空值与错误分开，坏JSON结果不能伪装成功', () async {
    for (final output in ['""', 'null', 'false']) {
      final bridge = WebViewPageBridge((_) async => output);
      expect(
        jsonDecode(
          await bridge.invoke('{"target":"cache","method":"get","args":["a"]}'),
        ),
        {'value': jsonDecode(output)},
      );
    }
    final failed = WebViewPageBridge((_) async => throw StateError('请求已取消'));
    final error = jsonDecode(
      await failed.invoke('{"target":"cache","method":"get","args":["a"]}'),
    ) as Map;
    expect(error['error'], contains('请求已取消'));
    expect(error, isNot(contains('value')));
    final bad = WebViewPageBridge((_) async => '不是JSON');
    expect(
      jsonDecode(
        await bad.invoke('{"target":"cache","method":"get","args":["a"]}'),
      ),
      contains('error'),
    );
  });
}
