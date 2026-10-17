import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/features/toc/application/toc_cache_controller.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/services/audio_cache_events.dart';

class _Chapters extends Mock implements ChapterCacheRepository {}

class _Downloads extends Mock implements CacheDownloadService {}

class _Audio extends Mock implements AudioCacheRepository {}

void main() {
  late _Chapters chapters;
  late _Downloads downloads;
  late _Audio audio;
  late StreamController<AudioCacheChanged> events;
  late TocCacheController controller;
  var notifications = 0;
  const online = Book(bookUrl: 'book', origin: 'source');

  TocCacheController create([Book book = online]) => TocCacheController(
    readBook: () => book,
    chapters: chapters,
    downloads: downloads,
    audio: audio,
    events: events.stream,
  )..addListener(() => notifications++);

  setUp(() {
    chapters = _Chapters();
    downloads = _Downloads();
    audio = _Audio();
    events = StreamController<AudioCacheChanged>.broadcast(sync: true);
    notifications = 0;
    when(() => chapters.listCachedChapterUrls(any()))
        .thenAnswer((_) async => []);
    when(() => chapters.listCachedChapters(any())).thenAnswer((_) async => {});
    when(() => downloads.listDownloadingChapters(any()))
        .thenAnswer((_) async => []);
    when(() => downloads.listFailedChapters(any())).thenAnswer((_) async => []);
    when(() => audio.audioCacheList(bookUrl: any(named: 'bookUrl')))
        .thenAnswer((_) async => []);
    controller = create();
  });
  tearDown(() async {
    controller.dispose();
    await events.close();
  });

  test('初始状态与轮询字数、运行及失败状态来自原服务', () async {
    when(() => chapters.listCachedChapterUrls('book'))
        .thenAnswer((_) async => ['chapter-1']);
    when(() => downloads.listDownloadingChapters('book'))
        .thenAnswer((_) async => [2]);
    when(() => downloads.listFailedChapters('book'))
        .thenAnswer((_) async => [3]);
    await controller.loadInitial();
    expect(controller.state.urls, {'chapter-1'});
    expect(controller.state.downloading, {2});
    expect(controller.state.failed, {3});
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) async => {'chapter-2': '1000字'});
    await controller.refresh();
    expect(controller.state.urls, {'chapter-2'});
    expect(controller.state.wordCounts, {'chapter-2': '1000字'});
    expect(() => controller.state.urls.add('bad'), throwsUnsupportedError);
    verifyNever(() => audio.audioCacheList(bookUrl: any(named: 'bookUrl')));
  });

  test('相同快照不重复通知，清空字数也会发布', () async {
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) async => {'c': '10字'});
    await controller.refresh();
    await controller.refresh();
    expect(notifications, 1);
    when(() => chapters.listCachedChapters('book')).thenAnswer((_) async => {});
    await controller.refresh();
    expect(controller.state.wordCounts, isEmpty);
    expect(notifications, 2);
  });

  test('轮询主查询失败保留旧快照，子查询失败只保留对应状态', () async {
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) async => {'a': '10字'});
    when(() => downloads.listDownloadingChapters('book'))
        .thenAnswer((_) async => [2]);
    await controller.refresh();
    final previous = controller.state;
    when(() => chapters.listCachedChapters('book')).thenThrow(StateError('离线'));
    await controller.refresh();
    expect(identical(controller.state, previous), isTrue);
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) async => {'b': '20字'});
    when(() => downloads.listDownloadingChapters('book'))
        .thenThrow(StateError('下载查询失败'));
    when(() => downloads.listFailedChapters('book'))
        .thenAnswer((_) async => [4]);
    await controller.refresh();
    expect(controller.state.urls, {'b'});
    expect(controller.state.downloading, {2});
    expect(controller.state.failed, {4});
  });

  test('初始缓存查询失败不阻断其他状态', () async {
    when(() => chapters.listCachedChapterUrls('book'))
        .thenThrow(StateError('缓存失败'));
    when(() => downloads.listFailedChapters('book'))
        .thenAnswer((_) async => [3]);
    await controller.loadInitial();
    expect(controller.state.urls, isEmpty);
    expect(controller.state.failed, {3});
  });

  test('并发刷新复用在途查询', () async {
    final pending = Completer<Map<String, String>>();
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) => pending.future);
    final first = controller.refresh();
    final second = controller.refresh();
    expect(identical(first, second), isTrue);
    pending.complete({'c': '10字'});
    await Future.wait([first, second]);
    verify(() => chapters.listCachedChapters('book')).called(1);
    expect(notifications, 1);
  });

  testWidgets('轮询只启动一份，停止后不再查询，恢复可继续观察', (tester) async {
    controller.start();
    controller.start();
    expect(events.hasListener, isTrue);
    await tester.pump(const Duration(seconds: 1));
    verify(() => chapters.listCachedChapters('book')).called(1);
    controller.stop();
    expect(events.hasListener, isFalse);
    await tester.pump(const Duration(seconds: 3));
    verifyNever(() => chapters.listCachedChapters('book'));
    controller.start();
    await tester.pump(const Duration(seconds: 1));
    verify(() => chapters.listCachedChapters('book')).called(1);
    controller.stop();
  });

  testWidgets('仅本书音频事件触发立即刷新，停止后取消订阅', (tester) async {
    controller.dispose();
    controller = create(online.copyWith(bookType: BookType.audio));
    controller.start();
    events.add(const AudioCacheChanged(bookUrl: 'other', chapterIndex: 0));
    await tester.pump();
    verifyNever(() => audio.audioCacheList(bookUrl: any(named: 'bookUrl')));
    when(() => audio.audioCacheList(bookUrl: 'book'))
        .thenAnswer((_) async => [1]);
    events.add(const AudioCacheChanged(bookUrl: 'book', chapterIndex: 1));
    await tester.pump();
    expect(controller.state.audio, {1});
    controller.stop();
    events.add(const AudioCacheChanged(bookUrl: 'book', chapterIndex: 2));
    await tester.pump();
    verify(() => audio.audioCacheList(bookUrl: 'book')).called(1);
  });

  testWidgets('本地与WebDAV目录不查询远程缓存、不启动轮询', (tester) async {
    for (final origin in [BookType.localTag, 'dav:server']) {
      controller.dispose();
      controller = create(online.copyWith(origin: origin));
      controller.start();
      await controller.loadInitial();
      await controller.refresh();
      await controller.refreshUrls();
      await tester.pump(const Duration(seconds: 2));
      expect(events.hasListener, isFalse);
    }
    verifyZeroInteractions(chapters);
    verifyZeroInteractions(downloads);
    verifyZeroInteractions(audio);
  });

  test('停止时忽略未完成的查询结果', () async {
    final pending = Completer<Map<String, String>>();
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) => pending.future);
    final work = controller.refresh();
    controller.stop();
    pending.complete({'old': '10字'});
    await work;
    expect(notifications, 0);
    verifyZeroInteractions(downloads);
  });

  test('只刷新URL时保留下载、失败及字数状态', () async {
    when(() => chapters.listCachedChapters('book'))
        .thenAnswer((_) async => {'a': '10字'});
    when(() => downloads.listFailedChapters('book'))
        .thenAnswer((_) async => [3]);
    await controller.refresh();
    when(() => chapters.listCachedChapterUrls('book'))
        .thenAnswer((_) async => ['b']);
    await controller.refreshUrls();
    expect(controller.state.urls, {'b'});
    expect(controller.state.wordCounts, {'a': '10字'});
    expect(controller.state.failed, {3});
  });
}
