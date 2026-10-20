import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/video_danmaku_service.dart';
import 'package:flutter_legado/src/domain/contracts/video_progress_repository.dart';
import 'package:flutter_legado/src/features/video/application/video_play_settings.dart';
import 'package:flutter_legado/src/features/video/application/video_playback_controller.dart';
import 'package:flutter_legado/src/features/video/application/video_playback_request.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/services/video_float_window.dart';

import '../../../helpers/fake_video_platform.dart';

class _Reading extends Mock implements ReadingRepository {}

class _Sources extends Mock implements BookSourceRepository {}

class _Danmaku extends Mock implements VideoDanmakuService {}

class _Progress extends Mock implements VideoProgressRepository {}

class _Floating extends VideoFloatWindowCoordinator {
  bool supported = false;
  Completer<bool>? pending;
  final entered = Completer<VideoFloatWindowState>();
  @override
  bool get isSupported => supported;
  @override
  Future<VideoFloatWindowState?> probeAndTakeOver({
    String? bookUrl,
    String? videoUrl,
    ReadingRepository? reading,
    VideoProgressRepository? progress,
  }) async => null;
  @override
  Future<bool> enterWindow({
    required VideoFloatWindowState state,
    Book? book,
    List<BookChapter>? chapters,
    Map<String, String>? sourceHeaders,
    ReadingRepository? reading,
    VideoProgressRepository? progress,
  }) {
    entered.complete(state);
    return pending?.future ?? Future.value(false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Reading reading;
  late _Sources sources;
  late _Danmaku danmaku;
  late _Progress progress;
  late _Floating floating;
  late FakeVideoPlatform platform;
  late Directory temporary;
  const book = Book(
    bookUrl: 'book://video',
    origin: 'source://video',
    durChapterPos: 4000,
  );
  const mpd = '<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"></MPD>';

  setUp(() async {
    reading = _Reading();
    sources = _Sources();
    danmaku = _Danmaku();
    progress = _Progress();
    floating = _Floating();
    platform = FakeVideoPlatform();
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    temporary = await Directory.systemTemp.createTemp('legado-video-session-');
    addTearDown(() => temporary.delete());
    when(() => sources.getBookSources()).thenAnswer((_) async => []);
    when(() => progress.read(any())).thenAnswer((_) async => 1000);
    when(() => progress.write(any(), any())).thenAnswer((_) async {});
    when(() => reading.getChapters(book.bookUrl)).thenAnswer(
      (_) async => [
        for (var i = 0; i < 3; i++)
          BookChapter(
            bookUrl: book.bookUrl,
            url: 'https://chapter/$i',
            title: '第$i集',
            index: i,
          ),
      ],
    );
    when(() => reading.fetchChapterContent(any(), any(), any()))
        .thenAnswer((call) async => '${call.positionalArguments[1]}.mp4');
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => danmaku.getVideoDanmaku(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((_) async => null);
  });

  VideoPlaybackController make({
    VideoPlaybackRequest request = const VideoPlaybackRequest(
      videoUrl: 'https://direct/video.mp4',
    ),
    Future<VideoPlaySettings> Function()? settings,
    Future<Directory> Function()? directory,
    void Function()? onFloatEntered,
  }) {
    final controller = VideoPlaybackController(
      request: request,
      reading: reading,
      sources: sources,
      danmaku: danmaku,
      progress: progress,
      floating: floating,
      loadSettings: settings ?? () async => VideoPlaySettings(),
      temporaryDirectory: directory ?? () async => temporary,
      onFloatEntered: onFloatEntered,
    );
    addTearDown(() async {
      controller.dispose();
      await controller.released;
    });
    return controller;
  }

  test('设置迟到：退出后不启动播放器，重复start仍是同一任务', () async {
    final settings = Completer<VideoPlaySettings>();
    final controller = make(settings: () => settings.future);
    final starting = controller.start();
    expect(controller.start(), same(starting));
    controller.dispose();
    settings.complete(VideoPlaySettings());
    await starting;
    expect(platform.created, isEmpty);
    verifyZeroInteractions(reading);
    verifyZeroInteractions(progress);
  });

  test('章节列表迟到：退出后不继续抓取正文或通知界面', () async {
    final chapters = Completer<List<BookChapter>>();
    final requested = Completer<void>();
    when(() => reading.getChapters(book.bookUrl)).thenAnswer((_) {
      requested.complete();
      return chapters.future;
    });
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: '', book: book),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final starting = controller.start();
    await requested.future;
    controller.dispose();
    final before = notifications;
    chapters.complete([const BookChapter(url: 'https://late')]);
    await starting;
    expect(notifications, before);
    expect(platform.created, isEmpty);
    verifyNever(() => reading.fetchChapterContent(any(), any(), any()));
  });

  test('读取书源失败迟到：退出后不继续读章节', () async {
    final sourceResult = Completer<List<BookSource>>();
    final requested = Completer<void>();
    when(() => sources.getBookSources()).thenAnswer((_) {
      requested.complete();
      return sourceResult.future;
    });
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: '', book: book),
    );
    final starting = controller.start();
    await requested.future;
    controller.dispose();
    sourceResult.completeError(StateError('书源失败'));
    await starting;
    verifyNever(() => reading.getChapters(any()));
    expect(platform.created, isEmpty);
  });

