import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_http_tts_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const repository = RustHttpTtsRepository();
  late _Bridge bridge;
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('列表与导出保持裸数组、完整 camelCase 字段，不缓存查询', () async {
    const row = HttpTts(
      id: 17,
      name: '测试',
      url: 'http://a',
      contentType: 'audio/wav',
      pauseDuration: 120,
      concurrentRate: '1500',
      loginUrl: 'function login(){}',
      loginUi: '[{"name":"AppKey","type":"text"}]',
      header: '{"Authorization":"Bearer token"}',
      jsLib: 'var v = 1;',
      enabledCookieJar: true,
      loginCheckJs: 'result',
      speed: 15,
      synthesisThreadCount: 4,
      lastUpdateTime: 1700000001234,
      isEnabled: false,
    );
    when(() => bridge.crateFfiFfiHttpTtsList())
        .thenAnswer((_) async => jsonEncode([row.toJson()]));
    expect(await repository.getHttpTts(), [row]);
    expect(jsonDecode(await repository.exportHttpTts()), [row.toJson()]);
    when(() => bridge.crateFfiFfiHttpTtsList()).thenAnswer((_) async => '[]');
    expect(await repository.getHttpTts(), isEmpty);
    verify(() => bridge.crateFfiFfiHttpTtsList()).called(3);
    verifyNoMoreInteractions(bridge);
  });

  test('新增传递完整 HttpTts JSON（含并发 clamp），结果保留输入字段并采用原生 ID', () async {
    const input = HttpTts(
      id: -5,
      name: '测试',
      url: 'http://a',
      contentType: 'audio/wav',
      pauseDuration: 200,
      concurrentRate: '1000',
      loginUrl: 'function login(){}',
      loginUi: '[{"name":"Key"}]',
      header: '{"X-Test":"1"}',
      jsLib: 'var a = 2;',
      enabledCookieJar: true,
      loginCheckJs: 'result',
      speed: 20,
      synthesisThreadCount: 15,
      lastUpdateTime: 1700000000000,
      isEnabled: false,
    );
    final expectedNormalized = input.copyWith(synthesisThreadCount: 8);
    when(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: jsonEncode(expectedNormalized.toJson()),
      ),
    ).thenAnswer((_) async => 17);
    expect(
      await repository.addHttpTts(input),
      expectedNormalized.copyWith(id: 17),
    );
    verify(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: jsonEncode(expectedNormalized.toJson()),
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('原地更新成功返回 void；目标不存在返回 false 时抛 StateError，不伪装成功', () async {
    const row = HttpTts(
      id: 17,
      name: '修改',
      url: 'http://b',
      header: '{"X":"Y"}',
      speed: 12,
      synthesisThreadCount: 3,
    );
    final payload = jsonEncode(row.toJson());
    when(() => bridge.crateFfiFfiHttpTtsUpdate(httpTtsJson: payload))
        .thenAnswer((_) async => true);
    await repository.updateHttpTts(row);

    when(() => bridge.crateFfiFfiHttpTtsUpdate(httpTtsJson: payload))
        .thenAnswer((_) async => false);
    await expectLater(repository.updateHttpTts(row), throwsStateError);

    when(() => bridge.crateFfiFfiHttpTtsDelete(id: 17))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .thenAnswer((_) async => false);
    await repository.deleteHttpTts(row.id);
    expect(await repository.httpTtsSetEnabled(row.id, false), isFalse);
    verify(() => bridge.crateFfiFfiHttpTtsUpdate(httpTtsJson: payload))
        .called(2);
    verify(() => bridge.crateFfiFfiHttpTtsDelete(id: 17)).called(1);
    verify(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('导入完整保留全字段及数组 loginUi，跳过缺 name/url 条目', () async {
    final payloads = <Map<String, dynamic>>[];
    when(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: any(named: 'httpTtsJson'),
      ),
    ).thenAnswer((invocation) async {
      final jsonStr = invocation.namedArguments[#httpTtsJson] as String;
      payloads.add(jsonDecode(jsonStr) as Map<String, dynamic>);
      return payloads.length;
    });

    final count = await repository.importHttpTts(
      jsonEncode([
        {
          'id': -29,
          'name': '甲',
          'url': 'http://a',
          'contentType': 'audio/mpeg',
          'loginUi': [
            {'name': 'AppKey', 'type': 'text'},
          ],
          'header': '{"Auth":"1"}',
          'speed': 10,
          'synthesisThreadCount': 99,
          'pauseDuration': 80,
          'isEnabled': false,
        },
        {'name': ''},
        {'url': 'http://skip'},
        {'name': ' 乙 ', 'url': 'http://b'},
      ]),
    );
    expect(count, 2);
    expect(payloads[0]['id'], -29);
    expect(payloads[0]['name'], '甲');
    expect(payloads[0]['loginUi'], '[{"name":"AppKey","type":"text"}]');
    expect(payloads[0]['header'], '{"Auth":"1"}');
    expect(payloads[0]['speed'], 10);
    expect(payloads[0]['synthesisThreadCount'], 8);
    expect(payloads[0]['pauseDuration'], 80);
    expect(payloads[0]['isEnabled'], false);
    expect(payloads[1]['name'], ' 乙 ');
    expect(payloads[1]['url'], 'http://b');
  });

  test('导入失败立即上抛，已完成写入不回滚，后续条目不执行', () async {
    final failure = StateError('写入失败');
    var calls = 0;
    when(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: any(named: 'httpTtsJson'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 2) throw failure;
      return calls;
    });
    await expectLater(
      repository.importHttpTts(
        '[{"name":"甲","url":"http://a"},{"name":"乙","url":"http://b"},{"name":"丙","url":"http://c"}]',
      ),
      throwsA(same(failure)),
    );
    expect(calls, 2);
    verify(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: any(named: 'httpTtsJson'),
      ),
    ).called(2);
    verifyNoMoreInteractions(bridge);
  });

  for (final json in ['{}', '{"data":[]}', 'null', '不是 JSON']) {
    test('查询与导入拒绝非裸数组：$json', () async {
      when(() => bridge.crateFfiFfiHttpTtsList()).thenAnswer((_) async => json);
      await expectLater(repository.getHttpTts(), throwsFormatException);
      await expectLater(repository.importHttpTts(json), throwsFormatException);
    });
  }

  test('底层失败原样上抛，不以空列表或成功覆盖', () async {
    final failure = StateError('数据库失败');
    when(() => bridge.crateFfiFfiHttpTtsList())
        .thenAnswer((_) async => throw failure);
    when(
      () => bridge.crateFfiFfiHttpTtsAdd(
        httpTtsJson: any(named: 'httpTtsJson'),
      ),
    ).thenAnswer((_) async => throw failure);
    when(
      () => bridge.crateFfiFfiHttpTtsUpdate(
        httpTtsJson: any(named: 'httpTtsJson'),
      ),
    ).thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiHttpTtsDelete(id: 17))
        .thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .thenAnswer((_) async => throw failure);
    const row = HttpTts(id: 17, name: '甲', url: 'http://a');
    for (final invoke in <Future<Object?> Function()>[
      repository.getHttpTts,
      repository.exportHttpTts,
      () => repository.addHttpTts(row),
      () => repository.updateHttpTts(row),
      () => repository.deleteHttpTts(17),
      () => repository.httpTtsSetEnabled(17, false),
      () => repository.importHttpTts('[{"name":"甲","url":"http://a"}]'),
    ]) {
      await expectLater(invoke(), throwsA(same(failure)));
    }
  });
}
