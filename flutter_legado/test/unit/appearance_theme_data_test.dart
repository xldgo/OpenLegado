import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/repositories/preferences_theme_preset_repository.dart';
import 'package:flutter_legado/src/features/appearance/theme_actions.dart';
import 'package:flutter_legado/src/models/theme_document.dart';
import 'package:flutter_legado/src/models/theme_preset.dart';
import 'package:flutter_legado/src/platform/files/theme_file_service.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/services/settings_service.dart';

class ControlledPresetSettings extends SettingsService {
  String value = '';
  Completer<void>? gate;
  bool failNext = false;

  @override
  Future<String> getStringPref(String key, {String defaultValue = ''}) async =>
      value;

  @override
  Future<void> setStringPrefChecked(String key, String value) async {
    await gate?.future;
    if (failNext) {
      failNext = false;
      throw StateError('模拟保存失败');
    }
    this.value = value;
  }
}

class ControlledThemeFiles extends ThemeFileService {
  ThemeDocument? exported;
  Object? error;
  bool cancelled = false;

  @override
  Future<ThemeDocument?> importTheme() async {
    if (error case final Object value) throw value;
    return null;
  }

  @override
  Future<bool> exportTheme(ThemeDocument document) async {
    if (error case final Object value) throw value;
    if (cancelled) return false;
    exported = document;
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('命名预设保留旧字段、默认名称及严格整型颜色', () {
    final json = <String, dynamic>{'primary': 123, 'extra': '原数据'};
    final preset = ThemePreset.fromJson(json);
    json['primary'] = 456;
    expect(preset.name, '未命名');
    expect(preset.isNight, isFalse);
    expect(preset.primary, 123);
    expect(preset.toJson(), {'primary': 123, 'extra': '原数据'});
    expect(
      () => ThemePreset.fromJson({'primary': 1.5}).primary,
      throwsA(isA<TypeError>()),
    );
  });

  test('日夜文件格式往返，缺省颜色保留 null', () {
    const document = ThemeDocument(
      paletteId: 'def',
      themeMode: 'system',
      day: ThemeDocumentColors(primary: 123),
      night: ThemeDocumentColors(background: 456),
    );
    final json = document.toJson();
    expect(json['app'], 'legado');
    expect(json['type'], 'theme');
    expect(json['version'], 1);
    final restored = ThemeDocument.fromJson(jsonDecode(jsonEncode(json)));
    expect(restored.toJson(), json);
    expect(restored.day.accent, isNull);
  });

  test('导入保留宽松格式：声明不作门禁，数值转整型，未知模式忽略', () {
    final document = ThemeDocument.fromJson({
      'app': '其他来源',
      'version': 99,
      'paletteId': '未知色板',
      'themeMode': 'unknown',
      'day': {'primary': 1.8, 'accent': '不是数字'},
      'night': '不是颜色组',
    });
    expect(document.paletteId, '未知色板');
    expect(document.themeMode, isNull);
    expect(document.day.primary, 1);
    expect(document.day.accent, isNull);
    expect(document.night.toJson().values, everyElement(isNull));
    expect(
      ThemeDocument.fromJson(<String, dynamic>{}).day.toJson().values,
      everyElement(isNull),
    );
    expect(() => ThemeDocument.fromJson([]), throwsFormatException);
  });

  test('预设通过原键读取并保存，删除保留其他条目及扩展字段', () async {
    SharedPreferences.setMockInitialValues({
      'themeConfigList': jsonEncode([
        {'name': '旧白天', 'primary': 11, 'extra': '保留'},
        {'name': '旧夜间', 'isNight': true, 'accent': 22},
      ]),
    });
    final repository = PreferencesThemePresetRepository(SettingsService());
    expect((await repository.readAll()).map((item) => item.name), [
      '旧白天',
      '旧夜间',
    ]);
    await repository.add(ThemePreset(name: '新主题', isNight: false, primary: 33));
    final remaining = await repository.removeAt(1);
    expect(remaining.map((item) => item.name), ['旧白天', '新主题']);
    final raw = (await SharedPreferences.getInstance()).getString(
      'themeConfigList',
    )!;
    expect((jsonDecode(raw) as List).first['extra'], '保留');
  });

  test('损坏预设沿用空列表回退，不改写存储', () async {
    for (final raw in ['{', '{}', '[1]']) {
      final settings = ControlledPresetSettings()..value = raw;
      expect(
        await PreferencesThemePresetRepository(settings).readAll(),
        isEmpty,
      );
      expect(settings.value, raw);
    }
  });

  test('并发保存与随后读取按顺序执行，失败不阻塞下一项', () async {
    final settings = ControlledPresetSettings()..gate = Completer<void>();
    final repository = PreferencesThemePresetRepository(settings);
    final first = repository.add(ThemePreset(name: '第一项', isNight: false));
    final second = repository.add(ThemePreset(name: '第二项', isNight: true));
    final read = repository.readAll();
    settings.gate!.complete();
    await Future.wait([first, second]);
    expect((await read).map((item) => item.name), ['第一项', '第二项']);
    settings.failNext = true;
    await expectLater(repository.removeAt(0), throwsStateError);
    expect((await repository.readAll()).map((item) => item.name), [
      '第一项',
      '第二项',
    ]);
    await repository.add(ThemePreset(name: '失败后重试', isNight: false));
    expect((await repository.readAll()).length, 3);
  });

  Future<ProviderContainer> initializedContainer({
    ControlledThemeFiles? files,
  }) async {
    final container = ProviderContainer(
      overrides: [
        if (files != null) themeFileServiceProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    container.read(themeColorsProvider);
    container.read(themeNotifierProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('保存与应用预设只更新对应日夜颜色，不修改另一侧和背景图', () async {
    final container = await initializedContainer();
    final colors = container.read(themeColorsProvider.notifier);
    await colors.applyColors({PrefKeys.cPrimary: 11, PrefKeys.cNPrimary: 22});
    await colors.setBgImage(day: '原背景');
    final actions = container.read(themeActionsProvider);
    await actions.savePreset('夜间', isNight: true);
    await colors.applyColors({PrefKeys.cPrimary: 33, PrefKeys.cNPrimary: 44});
    await actions.applyPreset((await actions.readPresets()).single);
    expect(container.read(themeColorsProvider).primary, 33);
    expect(container.read(themeColorsProvider).primaryNight, 22);
    expect(container.read(themeColorsProvider).bgImage, '原背景');
  });

  test('文件导入清除缺省组，更新色板模式，保留背景图', () async {
    final container = await initializedContainer();
    final colors = container.read(themeColorsProvider.notifier);
    await colors.applyColors({PrefKeys.cPrimary: 11, PrefKeys.cNPrimary: 22});
    await colors.setBgImage(night: '夜间背景');
    await container
        .read(themeActionsProvider)
        .applyDocument(
          ThemeDocument.fromJson({
            'paletteId': 'koharu',
            'themeMode': 'dark',
            'day': {'accent': 33},
          }),
        );
    expect(container.read(themeColorsProvider).primary, isNull);
    expect(container.read(themeColorsProvider).primaryNight, isNull);
    expect(container.read(themeColorsProvider).accent, 33);
    expect(container.read(themeColorsProvider).bgImageNight, '夜间背景');
    expect(container.read(themeNotifierProvider).paletteId, 'koharu');
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
  });

  test('导入未知模式和空色板时保留当前选择', () async {
    final container = await initializedContainer();
    await container
        .read(themeNotifierProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await container.read(themeNotifierProvider.notifier).setPaletteId('koharu');
    await container
        .read(themeActionsProvider)
        .applyDocument(
          ThemeDocument.fromJson({'themeMode': 'other', 'paletteId': ''}),
        );
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    expect(container.read(themeNotifierProvider).paletteId, 'koharu');
  });

  test('文件选择取消或失败不更改配色，导出使用当前状态', () async {
    final files = ControlledThemeFiles();
    final container = await initializedContainer(files: files);
    await container.read(themeColorsProvider.notifier).applyColors({
      PrefKeys.cPrimary: 77,
    });
    final actions = container.read(themeActionsProvider);
    expect(await actions.readThemeFile(), isNull);
    files.cancelled = true;
    expect(await actions.exportTheme(), isFalse);
    expect(files.exported, isNull);
    files.error = const FormatException('模拟文件错误');
    await expectLater(actions.readThemeFile(), throwsFormatException);
    expect(container.read(themeColorsProvider).primary, 77);
    files.error = null;
    files.cancelled = false;
    expect(await actions.exportTheme(), isTrue);
    expect(files.exported!.day.primary, 77);
    expect(files.exported!.paletteId, 'def');
  });
}
