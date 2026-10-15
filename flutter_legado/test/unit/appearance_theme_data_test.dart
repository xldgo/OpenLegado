import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/models/theme_colors_settings.dart';
import 'package:flutter_legado/src/data/repositories/preferences_theme_preset_repository.dart';
import 'package:flutter_legado/src/features/appearance/theme_actions.dart';
import 'package:flutter_legado/src/models/theme_document.dart';
import 'package:flutter_legado/src/models/theme_preset.dart';
import 'package:flutter_legado/src/platform/files/theme_file_service.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';

class ControlledPresetPreferences extends Fake implements SharedPreferences {
  ControlledPresetPreferences(this.delegate);
  final SharedPreferences delegate;
  Completer<void>? gate;
  bool failNext = false;
  bool throwsOnFailure = true;
  bool failRead = false;
  int writes = 0;

  @override
  String? getString(String key) {
    if (failRead) throw StateError('模拟读取失败');
    return delegate.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    writes++;
    final saved = await delegate.setString(key, value);
    await gate?.future;
    if (failNext) {
      failNext = false;
      if (throwsOnFailure) throw StateError('模拟保存失败');
      return false;
    }
    return saved;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);
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
    final repository = PreferencesThemePresetRepository();
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
      SharedPreferences.setMockInitialValues({'themeConfigList': raw});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await PreferencesThemePresetRepository(
          loadPreferences: () async => prefs,
        ).readAll(),
        isEmpty,
      );
      expect(prefs.getString('themeConfigList'), raw);
    }
  });

  test('并发保存与随后读取按顺序执行，失败不阻塞下一项', () async {
    final settings = ControlledPresetPreferences(
      await SharedPreferences.getInstance(),
    )..gate = Completer<void>();
    final repository = PreferencesThemePresetRepository(
      loadPreferences: () async => settings,
    );
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

  test('平台读取失败不伪装空列表覆盖原预设，恢复后可重试', () async {
    const raw = '[{"name":"原主题","extra":"保留"}]';
    SharedPreferences.setMockInitialValues({'themeConfigList': raw});
    final prefs = await SharedPreferences.getInstance();
    final controlled = ControlledPresetPreferences(prefs)..failRead = true;
    final repository = PreferencesThemePresetRepository(
      loadPreferences: () async => controlled,
    );
    await expectLater(repository.readAll(), throwsStateError);
    await expectLater(
      repository.add(ThemePreset(name: '新项', isNight: true)),
      throwsStateError,
    );
    expect(prefs.getString('themeConfigList'), raw);
    expect(controlled.writes, 0);
    controlled.failRead = false;
    await repository.add(ThemePreset(name: '新项', isNight: true));
    expect((await repository.readAll()).map((item) => item.name), [
      '原主题',
      '新项',
    ]);
  });

  for (final throwsOnFailure in [false, true]) {
    for (final remove in [false, true]) {
      test(
        '预设${remove ? '删除' : '新增'}写入${throwsOnFailure ? '异常' : 'false'}恢复列表和缓存，可重试',
        () async {
          const raw = '[{"name":"原主题","isNight":true,"extra":"保留"}]';
          SharedPreferences.setMockInitialValues({'themeConfigList': raw});
          final prefs = await SharedPreferences.getInstance();
          final controlled = ControlledPresetPreferences(prefs)
            ..failNext = true
            ..throwsOnFailure = throwsOnFailure;
          final repository = PreferencesThemePresetRepository(
            loadPreferences: () async => controlled,
          );
          final changed = ThemePreset(name: '新主题', isNight: false);
          await expectLater(
            remove ? repository.removeAt(0) : repository.add(changed),
            throwsStateError,
          );
          expect(prefs.getString('themeConfigList'), raw);
          expect((await repository.readAll()).single.name, '原主题');
          await prefs.reload();
          expect(prefs.getString('themeConfigList'), raw);
          if (remove) {
            expect(await repository.removeAt(0), isEmpty);
          } else {
            await repository.add(changed);
            expect((await repository.readAll()).map((item) => item.name), [
              '原主题',
              '新主题',
            ]);
          }
        },
      );
    }

    test('首份预设写入${throwsOnFailure ? '异常' : 'false'}恢复缺键并可重试', () async {
      final prefs = await SharedPreferences.getInstance();
      final controlled = ControlledPresetPreferences(prefs)
        ..failNext = true
        ..throwsOnFailure = throwsOnFailure;
      final repository = PreferencesThemePresetRepository(
        loadPreferences: () async => controlled,
      );
      final first = ThemePreset(name: '首份主题', isNight: false);
      await expectLater(repository.add(first), throwsStateError);
      expect(prefs.containsKey('themeConfigList'), isFalse);
      await prefs.reload();
      expect(prefs.containsKey('themeConfigList'), isFalse);
      await repository.add(first);
      expect((await repository.readAll()).single.name, '首份主题');
    });
  }

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
    await colors.applyColors({
      ThemeColorRole.primary: 11,
      ThemeColorRole.primaryNight: 22,
    });
    await colors.setBgImage(day: '原背景');
    final actions = container.read(themeActionsProvider);
    await actions.savePreset('夜间', isNight: true);
    await colors.applyColors({
      ThemeColorRole.primary: 33,
      ThemeColorRole.primaryNight: 44,
    });
    await actions.applyPreset((await actions.readPresets()).single);
    expect(container.read(themeColorsProvider).primary, 33);
    expect(container.read(themeColorsProvider).primaryNight, 22);
    expect(container.read(themeColorsProvider).bgImage, '原背景');
  });

  test('文件导入清除缺省组，更新色板模式，保留背景图', () async {
    final container = await initializedContainer();
    final colors = container.read(themeColorsProvider.notifier);
    await colors.applyColors({
      ThemeColorRole.primary: 11,
      ThemeColorRole.primaryNight: 22,
    });
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
      ThemeColorRole.primary: 77,
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
