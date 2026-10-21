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

import 'package:flutter_legado/src/widgets/export_dialog.dart';
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
  Future<BookExportInfo> getExportInfo({
    required String bookUrl,
    required String format,
  }) async {
    return const BookExportInfo(fileName: '测试书籍.txt', chapterCount: 100);
  }

  @override
  Future<bool> webdavUpload(
    WebDavConnection connection,
    String path,
    String data,
  ) async {
    webdavCalled = true;
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
  }) {
    // 构造测试用书籍对象
    final testBook =
        book ?? const Book(bookUrl: 'https://example.com/book1', name: '测试书籍');
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Center(
          child: ExportDialog(
            book: testBook,
            exportService: exportService ?? fakeExportService,

            webDavConfig: webDavConfig,
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
      ),
    );
  }

  Future<Directory> selectExportDirectory(WidgetTester tester) async {
    final directory = Directory.systemTemp.createTempSync('legado_export_');
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _DirectoryPicker(directory.path);
    addTearDown(() {
      FilePickerPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });
    final path = find.text('点击选择导出目录');
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
    // 文件写入走真实I/O；按实际文件内容收敛，再推进原有的自动关闭计时。
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
    // 交替处理真实I/O与测试计时器，直到现有的延迟关闭实际完成。
    final dialog = find.byType(ExportDialog);
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

  group('导出对话框 UI 渲染', () {
    testWidgets('显示对话框标题', (tester) async {
      await pumpTestWidget(tester);

      expect(find.text('导出测试书籍'), findsOneWidget);
    });

    testWidgets('显示格式选择器', (tester) async {
      await pumpTestWidget(tester);

      expect(find.text('导出格式'), findsOneWidget);
      expect(find.text('TXT'), findsOneWidget);
      expect(find.text('EPUB'), findsOneWidget);
      expect(find.text('HTML'), findsOneWidget);
    });

    testWidgets('显示字符编码选择器', (tester) async {
      await pumpTestWidget(tester);

      expect(find.text('字符编码'), findsOneWidget);
      // 默认选中 UTF-8
      expect(find.text('UTF-8'), findsWidgets);
    });

    testWidgets('显示 TOC 复选框', (tester) async {
      await pumpTestWidget(tester);
      await tester.ensureVisible(find.text('包含目录'));

      expect(find.text('包含目录'), findsOneWidget);
      expect(find.text('导出时包含书籍的目录结构'), findsOneWidget);
    });

    testWidgets('显示取消和确认按钮', (tester) async {
      await pumpTestWidget(tester);

      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

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

  group('导出对话框交互', () {
    testWidgets('默认选中 EPUB 格式', (tester) async {
      for (final theme in [
        AppTheme.light,
        AppTheme.dark,
        AppTheme.withColorScheme(
          AppTheme.dark,
          ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        ),
      ]) {
        await pumpTestWidget(tester, theme: theme);
        await tester.pumpAndSettle();

        // 默认状态及标签颜色来自实际组件，覆盖应用明暗和局部色板。
        final epubChip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text('EPUB'),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(epubChip.selected, isTrue);
        expect(
          DefaultTextStyle.of(tester.element(find.text('EPUB'))).style.color,
          theme.colorScheme.onSecondaryContainer,
        );
        expect(
          DefaultTextStyle.of(tester.element(find.text('TXT'))).style.color,
          theme.colorScheme.onSurfaceVariant,
        );
      }
    });

    testWidgets('切换格式选择', (tester) async {
      await pumpTestWidget(tester);

      // 点击 TXT 格式
      await tester.tap(find.text('TXT'));
      await tester.pump();

      final txtChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('TXT'), matching: find.byType(ChoiceChip)),
      );
      expect(txtChip.selected, isTrue);
    });

    testWidgets('切换 TOC 复选框', (tester) async {
      await pumpTestWidget(tester);
      await tester.ensureVisible(find.text('包含目录'));

      // 初始状态为选中
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(checkbox.value, isTrue);

      // 点击取消选中
      await tester.tap(find.text('包含目录'));
      await tester.pump();

      final updatedCheckbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(updatedCheckbox.value, isFalse);
    });

    testWidgets('点击取消关闭对话框', (tester) async {
      await pumpTestWidget(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 对话框应该被关闭（Navigator.pop）
      expect(find.text('导出测试书籍'), findsNothing);
    });

    testWidgets('点击确认触发导出', (tester) async {
      await pumpTestWidget(tester);
      final directory = await selectExportDirectory(tester);

      expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pump();

      // 验证导出被调用
      expect(fakeExportService.exportCalled, isTrue);
      await waitForSavedFile(tester, directory);

      await waitForExportClose(tester);
    });

    testWidgets('导出成功后对话框自动关闭', (tester) async {
      await pumpTestWidget(tester);
      final directory = await selectExportDirectory(tester);

      // 确认对话框存在
      expect(find.text('导出测试书籍'), findsOneWidget);

      await tester.tap(find.text('确认'));
      await tester.pump();
      await waitForSavedFile(tester, directory);

      await waitForExportClose(tester);

      // 对话框应已关闭
      expect(find.text('导出测试书籍'), findsNothing);
    });

    testWidgets('未选择导出目录时提示错误且不调用导出', (tester) async {
      await pumpTestWidget(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(find.text('请先选择导出目录'), findsWidgets);
      expect(fakeExportService.exportCalled, isFalse);
      expect(find.text('导出测试书籍'), findsOneWidget);
    });
  });

  group('导出对话框字符集选择', () {
    testWidgets('字符集下拉框包含所有选项', (tester) async {
      await pumpTestWidget(tester);

      // 点击下拉框展开
      await tester.tap(find.text('UTF-8').first);
      await tester.pumpAndSettle();

      // 验证所有字符集选项
      expect(find.text('GBK'), findsWidgets);
      expect(find.text('Big5'), findsWidgets);
    });
  });
}
