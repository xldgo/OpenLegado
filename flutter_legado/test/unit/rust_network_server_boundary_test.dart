import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_network_service.dart';
import 'package:flutter_legado/src/data/services/rust_local_server_service.dart';
import 'package:flutter_legado/src/data/services/rust_rule_execution_service.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const network = RustNetworkService();
  const server = RustLocalServerService();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('GET与POST保留状态、中文正文和重定向URL，POST不改写请求体', () async {
    when(() => bridge.crateFfiFfiHttpGet(url: 'https://old.test')).thenAnswer(
      (_) async => '{"status":404,"body":"未找到","url":"https://final.test"}',
    );
    when(
      () => bridge.crateFfiFfiHttpPost(url: 'https://post.test', body: 'a=中文'),
    ).thenAnswer(
      (_) async => '{"status":201,"body":"已保存","url":"https://post.test"}',
    );
    final get = await network.httpGet('https://old.test');
    expect(get.statusCode, 404);
    expect(get.body, '未找到');
    expect(get.url, 'https://final.test');
    expect(get.isSuccess, isFalse);
    final post = await network.httpPost('https://post.test', 'a=中文');
    expect(post.isSuccess, isTrue);
    expect(post.body, '已保存');
    verify(
      () => bridge.crateFfiFfiHttpPost(url: 'https://post.test', body: 'a=中文'),
    ).called(1);
  });

  test('二进制请求头只在适配器编码，原始字节及响应URL不丢失', () async {
    when(
      () => bridge.crateFfiFfiHttpGetBytes(
        url: 'https://image.test',
        headersJson: '{"Referer":"https://book.test"}',
      ),
    ).thenAnswer(
      (_) async => jsonEncode({
        'status': 200,
        'bodyBase64': base64Encode([0, 128, 255]),
        'url': 'https://cdn.test',
      }),
    );
    final result = await network.httpGetBytes(
      'https://image.test',
      headers: {'Referer': 'https://book.test'},
    );
    expect(result.bytes, [0, 128, 255]);
    expect(result.url, 'https://cdn.test');
    expect(result.isSuccess, isTrue);
  });

  test('空请求头保持空串；合法空正文可返回，缺URL保留请求地址', () async {
    when(() => bridge.crateFfiFfiHttpGetBytes(url: 'u', headersJson: ''))
        .thenAnswer((_) async => '{"status":204,"bodyBase64":""}');
    for (final headers in [null, <String, String>{}]) {
      final result = await network.httpGetBytes('u', headers: headers);
      expect(result.bytes, isEmpty);
      expect(result.statusCode, 204);
      expect(result.url, 'u');
    }
    verify(() => bridge.crateFfiFfiHttpGetBytes(url: 'u', headersJson: ''))
        .called(2);
  });

  for (final payload in [
    '[]',
    '{}',
    '{"status":200}',
    '{"status":"200","body":"x"}',
    '{"status":200,"body":null}',
    '{"status":200,"body":"x","url":3}',
  ]) {
    test('拒绝坏文本响应：$payload', () async {
      when(() => bridge.crateFfiFfiHttpGet(url: 'u'))
          .thenAnswer((_) async => payload);
      await expectLater(network.httpGet('u'), throwsFormatException);
    });
  }
  for (final payload in [
    '{}',
    '{"status":200}',
    '{"status":200,"bodyBase64":"%"}',
    '{"status":true,"bodyBase64":""}',
  ]) {
    test('拒绝坏二进制响应：$payload', () async {
      when(() => bridge.crateFfiFfiHttpGetBytes(url: 'u', headersJson: ''))
          .thenAnswer((_) async => payload);
      await expectLater(network.httpGetBytes('u'), throwsFormatException);
    });
  }
  test('显式超时生效，不发起额外重试请求', () async {
    final pending = Completer<String>();
    when(() => bridge.crateFfiFfiHttpGet(url: 'slow'))
        .thenAnswer((_) => pending.future);
    await expectLater(
      network.httpGet('slow', timeout: const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete('{"status":200,"body":"迟到"}');
    verify(() => bridge.crateFfiFfiHttpGet(url: 'slow')).called(1);
  });
  test('网络异常与hosts失败原样向上传递，不伪造空响应', () async {
    final error = StateError('共享客户端不可用');
    when(() => bridge.crateFfiFfiHttpGet(url: 'u')).thenThrow(error);
    when(() => bridge.crateFfiFfiSetCustomHosts(hostsJson: '{}'))
        .thenThrow(error);
    await expectLater(network.httpGet('u'), throwsA(same(error)));
    await expectLater(() => network.setCustomHosts('{}'), throwsA(same(error)));
    when(() => bridge.crateFfiFfiSetCustomHosts(hostsJson: ''))
        .thenAnswer((_) async {});
    await network.setCustomHosts('');
    verify(() => bridge.crateFfiFfiSetCustomHosts(hostsJson: '')).called(1);
  });

  test('服务控制保持端口和调用次数，状态使用真实字段', () async {
    when(() => bridge.crateFfiFfiServerStart(port: 4321))
        .thenAnswer((_) async => 'started');
    when(() => bridge.crateFfiFfiServerStop())
        .thenAnswer((_) async => 'stopped');
    when(() => bridge.crateFfiFfiServerStatus())
        .thenAnswer((_) async => '{"running":true,"port":4321}');
    when(() => bridge.crateFfiFfiConfigSet(key: 'server_port', value: '4321'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiSetMcpPort(port: 1236))
        .thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiSetMcpPort(port: 0)).thenAnswer((_) async {});
    await server.startServer(port: 4321);
    final status = await server.getServerStatus();
    expect(status.running, isTrue);
    expect(status.port, 4321);
    await server.setServerPort(4321);
    await server.setMcpPort(1236);
    await server.setMcpPort(0);
    await server.stopServer();
    verifyInOrder([
      () => bridge.crateFfiFfiServerStart(port: 4321),
      () => bridge.crateFfiFfiServerStatus(),
      () => bridge.crateFfiFfiConfigSet(key: 'server_port', value: '4321'),
      () => bridge.crateFfiFfiSetMcpPort(port: 1236),
      () => bridge.crateFfiFfiSetMcpPort(port: 0),
      () => bridge.crateFfiFfiServerStop(),
    ]);
  });
  for (final payload in [
    '[]',
    '{}',
    '{"running":"true","port":1122}',
    '{"running":false}',
  ]) {
    test('坏服务状态不冒充stopped：$payload', () async {
      when(() => bridge.crateFfiFfiServerStatus())
          .thenAnswer((_) async => payload);
      await expectLater(server.getServerStatus(), throwsFormatException);
    });
  }
  test('服务失败与端口写入拒绝不会伪装成功', () async {
    final error = StateError('端口已占用');
    when(() => bridge.crateFfiFfiServerStart(port: 1122)).thenThrow(error);
    when(() => bridge.crateFfiFfiServerStop()).thenThrow(error);
    when(() => bridge.crateFfiFfiSetMcpPort(port: 1236)).thenThrow(error);
    when(() => bridge.crateFfiFfiConfigSet(key: 'server_port', value: '4321'))
        .thenAnswer((_) async => false);
    await expectLater(server.startServer(), throwsA(same(error)));
    await expectLater(server.stopServer(), throwsA(same(error)));
    await expectLater(() => server.setMcpPort(1236), throwsA(same(error)));
    await expectLater(server.setServerPort(4321), throwsStateError);
  });

  test('脚本执行仍调用注入的平台拦截，规则参数原样透传', () async {
    final intercepted = <String>[];
    final service = RustRuleExecutionService(
      interceptResult: (raw) async {
        intercepted.add(raw);
        return '平台处理结果';
      },
    );
    when(() => bridge.crateFfiFfiJsEval(script: 'java.webView()'))
        .thenAnswer((_) async => '平台请求');
    when(
      () => bridge.crateFfiFfiParseRule(
        content: '<p>小说</p>',
        rule: 'p@text',
        ruleType: 'css',
      ),
    ).thenAnswer((_) async => '小说');
    expect(await service.evalJs('java.webView()'), '平台处理结果');
    expect(intercepted, ['平台请求']);
    expect(await service.parseRule('<p>小说</p>', 'p@text', 'css'), '小说');
  });
  test('JS错误不进入拦截，版本探测失败仍为unknown', () async {
    var intercepted = false;
    final service = RustRuleExecutionService(
      interceptResult: (raw) async {
        intercepted = true;
        return raw;
      },
    );
    final error = StateError('脚本错误');
    when(() => bridge.crateFfiFfiJsEval(script: any(named: 'script')))
        .thenThrow(error);
    await expectLater(service.evalJs('broken()'), throwsA(same(error)));
    expect(intercepted, isFalse);
    expect(await service.getJsEngineVersion(), 'unknown');
  });
}
