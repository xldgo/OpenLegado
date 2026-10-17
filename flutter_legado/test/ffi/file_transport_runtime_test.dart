library;

@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/file_dto.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/services/rust_book_archive_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_export_service.dart';
import 'package:flutter_legado/src/data/services/rust_local_book_service.dart';
import 'package:flutter_legado/src/data/services/rust_local_server_service.dart';
import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';
import 'package:flutter_legado/src/domain/models/book_content_result.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';

void main() {
  if (!Platform.isWindows) {
    test('需要Windows DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File text;
  const archiveService = RustBookArchiveService();
  const local = RustLocalBookService();
  const exporter = RustBookExportService();
  setUpAll(() async {
    root = Directory(
      '.dart_tool/file-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    text = File('${root.absolute.path}/小说😀.txt')
      ..writeAsStringSync('第一章 初见\n正文甲😀\n第二章 再见\n正文乙\n');
    await const NativeRustRuntime().initialize();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  test('本地元数据、导入、原始字节导出和预览章节数真实贯通', () async {
    final detected = await bridge.importDetectFormat(filePath: text.path);
    expect(detected.format, 'txt');
    expect(detected.path, text.path);
    final metadata = await bridge.importParseMetadata(filePath: text.path);
    expect(metadata.format, BookFormatDto.txt);
    expect(metadata.title, isNotEmpty);
    final book = await local.importLocalBook(text.path);
    final chapters = (await bridge.readerGetChapters(bookUrl: book.bookUrl))
        .chapters;
    expect(chapters, hasLength(2));
    final info = await exporter.bookExportInfo(
      bookUrl: book.bookUrl,
      format: 'txt',
    );
    expect(info.chapterCount, chapters.length);
    final exported = await exporter.bookExportWithOptions(
      bookUrl: book.bookUrl,
      format: 'txt',
      includeToc: false,
      options: const BookExportOptions(fileNameTemplate: '{name}-导出'),
    );
    expect(exported.fileName, endsWith('-导出.txt'));
    final content = utf8.decode(exported.bytes);
    expect(content, contains('正文甲😀'));
    expect(content, contains('正文乙'));
    final failed = await bridge.bookExport(
      bookUrl: book.bookUrl,
      format: 'unknown',
      includeToc: false,
    );
    expect(failed.success, isFalse);
    expect(failed.data, isNull);
    expect(failed.error, isNotEmpty);
  });
  test('真实ZIP条目、解包路径和编码转换不经JSON', () async {
    final zip = Archive()..addFile(ArchiveFile('目录/书.txt', 3, [65, 66, 67]));
    final file = File('${root.absolute.path}/书包.zip')
      ..writeAsBytesSync(ZipEncoder().encode(zip));
    expect(await archiveService.archiveListZipFiles(zipPath: file.path), [
      '书.txt',
    ]);
    final paths = await archiveService.archiveImportZip(
      zipPath: file.path,
      outputDir: '${root.absolute.path}/out',
    );
    expect(await File(paths.single).readAsBytes(), [65, 66, 67]);
    final detection = await archiveService.archiveDetectEncoding(
      filePath: text.path,
    );
    expect(detection.encoding.toLowerCase(), 'utf-8');
    final converted = await archiveService.archiveConvertEncoding(
      filePath: text.path,
      fromEncoding: 'UTF-8',
      toEncoding: 'UTF-16LE',
    );
    expect(await File(converted).length(), greaterThan(0));
    await expectLater(
      archiveService.archiveImportZip(
        zipPath: '${root.absolute.path}/missing.zip',
        outputDir: '${root.absolute.path}/fail',
      ),
      throwsA(anything),
    );
  });
  test('WebDAV真实PROPFIND返回完整目录元数据及精确u64', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final methods = <String>[];
    server.listen((request) async {
      methods.add(request.method);
      request.response.statusCode = 207;
      request.response.headers.contentType = ContentType('application', 'xml');
      request.response.write(
        '''<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:response><d:href>/book.txt</d:href><d:propstat><d:prop><d:displayname>book.txt</d:displayname><d:getcontentlength>9007199254740993</d:getcontentlength><d:getlastmodified>Mon, 01 Jan 2024 00:00:00 GMT</d:getlastmodified><d:getetag>etag</d:getetag><d:resourcetype/></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''',
      );
      await request.response.close();
    });
    final result = await const RustWebDavService()
        .webdavListDir(
          WebDavConnection(
            url: 'http://127.0.0.1:${server.port}',
            remoteDir: '',
          ),
          '',
        )
        .timeout(const Duration(seconds: 15))
        .catchError((Object error) {
          if (error is BridgeError) fail('WebDAV请求失败：${error.message}');
          throw error;
        });
    expect(methods, ['PROPFIND']);
    expect(result.single['name'], 'book.txt');
    expect(result.single['path'], '/book.txt');
    expect(result.single['size'], 9007199254740993);
    expect(result.single['is_dir'], false);
    expect(result.single['etag'], 'etag');
    expect(result.single['last_modified'], 'Mon, 01 Jan 2024 00:00:00 GMT');
  });
  test('服务停止状态直接读取，不启动监听器', () async {
    final state = await const RustLocalServerService().getServerStatus();
    expect(state.running, isFalse);
    expect(state.port, inInclusiveRange(0, 65535));
  });
}
