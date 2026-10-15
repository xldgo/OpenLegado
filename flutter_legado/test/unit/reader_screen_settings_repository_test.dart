import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_screen_settings.dart';
import 'package:flutter_legado/src/domain/models/reader_status_strip_settings.dart';

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

  test('九项默认不读取旧键或写入默认转换标记', () async {
    storage.values.addAll({
      'screenOrientation': 2,
      'hideStatusBar': true,
      'hideNavigationBar': true,
      'readBodyToLh': true,
      'paddingDisplayCutouts': true,
      'reader_adv_show_battery': true,
      'reader_adv_show_time': true,
      'reader_adv_show_progress': true,
      'reader_adv_show_chapter_name': true,
    });
    final settings = await repository.load();
    expect(settings.screen, const ReaderScreenSettings());
    expect(settings.statusStrip, const ReaderStatusStripSettings());
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    await repository.updateScreen();
    await repository.updateStatusStrip();
    expect(storage.writes, isEmpty);
    await repository.load();
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'settingsMigrated_v271',
      ),
      isFalse,
    );
  });

  test('真实Preferences保存九项，新服务恢复且旧值和其他偏好保持', () async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 23.0,
      'hideStatusBar': false,
    });
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.load();
    await actual.updateScreen(
      orientation: 5,
      hideStatusBar: true,
      hideNavigationBar: true,
      extendIntoCutout: true,
      avoidDisplayCutouts: true,
    );
    await actual.updateStatusStrip(
      showBattery: true,
      showTime: true,
      showProgress: true,
      showChapterName: true,
    );
    final freshService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(freshService.dispose);
    final restored = await AppReaderSettingsRepository(freshService).load();
    expect(
      restored.screen,
      const ReaderScreenSettings(
        orientation: 5,
        hideStatusBar: true,
        hideNavigationBar: true,
        extendIntoCutout: true,
        avoidDisplayCutouts: true,
      ),
    );
    expect(
      restored.statusStrip,
      const ReaderStatusStripSettings(
        showBattery: true,
        showTime: true,
        showProgress: true,
        showChapterName: true,
      ),
    );
    expect(restored.fontSize, 23);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(11));
    expect(prefs.getBool('hideStatusBar'), isFalse);
    expect(prefs.getInt('reader_screen_orientation'), 5);
    expect(prefs.getBool('reader_avoid_display_cutouts'), isTrue);
    expect(prefs.getBool('reader_status_show_chapter_name'), isTrue);
  });

  test('逐字段保存保留另一组和显式false，方向范围0至5', () async {
    await repository.load();
    await repository.updateScreen(orientation: 20, hideStatusBar: true);
    await repository.updateStatusStrip(showTime: true);
    await repository.updateStatusStrip(showBattery: true);
    expect(repository.current.screen.orientation, 5);
    expect(repository.current.statusStrip.showTime, isTrue);
    await repository.updateScreen(orientation: -1, hideStatusBar: false);
    expect(repository.current.screen.orientation, 0);
    expect(repository.current.screen.hideStatusBar, isFalse);
    expect(repository.current.statusStrip.showBattery, isTrue);
    expect(storage.values.keys.toSet(), {
      'reader_screen_orientation',
      'reader_hide_status_bar',
      'reader_status_show_time',
      'reader_status_show_battery',
    });
    storage.values['reader_screen_orientation'] = 99;
    await repository.reload();
    expect(repository.current.screen.orientation, 5);
  });

  test('两组保存失败回退并传播，重试发布同源快照', () async {
    await repository.load();
    final observed = <ReaderScreenSettings>[];
    final subscription = repository
        .watch()
        .map((s) => s.screen)
        .listen(observed.add);
    addTearDown(subscription.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.updateScreen(hideStatusBar: true),
      throwsStateError,
    );
    await expectLater(
      repository.updateStatusStrip(showTime: true),
      throwsStateError,
    );
    expect(repository.current.screen, const ReaderScreenSettings());
    expect(repository.current.statusStrip, const ReaderStatusStripSettings());
    storage.writeFailure = false;
    await repository.updateScreen(hideStatusBar: true);
    await repository.updateStatusStrip(showTime: true);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.hideStatusBar, isTrue);
    expect(repository.current.statusStrip.showTime, isTrue);
  });

  test('外部恢复包含九项，读取失败不覆盖当前快照且可重试', () async {
    await repository.load();
    storage.values.addAll({
      'reader_screen_orientation': 2,
      'reader_hide_status_bar': true,
      'reader_hide_navigation_bar': true,
      'reader_extend_into_cutout': true,
      'reader_avoid_display_cutouts': true,
      'reader_status_show_battery': true,
      'reader_status_show_time': true,
      'reader_status_show_progress': true,
      'reader_status_show_chapter_name': true,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.screen, const ReaderScreenSettings());
    expect(repository.current.statusStrip, const ReaderStatusStripSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(
      repository.current.screen,
      const ReaderScreenSettings(
        orientation: 2,
        hideStatusBar: true,
        hideNavigationBar: true,
        extendIntoCutout: true,
        avoidDisplayCutouts: true,
      ),
    );
    expect(
      repository.current.statusStrip,
      const ReaderStatusStripSettings(
        showBattery: true,
        showTime: true,
        showProgress: true,
        showChapterName: true,
      ),
    );
    expect(storage.writes, isEmpty);
  });

  test('修改剩余阅读设置不会覆盖九项或触碰旧键和默认标记', () async {
    await repository.updateScreen(hideStatusBar: true, extendIntoCutout: true);
    await repository.updateStatusStrip(showTime: true);
    await repository.updateScreen(keepScreenOnSeconds: 60);
    expect(repository.current.screen.hideStatusBar, isTrue);
    expect(repository.current.screen.extendIntoCutout, isTrue);
    expect(repository.current.statusStrip.showTime, isTrue);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'screenOrientation',
      'hideStatusBar',
      'hideNavigationBar',
      'readBodyToLh',
      'paddingDisplayCutouts',
      'reader_adv_show_battery',
      'reader_adv_show_time',
      'reader_adv_show_progress',
      'reader_adv_show_chapter_name',
      'settingsMigrated_v271',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(storage.values['reader_keep_screen_on_seconds'], 60);
    expect(prefs.containsKey('keep_light'), isFalse);
  });
}
