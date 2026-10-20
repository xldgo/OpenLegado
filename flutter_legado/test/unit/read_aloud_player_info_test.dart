import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_player_info.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';

import '../mocks/mocks.dart';

class _Audio extends AudioNotifier {
  _Audio(this.url);
  String url;
  @override
  AudioState build() => AudioState(config: TtsConfig(engineUrl: url));
  // 展示测试只提供选中值，不依赖真实播放服务的构造细节。
  @override
  String resolveTtsEngineUrl() => state.config.engineUrl;
  @override
  Future<int?> resolveTtsEngineId() async =>
      int.tryParse(state.config.engineUrl);
  void select(String value) {
    url = value;
    state = state.copyWith(config: TtsConfig(engineUrl: value));
  }
}

class _Voices extends Fake implements ReadAloudVoiceRepository {
  final catalog = <ReadAloudVoice>[];
  Completer<List<ReadAloudVoice>>? pending;
  @override
  Future<List<ReadAloudVoice>> list() =>
      pending?.future ?? Future.value(catalog);
}

class _Cloud extends Fake implements CloudTtsRepository {
  @override
  Future<List<CloudTtsEngine>> list() async => const [
    CloudTtsEngine(id: 'mimo', name: '我的 MiMo', provider: 'mimo'),
  ];
}

class _System extends Fake implements SystemTts {
  @override
  String get selectedEngine => 'installed.tts';
  @override
  String get selectedVoice => 'voice-key';
}

void main() {
  late MockRustApi api;
  late _Voices voices;
  late ProviderContainer container;
  late _Audio audio;
  final configs = <String, String>{};

  setUp(() {
    api = MockRustApi();
    voices = _Voices();
    audio = _Audio('1');
    configs.clear();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((call) async => configs[call.positionalArguments[0]]);
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => const [
        HttpTts(
          id: 1,
          name: '我的 HTTP',
          url: 'https://private.example/?token=secret',
        ),
      ],
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        audioNotifierProvider.overrideWith(() => audio),
        readAloudVoiceRepositoryProvider.overrideWithValue(voices),
        cloudTtsRepositoryProvider.overrideWithValue(_Cloud()),
        systemTtsServiceProvider.overrideWithValue(_System()),
      ]),
    );
    addTearDown(container.dispose);
  });

  Future<ReadAloudPlayerInfo> info() =>
      container.read(readAloudPlayerInfoProvider.future);

  test('HTTP 只展示当前已保存音色，不暴露 URL 或保存配置', () async {
    voices.catalog.add(
      const ReadAloudVoice(
        id: 'saved',
        engineType: 'http',
        engineId: '1',
        speakerId: 'zh',
        displayName: '中文声音',
      ),
    );
    configs['ttsVoice:${1}'] = jsonEncode({
      'voiceId': 'saved',
      'emotionTag': null,
    });
    final value = await info();
    expect(value.engineName, '我的 HTTP');
    expect(value.voiceName, '中文声音');
    verifyNever(() => api.configRepository.setConfig(any(), any()));
  });

  test('缺失或被排除的 HTTP 音色展示默认状态，不误认其他音色', () async {
    voices.catalog.add(
      const ReadAloudVoice(
        id: 'saved',
        engineType: 'http',
        engineId: '1',
        speakerId: 'zh',
        displayName: '已排除音色',
        excluded: true,
      ),
    );
    configs['ttsVoice:${1}'] = jsonEncode({
      'voiceId': 'saved',
      'emotionTag': null,
    });
    expect((await info()).voiceName, isNull);
  });

  test('云端读取所属引擎音色，不读取凭据或发起合成', () async {
    audio.url = 'cloud://mimo';
    voices.catalog.add(
      const ReadAloudVoice(
        id: 'cloud-voice',
        engineType: 'cloud_tts',
        engineId: 'mimo',
        speakerId: 'default',
        displayName: '我的云端音色',
      ),
    );
    configs['cloudTtsVoice:mimo'] = 'cloud-voice';
    final value = await info();
    expect(value.engineName, '我的 MiMo');
    expect(value.voiceName, '我的云端音色');
    verifyNever(() => api.configRepository.setConfig(any(), any()));
    verifyNever(() => api.httpTtsRepository.getHttpTts());
  });

  test('系统展示已添加的音色，不初始化插件或枚举设备音色', () async {
    audio.url = systemTtsEngineUrl;
    voices.catalog.add(
      ReadAloudVoice(
        id: 'system-voice',
        engineType: 'system',
        engineId: 'system:installed.tts',
        speakerId: 'zh',
        displayName: '设备中文',
        traitsJson: jsonEncode({'voiceKey': 'voice-key'}),
      ),
    );
    final value = await info();
    expect(value.system, isTrue);
    expect(value.engineName, 'installed.tts');
    expect(value.voiceName, '设备中文');
    // Fake 未实现初始化和枚举，意外调用将直接使测试失败。
    verifyNever(() => api.configRepository.setConfig(any(), any()));
  });

  test('慢目录返回期间切换引擎，忽略旧结果且不访问失效 Ref', () async {
    voices.pending = Completer<List<ReadAloudVoice>>();
    final subscription = container.listen(
      readAloudPlayerInfoProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    container.read(readAloudPlayerInfoProvider);
    audio.select('cloud://mimo');
    await container.pump();
    voices.pending!.complete([]);
    final value = await info();
    expect(value.engineName, '我的 MiMo');
    await container.pump();
  });
}
