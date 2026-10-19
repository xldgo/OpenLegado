import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/repositories/app_download_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';

import '../../../fixtures/home_settings_storage.dart';

import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/review_service.dart';
import 'package:flutter_legado/src/domain/models/review.dart';
import 'package:flutter_legado/src/features/reader/application/reader_chapter_coordinator.dart';
import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Content extends Mock implements ChapterContentService {}

class _Sources extends Mock implements BookSourceRepository {}

class _Reviews extends Mock implements ReviewService {}

void main() {
  const book = Book(
    bookUrl: 'https://book/1',
    name: '小说',
    origin: 'https://source/1',
  );
  final chapters = List.generate(
    5,
    (i) => BookChapter(url: 'https://chapter/$i', title: '第$i章', index: i),
  );
  late _Content content;
  late _Sources sources;
  late _Reviews reviews;
  late ReaderChapterCoordinator coordinator;
  late ReaderState state;
  late List<(String, int)> reads;
  late bool disposed;
  late AppDownloadSettingsRepository downloadSettings;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));
  setUp(() {
    content = _Content();
    sources = _Sources();
    reviews = _Reviews();
    reads = [];
    disposed = false;
    state = ReaderState(
      currentBook: book,
      chapters: chapters,
      currentChapterIndex: 2,
    );
    when(() => content.read(any(), any())).thenAnswer((call) async {
      reads.add((
        call.positionalArguments[0] as String,
        call.positionalArguments[1] as int,
      ));
      return '缓存正文';
    });
    when(() => sources.getBookSources()).thenAnswer(
      (_) async => [BookSource(bookSourceUrl: book.origin, mainJs: 'review')],
    );
    when(() => reviews.reviewGetSummary(any(), any())).thenAnswer(
      (_) async => ReviewSummary(counts: {1: 3}, keys: {1: '段落查询参数'}),
    );
    final settingsService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: HomeSettingsStorage()
          ..values.addAll({'preDownloadNum': 2, 'preDownloadNumPrev': 2}),
      },
    );
    addTearDown(settingsService.dispose);
    downloadSettings = AppDownloadSettingsRepository(settingsService);
    coordinator = ReaderChapterCoordinator(
      content: content,
      settings: downloadSettings,
      sources: sources,
      reviews: reviews,
    );
    addTearDown(() {
      if (!disposed) coordinator.dispose();
    });
  });

  Future<void> completeChapter(ReaderState next) async {
    coordinator.observe(next.copyWith(isLoading: true));
    coordinator.observe(next.copyWith(isLoading: false));
    await Future<void>.delayed(Duration.zero);
  }

  test('加载完成才按距离预取前后两章，摘要使用同章原始上下文', () async {
    coordinator.observe(state.copyWith(isLoading: true));
    expect(reads, isEmpty);
    coordinator.observe(state);
    await Future<void>.delayed(Duration.zero);
    expect(reads, [
      for (final i in [3, 1, 4, 0]) (book.bookUrl, i),
    ]);
    final call = verify(
      () => reviews.reviewGetSummary(captureAny(), captureAny()),
    ).captured;
    expect(
      jsonDecode(call[0] as String),
      containsPair('bookSourceUrl', book.origin),
    );
    final request = call[1] as Map<String, dynamic>;
    expect(request['chapterUrl'], chapters[2].url);
    expect(request['book'], book.toJson());
    expect(request['chapter'], chapters[2].toJson());
    expect(coordinator.value.counts, {1: 3});
    expect(coordinator.value.keys, {1: '段落查询参数'});
    expect(coordinator.value.belongsTo(state), isTrue);
    expect(() => coordinator.value.counts[1] = 9, throwsUnsupportedError);
  });

  test('字号、选区和重复完成通知不重复预取同章', () async {
    await completeChapter(state);
    coordinator.observe(state.copyWith(fontSize: 27, showControls: true));
    await completeChapter(state);
    expect(reads, hasLength(4));
    verify(() => sources.getBookSources()).called(1);
  });

  test('进入已就绪章节仍会预取，刷新加载时不推进窗口', () async {
    coordinator.observe(state);
    await Future<void>.delayed(Duration.zero);
    expect(reads, hasLength(4));
    coordinator.observe(state.copyWith(isLoading: true));
    await downloadSettings.update(
      (s) => s.copyWith(preDownloadNum: 0, preDownloadNumPrev: 0),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reads, hasLength(4));
  });

  test('共享设置变更重建当前预取窗口，不重复触发段评或改动阅读位置', () async {
    await downloadSettings.update(
      (s) => s.copyWith(preDownloadNum: 0, preDownloadNumPrev: 0),
    );
    await completeChapter(state);
    expect(reads, isEmpty);
    await downloadSettings.update((s) => s.copyWith(preDownloadNumPrev: 1));
    await Future<void>.delayed(Duration.zero);
    expect(reads, [(book.bookUrl, 1)]);
    expect(state.currentChapterIndex, 2);
    verify(() => sources.getBookSources()).called(1);
  });

  test('首尾章只预取合法范围，切书后同一章索引仍触发新的预取', () async {
    await completeChapter(state.copyWith(currentChapterIndex: 0));
    expect(reads, [(book.bookUrl, 1), (book.bookUrl, 2)]);
    reads.clear();
    await completeChapter(state.copyWith(currentChapterIndex: 4));
    expect(reads, [(book.bookUrl, 3), (book.bookUrl, 2)]);
    reads.clear();
    final other = book.copyWith(bookUrl: 'https://book/2');
    await completeChapter(
      state.copyWith(currentBook: other, currentChapterIndex: 4),
    );
    expect(reads, [(other.bookUrl, 3), (other.bookUrl, 2)]);
  });

  for (final (label, source) in [
    ('书源不存在', null),
    ('没有段评规则', BookSource(bookSourceUrl: book.origin)),
    (
      '规则关闭',
      BookSource.fromJson({
        'bookSourceUrl': book.origin,
        'ruleReview': {'enabled': false, 'reviewSummaryUrl': 'https://summary'},
      }),
    ),
    (
      '规则地址空白',
      BookSource.fromJson({
        'bookSourceUrl': book.origin,
        'ruleReview': {'enabled': true, 'reviewSummaryUrl': ' '},
      }),
    ),
  ]) {
    test('$label时不调用段评服务', () async {
      when(() => sources.getBookSources()).thenAnswer((_) async => [?source]);
      await completeChapter(state);
      expect(coordinator.value.counts, isEmpty);
      verifyZeroInteractions(reviews);
    });
  }

  test('启用的URL规则和mainJs两种入口均沿用现有启用语义', () async {
    when(() => sources.getBookSources()).thenAnswer(
      (_) async => [
        BookSource.fromJson({
          'bookSourceUrl': book.origin,
          'ruleReview': {
            'enabled': true,
            'reviewSummaryUrl': 'https://summary',
          },
        }),
      ],
    );
    await completeChapter(state);
    expect(coordinator.value.counts, {1: 3});
    verify(() => reviews.reviewGetSummary(any(), any())).called(1);
  });

  test('加载失败不预取，不让辅助任务影响章节错误', () async {
    await completeChapter(state.copyWith(error: '正文错误'));
    expect(reads, isEmpty);
    verifyZeroInteractions(reviews);
    await completeChapter(state);
    expect(reads, hasLength(4));
  });

  test('切章立即失效旧摘要，迟到结果不属于新章', () async {
    final pending = Completer<ReviewSummary>();
    when(() => reviews.reviewGetSummary(any(), any()))
        .thenAnswer((_) => pending.future);
    await completeChapter(state);
    final next = state.copyWith(currentChapterIndex: 3, isLoading: true);
    coordinator.observe(next);
    pending.complete(ReviewSummary(counts: {1: 99}, keys: {}));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.value.counts, isEmpty);
    expect(coordinator.value.belongsTo(next), isFalse);
  });

  test('同章换源清除旧摘要；没有规则的新源不会残留角标', () async {
    await completeChapter(state);
    final next = state.copyWith(
      currentBook: book.copyWith(origin: 'https://source/2'),
    );
    await completeChapter(next);
    expect(coordinator.value.counts, isEmpty);
    expect(coordinator.value.belongsTo(state), isFalse);
  });

  test('预取或摘要失败保持静默，销毁后不会发布摘要', () async {
    when(() => content.read(any(), any()))
        .thenAnswer((_) async => throw StateError('预取失败'));
    final pending = Completer<ReviewSummary>();
    when(() => reviews.reviewGetSummary(any(), any()))
        .thenAnswer((_) => pending.future);
    var notifications = 0;
    coordinator.addListener(() => notifications++);
    await completeChapter(state);
    coordinator.dispose();
    disposed = true;
    pending.complete(ReviewSummary(counts: {1: 9}, keys: {}));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 0);
  });
}
