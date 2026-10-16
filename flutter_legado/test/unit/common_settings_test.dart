import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/data/repositories/app_bookshelf_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_read_record_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_locale_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_eye_protection_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_welcome_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/bookshelf_settings.dart';
import 'package:flutter_legado/src/domain/models/read_record_settings.dart';
import 'package:flutter_legado/src/domain/models/locale_settings.dart';
import 'package:flutter_legado/src/domain/models/eye_protection_settings.dart';
import 'package:flutter_legado/src/domain/models/welcome_settings.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_locale_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/eye_protection_notifier.dart';
import 'package:flutter_legado/src/providers/welcome_settings_provider.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppBookshelfSettingsRepository shelf;
  late AppReadRecordSettingsRepository records;
  late AppLocaleSettingsRepository locale;
  late AppEyeProtectionSettingsRepository eye;
  late AppWelcomeSettingsRepository welcome;

  setUp(() {
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    shelf = AppBookshelfSettingsRepository(service);
    records = AppReadRecordSettingsRepository(service);
    locale = AppLocaleSettingsRepository(
      service,
      supportedLanguages: ['zh', 'en'],
    );
    eye = AppEyeProtectionSettingsRepository(service);
    welcome = AppWelcomeSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  test('五域共二十五项默认值保持，读取和空更新不补写存储', () async {
    expect(await shelf.load(), const BookshelfSettings());
    expect(await records.load(), const ReadRecordSettings());
    expect(await locale.load(), const LocaleSettings());
    expect(await eye.load(), const EyeProtectionSettings());
    expect(await welcome.load(), const WelcomeSettings());
    expect(storage.reads.toSet(), {
      'bookshelf_layout',
      'bookshelf_grid_columns',
      'bookshelf_group_mode',
      'bookshelf_tab_position',
      'openBookInfoByClickTitle',
      'delete_book_alert',
      'enableReadRecord',
      'readRecordSort',
      'readRecordDisplayMode',
      'app_locale',
      'eyeProtectionEnabled',
      'colorTemperature',
      'eyeProtectionAutoNight',
      'eyeProtectionSchedule',
      'eyeProtectionStartTime',
      'eyeProtectionEndTime',
      'welcomeShowTime',
      'customWelcome',
      'welcomeImagePath',
      'welcomeImagePathDark',
      'welcomeShowText',
      'welcomeShowIcon',
      'welcomeShowTextDark',
      'welcomeShowIconDark',
      'defaultToRead',
    });
    expect(storage.reads, hasLength(25));
    await Future.wait([
      shelf.update(),
      records.update(),
      locale.update(),
      eye.update(),
      welcome.update(),
    ]);
    expect(storage.writes, isEmpty);
  });

  test('书架原布尔、整数和分组名称编码保存并恢复', () async {
    await shelf.update(
      isGridView: true,
      gridColumns: 4,
      groupMode: GroupMode.byGroup,
      selectedGroupIndex: 2,
      openBookInfoByClickTitle: true,
    );
    expect(storage.values, {
      'bookshelf_layout': true,
      'bookshelf_grid_columns': 4,
      'bookshelf_group_mode': 'byGroup',
      'bookshelf_tab_position': 2,
      'openBookInfoByClickTitle': true,
    });
    expect(
      await AppBookshelfSettingsRepository(service).load(),
      const BookshelfSettings(
        isGridView: true,
        gridColumns: 4,
        groupMode: GroupMode.byGroup,
        selectedGroupIndex: 2,
        openBookInfoByClickTitle: true,
      ),
    );
  });

  test('记录排序整数和展示枚举名称沿用原编码', () async {
    await records.update(enableRecord: false);
    for (final (mode, raw) in [
      (ReadRecordSortMode.name, 0),
      (ReadRecordSortMode.readTime, 1),
      (ReadRecordSortMode.lastRead, 2),
    ]) {
      await records.update(sortMode: mode);
      expect(storage.values['readRecordSort'], raw);
    }
    for (final mode in ReadRecordDisplayMode.values) {
      await records.update(displayMode: mode);
      expect(storage.values['readRecordDisplayMode'], mode.name);
    }
    expect(
      await AppReadRecordSettingsRepository(service).load(),
      const ReadRecordSettings(
        enableRecord: false,
        sortMode: ReadRecordSortMode.lastRead,
        displayMode: ReadRecordDisplayMode.latest,
      ),
    );
  });

  test('语言按现有支持列表归一化，读取旧地区格式不重写', () async {
    storage.values['app_locale'] = 'zh_CN';
    expect((await locale.load()).locale, 'zh');
    expect(storage.values['app_locale'], 'zh_CN');
    await locale.update(locale: 'en-US');
    expect(storage.values['app_locale'], 'en');
    await locale.update(locale: 'ja');
    expect(locale.current.locale, 'system');
  });

  test('护眼六项原键保存与时段规则保持', () async {
    await eye.update(
      enabled: true,
      intensity: 65,
      autoNight: true,
      schedule: true,
      startTime: '21:30',
      endTime: '06:45',
    );
    expect(storage.values, {
      'eyeProtectionEnabled': true,
      'colorTemperature': 65,
      'eyeProtectionAutoNight': true,
      'eyeProtectionSchedule': true,
      'eyeProtectionStartTime': '21:30',
      'eyeProtectionEndTime': '06:45',
    });
    expect(
      await AppEyeProtectionSettingsRepository(service).load(),
      const EyeProtectionSettings(
        enabled: true,
        intensity: 65,
        autoNight: true,
        schedule: true,
        startTime: '21:30',
        endTime: '06:45',
      ),
    );
    expect(
      eye.current.isActiveAt(isDark: false, now: DateTime(2026, 10, 14, 23)),
      isTrue,
    );
  });

  test('欢迎样式与默认开读保留九项键，空图路径仍是空字符串', () async {
    await welcome.update(
      showTime: 700,
      customWelcome: true,
      imageDay: 'fixtures/day.png',
      imageNight: '',
      showText: false,
      showIcon: false,
      showTextDark: false,
      showIconDark: false,
      defaultToRead: true,
    );
    expect(storage.values, {
      'welcomeShowTime': 700,
      'customWelcome': true,
      'welcomeImagePath': 'fixtures/day.png',
      'welcomeImagePathDark': '',
      'welcomeShowText': false,
      'welcomeShowIcon': false,
      'welcomeShowTextDark': false,
      'welcomeShowIconDark': false,
      'defaultToRead': true,
    });
    expect(await AppWelcomeSettingsRepository(service).load(), welcome.current);
  });

  test('列数、护眼强度和欢迎时长保留现有限值', () async {
    await shelf.update(gridColumns: 9);
    await eye.update(intensity: -10);
    await welcome.update(showTime: 900);
    expect(storage.values['bookshelf_grid_columns'], 6);
    expect(storage.values['colorTemperature'], 0);
    expect(storage.values['welcomeShowTime'], 800);
  });

  for (final (name, save, current, initial, updated)
      in <(String, Future<void> Function(), Object Function(), Object, Object)>[
        (
          '书架',
          () => shelf.update(isGridView: true),
          () => shelf.current,
          const BookshelfSettings(),
          const BookshelfSettings(isGridView: true),
        ),
        (
          '记录',
          () => records.update(enableRecord: false),
          () => records.current,
          const ReadRecordSettings(),
          const ReadRecordSettings(enableRecord: false),
        ),
        (
          '语言',
          () => locale.update(locale: 'en'),
          () => locale.current,
          const LocaleSettings(),
          const LocaleSettings(locale: 'en'),
        ),
        (
          '护眼',
          () => eye.update(enabled: true),
          () => eye.current,
          const EyeProtectionSettings(),
          const EyeProtectionSettings(enabled: true),
        ),
        (
          '欢迎',
          () => welcome.update(customWelcome: true),
          () => welcome.current,
          const WelcomeSettings(),
          const WelcomeSettings(customWelcome: true),
        ),
      ]) {
    test('$name 保存失败回退，重试不被失败阻断', () async {
      storage.writeFailure = true;
      final saving = save();
      expect(current(), updated);
      await expectLater(saving, throwsStateError);
      expect(current(), initial);
      storage.writeFailure = false;
      await save();
      expect(current(), updated);
    });
  }

  test('各域恢复重读同一共享快照，已有状态消费者同步', () async {
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(container.dispose);
    container.read(bookshelfNotifierProvider);
    container.read(readRecordNotifierProvider);
    container.read(appLocaleProvider);
    container.read(eyeProtectionProvider);
    final subscription = container.listen(welcomeSettingsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(welcomeSettingsProvider.future);
    await Future<void>.delayed(Duration.zero);
    storage.values.addAll({
      'bookshelf_layout': true,
      'bookshelf_grid_columns': 5,
      'enableReadRecord': false,
      'readRecordDisplayMode': 'timeline',
      'app_locale': 'en',
      'eyeProtectionEnabled': true,
      'defaultToRead': true,
    });
    await Future.wait([
      shelf.reload(),
      records.reload(),
      locale.reload(),
      eye.reload(),
      welcome.reload(),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bookshelfNotifierProvider).isGridView, isTrue);
    expect(container.read(bookshelfNotifierProvider).gridColumns, 5);
    expect(container.read(readRecordNotifierProvider).enableRecord, isFalse);
    expect(
      container.read(readRecordNotifierProvider).displayMode,
      ReadRecordDisplayMode.timeline,
    );
    expect(container.read(appLocaleProvider), 'en');
    expect(container.read(eyeProtectionProvider).enabled, isTrue);
    expect(
      container.read(welcomeSettingsProvider).value!.defaultToRead,
      isTrue,
    );
  });
}
