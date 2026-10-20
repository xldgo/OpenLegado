import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

// D1 回归护栏：音频焦点唯一所有者语义不变。
//
// 纯音频后端使用 just_audio，关闭自动焦点/中断及音频会话激活，
// AppAudioSession 作为唯一焦点所有者，媒体协调层解释会话恢复意图。
// 本文件从 Dart 侧钉住焦点事件处理：外部抢占（loss/lossTransient）
// 仍然暂停真实播放（流模式 pause、TTS 停止当前段），gain 恢复，
// 旧 duck 事件不再由平台产生；speech 配置映射为暂停，适配器另有行为测试。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

import '../mocks/mocks.dart';
import '../fixtures/media_artwork_loader.dart';

void main() {
  late MockRustApi mockApi;
  late MockAudioService mockAudio;
  late FakeStreamAudioPlayer fakePlayer;
  late ProviderContainer container;
  late StreamController<AudioFocusEvent> focusController;
  late StreamController<MediaButtonEvent> buttonController;

  // 播放中的周期时钟必须在Widget测试检查计时器前销毁。
  void testPlayback(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        container.dispose();
      }
    });
  }

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    mockApi = MockRustApi();
    mockAudio = MockAudioService();
    fakePlayer = FakeStreamAudioPlayer();
    focusController = StreamController<AudioFocusEvent>.broadcast();
    buttonController = StreamController<MediaButtonEvent>.broadcast();

    when(() => mockAudio.init()).thenAnswer((_) async {});
    when(() => mockAudio.isInitialized).thenReturn(true);
    when(() => mockAudio.audioFocusStream)
        .thenAnswer((_) => focusController.stream);
    when(() => mockAudio.mediaButtonStream)
        .thenAnswer((_) => buttonController.stream);
    when(() => mockAudio.requestAudioFocus()).thenAnswer((_) async => true);
    when(
      () => mockAudio.updateMetadata(
        title: any(named: 'title'),
        artist: any(named: 'artist'),
        album: any(named: 'album'),
        mediaId: any(named: 'mediaId'),
        sessionToken: any(named: 'sessionToken'),
        timerText: any(named: 'timerText'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockAudio.notifyPlaying(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => mockAudio.notifyPaused(position: any(named: 'position')))
        .thenAnswer((_) async {});
    when(() => mockAudio.notifyStopped()).thenAnswer((_) async {});
    when(() => mockAudio.setPlaying(any())).thenAnswer((_) async {});
    when(
      () => mockAudio.updatePlaybackState(
        state: any(named: 'state'),
        position: any(named: 'position'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockAudio.abandonAudioFocus()).thenAnswer((_) async {});
    when(() => mockAudio.dispose()).thenAnswer((_) async {});
    when(() => mockAudio.setWakeLock(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        streamAudioPlayerProvider.overrideWithValue(fakePlayer),
        audioServiceProvider.overrideWithValue(mockAudio),
        mediaArtworkLoaderProvider.overrideWithValue(FakeMediaArtworkLoader()),
      ]),
    );
    addTearDown(() async {
      await focusController.close();
      await buttonController.close();
    });
  });

  AudioState readState() => container.read(audioNotifierProvider);
  AudioNotifier readNotifier() =>
      container.read(audioNotifierProvider.notifier);

  /// 进入「音频书流模式播放中」
  Future<void> startStreamPlayback() async {
    when(() => mockApi.readingRepository.getChapters(any())).thenAnswer(
      (_) async => [
        const BookChapter(title: 'ch1', index: 0),
        const BookChapter(title: 'ch2', index: 1),
      ],
    );
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.audioBookService.getAudioChapterMedia(any(), any()))
        .thenAnswer((invocation) async {
          final index = invocation.positionalArguments[1] as int;
          return AudioChapterMedia.fromJson({
            'mediaUrl': 'https://cdn.example.com/$index.mp3',
            'isVolume': false,
          });
        });
    when(() => mockApi.audioBookService.getAudioProgress(any(), any()))
        .thenAnswer((_) async => 0);
    when(() => mockApi.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.audioBookService.saveAudioProgress(any(), any(), any()))
        .thenAnswer((_) async {});

    await readNotifier().initMediaSession();
    await readNotifier().loadChapters('url');
    readNotifier().setAudioBookMode(true);
    await readNotifier().play();
  }

  /// 进入「TTS 朗读播放中」
  Future<void> startTtsPlayback() async {
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => [const BookChapter(title: '第一章', index: 0)]);
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '第一段文本内容。\n\n第二段文本内容。');
    when(
      () => mockApi.httpTtsSynthesizer.synthesize(
        cancellation: any(named: 'cancellation'),
        engineId: any(named: 'engineId'),
        text: any(named: 'text'),
        engineUrl: any(named: 'engineUrl'),
        speed: any(named: 'speed'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceName: any(named: 'voiceName'),
      ),
    ).thenAnswer((_) async => HttpTtsAudio(audioPath: '/tmp/tts/para_1.wav'));

    await readNotifier().initMediaSession();
    await readNotifier().loadChapters('url');
    readNotifier().updateConfig(engineUrl: 'https://tts.example.com/{{text}}');
    await readNotifier().play();
  }

  group('流模式焦点事件（外部抢占暂停语义保留）', () {
    testPlayback('焦点拒绝时不开始播放，也不发布播放中', (tester) async {
      when(() => mockAudio.requestAudioFocus()).thenAnswer((_) async => false);
      await startStreamPlayback();
      expect(fakePlayer.playedUrls, isEmpty);
      expect(readState().state, PlayerState.error);
      verifyNever(() => mockAudio.notifyPlaying());
    });

    testPlayback('申请期间用户暂停，迟到的许可不能启动旧章节', (tester) async {
      final grant = Completer<bool>();
      when(() => mockAudio.requestAudioFocus()).thenAnswer((_) => grant.future);
      final starting = startStreamPlayback();
      await tester.pump();
      readNotifier().pause();
      grant.complete(true);
      await starting;
      expect(fakePlayer.playedUrls, isEmpty);
      expect(readState().state, PlayerState.paused);
    });

    testPlayback('恢复时焦点被拒绝，不调用播放器 resume', (tester) async {
      await startStreamPlayback();
      readNotifier().pause();
      await tester.pump();
      when(() => mockAudio.requestAudioFocus()).thenAnswer((_) async => false);
      await readNotifier().resumeOrPlay();
      expect(fakePlayer.resumeCount, 0);
      expect(readState().state, PlayerState.error);
    });

    testPlayback('lossTransient → 暂停流播放（pause，不丢弃进度）', (tester) async {
      await startStreamPlayback();
      expect(readState().state, PlayerState.playing);
      final pauseBefore = fakePlayer.pauseCount;

      focusController.add(AudioFocusEvent.lossTransient);
      await tester.pump();

      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.pauseCount, greaterThan(pauseBefore));
      expect(fakePlayer.stopCount, 0);
    });

    testPlayback('loss（永久丢失）→ 暂停流播放', (tester) async {
      await startStreamPlayback();

      focusController.add(AudioFocusEvent.loss);
      await tester.pump();

      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.pauseCount, greaterThan(0));
    });

    testPlayback('gain（暂停后）→ 恢复流播放且重新同步媒体会话', (tester) async {
      await startStreamPlayback();
      focusController.add(AudioFocusEvent.lossTransient);
      await tester.pump();
      expect(readState().state, PlayerState.paused);

      focusController.add(AudioFocusEvent.gain);
      await tester.pump();
      await tester.pump();

      expect(readState().state, PlayerState.playing);
      expect(fakePlayer.resumeCount, greaterThan(0));
      verify(() => mockAudio.requestAudioFocus()).called(greaterThan(0));
    });

    testPlayback('lossTransientCanDuck → 保持播放（可 duck，不暂停）', (tester) async {
      await startStreamPlayback();

      focusController.add(AudioFocusEvent.lossTransientCanDuck);
      await tester.pump();

      expect(readState().state, PlayerState.playing);
      expect(fakePlayer.pauseCount, 0);
    });
  });

  group('TTS 焦点事件（与流模式同链路）', () {
    testPlayback('焦点拒绝时不朗读或合成', (tester) async {
      when(() => mockAudio.requestAudioFocus()).thenAnswer((_) async => false);
      await startTtsPlayback();
      expect(fakePlayer.playedLocalFiles, isEmpty);
      expect(readState().state, PlayerState.error);
    });

    testPlayback('耳机断开式永久失焦后，gain 不自动续播', (tester) async {
      await startTtsPlayback();
      focusController.add(AudioFocusEvent.loss);
      await tester.pump();
      focusController.add(AudioFocusEvent.gain);
      await tester.pump();
      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.resumeCount, 0);
    });

    testPlayback('HTTP 恢复被拒绝时保留暂停，不恢复播放器', (tester) async {
      await startTtsPlayback();
      readNotifier().pause();
      await tester.pump();
      when(() => mockAudio.requestAudioFocus()).thenAnswer((_) async => false);
      await readNotifier().resumeOrPlay();
      expect(fakePlayer.resumeCount, 0);
      expect(readState().isPlaying, isFalse);
      expect(readState().errorMessage, contains('音频会话'));
    });

    testPlayback('loss → 原位暂停 HTTP 音频，不销毁已加载段落', (tester) async {
      await startTtsPlayback();
      expect(readState().state, PlayerState.playing);
      final stopBefore = fakePlayer.stopCount;

      focusController.add(AudioFocusEvent.loss);
      await tester.pump();

      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.stopCount, stopBefore);
      expect(fakePlayer.pauseCount, 1);
      expect(readNotifier().currentParagraphIndex, 0);
    });

    testPlayback('临时焦点中断恢复 HTTP 原位置，不重新合成；用户暂停后不自动恢复', (tester) async {
      await startTtsPlayback();
      fakePlayer.emitProgress(
        const Duration(seconds: 4),
        const Duration(seconds: 10),
      );
      focusController.add(AudioFocusEvent.lossTransient);
      await tester.pump();
      expect(readState().state, PlayerState.paused);
      focusController.add(AudioFocusEvent.gain);
      await tester.pump();
      await tester.pump();
      expect(readState().state, PlayerState.playing);
      expect(fakePlayer.resumeCount, 1);
      expect(fakePlayer.position, const Duration(seconds: 4));
      expect(fakePlayer.playedLocalFiles, hasLength(1));
      focusController.add(AudioFocusEvent.lossTransient);
      await tester.pump();
      final resumes = fakePlayer.resumeCount;
      readNotifier().pause();
      await tester.pump();
      verify(() => mockAudio.abandonAudioFocus()).called(greaterThan(0));
      focusController.add(AudioFocusEvent.gain);
      await tester.pump();
      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.resumeCount, resumes);
    });

    testPlayback('lossTransientCanDuck → 保持播放', (tester) async {
      await startTtsPlayback();

      focusController.add(AudioFocusEvent.lossTransientCanDuck);
      await tester.pump();

      expect(readState().state, PlayerState.playing);
    });
  });
}
