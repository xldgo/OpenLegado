import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_interaction_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  Future<void> initialize(
    WidgetTester tester, {
    ReaderSettingsCategory category = ReaderSettingsCategory.interaction,
  }) async {
    SharedPreferences.setMockInitialValues({});
    if (category == ReaderSettingsCategory.screen) {
      const channel = MethodChannel('github.com/aaassseee/screen_brightness');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(code: 'unsupported');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
    }
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await container.read(readerSettingsRepositoryProvider).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderSettingsSheet(fullPage: true, category: category),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.writes.clear();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String title) => tester
      .widget<Switch>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is SettingSwitchRow && w.title == title,
          ),
          matching: find.byType(Switch),
        ),
      )
      .value;

  testWidgets('自动翻页启停、间隔和方向同源，120秒可直接显示', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    await tap(tester, find.text('启用自动翻页'));
    expect(repository.current.autoPageTurn.enabled, isTrue);
    expect(switchValue(tester, '启用自动翻页'), isTrue);
    await repository.updateAutoPageTurn(intervalSeconds: 120);
    await tester.pumpAndSettle();
    expect(find.text('间隔 120 秒'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byWidgetPredicate((w) => w is Slider && w.max == 120),
    );
    expect(slider.value, 120);
    slider.onChanged!(35);
    await tester.pumpAndSettle();
    expect(repository.current.autoPageTurn.intervalSeconds, 35);
    await tap(tester, find.text('上一章').hitTestable());
    expect(repository.current.autoPageTurn.forward, isFalse);
    await tap(tester, find.text('启用自动翻页'));
    expect(repository.current.autoPageTurn.enabled, isFalse);
    expect(find.text('间隔 35 秒'), findsNothing);
    expect(repository.current.autoPageTurn.intervalSeconds, 35);
    expect(storage.writes.map((e) => e.$1).toSet(), {
      'reader_auto_page_turn_enabled',
      'reader_auto_page_turn_interval_seconds',
      'reader_auto_page_turn_forward',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('九宫格独立修改、失败回退和恢复默认不覆盖其他操作', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    await repository.updateInteraction(selectText: false);
    await tester.pumpAndSettle();
    storage.writeFailure = true;
    await tap(tester, find.byTooltip(RegExp('^左上：')));
    await tap(tester, find.text('打开目录').hitTestable());
    expect(find.text('翻页与操作设置保存失败，请重试'), findsOneWidget);
    expect(repository.current.interaction.tapActions[0], TapAction.prevPage);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip(RegExp('^左上：')));
    await tap(tester, find.text('打开目录').hitTestable());
    expect(repository.current.interaction.tapActions[0], TapAction.openCatalog);
    expect(repository.current.interaction.tapActions[1], TapAction.prevPage);
    expect(
      (storage.values['reader_tap_actions'] as SettingsStringList).values.first,
      'openCatalog',
    );
    await tap(tester, find.byTooltip('恢复默认点击区域'));
    expect(
      repository.current.interaction.tapActions,
      ReaderInteractionSettings.defaultTapActions,
    );
    expect(repository.current.interaction.selectText, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作开关连续修改、失败回退及外部重读保持同源', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    await tap(tester, find.text('滚动翻页无动画'));
    expect(repository.current.interaction.noAnimScrollPage, isTrue);
    storage.writeFailure = true;
    await tap(tester, find.text('鼠标滚轮翻页'));
    expect(find.text('翻页与操作设置保存失败，请重试'), findsOneWidget);
    expect(switchValue(tester, '鼠标滚轮翻页'), isTrue);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('鼠标滚轮翻页'));
    expect(repository.current.interaction.mouseWheelPage, isFalse);
    expect(repository.current.interaction.noAnimScrollPage, isTrue);
    await tap(tester, find.text('朗读时音量键翻页'));
    expect(repository.current.interaction.volumeKeyPageOnPlay, isTrue);
    await tap(tester, find.text('音量键翻页'));
    expect(repository.current.interaction.volumeKeyPage, isFalse);
    expect(find.text('朗读时音量键翻页'), findsNothing);
    storage.values.addAll({
      'reader_volume_key_page': true,
      'reader_no_anim_scroll_page': false,
    });
    await repository.reload();
    await tester.pumpAndSettle();
    expect(switchValue(tester, '音量键翻页'), isTrue);
    expect(switchValue(tester, '朗读时音量键翻页'), isTrue);
    expect(switchValue(tester, '滚动翻页无动画'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自动翻页启用保存失败回退，可重试且不改间隔方向', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    await repository.updateAutoPageTurn(intervalSeconds: 35, forward: false);
    await tester.pumpAndSettle();
    storage.writeFailure = true;
    await tap(tester, find.text('启用自动翻页'));
    expect(find.text('翻页与操作设置保存失败，请重试'), findsOneWidget);
    expect(switchValue(tester, '启用自动翻页'), isFalse);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('启用自动翻页'));
    expect(find.text('间隔 35 秒'), findsOneWidget);
    expect(repository.current.autoPageTurn.forward, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择开关和两个阈值输入保存生效，失败回退后可重试', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    await tap(tester, find.text('长按选择文本'));
    expect(repository.current.interaction.selectText, isFalse);
    await tap(tester, find.text('滑动翻页阈值'));
    await tester.enterText(find.byType(TextField), '45');
    await tap(tester, find.text('确定').hitTestable());
    expect(repository.current.interaction.pageTouchSlop, 45);
    storage.writeFailure = true;
    await tap(tester, find.text('边缘点击阈值'));
    await tester.enterText(find.byType(TextField), '30');
    await tap(tester, find.text('确定').hitTestable());
    expect(find.text('翻页与操作设置保存失败，请重试'), findsOneWidget);
    expect(repository.current.interaction.pageTouchClick, 0);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('边缘点击阈值'));
    await tester.enterText(find.byType(TextField), '30');
    await tap(tester, find.text('确定').hitTestable());
    expect(repository.current.interaction.pageTouchClick, 30);
    expect(repository.current.interaction.pageTouchSlop, 45);
    expect(repository.current.interaction.selectText, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('进度条行为保存失败回退，成功后可从外部恢复重读', (tester) async {
    await initialize(tester, category: ReaderSettingsCategory.screen);
    final repository = container.read(readerSettingsRepositoryProvider);
    storage.writeFailure = true;
    await tap(tester, find.text('进度条行为'));
    await tap(tester, find.text('调章节').hitTestable());
    expect(find.text('翻页与操作设置保存失败，请重试'), findsOneWidget);
    expect(repository.current.interaction.progressBarBehavior, 'page');
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('进度条行为'));
    await tap(tester, find.text('调章节').hitTestable());
    expect(repository.current.interaction.progressBarBehavior, 'chapter');
    storage.values['reader_progress_bar_behavior'] = 'page';
    await repository.reload();
    await tester.pumpAndSettle();
    final row = tester.widget<SettingMenuRow<String>>(
      find.byWidgetPredicate(
        (w) => w is SettingMenuRow<String> && w.title == '进度条行为',
      ),
    );
    expect(row.value, 'page');
    expect(tester.takeException(), isNull);
  });
}