  test('正文迟到：连续选集只安装最新请求，不回写旧章节', () async {
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: '', book: book),
    );
    await controller.start();
    await controller.initialization;
    final old = Completer<String>();
    when(
      () => reading.fetchChapterContent(
        book.bookUrl,
        'https://chapter/1',
        book.origin,
      ),
    ).thenAnswer((_) => old.future);
    final pending = controller.playChapter(1);
    await controller.playChapter(2);
    await controller.initialization;
    old.complete('https://old.mp4');
    await pending;
    expect(controller.chapterIndex, 2);
    expect(controller.currentUrl, 'https://chapter/2.mp4');
    expect(platform.created, hasLength(2));
    verifyNever(
      () => reading.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: 1,
        chapterPos: any(named: 'chapterPos'),
      ),
    );
  });

  test('弹幕迟到：旧章节原文不再解析或覆盖新章节', () async {
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: '', book: book),
    );
    await controller.start();
    await controller.initialization;
    final old = Completer<String?>();
    final requested = Completer<void>();
    when(() => danmaku.getVideoDanmaku(bookUrl: book.bookUrl, chapterIndex: 1))
        .thenAnswer((_) {
          requested.complete();
          return old.future;
        });
    final pending = controller.playChapter(1);
    await requested.future;
    await controller.playChapter(2);
    await controller.initialization;
    old.complete('旧弹幕');
    await pending;
    verifyNever(() => danmaku.parseVideoDanmaku(raw: '旧弹幕'));
    expect(controller.chapterIndex, 2);
    expect(controller.danmakuAvailable, isFalse);
  });

  test('旧seek完成后不操纵新播放器，也不重复自动播放', () async {
    final seek = Completer<void>(), seeking = Completer<void>();
    platform.onSeek = (id, position) async {
      if (id == 1 && position.inMilliseconds > 0) {
        seeking.complete();
        await seek.future;
      }
    };
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: '', book: book),
    );
    await controller.start();
    final initial = controller.initialization;
    await seeking.future;
    await controller.playChapter(1);
    await controller.initialization;
    seek.complete();
    await initial;
    expect(platform.playCalls, [2]);
    expect(platform.disposed, [1]);
    controller.dispose();
    await controller.released;
    expect(platform.disposed, [1, 2]);
  });

  test('初始化恢复期间退出，迟到seek不会播放且资源只释放一次', () async {
    final seek = Completer<void>(), seeking = Completer<void>();
    platform.onSeek = (id, position) async {
      if (position.inMilliseconds > 0) {
        seeking.complete();
        await seek.future;
      }
    };
    final controller = make();
    await controller.start();
    final initializing = controller.initialization;
    await seeking.future;
    controller.dispose();
    controller.dispose();
    seek.complete();
    await initializing;
    await controller.released;
    expect(platform.playCalls, isEmpty);
    expect(platform.disposed, [1]);
  });

  test('MPD目录解析迟到时退出，不创建遗留文件或播放器', () async {
    final directory = Completer<Directory>();
    final requested = Completer<void>();
    final controller = make(
      request: const VideoPlaybackRequest(videoUrl: mpd),
      directory: () {
        requested.complete();
        return directory.future;
      },
    );
    final starting = controller.start();
    await requested.future;
    controller.dispose();
    directory.complete(temporary);
    await starting;
    await controller.released;
    expect(await temporary.list().toList(), isEmpty);
    expect(platform.created, isEmpty);
  });

  test('回全屏预置MPD在设置加载期间退出也释放文件', () async {
    final file = await File('${temporary.path}/preset.mpd').writeAsString(mpd);
    final settings = Completer<VideoPlaySettings>();
    final controller = make(
      request: VideoPlaybackRequest(
        videoUrl: '',
        presetUrl: file.uri.toString(),
        presetMpdPath: file.path,
      ),
      settings: () => settings.future,
    );
    final starting = controller.start();
    controller.dispose();
    await controller.released;
    expect(await file.exists(), isFalse);
    settings.complete(VideoPlaySettings());
    await starting;
    expect(platform.created, isEmpty);
  });

  test('重试预置MPD保留正在复用的文件，最后退出才删除', () async {
    final file = await File('${temporary.path}/retry.mpd').writeAsString(mpd);
    final controller = make(
      request: VideoPlaybackRequest(
        videoUrl: '',
        presetUrl: file.uri.toString(),
        presetMpdPath: file.path,
      ),
    );
    await controller.start();
    await controller.initialization;
    await controller.retry();
    await controller.initialization;
    expect(await file.exists(), isTrue);
    expect(platform.created, hasLength(2));
    expect(platform.disposed, [1]);
    controller.dispose();
    await controller.released;
    expect(await file.exists(), isFalse);
    expect(platform.disposed, [1, 2]);
  });

  for (final accepted in [true, false]) {
    test('MPD悬浮窗移交未完成时退出，原生${accepted ? '接受后保留' : '拒绝后释放'}文件', () async {
      floating.supported = true;
      floating.pending = Completer<bool>();
      var navigations = 0;
      final controller = make(
        request: const VideoPlaybackRequest(videoUrl: mpd),
        settings: () async => VideoPlaySettings(defaultFloatWindow: true),
        onFloatEntered: () => navigations++,
      );
      final starting = controller.start();
      final state = await floating.entered.future;
      final file = File(state.mpdTempPath!);
      controller.dispose();
      expect(await file.exists(), isTrue);
      floating.pending!.complete(accepted);
      await starting;
      await controller.released;
      expect(await file.exists(), accepted);
      expect(navigations, 0);
      expect(platform.created, isEmpty);
      if (accepted) await file.delete();
    });
  }
}
