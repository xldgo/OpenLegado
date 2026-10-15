import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('legado/media_session');
  final service = AudioService.instance;
  final calls = <MethodCall>[];
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'init' ? true : null;
        });
    calls.clear();
    await service.init();
  });
  tearDown(() async {
    await service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('文字、图片与清除独立编码，携带同一媒体身份', () async {
    await service.updateMetadata(
      title: '书名',
      artist: '第一章',
      album: '书名',
      mediaId: 'book',
      sessionToken: 7,
      timerText: '剩余 4 章',
    );
    final bytes = Uint8List.fromList([1, 2, 3]);
    await service.updateArtwork(
      mediaId: 'book',
      sessionToken: 7,
      artworkBytes: bytes,
    );
    await service.updateArtwork(
      mediaId: 'book',
      sessionToken: 7,
      artworkBytes: null,
    );
    expect(calls[1].arguments, {
      'title': '书名',
      'artist': '第一章',
      'album': '书名',
      'mediaId': 'book',
      'sessionToken': 7,
      'timerText': '剩余 4 章',
    });
    expect(calls[2].method, 'updateArtwork');
    expect((calls[2].arguments as Map)['artworkBytes'], bytes);
    expect((calls[3].arguments as Map).containsKey('artworkBytes'), isTrue);
    expect((calls[3].arguments as Map)['artworkBytes'], isNull);
  });

  test('进度快照按毫秒编码，暂停及按钮能力独立传递', () async {
    await service.updateProgress(
      const MediaPlaybackProgress(
        mediaId: 'book',
        sessionToken: 9,
        chapterIndex: 2,
        state: 'paused',
        position: 12500,
        duration: 60000,
        speed: 1.5,
        canSeek: true,
        hasPrevious: false,
        hasNext: true,
        isStream: true,
      ),
    );
    final call = calls.last;
    expect(call.method, 'updateProgress');
    expect(call.arguments, {
      'mediaId': 'book',
      'sessionToken': 9,
      'chapterIndex': 2,
      'state': 'paused',
      'position': 12500,
      'duration': 60000,
      'speed': 1.5,
      'canSeek': true,
      'hasPrevious': false,
      'hasNext': true,
      'isStream': true,
    });
  });

  test('系统定位和导航回调拒绝非法身份，不误转成其他媒体按钮', () async {
    final seeks = <MediaSeekRequest>[];
    final opens = <MediaPlaybackTarget>[];
    final buttons = <MediaButtonEvent>[];
    final subscriptions = <StreamSubscription<dynamic>>[
      service.seekStream.listen(seeks.add),
      service.openPlaybackStream.listen(opens.add),
      service.mediaButtonStream.listen(buttons.add),
    ];
    addTearDown(() async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    });
    Future<void> send(String name, Map<String, Object> arguments) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(name, arguments),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);
    }

    final target = <String, Object>{
      'mediaId': 'book',
      'sessionToken': 9,
      'chapterIndex': 2,
    };
    await send('onSeekTo', {...target, 'position': 12500});
    await send('onOpenPlayback', target);
    await send('onSeekTo', {...target, 'position': -1});
    await send('onSeekTo', {...target, 'position': 1.5});
    await send('onSeekTo', {...target, 'sessionToken': 0, 'position': 100});
    await send('onOpenPlayback', {...target, 'chapterIndex': -1});
    expect(seeks, hasLength(1));
    expect(seeks.single.position, 12500);
    expect(seeks.single.target.chapterIndex, 2);
    expect(opens.single.mediaId, 'book');
    expect(buttons, isEmpty);
  });

  test('释放后不再向平台发送图片', () async {
    await service.dispose();
    final count = calls.length;
    await service.updateArtwork(
      mediaId: 'old',
      sessionToken: 1,
      artworkBytes: null,
    );
    expect(calls, hasLength(count));
  });
}
