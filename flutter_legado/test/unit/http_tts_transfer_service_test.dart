import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_legado/src/data/repositories/mock_http_tts_repository.dart';
import 'package:flutter_legado/src/data/services/http_tts_transfer_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Network extends Mock implements NetworkService {}

void main() {
  late MockHttpTtsRepository repository;
  late _Network network;
  late HttpTtsTransferService service;
  var nextId = 1;
  const raw = <String, dynamic>{
    'id': 17,
    'name': '完整源',
    'url': 'https://tts.test,{"method":"POST"}',
    'header': '{"X-Auth":"fixture"}',
    'contentType': 'audio/wav',
    'pauseDuration': 100,
    'concurrentRate': '1000',
    'loginUi': [
      {'name': '密钥'},
    ],
    'loginUrl': 'https://tts.test/login',
    'loginCheckJs': 'result',
    'jsLib': 'var a = 1',
    'enabledCookieJar': true,
    'speed': 15,
    'synthesisThreadCount': 4,
    'isEnabled': false,
    'lastUpdateTime': 200,
    'speakersJson': '[{"speakerName":"中文","toneID":"zh","tags":["女"]}]',
    'emotionsJson': '[{"emotionName":"高兴","emotionTag":"happy"}]',
  };
  setUp(() {
    nextId = 1;
    repository = MockHttpTtsRepository(nextId: () => nextId++);
    network = _Network();
    service = HttpTtsTransferService(repository, network);
  });

  test('预览单对象不写入，按 ID/时间区分新增、更新、已有', () async {
    await repository.addHttpTts(
      const HttpTts(
        id: 3,
        name: '本地',
        url: 'https://local',
        lastUpdateTime: 100,
      ),
    );
    final items = await service.preview(
      jsonEncode([
        raw,
        {'id': 3, 'name': '更新', 'url': 'https://new', 'lastUpdateTime': 101},
        {'id': 4, 'name': '新增', 'url': 'https://new'},
      ]),
    );
    expect(items.map((e) => e.status), [
      HttpTtsImportStatus.added,
      HttpTtsImportStatus.updated,
      HttpTtsImportStatus.added,
    ]);
    final existing = await service.preview(
      '{"id":3,"name":"本地","url":"https://local","lastUpdateTime":100}',
    );
    expect(existing.single.status, HttpTtsImportStatus.existing);
    expect(existing.single.selectedByDefault, isFalse);
    expect((await repository.getHttpTts()).single.name, '本地');
    verifyZeroInteractions(network);
  });

  test('只保存勾选项，更新保留 ID 与全部高级字段及源目录', () async {
    await repository.addHttpTts(
      const HttpTts(id: 17, name: '旧', url: 'https://old'),
    );
    final items = await service.preview(
      jsonEncode([
        raw,
        {'id': 18, 'name': '未勾选', 'url': 'https://unused'},
      ]),
    );
    expect(await service.save([items.first]), 1);
    final saved = (await repository.getHttpTts()).single;
    expect(saved, HttpTts.fromJson(raw));
    final voice = (await repository.voiceCatalog.list()).single;
    expect(voice.speakerId, 'zh');
    expect(jsonDecode(voice.traitsJson), ['女']);
    expect(jsonDecode(voice.emotionCatalogJson), [
      {'emotionName': '高兴', 'emotionTag': 'happy'},
    ]);
    expect(await service.save([]), 0);
  });

  for (final input in [
    '[]',
    '[null]',
    '[{"name":"甲","url":"https://a"},null]',
    '{"name":"","url":"https://a"}',
    '{"name":"甲"}',
    'false',
    '[{"id":7,"name":"甲","url":"https://a"},{"id":7,"name":"乙","url":"https://b"}]',
  ]) {
    test('无效/重复输入整体拒绝，不产生部分写入：$input', () async {
      await expectLater(service.preview(input), throwsFormatException);
      expect(await repository.getHttpTts(), isEmpty);
    });
  }

  test('底层 Mock 整批解析失败也不留前面已解析的配置/目录', () async {
    await expectLater(
      repository.importHttpTts(jsonEncode([raw, null])),
      throwsFormatException,
    );
    expect(await repository.getHttpTts(), isEmpty);
    expect(await repository.voiceCatalog.list(), isEmpty);
  });

  test('同批零 ID 与显式 ID 不互相覆盖', () async {
    final items = await service.preview(
      '[{"name":"自动","url":"https://a"},{"id":1,"name":"显式","url":"https://b"}]',
    );
    expect(await service.save(items), 2);
    final saved = await repository.getHttpTts();
    expect(saved.map((e) => e.name), ['显式', '自动']);
    expect(saved.map((e) => e.id), [1, 2]);
  });

  test('HTTP URL、data URI 和两种应用链接汇合为同一预览', () async {
    final doc = jsonEncode(raw);
    when(() => network.httpGet('https://rules.test/tts'))
        .thenAnswer((_) async => HttpTextResponse(statusCode: 200, body: doc));
    for (final input in [
      'https://rules.test/tts',
      Uri.dataFromString(
        doc,
        mimeType: 'application/json',
        encoding: utf8,
        base64: true,
      ).toString(),
      Uri(
        scheme: 'legado',
        host: 'import',
        path: '/httpTTS',
        queryParameters: {'src': doc},
      ).toString(),
      Uri(
        scheme: 'yuedu',
        host: 'import',
        path: '/httpTTS',
        queryParameters: {'src': 'https://rules.test/tts'},
      ).toString(),
    ]) {
      expect((await service.preview(input)).single.raw, raw);
    }
    expect(await repository.getHttpTts(), isEmpty);
  });

  test('无 UA 标记使用共享字节请求，传递上游指定请求头', () async {
    when(
      () => network.httpGetBytes(
        'https://rules.test/tts',
        headers: {'User-Agent': 'null'},
      ),
    ).thenAnswer(
      (_) async => HttpBytesResponse(
        statusCode: 200,
        url: 'https://rules.test/tts',
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(raw))),
      ),
    );
    expect(
      (await service.preview('https://rules.test/tts#requestWithoutUA'))
          .single
          .engine
          .name,
      '完整源',
    );
    verifyNever(() => network.httpGet(any()));
  });

  test('下载失败、链接循环及其他类型导入链接明确拒绝', () async {
    when(() => network.httpGet('https://rules.test/tts')).thenAnswer(
      (_) async => const HttpTextResponse(statusCode: 503, body: 'unavailable'),
    );
    await expectLater(
      service.preview('https://rules.test/tts'),
      throwsFormatException,
    );
    when(() => network.httpGet('https://rules.test/tts')).thenAnswer(
      (_) async => const HttpTextResponse(
        statusCode: 200,
        body: 'https://rules.test/tts',
      ),
    );
    await expectLater(
      service.preview('https://rules.test/tts'),
      throwsFormatException,
    );
    await expectLater(
      service.preview('legado://import/bookSource?src=%7B%7D'),
      throwsFormatException,
    );
    expect(await repository.getHttpTts(), isEmpty);
  });

  test('导出/再导入保留全部配置、音色和情绪，不混入其他引擎目录', () async {
    await service.save(await service.preview(jsonEncode(raw)));
    await repository.addHttpTts(
      const HttpTts(id: 18, name: '其他', url: 'https://other'),
    );
    await repository.voiceCatalog.syncSystem('system:default', [
      const SystemVoiceCatalogEntry(
        speakerId: 'sys',
        displayName: '系统',
        traitsJson: '{}',
      ),
    ]);
    final exported = await service.export(ids: {17});
    final list = jsonDecode(exported) as List;
    expect(list, hasLength(1));
    expect(
      HttpTts.fromJson(Map<String, dynamic>.from(list.single)),
      HttpTts.fromJson(raw),
    );
    expect(
      jsonDecode(list.single['speakersJson']),
      jsonDecode(raw['speakersJson'] as String),
    );
    expect(
      jsonDecode(list.single['emotionsJson']),
      jsonDecode(raw['emotionsJson'] as String),
    );
    var id = 1;
    final second = MockHttpTtsRepository(nextId: () => id++);
    await second.importHttpTts(exported);
    expect((await second.voiceCatalog.list()).single.speakerId, 'zh');
    expect((await second.getHttpTts()).single.id, 17);
    await expectLater(service.export(ids: {999}), throwsStateError);
  });
}
