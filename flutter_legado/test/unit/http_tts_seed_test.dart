import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

// D3 缺陷回归：Flutter 轨 httpTTS 种子导入与可用性如实登记。
//
// 背景（QA 证据 .tmp/tts_qa/device_legado.db / screen_12_ttsconfig.png）：
// dict/rss/txtToc 均有种子导入器，httpTTS 缺失 → 首启引擎表为空。
// 种子内容（app/src/main/assets/defaultData/httpTTS.json）依赖原版
// AnalyzeUrl 的 POST/@js/loginUrl 能力，当前 Rust 合成管线（GET + 占位符）
// 不支持（QA 实测种子「1.百度」无参数返回错误 JSON）。
//
// 本文件钉住修复契约：
// 1. 种子资产存在且非空（确实存在才导入）；
// 2. syncDefaultHttpTts 只导入 name/url 非空条目、幂等、失败不抛；
// 3. 种子按原版形态全量导入、不做启用态标记（原版 HttpTTS.kt 无 isEnabled
//    概念；可用性由 URL 兼容性判定在自动选默认引擎时把关，写入启用态列无效）；
// 4. ensureDefaultHttpTts 版本门控；
// 5. 自动选默认引擎跳过不兼容模板，只接受 GET+文本占位符。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud.dart';

import '../mocks/mocks.dart';

