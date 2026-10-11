import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/system_tts_service.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

import '../mocks/mocks.dart';

class FakeSystemTts extends SystemTtsService {
  FakeSystemTts() : super(platform: TargetPlatform.android);
  final texts = <String>[];
  final requests = <Completer<SystemTtsOutcome>>[];
  bool paused = false;
  int pauses = 0;
  @override
  bool get isPaused => paused;
  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
  }) {
    paused = false;
    texts.add(text);
    final result = Completer<SystemTtsOutcome>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<void> stop() async {
    paused = false;
  }

  @override
  Future<void> pause() async {
    paused = true;
    pauses++;
  }

  @override
  Future<SystemTtsOutcome> resume() => speak(texts.last);
  @override
  Future<void> dispose() => stop();
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRustApi api;
  late FakeSystemTts system;
  late FakeStreamAudioPlayer player;
  late ProviderContainer container;
  late MockAudioService audio;
  late StreamController<AudioFocusEvent> focus;
  late StreamController<MediaButtonEvent> buttons;
  AudioNotifier notifier() => container.read(audioNotifierProvider.notifier);
  AudioState state() => container.read(audioNotifierProvider);

  setUpAll(registerFallbacks);
  setUp(() {
    api = MockRustApi();
    system = FakeSystemTts();
    player = FakeStreamAudioPlayer();
    audio = MockAudioService();
    focus = StreamController<AudioFocusEvent>.broadcast();
    buttons = StreamController<MediaButtonEvent>.broadcast();
    when(() => audio.init()).thenAnswer((_) async {});
    when(() => audio.isInitialized).thenReturn(true);
    when(() => audio.audioFocusStream).thenAnswer((_) => focus.stream);
    when(() => audio.mediaButtonStream).thenAnswer((_) => buttons.stream);
    when(() => audio.requestAudioFocus()).thenAnswer((_) async => true);
    when(
      () => audio.updateMetadata(
        title: any(named: 'title'),
        artist: any(named: 'artist'),
        album: any(named: 'album'),
      ),
    ).thenAnswer((_) async {});
    when(() => audio.notifyPlaying(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => audio.notifyPaused(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => audio.notifyStopped()).thenAnswer((_) async {});
    when(() => audio.abandonAudioFocus()).thenAnswer((_) async {});
    when(() => audio.dispose()).thenAnswer((_) async {});
    when(() => api.getChapters(any())).thenAnswer(
      (_) async => [
        const BookChapter(title: '第一章', index: 0),
        const BookChapter(title: '第二章', index: 1),
      ],
    );
    when(() => api.getBook(any())).thenAnswer((_) async => null);
    when(() => api.getChapterContentFull(any(), any())).thenAnswer(
      (call) async =>
          call.positionalArguments[1] == 0 ? '第一段。\n\n第二段。' : '下一章。',
    );
    when(() => api.getConfig(any())).thenAnswer((_) async => null);
    when(() => api.setConfig(any(), any())).thenAnswer((_) async {});
    when(
      () => api.audioSpeak(
        text: any(named: 'text'),
        engineUrl: any(named: 'engineUrl'),
        speed: any(named: 'speed'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceName: any(named: 'voiceName'),
      ),
    ).thenAnswer((_) async => '/tmp/tts.mp3');
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        systemTtsServiceProvider.overrideWithValue(system),
        streamAudioPlayerProvider.overrideWithValue(player),
        audioServiceProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await focus.close();
      await buttons.close();
    });
  });

  Future<void> start() async {
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: systemTtsEngineUrl);
    await flush();
    await notifier().play();
    await flush();
  }

  test('系统直接朗读，完成后切段切章，不进入 Rust 合成与文件播放器', () async {
    await start();
    expect(system.texts, ['第一段。']);
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(system.texts, ['第一段。', '第二段。']);
    system.requests[1].complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().currentIndex, 1);
    expect(system.texts.last, '下一章。');
    expect(player.playedLocalFiles, isEmpty);
    verifyNever(
      () => api.audioSpeak(
        text: any(named: 'text'),
        engineUrl: any(named: 'engineUrl'),
        speed: any(named: 'speed'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceName: any(named: 'voiceName'),
      ),
    );
  });

  test('快速切段后旧完成不能误推进，停止后也不续播', () async {
    await start();
    await notifier().nextParagraph();
    await flush();
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(notifier().currentParagraphIndex, 1);
    expect(system.texts.length, 2);
    notifier().stop();
    system.requests[1].complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().state, PlayerState.idle);
    expect(system.texts.length, 2);
  });

  test('暂停恢复沿用系统续读，暂停时迟到完成不切段', () async {
    await start();
    notifier().pause();
    await flush();
    expect(system.pauses, 1);
    expect(state().state, PlayerState.paused);
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(notifier().currentParagraphIndex, 0);
    await notifier().resumeOrPlay();
    await flush();
    expect(state().state, PlayerState.playing);
    expect(system.texts.length, 2);
    system.requests[1].complete(SystemTtsOutcome.completed);
    await flush();
    expect(notifier().currentParagraphIndex, 1);
  });

  test('暂停后手动切段，恢复朗读新段而不是旧暂停内容', () async {
    await start();
    notifier().pause();
    await flush();
    await notifier().nextParagraph();
    await flush();
    expect(system.isPaused, false);
    expect(state().state, PlayerState.paused);
    await notifier().resumeOrPlay();
    await flush();
    expect(system.texts.last, '第二段。');
  });

  test('临时音频中断恢复系统朗读，用户暂停后 gain 不能重新开播', () async {
    await notifier().initMediaSession();
    await start();
    focus.add(AudioFocusEvent.lossTransient);
    await flush();
    expect(state().state, PlayerState.paused);
    focus.add(AudioFocusEvent.gain);
    await flush();
    expect(state().state, PlayerState.playing);
    expect(system.texts.length, 2);
    focus.add(AudioFocusEvent.lossTransient);
    await flush();
    notifier().pause();
    focus.add(AudioFocusEvent.gain);
    await flush();
    expect(state().state, PlayerState.paused);
    expect(system.texts.length, 2);
  });

  test('媒体按钮控制系统朗读，停止后旧完成不续播', () async {
    await notifier().initMediaSession();
    await start();
    buttons.add(MediaButtonEvent.pause);
    await flush();
    expect(state().state, PlayerState.paused);
    buttons.add(MediaButtonEvent.play);
    await flush();
    expect(state().state, PlayerState.playing);
    buttons.add(MediaButtonEvent.stop);
    await flush();
    system.requests.last.complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().state, PlayerState.idle);
    expect(system.texts.length, 2);
  });

  test('系统朗读复用章末定时停止，整章完成后不自动切章', () async {
    await start();
    notifier().startChapterStop(1);
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    system.requests[1].complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().state, PlayerState.idle);
    expect(state().currentIndex, 0);
    expect(system.texts.length, 2);
  });

  test('系统失败暂停提示，不按估算时间继续', () async {
    await start();
    system.requests[0].completeError(StateError('中文语音缺失'));
    await flush();
    expect(state().state, PlayerState.paused);
    expect(state().errorMessage, contains('中文语音缺失'));
    expect(notifier().currentParagraphIndex, 0);
    expect(system.texts.length, 1);
  });

  test('系统与 HTTP 双向切换，旧系统完成不推进 HTTP 段落', () async {
    await start();
    await notifier().setGlobalTtsEngine('https://tts/{{text}}');
    await flush();
    expect(player.playedLocalFiles.length, 1);
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(notifier().currentParagraphIndex, 0);
    expect(player.playedLocalFiles.length, 1);
    await notifier().setGlobalTtsEngine(systemTtsEngineUrl);
    await flush();
    expect(system.texts.length, 2);
    player.onCompleted?.call(null);
    await flush();
    expect(system.texts.length, 2);
  });
  test('修改系统语音设置不会重启正在播放的 HTTP 音频', () async {
    await start();
    await notifier().setGlobalTtsEngine('https://tts/{{text}}');
    await flush();
    final count = player.playedLocalFiles.length;
    await notifier().refreshSystemTtsSettings();
    await flush();
    expect(player.playedLocalFiles.length, count);
    expect(state().state, PlayerState.playing);
  });

  test('书级与全局系统引擎分别持久化，恢复不需要 HTTP 数据行', () async {
    Book saved = const Book(bookUrl: 'book', name: '小说');
    when(() => api.getBook('book')).thenAnswer((_) async => saved);
    when(() => api.updateBook(any())).thenAnswer((call) async {
      saved = call.positionalArguments.first as Book;
    });
    await notifier().loadChapters('book');
    expect(await notifier().setBookTtsEngine(systemTtsEngineUrl), true);
    expect(saved.readConfig?.ttsEngine, systemTtsEngineUrl);
    expect(notifier().resolveTtsEngineUrl(), systemTtsEngineUrl);
    await notifier().setGlobalTtsEngine(systemTtsEngineUrl);
    expect(saved.readConfig?.ttsEngine, isNull);
    verify(() => api.setConfig(kTtsEngineConfigKey, systemTtsEngineUrl))
        .called(1);
    expect(notifier().resolveTtsEngineUrl(), systemTtsEngineUrl);
    verifyNever(() => api.getHttpTts());
  });

  test('暂停时切换引擎不会自动开始，恢复才播放新路径', () async {
    await start();
    notifier().pause();
    await flush();
    await notifier().setGlobalTtsEngine('https://tts/{{text}}');
    await flush();
    expect(state().state, PlayerState.paused);
    expect(player.playedLocalFiles, isEmpty);
    await notifier().resumeOrPlay();
    await flush();
    expect(player.playedLocalFiles.length, 1);
  });

  test('连续快速切章时迟到的系统完成不再跳章', () async {
    await start();
    await notifier().jumpTo(1);
    await flush();
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().currentIndex, 1);
    expect(system.texts.length, 2);
    expect(system.texts.last, '下一章。');
  });
}
