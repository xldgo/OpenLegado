import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/file_dto.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/models/book.dart';

import 'package:flutter_legado/src/bridge/content_dto.dart';
import 'package:flutter_legado/src/data/bridge/content_dto_mapping.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_local_book_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_archive_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_export_service.dart';
import 'package:flutter_legado/src/data/services/rust_review_service.dart';
import 'package:flutter_legado/src/domain/models/book_content_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const local = RustLocalBookService();
  const archive = RustBookArchiveService();
  const exporter = RustBookExportService();
  const reviews = RustReviewService();
  setUpAll(() {
    registerFallbackValue(reviewRequestToDto({}));
  });
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('传输异常原样传递，不转换成空结果或成功', () async {
    final error = StateError('传输失败');
    when(() => bridge.crateFfiFfiImportLocalBook(filePath: 'p'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiCbzReadPage(path: 'p', entry: 'e'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiArchiveListZipFiles(zipPath: 'z'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiBookExportInfo(bookUrl: 'b', format: 'txt'))
        .thenThrow(error);
    when(
      () => bridge.crateFfiFfiReviewGetSummary(
        sourceJson: 's',
        request: reviewRequestToDto({}),
      ),
    ).thenThrow(error);
    await expectLater(local.importLocalBook('p'), throwsA(same(error)));
    await expectLater(
      local.cbzReadPage(path: 'p', entry: 'e'),
      throwsA(same(error)),
    );
    await expectLater(
      archive.archiveListZipFiles(zipPath: 'z'),
      throwsA(same(error)),
    );
    await expectLater(
      exporter.bookExportInfo(bookUrl: 'b', format: 'txt'),
      throwsA(same(error)),
    );
    await expectLater(reviews.reviewGetSummary('s', {}), throwsA(same(error)));
  });

  test('导入与CBZ按原路径调用，解码返回书籍和字节', () async {
    when(() => bridge.crateFfiFfiImportLocalBook(filePath: '目录/书.cbz'))
        .thenAnswer(
          (_) async => LocalImportDto(
            success: true,
            book: bookToDto(
              const Book(bookUrl: 'file://书.cbz', name: '漫画', bookType: 4160),
            ),
          ),
        );
    when(
      () => bridge.crateFfiFfiCbzReadPage(
        path: '目录/书.cbz',
        entry: 'cbz://封面.png',
      ),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    final book = await local.importLocalBook('目录/书.cbz');
    expect(book.name, '漫画');
    expect(await local.cbzReadPage(path: '目录/书.cbz', entry: 'cbz://封面.png'), [
      1,
      2,
      3,
    ]);
    verify(() => bridge.crateFfiFfiImportLocalBook(filePath: '目录/书.cbz'))
        .called(1);
    verify(
      () => bridge.crateFfiFfiCbzReadPage(
        path: '目录/书.cbz',
        entry: 'cbz://封面.png',
      ),
    ).called(1);
  });

  for (final payload in [
    const LocalImportDto(success: true),
    const LocalImportDto(success: false, error: '文件不存在'),
  ]) {
    test('坏导入结果不能伪造书籍：$payload', () async {
      when(() => bridge.crateFfiFfiImportLocalBook(filePath: 'p'))
          .thenAnswer((_) async => payload);
      await expectLater(local.importLocalBook('p'), throwsA(isA<Exception>()));
    });
  }
  test('CBZ字节直传不改变完整字节域或伪造空包内容', () async {
    final bytes = Uint8List.fromList(List.generate(256, (i) => i));
    when(() => bridge.crateFfiFfiCbzReadPage(path: 'p', entry: 'e'))
        .thenAnswer((_) async => bytes);
    expect(await local.cbzReadPage(path: 'p', entry: 'e'), same(bytes));
    when(() => bridge.crateFfiFfiCbzReadPage(path: 'p', entry: 'e'))
        .thenAnswer((_) async => Uint8List(0));
    expect(await local.cbzReadPage(path: 'p', entry: 'e'), isEmpty);
  });

  test('ZIP/RAR列表、密码和解包参数一致，返回文件路径', () async {
    when(() => bridge.crateFfiFfiArchiveListZipFiles(zipPath: 'z'))
        .thenAnswer((_) async => ['目录/书.txt']);
    when(
      () => bridge.crateFfiFfiArchiveListRarFiles(rarPath: 'r', password: '密码'),
    ).thenAnswer((_) async => <String>[]);
    when(
      () => bridge.crateFfiFfiArchiveImportZip(zipPath: 'z', outputDir: 'out'),
    ).thenAnswer(
      (_) async =>
          const ArchiveImportDto(success: true, extractedFiles: ['out/书.txt']),
    );
    when(
      () => bridge.crateFfiFfiArchiveImportRar(
        rarPath: 'r',
        outputDir: 'out',
        password: '密码',
      ),
    ).thenAnswer(
      (_) async => const ArchiveImportDto(success: true, extractedFiles: []),
    );
    expect(await archive.archiveListZipFiles(zipPath: 'z'), ['目录/书.txt']);
    expect(
      await archive.archiveListRarFiles(rarPath: 'r', password: '密码'),
      isEmpty,
    );
    expect(await archive.archiveImportZip(zipPath: 'z', outputDir: 'out'), [
      'out/书.txt',
    ]);
    expect(
      await archive.archiveImportRar(
        rarPath: 'r',
        outputDir: 'out',
        password: '密码',
      ),
      isEmpty,
    );
    verify(
      () => bridge.crateFfiFfiArchiveImportRar(
        rarPath: 'r',
        outputDir: 'out',
        password: '密码',
      ),
    ).called(1);
  });

  test('编码检测与转换返回类型化字段及新路径', () async {
    when(
      () => bridge.crateFfiFfiArchiveDetectEncoding(filePath: 'p'),
    ).thenAnswer(
      (_) async =>
          const EncodingDto(encoding: 'GBK', hasBom: false, confidence: 'high'),
    );
    when(
      () => bridge.crateFfiFfiArchiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'GBK',
        toEncoding: 'UTF-8',
      ),
    ).thenAnswer(
      (_) async =>
          const EncodingConversionDto(success: true, outputPath: 'new.txt'),
    );
    when(() => bridge.crateFfiFfiArchiveIsArchive(filePath: 'p'))
        .thenAnswer((_) async => false);
    final detected = await archive.archiveDetectEncoding(filePath: 'p');
    expect(detected.encoding, 'GBK');
    expect(detected.hasBom, isFalse);
    expect(detected.confidence, 'high');
    expect(
      await archive.archiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'GBK',
        toEncoding: 'UTF-8',
      ),
      'new.txt',
    );
    expect(await archive.archiveIsArchive(filePath: 'p'), isFalse);
  });

  test('解包失败、坏列表与转换失败均不当成功', () async {
    when(() => bridge.crateFfiFfiArchiveImportZip(zipPath: 'z', outputDir: 'o'))
        .thenAnswer(
          (_) async => const ArchiveImportDto(
            success: false,
            extractedFiles: [],
            error: '损坏压缩包',
          ),
        );
    when(() => bridge.crateFfiFfiArchiveListZipFiles(zipPath: 'z'))
        .thenAnswer((_) async => throw const FormatException('目录读取失败'));
    when(
      () => bridge.crateFfiFfiArchiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'x',
        toEncoding: 'y',
      ),
    ).thenAnswer(
      (_) async => const EncodingConversionDto(success: false, error: '未知编码'),
    );
    await expectLater(
      archive.archiveImportZip(zipPath: 'z', outputDir: 'o'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      archive.archiveListZipFiles(zipPath: 'z'),
      throwsFormatException,
    );
    await expectLater(
      archive.archiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'x',
        toEncoding: 'y',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('导出选项编码一次，预览章节数直接映射', () async {
    String? options;
    when(
      () => bridge.crateFfiFfiBookExportWithOptions(
        bookUrl: 'b',
        format: 'epub',
        includeToc: true,
        optionsJson: any(named: 'optionsJson'),
      ),
    ).thenAnswer((call) async {
      options = call.namedArguments[#optionsJson] as String;
      return BookExportDto(
        success: true,
        fileName: '书.epub',
        data: Uint8List.fromList([1, 2, 3]),
        mimeType: 'application/epub+zip',
      );
    });
    when(() => bridge.crateFfiFfiBookExportInfo(bookUrl: 'b', format: 'epub'))
        .thenAnswer(
          (_) async => BookExportDto(
            success: true,
            fileName: '书.epub',
            chapterCount: BigInt.from(24),
          ),
        );
    final data = await exporter.bookExportWithOptions(
      bookUrl: 'b',
      format: 'epub',
      includeToc: true,
      options: const BookExportOptions(
        encoding: 'GBK',
        startChapter: 1,
        endChapter: 4,
        fileNameTemplate: '{name}',
      ),
    );
    expect(data.bytes, [1, 2, 3]);
    expect(data.fileName, '书.epub');
    expect(data.mimeType, 'application/epub+zip');
    expect(jsonDecode(options!), {
      'encoding': 'GBK',
      'startChapter': 1,
      'endChapter': 4,
      'fileNameTemplate': '{name}',
    });
    expect(
      (await exporter.bookExportInfo(
        bookUrl: 'b',
        format: 'epub',
      )).chapterCount,
      24,
    );
  });

  test('导出缺失字节和章节数不伪造成功', () async {
    when(
      () => bridge.crateFfiFfiBookExportWithOptions(
        bookUrl: 'b',
        format: 'txt',
        includeToc: false,
        optionsJson: '',
      ),
    ).thenAnswer(
      (_) async => const BookExportDto(
        success: true,
        fileName: '书.txt',
        mimeType: 'text/plain',
      ),
    );
    when(() => bridge.crateFfiFfiBookExportInfo(bookUrl: 'b', format: 'txt'))
        .thenAnswer(
          (_) async => const BookExportDto(success: true, fileName: '书.txt'),
        );
    await expectLater(
      exporter.bookExportWithOptions(
        bookUrl: 'b',
        format: 'txt',
        includeToc: false,
      ),
      throwsFormatException,
    );
    await expectLater(
      exporter.bookExportInfo(bookUrl: 'b', format: 'txt'),
      throwsFormatException,
    );
  });

  test('类型化段评保持上下文、递归回复、计数和分页', () async {
    when(
      () => bridge.crateFfiFfiReviewGetSummary(
        sourceJson: 's',
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) async => const ReviewSummaryDto(counts: {2: 3, 3: 0}, keys: {2: 'k'}),
    );
    when(
      () => bridge.crateFfiFfiReviewGetDetail(
        sourceJson: 's',
        request: any(named: 'request'),
        page: 2,
      ),
    ).thenAnswer(
      (_) async => ReviewPageDto(
        items: [
          _item('正文', [_item('嵌套', [])]),
        ],
        nextPageUrl: 'next2',
        hasReplyUrl: true,
      ),
    );
    when(
      () => bridge.crateFfiFfiReviewGetReplies(
        sourceJson: 's',
        request: any(named: 'request'),
        page: 1,
      ),
    ).thenAnswer(
      (_) async =>
          const ReviewPageDto(items: [], nextPageUrl: null, hasReplyUrl: false),
    );
    final summary = await reviews.reviewGetSummary('s', {'chapterUrl': 'c'});
    expect(summary.counts, {2: 3});
    expect(summary.keys, {2: 'k'});
    final page = await reviews.reviewGetDetail('s', {
      'paraIndex': 2,
      'paraData': '数据😀',
      'detailUrl': 'next',
    }, 2);
    expect(page.items.single.replies.single.content, '嵌套');
    expect(page.hasReplyUrl, true);
    expect(page.nextPageUrl, 'next2');
    final request =
        verify(
              () => bridge.crateFfiFfiReviewGetDetail(
                sourceJson: 's',
                request: captureAny(named: 'request'),
                page: 2,
              ),
            ).captured.single
            as ReviewRequestDto;
    expect(request.paraIndex, '2');
    expect(request.paraData, '数据😀');
    expect(request.detailUrl, 'next');
    expect(
      (await reviews.reviewGetReplies('s', {'reviewId': '1'}, 1)).items,
      isEmpty,
    );
    final failure = StateError('规则失败');
    when(
      () => bridge.crateFfiFfiReviewGetDetail(
        sourceJson: 's',
        request: any(named: 'request'),
        page: 1,
      ),
    ).thenThrow(failure);
    await expectLater(
      reviews.reviewGetDetail('s', {}, 1),
      throwsA(same(failure)),
    );
  });
}

ReviewDetailItemDto _item(String text, List<ReviewDetailItemDto> replies) =>
    ReviewDetailItemDto(
      id: '1',
      avatar: 'avatar',
      name: '名字',
      badges: ['标识'],
      content: text,
      imageUrl: 'image',
      audioUrl: 'audio',
      time: '今天',
      likeCount: 5,
      replyCount: 2,
      replies: replies,
    );
