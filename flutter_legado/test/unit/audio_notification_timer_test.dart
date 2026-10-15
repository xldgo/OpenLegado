import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

// 书名为主标题、章节为次标题；定时使用独立字段。— Codex + UI
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';
import 'package:flutter_legado/src/providers/audio/read_aloud_preferences.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';

import '../mocks/mocks.dart';
import '../fixtures/media_artwork_loader.dart';

class _Privacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);
  void replace(PrivacyState value) => state = value;
}

void main() {
  late MockRustApi mockApi;
  late MockAudioService mockAudio;
  late FakeStreamAudioPlayer fakePlayer;
  late ProviderContainer container;
  late StreamController<AudioFocusEvent> focusController;
  late StreamController<MediaButtonEvent> buttonController;
  late FakeMediaArtworkLoader artworkLoader;
  late List<({String mediaId, int token, Uint8List? bytes})> artworkCalls;
  late List<MediaPlaybackProgress> progressCalls;
  late int clock;

  /// 记录实际发送的书名、章节及独立定时信息
  late List<
    ({
      String title,
      String artist,
      String album,
      String timerText,
      String mediaId,
      int sessionToken,
    })
  >
  metadataCalls;

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

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.setConfig(any(), any())).thenAnswer((_) async {});
    mockAudio = MockAudioService();
    fakePlayer = FakeStreamAudioPlayer();
    focusController = StreamController<AudioFocusEvent>.broadcast();
    buttonController = StreamController<MediaButtonEvent>.broadcast();
    metadataCalls = [];
    artworkCalls = [];
    progressCalls = [];
    clock = 0;
    artworkLoader = FakeMediaArtworkLoader();

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
    ).thenAnswer((invocation) async {
      metadataCalls.add((
        title: invocation.namedArguments[#title] as String,
        artist: invocation.namedArguments[#artist] as String,
        album: invocation.namedArguments[#album] as String,
        timerText: invocation.namedArguments[#timerText] as String,
        mediaId: invocation.namedArguments[#mediaId] as String,
        sessionToken: invocation.namedArguments[#sessionToken] as int,
      ));
    });
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
    when(() => mockAudio.updateProgress(any())).thenAnswer((call) async {
      progressCalls.add(
        call.positionalArguments.single as MediaPlaybackProgress,
      );
    });
    when(
      () => mockAudio.updateArtwork(
        mediaId: any(named: 'mediaId'),
        sessionToken: any(named: 'sessionToken'),
        artworkBytes: any(named: 'artworkBytes'),
      ),
    ).thenAnswer((call) async {
      artworkCalls.add((
        mediaId: call.namedArguments[#mediaId] as String,
        token: call.namedArguments[#sessionToken] as int,
        bytes: call.namedArguments[#artworkBytes] as Uint8List?,
      ));
    });

    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(mockApi),
        streamAudioPlayerProvider.overrideWithValue(fakePlayer),
        audioServiceProvider.overrideWithValue(mockAudio),
        mediaArtworkLoaderProvider.overrideWithValue(artworkLoader),
        privacyControllerProvider.overrideWith(_Privacy.new),
        mediaMonotonicClockProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(() async {
      await focusController.close();
      await buttonController.close();
    });
  });

  AudioState readState() => container.read(audioNotifierProvider);
  AudioNotifier readNotifier() =>
      container.read(audioNotifierProvider.notifier);

  /// 进入「音频书流媒体播放中」（书名经 initMediaSession 绑定）
  Future<void> startStreamPlayback({
    String bookName = '测试书',
    int chapterCount = 3,
  }) async {
    when(() => mockApi.readingRepository.getChapters(any())).thenAnswer(
      (_) async => List.generate(
        chapterCount,
        (i) => BookChapter(title: 'ch${i + 1}', index: i),
      ),
    );
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.getAudioChapterMedia(any(), any()))
        .thenAnswer((invocation) async {
          final index = invocation.positionalArguments[1] as int;
          return {
            'mediaUrl': 'https://cdn.example.com/$index.mp3',
            'isVolume': false,
          };
        });
    when(() => mockApi.getAudioProgress(any(), any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.saveAudioProgress(any(), any(), any()))
        .thenAnswer((_) async {});

    await readNotifier().initMediaSession(bookName: bookName);
    await readNotifier().loadChapters('url');
    readNotifier().setAudioBookMode(true);
    await readNotifier().play();
  }

  /// 进入「TTS 朗读播放中」
  Future<void> startTtsPlayback({String bookName = '测试书'}) async {
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => [const BookChapter(title: '第一章', index: 0)]);
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '第一段文本内容。');
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
    ).thenAnswer((_) async => HttpTtsAudio(audioPath: '/tmp/tts/para.mp3'));

    await readNotifier().initMediaSession(bookName: bookName);
    await readNotifier().loadChapters('url');
    readNotifier().updateConfig(engineUrl: 'https://tts.example.com/{{text}}');
    await readNotifier().play();
  }

  testPlayback('a) 未启用定时：书名和章节分开，不含播放前缀', (tester) async {
    await startStreamPlayback();
    expect(metadataCalls, isNotEmpty);
    expect(metadataCalls.last.timerText, '');
    expect(metadataCalls.last.timerText.contains('剩余'), isFalse);
    expect(metadataCalls.last.artist, 'ch1');
    expect(metadataCalls.last.title, '测试书'); // 主标题保持书名
    expect(metadataCalls.last.album, '测试书');
    expect(readNotifier().sleepTimerRemainingLabel, isEmpty);

    // 0 视同关闭：不得出现「剩余 0」
    readNotifier().startSleepTimer(0);
    expect(readNotifier().sleepTimerRemainingLabel, isEmpty);
    expect(metadataCalls.last.timerText, '');
  });

  testPlayback('b) 按章停止 N 章：定时字段含「剩余 N 章」，章末计数刷新', (tester) async {
    await startStreamPlayback();
    readNotifier().startChapterStop(3);

    expect(readNotifier().sleepTimerRemainingLabel, '剩余 3 章');
    expect(metadataCalls.last.artist, 'ch1');
    expect(metadataCalls.last.title, '测试书');
    expect(metadataCalls.last.timerText, '剩余 3 章');

    // 第一章自然播完 → 计数 2 并切到第二章（章末即时刷新）
    fakePlayer.completePlayback();
    await tester.pump();
    await tester.pump();

    expect(readState().currentIndex, 1);
    expect(readNotifier().chaptersToStopRemaining, 2);
    expect(metadataCalls.last.artist, 'ch2');
    expect(metadataCalls.last.title, '测试书');
    expect(metadataCalls.last.timerText, '剩余 2 章');
  });

  testPlayback('c) 分钟倒计时：独立定时字段含剩余分钟（向上取整对齐原版节奏）', (tester) async {
    await startStreamPlayback();
    readNotifier().startSleepTimer(5);

    expect(readNotifier().sleepTimerRemainingLabel, '剩余 5 分钟');
    expect(metadataCalls.last.timerText, '剩余 5 分钟');

    // 走过 59 秒：剩余 241s，分钟整数仍为 5
    await tester.pump(const Duration(seconds: 59));
    expect(readNotifier().sleepRemainingSeconds, 241);
    expect(readNotifier().sleepTimerRemainingLabel, '剩余 5 分钟');

    // 再 1 秒到 240s → 4 分钟
    await tester.pump(const Duration(seconds: 1));
    expect(readNotifier().sleepRemainingSeconds, 240);
    expect(readNotifier().sleepTimerRemainingLabel, '剩余 4 分钟');
    expect(metadataCalls.last.timerText, '剩余 4 分钟');

    // 清理进行中的 ticker（测试结束不得残留 pending Timer）
    readNotifier().cancelSleepTimer();
  });

  testPlayback('d) 去重节流：分钟整数不变/同值重设/恢复播放均不重推 metadata', (tester) async {
    await startStreamPlayback();
    readNotifier().startSleepTimer(5);
    final callsAfterStart = metadataCalls.length;

    // 59 次 tick（300→241）分钟整数不变 → 0 次重推
    await tester.pump(const Duration(seconds: 59));
    expect(metadataCalls.length, callsAfterStart);

    // 同值重设 5 分钟：签名未变 → 不重推
    readNotifier().startSleepTimer(5);
    expect(metadataCalls.length, callsAfterStart);

    // 暂停/恢复：元数据未变 → 不重推（播放态经 notifyPlaying 单独发布）
    readNotifier().pause();
    await tester.pump();
    await readNotifier().resumeOrPlay();
    await tester.pump();
    expect(readState().state, PlayerState.playing);
    expect(metadataCalls.length, callsAfterStart);

    // 清理进行中的 ticker（测试结束不得残留 pending Timer）
    readNotifier().cancelSleepTimer();
  });

  testPlayback('e1) 分钟到点：停止通知，不再推送旧元数据', (tester) async {
    await startStreamPlayback();
    readNotifier().startSleepTimer(1); // 60s
    expect(metadataCalls.last.timerText, '剩余 1 分钟');
    final countBeforeStop = metadataCalls.length;

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(readState().state, PlayerState.idle);
    expect(readNotifier().isSleepTimerActive, isFalse);
    expect(metadataCalls.length, countBeforeStop);
    verify(() => mockAudio.notifyStopped()).called(1);
  });

  testPlayback('e2) 取消定时：标题恢复原形态', (tester) async {
    await startStreamPlayback();
    readNotifier().startChapterStop(2);
    expect(metadataCalls.last.timerText, '剩余 2 章');

    readNotifier().cancelSleepTimer();
    expect(readNotifier().sleepTimerMode, SleepTimerMode.off);
    expect(metadataCalls.last.timerText, '');
    expect(metadataCalls.last.timerText.contains('剩余'), isFalse);
  });

  testPlayback('e3) 手动停止：定时清空，不重新创建通知', (tester) async {
    await startStreamPlayback();
    readNotifier().startChapterStop(1);
    expect(metadataCalls.last.timerText, '剩余 1 章');

    final countBeforeStop = metadataCalls.length;
    readNotifier().stop();
    await tester.pump();

    expect(readNotifier().isSleepTimerActive, isFalse);
    expect(metadataCalls.length, countBeforeStop);
  });

  testPlayback('f) TTS 模式同样使用书名和章节，定时独立', (tester) async {
    await startTtsPlayback();
    expect(readState().isStreamMode, isFalse);
    expect(metadataCalls.last.timerText, '');
    expect(metadataCalls.last.artist, '第一章');
    expect(metadataCalls.last.title, '测试书');

    readNotifier().startSleepTimer(10);
    expect(metadataCalls.last.timerText, '剩余 10 分钟');

    readNotifier().startChapterStop(2);
    expect(metadataCalls.last.timerText, '剩余 2 章');

    readNotifier().cancelSleepTimer();
    expect(metadataCalls.last.timerText, '');
    expect(metadataCalls.last.timerText.contains('剩余'), isFalse);
  });

  testPlayback('封面异步返回不阻塞播放，同书切章和倒计时只更新文字', (tester) async {
    final pending = Completer<Uint8List?>();
    artworkLoader.resolve = (_, _) => pending.future;
    readNotifier().bindBook(
      const Book(bookUrl: 'url', coverUrl: 'https://cover'),
    );
    await startStreamPlayback();
    expect(readState().state, PlayerState.playing);
    expect(artworkCalls, isEmpty);
    expect(artworkLoader.requests, hasLength(1));
    readNotifier().startChapterStop(3);
    fakePlayer.completePlayback();
    await tester.pump();
    await tester.pump();
    expect(artworkLoader.requests, hasLength(1));
    pending.complete(Uint8List.fromList([7, 8]));
    await tester.pump();
    expect(artworkCalls.single.bytes, [7, 8]);
    expect(metadataCalls.last.title, '测试书');
    expect(metadataCalls.last.artist, 'ch2');
    expect(metadataCalls.last.timerText, '剩余 2 章');
    readNotifier().cancelSleepTimer();
  });

  testPlayback('切书拒绝旧图，同一本书停止重播也拒绝上一会话结果', (tester) async {
    final first = Completer<Uint8List?>(), second = Completer<Uint8List?>();
    var request = 0;
    artworkLoader.resolve = (_, _) =>
        ++request == 1 ? first.future : second.future;
    await startStreamPlayback();
    final firstToken = metadataCalls.last.sessionToken;
    readNotifier().stop();
    await tester.pump();
    await readNotifier().play();
    expect(metadataCalls.last.sessionToken, greaterThan(firstToken));
    first.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(artworkCalls, isEmpty);
    second.complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(artworkCalls.single.bytes, [2]);

    final old = Completer<Uint8List?>(), next = Completer<Uint8List?>();
    artworkLoader.resolve = (book, _) =>
        book?.bookUrl == 'url' ? old.future : next.future;
    readNotifier().bindBook(const Book(bookUrl: 'url', coverUrl: 'old'));
    await tester.pump();
    await readNotifier().loadChapters('another-book');
    readNotifier().bindBook(
      const Book(bookUrl: 'another-book', coverUrl: 'new'),
    );
    await readNotifier().play();
    old.complete(Uint8List.fromList([3]));
    next.complete(Uint8List.fromList([4]));
    await tester.pump();
    expect(artworkCalls.map((call) => call.bytes?.first), [2, 4]);
    expect(artworkCalls.last.mediaId, 'another-book');
  });

  testPlayback('隐私锁定清除真实标题和封面，迟到结果不能重新暴露', (tester) async {
    final pending = Completer<Uint8List?>();
    artworkLoader.resolve = (_, hidden) =>
        hidden ? Future.value(null) : pending.future;
    const book = Book(
      bookUrl: 'url',
      isPrivate: true,
      coverUrl: 'private-cover',
    );
    readNotifier().bindBook(book);
    await startStreamPlayback();
    final visibleToken = metadataCalls.last.sessionToken;
    (container.read(privacyControllerProvider.notifier) as _Privacy).replace(
      const PrivacyState(
        loading: false,
        settings: PrivacySettings(enabled: true),
      ),
    );
    await tester.pump();
    expect(metadataCalls.last.title, '私密书籍');
    expect(metadataCalls.last.artist, '');
    expect(metadataCalls.last.sessionToken, greaterThan(visibleToken));
    expect(artworkLoader.requests.last.hidden, isTrue);
    pending.complete(Uint8List.fromList([9]));
    await tester.pump();
    expect(artworkCalls, hasLength(1));
    expect(artworkCalls.single.bytes, isNull);
  });

  testPlayback('释放媒体会话或销毁后拒绝旧封面，加载异常不改变播放状态', (tester) async {
    final pending = Completer<Uint8List?>();
    artworkLoader.resolve = (_, _) => pending.future;
    await startStreamPlayback();
    await readNotifier().releaseMediaSession();
    pending.complete(Uint8List.fromList([3]));
    await tester.pump();
    expect(artworkCalls, isEmpty);
    artworkLoader.resolve = (_, _) async => throw StateError('图片失败');
    await readNotifier().initMediaSession();
    readNotifier().pause();
    await readNotifier().resumeOrPlay();
    await tester.pump();
    expect(readState().state, PlayerState.playing);
    expect(readState().errorMessage, isNull);
  });

  MediaPlaybackTarget currentTarget() => MediaPlaybackTarget(
    mediaId: metadataCalls.last.mediaId,
    sessionToken: metadataCalls.last.sessionToken,
    chapterIndex: readState().currentIndex,
  );

  testPlayback('音频书发布真实时长/位置，暂停定位保持暂停，旧章请求不执行', (tester) async {
    fakePlayer.loadedDuration = const Duration(seconds: 60);
    await startStreamPlayback();
    clock = 1000;
    fakePlayer.emitProgress(
      const Duration(seconds: 12),
      const Duration(seconds: 60),
    );
    await tester.pump();
    expect(progressCalls.last.position, 12000);
    expect(progressCalls.last.duration, 60000);
    expect(progressCalls.last.canSeek, isTrue);
    expect(progressCalls.last.hasPrevious, isFalse);
    readNotifier().pause();
    await tester.pump();
    final target = currentTarget();
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 25000),
    );
    expect(readState().state, PlayerState.paused);
    expect(fakePlayer.lastSeekPosition, const Duration(seconds: 25));
    expect(progressCalls.last.position, 25000);
    expect(progressCalls.last.state, 'paused');
    await readNotifier().next();
    final count = fakePlayer.seekCount;
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 30000),
    );
    expect(fakePlayer.seekCount, count);
  });

  testPlayback('未知音频时长不允许系统定位，过期会话身份不影响当前播放器', (tester) async {
    await startStreamPlayback();
    expect(progressCalls.last.duration, 0);
    expect(progressCalls.last.canSeek, isFalse);
    final target = currentTarget();
    final count = fakePlayer.seekCount;
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 1000),
    );
    expect(fakePlayer.seekCount, count);
    fakePlayer.emitProgress(
      const Duration(seconds: 1),
      const Duration(seconds: 60),
    );
    await tester.pump();
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(
        target: MediaPlaybackTarget(
          mediaId: target.mediaId,
          sessionToken: target.sessionToken + 1,
          chapterIndex: target.chapterIndex,
        ),
        position: 5000,
      ),
    );
    expect(fakePlayer.seekCount, count);
  });

  testPlayback('快速连续系统拖动按顺序提交，最终保持最新目标且停止后拒绝', (tester) async {
    fakePlayer.loadedDuration = const Duration(seconds: 60);
    await startStreamPlayback();
    fakePlayer.emitProgress(Duration.zero, const Duration(seconds: 60));
    final target = currentTarget();
    final gate = Completer<void>();
    fakePlayer.seekBarrier = gate.future;
    final first = readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 20000),
    );
    await tester.pump();
    final second = readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 30000),
    );
    gate.complete();
    fakePlayer.seekBarrier = null;
    await Future.wait([first, second]);
    expect(fakePlayer.position, const Duration(seconds: 30));
    expect(readState().positionMs, 30000);
    readNotifier().stop();
    final count = fakePlayer.seekCount;
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: target, position: 10000),
    );
    expect(fakePlayer.seekCount, count);
  });

  testPlayback('正文以章内原文估算总时长，锁屏拖动不恢复暂停朗读', (tester) async {
    await startTtsPlayback();
    expect(progressCalls.last.duration, '第一段文本内容。'.length * 250);
    expect(progressCalls.last.isStream, isFalse);
    expect(progressCalls.last.speed, 1);
    readNotifier().pause();
    await tester.pump();
    final starts = fakePlayer.playedLocalFiles.length;
    await readNotifier().seekFromMediaSession(
      MediaSeekRequest(target: currentTarget(), position: 1000),
    );
    expect(readState().state, PlayerState.paused);
    expect(readNotifier().readAloudPosition.value!.offset, 4);
    expect(fakePlayer.playedLocalFiles, hasLength(starts));
    expect(progressCalls.last.position, 1000);
    expect(progressCalls.last.state, 'paused');
  });

  testPlayback('媒体前后按钮遵循切段设置，音频书仍按章切换', (tester) async {
    await startTtsPlayback();
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '第一段。\n第二段。');
    await readNotifier().seekToChapterPosition(0, 0);
    // 已加载章节使用真实缓存，切段用独立的重新加载会话。
    await readNotifier().loadChapters('other');
    readNotifier().setAudioBookMode(false);
    await readNotifier().play();
    await container
        .read(readAloudPreferencesProvider.notifier)
        .setMediaButtonPerNext(false);
    buttonController.add(MediaButtonEvent.skipToNext);
    await tester.pump();
    await tester.pump();
    expect(readState().currentIndex, 0);
    expect(readNotifier().currentParagraphIndex, 1);
    buttonController.add(MediaButtonEvent.skipToPrevious);
    await tester.pump();
    await tester.pump();
    expect(readNotifier().currentParagraphIndex, 0);
    await startStreamPlayback();
    buttonController.add(MediaButtonEvent.skipToNext);
    await tester.pump();
    await tester.pump();
    expect(readState().currentIndex, 1);
  });
}
