import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/platform/tts/system_tts_service.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFlutterTts plugin;
  late SystemTtsService service;
  late List<Completer<dynamic>> requests;
  late List<String> spoken;
  late List<Map<String, String>> chosenVoices;
  late List<double> rates;
  late List<dynamic> voices;
  late void Function(dynamic) errorHandler;
  late int stopCount;
  late void Function() completionHandler;
  late void Function() cancelHandler;
  late void Function() pauseHandler;
  late void Function(String, int, int, String) progressHandler;
  int? nativeIndex;
  final cancelled = <int>{};

  setUpAll(() {
    registerFallbackValue((String text, int start, int end, String word) {});
    registerFallbackValue(IosTextToSpeechAudioCategory.playback);
    registerFallbackValue(IosTextToSpeechAudioMode.spokenAudio);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plugin = MockFlutterTts();
    requests = [];
    spoken = [];
    chosenVoices = [];
    rates = [];
    stopCount = 0;
    nativeIndex = null;
    cancelled.clear();
    voices = [
      {'name': '联网中文', 'locale': 'zh-CN', 'network_required': true},
      {'name': '离线中文', 'locale': 'zh-CN', 'network_required': false},
    ];
    when(() => plugin.getEngines).thenAnswer((_) async => ['test.engine']);
    when(() => plugin.getDefaultEngine).thenAnswer((_) async => 'test.engine');
    when(() => plugin.setEngine(any())).thenAnswer((_) async => 1);
    when(() => plugin.setQueueMode(any())).thenAnswer((_) async => 1);
    when(() => plugin.getMaxSpeechInputLength).thenAnswer((_) async => 8);
    when(() => plugin.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => plugin.getSpeechRateValidRange).thenAnswer(
      (_) async =>
          SpeechRateValidRange(0, 0.5, 1.5, TextToSpeechPlatform.android),
    );
    when(() => plugin.getVoices).thenAnswer((_) async => voices);
    when(() => plugin.setVoice(any())).thenAnswer((call) async {
      chosenVoices.add(call.positionalArguments.first as Map<String, String>);
      return 1;
    });
    when(() => plugin.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => plugin.isLanguageAvailable(any()))
        .thenAnswer((_) async => false);
    when(() => plugin.setSpeechRate(any())).thenAnswer((call) async {
      rates.add(call.positionalArguments.first as double);
      return 1;
    });
    when(() => plugin.setPitch(any())).thenAnswer((_) async => 1);
    when(() => plugin.setVolume(any())).thenAnswer((_) async => 1);
    when(() => plugin.setSharedInstance(any())).thenAnswer((_) async => 1);
    when(() => plugin.autoStopSharedSession(any())).thenAnswer((_) async => 1);
    when(() => plugin.setIosAudioCategory(any(), any(), any()))
        .thenAnswer((_) async => 1);
    when(() => plugin.setErrorHandler(any())).thenAnswer((call) {
      errorHandler = call.positionalArguments.first as void Function(dynamic);
    });
    when(() => plugin.setCompletionHandler(any())).thenAnswer((call) {
      completionHandler = call.positionalArguments.first as void Function();
    });
    when(() => plugin.setCancelHandler(any())).thenAnswer((call) {
      cancelHandler = call.positionalArguments.first as void Function();
    });
    when(() => plugin.setProgressHandler(any())).thenAnswer((call) {
      progressHandler =
          call.positionalArguments.first
              as void Function(String, int, int, String);
    });
    when(() => plugin.setPauseHandler(any())).thenAnswer((call) {
      pauseHandler = call.positionalArguments.first as void Function();
    });
    when(() => plugin.stop()).thenAnswer((_) async {
      stopCount++;
      if (nativeIndex != null) {
        cancelled.add(nativeIndex!);
        nativeIndex = null;
        scheduleMicrotask(cancelHandler);
      }
      return 1;
    });
    when(() => plugin.pause()).thenAnswer((_) async {
      if (nativeIndex != null) {
        cancelled.add(nativeIndex!);
        nativeIndex = null;
        scheduleMicrotask(pauseHandler);
      }
      return 1;
    });
    when(() => plugin.speak(any(), focus: any(named: 'focus')))
        .thenAnswer((call) async {
          spoken.add(call.positionalArguments.first as String);
          final request = Completer<dynamic>();
          final index = requests.length;
          requests.add(request);
          nativeIndex = index;
          request.future.then((_) {
            if (!cancelled.contains(index)) {
              nativeIndex = null;
              completionHandler();
            }
          });
          return 1;
        });
    service = SystemTtsService(tts: plugin, platform: TargetPlatform.android);
  });

  test('临时试听音色不写偏好，停止后正文仍使用原默认声音', () async {
    await service.initialize();
    final key = const SystemTtsVoice(name: '联网中文', locale: 'zh-CN').key;
    final preview = service.speak('试听', voiceKey: key);
    await flush();
    expect(chosenVoices.last['name'], '联网中文');
    expect(service.selectedVoice, '');
    await service.stop();
    expect(await preview, SystemTtsOutcome.cancelled);
    final normal = service.speak('正文');
    await flush();
    expect(chosenVoices.last['name'], '离线中文');
    expect(
      (await SharedPreferences.getInstance()).getString('systemTtsVoice'),
      isNull,
    );
    await service.stop();
    expect(await normal, SystemTtsOutcome.cancelled);
  });
  test('分片范围回调映射回原文，停止后不发布旧位置', () async {
    final positions = <(int, int)>[];
    service.onProgress = (start, end) => positions.add((start, end));
    final result = service.speak('第一句结束。第二句结束。');
    await flush();
    progressHandler(spoken[0], 1, 3, '一句');
    expect(positions, [(1, 3)]);
    requests[0].complete(1);
    await flush();
    progressHandler(spoken[0], 0, 1, '第');
    expect(positions.length, 1);
    progressHandler(spoken[1], 2, 4, '句结');
    expect(positions.last, (spoken[0].length + 2, spoken[0].length + 4));
    await service.stop();
    progressHandler(spoken[1], 3, 5, '结束');
    expect(positions.length, 2);
    expect(await result, SystemTtsOutcome.cancelled);
  });

  test('Android 连续暂停后的后缀范围保留累计原文偏移', () async {
    final positions = <int>[];
    service.onProgress = (start, end) => positions.add(start);
    final first = service.speak('中文朗读段落。');
    await flush();
    progressHandler('中文朗读段落。', 2, 4, '朗读');
    await service.pause();
    expect(await first, SystemTtsOutcome.paused);
    final second = service.resume();
    await flush();
    progressHandler('朗读段落。', 1, 3, '读段');
    expect(positions.last, 3);
    await service.pause();
    expect(await second, SystemTtsOutcome.paused);
    final third = service.resume();
    await flush();
    progressHandler('读段落。', 1, 3, '段落');
    expect(positions.last, 4);
    await service.stop();
    expect(await third, SystemTtsOutcome.cancelled);
  });

  test('优先离线中文，保持唯一媒体焦点并映射倍速', () async {
    final result = service.speak('中文小说。', speed: 2);
    await flush();
    expect(chosenVoices.single['name'], '离线中文');
    expect(rates.single, 1.0);
    verify(() => plugin.speak('中文小说。', focus: false)).called(1);
    requests.single.complete(1);
    expect(await result, SystemTtsOutcome.completed);
  });

  test('长段落串行分片，全部播完才完成原段落', () async {
    final result = service.speak('第一句结束。第二句结束。');
    var completed = false;
    result.then((_) => completed = true);
    await flush();
    expect(spoken, ['第一句结束。']);
    requests[0].complete(1);
    await flush();
    expect(completed, false);
    expect(spoken, ['第一句结束。', '第二句结束。']);
    requests[1].complete(1);
    expect(await result, SystemTtsOutcome.completed);
  });

  test('旧取消确认到达前不能启动新朗读', () async {
    final old = service.speak('旧段。');
    await flush();
    void Function()? acknowledge;
    when(() => plugin.stop()).thenAnswer((_) async {
      if (nativeIndex != null) {
        cancelled.add(nativeIndex!);
        nativeIndex = null;
        acknowledge = cancelHandler;
      }
      return 1;
    });
    final stopped = service.stop();
    final current = service.speak('新段。');
    await flush();
    expect(await old, SystemTtsOutcome.cancelled);
    expect(spoken, ['旧段。']);
    acknowledge!();
    await stopped;
    await flush();
    expect(spoken, ['旧段。', '新段。']);
    requests[1].complete(1);
    expect(await current, SystemTtsOutcome.completed);
  });

  test('引擎不确认停止时明确失败，不能启动重叠声音', () async {
    final old = service.speak('旧段。');
    await flush();
    when(() => plugin.stop()).thenAnswer((_) async => 1);
    final stopped = service.stop();
    final stopping = expectLater(stopped, throwsStateError);
    final current = service.speak('新段。');
    final rejected = expectLater(current, throwsStateError);
    expect(await old, SystemTtsOutcome.cancelled);
    await stopping;
    await rejected;
    expect(spoken, ['旧段。']);
    cancelHandler();
  });

  test('暂停续读不停止原生暂停内容，旧完成不会串入恢复请求', () async {
    final first = service.speak('中文段落。');
    await flush();
    await service.pause();
    expect(await first, SystemTtsOutcome.paused);
    final stops = stopCount;
    final resumed = service.resume();
    var completed = false;
    resumed.then((_) => completed = true);
    await flush();
    expect(stopCount, stops);
    expect(spoken, ['中文段落。', '中文段落。']);
    requests[0].complete(1);
    await flush();
    expect(completed, false);
    requests[1].complete(1);
    expect(await resumed, SystemTtsOutcome.completed);
  });

  test('快速开始再停止，在初始化结束后不朗读', () async {
    final result = service.speak('不能读。');
    await service.stop();
    expect(await result, SystemTtsOutcome.cancelled);
    await flush();
    expect(spoken, isEmpty);
  });

  test('缺失中文语音明确失败', () async {
    voices = [];
    await expectLater(service.speak('中文'), throwsStateError);
    expect(spoken, isEmpty);
  });

  test('插件错误终止等待，不用完成回调假装成功', () async {
    final result = service.speak('测试');
    final expectation = expectLater(result, throwsStateError);
    await flush();
    errorHandler('引擎失败');
    await expectation;
    await service.stop();
  });

  test('保存系统音色不写入 HTTP 配置，重建服务恢复', () async {
    await service.initialize();
    final voice = (await service.getVoices()).last;
    await service.saveSettings(engine: '', voice: voice.key);
    final fresh = SystemTtsService(
      tts: plugin,
      platform: TargetPlatform.android,
    );
    await fresh.initialize();
    expect(fresh.selectedVoice, voice.key);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'system_tts_voice', 'system_tts_engine'});
  });

  test('iOS 使用共享 playback 会话，段间不释放', () async {
    service = SystemTtsService(tts: plugin, platform: TargetPlatform.iOS);
    await service.initialize();
    verify(() => plugin.setSharedInstance(true)).called(1);
    verify(() => plugin.autoStopSharedSession(false)).called(1);
    verify(
      () => plugin.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [],
        IosTextToSpeechAudioMode.spokenAudio,
      ),
    ).called(1);
    verifyNever(() => plugin.setEngine(any()));
  });

  test('iOS 暂停恢复共用原生完成事件，不创建等待完成 Future', () async {
    service = SystemTtsService(tts: plugin, platform: TargetPlatform.iOS);
    when(() => plugin.pause()).thenAnswer((_) async => 1);
    final first = service.speak('中文段落。');
    await flush();
    await service.pause();
    expect(await first, SystemTtsOutcome.paused);
    when(() => plugin.speak(any(), focus: any(named: 'focus')))
        .thenAnswer((_) async => 1);
    final resumed = service.resume();
    await flush();
    completionHandler();
    expect(await resumed, SystemTtsOutcome.completed);
    verify(() => plugin.awaitSpeakCompletion(false)).called(1);
    verifyNever(() => plugin.awaitSpeakCompletion(true));
  });

  test('iOS 暂停恢复时重新激活共享音频会话', () async {
    service = SystemTtsService(tts: plugin, platform: TargetPlatform.iOS);
    when(() => plugin.pause()).thenAnswer((_) async => 1);
    final first = service.speak('中文段落。');
    await flush();
    await service.pause();
    expect(await first, SystemTtsOutcome.paused);
    when(() => plugin.speak(any(), focus: any(named: 'focus')))
        .thenAnswer((_) async => 1);
    final resumed = service.resume();
    await flush();
    verify(() => plugin.setSharedInstance(true)).called(3);
    completionHandler();
    expect(await resumed, SystemTtsOutcome.completed);
  });

  test('暂停不支持时停止，恢复重播当前分片', () async {
    when(() => plugin.pause()).thenAnswer((_) async => 0);
    final first = service.speak('中文段落。');
    await flush();
    await service.pause();
    expect(await first, SystemTtsOutcome.paused);
    final resumed = service.resume();
    await flush();
    expect(spoken, ['中文段落。', '中文段落。']);
    requests[1].complete(1);
    expect(await resumed, SystemTtsOutcome.completed);
  });

  test('不支持平台明确失败，不调用插件', () async {
    service = SystemTtsService(tts: plugin, platform: TargetPlatform.linux);
    await expectLater(service.initialize(), throwsStateError);
    verifyNever(() => plugin.getVoices);
  });

  test('分片保留全部文本，UTF-16 代理对不会被截断', () {
    const text = '甲乙丙😀丁戊己😀庚辛';
    final parts = SystemTtsService.splitText(text, 4);
    expect(parts.join(), text);
    for (final part in parts) {
      expect(part.length, lessThanOrEqualTo(4));
      expect(
        part.codeUnitAt(part.length - 1),
        isNot(inInclusiveRange(0xd800, 0xdbff)),
      );
    }
  });

  test('被排除的显式选择仍可发现目录，但起播拒绝换音色', () async {
    const voice = SystemTtsVoice(name: '离线中文', locale: 'zh-CN');
    SharedPreferences.setMockInitialValues({'system_tts_voice': voice.key});
    service = SystemTtsService(
      tts: plugin,
      platform: TargetPlatform.android,
      excludedVoiceKeys: (_) async => {voice.key},
    );
    expect(await service.getVoices(), hasLength(2));
    await expectLater(service.speak('中文'), throwsStateError);
    expect(chosenVoices, isEmpty);
    expect(spoken, isEmpty);
  });
  test('失效音色不自动替换，设备新目录可重新发现', () async {
    SharedPreferences.setMockInitialValues({'system_tts_voice': 'removed'});
    await expectLater(service.speak('中文'), throwsStateError);
    expect(chosenVoices, isEmpty);
    voices = [
      {'name': '新装中文', 'locale': 'zh-CN'},
    ];
    expect((await service.getVoices()).single.name, '新装中文');
  });
  test('默认选择避开排除音色，后续起播重新读取标记', () async {
    final excluded = <String>{};
    service = SystemTtsService(
      tts: plugin,
      platform: TargetPlatform.android,
      excludedVoiceKeys: (_) async => excluded,
    );
    final first = service.speak('第一段');
    await flush();
    requests.last.complete(1);
    await first;
    excluded.add(const SystemTtsVoice(name: '离线中文', locale: 'zh-CN').key);
    final second = service.speak('第二段');
    await flush();
    expect(chosenVoices.last['name'], '联网中文');
    requests.last.complete(1);
    await second;
    excluded.add(const SystemTtsVoice(name: '联网中文', locale: 'zh-CN').key);
    await expectLater(service.speak('第三段'), throwsStateError);
    verifyNever(() => plugin.setLanguage(any()));
  });
  test('引擎与显式音色一同保存，不因引擎变化清空选择', () async {
    const voice = SystemTtsVoice(name: '联网中文', locale: 'zh-CN');
    await service.saveSettings(engine: 'test.engine', voice: voice.key);
    final request = service.speak('明确选择');
    await flush();
    expect(chosenVoices.last['name'], '联网中文');
    requests.last.complete(1);
    await request;
    expect(service.selectedVoice, voice.key);
  });

  test('倍速遵循平台范围与正常值', () {
    expect(SystemTtsService.speechRate(1, 0.5, 1), 0.5);
    expect(SystemTtsService.speechRate(3, 0.5, 1), 1);
    expect(SystemTtsService.speechRate(3, 0.5, 1.5), 1.5);
    expect(SystemTtsService.speechRate(0.5, 0.5, 1), 0.25);
  });
}
