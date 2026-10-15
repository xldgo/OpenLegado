import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_auto_page_turn_settings.dart';
import 'package:flutter_legado/src/domain/models/reader_interaction_settings.dart';

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

  test('默认值同源，不读旧九宫格、三列或操作偏好，也不补写默认', () async {
    storage.values.addAll({
      'reader_adv_auto_page_turn': true,
      'reader_adv_auto_interval': 3.0,
      'reader_adv_auto_forward': false,
      'reader_adv_tap_actions_v1': List.filled(9, '0'),
      'reader_adv_left_action': 4,
      'volumeKeyPage': false,
      'selectText': false,
      'pageTouchSlop': 100,
      'progressBarBehavior': 'chapter',
    });
    final loaded = await repository.load();
    expect(loaded.autoPageTurn, const ReaderAutoPageTurnSettings());
    expect(loaded.interaction, const ReaderInteractionSettings.defaults());
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    await repository.updateAutoPageTurn();
    await repository.updateInteraction();
    expect(storage.writes, isEmpty);
  });

  test('真实Preferences保存十二项，StringList名称和原字段类型可恢复', () async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 23.0,
      'volumeKeyPage': true,
    });
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    final actions = List<TapAction>.of(
      ReaderInteractionSettings.defaultTapActions,
    )..[0] = TapAction.openCatalog;
    await actual.load();
    await actual.updateAutoPageTurn(
      enabled: true,
      intervalSeconds: 85.0,
      forward: false,
    );
    await actual.updateInteraction(
      tapActions: actions,
      selectText: false,
      noAnimScrollPage: true,
      volumeKeyPage: false,
      volumeKeyPageOnPlay: true,
      mouseWheelPage: false,
      pageTouchSlop: 35,
      pageTouchClick: 12,
      progressBarBehavior: 'chapter',
    );
    final freshService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(freshService.dispose);
    final restored = await AppReaderSettingsRepository(freshService).load();
    expect(
      restored.autoPageTurn,
      const ReaderAutoPageTurnSettings(
        enabled: true,
        intervalSeconds: 85,
        forward: false,
      ),
    );
    expect(
      restored.interaction,
      ReaderInteractionSettings(
        tapActions: actions,
        selectText: false,
        noAnimScrollPage: true,
        volumeKeyPage: false,
        volumeKeyPageOnPlay: true,
        mouseWheelPage: false,
        pageTouchSlop: 35,
        pageTouchClick: 12,
        progressBarBehavior: 'chapter',
      ),
    );
    expect(restored.fontSize, 23);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(14));
    expect(
      prefs.getStringList('reader_tap_actions'),
      actions.map((a) => a.name),
    );
    expect(prefs.getDouble('reader_auto_page_turn_interval_seconds'), 85);
    expect(prefs.getBool('volumeKeyPage'), isTrue);
  });

  test('九宫格输入与输出不可共享修改，值相等且哈希一致', () async {
    final input = List<TapAction>.of(
      ReaderInteractionSettings.defaultTapActions,
    );
    final model = ReaderInteractionSettings(tapActions: input);
    input[0] = TapAction.none;
    expect(model.tapActions[0], TapAction.prevPage);
    expect(() => model.tapActions[0] = TapAction.none, throwsUnsupportedError);
    expect(model, const ReaderInteractionSettings.defaults());
    expect(model.hashCode, const ReaderInteractionSettings.defaults().hashCode);
    await repository.load();
    final saving = repository.updateInteraction(tapActions: input);
    input[0] = TapAction.openCatalog;
    await saving;
    expect(repository.current.interaction.tapActions[0], TapAction.none);
    expect(
      (storage.values['reader_tap_actions'] as SettingsStringList).values.first,
      'none',
    );
    expect(
      () => repository.updateInteraction(tapActions: []),
      throwsArgumentError,
    );
  });

  test('逐字段保存互不覆盖，false与零有效，范围和进度条行为统一', () async {
    await repository.load();
    await repository.updateAutoPageTurn(enabled: true, intervalSeconds: 200);
    await repository.updateInteraction(
      pageTouchSlop: 20000,
      pageTouchClick: -1,
    );
    await repository.updateInteraction(
      selectText: false,
      progressBarBehavior: 'chapter',
    );
    await repository.updateAutoPageTurn(intervalSeconds: 0, forward: false);
    expect(
      repository.current.autoPageTurn,
      const ReaderAutoPageTurnSettings(
        enabled: true,
        intervalSeconds: 3,
        forward: false,
      ),
    );
    expect(repository.current.interaction.pageTouchSlop, 9999);
    expect(repository.current.interaction.pageTouchClick, 0);
    expect(repository.current.interaction.selectText, isFalse);
    expect(repository.current.interaction.progressBarBehavior, 'chapter');
    await repository.updateInteraction(
      pageTouchSlop: 0,
      pageTouchClick: 800,
      progressBarBehavior: 'invalid',
    );
    expect(repository.current.interaction.pageTouchSlop, 0);
    expect(repository.current.interaction.pageTouchClick, 399);
    expect(repository.current.interaction.progressBarBehavior, 'page');
    expect(
      storage.writes.every((entry) => entry.$1.startsWith('reader_')),
      isTrue,
    );
  });

  test('两组保存失败回退且可重试，订阅不发布可变动作列表', () async {
    await repository.load();
    final observed = <ReaderAutoPageTurnSettings>[];
    final sub = repository
        .watch()
        .map((s) => s.autoPageTurn)
        .listen(observed.add);
    addTearDown(sub.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.updateAutoPageTurn(enabled: true),
      throwsStateError,
    );
    await expectLater(
      repository.updateInteraction(selectText: false),
      throwsStateError,
    );
    await expectLater(
      repository.updateInteraction(tapActions: List.filled(9, TapAction.none)),
      throwsStateError,
    );
    expect(repository.current.autoPageTurn, const ReaderAutoPageTurnSettings());
    expect(
      repository.current.interaction,
      const ReaderInteractionSettings.defaults(),
    );
    storage.writeFailure = false;
    await repository.updateAutoPageTurn(enabled: true);
    await repository.updateInteraction(selectText: false);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.enabled, isTrue);
    expect(repository.current.interaction.selectText, isFalse);
  });

  test('外部恢复重读全部设置，坏动作列表仅回退本字段，失败保留快照', () async {
    await repository.load();
    storage.values.addAll({
      'reader_auto_page_turn_enabled': true,
      'reader_auto_page_turn_interval_seconds': 200.0,
      'reader_auto_page_turn_forward': false,
      'reader_tap_actions': List.filled(9, 'openCatalog'),
      'reader_select_text': false,
      'reader_no_anim_scroll_page': true,
      'reader_volume_key_page': false,
      'reader_volume_key_page_on_play': true,
      'reader_mouse_wheel_page': false,
      'reader_page_touch_slop': 35,
      'reader_page_touch_click': 12,
      'reader_progress_bar_behavior': 'chapter',
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.autoPageTurn, const ReaderAutoPageTurnSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(repository.current.autoPageTurn.intervalSeconds, 120);
    expect(
      repository.current.interaction.tapActions,
      List.filled(9, TapAction.openCatalog),
    );
    expect(repository.current.interaction.pageTouchSlop, 35);
    expect(repository.current.interaction.volumeKeyPageOnPlay, isTrue);
    for (final invalid in [
      <String>['none'],
      List.filled(9, 'unknown'),
    ]) {
      storage.values['reader_tap_actions'] = invalid;
      await repository.reload();
      expect(
        repository.current.interaction.tapActions,
        ReaderInteractionSettings.defaultTapActions,
      );
      expect(repository.current.interaction.progressBarBehavior, 'chapter');
    }
    expect(storage.writes, isEmpty);
  });

  test('其他阅读设置不写回自动翻页和操作旧键', () async {
    await repository.updateAutoPageTurn(intervalSeconds: 35);
    await repository.updateInteraction(pageTouchClick: 30);
    await repository.updateScreen(keepScreenOnSeconds: 60);
    expect(repository.current.autoPageTurn.intervalSeconds, 35);
    expect(repository.current.interaction.pageTouchClick, 30);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'reader_adv_auto_page_turn',
      'reader_adv_auto_interval',
      'reader_adv_auto_forward',
      'reader_adv_tap_actions_v1',
      'reader_adv_left_action',
      'reader_adv_center_action',
      'reader_adv_right_action',
      'progressBarBehavior',
      'noAnimScrollPage',
      'selectText',
      'volumeKeyPage',
      'volumeKeyPageOnPlay',
      'mouseWheelPage',
      'pageTouchSlop',
      'pageTouchClick',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(storage.values['reader_keep_screen_on_seconds'], 60);
    expect(prefs.containsKey('keep_light'), isFalse);
  });
}
