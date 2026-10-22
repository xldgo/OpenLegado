import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/bookmarks/bookmark_export.dart';
import 'package:flutter_legado/src/domain/models/bookmark_export_document.dart';
import 'package:flutter_legado/src/data/services/mock_bookmark_export_service.dart';
import 'package:flutter_legado/src/models/misc.dart';

import '../../fixtures/bookmark_export_fixture.dart';

void main() {
  const bookmarks = [
    Bookmark(id: 42, bookName: '书名', bookAuthor: '作者', content: '备注'),
  ];
  test('两种格式均把查询快照交给格式服务，原样保存返回文档', () async {
    final exporter = RecordingBookmarkExporter();
    final saver = RecordingBookmarkSaver()..result = '/saved/bookmark.md';
    final controller = BookmarkExport(exporter: exporter, saver: saver);
    for (final format in BookmarkExportFormat.values) {
      final path = await controller.export(
        bookName: '书名',
        bookAuthor: '作者',
        bookmarks: bookmarks,
        format: format,
        initialDirectory: '/initial',
      );
      expect(path, '/saved/bookmark.md');
      expect(exporter.requests.last, (
        name: '书名',
        author: '作者',
        bookmarks: bookmarks,
        format: format,
      ));
      expect(saver.document, same(RecordingBookmarkExporter.document));
      expect(saver.initialDirectory, '/initial');
    }
  });

  test('取消返回null，保存或生成失败均传播且生成失败不打开选择器', () async {
    final exporter = RecordingBookmarkExporter();
    final saver = RecordingBookmarkSaver();
    final controller = BookmarkExport(exporter: exporter, saver: saver);
    Future<String?> export() => controller.export(
      bookName: '书名',
      bookAuthor: '作者',
      bookmarks: bookmarks,
      format: BookmarkExportFormat.json,
    );
    expect(await export(), isNull);
    final saveError = StateError('磁盘写入失败');
    saver.error = saveError;
    await expectLater(export(), throwsA(same(saveError)));
    final previousCalls = saver.calls;
    final buildError = StateError('生成失败');
    exporter.error = buildError;
    await expectLater(export(), throwsA(same(buildError)));
    expect(saver.calls, previousCalls);
  });

  test('Mock明确报不支持，不初始化原生或输出空文件', () async {
    await expectLater(
      const MockBookmarkExportService().buildDocument(
        bookName: '书名',
        bookAuthor: '作者',
        bookmarks: bookmarks,
        format: BookmarkExportFormat.json,
      ),
      throwsUnsupportedError,
    );
  });
}
