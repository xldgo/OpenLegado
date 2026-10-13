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

  test('列表与导出保持裸数组、完整字段，不缓存查询', () async {
    const row = HttpTts(
      id: 17,
      name: '测试',
      url: 'http://a',
      contentType: 'audio/wav',
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

  test('新增仍只传 name/url，结果保留输入字段并采用原生 ID', () async {
    const input = HttpTts(
      id: -5,
      name: '测试',
      url: 'http://a',
      contentType: 'audio/wav',
    );
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: input.name, url: input.url))
        .thenAnswer((_) async => 17);
    expect(await repository.addHttpTts(input), input.copyWith(id: 17));
    verify(() => bridge.crateFfiFfiHttpTtsAdd(name: input.name, url: input.url))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('更新删除保留 void 语义，启用操作原样返回 bool', () async {
    const row = HttpTts(id: 17, name: '修改', url: 'http://b');
    when(
      () =>
          bridge.crateFfiFfiHttpTtsUpdate(id: 17, name: row.name, url: row.url),
    ).thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiHttpTtsDelete(id: 17))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .thenAnswer((_) async => false);
    await repository.updateHttpTts(row);
    await repository.deleteHttpTts(row.id);
    expect(await repository.httpTtsSetEnabled(row.id, false), isFalse);
    verify(
      () =>
          bridge.crateFfiFfiHttpTtsUpdate(id: 17, name: row.name, url: row.url),
    ).called(1);
    verify(() => bridge.crateFfiFfiHttpTtsDelete(id: 17)).called(1);
    verify(() => bridge.crateFfiFfiHttpTtsSetEnabled(id: 17, enabled: false))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('导入依次保留原值，跳过缺 name/url，不擅自增加事务', () async {
    final imported = <String>[];
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: '甲', url: 'http://a'))
        .thenAnswer((_) async {
          imported.add('甲');
          return 1;
        });
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: ' 乙 ', url: 'http://b'))
        .thenAnswer((_) async {
          imported.add(' 乙 ');
          return 2;
        });
    expect(
      await repository.importHttpTts(
        '[{"name":"甲","url":"http://a"},{"name":""},{"url":"http://skip"},{"name":" 乙 ","url":"http://b"}]',
      ),
      2,
    );
    expect(imported, ['甲', ' 乙 ']);
  });

  test('导入失败立即上抛，已完成写入不回滚，后续条目不执行', () async {
    final failure = StateError('写入失败');
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: '甲', url: 'http://a'))
        .thenAnswer((_) async => 1);
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: '乙', url: 'http://b'))
        .thenAnswer((_) async => throw failure);
    await expectLater(
      repository.importHttpTts(
        '[{"name":"甲","url":"http://a"},{"name":"乙","url":"http://b"},{"name":"丙","url":"http://c"}]',
      ),
      throwsA(same(failure)),
    );
    verify(() => bridge.crateFfiFfiHttpTtsAdd(name: '甲', url: 'http://a'))
        .called(1);
    verify(() => bridge.crateFfiFfiHttpTtsAdd(name: '乙', url: 'http://b'))
        .called(1);
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
    when(() => bridge.crateFfiFfiHttpTtsAdd(name: '甲', url: 'http://a'))
        .thenAnswer((_) async => throw failure);
    when(
      () => bridge.crateFfiFfiHttpTtsUpdate(id: 17, name: '甲', url: 'http://a'),
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
