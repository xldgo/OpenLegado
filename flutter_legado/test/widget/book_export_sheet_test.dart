import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_legado/src/domain/models/book_content_result.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/services/export_service.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/features/cache/presentation/book_export_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

/// 只替换系统目录选择，不改变导出前置校验和真实文件写入。— Codex + UI
class _DirectoryPicker extends FilePickerPlatform {
  _DirectoryPicker(this.directory);
  final String? directory;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => directory;
}

/// 伪造的导出服务，用于测试
class FakeExportService extends ExportService {
  /// 是否模拟导出失败
  bool shouldFail = false;

  /// 导出是否被调用
  bool exportCalled = false;
  int exportCount = 0;
  Completer<void>? exportGate;
  bool uploadFails = false;
  List<int>? uploadedBytes;
  ({String format, bool includeToc, String? encoding})? request;

  /// WebDAV 上传是否被调用
  bool webdavCalled = false;

  FakeExportService()
    : super(
        exporter: createTestApplication(useMock: true).bookExportService,
        webDav: createTestApplication(useMock: true).webDavService,
      );

  @override
  List<String> get supportedFormats => ['txt', 'epub', 'html'];

  @override
  List<String> get supportedEncodings => ['UTF-8', 'GBK', 'Big5'];

  @override
  Future<BookExportData> export({
    required String bookUrl,
    required String format,
    required bool includeToc,
    String? encoding,
    int? startChapter,
    int? endChapter,
    String? fileNameTemplate,
  }) async {
    exportCalled = true;
    exportCount++;
    await exportGate?.future;
    request = (format: format, includeToc: includeToc, encoding: encoding);
    if (shouldFail) {
      throw const ExportException('模拟导出失败');
    }
    return BookExportData(
      fileName: '测试书籍.txt',
      bytes: Uint8List.fromList([116, 101, 115, 116]),
      mimeType: 'text/plain',
    );
  }

  @override
  Future<bool> webdavUploadFile(
    WebDavConnection connection,
    String remotePath,
    String localPath,
  ) async {
    webdavCalled = true;
    uploadedBytes = await File(localPath).readAsBytes();
    if (uploadFails) throw StateError('上传失败');
    return true;
  }
}

