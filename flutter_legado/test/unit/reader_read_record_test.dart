import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_record_repository_provider.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/providers/read_record_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  const book = Book(bookUrl: 'fixture://record', name: '测试书籍', author: '真实作者');
  late MockRustApi api;
  late _Records records;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(const ReadRecord());
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'enableReadRecord': true});
    api = MockRustApi();
    records = _Records();
    when(() => api.readingRepository.getChapters(book.bookUrl)).thenAnswer(
      (_) async => [
        const BookChapter(url: 'fixture://chapter', title: '正文', index: 0),
      ],
    );
    when(() => api.readingRepository.getChapterContentFull(book.bookUrl, 0))
        .thenAnswer((_) async => '测试正文。');
    when(
      () => api.readingRepository.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        readRecordRepositoryProvider.overrideWithValue(records),
      ]),
    );
    addTearDown(container.dispose);
  });

  test('保存进度复用已有累计毫秒及同名合并，连续保存不会重置', () async {
    when(() => records.getReadRecords()).thenAnswer(
      (_) async => [
        const ReadRecord(bookName: '测试书籍', readTime: 4000),
        const ReadRecord(bookName: '测试书籍', deviceId: '其他设备', readTime: 2000),
        const ReadRecord(bookName: '其他书籍', readTime: 99000),
      ],
    );
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((_) async {});
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    final saved = verify(
      () => records.putReadRecord(
        captureAny(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).captured.cast<ReadRecord>();
    expect(saved, hasLength(2));
    expect(saved.first.bookName, book.name);
    expect(saved.first.readTime, greaterThan(6000));
    expect(saved.last.readTime, greaterThan(saved.first.readTime));
    expect(saved.first.lastRead, greaterThan(0));
    expect(saved.first.author, book.author);
    expect(saved.first.startTime, lessThan(saved.first.lastRead));
    expect(saved.last.startTime, saved.first.lastRead);
    verify(() => records.getReadRecords()).called(1);
    verifyNever(() => api.readRecordRepository);
    expect(container.read(readerNotifierProvider).chapterContent, '测试正文。');
  });

  test('关闭记录时开书与保存均不调用记录存储', () async {
    SharedPreferences.setMockInitialValues({'enableReadRecord': false});
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await reader.saveProgress();
    verifyZeroInteractions(records);
    expect(container.read(readerNotifierProvider).chapterContent, '测试正文。');
  });

  test('运行中关闭共享记录偏好立即影响阅读器保存，重新开启继续记录', () async {
    when(() => records.getReadRecords()).thenAnswer((_) async => []);
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((_) async {});
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await container
        .read(readRecordSettingsRepositoryProvider)
        .update(enableRecord: false);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    verifyNever(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    );
    await container
        .read(readRecordSettingsRepositoryProvider)
        .update(enableRecord: true);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    verify(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).called(1);
  });

  test('记录查询和写入失败均不阻断正文或进度保存', () async {
    when(() => records.getReadRecords())
        .thenAnswer((_) async => throw StateError('查询失败'));
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((_) async => throw StateError('写入失败'));
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    expect(container.read(readerNotifierProvider).chapterContent, '测试正文。');
    expect(container.read(readerNotifierProvider).error, isNull);
    verify(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).called(1);
    verify(
      () => api.readingRepository.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterPos: any(named: 'chapterPos'),
      ),
    ).called(1);
  });

  test('失败重试保留未保存时段，不丢失累计增量', () async {
    when(() => records.getReadRecords()).thenAnswer((_) async => []);
    final saved = <ReadRecord>[];
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((call) async {
      saved.add(call.positionalArguments.single as ReadRecord);
      if (saved.length == 1) throw StateError('首次写入失败');
    });
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    expect(saved, hasLength(2));
    expect(saved.last.startTime, saved.first.startTime);
    expect(saved.last.readTime, saved.last.lastRead - saved.first.startTime!);
  });

  test('较早的保存迟到完成，不覆盖后续累计起点', () async {
    when(() => records.getReadRecords()).thenAnswer((_) async => []);
    final firstWrite = Completer<void>();
    final saved = <ReadRecord>[];
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((call) async {
      saved.add(call.positionalArguments.single as ReadRecord);
      if (saved.length == 1) await firstWrite.future;
    });
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final pending = reader.saveProgress();
    while (saved.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    firstWrite.complete();
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    expect(saved, hasLength(3));
    expect(saved.last.startTime, saved[1].lastRead);
    expect(saved.last.readTime, greaterThan(saved[1].readTime));
  });
}
