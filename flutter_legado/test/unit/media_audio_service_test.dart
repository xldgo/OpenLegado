import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' as media;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';
import 'package:flutter_legado/src/platform/audio/media_artwork_files.dart';
import 'package:flutter_legado/src/platform/audio/read_aloud_audio_handler.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

import '../fixtures/app_audio_session_backend.dart';

class _Artwork extends Fake implements MediaArtworkFiles {
  Completer<Uri>? pending;
  final writes = <Uint8List>[];
  @override
  Future<Uri> write(Uint8List bytes) {
    writes.add(bytes);
    return pending?.future ??
        Future.value(Uri.file('/tmp/media-${writes.length}.png'));
  }

  @override
  Future<void> prune({Uri? keep}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestAudioSessionBackend backend;
  late AudioService service;
  late ReadAloudAudioHandler handler;
  late StreamController<bool> clicks;
  late _Artwork artwork;
  int initializations = 0;
  Completer<void>? barrier;
  Object? failure;
  setUp(() {
    backend = TestAudioSessionBackend();
    artwork = _Artwork();
    clicks = StreamController<bool>.broadcast();
    initializations = 0;
    barrier = null;
    failure = null;
    service = AudioService.forTesting(
      AppAudioSession(backend),
      artworkFiles: artwork,
      notificationClicks: clicks.stream,
      initializeMedia: (value) async {
        handler = value;
        initializations++;
        await barrier?.future;
        if (failure case final error?) throw error;
        return value;
      },
    );
  });
  tearDown(() async {
    await service.dispose();
    await clicks.close();
    await backend.source.close();
    if (initializations > 0) {
      await handler.mediaItem.close();
      await handler.playbackState.close();
    }
  });

  Future<void> publish({
    String id = 'book',
    int token = 9,
    int chapter = 2,
  }) async {
    await service.updateMetadata(
      title: '书名',
      artist: '第${chapter + 1}章',
      album: '书名',
      mediaId: id,
      sessionToken: token,
      timerText: '剩余 4 章',
    );
    await service.updateProgress(
      MediaPlaybackProgress(
        mediaId: id,
        sessionToken: token,
        chapterIndex: chapter,
        state: 'paused',
        position: 12500,
        duration: 60000,
        speed: 1.5,
        canSeek: true,
        hasPrevious: true,
        hasNext: true,
        isStream: true,
      ),
    );
  }

  test('进程内初始化合并，释放后复用同一Handler，不重复注册插件', () async {
    barrier = Completer<void>();
    final first = service.init(), second = service.init();
    expect(initializations, 1);
    barrier!.complete();
    await Future.wait([first, second]);
    expect(service.isInitialized, isTrue);
    final original = handler;
    expect(clicks.hasListener, isTrue);
    await service.dispose();
    expect(clicks.hasListener, isTrue);
    await service.init();
    expect(service.isInitialized, isTrue);
    expect(identical(handler, original), isTrue);
    expect(initializations, 1);
  });

  test('初始化途中销毁不发布伪就绪，后续初始化可复用已完成注册', () async {
    barrier = Completer<void>();
    final starting = service.init();
    await service.dispose();
    barrier!.complete();
    await starting;
    expect(service.isInitialized, isFalse);
    await service.init();
    expect(service.isInitialized, isTrue);
    expect(initializations, 1);
  });

  test('插件初始化失败保留原因，不伪造成功或重复注册', () async {
    failure = StateError('服务连接失败');
    await expectLater(service.init(), throwsStateError);
    expect(service.isInitialized, isFalse);
    await expectLater(service.init(), throwsStateError);
    expect(initializations, 1);
  });

  test('迟到暂停或停止不能覆盖新书籍的媒体快照', () async {
    await service.init();
    await publish();
    final stopping = service.notifyStopped();
    await publish(id: 'next', token: 10);
    await stopping;
    expect(handler.mediaItem.value!.id, 'next');
    expect(
      handler.playbackState.value.processingState,
      media.AudioProcessingState.ready,
    );
    final pausing = service.notifyPaused();
    await publish(id: 'latest', token: 11);
    await pausing;
    expect(handler.mediaItem.value!.id, 'latest');
    expect(
      handler.playbackState.value.updatePosition,
      const Duration(milliseconds: 12500),
    );
  });

  test('真实Handler命令转入现有媒体控制流，seek与通知导航均携带身份', () async {
    final commands = <MediaButtonEvent>[],
        seeks = <MediaSeekRequest>[],
        opens = <MediaPlaybackTarget>[];
    final subscriptions = <StreamSubscription<dynamic>>[
      service.mediaButtonStream.listen(commands.add),
      service.seekStream.listen(seeks.add),
      service.openPlaybackStream.listen(opens.add),
    ];
    addTearDown(() async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    });
    await service.init();
    await publish();
    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.seek(const Duration(seconds: 4));
    clicks.add(true);
    clicks.add(false);
    await pumpEventQueue();
    expect(commands, [
      MediaButtonEvent.play,
      MediaButtonEvent.pause,
      MediaButtonEvent.skipToNext,
      MediaButtonEvent.skipToPrevious,
    ]);
    expect(seeks.single.position, 4000);
    expect(seeks.single.target.chapterIndex, 2);
    expect(opens.single.mediaId, 'book');
    expect(opens.single.sessionToken, 9);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('导航未接入前只保存最新有效点击，停止清除待处理导航', () async {
    await service.init();
    await publish();
    clicks.add(true);
    await pumpEventQueue();
    final pending = await service.takePendingOpen();
    expect(pending!.mediaId, 'book');
    expect(await service.takePendingOpen(), isNull);
    clicks.add(true);
    await pumpEventQueue();
    await service.notifyStopped();
    expect(await service.takePendingOpen(), isNull);
    clicks.add(true);
    await pumpEventQueue();
    expect(await service.takePendingOpen(), isNull);
  });

  test('封面URI经真实Handler发布，异步旧图片和释放后图片不污染当前书籍', () async {
    await service.init();
    await publish();
    artwork.pending = Completer<Uri>();
    final stale = service.updateArtwork(
      mediaId: 'book',
      sessionToken: 9,
      artworkBytes: Uint8List.fromList([1, 2, 3]),
    );
    await publish(id: 'new', token: 10);
    artwork.pending!.complete(Uri.file('/tmp/old.png'));
    await stale;
    expect(handler.mediaItem.value!.id, 'new');
    expect(handler.mediaItem.value!.artUri, isNull);
    artwork.pending = null;
    await service.updateArtwork(
      mediaId: 'new',
      sessionToken: 10,
      artworkBytes: Uint8List.fromList([4]),
    );
    expect(handler.mediaItem.value!.artUri, Uri.file('/tmp/media-2.png'));
    await service.updateArtwork(
      mediaId: 'new',
      sessionToken: 10,
      artworkBytes: null,
    );
    expect(handler.mediaItem.value!.artUri, isNull);
    await service.dispose();
    await service.updateArtwork(
      mediaId: 'new',
      sessionToken: 10,
      artworkBytes: Uint8List.fromList([5]),
    );
    expect(artwork.writes, hasLength(2));
  });

  test('停止发布idle，但不销毁插件或改动焦点适配器所有权', () async {
    await service.init();
    await publish();
    expect(await service.requestAudioFocus(), isTrue);
    await service.notifyPlaying();
    expect(handler.playbackState.value.playing, isTrue);
    await service.notifyPaused();
    expect(handler.playbackState.value.playing, isFalse);
    await service.notifyStopped();
    expect(
      handler.playbackState.value.processingState,
      media.AudioProcessingState.idle,
    );
    expect(handler.mediaItem.value, isNull);
    expect(service.isInitialized, isTrue);
    expect(backend.activations, [true]);
    await service.abandonAudioFocus();
    expect(backend.activations, [true, false]);
  });
}
