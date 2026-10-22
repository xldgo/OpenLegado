import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/bookmark_export_document.dart';
import 'package:flutter_legado/src/platform/files/bookmark_document_saver.dart';

class _DirectoryPicker extends FilePickerPlatform {
  String? directory;
  String? receivedInitialDirectory;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    receivedInitialDirectory = initialDirectory;
    return directory;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform original;
  late _DirectoryPicker picker;
  late Directory temporary;
  const document = BookmarkExportDocument(
    fileName: 'bookmark-demo.md',
    mimeType: 'text/markdown',
    content: '文档内容\n😀',
  );
  const saver = PlatformBookmarkDocumentSaver();
  setUp(() async {
    original = FilePickerPlatform.instance;
    picker = _DirectoryPicker();
    FilePickerPlatform.instance = picker;
    temporary = await Directory.systemTemp.createTemp(
      'legado-bookmark-export-',
    );
  });
  tearDown(() async {
    FilePickerPlatform.instance = original;
    await temporary.delete(recursive: true);
  });
  test('目录选择取消不写文件，选定目录按UTF-8保存原生内容', () async {
    expect(
      await saver.save(document, initialDirectory: temporary.path),
      isNull,
    );
    expect(picker.receivedInitialDirectory, temporary.path);
    expect(await temporary.list().toList(), isEmpty);
    picker.directory = temporary.path;
    final saved = await saver.save(document);
    expect(saved, File.fromUri(temporary.uri.resolve(document.fileName)).path);
    expect(await File(saved!).readAsString(), document.content);
  });
  test('目标同名路径为目录时写入失败，不返回成功路径', () async {
    picker.directory = temporary.path;
    final target = Directory.fromUri(temporary.uri.resolve(document.fileName));
    await target.create();
    await expectLater(
      saver.save(document),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.exists(), isTrue);
  });
}
