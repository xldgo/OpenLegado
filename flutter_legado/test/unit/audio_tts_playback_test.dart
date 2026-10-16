import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

// TTS 合成产物真实播放接线测试（A1 批）
//
// 覆盖：
// 1) TTS 段落播放调用链：audioSpeak 返回本地路径 → FakeStreamAudioPlayer
//    以该路径播放；段落推进由播放完成回调驱动（非 5 字/秒估算 Timer）。
// 2) 合成/播放失败 → 估算时长降级 + 用户可见提示（errorMessage，不静默）。
// 3) 停止后不再推进，且在途合成失效（不落播放）。
// 4) 段落队列：手动切段先停旧音频再合成新段（不叠音）。
// 5) 回归：音频书网络流路径（playUrl + 完成回调驱动下一章）不受影响。
//
// 计时推进用 testWidgets 的 FakeAsync（tester.pump(duration) 推时钟），
// 播放器经 streamAudioPlayerProvider 注入 Fake，不触真实 video_player 平台通道。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;
  late FakeStreamAudioPlayer fakePlayer;
  late ProviderContainer container;

  /// audioSpeak 入参语速记录（每用例清空）
  final speakSpeeds = <double>[];

  /// audioSpeak 按调用序返回的本地路径（每用例可覆写）
  String Function(int call) pathFor = (call) => '/tmp/tts/para_$call.mp3';

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => const [
        HttpTts(id: 1, name: '默认引擎', url: 'https://tts.example.com/{{text}}'),
      ],
    );
    fakePlayer = FakeStreamAudioPlayer();
    speakSpeeds.clear();
    pathFor = (call) => '/tmp/tts/para_$call.mp3';
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        streamAudioPlayerProvider.overrideWithValue(fakePlayer),
      ]),
    );
    addTearDown(container.dispose);
  });

  AudioState readState() => container.read(audioNotifierProvider);
  AudioNotifier readNotifier() =>
      container.read(audioNotifierProvider.notifier);

  /// 单章 + 指定正文
  void stubChapter({String content = '第一段文本内容。\n\n第二段文本内容。'}) {
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => [const BookChapter(title: '第一章', index: 0)]);
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => content);
  }

  /// audioSpeak 按调用序返回不同本地路径，并记录入参语速
  void stubAudioSpeak() {
    var calls = 0;
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
    ).thenAnswer((invocation) async {
      speakSpeeds.add(invocation.namedArguments[#speed] as double);
      return HttpTtsAudio(audioPath: pathFor(++calls));
    });
  }

  Future<void> startTts({double speed = 1.0}) async {
    stubChapter();
    stubAudioSpeak();
    await readNotifier().loadChapters('url');
    readNotifier().updateConfig(
      engineUrl: 'https://tts.example.com/{{text}}',
      engineId: 1,
    );
    readNotifier().updateConfig(speed: speed);
    await readNotifier().play();
  }

  group('TTS 段落真实播放（完成回调驱动）', () {
    testWidgets('audioSpeak 返回 audioPath → 播放该本地文件', (tester) async {
      await startTts(speed: 2.0);

      expect(readState().state, PlayerState.playing);
      expect(fakePlayer.playedLocalFiles, hasLength(1));
      expect(fakePlayer.playedLocalFiles.first.path, '/tmp/tts/para_1.mp3');
      // 语速在合成与播放侧均生效（对齐 Issue 3：全局倍速 request.speed）
      expect(speakSpeeds, [2.0]);
      expect(fakePlayer.playedLocalFiles.first.speed, 2.0);
      expect(readState().errorMessage, isNull);
    });

    testWidgets('段落推进由播放完成回调触发（估算 Timer 不推进）', (tester) async {
      await startTts();
      expect(readNotifier().currentParagraphIndex, 0);
      expect(fakePlayer.playedLocalFiles, hasLength(1));

      // 显式推进 30s 假时钟：若仍是 5 字/秒估算 Timer 驱动，段落会前进
      await tester.pump(const Duration(seconds: 30));
      expect(
        readNotifier().currentParagraphIndex,
        0,
        reason: '完成回调前不得推进（估算 Timer 仅失败降级）',
      );
      expect(fakePlayer.playedLocalFiles, hasLength(1));

      // 播放完成 → 推进到第 2 段并合成播放
      fakePlayer.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(readNotifier().currentParagraphIndex, 1);
      expect(fakePlayer.playedLocalFiles, hasLength(2));
      expect(fakePlayer.playedLocalFiles.last.path, '/tmp/tts/para_2.mp3');

      // 末段完成且无下一章 → 停止
      fakePlayer.completePlayback();
      await tester.pump();
      await tester.pump();
      expect(readState().state, PlayerState.idle);
    });

    testWidgets('手动切段：先停旧音频再合成播放新段（不叠音）', (tester) async {
      await startTts();
      final stopBefore = fakePlayer.stopCount;

      await readNotifier().nextParagraph();
      await tester.pump();

      expect(readNotifier().currentParagraphIndex, 1);
      expect(fakePlayer.stopCount, greaterThan(stopBefore));
      expect(fakePlayer.playedLocalFiles, hasLength(2));
      expect(fakePlayer.playedLocalFiles.last.path, '/tmp/tts/para_2.mp3');
    });
  });

  group('失败降级（估算时长 + 用户可见提示）', () {
    testWidgets('本地播放失败 → 提示 + 估算时长推进', (tester) async {
      stubChapter();
      stubAudioSpeak();
      await readNotifier().loadChapters('url');
      readNotifier().updateConfig(
        engineUrl: 'https://tts.example.com/{{text}}',
      );
      fakePlayer.playLocalError = StateError('MissingPluginException');

      await readNotifier().play();

      expect(readState().state, PlayerState.playing);
      expect(readState().errorMessage, isNotNull);
      expect(readState().errorMessage, contains('估算时长'));
      expect(fakePlayer.playedLocalFiles, isEmpty);

      // 估算时长（8 字 / 5 字每秒 ≈ 1.6s）到点推进（第二段约 3.2s 才到点，
      // 此处只推到第一段到点，随后 stop 取消未决定时器）
      await tester.pump(const Duration(seconds: 2));
      expect(readNotifier().currentParagraphIndex, 1);
      readNotifier().stop();
    });

    testWidgets('合成失败 → 提示 + 估算时长推进', (tester) async {
      stubChapter();
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
      ).thenThrow(StateError('引擎不可达'));
      await readNotifier().loadChapters('url');
      readNotifier().updateConfig(
        engineUrl: 'https://tts.example.com/{{text}}',
      );

      await readNotifier().play();

      expect(readState().state, PlayerState.playing);
      expect(readState().errorMessage, contains('引擎不可达'));
      expect(fakePlayer.playedLocalFiles, isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(readNotifier().currentParagraphIndex, 1);
      readNotifier().stop();
    });

    testWidgets('合成返回空路径 → 视为失败降级并提示', (tester) async {
      stubChapter();
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
      ).thenAnswer(
        (_) async => const HttpTtsNoAudio(HttpTtsNoAudioReason.emptyResult),
      );
      await readNotifier().loadChapters('url');
      readNotifier().updateConfig(
        engineUrl: 'https://tts.example.com/{{text}}',
      );

      await readNotifier().play();

      expect(readState().errorMessage, contains('估算时长'));
      expect(fakePlayer.playedLocalFiles, isEmpty);
      // 取消降级估算定时器，避免用例结束仍有 pending timer
      readNotifier().stop();
    });
  });

  group('停止/取消', () {
    testWidgets('stop 后在途合成失效、完成回调不再推进', (tester) async {
      stubChapter();
      final completer = Completer<HttpTtsSynthesisResult>();
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
      ).thenAnswer((_) => completer.future);
      await readNotifier().loadChapters('url');
      readNotifier().updateConfig(
        engineUrl: 'https://tts.example.com/{{text}}',
      );

      final playFuture = readNotifier().play();
      await tester.pump();
      expect(readState().state, PlayerState.playing);

      readNotifier().stop();
      expect(readState().state, PlayerState.idle);

      // 在途合成迟到返回：不得落播放
      completer.complete(const HttpTtsAudio(audioPath: '/tmp/tts/late.mp3'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(fakePlayer.playedLocalFiles, isEmpty);
      expect(readNotifier().currentParagraphIndex, 0);

      // 停止后的迟到完成回调同样被忽略
      fakePlayer.completePlayback();
      await tester.pump(const Duration(seconds: 5));
      expect(readNotifier().currentParagraphIndex, 0);

      await playFuture;
    });

    testWidgets('暂停后从同一音频位置续播，新会话完成推进且旧会话无效', (tester) async {
      await startTts();
      final notifier = readNotifier();
      final oldTag = fakePlayer.currentTag;
      final stops = fakePlayer.stopCount;
      fakePlayer.emitProgress(
        const Duration(seconds: 4),
        const Duration(seconds: 10),
      );
      final offset = notifier.readAloudPosition.value!.offset;
      notifier.pause();
      await tester.pump();
      expect(readState().state, PlayerState.paused);
      expect(fakePlayer.stopCount, stops);
      expect(fakePlayer.pauseCount, 1);
      await notifier.resumeOrPlay();
      expect(fakePlayer.position, const Duration(seconds: 4));
      expect(fakePlayer.resumeCount, 1);
      expect(fakePlayer.playedLocalFiles, hasLength(1));
      expect(speakSpeeds, hasLength(1));
      expect(fakePlayer.currentTag, isNot(same(oldTag)));
      fakePlayer.emitProgressForTag(
        oldTag,
        Duration.zero,
        const Duration(seconds: 10),
      );
      fakePlayer.completePlaybackForTag(oldTag);
      await tester.pump();
      expect(notifier.readAloudPosition.value!.offset, offset);
      expect(notifier.currentParagraphIndex, 0);
      fakePlayer.emitProgress(
        const Duration(seconds: 6),
        const Duration(seconds: 10),
      );
      expect(notifier.readAloudPosition.value!.offset, greaterThan(offset));
      fakePlayer.completePlayback();
      fakePlayer.completePlayback();
      await tester.pump();
      await tester.pump();
      expect(notifier.currentParagraphIndex, 1);
      expect(fakePlayer.playedLocalFiles, hasLength(2));
    });

    testWidgets('从段内起点朗读，暂停续播仍按原请求映射正文偏移', (tester) async {
      await startTts();
      final notifier = readNotifier();
      notifier.pause();
      await tester.pump();
      await notifier.seekToChapterPosition(0, 2);
      await notifier.resumeOrPlay();
      final paragraphLength = notifier.currentParagraphs.first.length;
      fakePlayer.emitProgress(
        const Duration(seconds: 4),
        const Duration(seconds: 10),
      );
      final offset = notifier.readAloudPosition.value!.offset;
      notifier.pause();
      await tester.pump();
      await notifier.resumeOrPlay();
      expect(fakePlayer.playedLocalFiles, hasLength(2));
      expect(speakSpeeds, hasLength(2));
      fakePlayer.emitProgress(
        const Duration(seconds: 4),
        const Duration(seconds: 10),
      );
      expect(notifier.readAloudPosition.value!.offset, offset);
      fakePlayer.emitProgress(
        const Duration(seconds: 6),
        const Duration(seconds: 10),
      );
      expect(
        notifier.readAloudPosition.value!.offset,
        2 + ((paragraphLength - 2) * 0.6).floor(),
      );
    });

    testWidgets('快速暂停恢复等待确认，等待时停止不再恢复', (tester) async {
      await startTts();
      final barrier = Completer<void>();
      fakePlayer.pauseBarrier = barrier.future;
      readNotifier().pause();
      final resume = readNotifier().resumeOrPlay();
      await tester.pump();
      expect(fakePlayer.resumeCount, 0);
      readNotifier().stop();
      barrier.complete();
      await resume;
      await tester.pump();
      expect(readState().state, PlayerState.idle);
      expect(fakePlayer.resumeCount, 0);
      expect(fakePlayer.playedLocalFiles, hasLength(1));
    });

    testWidgets('暂停后手动换段重新起播，不复用上一段音频', (tester) async {
      await startTts();
      readNotifier().pause();
      await tester.pump();
      await readNotifier().nextParagraph();
      await readNotifier().resumeOrPlay();
      expect(readNotifier().currentParagraphIndex, 1);
      expect(fakePlayer.resumeCount, 0);
      expect(fakePlayer.playedLocalFiles.last.path, '/tmp/tts/para_2.mp3');
    });

    testWidgets('暂停后更换 HTTP 引擎使原音频失效', (tester) async {
      await startTts();
      readNotifier().pause();
      await tester.pump();
      readNotifier().updateConfig(
        engineUrl: 'https://other.example.com/{{text}}',
        engineId: 2,
      );
      await tester.pump();
      await readNotifier().resumeOrPlay();
      expect(fakePlayer.resumeCount, 0);
      expect(fakePlayer.playedLocalFiles, hasLength(2));
    });

    testWidgets('暂停期间更改倍速保留音频，续播失败保持暂停并显示错误', (tester) async {
      await startTts();
      readNotifier().pause();
      await tester.pump();
      readNotifier().updateConfig(speed: 1.5);
      fakePlayer.resumeError = StateError('设备恢复失败');
      await readNotifier().resumeOrPlay();
      await tester.pump();
      expect(readState().state, PlayerState.paused);
      expect(readState().errorMessage, contains('设备恢复失败'));
      expect(fakePlayer.playedLocalFiles, hasLength(1));
      expect(readNotifier().currentParagraphIndex, 0);
    });
  });

  for (final hasAudio in [true, false]) {
    testWidgets('独立覆盖合成接口：${hasAudio ? '缓存音频正常播放' : '探活成功仍提示并估算'}', (
      tester,
    ) async {
      stubChapter();
      final synthesis = MockHttpTtsSynthesizer();
      when(
        () => synthesis.synthesize(
          cancellation: any(named: 'cancellation'),
          engineId: any(named: 'engineId'),
          text: any(named: 'text'),
          engineUrl: any(named: 'engineUrl'),
          speed: any(named: 'speed'),
          pitch: any(named: 'pitch'),
          volume: any(named: 'volume'),
          voiceName: any(named: 'voiceName'),
        ),
      ).thenAnswer(
        (_) async => hasAudio
            ? const HttpTtsAudio(
                audioPath: '/cache/independent.wav',
                fromCache: true,
                contentType: 'audio/wav',
              )
            : const HttpTtsNoAudio(HttpTtsNoAudioReason.synthesisFailed),
      );
      final isolated = ProviderContainer(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          streamAudioPlayerProvider.overrideWithValue(fakePlayer),
          httpTtsSynthesizerProvider.overrideWithValue(synthesis),
        ]),
      );
      addTearDown(isolated.dispose);
      final notifier = isolated.read(audioNotifierProvider.notifier);
      await notifier.loadChapters('url');
      notifier.updateConfig(engineUrl: 'https://tts.example.com/{{text}}');
      await notifier.play();
      if (hasAudio) {
        expect(
          fakePlayer.playedLocalFiles.single.path,
          '/cache/independent.wav',
        );
        expect(isolated.read(audioNotifierProvider).errorMessage, isNull);
      } else {
        expect(fakePlayer.playedLocalFiles, isEmpty);
        expect(
          isolated.read(audioNotifierProvider).errorMessage,
          contains('估算时长'),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(notifier.currentParagraphIndex, 1);
      }
      verifyNever(
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
      );
      notifier.stop();
    });
  }

  group('网络流（音频书）路径回归', () {
    testWidgets('playUrl 播放 + 完成回调驱动下一章', (tester) async {
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

      await readNotifier().loadChapters('url');
      readNotifier().setAudioBookMode(true);
      await readNotifier().play();

      expect(readState().state, PlayerState.playing);
      expect(fakePlayer.playedUrls, ['https://cdn.example.com/0.mp3']);
      expect(fakePlayer.playedLocalFiles, isEmpty);

      fakePlayer.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(readState().currentIndex, 1);
      expect(fakePlayer.playedUrls, [
        'https://cdn.example.com/0.mp3',
        'https://cdn.example.com/1.mp3',
      ]);
    });
  });
}
