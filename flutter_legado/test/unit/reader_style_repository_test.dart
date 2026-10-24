import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_style_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_style.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppReaderStyleRepository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    repository = AppReaderStyleRepository(service);
  });
  tearDown(() => service.dispose());

  test('六套日夜配色逐项对应固定上游 JSON，包含明确文字色', () {
    final fixture = jsonDecode(
      File('test/fixtures/upstream_reader_colors.json').readAsStringSync(),
    ) as Map;
    final rows = fixture['styles'] as List;
    expect(readerStylePresets, hasLength(rows.length));
    int argb(String value) => int.parse(
      value.length == 7 ? 'FF${value.substring(1)}' : value.substring(1),
      radix: 16,
    );
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map;
      final style = readerStylePresets[i];
      expect(style.name, row['name']);
      expect(style.day.background, argb(row['bgStr'] as String));
      expect(style.day.text, argb(row['textColor'] as String));
      expect(style.night.background, argb(row['bgStrNight'] as String));
      expect(style.night.text, argb(row['textColorNight'] as String));
    }
  });

  test('旧显式背景及文字色转入同一自定义样式，原值保留', () async {
    storage.values.addAll({
      'reader_bg_color_index': 1,
      'reader_adv_custom_text_color': 0xFF123456,
    });
    final result = await repository.load();
    expect(result.selectedId, 'custom');
    expect(
      result.selected.day,
      const ReaderColors(background: 0xFFCCEBCC, text: 0xFF123456),
    );
    expect(result.selected.night, result.selected.day);
    expect(storage.values['reader_bg_color_index'], 1);
    expect(storage.writes.map((write) => write.$1).toSet(), {'reader_styles'});
  });

  test('未选背景与旧夜间预设保留默认解析，浅色旧预设保留原文字色', () async {
    expect((await repository.load()).selected.day.background, isNull);
    storage.values.remove('reader_styles');
    storage.values['reader_bg_color_index'] = 4;
    await repository.reload();
    expect(repository.current.selected.day.background, 0xFF1A1A1A);
    expect(repository.current.selected.night.background, isNull);
    expect(repository.current.selected.night.text, 0xFFCCCCCC);
  });

  test('自定义背景优先于旧预设，两侧保留原背景和自动文字色', () async {
    storage.values.addAll({
      'reader_bg_color_index': 2,
      'reader_bg_use_custom': true,
      'reader_custom_bg_color': 0xFF232323,
    });
    final style = (await repository.load()).selected;
    expect(style.day, const ReaderColors(background: 0xFF232323));
    expect(style.night, style.day);
  });

  test('模板内日夜独立编辑，切换模板与重新装配恢复各自颜色', () async {
    await repository.load();
    final copy = await repository.createFromTemplate('preset2', '我的米色');
    final night = repository.current.selected.night;
    await repository.updateColors(
      isNight: false,
      update: (_) =>
          const ReaderColors(background: 0xFF112233, text: 0xFFAABBCC),
    );
    expect(repository.current.selected.night, night);
    await repository.select('preset3');
    expect(repository.current.selected.day, readerStylePresets[3].day);
    await repository.select(copy);
    expect(repository.current.selected.day.background, 0xFF112233);
    final fresh = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(fresh.dispose);
    storage.reads.clear();
    final restored = await AppReaderStyleRepository(fresh).load();
    expect(restored, repository.current);
    expect(() => restored.styles.clear(), throwsUnsupportedError);
  });

  test('模板选择和编辑保存失败回退，重试成功，其他高级保存不覆盖配色', () async {
    await repository.load();
    storage.writeFailure = true;
    await expectLater(repository.select('preset4'), throwsStateError);
    expect(repository.current.selectedId, 'custom');
    storage.writeFailure = false;
    await repository.createFromTemplate('preset4', '我的紫色');
    final before = repository.current;
    storage.writeFailure = true;
    await expectLater(
      repository.updateColors(
        isNight: true,
        update: (colors) =>
            ReaderColors(background: colors.background, text: 0xFF445566),
      ),
      throwsStateError,
    );
    expect(repository.current, before);
    storage.writeFailure = false;
    final settings = AppReaderSettingsRepository(service);
    await settings.updateScreen(keepScreenOnSeconds: 60);
    expect(repository.current, before);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'reader_adv_custom_text_color',
      ),
      isFalse,
    );
  });

  test('恢复的样式文档重新读取，未知模板拒绝保存，损坏文档不覆盖原值', () async {
    await repository.load();
    final original = storage.values['reader_styles'];
    await repository.select('preset5');
    storage.values['reader_styles'] = original;
    await repository.reload();
    expect(repository.current.selectedId, 'custom');
    expect(() => repository.select('不存在'), throwsArgumentError);
    storage.values['reader_styles'] = '损坏内容';
    await expectLater(repository.reload(), throwsFormatException);
    expect(storage.values['reader_styles'], '损坏内容');
  });
}
