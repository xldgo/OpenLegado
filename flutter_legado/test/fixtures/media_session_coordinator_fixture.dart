import 'dart:async';

import 'package:flutter_legado/src/features/audio/playback/media_session_coordinator.dart';
import 'package:flutter_legado/src/features/audio/playback/media_session_host.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';
import 'package:flutter_legado/src/features/audio/application/read_aloud_position.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

import '../mocks/mocks.dart';
import 'media_artwork_loader.dart';
import 'media_audio_service.dart';
export 'media_audio_service.dart';

class MediaSessionFixture {
  MediaSessionFixture() {
    coordinator = MediaSessionCoordinator(
      host: MediaSessionHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => token,
        isDisposed: () => hostDisposed,
        currentBook: () => book,
        isBookHidden: (_) => hidden,
        timerLabel: () => timerLabel,
        readPosition: () => position,
        hasReadAloudUnits: () => hasUnits,
        paragraphIndex: () => paragraph,
        paragraphCount: () => 3,
        loadPreferences: () async => preferencesLoads++,
        mediaButtonPerChapter: () => perChapter,
        resumeOrPlay: resume,
        pause: pause,
        stop: stop,
        nextChapter: () => chapter(1),
        previousChapter: () => chapter(-1),
        nextParagraph: () async {
          actions.add('下一段');
          paragraph++;
        },
        previousParagraph: () async {
          actions.add('上一段');
          paragraph--;
        },
        seekReadAloud: (chapter, offset) async {
          sourceSeeks.add((chapter, offset));
          setPosition(offset);
          coordinator.reviseTimeline();
        },
        persistStreamPosition: ({bool force = false, int? positionMs}) async =>
            saves.add((position: positionMs, force: force)),
      ),
      audioService: audio,
      player: player,
      artwork: artwork,
      clock: () => clock,
    );
    player.isInitialized = true;
  }

  final audio = TestMediaAudioService();
  final player = FakeStreamAudioPlayer();
  final artwork = FakeMediaArtworkLoader();
  late final MediaSessionCoordinator coordinator;
  final actions = <String>[];
  final sourceSeeks = <(int, int)>[];
  final saves = <({int? position, bool force})>[];
  Book book = const Book(
    bookUrl: 'book',
    name: '测试书',
    coverUrl: 'https://cover',
  );
  bool hidden = false,
      hostDisposed = false,
      perChapter = false,
      hasUnits = true;
  int token = 1, paragraph = 0, clock = 0, preferencesLoads = 0;
  String timerLabel = '';
  ReadAloudPosition? position;
  AudioState _state = AudioState(
    bookUrl: 'book',
    bookName: '测试书',
    config: TtsConfig(),
    chapters: [
      AudioChapter(index: 0, title: '第一章', text: '甲乙丙丁戊己庚辛壬癸' * 4),
      AudioChapter(index: 1, title: '第二章', text: '第二章正文'),
    ],
  );

  AudioState get state {
    if (hostDisposed) throw StateError('释放后读取了宿主状态');
    return _state;
  }

  set state(AudioState value) {
    if (hostDisposed) throw StateError('释放后写入了宿主状态');
    final previous = _state;
    _state = value;
    coordinator.stateChanged(previous, value);
  }

  Future<void> start({bool stream = true}) async {
    await coordinator.init();
    state = state.copyWith(
      state: PlayerState.playing,
      isStreamMode: stream,
      positionMs: 4000,
      durationMs: stream ? 60000 : 0,
    );
    await coordinator.activate();
  }

  void pause({bool dueToInterruption = false}) {
    actions.add('暂停');
    coordinator.preparePause(dueToInterruption: dueToInterruption);
    state = state.copyWith(state: PlayerState.paused);
    unawaited(coordinator.notifyPaused());
  }

  Future<void> resume() async {
    actions.add('恢复');
    coordinator.prepareResume();
    state = state.copyWith(state: PlayerState.playing);
    await coordinator.activate();
  }

  void stop() {
    actions.add('停止');
    token++;
    coordinator.invalidate();
    state = state.copyWith(state: PlayerState.idle);
    coordinator.notifyStopped();
  }

  Future<void> chapter(int step) async {
    actions.add(step > 0 ? '下一章' : '上一章');
    state = state.copyWith(currentIndex: state.currentIndex + step);
  }

  void setPosition(int offset) => position = ReadAloudPosition(
    bookUrl: state.bookUrl,
    chapterIndex: state.currentIndex,
    paragraphIndex: paragraph,
    paragraphStart: 0,
    paragraphEnd: 40,
    offset: offset,
    session: token,
  );

  MediaPlaybackTarget get target {
    final metadata = audio.metadata.last;
    return MediaPlaybackTarget(
      mediaId: metadata.mediaId,
      sessionToken: metadata.sessionToken,
      chapterIndex: state.currentIndex,
    );
  }

  Future<void> close() async {
    coordinator.dispose();
    hostDisposed = true;
    await audio.closeStreams();
  }
}
