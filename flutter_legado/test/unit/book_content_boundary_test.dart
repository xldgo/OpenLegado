import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/domain/models/book_content_result.dart';
import 'package:flutter_legado/src/providers/book_content_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/export_service.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(const BookExportOptions()));

  test('Mock本地导入、书架和导出共用同一书籍事实', () async {
    final api = MockBookApi();
    final book = await api.localBookService.importLocalBook(r'E:\书籍\新书.cbz');
    expect((await api.bookshelfRepository.getBook(book.bookUrl))?.name, '新书');
    final exported = await api.bookExportService.bookExportWithOptions(
      bookUrl: book.bookUrl,
      format: 'txt',
      includeToc: true,
    );
    expect(exported.fileName, '新书.txt');
    expect(exported.bytes, isNotEmpty);
    expect(
      (await api.bookExportService.bookExportInfo(
        bookUrl: book.bookUrl,
        format: 'txt',
      )).chapterCount,
      0,
    );
    final files = await api.bookArchiveService.archiveImportZip(
      zipPath: 'a.zip',
      outputDir: r'E:\out',
    );
    expect(files, hasLength(2));
    expect(files.first, endsWith('book1.txt'));
    expect(
      (await api.reviewService.reviewGetDetail('{}', {}, 2)).nextPageUrl,
      isNull,
    );
  });

  test('四个窄Provider可独立注入，不创建根接口', () {
    final local = LocalBookServiceMock();
    final archive = BookArchiveServiceMock();
    final exporter = BookExportServiceMock();
    final review = ReviewServiceMock();
    final c = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
        localBookServiceProvider.overrideWithValue(local),
        bookArchiveServiceProvider.overrideWithValue(archive),
        bookExportServiceProvider.overrideWithValue(exporter),
        reviewServiceProvider.overrideWithValue(review),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(localBookServiceProvider), same(local));
    expect(c.read(bookArchiveServiceProvider), same(archive));
    expect(c.read(bookExportServiceProvider), same(exporter));
    expect(c.read(reviewServiceProvider), same(review));
  });

  test('正式工厂读取内容能力不初始化第二份运行时', () {
    final api = createBookApi(useMock: false);
    expect(api.localBookService, same(api.localBookService));
    expect(api.bookArchiveService, same(api.bookArchiveService));
    expect(api.bookExportService, same(api.bookExportService));
    expect(api.reviewService, same(api.reviewService));
  });

  test('导出编排使用窄接口，保留有效选项并过滤空值', () async {
    final exporter = BookExportServiceMock();
    final webDav = WebDavServiceMock();
    when(
      () => exporter.bookExportWithOptions(
        bookUrl: 'b',
        format: 'txt',
        includeToc: true,
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => throw StateError('用于检查选项'));
    final service = ExportService(exporter: exporter, webDav: webDav);
    await expectLater(
      service.export(
        bookUrl: 'b',
        format: 'txt',
        includeToc: true,
        encoding: 'GBK',
        startChapter: -1,
        endChapter: 5,
        fileNameTemplate: '  {name}  ',
      ),
      throwsStateError,
    );
    final options =
        verify(
              () => exporter.bookExportWithOptions(
                bookUrl: 'b',
                format: 'txt',
                includeToc: true,
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as BookExportOptions;
    expect(options.encoding, 'GBK');
    expect(options.startChapter, isNull);
    expect(options.endChapter, 5);
    expect(options.fileNameTemplate, '{name}');
    await expectLater(
      service.export(bookUrl: 'b', format: 'unknown', includeToc: true),
      throwsA(isA<ExportException>()),
    );
    verifyNoMoreInteractions(exporter);
    verifyZeroInteractions(webDav);
  });
}
