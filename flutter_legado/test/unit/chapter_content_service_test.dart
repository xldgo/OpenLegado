import 'dart:async';

import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/providers/chapter_cache_provider.dart';
import 'package:flutter_legado/src/providers/chapter_content_provider.dart';
import 'package:flutter_legado/src/providers/reading_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class ContentReading extends Mock implements ReadingRepository {}

class ContentCache extends Mock implements ChapterCacheRepository {}

void main() {
  late ContentReading reading;
  late ContentCache cache;
  late ChapterContentService service;
  const bookUrl = 'stable-book';
  const chapterUrl = 'https://current-source.test/chapter';
  const sourceUrl = 'https://current-source.test';

  setUp(() {
    reading = ContentReading();
    cache = ContentCache();
    service = ChapterContentService(reading: reading, cache: cache);
    when(() => reading.getChapterContent(any(), any()))
        .thenAnswer((_) async => '本地纯正文');
    when(() => reading.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '在线纯正文');
    when(() => cache.clearChapterCache(any(), any()))
        .thenAnswer((_) async => 1);
    when(() => reading.fetchChapterContent(any(), any(), any()))
        .thenAnswer((_) async => '刷新正文');
  });

  group('纯正文选路', () {
    for (final extension in [
      'epub',
      'txt',
      'text',
      'mobi',
      'azw',
      'azw3',
      'pdf',
      'cbz',
    ]) {
      test('本地$extension保留相对标识，由底层还原路径', () async {
        final url = 'books/中文 小说.${extension.toUpperCase()}';
        expect(await service.read(url, 3), '本地纯正文');
        verify(() => reading.getChapterContent(url, 3)).called(1);
        verifyNever(() => reading.getChapterContentFull(any(), any()));
        verifyZeroInteractions(cache);
      });
    }

    for (final url in [
      bookUrl,
      'https://source.test/123',
      'books/a.umd',
      'books/a.zip',
      'books/a.epub.bak',
    ]) {
      test('非本地判据$url走完整正文入口', () async {
        expect(await service.read(url, 2), '在线纯正文');
        verify(() => reading.getChapterContentFull(url, 2)).called(1);
        verifyNever(() => reading.getChapterContent(any(), any()));
        verifyZeroInteractions(cache);
      });
    }

    test('不另存正文副本，设置或缓存内容更新后继续交给仓储读取', () async {
      var current = '原正文';
      when(() => reading.getChapterContentFull(bookUrl, 0))
          .thenAnswer((_) async => current);
      expect(await service.read(bookUrl, 0), '原正文');
      current = '替换规则更新后的正文';
      expect(await service.read(bookUrl, 0), current);
      verify(() => reading.getChapterContentFull(bookUrl, 0)).called(2);
      verifyZeroInteractions(cache);
    });

    test('本地解析或在线请求失败原样传播，不切换链路重试', () async {
      final localError = StateError('文件不可读');
      final onlineError = StateError('网络不可用');
      when(() => reading.getChapterContent('books/a.txt', 1))
          .thenThrow(localError);
      when(() => reading.getChapterContentFull(bookUrl, 1))
          .thenThrow(onlineError);
      await expectLater(
        () => service.read('books/a.txt', 1),
        throwsA(same(localError)),
      );
      await expectLater(
        () => service.read(bookUrl, 1),
        throwsA(same(onlineError)),
      );
      verify(() => reading.getChapterContent('books/a.txt', 1)).called(1);
      verify(() => reading.getChapterContentFull(bookUrl, 1)).called(1);
      verifyZeroInteractions(cache);
    });
  });

  Future<String> refresh() => service.refresh(
    bookUrl: bookUrl,
    chapterIndex: 4,
    chapterUrl: chapterUrl,
    sourceUrl: sourceUrl,
  );

  group('强制刷新', () {
    test('等待当前章缓存失效后才抓取，稳定书籍键和当前源地址分开传递', () async {
      final clearing = Completer<int>();
      when(() => cache.clearChapterCache(bookUrl, 4))
          .thenAnswer((_) => clearing.future);
      final pending = refresh();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => reading.fetchChapterContent(any(), any(), any()));
      clearing.complete(1);
      expect(await pending, '刷新正文');
      verifyInOrder([
        () => cache.clearChapterCache(bookUrl, 4),
        () => reading.fetchChapterContent(bookUrl, chapterUrl, sourceUrl),
      ]);
      verifyNever(() => cache.clearBookCache(any()));
      verifyNever(() => reading.getChapterContentFull(any(), any()));
    });

    test('没有旧缓存也会抓取新正文', () async {
      when(() => cache.clearChapterCache(bookUrl, 4))
          .thenAnswer((_) async => 0);
      expect(await refresh(), '刷新正文');
      verify(() => reading.fetchChapterContent(bookUrl, chapterUrl, sourceUrl))
          .called(1);
    });

    test('缓存失效失败立即上抛，不伪装刷新成功或继续抓取', () async {
      final error = StateError('失效失败');
      when(() => cache.clearChapterCache(bookUrl, 4)).thenThrow(error);
      await expectLater(refresh(), throwsA(same(error)));
      verifyZeroInteractions(reading);
    });

    test('抓取失败保留原始错误，不追加整书清理或重试', () async {
      final error = StateError('抓取失败');
      when(() => reading.fetchChapterContent(bookUrl, chapterUrl, sourceUrl))
          .thenThrow(error);
      await expectLater(refresh(), throwsA(same(error)));
      verifyInOrder([
        () => cache.clearChapterCache(bookUrl, 4),
        () => reading.fetchChapterContent(bookUrl, chapterUrl, sourceUrl),
      ]);
      verifyNoMoreInteractions(cache);
      verifyNoMoreInteractions(reading);
    });
  });

  test('正文服务由窄依赖装配，仓储替换后新调用使用新实例', () async {
    final container = ProviderContainer(
      overrides: [
        readingRepositoryProvider.overrideWithValue(reading),
        chapterCacheRepositoryProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    final first = container.read(chapterContentServiceProvider);
    expect(await first.read(bookUrl, 0), '在线纯正文');
    expect(container.read(chapterContentServiceProvider), same(first));
    final next = ContentReading();
    when(() => next.getChapterContentFull(bookUrl, 0))
        .thenAnswer((_) async => '替换仓储正文');
    container.updateOverrides([
      readingRepositoryProvider.overrideWithValue(next),
      chapterCacheRepositoryProvider.overrideWithValue(cache),
    ]);
    final second = container.read(chapterContentServiceProvider);
    expect(second, isNot(same(first)));
    expect(await second.read(bookUrl, 0), '替换仓储正文');
    verify(() => next.getChapterContentFull(bookUrl, 0)).called(1);
    verifyZeroInteractions(cache);
  });
}
