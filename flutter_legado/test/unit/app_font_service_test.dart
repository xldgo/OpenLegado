import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_appearance_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_font_repository.dart';
import 'package:flutter_legado/src/data/services/app_font_service.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/services/font_catalog_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/platform/app_font_picker.dart';
import 'package:flutter_legado/src/platform/reader_font_files.dart';

import '../fixtures/theme_settings_storage.dart';

class _Picker extends AppFontPicker {
  bool cancelled = false;
  @override
  Future<({String name, Uint8List bytes})?> pick() async => cancelled
      ? null
      : (name: '界面字体.otf', bytes: Uint8List.fromList([1, 2, 3]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ThemeSettingsStorage storage;
  late AppSettingsService settings;
  late AppAppearanceSettingsRepository appearance;
  late AppReaderFontRepository repository;
  late FontCatalogService catalog;
  late AppFontService service;
  late _Picker picker;
  var failCatalog = false;
  var failRegister = false;
  var registrations = 0;
  var entries = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('legado-app-font-');
    storage = ThemeSettingsStorage({
      'reader_font_family': 'SimSun',
      'reader_title_font_family': 'KaiTi',
    });
    settings = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    appearance = AppAppearanceSettingsRepository(settings);
    failCatalog = false;
    failRegister = false;
    registrations = 0;
    entries = [];
    repository = AppReaderFontRepository(
      read: () async => entries,
      write: (value) async {
        if (failCatalog) throw StateError('目录保存失败');
        entries = value;
      },
    );
    catalog = FontCatalogService(
      repository: repository,
      files: ReaderFontFiles(
        documents: () async => directory,
        register: (_, _) async {
          if (failRegister) throw StateError('字体加载失败');
          registrations++;
        },
      ),
    );
    picker = _Picker();
    service = AppFontService(
      settings: appearance,
      catalog: catalog,
      picker: picker,
    );
  });
  tearDown(() async {
    await settings.dispose();
    await repository.dispose();
    directory.deleteSync(recursive: true);
  });

  test('导入先加载再保存界面选择，重启重新注册且不改阅读字体', () async {
    expect(await service.importFont(), '界面字体');
    expect(appearance.current.fontFamily, 'Custom_界面字体');
    expect(storage.values['app_font_family'], 'Custom_界面字体');
    expect(storage.values['reader_font_family'], 'SimSun');
    expect(storage.values['reader_title_font_family'], 'KaiTi');
    expect(registrations, 1);
    final cold = FontCatalogService(
      repository: repository,
      files: ReaderFontFiles(
        documents: () async => directory,
        register: (_, _) async => registrations++,
      ),
    );
    await appearance.reload();
    expect(await cold.loadFamily(appearance.current.fontFamily), 'Custom_界面字体');
    expect(registrations, 2);
    await service.select('');
    expect(appearance.current.fontFamily, '');
    expect(storage.values['reader_font_family'], 'SimSun');
  });

  test('取消文件选择不安装字体也不修改偏好', () async {
    picker.cancelled = true;
    expect(await service.importFont(), isNull);
    expect(entries, isEmpty);
    expect(storage.writes, isEmpty);
    expect(registrations, 0);
  });

  test('注册失败或目录保存失败均不写入界面选择', () async {
    failRegister = true;
    await expectLater(service.importFont(), throwsStateError);
    expect(entries, isEmpty);
    expect(storage.writes, isEmpty);
    failRegister = false;
    failCatalog = true;
    await expectLater(service.importFont(), throwsStateError);
    expect(appearance.current.fontFamily, '');
    expect(storage.writes, isEmpty);
  });

  test('偏好保存失败保留旧选择，缺失字体不伪装成加载成功', () async {
    await appearance.load();
    storage.failNext = true;
    await expectLater(service.importFont(), throwsStateError);
    expect(appearance.current.fontFamily, '');
    expect(storage.values.containsKey('app_font_family'), isFalse);
    await expectLater(service.select('Custom_Missing'), throwsStateError);
    expect(appearance.current.fontFamily, '');
    await service.select('Custom_界面字体');
    expect(appearance.current.fontFamily, 'Custom_界面字体');
  });
}
