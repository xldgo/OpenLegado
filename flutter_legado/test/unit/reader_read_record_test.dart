import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_record_repository_provider.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  const book = Book(bookUrl: 'fixture://record', name: '测试书籍');
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
    when(() => api.getChapters(book.bookUrl)).thenAnswer(
      (_) async => [
        const BookChapter(url: 'fixture://chapter', title: '正文', index: 0),
      ],
    );
    when(() => api.getChapterContentFull(book.bookUrl, 0))
        .thenAnswer((_) async => '测试正文。');
    when(
      () => api.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        readRecordRepositoryProvider.overrideWithValue(records),
      ],
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
    when(() => records.putReadRecord(any())).thenAnswer((_) async {});
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    final saved = verify(() => records.putReadRecord(captureAny())).captured
        .cast<ReadRecord>();
    expect(saved, hasLength(2));
    expect(saved.first.bookName, book.name);
    expect(saved.first.readTime, greaterThan(6000));
    expect(saved.last.readTime, greaterThan(saved.first.readTime));
    expect(saved.first.lastRead, greaterThan(0));
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

  test('记录查询和写入失败均不阻断正文或进度保存', () async {
    when(() => records.getReadRecords())
        .thenAnswer((_) async => throw StateError('查询失败'));
    when(() => records.putReadRecord(any()))
        .thenAnswer((_) async => throw StateError('写入失败'));
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await reader.saveProgress();
    expect(container.read(readerNotifierProvider).chapterContent, '测试正文。');
    expect(container.read(readerNotifierProvider).error, isNull);
    verify(() => records.putReadRecord(any())).called(1);
    verify(
      () => api.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterPos: any(named: 'chapterPos'),
      ),
    ).called(1);
  });
}
