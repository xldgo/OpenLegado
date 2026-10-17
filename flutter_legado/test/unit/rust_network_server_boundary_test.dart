import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/file_dto.dart';

import 'package:flutter_legado/src/bridge/content_dto.dart';

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
  test('GET与POST直接返回状态、中文正文和最终URL，不改写请求体', () async {
    when(() => bridge.crateFfiFfiHttpGet(url: 'https://old.test')).thenAnswer(
      (_) async => const HttpTextResponseDto(
        status: 404,
        body: '未找到',
        url: 'https://final.test',
      ),
    );
    when(
      () => bridge.crateFfiFfiHttpPost(url: 'https://post.test', body: 'a=中文'),
    ).thenAnswer(
      (_) async => const HttpTextResponseDto(
        status: 201,
        body: '已保存',
        url: 'https://post.test',
      ),
    );
    final get = await network.httpGet('https://old.test');
    expect(get.statusCode, 404);
    expect(get.body, '未找到');
    expect(get.url, 'https://final.test');
    expect(get.isSuccess, false);
    final post = await network.httpPost('https://post.test', 'a=中文');
    expect(post.isSuccess, true);
    expect(post.body, '已保存');
    verify(
      () => bridge.crateFfiFfiHttpPost(url: 'https://post.test', body: 'a=中文'),
    ).called(1);
  });
  test('请求头直接传映射，完整字节域与空正文不经base64', () async {
    final bytes = Uint8List.fromList(List.generate(256, (i) => i));
    when(
      () => bridge.crateFfiFfiHttpGetBytes(
        url: 'image',
        headers: {'Referer': 'book'},
      ),
    ).thenAnswer(
      (_) async => HttpBytesResponseDto(status: 200, bytes: bytes, url: 'cdn'),
    );
    final reply = await network.httpGetBytes(
      'image',
      headers: {'Referer': 'book'},
    );
    expect(reply.bytes, bytes);
    expect(reply.url, 'cdn');
    expect(reply.isSuccess, true);
    when(
      () => bridge.crateFfiFfiHttpGetBytes(url: 'empty', headers: null),
    ).thenAnswer(
      (_) async =>
          HttpBytesResponseDto(status: 204, bytes: Uint8List(0), url: 'empty'),
    );
    for (final headers in [null, <String, String>{}]) {
      expect(
        (await network.httpGetBytes('empty', headers: headers)).bytes,
        isEmpty,
      );
    }
    verify(() => bridge.crateFfiFfiHttpGetBytes(url: 'empty', headers: null))
        .called(2);
  });
  test('超时不隐式重试，迟到响应不改变结果', () async {
    final pending = Completer<HttpTextResponseDto>();
    when(() => bridge.crateFfiFfiHttpGet(url: 'slow'))
        .thenAnswer((_) => pending.future);
    await expectLater(
      network.httpGet('slow', timeout: const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete(
      const HttpTextResponseDto(status: 200, body: '迟到', url: 'slow'),
    );
    verify(() => bridge.crateFfiFfiHttpGet(url: 'slow')).called(1);
  });
  test('文本与字节异常均向上传递，hosts保持原协议', () async {
    final error = StateError('网络失败');
    when(() => bridge.crateFfiFfiHttpGet(url: 'u')).thenThrow(error);
    when(() => bridge.crateFfiFfiHttpGetBytes(url: 'u', headers: null))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiSetCustomHosts(hostsJson: '{}'))
        .thenThrow(error);
    await expectLater(network.httpGet('u'), throwsA(same(error)));
    await expectLater(network.httpGetBytes('u'), throwsA(same(error)));
    await expectLater(() => network.setCustomHosts('{}'), throwsA(same(error)));
  });
  test('服务控制保持端口和调用次数，状态使用真实字段', () async {
    when(() => bridge.crateFfiFfiServerStart(port: 4321))
        .thenAnswer((_) async => 'started');
    when(() => bridge.crateFfiFfiServerStop())
        .thenAnswer((_) async => 'stopped');
    when(
      () => bridge.crateFfiFfiServerStatus(),
    ).thenAnswer((_) async => const ServerStatusDto(running: true, port: 4321));
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
  test('服务状态读取失败不冒充stopped', () async {
    final error = StateError('状态读取失败');
    when(() => bridge.crateFfiFfiServerStatus()).thenThrow(error);
    await expectLater(server.getServerStatus(), throwsA(same(error)));
  });
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
