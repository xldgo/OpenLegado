import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/file_read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';
import 'package:flutter_legado/src/services/read_aloud_audio_player.dart';

/// 无网络、无数据库的真实播放器对照。调试结果不作为发布性能或逐样本无缝证明。
/// 仅在隔离测试设备运行；flutter test 必须带 --no-uninstall，且执行前备份设备数据。
/// 示例：flutter test --no-uninstall integration_test/read_aloud_playlist_test.dart -d <设备号>。
/// 测试后仍须覆盖安装正常入口应用，不能把测试入口留在用户设备上。
class _Lease implements TtsAudioLease {
  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
  }
}

Uint8List wav(int milliseconds) {
  const rate = 24000;
  final samples = rate * milliseconds ~/ 1000;
  final bytes = Uint8List(44 + samples * 2);
  final data = ByteData.sublistView(bytes);
  void text(int start, String value) =>
      bytes.setRange(start, start + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(
      44 + i * 2,
      (180 * math.sin(2 * math.pi * 220 * i / rate)).round(),
      Endian.little,
    );
  }
  return bytes;
}

Future<Map<String, Object>> queued(List<File> files) async {
  var players = 0;
  final player = ReadAloudAudioPlayer(
    createPlayer: () {
      players++;
      return audio.AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
        androidApplyAudioAttributes: false,
        maxSkipsOnError: 0,
      );
    },
  );
  final leases = <_Lease>[];
  final engine = FileReadAloudEngine(
    player: player,
    synthesize: (r, c) async {
      final lease = _Lease();
      leases.add(lease);
      return HttpTtsAudio(
        audioPath: files[int.parse(r.text)].path,
        lease: lease,
      );
    },
  );
  final watch = Stopwatch()..start();
  final done = Completer<void>();
  final starts = <int>[];
  final indices = <int>[];
  final session = ReadAloudSession(
    isCurrent: () => true,
    onProgress: (_) {},
    onCompleted: () {
      if (!done.isCompleted) done.complete();
    },
    onError: (e) {
      if (!done.isCompleted) done.completeError(e);
    },
  );
  try {
    final result = await engine.speakPlaylist(
      [
        for (var i = 0; i < files.length; i++)
          ReadAloudPlaylistCue(
            request: ReadAloudRequest(text: '$i'),
            sourceOffset: i,
            paragraphIndex: i,
          ),
      ],
      session,
      onCueStarted: (cue) {
        starts.add(watch.elapsedMilliseconds);
        indices.add(cue.paragraphIndex);
      },
    );
    expect(result, ReadAloudStart.started);
    await done.future.timeout(const Duration(seconds: 40));
    expect(indices, List.generate(files.length, (i) => i));
    expect(players, 1);
    return {
      'totalWallMs': watch.elapsedMilliseconds,
      'startTimesMs': starts,
      'nativePlayerCreations': players,
      'files': files.length,
    };
  } finally {
    await engine.stop();
    await player.dispose();
    expect(leases.map((e) => e.releases), everyElement(1));
  }
}

Future<T> onHost<T>(Future<T> Function() body) async {
  final previous = debugDefaultTargetPlatformOverride;
  try {
    if (Platform.isWindows) {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    }
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('真实WAV验证有界原生队列', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('音频播放队列验证')),
      ),
    );
    await tester.runAsync(
      () => onHost(() async {
        final folder = await Directory.systemTemp.createTemp(
          'legado-playlist-',
        );
        try {
          const count = 8, duration = 400;
          final files = <File>[];
          for (var i = 0; i < count; i++) {
            files.add(
              await File('${folder.path}/$i.wav').writeAsBytes(wav(duration)),
            );
          }
          final after = await queued(files);
          // 仅有顺序回调不足以证明没有跳过音频；总播放时间也应覆盖媒体时长。
          expect(
            after['totalWallMs'],
            greaterThanOrEqualTo(count * duration - 200),
          );
          final result = {
            'fixture': '24kHz/16bit/mono WAV',
            'durationPerFileMs': duration,
            'mediaDurationMs': count * duration,
            'after': after,
            'limits': 'wall time includes loading and Dart callbacks; no acoustic measurement',
          };
          binding.reportData = result;
          // 输出固定夹具的性能摘要，不包含书籍、账号或设备凭据。
          debugPrint('TTS_PLAYLIST_METRICS: ${jsonEncode(result)}');
        } finally {
          await folder.delete(recursive: true);
        }
      }),
    );
  });
  testWidgets('真实HTTP音频书暂停/定位/换绑与自然完成', (tester) async {
    await tester.runAsync(
      () => onHost(() async {
        final bytes = wav(1200);
        final requests = <Uri>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          requests.add(request.uri);
          final range = request.headers.value(HttpHeaders.rangeHeader);
          final match = range == null
              ? null
              : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
          final start = match == null ? 0 : int.parse(match[1]!);
          final end = match == null || match[2]!.isEmpty
              ? bytes.length - 1
              : int.parse(match[2]!);
          final response = request.response;
          response.headers.contentType = ContentType('audio', 'wav');
          response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          if (start >= bytes.length || end < start || end >= bytes.length) {
            response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          } else {
            if (match != null) {
              response.statusCode = HttpStatus.partialContent;
              response.headers.set(
                HttpHeaders.contentRangeHeader,
                'bytes $start-$end/${bytes.length}',
              );
            }
            response.contentLength = end - start + 1;
            if (request.method != 'HEAD') {
              response.add(bytes.sublist(start, end + 1));
            }
          }
          await response.close();
        });
        final player = ReadAloudAudioPlayer();
        final done = Completer<Object?>();
        final oldTag = Object(), newTag = Object();
        player.onCompleted = (tag) {
          if (!done.isCompleted) done.complete(tag);
        };
        player.onError = (error, _) {
          if (!done.isCompleted) done.completeError(error);
        };
        try {
          await player
              .playUrl(
                'http://127.0.0.1:${server.port}/book.wav?chapter=2',
                tag: oldTag,
              )
              .timeout(const Duration(seconds: 15));
          await player.pause();
          expect(done.isCompleted, isFalse);
          await player.seek(const Duration(milliseconds: 300));
          expect(
            await player.resumeWithTag(previousTag: Object(), tag: newTag),
            isFalse,
          );
          expect(
            await player.resumeWithTag(previousTag: oldTag, tag: newTag),
            isTrue,
          );
          expect(
            await done.future.timeout(const Duration(seconds: 15)),
            same(newTag),
          );
          expect(requests, isNotEmpty);
          expect(
            requests.every(
              (uri) =>
                  uri.path == '/book.wav' &&
                  uri.queryParameters['chapter'] == '2',
            ),
            isTrue,
          );
          expect(player.duration.inMilliseconds, 1200);
        } finally {
          await player.dispose();
          await server.close(force: true);
        }
      }),
    );
  });
}
