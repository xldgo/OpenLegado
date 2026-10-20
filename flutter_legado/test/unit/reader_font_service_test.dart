import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_font_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/reader_font_service.dart';
import 'package:flutter_legado/src/domain/models/reader_font.dart';
import 'package:flutter_legado/src/platform/reader_font_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('相对字体文件按Documents解析，字体页和正文复用注册，内容变化更新修订', () async {
    final directory = Directory.systemTemp.createTempSync('legado-fonts-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final fontDir = Directory('${directory.path}/fonts')..createSync();
    final file = File('${fontDir.path}/test.ttf')..writeAsBytesSync([1, 2, 3]);
    var registrations = 0;
    final registeredBytes = <int>[];
    final files = ReaderFontFiles(
      documents: () async => directory,
      register: (family, bytes) async {
        expect(family, 'Custom_Test');
        registrations++;
        registeredBytes
          ..clear()
          ..addAll(bytes);
      },
    );
    const font = ReaderFont(family: 'Custom_Test', path: 'fonts/test.ttf');
    await files.load(font);
    final before = files.revisionFor({'Custom_Test'});
    await files.load(font);
    expect(registrations, 1);
    expect(registeredBytes, [1, 2, 3]);
    file.writeAsBytesSync([4, 5, 6, 7]);
    await files.load(font);
    expect(registrations, 2);
    expect(files.revisionFor({'Custom_Test'}), isNot(before));
    expect(registeredBytes, [4, 5, 6, 7]);
  });

  test('导入文件和目录后才自动选择，标题与正文选择相互独立', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync('legado-fonts-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final settingsService = createAppSettingsService();
    addTearDown(settingsService.dispose);
    final settings = AppReaderSettingsRepository(settingsService);
    await settings.update(fontFamily: 'SimSun', titleFontFamily: 'KaiTi');
    final catalog = AppReaderFontRepository();
    addTearDown(catalog.dispose);
    var registered = 0;
    final files = ReaderFontFiles(
      documents: () async => directory,
      register: (_, _) async => registered++,
    );
    final service = ReaderFontService(
      repository: catalog,
      settings: settings,
      files: files,
    );
    expect(
      await service.importFont(
        '宋体.otf',
        Uint8List.fromList([1, 2]),
        title: true,
      ),
      '宋体',
    );
    expect(settings.current.fontFamily, 'SimSun');
    expect(settings.current.titleFontFamily, 'Custom_宋体');
    expect(catalog.current.single.path, 'fonts/Custom_宋体.ttf');
    expect(File('${directory.path}/fonts/Custom_宋体.ttf').existsSync(), isTrue);
    await service.loadSelected(settings.current);
    await service.loadAvailable();
    expect(registered, 1);
    final coldFiles = ReaderFontFiles(
      documents: () async => directory,
      register: (_, _) async => registered++,
    );
    await ReaderFontService(
      repository: catalog,
      settings: settings,
      files: coldFiles,
    ).loadSelected(await settings.load());
    expect(registered, 2, reason: '新进程需要重新注册已选择的自定义字体');
    await settings.update(fontFamily: '', titleFontFamily: '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('reader_font_family'), isFalse);
    expect(prefs.getString('reader_title_font_family'), '');
  });

  test('目录写入失败不自动选择，缺失文件不会注册为可用字体', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync('legado-fonts-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final settingsService = createAppSettingsService();
    addTearDown(settingsService.dispose);
    final settings = AppReaderSettingsRepository(settingsService);
    await settings.update(fontFamily: 'SimSun');
    final catalog = AppReaderFontRepository(
      read: () async => ['Custom_Missing|fonts/missing.ttf'],
      write: (_) async => throw StateError('目录保存失败'),
    );
    addTearDown(catalog.dispose);
    final files = ReaderFontFiles(
      documents: () async => directory,
      register: (_, _) async {},
    );
    final service = ReaderFontService(
      repository: catalog,
      settings: settings,
      files: files,
    );
    await expectLater(
      service.importFont('新字体.ttf', Uint8List.fromList([1]), title: false),
      throwsStateError,
    );
    expect(settings.current.fontFamily, 'SimSun');
    final available = await service.loadAvailable();
    expect(available.fonts, isEmpty);
    expect(available.missing, ['Custom_Missing']);
  });
}
