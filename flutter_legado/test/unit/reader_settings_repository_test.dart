import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/page_turn_mode.dart';
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

  test('默认覆盖，不读取未生效的高级翻页副本，也不补写设置', () async {
    storage.values['flip_mode'] = 0;
    expect(await repository.load(), const ReaderSettings());
    await repository.update();
    expect(storage.writes, isEmpty);
    expect(storage.values, {'flip_mode': 0});
  });

  test('名称优先，原有效整数按原索引恢复，与高级整数含义无关', () async {
    storage.values.addAll({
      'reader_flip_mode_name': 'scroll',
      'reader_flip_mode': 2,
      'flip_mode': 3,
    });
    expect((await repository.load()).pageTurnMode, PageTurnMode.scroll);
    storage.values.remove('reader_flip_mode_name');
    for (final (index, mode) in const [
      (0, PageTurnMode.scroll),
      (1, PageTurnMode.slide),
      (2, PageTurnMode.simulate),
      (3, PageTurnMode.none),
      (4, PageTurnMode.cover),
    ]) {
      storage.values['reader_flip_mode'] = index;
      await repository.reload();
      expect(repository.current.pageTurnMode, mode);
    }
    expect(storage.writes, isEmpty);
  });

  test('五种模式只写规范名称，重新装配可恢复，其他偏好保持原值', () async {
    SharedPreferences.setMockInitialValues({
      'reader_flip_mode': 3,
      'flip_mode': 0,
      'reader_font_size': 24.0,
      'keep_light': 8,
    });
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    for (final mode in PageTurnMode.values) {
      await actual.update(pageTurnMode: mode);
      final freshService = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      try {
        expect(
          (await AppReaderSettingsRepository(freshService).load()).pageTurnMode,
          mode,
        );
      } finally {
        await freshService.dispose();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reader_flip_mode_name'), 'cover');
    expect(prefs.getInt('reader_flip_mode'), 3);
    expect(prefs.getInt('flip_mode'), 0);
    expect(prefs.getDouble('reader_font_size'), 24);
    expect(prefs.getInt('keep_light'), 8);
  });

  test('加载前选择新模式，不被原值覆盖，也不写旧整数副本', () async {
    storage.values.addAll({
      'reader_flip_mode_name': 'slide',
      'reader_flip_mode': 1,
      'reader_font_size': 22.0,
    });
    await repository.update(pageTurnMode: PageTurnMode.simulate);
    expect(repository.current.pageTurnMode, PageTurnMode.simulate);
    expect((await repository.load()).pageTurnMode, PageTurnMode.simulate);
    expect(storage.writes, [('reader_flip_mode_name', 'simulate')]);
    expect(storage.values['reader_flip_mode'], 1);
    expect(storage.values['reader_font_size'], 22);
  });

  test('修改屏幕设置不会重新创建或覆盖翻页副本', () async {
    SharedPreferences.setMockInitialValues({
      'reader_flip_mode_name': 'slide',
      'flip_mode': 2,
    });
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.update(pageTurnMode: PageTurnMode.scroll);
    await actual.updateScreen(keepScreenOnSeconds: 60);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reader_flip_mode_name'), 'scroll');
    expect(prefs.getInt('flip_mode'), 2);
    expect(prefs.getInt('reader_keep_screen_on_seconds'), 60);
    expect(actual.current.pageTurnMode, PageTurnMode.scroll);
  });

  test('保存失败向调用方报错、共享值回退，重试后可恢复', () async {
    storage.values['reader_flip_mode_name'] = 'none';
    await repository.load();
    final observed = <ReaderSettings>[];
    final subscription = repository.watch().listen(observed.add);
    addTearDown(subscription.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.update(pageTurnMode: PageTurnMode.cover),
      throwsStateError,
    );
    expect(repository.current.pageTurnMode, PageTurnMode.none);
    expect(storage.values['reader_flip_mode_name'], 'none');
    storage.writeFailure = false;
    await repository.update(pageTurnMode: PageTurnMode.cover);
    await Future<void>.delayed(Duration.zero);
    expect(repository.current.pageTurnMode, PageTurnMode.cover);
    expect(storage.values['reader_flip_mode_name'], 'cover');
    expect(observed.last.pageTurnMode, PageTurnMode.cover);
  });

  test('恢复后的显式重读发布新模式，失效名称沿用原回退规则', () async {
    storage.values['reader_flip_mode_name'] = 'slide';
    await repository.load();
    storage.values['reader_flip_mode_name'] = 'simulate';
    await repository.reload();
    expect(repository.current.pageTurnMode, PageTurnMode.simulate);
    storage.values.addAll({
      'reader_flip_mode_name': '已删除的模式',
      'reader_flip_mode': 0,
    });
    await repository.reload();
    expect(repository.current.pageTurnMode, PageTurnMode.scroll);
    storage.values.remove('reader_flip_mode');
    await repository.reload();
    expect(repository.current.pageTurnMode, PageTurnMode.cover);
    expect(storage.writes, isEmpty);
  });

  test('字号行距按原double键和默认值恢复，独立修改不覆盖其他字段', () async {
    storage.values.addAll({
      'reader_font_size': 20.6,
      'reader_line_height': 1.9,
      'reader_flip_mode_name': 'slide',
    });
    final loaded = await repository.load();
    expect(loaded.fontSize, 20.6);
    expect(loaded.lineHeight, 1.9);
    await repository.update(fontSize: 25.0);
    expect(repository.current.lineHeight, 1.9);
    await repository.update(lineHeight: 2.2);
    expect(repository.current.fontSize, 25);
    expect(repository.current.pageTurnMode, PageTurnMode.slide);
    expect(storage.writes, [
      ('reader_font_size', 25.0),
      ('reader_line_height', 2.2),
    ]);
    final freshService = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(freshService.dispose);
    expect(
      await AppReaderSettingsRepository(freshService).load(),
      const ReaderSettings(
        pageTurnMode: PageTurnMode.slide,
        fontSize: 25,
        lineHeight: 2.2,
      ),
    );
  });

  test('双字段保存中后一项失败，只回退失败字段，重试后保存成功', () async {
    storage.values.addAll({
      'reader_font_size': 22.0,
      'reader_line_height': 1.8,
    });
    await repository.load();
    storage.beforeWrite = (key, _) async {
      if (key == 'reader_line_height') throw StateError('行距保存失败');
    };
    await expectLater(
      repository.update(fontSize: 24, lineHeight: 2),
      throwsStateError,
    );
    expect(repository.current.fontSize, 24);
    expect(repository.current.lineHeight, 1.8);
    expect(storage.values['reader_font_size'], 24);
    expect(storage.values['reader_line_height'], 1.8);
    storage.beforeWrite = null;
    await repository.update(lineHeight: 2);
    expect(repository.current.lineHeight, 2);
  });

  test('恢复后的重读包含字号行距，读取失败不覆盖有效快照', () async {
    storage.values.addAll({
      'reader_font_size': 22.0,
      'reader_line_height': 1.8,
    });
    await repository.load();
    storage.values.addAll({
      'reader_font_size': 26.0,
      'reader_line_height': 2.4,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.fontSize, 22);
    expect(repository.current.lineHeight, 1.8);
    storage.readFailure = false;
    await repository.reload();
    expect(repository.current.fontSize, 26);
    expect(repository.current.lineHeight, 2.4);
    expect(storage.writes, isEmpty);
  });

  test('目录与链接使用规范键、原默认，不读取旧键', () async {
    storage.values.addAll({
      'toc_load_word_count': false,
      'readUrlInBrowser': true,
    });
    expect(await repository.load(), const ReaderSettings());
    expect(storage.reads, isNot(contains('toc_load_word_count')));
    expect(storage.reads, isNot(contains('readUrlInBrowser')));
    expect(storage.writes, isEmpty);
  });

  test('目录与链接独立保存到规范键，新装配恢复同一偏好', () async {
    storage.values['reader_font_size'] = 23.0;
    await repository.load();
    await repository.update(tocLoadWordCount: false);
    expect(repository.current.chapterInSystemBrowser, isFalse);
    await repository.update(chapterInSystemBrowser: true);
    expect(repository.current.tocLoadWordCount, isFalse);
    expect(repository.current.fontSize, 23);
    expect(storage.writes, [
      ('reader_toc_load_word_count', false),
      ('reader_chapter_in_system_browser', true),
    ]);
    final freshService = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(freshService.dispose);
    expect(
      await AppReaderSettingsRepository(freshService).load(),
      const ReaderSettings(
        fontSize: 23,
        tocLoadWordCount: false,
        chapterInSystemBrowser: true,
      ),
    );
  });

  test('目录与链接保存失败均回退，订阅发布成功重试值', () async {
    await repository.load();
    final observed = <ReaderSettings>[];
    final subscription = repository.watch().listen(observed.add);
    addTearDown(subscription.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.update(tocLoadWordCount: false),
      throwsStateError,
    );
    await expectLater(
      repository.update(chapterInSystemBrowser: true),
      throwsStateError,
    );
    expect(repository.current, const ReaderSettings());
    expect(storage.values, isEmpty);
    storage.writeFailure = false;
    await repository.update(
      tocLoadWordCount: false,
      chapterInSystemBrowser: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      observed.last,
      const ReaderSettings(
        tocLoadWordCount: false,
        chapterInSystemBrowser: true,
      ),
    );
    expect(observed, contains(const ReaderSettings()));
  });

  test('外部恢复重读两项偏好，失败保留有效快照', () async {
    await repository.load();
    storage.values.addAll({
      'reader_toc_load_word_count': false,
      'reader_chapter_in_system_browser': true,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current, const ReaderSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(
      repository.current,
      const ReaderSettings(
        tocLoadWordCount: false,
        chapterInSystemBrowser: true,
      ),
    );
    expect(storage.writes, isEmpty);
  });
}