/// 原版种子「1.百度」URL（POST/JS 形态，Rust 管线不支持）
const _seedBaiduUrl =
    'http://tts.baidu.com/text2audio,{"method": "POST","body": "tex=...&aue=6"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFallbacks);

  group('种子资产（确实存在且不为空）', () {
    test('assets/default_data/httpTTS.json 存在且每个条目 name/url 非空', () {
      final file = File(kDefaultHttpTtsAsset);
      expect(file.existsSync(), isTrue, reason: '种子资源必须随 Flutter 轨打包');
      final text = file.readAsStringSync().trim();
      expect(text, isNotEmpty);

      final list = jsonDecode(text) as List<dynamic>;
      expect(list, isNotEmpty, reason: '种子为空则不应导入');
      for (final item in list.whereType<Map<String, dynamic>>()) {
        expect((item['name'] as String?)?.trim(), isNotEmpty);
        expect((item['url'] as String?)?.trim(), isNotEmpty);
      }
    });
  });

  group('syncDefaultHttpTts 导入', () {
    late MockRustApi api;
    late List<HttpTts> added;
    var nextId = 100;

    setUp(() {
      api = MockRustApi();
      added = [];
      nextId = 100;
      when(() => api.httpTtsRepository.getHttpTts())
          .thenAnswer((_) async => []);
      when(() => api.httpTtsRepository.addHttpTts(any()))
          .thenAnswer((invocation) async {
            final tts = invocation.positionalArguments[0] as HttpTts;
            added.add(tts);
            return tts.copyWith(id: nextId++);
          });
    });

    test('非空种子：按原版形态全量导入全字段（含数组 loginUi，不做额外启用态写入）', () async {
      final json = jsonEncode([
        {
          'id': -100,
          'name': '1.百度',
          'url': _seedBaiduUrl,
          'contentType': 'audio/wav',
        },
        {
          'id': -29,
          'name': '2.阿里云语音',
          'url': 'https://nls.example.com/tts',
          'contentType': 'audio/mpeg',
          'loginUrl': 'function login(){}',
          'loginUi': [
            {'name': 'AppKey', 'type': 'text'},
          ],
          'loginCheckJs': 'result',
          'speed': 10,
          'synthesisThreadCount': 4,
        },
      ]);

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 2);
      expect(added.map((e) => e.name), ['1.百度', '2.阿里云语音']);
      expect(added.first.id, -100);
      expect(added.first.url, _seedBaiduUrl);
      expect(added.first.contentType, 'audio/wav');
      expect(added[1].id, -29);
      expect(added[1].loginUrl, 'function login(){}');
      expect(added[1].loginUi, '[{"name":"AppKey","type":"text"}]');
      expect(added[1].loginCheckJs, 'result');
      expect(added[1].speed, 10);
      expect(added[1].synthesisThreadCount, 4);
      // 不做启用态写入：原版 HttpTTS.kt 无 isEnabled 概念，可用性由 URL 兼容性判定把关
      verifyNever(() => api.httpTtsRepository.httpTtsSetEnabled(any(), any()));
    });

    test('空种子 / 空串 / 非法 JSON：返回 0 且不写库、不抛出', () async {
      expect(
        await syncDefaultHttpTts(api.httpTtsRepository, jsonOverride: ''),
        0,
      );
      expect(
        await syncDefaultHttpTts(api.httpTtsRepository, jsonOverride: '   '),
        0,
      );
      expect(
        await syncDefaultHttpTts(api.httpTtsRepository, jsonOverride: '[]'),
        0,
      );
      expect(
        await syncDefaultHttpTts(
          api.httpTtsRepository,
          jsonOverride: 'not-json',
        ),
        0,
      );
      expect(
        await syncDefaultHttpTts(
          api.httpTtsRepository,
          jsonOverride: '{"a":1}',
        ),
        0,
      );
      verifyNever(() => api.httpTtsRepository.addHttpTts(any()));
    });

    test('缺 name/url 的条目被过滤', () async {
      const json = '''
      [
        {"id": 1, "name": "", "url": "http://a"},
        {"id": 2, "name": "B", "url": ""},
        {"id": 3, "name": "C", "url": "http://c"}
      ]
      ''';

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 1);
      expect(added.single.name, 'C');
    });

    test('幂等：库中已有同名同 URL 时跳过', () async {
      when(() => api.httpTtsRepository.getHttpTts())
          .thenAnswer((_) async => [HttpTts(name: '1.百度', url: _seedBaiduUrl)]);
      final json = jsonEncode([
        {'id': -100, 'name': '1.百度', 'url': _seedBaiduUrl},
      ]);

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 0);
      verifyNever(() => api.httpTtsRepository.addHttpTts(any()));
    });

    test('保护用户配置：用户修改已有同 ID 引擎的名称、URL 或 Header 后，自动同步不会覆盖该引擎', () async {
      when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
        (_) async => const [
          HttpTts(
            id: -100,
            name: '1.百度-用户定制',
            url: 'https://custom.baidu.example/tts?text={{text}}',
            header: '{"Authorization":"Bearer user-secret"}',
          ),
        ],
      );
      final json = jsonEncode([
        {'id': -100, 'name': '1.百度', 'url': _seedBaiduUrl, 'header': '{}'},
        {'id': -29, 'name': '2.阿里云语音', 'url': 'https://nls.example.com/tts'},
      ]);

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 1);
      expect(added, hasLength(1));
      expect(added.single.id, -29);
      expect(added.single.name, '2.阿里云语音');
    });

    test('读取现有配置失败时立即中止并返回 0，绝不按空库继续覆盖写入', () async {
      when(() => api.httpTtsRepository.getHttpTts())
          .thenThrow(StateError('数据库繁忙'));
      final json = jsonEncode([
        {'id': -100, 'name': '1.百度', 'url': _seedBaiduUrl},
      ]);

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 0);
      verifyNever(() => api.httpTtsRepository.addHttpTts(any()));
    });

    test('单条种子字段解析错误不会中断后续有效种子的导入', () async {
      final json = jsonEncode([
        {
          'id': -100,
          'name': '损坏条目',
          'url': 'http://broken.example/tts',
          'speed': 'not-an-int',
        },
        {
          'id': -29,
          'name': '2.阿里云语音',
          'url': 'https://nls.example.com/tts',
          'speed': 10,
        },
      ]);

      final count = await syncDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: json,
      );

      expect(count, 1);
      expect(added, hasLength(1));
      expect(added.single.id, -29);
      expect(added.single.name, '2.阿里云语音');
    });
  });

  group('ensureDefaultHttpTts 版本门控', () {
    late MockRustApi api;
    setUp(() {
      api = MockRustApi();
      when(() => api.httpTtsRepository.getHttpTts())
          .thenAnswer((_) async => []);
      when(() => api.httpTtsRepository.addHttpTts(any())).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments[0] as HttpTts).copyWith(id: 1),
      );
    });

    test('首启导入一次并写版本号，再次调用不再导入', () async {
      SharedPreferences.setMockInitialValues({});
      const json =
          '[{"id": -100, "name": "1.百度", "url": "http://a/tts?t={{speakText}}"}]';

      await ensureDefaultHttpTts(api.httpTtsRepository, jsonOverride: json);
      verify(() => api.httpTtsRepository.addHttpTts(any())).called(1);
      verifyNever(() => api.httpTtsRepository.httpTtsSetEnabled(any(), any()));

      await ensureDefaultHttpTts(api.httpTtsRepository, jsonOverride: json);
      verifyNever(() => api.httpTtsRepository.addHttpTts(any()));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kHttpTtsSeedVersionKey), kHttpTtsSeedVersion);
    });

    test('版本已是最新：完全跳过（不读库不导入）', () async {
      SharedPreferences.setMockInitialValues({
        kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
      });

      await ensureDefaultHttpTts(
        api.httpTtsRepository,
        jsonOverride: '[{"name":"x","url":"http://x"}]',
      );

      verifyNever(() => api.httpTtsRepository.getHttpTts());
    });
  });

  group('引擎 URL 兼容性判定（自动选默认引擎）', () {
    test('POST、JS 和 HTTP 入口受支持，空和非 HTTP 规则拒绝', () {
      expect(isCompatibleHttpTtsEngineUrl(_seedBaiduUrl), isTrue);
      expect(
        isCompatibleHttpTtsEngineUrl(
          'https://nls-gateway.example.com/tts,{"method":"POST"}',
        ),
        isTrue,
      );
      expect(
        isCompatibleHttpTtsEngineUrl('@js:apiurl(speakText,speakSpeed)'),
        isTrue,
      );
      expect(
        isCompatibleHttpTtsEngineUrl('http://tts.example.com/tts'),
        isTrue,
      );
      expect(isCompatibleHttpTtsEngineUrl(''), isFalse);
      expect(
        isCompatibleHttpTtsEngineUrl('ftp://tts.example.com/{{text}}'),
        isFalse,
      );
    });

    test('GET + 文本占位符（Rust 管线支持）为兼容', () {
      expect(
        isCompatibleHttpTtsEngineUrl(
          'http://192.168.1.2:8770/tts?text={{text}}&speed={{speed}}',
        ),
        isTrue,
      );
      expect(
        isCompatibleHttpTtsEngineUrl(
          'https://tts.example.com/api?text={{speakText}}&speed={{speakSpeed}}',
        ),
        isTrue,
      );
    });
  });

  group('AudioNotifier 自动选默认引擎（D3 集成）', () {
    late MockRustApi api;
    late FakeStreamAudioPlayer fakePlayer;
    late ProviderContainer container;

    setUpAll(registerFallbacks);

    setUp(() {
      // 版本已最新：跳过种子导入，聚焦默认引擎筛选
      SharedPreferences.setMockInitialValues({
        kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
      });
      api = MockRustApi();
      fakePlayer = FakeStreamAudioPlayer();
      container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...api.overrides,
          ReadAloudPlannerStub.singleUnit().providerOverride,
          streamAudioPlayerProvider.overrideWithValue(fakePlayer),
        ]),
      );
      addTearDown(container.dispose);

      when(() => api.readingRepository.getChapters(any()))
          .thenAnswer((_) async => [const BookChapter(title: '第一章', index: 0)]);
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => null);
      when(() => api.readingRepository.getChapterContentFull(any(), any()))
          .thenAnswer((_) async => '正文内容。');
      when(
        () => api.httpTtsSynthesizer.synthesize(
          cancellation: any(named: 'cancellation'),
          engineId: any(named: 'engineId'),
          text: any(named: 'text'),
          engineUrl: any(named: 'engineUrl'),
          speed: any(named: 'speed'),
          pitch: any(named: 'pitch'),
          volume: any(named: 'volume'),
          voiceName: any(named: 'voiceName'),
        ),
      ).thenAnswer((_) async => HttpTtsAudio(audioPath: '/tmp/tts/para.mp3'));
    });

    test('库中只有无效请求入口 → 不自动选中，保持无引擎提示', () async {
      when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
        (_) async => [HttpTts(id: -100, name: '无效入口', url: 'ftp://invalid')],
      );

      await container
          .read(audioNotifierProvider.notifier)
          .startReadAloud(bookUrl: 'url', bookName: '书');

      final state = container.read(audioNotifierProvider);
      expect(state.config.engineUrl, isEmpty);
      expect(state.state, PlayerState.playing);
      // 无可用引擎：不调用合成（降级估算），并给用户可见的一次性提示
      // [A4 批 2026-10-03] 由「静默降级」改为「温和提示」（用户裁决）
      verifyNever(
        () => api.httpTtsSynthesizer.synthesize(
          cancellation: any(named: 'cancellation'),
          engineId: any(named: 'engineId'),
          text: any(named: 'text'),
          engineUrl: any(named: 'engineUrl'),
          speed: any(named: 'speed'),
          pitch: any(named: 'pitch'),
          volume: any(named: 'volume'),
          voiceName: any(named: 'voiceName'),
        ),
      );
      expect(state.errorMessage, kNoUsableEngineHint);
    });

    test('库中含兼容引擎 → 跳过不兼容项选中兼容项', () async {
      when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
        (_) async => [
          HttpTts(id: -100, name: '无效入口', url: 'ftp://invalid'),
          HttpTts(
            id: 5,
            name: '本地引擎',
            url: 'http://192.168.1.2:8770/tts?text={{text}}',
          ),
        ],
      );

      await container
          .read(audioNotifierProvider.notifier)
          .startReadAloud(bookUrl: 'url', bookName: '书');

      final state = container.read(audioNotifierProvider);
      expect(
        state.config.engineUrl,
        'http://192.168.1.2:8770/tts?text={{text}}',
      );
      expect(fakePlayer.playedLocalFiles, hasLength(1));
    });
  });
}
