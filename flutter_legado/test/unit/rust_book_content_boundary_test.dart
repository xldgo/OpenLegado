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
        requestJson: '{}',
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
          (_) async => jsonEncode({
            'success': true,
            'book': {'bookUrl': 'file://书.cbz', 'name': '漫画', 'type': 4160},
          }),
        );
    when(
      () => bridge.crateFfiFfiCbzReadPage(
        path: '目录/书.cbz',
        entry: 'cbz://封面.png',
      ),
    ).thenAnswer((_) async => ' {"base64":"AQID","len":3}');
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
    '{}',
    '{"success":true}',
    '{"success":false,"error":"文件不存在"}',
  ]) {
    test('坏导入结果不能伪造书籍：$payload', () async {
      when(() => bridge.crateFfiFfiImportLocalBook(filePath: 'p'))
          .thenAnswer((_) async => payload);
      await expectLater(local.importLocalBook('p'), throwsA(isA<Exception>()));
    });
  }
  for (final payload in [
    '{}',
    '{"base64":"AQID","len":2}',
    '{"base64":"***","len":3}',
  ]) {
    test('CBZ损坏载荷拒绝：$payload', () async {
      when(() => bridge.crateFfiFfiCbzReadPage(path: 'p', entry: 'e'))
          .thenAnswer((_) async => payload);
      await expectLater(
        local.cbzReadPage(path: 'p', entry: 'e'),
        throwsFormatException,
      );
    });
  }

  test('ZIP/RAR列表、密码和解包参数一致，返回文件路径', () async {
    when(() => bridge.crateFfiFfiArchiveListZipFiles(zipPath: 'z'))
        .thenAnswer((_) async => '["目录/书.txt"]');
    when(
      () => bridge.crateFfiFfiArchiveListRarFiles(rarPath: 'r', password: '密码'),
    ).thenAnswer((_) async => '[]');
    when(
      () => bridge.crateFfiFfiArchiveImportZip(zipPath: 'z', outputDir: 'out'),
    ).thenAnswer(
      (_) async => ' {"success":true,"extracted_files":["out/书.txt"]}',
    );
    when(
      () => bridge.crateFfiFfiArchiveImportRar(
        rarPath: 'r',
        outputDir: 'out',
        password: '密码',
      ),
    ).thenAnswer((_) async => ' {"success":true,"extracted_files":[]}');
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
    when(() => bridge.crateFfiFfiArchiveDetectEncoding(filePath: 'p'))
        .thenAnswer(
          (_) async =>
              ' {"encoding":"GBK","has_bom":false,"confidence":"high"}',
        );
    when(
      () => bridge.crateFfiFfiArchiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'GBK',
        toEncoding: 'UTF-8',
      ),
    ).thenAnswer((_) async => ' {"success":true,"output_path":"new.txt"}');
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
        .thenAnswer((_) async => ' {"success":false,"error":"损坏压缩包"}');
    when(() => bridge.crateFfiFfiArchiveListZipFiles(zipPath: 'z'))
        .thenAnswer((_) async => '[null]');
    when(
      () => bridge.crateFfiFfiArchiveConvertEncoding(
        filePath: 'p',
        fromEncoding: 'x',
        toEncoding: 'y',
      ),
    ).thenAnswer((_) async => ' {"success":false,"error":"未知编码"}');
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

  test('导出选项编码一次，预览章节数适配当前Rust协议', () async {
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
      return '{"success":true,"file_name":"书.epub","data_base64":"AQID","mime_type":"application/epub+zip"}';
    });
    when(() => bridge.crateFfiFfiBookExportInfo(bookUrl: 'b', format: 'epub'))
        .thenAnswer(
          (_) async =>
              ' {"success":true,"file_name":"书.epub","error":"章节数: 24"}',
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

  test('导出坏base64和缺失章节数不伪造成功', () async {
    when(
      () => bridge.crateFfiFfiBookExportWithOptions(
        bookUrl: 'b',
        format: 'txt',
        includeToc: false,
        optionsJson: '',
      ),
    ).thenAnswer(
      (_) async => ' {"success":true,"file_name":"书.txt","data_base64":"***","mime_type":"text/plain"}',
    );
    when(() => bridge.crateFfiFfiBookExportInfo(bookUrl: 'b', format: 'txt'))
        .thenAnswer((_) async => ' {"success":true,"file_name":"书.txt"}');
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

  test('段评摘要、详情、回复请求上下文和页码透传', () async {
    when(
      () => bridge.crateFfiFfiReviewGetSummary(
        sourceJson: 's',
        requestJson: '{"chapterUrl":"c"}',
      ),
    ).thenAnswer((_) async => ' {"counts":{"2":3,"3":0},"keys":{"2":"k"}}');
    when(
      () => bridge.crateFfiFfiReviewGetDetail(
        sourceJson: 's',
        requestJson: '{"paraIndex":2,"detailUrl":"next"}',
        page: 2,
      ),
    ).thenAnswer(
      (_) async => ' {"items":[{"id":"1","content":"正文段评","replies":[{"content":"嵌套回复"}]}],"nextPageUrl":"next2","hasReplyUrl":true}',
    );
    when(
      () => bridge.crateFfiFfiReviewGetReplies(
        sourceJson: 's',
        requestJson: '{"reviewId":"1"}',
        page: 1,
      ),
    ).thenAnswer((_) async => ' {"items":[],"nextPageUrl":null}');
    final summary = await reviews.reviewGetSummary('s', {'chapterUrl': 'c'});
    expect(summary.counts, {2: 3});
    expect(summary.keys, {2: 'k'});
    final page = await reviews.reviewGetDetail('s', {
      'paraIndex': 2,
      'detailUrl': 'next',
    }, 2);
    expect(page.items.single.replies.single.content, '嵌套回复');
    expect(page.hasReplyUrl, isTrue);
    expect(page.nextPageUrl, 'next2');
    expect(
      (await reviews.reviewGetReplies('s', {'reviewId': '1'}, 1)).items,
      isEmpty,
    );
  });

  for (final payload in [
    '{}',
    '{"items":[null]}',
    '{"items":[],"nextPageUrl":2}',
  ]) {
    test('段评坏响应不当空列表：$payload', () async {
      when(
        () => bridge.crateFfiFfiReviewGetDetail(
          sourceJson: 's',
          requestJson: '{}',
          page: 1,
        ),
      ).thenAnswer((_) async => payload);
      await expectLater(
        reviews.reviewGetDetail('s', {}, 1),
        throwsFormatException,
      );
    });
  }
}
