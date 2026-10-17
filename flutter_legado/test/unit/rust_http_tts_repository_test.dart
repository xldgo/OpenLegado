import 'dart:convert';

import 'package:flutter_legado/src/data/bridge/media_dto_mapping.dart';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_http_tts_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const repository = RustHttpTtsRepository();
  late _Bridge bridge;
  setUpAll(() => registerFallbackValue(httpTtsToDto(const HttpTts())));
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
        .thenAnswer((_) async => [httpTtsToDto(row)]);
    expect(await repository.getHttpTts(), [row]);
    expect(jsonDecode(await repository.exportHttpTts()), [row.toJson()]);
    when(() => bridge.crateFfiFfiHttpTtsList()).thenAnswer((_) async => []);
    expect(await repository.getHttpTts(), isEmpty);
    verify(() => bridge.crateFfiFfiHttpTtsList()).called(3);
    verifyNoMoreInteractions(bridge);
  });

  test('新增传递完整 HttpTts DTO（含并发 clamp），结果保留输入字段并采用原生 ID', () async {
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
      () => bridge.crateFfiFfiHttpTtsAdd(tts: httpTtsToDto(expectedNormalized)),
    ).thenAnswer((_) async => 17);
    expect(
      await repository.addHttpTts(input),
      expectedNormalized.copyWith(id: 17),
    );
    verify(
      () => bridge.crateFfiFfiHttpTtsAdd(tts: httpTtsToDto(expectedNormalized)),
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
    final payload = httpTtsToDto(row);
    when(() => bridge.crateFfiFfiHttpTtsUpdate(tts: payload))
        .thenAnswer((_) async => true);
    await repository.updateHttpTts(row);

    when(() => bridge.crateFfiFfiHttpTtsUpdate(tts: payload))
        .thenAnswer((_) async => false);
    await expectLater(repository.updateHttpTts(row), throwsStateError);

    when(() => bridge.crateFfiFfiHttpTtsDelete(id: 17))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .thenAnswer((_) async => false);
    await repository.deleteHttpTts(row.id);
    expect(await repository.httpTtsSetEnabled(row.id, false), isFalse);
    verify(() => bridge.crateFfiFfiHttpTtsUpdate(tts: payload)).called(2);
    verify(() => bridge.crateFfiFfiHttpTtsDelete(id: 17)).called(1);
    verify(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('文档导入完整透传给原生解析器，保留数组loginUi与内嵌目录', () async {
    const doc =
        '[{"id":-29,"name":"甲","url":"http://a","loginUi":[{"name":"Key"}],"speakersJson":"[]","emotionsJson":"[]"},{"name":""}]';
    when(() => bridge.crateFfiFfiHttpTtsImport(document: doc))
        .thenAnswer((_) async => 1);
    expect(await repository.importHttpTts(doc), 1);
    verify(() => bridge.crateFfiFfiHttpTtsImport(document: doc)).called(1);
    verifyNoMoreInteractions(bridge);
  });
  test('列表、保存、更新、文档导入与删除错误原样上抛', () async {
    final failure = StateError('数据库失败');
    when(() => bridge.crateFfiFfiHttpTtsList()).thenThrow(failure);
    when(() => bridge.crateFfiFfiHttpTtsAdd(tts: any(named: 'tts')))
        .thenThrow(failure);
    when(() => bridge.crateFfiFfiHttpTtsUpdate(tts: any(named: 'tts')))
        .thenThrow(failure);
    when(() => bridge.crateFfiFfiHttpTtsDelete(id: 17)).thenThrow(failure);
    when(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .thenThrow(failure);
    when(() => bridge.crateFfiFfiHttpTtsImport(document: 'bad'))
        .thenThrow(failure);
    for (final call in <Future<Object?> Function()>[
      repository.getHttpTts,
      repository.exportHttpTts,
      () => repository.addHttpTts(const HttpTts()),
      () => repository.updateHttpTts(const HttpTts()),
      () => repository.deleteHttpTts(17),
      () => repository.httpTtsSetEnabled(17, false),
      () => repository.importHttpTts('bad'),
    ]) {
      await expectLater(Future<Object?>.sync(call), throwsA(same(failure)));
    }
  });
  test('普通保存拒绝有符号范围溢出，音色目录等协议字符串不改写', () {
    expect(
      () => httpTtsToDto(const HttpTts(pauseDuration: 2147483648)),
      throwsRangeError,
    );
    expect(
      () => httpTtsToDto(const HttpTts(speed: -2147483649)),
      throwsRangeError,
    );
    final value = httpTtsToDto(
      const HttpTts(header: '{}', loginUi: '[]', synthesisThreadCount: 99),
    );
    expect(value.header, '{}');
    expect(value.loginUi, '[]');
    expect(value.synthesisThreadCount, 8);
  });
}
