import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/models/book_chapter.dart';
import 'package:flutter_legado/src/providers/media_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mocks.dart';
import '../mocks/reading_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('五个媒体Provider可独立替换，不创建根接口', () {
    final image = BookImageRepositoryMock();
    final cache = AudioCacheRepositoryMock();
    final downloads = AudioCacheDownloadServiceMock();
    final audio = AudioBookServiceMock();
    final video = VideoDanmakuServiceMock();
    final container = ProviderContainer(
      overrides: [
        bookImageRepositoryProvider.overrideWithValue(image),
        audioCacheRepositoryProvider.overrideWithValue(cache),
        audioCacheDownloadServiceProvider.overrideWithValue(downloads),
        audioBookServiceProvider.overrideWithValue(audio),
        videoDanmakuServiceProvider.overrideWithValue(video),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(bookImageRepositoryProvider), same(image));
    expect(container.read(audioCacheRepositoryProvider), same(cache));
    expect(container.read(audioCacheDownloadServiceProvider), same(downloads));
    expect(container.read(audioBookServiceProvider), same(audio));
    expect(container.read(videoDanmakuServiceProvider), same(video));
  });

  test('正式装配重复读取返回同一媒体实例且不启动原生运行时', () {
    final api = createTestApplication(useMock: false);
    expect(api.bookImageRepository, same(api.bookImageRepository));
    expect(api.audioCacheRepository, same(api.audioCacheRepository));
    expect(api.audioCacheDownloadService, same(api.audioCacheDownloadService));
    expect(api.audioBookService, same(api.audioBookService));
    expect(api.videoDanmakuService, same(api.videoDanmakuService));
  });

  test('Provider下载与清理读取同一Mock缓存，书籍之间隔离', () async {
    final api = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    final downloads = container.read(audioCacheDownloadServiceProvider);
    final cache = container.read(audioCacheRepositoryProvider);
    for (final book in ['a', 'b']) {
      for (final index in [2, 0]) {
        final result = await downloads.audioCacheDownload(
          bookUrl: book,
          chapterIndex: index,
          chapterUrl: 'c$index',
          chapterTitle: '章$index',
          playUrl: 'https://cdn/$index.M4A?token=t',
        );
        expect(result.status, AudioCacheDownloadStatus.installed);
        expect(result.extension, 'm4a');
      }
    }
    expect(await cache.audioCacheList(bookUrl: 'a'), [0, 2]);
    expect(await cache.audioCacheClearBook(bookUrl: 'a'), 2);
    expect(await cache.audioCacheList(bookUrl: 'a'), isEmpty);
    expect(await cache.audioCacheList(bookUrl: 'b'), [0, 2]);
    expect(await cache.audioCacheClearBook(bookUrl: 'a'), 0);
  });

  test('图片缓存读写各自复制字节，同一URL按书隔离', () async {
    final images = MockBookApi().bookImageRepository;
    final bytes = [1, 2, 3];
    await images.saveImageCache(bookUrl: 'a', url: 'u', bytes: bytes);
    bytes[0] = 9;
    final first = await images.getImageCache('a', 'u');
    expect(first, [1, 2, 3]);
    first![1] = 9;
    expect(await images.getImageCache('a', 'u'), [1, 2, 3]);
    expect(await images.getImageCache('b', 'u'), isNull);
  });

  test('音频Mock从注入目录取媒体，卷标题不取址，模式合并保留其他配置', () async {
    final api = MockBookApi(
      readingRepository: TestReadingRepository(
        getChapters: (_) async => const [
          BookChapter(title: '卷', index: 0, url: 'volume', isVolume: true),
          BookChapter(title: '章', index: 1, url: 'c', resourceUrl: ' media '),
        ],
      ),
    );
    final audio = api.audioBookService;
    expect((await audio.getAudioChapterMedia('b', 0)).mediaUrl, isEmpty);
    final media = await audio.getAudioChapterMedia('b', 1);
    expect(media.mediaUrl, 'media');
    expect(media.title, '章');
    expect(media.url, 'c');
    expect(media.chapterIndex, 1);
    expect(await audio.getAudioProgress('b', 1), 0);
    final config = await audio.audioWithPlayMode(
      readConfig: const ReadConfig(
        openCredits: 12,
        closeCredits: 8,
        ttsEngine: 'tts',
      ),
      playMode: 2,
    );
    expect(config.playMode, 2);
    expect(config.openCredits, 12);
    expect(config.closeCredits, 8);
    expect(config.ttsEngine, 'tts');
  });
}
