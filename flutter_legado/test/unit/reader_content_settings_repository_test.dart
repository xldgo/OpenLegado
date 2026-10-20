import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_settings.dart';

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

  test('三项默认不读取旧键，不补写或转换旧设置', () async {
    storage.values.addAll({
      'autoChangeSource': false,
      'keep_light': -1,
      'showReadTitleAddition': false,
    });
    expect(await repository.load(), const ReaderSettings());
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    await repository.update();
    await repository.updateScreen();
    expect(storage.writes, isEmpty);
  });

  test('真实Preferences保存三项，新仓储恢复且不修改旧键', () async {
    SharedPreferences.setMockInitialValues({
      'autoChangeSource': true,
      'keep_light': 300,
      'showReadTitleAddition': true,
    });
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
    await actual.update(autoChangeSource: false, showTitleAddition: false);
    await actual.updateScreen(keepScreenOnSeconds: -1);
    final restored = await create().load();
    expect(restored.autoChangeSource, isFalse);
    expect(restored.showTitleAddition, isFalse);
    expect(restored.screen.keepScreenOnSeconds, -1);
    expect(restored, actual.current);
    expect(restored.hashCode, actual.current.hashCode);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(6));
    expect(prefs.getBool('reader_auto_change_source'), isFalse);
    expect(prefs.getBool('reader_show_title_addition'), isFalse);
    expect(prefs.getInt('reader_keep_screen_on_seconds'), -1);
    expect(prefs.getBool('autoChangeSource'), isTrue);
    expect(prefs.getInt('keep_light'), 300);
    expect(prefs.getBool('showReadTitleAddition'), isTrue);
  });

  test('逐字段保存保持其他分组，旧快照不可变且显式零有效', () async {
    await repository.load();
    await repository.updateMenuTheme(mode: 2, textColor: 0xff123456);
    await repository.updateInteraction(selectText: false);
    final before = repository.current;
    await repository.update(autoChangeSource: false);
    await repository.updateScreen(keepScreenOnSeconds: 600);
    await repository.update(showTitleAddition: false);
    expect(repository.current.menuTheme, before.menuTheme);
    expect(repository.current.interaction, before.interaction);
    expect(before.autoChangeSource, isTrue);
    expect(before.screen.keepScreenOnSeconds, 0);
    expect(before.showTitleAddition, isTrue);
    await repository.updateScreen(keepScreenOnSeconds: 0);
    expect(repository.current.screen.keepScreenOnSeconds, 0);
    expect(repository.current.autoChangeSource, isFalse);
    expect(repository.current.showTitleAddition, isFalse);
  });

  test('亮屏时长只接受已有选项，读写使用相同范围', () async {
    await repository.load();
    for (final value in [-1, 0, 60, 300, 600]) {
      await repository.updateScreen(keepScreenOnSeconds: value);
      expect(repository.current.screen.keepScreenOnSeconds, value);
      expect(storage.values['reader_keep_screen_on_seconds'], value);
    }
    await repository.updateScreen(keepScreenOnSeconds: 12);
    expect(repository.current.screen.keepScreenOnSeconds, 0);
    storage.values['reader_keep_screen_on_seconds'] = 50;
    await repository.reload();
    expect(repository.current.screen.keepScreenOnSeconds, 0);
    expect(storage.values['reader_keep_screen_on_seconds'], 50);
  });

  test('保存失败回退失败字段并通知，队列后续写入和重试可用', () async {
    await repository.load();
    final observed = <bool>[];
    final subscription = repository.watch().listen(
      (s) => observed.add(s.autoChangeSource),
    );
    addTearDown(subscription.cancel);
    storage.beforeWrite = (key, _) async {
      if (key == 'reader_auto_change_source') {
        throw StateError('模拟保存失败');
      }
    };
    final failed = expectLater(
      repository.update(autoChangeSource: false),
      throwsStateError,
    );
    await repository.updateScreen(keepScreenOnSeconds: 300);
    await failed;
    expect(repository.current.autoChangeSource, isTrue);
    expect(repository.current.screen.keepScreenOnSeconds, 300);
    expect(observed, containsAllInOrder([false, true]));
    storage.beforeWrite = null;
    await repository.update(autoChangeSource: false);
    expect(repository.current.autoChangeSource, isFalse);
    storage.writeFailure = true;
    await expectLater(
      repository.update(showTitleAddition: false),
      throwsStateError,
    );
    await expectLater(
      repository.updateScreen(keepScreenOnSeconds: -1),
      throwsStateError,
    );
    expect(repository.current.showTitleAddition, isTrue);
    expect(repository.current.screen.keepScreenOnSeconds, 300);
    storage.writeFailure = false;
    await repository.update(showTitleAddition: false);
    await repository.updateScreen(keepScreenOnSeconds: -1);
    expect(repository.current.showTitleAddition, isFalse);
    expect(repository.current.screen.keepScreenOnSeconds, -1);
  });

  test('并发加载复用同一次读取，等待期间的修改不被旧存储覆盖', () async {
    storage.values['reader_auto_change_source'] = true;
    final gate = Completer<void>();
    storage.readBarrier = gate;
    final first = repository.load();
    final second = repository.load();
    expect(identical(first, second), isTrue);
    final saving = repository.update(autoChangeSource: false);
    expect(repository.current.autoChangeSource, isFalse);
    gate.complete();
    await first;
    await second;
    await saving;
    expect(repository.current.autoChangeSource, isFalse);
    expect(storage.reads.toSet().length, storage.reads.length);
    expect(storage.writes, [('reader_auto_change_source', false)]);
  });

  test('读取失败可重试，恢复重读发布三项且不写入默认', () async {
    storage.readFailure = true;
    await expectLater(repository.load(), throwsStateError);
    storage.readFailure = false;
    await repository.load();
    final next = repository.watch().firstWhere(
      (s) =>
          !s.autoChangeSource &&
          !s.showTitleAddition &&
          s.screen.keepScreenOnSeconds == 300,
    );
    storage.values.addAll({
      'reader_auto_change_source': false,
      'reader_show_title_addition': false,
      'reader_keep_screen_on_seconds': 300,
    });
    await repository.reload();
    expect((await next).screen.keepScreenOnSeconds, 300);
    expect(storage.writes, isEmpty);
  });
}
