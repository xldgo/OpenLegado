library;

import '../fixtures/app_test_api.dart';

/// [cbz P1-1 回归 | 2026-10-03] 书架「添加本地」入口白名单测试
///
/// 背景（QA 真机证据 .tmp/cbz_qa/step10_picker_control.xml）：
/// 书架溢出菜单「添加本地」→ file_picker（FileType.custom）白名单缺 cbz，
/// Android 侧经 MimeTypeMap 过滤后 DocumentsUI 将 .cbz 置灰
/// （enabled="false"），UI 无法导入 cbz；而 import_screen.dart 的
/// _supportedFormats 已含 cbz（批 C）——两处白名单漂移导致回归。
///
/// 本用例直接走真实书架入口：
/// 更多菜单 → 添加本地 → 捕获 FilePicker.pickFiles 实参，
/// 断言 allowedExtensions 与 import_screen._supportedFormats 同序同集合
/// （含 cbz；且不含走压缩包解压链路的 zip/rar/7z）。
/// 修复前（['epub','txt','mobi','pdf','umd']）本用例必红。

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import 'package:flutter_legado/src/l10n/app_strings.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';

import '../mocks/mocks.dart';

/// 记录 pickFiles 实参的平台桩；返回空列表 = 用户取消，
/// 不进入 importLocalBook/FFI 链路（本用例只钉白名单，不测导入）。
class _RecordingFilePicker extends FilePickerPlatform {
  _RecordingFilePicker({this.files = const []});
  final List<PlatformFile> files;
  int pickCalls = 0;
  FileType? capturedType;
  List<String>? capturedAllowedExtensions;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickCalls++;
    capturedType = type;
    capturedAllowedExtensions = allowedExtensions;
    return files;
  }
}

/// 本地选择结果桩，路径与数据读取委托 XFile。
final class _PickedFile extends PlatformFile {
  _PickedFile(String path) : xFile = XFile(path);
  @override
  final XFile xFile;
  @override
  String get name => xFile.name;
  @override
  Uri get uri => Uri.file(xFile.path);
  @override
  int? lengthSync() => null;
  @override
  Future<int?> length() => xFile.length();
  @override
  Future<Uint8List> readAsBytes() => xFile.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      xFile.openRead().map(Uint8List.fromList);
}

/// 注入新版 FilePicker 平台桩并登记恢复。
void _useFakeFilePicker(FilePickerPlatform fake) {
  final original = FilePickerPlatform.instance;
  FilePickerPlatform.instance = fake;
  addTearDown(() => FilePickerPlatform.instance = original);
}

void main() {
  late MockRustApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    when(() => api.bookshelfRepository.getBooks())
        .thenAnswer((_) async => <Book>[]);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => <BookGroup>[]);
  });

  /// pump 真实书架页并等待 Notifier 初始加载落定
  Future<void> pumpShelf(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: const MaterialApp(home: BookshelfScreen()),
      ),
    );
    // _loadSettings/_loadBooks/_loadGroups 微任务落定
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('多选列表中的每本本地书都进入原有导入链路', (tester) async {
    final files = [
      _PickedFile('/books/first.txt'),
      _PickedFile('/books/second.cbz'),
    ];
    final fake = _RecordingFilePicker(files: files);
    _useFakeFilePicker(fake);
    when(() => api.localBookService.importLocalBook(any())).thenAnswer(
      (call) async =>
          Book(bookUrl: call.positionalArguments.single as String, name: '本地书'),
    );
    await pumpShelf(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.addLocalBook));
    await tester.pumpAndSettle();

    expect(fake.pickCalls, 1);
    for (final file in files) {
      verify(() => api.localBookService.importLocalBook(file.path!)).called(1);
    }
    expect(find.textContaining('已导入 2 本书籍'), findsOneWidget);
  });

  testWidgets('书架「更多 → 添加本地」白名单与导入页一致且含 cbz', (tester) async {
    final fake = _RecordingFilePicker();
    _useFakeFilePicker(fake);
    await pumpShelf(tester);

    // 打开顶栏「⋮ 更多」自绘菜单
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    // 点击「添加本地」→ _addLocalBook → FilePicker.pickFiles
    expect(
      find.text(AppStrings.addLocalBook),
      findsOneWidget,
      reason: '溢出菜单应含「添加本地」入口',
    );
    await tester.tap(find.text(AppStrings.addLocalBook));
    await tester.pumpAndSettle();

    expect(fake.pickCalls, 1, reason: '「添加本地」应触发一次文件选择');
    // Windows 测试宿主 Platform.isIOS=false → 走 Android custom 白名单分支
    expect(fake.capturedType, FileType.custom);

    final exts = fake.capturedAllowedExtensions;
    expect(exts, isNotNull, reason: 'custom 分支必须携带 allowedExtensions');
    expect(
      exts,
      contains('cbz'),
      reason: '[P1-1] 白名单缺 cbz → DocumentsUI 将 .cbz 置灰，UI 无法导入',
    );
    expect(
      exts,
      equals(const ['epub', 'txt', 'mobi', 'azw3', 'azw', 'pdf', 'umd', 'cbz']),
      reason: '须与 import_screen.dart::_supportedFormats 同序同集合（互指注释）',
    );
    // 压缩包格式走 ImportScreen 解压导入链路，不属于整本导入白名单
    for (final archive in const ['zip', 'rar', '7z']) {
      expect(exts, isNot(contains(archive)));
    }
  });
}
