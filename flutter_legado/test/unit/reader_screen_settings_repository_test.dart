import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_screen_settings.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';

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

  test('屏幕默认不补写，空更新不影响页眉页脚', () async {
    final settings = await repository.load();
    expect(settings.screen, const ReaderScreenSettings());
    await repository.updateScreen();
    expect(repository.current.pageLayout, settings.pageLayout);
    expect(storage.writes, isEmpty);
  });

  test('真实Preferences保存系统栏及安全区，新服务恢复', () async {
    SharedPreferences.setMockInitialValues({'reader_font_size': 23.0});
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.updateScreen(
      orientation: 5,
      hideStatusBar: true,
      hideNavigationBar: true,
      extendIntoCutout: true,
      avoidDisplayCutouts: true,
    );
    final fresh = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(fresh.dispose);
    final restored = await AppReaderSettingsRepository(fresh).load();
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
    expect(restored.fontSize, 23);
    expect((await SharedPreferences.getInstance()).getKeys(), hasLength(6));
  });

  test('逐字段保存与方向夹取，系统状态栏不改页面布局', () async {
    final before = (await repository.load()).pageLayout;
    await repository.updateScreen(orientation: 20, hideStatusBar: true);
    expect(repository.current.screen.orientation, 5);
    await repository.updateScreen(orientation: -1, hideStatusBar: false);
    expect(repository.current.screen.orientation, 0);
    expect(repository.current.screen.hideStatusBar, isFalse);
    expect(repository.current.pageLayout, before);
    expect(storage.values.keys.toSet(), {
      'reader_screen_orientation',
      'reader_hide_status_bar',
    });
  });

  test('保存失败回退并传播，重试发布同源快照', () async {
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
    expect(repository.current.screen, const ReaderScreenSettings());
    storage.writeFailure = false;
    await repository.updateScreen(hideStatusBar: true);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.hideStatusBar, isTrue);
  });

  test('外部恢复读取失败保留快照，重试同步系统栏', () async {
    await repository.load();
    storage.values.addAll({
      'reader_screen_orientation': 2,
      'reader_hide_status_bar': true,
      'reader_extend_into_cutout': true,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.screen, const ReaderScreenSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(repository.current.screen.orientation, 2);
    expect(repository.current.screen.hideStatusBar, isTrue);
    expect(repository.current.screen.extendIntoCutout, isTrue);
    expect(storage.writes, isEmpty);
  });

  test('其他设置更新不覆盖系统栏或页眉选择', () async {
    await repository.updateScreen(hideStatusBar: true, extendIntoCutout: true);
    await repository.updatePageEdge(ReaderPageEdge.header, leftTip: 1);
    await repository.updateScreen(keepScreenOnSeconds: 60);
    expect(repository.current.screen.hideStatusBar, isTrue);
    expect(repository.current.screen.extendIntoCutout, isTrue);
    expect(repository.current.pageLayout.header.leftTip, 1);
    expect(storage.values['reader_keep_screen_on_seconds'], 60);
  });
}