void main() {
  late FakeExportService fakeExportService;

  setUp(() {
    fakeExportService = FakeExportService();
  });

  /// 构建测试用 Widget
  Widget buildTestWidget({
    ThemeData? theme,
    Book? book,
    ExportService? exportService,
    WebDavConnection? webDavConfig,
    ValueChanged<BookExportData?>? onClosed,
  }) {
    // 构造测试用书籍对象
    final testBook =
        book ?? const Book(bookUrl: 'https://example.com/book1', name: '测试书籍');
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await BookExportSheet.show(
                context: context,
                book: testBook,
                exportService: exportService ?? fakeExportService,
                webDavConfig: webDavConfig,
              );
              onClosed?.call(result);
            },
            child: const Text('打开导出'),
          ),
        ),
      ),
    );
  }

  /// 使用手机逻辑尺寸验证长表单滚动与操作按钮。
  Future<void> pumpTestWidget(
    WidgetTester tester, {
    ThemeData? theme,
    Book? book,
    ExportService? exportService,
    WebDavConnection? webDavConfig,
    ValueChanged<BookExportData?>? onClosed,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      buildTestWidget(
        theme: theme,
        book: book,
        exportService: exportService,
        webDavConfig: webDavConfig,
        onClosed: onClosed,
      ),
    );
    await tester.tap(find.text('打开导出'));
    await tester.pumpAndSettle();
  }

  Future<Directory> selectExportDirectory(WidgetTester tester) async {
    final directory = Directory.systemTemp.createTempSync('legado_export_');
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _DirectoryPicker(directory.path);
    addTearDown(() {
      FilePickerPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });
    final path = find.text('导出目录');
    await tester.ensureVisible(path);
    await tester.tap(path);
    await tester.pumpAndSettle();
    expect(find.text(directory.path), findsOneWidget);
    return directory;
  }

  Future<void> waitForSavedFile(
    WidgetTester tester,
    Directory directory,
  ) async {
    // 文件写入走真实I/O；按实际文件内容收敛，再验证Sheet结果返回。
    final file = File('${directory.path}${Platform.pathSeparator}测试书籍.txt');
    List<int>? bytes;
    for (var attempt = 0; attempt < 100; attempt++) {
      bytes = await tester.runAsync<List<int>?>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return await file.exists() ? await file.readAsBytes() : null;
      });
      await tester.pump();
      if (bytes != null && bytes.length == 4) break;
    }
    expect(bytes, [116, 101, 115, 116]);
  }

  Future<void> waitForExportClose(WidgetTester tester) async {
    // 交替处理真实I/O与测试计时器，直到文件写入完成并返回结果。
    final dialog = find.byType(BookExportSheet);
    for (
      var attempt = 0;
      attempt < 100 && dialog.evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(dialog, findsNothing);
  }

  group('导出Sheet UI 渲染', () {
    testWidgets('无 WebDAV 配置时不显示 WebDAV 选项', (tester) async {
      await pumpTestWidget(tester, webDavConfig: null);

      expect(find.text('上传到 WebDAV'), findsNothing);
    });

    testWidgets('有 WebDAV 配置时显示 WebDAV 选项', (tester) async {
      await pumpTestWidget(
        tester,
        webDavConfig: const WebDavConnection(url: 'https://dav.example.com'),
      );
      await tester.ensureVisible(find.text('上传到 WebDAV'));

      expect(find.text('上传到 WebDAV'), findsOneWidget);
      expect(find.text('导出完成后自动上传到远程服务器'), findsOneWidget);
    });
  });

  group('导出Sheet交互', () {
    testWidgets('点击取消关闭Sheet', (tester) async {
      await pumpTestWidget(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Sheet应该被关闭（Navigator.pop）
      expect(find.text('导出测试书籍'), findsNothing);
    });

    testWidgets('所选格式、目录选项和编码传给服务，文件写入后关闭', (tester) async {
      final gate = Completer<void>();
      fakeExportService.exportGate = gate;
      await pumpTestWidget(tester);
      await tester.tap(find.text('TXT'));
      await tester.pump();
      await tester.ensureVisible(find.text('包含目录'));
      await tester.tap(find.text('包含目录'));
      await tester.ensureVisible(find.text('UTF-8').first);
      await tester.tap(find.text('UTF-8').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('GBK').last);
      await tester.pumpAndSettle();
      final directory = await selectExportDirectory(tester);

      expect(find.widgetWithText(FilledButton, '导出'), findsOneWidget);
      await tester.tap(find.text('导出'));
      await tester.pump();

      expect(fakeExportService.exportCalled, isTrue);
      expect(find.text('导出中'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BookExportSheet), findsOneWidget);
      await tester.tap(find.text('导出中'));
      expect(fakeExportService.exportCount, 1);
      gate.complete();
      await tester.pump();
      expect(fakeExportService.request, (
        format: 'txt',
        includeToc: false,
        encoding: 'GBK',
      ));
      await waitForSavedFile(tester, directory);

      await waitForExportClose(tester);
    });

    testWidgets('导出成功后Sheet自动关闭', (tester) async {
      await pumpTestWidget(tester);
      final directory = await selectExportDirectory(tester);

      // 确认Sheet存在
      expect(find.text('导出测试书籍'), findsOneWidget);

      await tester.tap(find.text('导出'));
      await tester.pump();
      expect(fakeExportService.request, (
        format: 'epub',
        includeToc: true,
        encoding: 'UTF-8',
      ));
      await waitForSavedFile(tester, directory);

      await waitForExportClose(tester);

      // Sheet应已关闭
      expect(find.text('导出测试书籍'), findsNothing);
    });

    testWidgets('未选择导出目录时提示错误且不调用导出', (tester) async {
      await pumpTestWidget(tester);
      await tester.tap(find.text('导出'));
      await tester.pumpAndSettle();

      expect(find.text('请先选择导出目录'), findsWidgets);
      expect(fakeExportService.exportCalled, isFalse);
      expect(find.text('导出测试书籍'), findsOneWidget);
    });
    testWidgets('WebDAV失败留在Sheet显示原因，不返回成功；重试后返回结果', (tester) async {
      var closed = false;
      BookExportData? returned;
      fakeExportService.uploadFails = true;
      await pumpTestWidget(
        tester,
        webDavConfig: const WebDavConnection(url: 'https://dav.example.com'),
        onClosed: (result) {
          closed = true;
          returned = result;
        },
      );
      await tester.ensureVisible(find.text('上传到 WebDAV'));
      await tester.tap(find.text('上传到 WebDAV'));
      await tester.pump();
      await tester.tap(find.text('导出'));
      for (
        var i = 0;
        i < 100 && find.textContaining('上传失败').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.textContaining('上传失败'), findsOneWidget);
      expect(fakeExportService.uploadedBytes, [116, 101, 115, 116]);
      expect(closed, isFalse);
      fakeExportService.uploadFails = false;
      await tester.tap(find.text('导出'));
      await waitForExportClose(tester);
      expect(closed, isTrue);
      expect(returned?.fileName, '测试书籍.txt');
    });
  });
}
