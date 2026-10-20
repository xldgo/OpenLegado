import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/domain/models/audio_playback_settings.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';

import '../fixtures/audio_book_controller_fixture.dart';

void main() {
  late AudioBookControllerFixture fixture;
  setUp(() {
    fixture = AudioBookControllerFixture();
    addTearDown(() => fixture.close());
  });

  test('独立装配不起播，播放使用宿主状态和共享播放器', () async {
    expect(fixture.service.requests, isEmpty);
    expect(fixture.state.state, PlayerState.idle);
    fixture.service.resolveMedia = (_, _) async => const AudioChapterMedia(
      mediaUrl: ' https://audio/chapter.mp3 ',
      lyric: ' 歌词 ',
    );
    await fixture.controller.play();
    expect(fixture.player.playedUrls, ['https://audio/chapter.mp3']);
    expect(fixture.state.mediaUrl, 'https://audio/chapter.mp3');
    expect(fixture.state.lyric, '歌词');
    expect(fixture.state.state, PlayerState.playing);
    expect(fixture.states.first.state, PlayerState.loading);
    expect(fixture.systemStops, 1);
    expect(fixture.mediaActivations, 1);
    expect(fixture.player.currentTag, (bookUrl: 'book', chapterIndex: 0));
  });

  test('卷标题和空地址按既有规则查找后续可播章', () async {
    fixture.service.resolveMedia = (_, index) async => switch (index) {
      0 => const AudioChapterMedia(mediaUrl: '', isVolume: true),
      1 => const AudioChapterMedia(mediaUrl: '  '),
      _ => const AudioChapterMedia(mediaUrl: 'https://audio/final.mp3'),
    };
    await fixture.controller.play();
    expect(fixture.service.requests, [('book', 0), ('book', 1), ('book', 2)]);
    expect(fixture.state.currentIndex, 2);
    expect(fixture.player.playedUrls, ['https://audio/final.mp3']);
  });

  test('末章无地址或只有卷标题明确失败，不使用旧媒体资源', () async {
    fixture.state = fixture.state.copyWith(currentIndex: 2);
    fixture.service.resolveMedia = (_, _) async =>
        const AudioChapterMedia(mediaUrl: '');
    await fixture.controller.play();
    expect(fixture.state.state, PlayerState.error);
    expect(fixture.state.errorMessage, '未获取到资源链接');
    fixture.service.resolveMedia = (_, _) async =>
        const AudioChapterMedia(mediaUrl: '', isVolume: true);
    await fixture.controller.play();
    expect(fixture.state.errorMessage, '无可播放章节');
    expect(fixture.player.playedUrls, isEmpty);
  });

  test('取址或播放器失败显示原错误，当前播放错误暂停且旧章错误被忽略', () async {
    fixture.service.resolveMedia = (_, _) => Future.error(StateError('取址失败'));
    await fixture.controller.play();
    expect(fixture.state.errorMessage, contains('取址失败'));
    fixture.service.resolveMedia = null;
    fixture.player.playUrlError = StateError('播放器失败');
    await fixture.controller.play();
    expect(fixture.state.errorMessage, contains('播放器失败'));
    fixture.player.playUrlError = null;
    await fixture.controller.play();
    fixture.controller.handleError(StateError('旧章'), (
      bookUrl: 'other',
      chapterIndex: 0,
    ));
    expect(fixture.state.state, PlayerState.playing);
    fixture.controller.handleError(
      StateError('网络断开'),
      fixture.player.currentTag,
    );
    expect(fixture.player.pauseCount, 1);
    expect(fixture.state.state, PlayerState.error);
    expect(fixture.state.errorMessage, contains('网络断开'));
  });

  test('正常续听位置优先恢复，暂停恢复不重新取址或起播', () async {
    fixture.settings.value = const AudioPlaybackSettings(openCredits: 10);
    fixture.service.progress[('book', 0)] = 40000;
    await fixture.controller.play();
    expect(fixture.player.lastSeekPosition, const Duration(seconds: 40));
    await fixture.progress(41000);
    fixture.pause();
    await fixture.flush();
    expect(fixture.state.state, PlayerState.paused);
    expect(await fixture.controller.resume(), isTrue);
    expect(fixture.state.state, PlayerState.playing);
    expect(fixture.player.position, const Duration(seconds: 41));
    expect(fixture.player.resumeCount, 1);
    expect(fixture.service.requests, hasLength(1));
    expect(fixture.player.playedUrls, hasLength(1));
    fixture.pause();
    fixture.player.isInitialized = false;
    expect(await fixture.controller.resume(), isFalse);
  });

  test('近章末恢复从头套用片头跳过，未知时长保留原续听行为', () async {
    fixture.settings.value = const AudioPlaybackSettings(openCredits: 10);
    fixture.service.progress[('book', 0)] = 119500;
    await fixture.controller.play();
    expect(fixture.player.lastSeekPosition, const Duration(seconds: 10));
    fixture.player.loadedDuration = Duration.zero;
    fixture.service.progress[('book', 0)] = 119500;
    await fixture.controller.play();
    expect(
      fixture.player.lastSeekPosition,
      const Duration(milliseconds: 119500),
    );
  });

  test('书级片头片尾覆盖全局值，片尾触发同一章完成流程', () async {
    fixture.settings.value = const AudioPlaybackSettings(
      openCredits: 10,
      closeCredits: 15,
    );
    fixture.book = const Book(
      bookUrl: 'book',
      readConfig: ReadConfig(openCredits: 20, closeCredits: 30),
    );
    await fixture.controller.play();
    expect(fixture.player.lastSeekPosition, const Duration(seconds: 20));
    await fixture.progress(90000);
    expect(fixture.actions, ['下一章']);
    expect(fixture.state.currentIndex, 1);
    expect(fixture.boundaries, 1);
    expect(fixture.service.saves.first.chapterIndex, 0);
    expect(fixture.service.saves.first.position, 90000);
  });

  test('短音频保持最短可听时长，设置加载失败沿用无跳过默认值', () async {
    fixture.player.loadedDuration = const Duration(seconds: 10);
    fixture.settings.value = const AudioPlaybackSettings(
      openCredits: 10,
      closeCredits: 15,
    );
    await fixture.controller.play();
    expect(fixture.player.seekCount, 0);
    fixture.settings.loadError = StateError('设置不可用');
    await fixture.controller.play();
    expect(fixture.player.seekCount, 0);
    expect(fixture.state.state, PlayerState.playing);
  });

  test('进度按原阈值节流，暂停强制保存实际位置', () async {
    await fixture.controller.play();
    await fixture.progress(2000);
    await fixture.progress(2300, elapsedMs: 100);
    expect(fixture.state.positionMs, 2000);
    expect(fixture.service.saves.map((value) => value.position), [2000]);
    await fixture.progress(7000);
    await fixture.progress(8000, elapsedMs: 100);
    expect(fixture.state.positionMs, 7000);
    fixture.pause();
    await fixture.flush();
    expect(fixture.service.saves.map((value) => value.position), [
      2000,
      7000,
      8000,
    ]);
    expect(fixture.player.pauseCount, 1);
  });

  test('切章后拒绝旧章的进度、错误和完成事件', () async {
    await fixture.controller.play();
    final old = fixture.player.currentTag;
    await fixture.progress(2000);
    await fixture.next();
    fixture.player.emitProgressForTag(
      old,
      const Duration(seconds: 119),
      const Duration(minutes: 2),
    );
    fixture.player.completePlaybackForTag(old);
    fixture.controller.handleError(StateError('旧章失败'), old);
    await fixture.flush();
    expect(fixture.state.currentIndex, 1);
    expect(fixture.state.state, PlayerState.playing);
    expect(fixture.state.errorMessage, isNull);
    expect(
      fixture.service.saves.where((value) => value.chapterIndex == 1),
      isEmpty,
    );
    expect(fixture.actions, ['下一章']);
    await fixture.progress(3000);
    expect(fixture.service.saves.last, (
      bookUrl: 'book',
      chapterIndex: 1,
      position: 3000,
    ));
  });

  test('自然播完先保存当前章再连续播放，末章结束停止', () async {
    await fixture.controller.play();
    await fixture.progress(4000);
    fixture.player.completePlayback();
    await fixture.flush();
    expect(fixture.state.currentIndex, 1);
    expect(fixture.actions, ['下一章']);
    fixture.state = fixture.state.copyWith(currentIndex: 2);
    await fixture.controller.play();
    fixture.player.completePlayback();
    await fixture.flush();
    expect(fixture.actions, ['下一章', '停止']);
    expect(fixture.state.state, PlayerState.idle);
  });

  test('单章循环先清零进度再重播，章末停止优先于循环', () async {
    fixture.state = fixture.state.copyWith(mode: AudioPlayMode.singleLoop);
    await fixture.controller.play();
    await fixture.progress(5000);
    fixture.player.completePlayback();
    await fixture.flush();
    expect(fixture.actions, ['循环']);
    expect(fixture.state.currentIndex, 0);
    expect(fixture.service.progress[('book', 0)], 0);
    expect(fixture.player.seekCount, 0);
    expect(fixture.player.playedUrls, hasLength(2));
    fixture.stopAtBoundary = true;
    fixture.player.completePlayback();
    await fixture.flush();
    expect(fixture.actions, ['循环', '停止']);
    expect(fixture.player.playedUrls, hasLength(2));
  });

  test('停止使在途取址失效，不会重新开始播放', () async {
    final pending = Completer<AudioChapterMedia>();
    fixture.service.resolveMedia = (_, _) => pending.future;
    final playing = fixture.controller.play();
    await fixture.flush();
    fixture.stop();
    pending.complete(
      const AudioChapterMedia(mediaUrl: 'https://audio/late.mp3'),
    );
    await playing;
    expect(fixture.state.state, PlayerState.idle);
    expect(fixture.player.playedUrls, isEmpty);
  });

  test('音频书控制器不播放或保存TTS模式进度', () async {
    fixture.state = fixture.state.copyWith(
      isStreamMode: false,
      positionMs: 6000,
    );
    await fixture.controller.play();
    await fixture.controller.persistPosition(force: true);
    expect(fixture.service.requests, isEmpty);
    expect(fixture.service.saves, isEmpty);
  });

  test('销毁只用最终快照保存一次，不读取宿主或释放共享播放器', () async {
    await fixture.controller.play();
    await fixture.progress(2000);
    await fixture.progress(3000);
    final snapshot = fixture.state;
    fixture.hostDisposed = true;
    fixture.controller.dispose(snapshot: snapshot);
    fixture.controller.dispose(snapshot: snapshot);
    fixture.controller.handleCompleted(fixture.player.currentTag);
    fixture.controller.handleProgress(
      const Duration(seconds: 5),
      const Duration(minutes: 2),
      fixture.player.currentTag,
    );
    fixture.controller.handleError(
      StateError('销毁后错误'),
      fixture.player.currentTag,
    );
    await fixture.controller.play();
    await fixture.controller.persistPosition(force: true);
    await fixture.flush();
    expect(fixture.service.saves.map((value) => value.position), [2000, 3000]);
    expect(fixture.player.stopCount, 0);
    expect(fixture.player.disposeCount, 0);
  });

  test('独立实例的进度节流与生命周期互不干扰', () async {
    final other = AudioBookControllerFixture();
    addTearDown(other.close);
    await fixture.controller.play();
    await other.controller.play();
    await fixture.progress(5000);
    await other.progress(6000);
    fixture.close();
    await other.progress(12000);
    expect(other.state.state, PlayerState.playing);
    expect(other.service.saves.map((value) => value.position), [6000, 12000]);
    expect(fixture.service.saves.map((value) => value.position), [5000]);
  });
}
