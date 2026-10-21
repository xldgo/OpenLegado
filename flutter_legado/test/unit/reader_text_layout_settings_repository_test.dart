import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_text_layout_settings.dart';

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

  test('九项实际默认、单位保持，旧排版键不读取也不补写', () async {
    storage.values.addAll({
      'reader_adv_paragraph_spacing': 20.0,
      'reader_adv_letter_spacing': 4.0,
      'reader_adv_paragraph_indent': false,
      'reader_adv_paragraph_indent_chars': 3,
      'reader_adv_text_full_justify': false,
      'textBold': 1,
      'reader_adv_italic': true,
      'useZhLayout': true,
      'hangingPunctuation': true,
    });
    expect(
      (await repository.load()).textLayout,
      const ReaderTextLayoutSettings(),
    );
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    await repository.updateTextLayout();
    expect(storage.writes, isEmpty);
  });

  test('真实Preferences保存九项，新服务恢复，基础偏好不变', () async {
    SharedPreferences.setMockInitialValues({'reader_font_size': 23.0});
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.load();
    await actual.updateTextLayout(
      paragraphSpacing: 12,
      letterSpacing: 0.24,
      paragraphIndent: 3,
      textFullJustify: false,
      textBottomJustify: false,
      textBold: 2,
      italic: true,
      useZhLayout: true,
      hangingPunctuation: true,
    );
    final freshService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(freshService.dispose);
    final restored = await AppReaderSettingsRepository(freshService).load();
    expect(restored.fontSize, 23);
    expect(
      restored.textLayout,
      const ReaderTextLayoutSettings(
        paragraphSpacing: 12,
        letterSpacing: 0.24,
        paragraphIndent: 3,
        textFullJustify: false,
        textBottomJustify: false,
        textBold: 2,
        italic: true,
        useZhLayout: true,
        hangingPunctuation: true,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('reader_letter_spacing'), 0.24);
    expect(
      prefs.getKeys().where((key) => key.startsWith('reader_adv_')),
      isEmpty,
    );
  });

  test('逐字段保存不覆盖另一控件的更新，显式零值生效', () async {
    await repository.load();
    await repository.updateTextLayout(letterSpacing: 0.24, paragraphIndent: 3);
    await repository.updateTextLayout(italic: true);
    await repository.updateTextLayout(letterSpacing: 0, paragraphSpacing: 0);
    expect(
      repository.current.textLayout,
      const ReaderTextLayoutSettings(
        paragraphSpacing: 0,
        paragraphIndent: 3,
        italic: true,
      ),
    );
    expect(storage.writes, [
      ('reader_letter_spacing', 0.24),
      ('reader_paragraph_indent', 3),
      ('reader_italic', true),
      ('reader_paragraph_spacing_tenths', 0.0),
      ('reader_letter_spacing', 0.0),
    ]);
  });

  test('读写均按原有效范围处理，不把0em误当未设置', () async {
    storage.values.addAll({
      'reader_paragraph_spacing_tenths': 100.0,
      'reader_letter_spacing': -2.0,
      'reader_paragraph_indent': 8,
      'reader_text_bold': 7,
    });
    expect(
      (await repository.load()).textLayout,
      const ReaderTextLayoutSettings(
        paragraphSpacing: 20,
        letterSpacing: -0.5,
        paragraphIndent: 3,
        textBold: 2,
      ),
    );
    await repository.updateTextLayout(
      paragraphSpacing: -1,
      letterSpacing: 2,
      paragraphIndent: -1,
      textBold: -1,
    );
    expect(
      repository.current.textLayout,
      const ReaderTextLayoutSettings(
        paragraphSpacing: 0,
        letterSpacing: 1,
        paragraphIndent: 0,
      ),
    );
    expect(storage.values['reader_paragraph_spacing_tenths'], 0.0);
    expect(storage.values['reader_letter_spacing'], 1.0);
  });

  test('保存失败回退并传播，重试后发布成功快照', () async {
    storage.values['reader_letter_spacing'] = 0.24;
    await repository.load();
    final observed = <ReaderTextLayoutSettings>[];
    final subscription = repository
        .watch()
        .map((settings) => settings.textLayout)
        .listen(observed.add);
    addTearDown(subscription.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.updateTextLayout(letterSpacing: 0.4),
      throwsStateError,
    );
    expect(repository.current.textLayout.letterSpacing, 0.24);
    expect(storage.values['reader_letter_spacing'], 0.24);
    storage.writeFailure = false;
    await repository.updateTextLayout(letterSpacing: 0.4);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.letterSpacing, 0.4);
    expect(storage.values['reader_letter_spacing'], 0.4);
  });

  test('其他阅读设置不写回正文排版，也不生成旧转换标识', () async {
    await repository.updateTextLayout(
      letterSpacing: 0.24,
      paragraphSpacing: 12,
      italic: true,
    );
    await repository.updateScreen(keepScreenOnSeconds: 60);
    expect(
      repository.current.textLayout,
      const ReaderTextLayoutSettings(
        letterSpacing: 0.24,
        paragraphSpacing: 12,
        italic: true,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'reader_adv_paragraph_spacing',
      'reader_adv_letter_spacing',
      'reader_adv_letter_spacing_migrated',
      'reader_adv_paragraph_indent_chars',
      'reader_adv_paragraph_indent',
      'reader_adv_text_full_justify',
      'textBold',
      'reader_adv_italic',
      'useZhLayout',
      'hangingPunctuation',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(storage.values['reader_keep_screen_on_seconds'], 60);
    expect(prefs.containsKey('keep_light'), isFalse);
  });

  test('恢复重读九项，读取失败保留当前快照', () async {
    await repository.load();
    storage.values.addAll({
      'reader_paragraph_spacing_tenths': 15.0,
      'reader_letter_spacing': -0.2,
      'reader_paragraph_indent': 1,
      'reader_text_full_justify': false,
      'reader_text_bottom_justify': false,
      'reader_text_bold': 1,
      'reader_italic': true,
      'reader_use_zh_layout': true,
      'reader_hanging_punctuation': true,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.textLayout, const ReaderTextLayoutSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(
      repository.current.textLayout,
      const ReaderTextLayoutSettings(
        paragraphSpacing: 15,
        letterSpacing: -0.2,
        paragraphIndent: 1,
        textFullJustify: false,
        textBottomJustify: false,
        textBold: 1,
        italic: true,
        useZhLayout: true,
        hangingPunctuation: true,
      ),
    );
    expect(storage.writes, isEmpty);
  });
  test('中文分行默认开启，显式关闭与比例段距在重建后恢复', () async {
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    final initial = await actual.load();
    expect(initial.textLayout.useZhLayout, isTrue);
    expect(initial.textLayout.paragraphSpacing, 2);
    await actual.updateTextLayout(useZhLayout: false, paragraphSpacing: 6);
    final freshService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(freshService.dispose);
    final restored = await AppReaderSettingsRepository(freshService).load();
    expect(restored.textLayout.useZhLayout, isFalse);
    expect(restored.textLayout.paragraphSpacing, 6);
    expect(
      (await SharedPreferences.getInstance()).getDouble(
        'reader_paragraph_spacing_tenths',
      ),
      6,
    );
  });
}
