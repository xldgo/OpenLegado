import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_menu_theme_settings.dart';
import 'package:flutter_legado/src/domain/models/reader_brightness_control_settings.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppReaderSettingsRepository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    repository = AppReaderSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  test('底栏图标文字默认关闭，真实Preferences保存并在新仓储中恢复', () async {
    AppReaderSettingsRepository create() {
      final actual = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      addTearDown(actual.dispose);
      return AppReaderSettingsRepository(actual);
    }

    final original = create();
    expect((await original.load()).showMenuLabels, isFalse);
    await original.update(showMenuLabels: true);
    expect((await create().load()).showMenuLabels, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reader_menu_show_labels'), isTrue);
    await original.update(showMenuLabels: false);
    expect((await create().load()).showMenuLabels, isFalse);
    expect(prefs.getBool('reader_menu_show_labels'), isFalse);
  });

  test('默认值不读取旧菜单和亮度键，也不转换或补写默认', () async {
    storage.values.addAll({
      'readBarStyleFollowPage': true,
      'readBarStyle': 2,
      'readMenuAccentColor': 0xff123456,
      'readMenuTextColorNight': 0xffabcdef,
      'showBrightnessView': true,
      'brightnessVwPos': '0',
      'readMenuBrightnessVertical': true,
      'readMenuBrightnessVwPos': 'left',
    });
    final settings = await repository.load();
    expect(settings.menuTheme, const ReaderMenuThemeSettings());
    expect(settings.brightnessControl, const ReaderBrightnessControlSettings());
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    await repository.updateMenuTheme();
    await repository.updateBrightnessControl();
    expect(storage.writes, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('readBarStyleFollowPage', true);
    await repository.load();
    expect(prefs.getBool('readBarStyleFollowPage'), isTrue);
    expect(prefs.containsKey('readBarStyle'), isFalse);
  });

  test('真实Preferences保存十三项，新服务完整恢复日夜颜色与亮度位置', () async {
    SharedPreferences.setMockInitialValues({'reader_font_size': 25.0});
    AppReaderSettingsRepository create() {
      final actual = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      addTearDown(actual.dispose);
      return AppReaderSettingsRepository(actual);
    }

    final actual = create();
    await actual.load();
    await actual.updateMenuTheme(
      mode: 2,
      paletteStyle: 'vibrant',
      colorMode: 1,
      accentColor: 0xff123456,
      accentColorNight: 0xffabcdef,
      backgroundColor: 0xfff0e0d0,
      backgroundColorNight: 0xff121212,
      containerColor: 0xffe0d0c0,
      containerColorNight: 0xff242424,
      textColor: 0xff010203,
      textColorNight: 0xfffafbfc,
    );
    await actual.updateBrightnessControl(mode: 2, onLeft: true);
    final restored = await create().load();
    expect(
      restored.menuTheme,
      const ReaderMenuThemeSettings(
        mode: 2,
        paletteStyle: 'vibrant',
        colorMode: 1,
        accentColor: 0xff123456,
        accentColorNight: 0xffabcdef,
        backgroundColor: 0xfff0e0d0,
        backgroundColorNight: 0xff121212,
        containerColor: 0xffe0d0c0,
        containerColorNight: 0xff242424,
        textColor: 0xff010203,
        textColorNight: 0xfffafbfc,
      ),
    );
    expect(
      restored.brightnessControl,
      const ReaderBrightnessControlSettings(mode: 2, onLeft: true),
    );
    expect(restored.fontSize, 25);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(14));
    expect(prefs.getInt('reader_menu_theme_mode'), 2);
    expect(prefs.getString('reader_menu_palette_style'), 'vibrant');
    expect(prefs.getInt('reader_menu_text_color_night'), 0xfffafbfc);
    expect(prefs.getBool('reader_brightness_control_on_left'), isTrue);
    expect(restored.menuTheme.hashCode, actual.current.menuTheme.hashCode);
    expect(
      restored.brightnessControl.hashCode,
      actual.current.brightnessControl.hashCode,
    );
  });

  test('逐字段更新不覆盖另一日夜值、亮度、其他设置或其他阅读设置', () async {
    await repository.load();
    final before = repository.current;
    await repository.updateMenuTheme(mode: 2, accentColor: 0xff123456);
    await repository.updateBrightnessControl(mode: 2, onLeft: true);
    await repository.updateMenuTheme(accentColorNight: 0xffabcdef);
    await repository.updateInteraction(selectText: false);
    await repository.updateBrightnessControl(mode: 0);
    await repository.update(autoChangeSource: false);
    expect(repository.current.menuTheme.accentColor, 0xff123456);
    expect(repository.current.menuTheme.accentColorNight, 0xffabcdef);
    expect(repository.current.menuTheme.mode, 2);
    expect(repository.current.brightnessControl.mode, 0);
    expect(repository.current.brightnessControl.onLeft, isTrue);
    expect(repository.current.interaction.selectText, isFalse);
    expect(before.menuTheme, const ReaderMenuThemeSettings());
    expect(before.brightnessControl, const ReaderBrightnessControlSettings());
    expect(
      storage.writes.where((w) => w.$1 == 'reader_menu_theme_mode'),
      hasLength(1),
    );
  });

  test('零值、空字符串和false可以保存，读写范围一致', () async {
    await repository.load();
    await repository.updateMenuTheme(
      mode: 9,
      paletteStyle: 'neutral',
      colorMode: 9,
      accentColor: -1,
    );
    await repository.updateBrightnessControl(mode: 9, onLeft: true);
    expect(repository.current.menuTheme.mode, 2);
    expect(repository.current.menuTheme.colorMode, 1);
    expect(repository.current.menuTheme.accentColor, 0);
    expect(repository.current.brightnessControl.mode, 2);
    await repository.updateMenuTheme(
      mode: 0,
      paletteStyle: '',
      colorMode: 0,
      textColorNight: 0,
    );
    await repository.updateBrightnessControl(mode: 0, onLeft: false);
    expect(repository.current.menuTheme, const ReaderMenuThemeSettings());
    expect(
      repository.current.brightnessControl,
      const ReaderBrightnessControlSettings(),
    );
    storage.values.addAll({
      'reader_menu_theme_mode': -1,
      'reader_menu_color_mode': 8,
      'reader_brightness_control_mode': 6,
    });
    await repository.reload();
    expect(repository.current.menuTheme.mode, 0);
    expect(repository.current.menuTheme.colorMode, 1);
    expect(repository.current.brightnessControl.mode, 2);
  });

  test('保存失败只回退失败字段，订阅可见新值与回退并能重试', () async {
    await repository.load();
    await repository.updateMenuTheme(mode: 2, textColorNight: 0xffabcdef);
    final events = <int>[];
    final subscription = repository.watch().listen(
      (s) => events.add(s.menuTheme.textColor),
    );
    addTearDown(subscription.cancel);
    final entered = Completer<void>();
    final gate = Completer<void>();
    storage.beforeWrite = (key, _) async {
      if (key == 'reader_menu_text_color') {
        entered.complete();
        await gate.future;
        throw StateError('模拟保存失败');
      }
    };
    final saving = repository.updateMenuTheme(textColor: 0xff123456);
    final failed = expectLater(saving, throwsStateError);
    await entered.future;
    expect(repository.current.menuTheme.textColor, 0xff123456);
    final later = repository.updateBrightnessControl(mode: 2, onLeft: true);
    gate.complete();
    await failed;
    await later;
    expect(repository.current.menuTheme.textColor, 0);
    expect(repository.current.menuTheme.textColorNight, 0xffabcdef);
    expect(repository.current.brightnessControl.onLeft, isTrue);
    expect(events, containsAllInOrder([0xff123456, 0]));
    storage.beforeWrite = null;
    await repository.updateMenuTheme(textColor: 0xff654321);
    expect(storage.values['reader_menu_text_color'], 0xff654321);
  });

  test('外部恢复后重读两组，读取失败保留当前快照且可重试', () async {
    await repository.load();
    final next = repository.watch().firstWhere(
      (s) => s.menuTheme.backgroundColorNight == 0xff202020,
    );
    storage.values.addAll({
      'reader_menu_background_color_night': 0xff202020,
      'reader_brightness_control_mode': 2,
      'reader_brightness_control_on_left': true,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.menuTheme.backgroundColorNight, 0);
    storage.readFailure = false;
    await repository.reload();
    expect(
      (await next).brightnessControl,
      const ReaderBrightnessControlSettings(mode: 2, onLeft: true),
    );
    expect(storage.writes, isEmpty);
  });
}
