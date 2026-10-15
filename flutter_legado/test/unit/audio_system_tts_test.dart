import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/audio/read_aloud_preferences.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

import '../mocks/mocks.dart';
import '../fixtures/media_artwork_loader.dart';

class FakeSystemTts extends Fake implements SystemTts {
  @override
  bool get isSupported => true;
  @override
  void Function(int start, int end)? onProgress;
  final texts = <String>[];
  final speeds = <double>[];
  final requests = <Completer<SystemTtsOutcome>>[];
  bool paused = false;
  int pauses = 0;
  Future<void>? pendingPause;
  @override
  bool get isPaused => paused;
  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  }) {
    paused = false;
    texts.add(text);
    speeds.add(speed);
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
    paused = requests.isNotEmpty && !requests.last.isCompleted;
    pauses++;
    await pendingPause;
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
    SharedPreferences.setMockInitialValues({});
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
        mediaId: any(named: 'mediaId'),
        sessionToken: any(named: 'sessionToken'),
        timerText: any(named: 'timerText'),
      ),
    ).thenAnswer((_) async {});
    when(() => audio.notifyPlaying(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => audio.notifyPaused(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => audio.notifyStopped()).thenAnswer((_) async {});
    when(() => audio.abandonAudioFocus()).thenAnswer((_) async {});
    when(() => audio.dispose()).thenAnswer((_) async {});
    when(() => api.readingRepository.getChapters(any())).thenAnswer(
      (_) async => [
        const BookChapter(title: '第一章', index: 0),
        const BookChapter(title: '第二章', index: 1),
      ],
    );
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer(
          (call) async =>
              call.positionalArguments[1] == 0 ? '第一段。\n\n第二段。' : '下一章。',
        );
    when(() => api.getConfig(any())).thenAnswer((_) async => null);
    when(() => api.setConfig(any(), any())).thenAnswer((_) async {});
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
    ).thenAnswer((_) async => HttpTtsAudio(audioPath: '/tmp/tts.mp3'));
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        systemTtsServiceProvider.overrideWithValue(system),
        streamAudioPlayerProvider.overrideWithValue(player),
        audioServiceProvider.overrideWithValue(audio),
        mediaArtworkLoaderProvider.overrideWithValue(FakeMediaArtworkLoader()),
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

  test('真实范围发布原文位置，手动切段后旧回调不能串入新段', () async {
    await start();
    final oldProgress = system.onProgress!;
    oldProgress(1, 3);
    expect(notifier().readAloudPosition.value!.offset, 1);
    expect(notifier().readAloudPosition.value!.paragraphStart, 0);
    expect(notifier().readAloudPosition.value!.paragraphEnd, 4);
    await notifier().seekToParagraph(1);
    expect(notifier().readAloudPosition.value!.paragraphStart, 6);
    oldProgress(2, 4);
    expect(notifier().readAloudPosition.value!.offset, 6);
    system.onProgress!(1, 3);
    expect(notifier().readAloudPosition.value!.offset, 7);
    notifier().detachReadAloudFollow();
    expect(notifier().followReadAloud.value, false);
    final speaks = system.texts.length;
    notifier().restoreReadAloudFollow();
    expect(system.texts.length, speaks);
    notifier().pause();
    await flush();
    system.onProgress!(2, 4);
    expect(notifier().readAloudPosition.value!.offset, 7);
    notifier().stop();
    expect(notifier().readAloudPosition.value, isNull);
  });

  test('暂停时按章节原文定位仍保持暂停，恢复只读目标后缀', () async {
    await start();
    notifier().pause();
    await flush();
    await notifier().seekToChapterPosition(1, 2);
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    expect(notifier().readAloudPosition.value!.chapterIndex, 1);
    expect(notifier().readAloudPosition.value!.offset, 2);
    final count = system.texts.length;
    await notifier().resumeOrPlay();
    await flush();
    expect(system.texts.length, count + 1);
    expect(system.texts.last, '章。');
  });

  for (final paused in [true, false]) {
    test('原文拖动定位保留组合字符，播放态不变：暂停=$paused', () async {
      const content = '  甲e\u0301👨‍👩‍👧‍👦乙。\r\n\n 末段。';
      when(() => api.readingRepository.getChapterContentFull(any(), any()))
          .thenAnswer((_) async => content);
      await start();
      if (paused) {
        notifier().pause();
        await flush();
      }
      final requests = system.texts.length;
      final anchor = content.indexOf('👨');
      await notifier().seekToChapterPosition(0, anchor + 3);
      await flush();
      expect(state().state, paused ? PlayerState.paused : PlayerState.playing);
      expect(notifier().readAloudPosition.value!.offset, anchor);
      if (paused) {
        expect(system.texts.length, requests);
        await notifier().resumeOrPlay();
        await flush();
      }
      expect(system.texts.last, startsWith('👨‍👩‍👧‍👦乙。'));
      system.onProgress!(0, 11);
      expect(notifier().readAloudPosition.value!.offset, anchor);
    });
  }

  test('HTTP 进度估算原文位置，切段后的旧音频事件被丢弃', () async {
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: 'https://tts.test');
    await flush();
    await notifier().play();
    await flush();
    final oldTag = player.currentTag;
    player.onProgress!(
      const Duration(seconds: 5),
      const Duration(seconds: 10),
      oldTag,
    );
    expect(notifier().readAloudPosition.value!.offset, 2);
    await notifier().seekToParagraph(1);
    player.onProgress!(
      const Duration(seconds: 9),
      const Duration(seconds: 10),
      oldTag,
    );
    player.onCompleted!(oldTag);
    await flush();
    expect(notifier().readAloudPosition.value!.offset, 6);
    expect(notifier().currentParagraphIndex, 1);
    player.onProgress!(
      const Duration(seconds: 5),
      const Duration(seconds: 10),
      player.currentTag,
    );
    expect(notifier().readAloudPosition.value!.offset, 8);
  });

  test('播放器暂停中点击正文只移动位置，恢复后读目标段', () async {
    await start();
    notifier().pause();
    await flush();
    await notifier().seekToParagraph(1);
    await flush();
    expect(state().state, PlayerState.paused);
    expect(notifier().currentParagraphIndex, 1);
    expect(system.texts, ['第一段。']);
    await notifier().resumeOrPlay();
    await flush();
    expect(system.texts.last, '第二段。');
  });

  test('播放器播放中拖动到目标段，旧段完成回调不能再推进', () async {
    await start();
    final previousSpeech = system.requests.first;
    await notifier().seekToParagraph(1);
    await flush();
    expect(state().state, PlayerState.playing);
    expect(system.texts.last, '第二段。');
    previousSpeech.complete(SystemTtsOutcome.completed);
    await flush();
    expect(state().currentIndex, 0);
    expect(notifier().currentParagraphIndex, 1);
    expect(system.texts, ['第一段。', '第二段。']);
  });

  test('正文快照不可修改，切章等待期间隐藏上一章正文', () async {
    await start();
    expect(notifier().currentParagraphs, ['第一段。', '第二段。']);
    expect(
      () => notifier().currentParagraphs.add('伪造正文'),
      throwsUnsupportedError,
    );
    final chapter = Completer<String>();
    when(() => api.readingRepository.getChapterContentFull('book', 1))
        .thenAnswer((_) => chapter.future);
    final pending = notifier().next();
    await flush();
    expect(notifier().currentParagraphs, isEmpty);
    chapter.complete('新章节正文。');
    await pending;
    expect(notifier().currentParagraphs, ['新章节正文。']);
    notifier().stop();
    expect(notifier().currentParagraphs, isEmpty);
  });

  test('当前正文起点保留段内偏移，换段后恢复完整正文', () async {
    notifier().updateConfig(
      engineUrl: systemTtsEngineUrl,
      restartPlayback: false,
    );
    const content = '  第一段。\r\n\n  第二段内容。';
    when(() => api.readingRepository.getChapterContentFull('book', 0))
        .thenAnswer((_) async => content);
    await notifier().startReadAloud(
      bookUrl: 'book',
      bookName: '小说',
      startChapterPos: content.indexOf('内容'),
    );
    await flush();
    expect(system.texts, ['内容。']);
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(system.texts.last, '下一章。');
  });

  test('HTTP 合成同样使用选区段内起点，重复段不误定位', () async {
    const content = '相同正文。\r\n  相同正文。';
    when(() => api.readingRepository.getChapterContentFull('book', 0))
        .thenAnswer((_) async => content);
    notifier().updateConfig(
      engineUrl: 'https://tts/{{text}}',
      restartPlayback: false,
    );
    await notifier().startReadAloud(
      bookUrl: 'book',
      bookName: '小说',
      startChapterPos: content.lastIndexOf('正文'),
    );
    await flush();
    verify(
      () => api.httpTtsSynthesizer.synthesize(
        cancellation: any(named: 'cancellation'),
        engineId: any(named: 'engineId'),
        text: '正文。',
        engineUrl: 'https://tts/{{text}}',
        speed: 1,
        pitch: 1,
        volume: 1,
        voiceName: null,
      ),
    ).called(1);
    expect(player.playedLocalFiles.length, 1);
    expect(system.texts, isEmpty);
  });

  test('从段中开始后切换系统参数仍保留起点，手动切段读完整正文', () async {
    notifier().updateConfig(
      engineUrl: systemTtsEngineUrl,
      restartPlayback: false,
    );
    await notifier().startReadAloud(
      bookUrl: 'book',
      bookName: '小说',
      startChapterPos: 2,
    );
    await flush();
    expect(system.texts, ['段。']);
    await notifier().refreshSystemTtsSettings();
    await flush();
    expect(system.texts.last, '段。');
    await notifier().nextParagraph();
    await flush();
    expect(system.texts.last, '第二段。');
  });

  test('正文还在加载时停止，迟到结果不能重新起播', () async {
    final content = Completer<String>();
    when(() => api.readingRepository.getChapterContentFull('book', 0))
        .thenAnswer((_) => content.future);
    notifier().updateConfig(
      engineUrl: systemTtsEngineUrl,
      restartPlayback: false,
    );
    final pending = notifier().startReadAloud(bookUrl: 'book', bookName: '小说');
    await flush();
    notifier().stop();
    content.complete('迟到正文');
    await pending;
    await flush();
    expect(system.texts, isEmpty);
    expect(state().state, PlayerState.idle);
  });

  test('段间停顿实际延迟播放，暂停后不会迟到续播', () async {
    await container
        .read(readAloudPreferencesProvider.notifier)
        .setParagraphInterval(100);
    await start();
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(system.texts, ['第一段。']);
    notifier().pause();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(system.texts, ['第一段。']);
    expect(state().state, PlayerState.paused);
    await notifier().resumeOrPlay();
    await flush();
    expect(system.texts.last, '第二段。');
  });

  test('HTTP 完成在段间停顿内只推进一次，旧进度不能写入下一段', () async {
    await container
        .read(readAloudPreferencesProvider.notifier)
        .setParagraphInterval(100);
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: 'https://tts.test');
    await flush();
    await notifier().play();
    final tag = player.currentTag;
    player.onCompleted!(tag);
    player.onCompleted!(tag);
    player.onProgress!(
      const Duration(seconds: 8),
      const Duration(seconds: 10),
      tag,
    );
    await flush();
    expect(notifier().currentParagraphIndex, 1);
    expect(player.playedLocalFiles.length, 1);
    expect(notifier().readAloudPosition.value!.paragraphIndex, 0);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await flush();
    expect(player.playedLocalFiles.length, 2);
    expect(notifier().readAloudPosition.value!.paragraphIndex, 1);
    notifier().stop();
  });

  test('旧暂停操作迟到报错不能暂停已经切换的 HTTP 朗读', () async {
    await start();
    final pending = Completer<void>();
    system.pendingPause = pending.future;
    notifier().pause();
    notifier().updateConfig(engineUrl: 'https://tts.test');
    await flush();
    await notifier().resumeOrPlay();
    await flush();
    expect(state().state, PlayerState.playing);
    expect(player.playedLocalFiles, isNotEmpty);
    pending.completeError(StateError('旧暂停失败'));
    await flush();
    expect(state().state, PlayerState.playing);
    expect(state().errorMessage, isNull);
    notifier().stop();
  });

  test('当前暂停控制失败仍显示错误并保持暂停', () async {
    await start();
    final pending = Completer<void>();
    system.pendingPause = pending.future;
    notifier().pause();
    pending.completeError(StateError('当前暂停失败'));
    await flush();
    expect(state().state, PlayerState.paused);
    expect(state().errorMessage, contains('当前暂停失败'));
  });

  test('切换系统引擎后迟到的 HTTP 合成错误不写入当前会话', () async {
    final pending = Completer<HttpTtsSynthesisResult>();
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
    ).thenAnswer((_) => pending.future);
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: 'https://tts.test');
    final playing = notifier().play();
    await flush();
    notifier().updateConfig(engineUrl: systemTtsEngineUrl);
    await flush();
    expect(system.texts, isNotEmpty);
    pending.completeError(StateError('旧合成失败'));
    await playing;
    await flush();
    expect(state().state, PlayerState.playing);
    expect(state().errorMessage, isNull);
    expect(player.playedLocalFiles, isEmpty);
  });

  test('当前 HTTP 暂停控制失败被接收，不形成未处理的异步错误', () async {
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: 'https://tts.test');
    await notifier().play();
    final pending = Completer<void>();
    player.pauseBarrier = pending.future;
    notifier().pause();
    pending.completeError(StateError('文件播放暂停失败'));
    await flush();
    expect(state().state, PlayerState.paused);
    expect(state().errorMessage, contains('文件播放暂停失败'));
  });

  test('旧 HTTP 暂停控制失败不能改写恢复后的播放状态', () async {
    await notifier().loadChapters('book');
    notifier().updateConfig(engineUrl: 'https://tts.test');
    await notifier().play();
    final pending = Completer<void>();
    player.pauseBarrier = pending.future;
    notifier().pause();
    notifier().updateConfig(engineUrl: 'https://other.tts.test', engineId: 2);
    await flush();
    await notifier().resumeOrPlay();
    pending.completeError(StateError('旧文件播放暂停失败'));
    await flush();
    expect(state().state, PlayerState.playing);
    expect(state().errorMessage, isNull);
    notifier().stop();
  });

  test('自然换段遵循段间停顿', () async {
    await container
        .read(readAloudPreferencesProvider.notifier)
        .setParagraphInterval(100);
    await start();
    system.requests[0].complete(SystemTtsOutcome.completed);
    await flush();
    expect(system.texts, ['第一段。']);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await flush();
    expect(system.texts, ['第一段。', '第二段。']);
  });

  test('旧书级手动语速迁移到独立偏好，跟随开关不会丢失原值', () async {
    when(() => api.getConfig('ttsFollowSys')).thenAnswer((_) async => 'false');
    when(() => api.bookshelfRepository.getBook('book')).thenAnswer(
      (_) async => const Book(
        bookUrl: 'book',
        name: '小说',
        readConfig: ReadConfig(playSpeed: 1.7),
      ),
    );
    notifier().updateConfig(
      engineUrl: systemTtsEngineUrl,
      restartPlayback: false,
    );
    await notifier().startReadAloud(bookUrl: 'book', bookName: '小说');
    await flush();
    expect(system.speeds.last, 1.7);
    verify(() => api.setConfig('ttsSpeechRate', '12')).called(1);
    await notifier().setReadAloudFollowSystem(true);
    await flush();
    expect(system.speeds.last, 1);
    await notifier().setReadAloudFollowSystem(false);
    await flush();
    expect(system.speeds.last, 1.7);
  });

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
    player.onCompleted?.call(player.currentTag);
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
    when(() => api.bookshelfRepository.getBook('book'))
        .thenAnswer((_) async => saved);
    when(() => api.bookshelfRepository.updateBook(any()))
        .thenAnswer((call) async {
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
    verifyNever(() => api.httpTtsRepository.getHttpTts());
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
