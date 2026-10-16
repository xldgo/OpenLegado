import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_chapter_cache_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_chapter_cache_repository.dart';
import 'package:flutter_legado/src/data/services/mock_cache_download_service.dart';
import 'package:flutter_legado/src/data/services/rust_cache_download_service.dart';
import 'package:flutter_legado/src/providers/chapter_cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mocks.dart';

void main() {
  test('应用装配直接选择Rust实现，不依赖运行时初始化', () {
    final api = createTestApplication(useMock: false);
    expect(api.chapterCacheRepository, isA<RustChapterCacheRepository>());
    expect(api.cacheDownloadService, isA<RustCacheDownloadService>());
    expect(
      identical(api.chapterCacheRepository, api.chapterCacheRepository),
      isTrue,
    );
    expect(
      identical(api.cacheDownloadService, api.cacheDownloadService),
      isTrue,
    );
  });

  test('Mock沿用缓存占位与空任务语义', () async {
    final api = MockBookApi();
    final cache = api.chapterCacheRepository;
    final downloads = api.cacheDownloadService;
    expect(cache, isA<MockChapterCacheRepository>());
    expect(downloads, isA<MockCacheDownloadService>());
    expect(await cache.clearBookCache('书'), 0);
    expect(await cache.clearChapterCache('书', 2), 0);
    expect(await cache.getCachedChapter('书', 2), '（mock 缓存正文：书 第 2 章）');
    expect(await cache.listCachedChapterUrls('书'), isEmpty);
    expect(await cache.listCachedChapters('书'), isEmpty);
    expect(await downloads.cacheDownloadStart('书', 0, 2), 1);
    expect((await downloads.cacheDownloadProgress(1)).status, 'completed');
    expect(await downloads.cacheDownloadList(), isEmpty);
    expect(await downloads.cacheDownloadCancel(1), isTrue);
    expect(await downloads.listDownloadingChapters('书'), isEmpty);
    expect(await downloads.listFailedChapters('书'), isEmpty);
  });

  test('窄Provider跟随窄依赖替换且可以独立注入', () {
    final first = MockBookApi();
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        chapterCacheRepositoryProvider.overrideWithValue(
          first.chapterCacheRepository,
        ),
        cacheDownloadServiceProvider.overrideWithValue(
          first.cacheDownloadService,
        ),
      ]),
    );
    addTearDown(container.dispose);
    expect(
      container.read(chapterCacheRepositoryProvider),
      same(first.chapterCacheRepository),
    );
    expect(
      container.read(cacheDownloadServiceProvider),
      same(first.cacheDownloadService),
    );
    container.updateOverrides(
      mergeTestOverrides([
        chapterCacheRepositoryProvider.overrideWithValue(
          second.chapterCacheRepository,
        ),
        cacheDownloadServiceProvider.overrideWithValue(
          second.cacheDownloadService,
        ),
      ]),
    );
    expect(
      container.read(chapterCacheRepositoryProvider),
      same(second.chapterCacheRepository),
    );
    expect(
      container.read(cacheDownloadServiceProvider),
      same(second.cacheDownloadService),
    );

    final cache = ChapterCacheRepositoryMock();
    final downloads = CacheDownloadServiceMock();
    final independent = ProviderContainer(
      overrides: [
        chapterCacheRepositoryProvider.overrideWithValue(cache),
        cacheDownloadServiceProvider.overrideWithValue(downloads),
      ],
    );
    addTearDown(independent.dispose);
    expect(independent.read(chapterCacheRepositoryProvider), same(cache));
    expect(independent.read(cacheDownloadServiceProvider), same(downloads));
    final mock = MockBookApi(
      chapterCacheRepository: cache,
      cacheDownloadService: downloads,
    );
    expect(mock.chapterCacheRepository, same(cache));
    expect(mock.cacheDownloadService, same(downloads));
  });
}
