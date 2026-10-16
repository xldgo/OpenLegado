import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_image_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_audio_cache_repository.dart';
import 'package:flutter_legado/src/data/services/rust_audio_book_service.dart';
import 'package:flutter_legado/src/data/services/rust_audio_cache_download_service.dart';
import 'package:flutter_legado/src/data/services/rust_video_danmaku_service.dart';
import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const image = RustBookImageRepository();
  const cache = RustAudioCacheRepository();
  const downloads = RustAudioCacheDownloadService();
  const audio = RustAudioBookService();
  const video = RustVideoDanmakuService();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('图片缓存编码与读取保留书籍标识，在线解码返回字节', () async {
    when(
      () => bridge.crateFfiFfiSaveImageCache(
        bookUrl: 'b',
        url: 'u',
        bytesBase64: 'AQID',
      ),
    ).thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiGetImageCache(bookUrl: 'b', url: 'u'))
        .thenAnswer((_) async => 'AQID');
    when(
      () => bridge.crateFfiFfiFetchImageWithDecode(url: 'u', sourceJson: 's'),
    ).thenAnswer((_) async => ' {"base64":"AQID","len":3}');
    expect(
      await image.saveImageCache(bookUrl: 'b', url: 'u', bytes: [1, 2, 3]),
      isTrue,
    );
    expect(await image.getImageCache('b', 'u'), [1, 2, 3]);
    expect(await image.fetchImageWithDecode('u', 's'), [1, 2, 3]);
    verify(
      () => bridge.crateFfiFfiSaveImageCache(
        bookUrl: 'b',
        url: 'u',
        bytesBase64: 'AQID',
      ),
    ).called(1);
  });
  test('缓存读写异常保留null/false降级，在线失败上抛', () async {
    final error = StateError('不可读');
    when(
      () => bridge.crateFfiFfiSaveImageCache(
        bookUrl: 'b',
        url: 'u',
        bytesBase64: 'AQ==',
      ),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiGetImageCache(bookUrl: 'b', url: 'u'))
        .thenAnswer((_) async => '***');
    when(
      () => bridge.crateFfiFfiFetchImageWithDecode(url: 'u', sourceJson: 's'),
    ).thenThrow(error);
    expect(
      await image.saveImageCache(bookUrl: 'b', url: 'u', bytes: [1]),
      isFalse,
    );
    expect(await image.getImageCache('b', 'u'), isNull);
    await expectLater(
      image.fetchImageWithDecode('u', 's'),
      throwsA(same(error)),
    );
  });
  for (final payload in [
    '{}',
    '{"base64":"AQID","len":2}',
    '{"base64":2,"len":3}',
  ]) {
    test('在线图片坏传输不伪造有效字节：$payload', () async {
      when(
        () => bridge.crateFfiFfiFetchImageWithDecode(url: 'u', sourceJson: 's'),
      ).thenAnswer((_) async => payload);
      await expectLater(
        image.fetchImageWithDecode('u', 's'),
        throwsFormatException,
      );
    });
  }
  test('下载结果类型化，取消透传既有布尔结果', () async {
    when(
      () => bridge.crateFfiFfiAudioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: 'c',
        chapterTitle: '章',
        playUrl: 'p',
      ),
    ).thenAnswer(
      (_) async => ' {"status":"installed","path":"cache/2.mp3","sizeBytes":4096,"extension":"mp3"}',
    );
    when(() => bridge.crateFfiFfiAudioCacheCancel())
        .thenAnswer((_) async => true);
    final result = await downloads.audioCacheDownload(
      bookUrl: 'b',
      chapterIndex: 2,
      chapterUrl: 'c',
      chapterTitle: '章',
      playUrl: 'p',
    );
    expect(result.status, AudioCacheDownloadStatus.installed);
    expect(result.path, 'cache/2.mp3');
    expect(result.sizeBytes, 4096);
    expect(await downloads.audioCacheCancel(), isTrue);
    verify(
      () => bridge.crateFfiFfiAudioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: 'c',
        chapterTitle: '章',
        playUrl: 'p',
      ),
    ).called(1);
  });
  for (final status in ['already_cached', 'unknown']) {
    test('安装状态$status按明确协议处理', () async {
      when(
        () => bridge.crateFfiFfiAudioCacheDownload(
          bookUrl: 'b',
          chapterIndex: 0,
          chapterUrl: 'c',
          chapterTitle: 't',
          playUrl: 'p',
        ),
      ).thenAnswer(
        (_) async => jsonEncode({
          'status': status,
          'path': 'p',
          'sizeBytes': 1,
          'extension': 'mp3',
        }),
      );
      final operation = downloads.audioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
        playUrl: 'p',
      );
      if (status == 'unknown') {
        await expectLater(operation, throwsFormatException);
      } else {
        expect(
          (await operation).status,
          AudioCacheDownloadStatus.alreadyCached,
        );
      }
    });
  }
  test('缓存查询与清理原样传入章节键并返回真实计数', () async {
    when(
      () => bridge.crateFfiFfiAudioCacheQuery(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: '',
        chapterTitle: ' 章 ',
      ),
    ).thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiAudioCacheList(bookUrl: 'b'))
        .thenAnswer((_) async => Int32List.fromList([2, 5]));
    when(
      () => bridge.crateFfiFfiAudioCacheClearChapter(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: '',
        chapterTitle: ' 章 ',
      ),
    ).thenAnswer((_) async => 2);
    when(() => bridge.crateFfiFfiAudioCacheClearBook(bookUrl: 'b'))
        .thenAnswer((_) async => 4);
    expect(
      await cache.audioCacheQuery(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: '',
        chapterTitle: ' 章 ',
      ),
      isTrue,
    );
    expect(await cache.audioCacheList(bookUrl: 'b'), [2, 5]);
    expect(
      await cache.audioCacheClearChapter(
        bookUrl: 'b',
        chapterIndex: 2,
        chapterUrl: '',
        chapterTitle: ' 章 ',
      ),
      2,
    );
    expect(await cache.audioCacheClearBook(bookUrl: 'b'), 4);
  });

  test('下载坏安装字段不能作为成功结果', () async {
    when(
      () => bridge.crateFfiFfiAudioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
        playUrl: 'p',
      ),
    ).thenAnswer(
      (_) async =>
          '{"status":"installed","path":"p","sizeBytes":"1","extension":"mp3"}',
    );
    await expectLater(
      downloads.audioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
        playUrl: 'p',
      ),
      throwsFormatException,
    );
  });

  test('缓存读面失败沿用降级，下载和取消失败向上传递', () async {
    final error = StateError('IO失败');
    when(
      () => bridge.crateFfiFfiAudioCacheQuery(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
      ),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiAudioCacheList(bookUrl: 'b')).thenThrow(error);
    when(
      () => bridge.crateFfiFfiAudioCacheClearChapter(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
      ),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiAudioCacheClearBook(bookUrl: 'b'))
        .thenThrow(error);
    when(
      () => bridge.crateFfiFfiAudioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
        playUrl: 'p',
      ),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiAudioCacheCancel()).thenThrow(error);
    expect(
      await cache.audioCacheQuery(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
      ),
      isFalse,
    );
    expect(await cache.audioCacheList(bookUrl: 'b'), isEmpty);
    expect(
      await cache.audioCacheClearChapter(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
      ),
      0,
    );
    expect(await cache.audioCacheClearBook(bookUrl: 'b'), 0);
    await expectLater(
      () => downloads.audioCacheDownload(
        bookUrl: 'b',
        chapterIndex: 0,
        chapterUrl: 'c',
        chapterTitle: 't',
        playUrl: 'p',
      ),
      throwsA(same(error)),
    );
    await expectLater(() => downloads.audioCacheCancel(), throwsA(same(error)));
  });
  test('音频取址、毫秒进度与模式合并保留原参数', () async {
    when(
      () =>
          bridge.crateFfiFfiAudioGetChapterMedia(bookUrl: 'b', chapterIndex: 2),
    ).thenAnswer(
      (_) async => ' {"mediaUrl":"p","chapterIndex":2,"isVolume":false,"fromCache":true,"lyric":"词"}',
    );
    when(
      () => bridge.crateFfiFfiAudioGetProgress(bookUrl: 'b', chapterIndex: 2),
    ).thenAnswer((_) async => 3500);
    when(
      () => bridge.crateFfiFfiAudioSaveProgress(
        bookUrl: 'b',
        chapterIndex: 2,
        position: 8000,
      ),
    ).thenAnswer((_) async => true);
    String? raw;
    when(
      () => bridge.crateFfiFfiAudioWithPlayMode(
        readConfig: any(named: 'readConfig'),
        playMode: 2,
      ),
    ).thenAnswer((call) async {
      raw = call.namedArguments[#readConfig] as String?;
      return jsonEncode({
        ...jsonDecode(raw!) as Map<String, dynamic>,
        'playMode': 2,
      });
    });
    final media = await audio.getAudioChapterMedia('b', 2);
    expect(media.mediaUrl, 'p');
    expect(media.fromCache, isTrue);
    expect(media.lyric, '词');
    expect(await audio.getAudioProgress('b', 2), 3500);
    await audio.saveAudioProgress('b', 2, 8000);
    final config = await audio.audioWithPlayMode(
      readConfig: const ReadConfig(openCredits: 15),
      playMode: 2,
    );
    expect(config.playMode, 2);
    expect(config.openCredits, 15);
    expect((jsonDecode(raw!) as Map)['openCredits'], 15);
  });
  test('取址坏响应不当可播放媒体，进度错误不冒充零', () async {
    when(
      () =>
          bridge.crateFfiFfiAudioGetChapterMedia(bookUrl: 'b', chapterIndex: 0),
    ).thenAnswer((_) async => '{}');
    when(
      () => bridge.crateFfiFfiAudioGetProgress(bookUrl: 'b', chapterIndex: 0),
    ).thenThrow(StateError('进度失败'));
    await expectLater(
      audio.getAudioChapterMedia('b', 0),
      throwsFormatException,
    );
    await expectLater(audio.getAudioProgress('b', 0), throwsStateError);
  });
  test('弹幕读取和解析保留现有模型与失败降级', () async {
    when(() => bridge.crateFfiFfiGetVideoDanmaku(bookUrl: 'b', chapterIndex: 0))
        .thenAnswer((_) async => 'xml');
    when(() => bridge.crateFfiFfiParseVideoDanmaku(raw: 'xml')).thenAnswer(
      (_) async =>
          '[{"timeMs":10,"type":1,"textSizeRaw":25,"color":-1,"text":"弹幕"}]',
    );
    expect(await video.getVideoDanmaku(bookUrl: 'b', chapterIndex: 0), 'xml');
    expect((await video.parseVideoDanmaku(raw: 'xml'))!.single.text, '弹幕');
    when(() => bridge.crateFfiFfiParseVideoDanmaku(raw: 'xml'))
        .thenAnswer((_) async => '{}');
    expect(await video.parseVideoDanmaku(raw: 'xml'), isNull);
    when(() => bridge.crateFfiFfiGetVideoDanmaku(bookUrl: 'b', chapterIndex: 0))
        .thenThrow(StateError('无弹幕'));
    expect(await video.getVideoDanmaku(bookUrl: 'b', chapterIndex: 0), isNull);
  });
}
