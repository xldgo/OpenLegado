import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_preview.dart';
import 'package:flutter_legado/src/domain/models/http_tts_voice_selection.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';

import '../mocks/mocks.dart' hide MockHttpTtsSynthesizer;

class _Cloud implements CloudTtsSynthesizer {
  Completer<HttpTtsSynthesisResult>? pending;
  HttpTtsCancellation? cancellation;
  Map<String, dynamic>? options;
  String? lastId;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    options = voiceOptions;
    lastId = voiceId;
    return pending?.future ?? const HttpTtsAudio(audioPath: '/fixture.wav');
  }
}

class _Http implements HttpTtsSynthesizer {
  final calls =
      <({int engine, String? tone, String? speaker, String? emotion})>[];
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  }) async {
    calls.add((
      engine: engineId,
      tone: toneId,
      speaker: speakerName,
      emotion: emotionTag,
    ));
    return const HttpTtsAudio(audioPath: '/http.wav');
  }
}

class _System extends Fake implements SystemTts {
  @override
  String get selectedEngine => 'device';
  @override
  String get selectedVoice => '原选择';
  String? previewKey;
  int writes = 0, stops = 0;
  final result = Completer<SystemTtsOutcome>();
  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  }) {
    previewKey = voiceKey;
    return result.future;
  }

  @override
  Future<void> saveSettings({
    required String engine,
    required String voice,
  }) async {
    writes++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  late _Cloud cloud;
  late _Http http;
  late _System system;
  late FakeStreamAudioPlayer player;
  late ReadAloudVoicePreview preview;
  final changes = <String?>[];
  final errors = <Object>[];
  ReadAloudVoice voice(String speaker) => ReadAloudVoice(
    id: readAloudVoiceId('cloud_tts', 'cloud', speaker),
    engineType: 'cloud_tts',
    engineId: 'cloud',
    speakerId: speaker,
    displayName: speaker,
    traitsJson: '{"style":"平静","format":"wav"}',
  );
  setUp(() async {
    cloud = _Cloud();
    http = _Http();
    system = _System();
    player = FakeStreamAudioPlayer();
    changes.clear();
    errors.clear();
    final engines = MockCloudTtsRepository();
    await engines.save(
      const CloudTtsEngine(
        id: 'cloud',
        name: '引擎',
        credentialKey: 'cloud-tts:cloud:fixture',
      ),
    );
    preview = ReadAloudVoicePreview(
      player: player,
      system: system,
      cloud: () => cloud,
      engines: () => engines,
      http: () => http,
      cache: () => const MockTtsCacheRepository(),
      onChanged: changes.add,
      onError: errors.add,
    );
  });
  tearDown(() async {
    await preview.dispose();
  });
  test('HTTP 试听与正文同样解析预设、显式情感、默认覆盖和失效回落', () async {
    final v = ReadAloudVoice(
      id: readAloudVoiceId('http', '7', 'zh'),
      engineType: 'http',
      engineId: '7',
      speakerId: 'zh',
      displayName: '中文',
      traitsJson: '{"emotionTag":"happy"}',
      emotionCatalogJson: '[{"emotionName":"高兴","emotionTag":"happy"},{"emotionName":"平静","emotionTag":"calm"}]',
    );
    await preview.speak(v, '默认预设');
    await preview.speak(
      v,
      '当前正文情感',
      httpSelection: HttpTtsVoiceSelection(v.id, emotionTag: 'calm'),
    );
    await preview.speak(
      v,
      '显式引擎默认',
      httpSelection: HttpTtsVoiceSelection(v.id, emotionTag: ''),
    );
    await preview.speak(
      v,
      '失效情感',
      httpSelection: HttpTtsVoiceSelection(v.id, emotionTag: 'gone'),
    );
    expect(http.calls.map((e) => e.emotion), ['happy', 'calm', null, null]);
    expect(
      http.calls.every(
        (e) => e.engine == 7 && e.tone == 'zh' && e.speaker == '中文',
      ),
      isTrue,
    );
    expect(player.playedLocalFiles, hasLength(4));
  });
  test('不同音色以独立草稿试听，停止后迟到文件不播放', () async {
    cloud.pending = Completer();
    final first = preview.speak(voice('alloy'), '测试', draft: true);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cloud.options?['voiceId'], 'alloy');
    await preview.stop();
    expect(cloud.cancellation!.isCancelled, true);
    cloud.pending!.complete(const HttpTtsAudio(audioPath: '/old.wav'));
    await first;
    expect(player.playedLocalFiles, isEmpty);
    cloud.pending = null;
    await preview.speak(voice('nova'), '测试', draft: true);
    expect(cloud.options?['voiceId'], 'nova');
    expect(player.playedLocalFiles.map((r) => r.path), ['/fixture.wav']);
    expect(errors, isEmpty);
  });
  test('已保存音色试听引用记录 ID，参数与可用状态由 Rust 查询', () async {
    await preview.speak(voice('nova'), '正文');
    expect(cloud.lastId, voice('nova').id);
    expect(cloud.options, isNull);
  });
  test('系统试听临时音色不写持久化，过期完成不停止下一会话', () async {
    final v = ReadAloudVoice(
      id: readAloudVoiceId('system', 'system:device', 'native'),
      engineType: 'system',
      engineId: 'system:device',
      speakerId: 'native',
      displayName: '试听音色',
      traitsJson: '{"voiceKey":"临时音色"}',
    );
    await preview.speak(v, '系统试听');
    expect(system.previewKey, '临时音色');
    expect(system.selectedVoice, '原选择');
    expect(system.writes, 0);
    await preview.speak(voice('nova'), '下一次');
    system.result.complete(SystemTtsOutcome.completed);
    await Future<void>.delayed(Duration.zero);
    expect(changes.last, voice('nova').id);
    expect(player.playedLocalFiles.map((r) => r.path), ['/fixture.wav']);
    expect(system.writes, 0);
  });
  test('合成失败后清除播放标记，销毁中迟到初始化不能开播', () async {
    cloud.pending = Completer();
    final speech = preview.speak(voice('alloy'), '测试', draft: true);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    cloud.pending!.completeError(StateError('fixture 失败'));
    await expectLater(speech, throwsStateError);
    expect(changes.last, isNull);
    await preview.dispose();
    await preview.speak(voice('nova'), '不会播放');
    expect(player.playedLocalFiles, isEmpty);
  });
  test('试听异步解码失败结束会话，旧音色错误不会终止新试听', () async {
    await preview.speak(voice('alloy'), '测试', draft: true);
    final oldTag = player.currentTag;
    player.onError!(StateError('试听解码失败'), oldTag);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(errors, hasLength(1));
    expect(errors.single.toString(), contains('试听解码失败'));
    expect(changes.last, isNull);
    await preview.speak(voice('nova'), '新试听', draft: true);
    player.onError!(StateError('旧错误'), oldTag);
    expect(errors, hasLength(1));
    expect(changes.last, voice('nova').id);
  });
}
