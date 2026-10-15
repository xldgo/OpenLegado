import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';
import 'package:flutter_legado/src/models/reader_advanced_config.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_settings_provider.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_padding_config_sheet.dart';
import 'package:flutter_legado/src/widgets/reader/reader_tip_config_sheet.dart';
import 'package:flutter_legado/src/widgets/reader/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: child is ReaderSettingsSheet
                ? child
                : SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> initialize(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        bookApiProvider.overrideWithValue(MockBookApi()),
      ],
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await container.read(readerSettingsRepositoryProvider).load();
    await show(tester, child);
    storage.writes.clear();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  SettingStepperRow row(WidgetTester tester, String title) =>
      tester.widget<SettingStepperRow>(
        find.byWidgetPredicate(
          (w) => w is SettingStepperRow && w.title == title,
        ),
      );

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

  testWidgets('正文边距左右联动、分开修改和恢复默认不覆盖其他区域', (tester) async {
    await initialize(
      tester,
      const ReaderPaddingConfigSheet(
        embedded: true,
        region: PaddingRegion.body,
      ),
    );
    expect(row(tester, '上边距').value, 24);
    expect(row(tester, '左边距').value, 20);
    await tap(tester, find.byTooltip('增大左边距'));
    expect(row(tester, '左边距').value, 21);
    expect(row(tester, '右边距').value, 21);
    await tap(tester, find.text('左右边距联动'));
    await tap(tester, find.byTooltip('增大左边距'));
    expect(row(tester, '左边距').value, 22);
    expect(row(tester, '右边距').value, 21);
    await tap(tester, find.text('恢复默认边距'));
    expect(row(tester, '上边距').value, 6);
    expect(row(tester, '下边距').value, 6);
    expect(row(tester, '左边距').value, 16);
    expect(row(tester, '右边距').value, 16);
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .pageLayout
          .header
          .padding
          .left,
      16,
    );
    expect(
      storage.writes.map((e) => e.$1),
      everyElement(startsWith('reader_page_margin_')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('边距失败回退并允许重试，外部恢复同步步进值', (tester) async {
    await initialize(
      tester,
      const ReaderPaddingConfigSheet(
        embedded: true,
        region: PaddingRegion.body,
      ),
    );
    storage.writeFailure = true;
    await tap(tester, find.byTooltip('增大上边距'));
    expect(find.text('页面布局保存失败，请重试'), findsOneWidget);
    expect(row(tester, '上边距').value, 24);
    expect(storage.values.containsKey('reader_page_margin_top'), isFalse);
    storage.writeFailure = false;
    await tap(tester, find.byTooltip('增大上边距'));
    expect(storage.values['reader_page_margin_top'], 25.0);
    storage.values['reader_page_margin_top'] = 31.0;
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(row(tester, '上边距').value, 31);
    expect(tester.takeException(), isNull);
  });

  testWidgets('章节标题保存失败回退，重试与外部恢复更新控件', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.title,
      ),
    );
    storage.writeFailure = true;
    await tap(tester, find.byTooltip('增大标题字号增量'));
    expect(find.text('页面布局保存失败，请重试'), findsOneWidget);
    expect(row(tester, '标题字号增量').value, 0);
    storage.writeFailure = false;
    await tap(tester, find.byTooltip('增大标题字号增量'));
    await tap(tester, find.byTooltip('增大标题上间距'));
    expect(storage.values['reader_title_size'], 1);
    expect(storage.values['reader_title_top_spacing'], 1);
    storage.values.addAll({
      'reader_title_size': 3,
      'reader_title_bottom_spacing': 9,
    });
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(row(tester, '标题字号增量').value, 3);
    expect(row(tester, '标题下间距').value, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页眉提示与分隔线保存，页脚保持独立并反馈失败', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.header,
      ),
    );
    await tap(tester, find.text('左侧提示'));
    await tap(tester, find.text('书名').hitTestable());
    await tap(tester, find.text('显示分隔线'));
    await tap(tester, find.byTooltip('增大上边距'));
    expect(storage.values['reader_header_tip_left'], 7);
    expect(storage.values['reader_header_show_line'], isTrue);
    expect(storage.values['reader_header_padding_top'], 1.0);
    await show(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.footer,
      ),
    );
    storage.writeFailure = true;
    await tap(tester, find.text('显示分隔线'));
    expect(find.text('页面布局保存失败，请重试'), findsOneWidget);
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .pageLayout
          .footer
          .showLine,
      isTrue,
    );
    storage.writeFailure = false;
    // 页脚按钮在屏幕底部，等待失败提示消失后再点击重试。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('显示分隔线'));
    expect(storage.values['reader_footer_show_line'], isFalse);
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .pageLayout
          .header
          .showLine,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('静态提示弹层连续切换状态条，控件与回调保留前次修改', (tester) async {
    final initial = ReaderAdvancedConfig(showProgress: true);
    final updates = <ReaderAdvancedConfig>[];
    await initialize(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => unawaited(
            ReaderTipConfigSheet.show(
              context,
              statusConfig: initial,
              onStatusChanged: updates.add,
            ),
          ),
          child: const Text('打开提示设置'),
        ),
      ),
    );
    await tap(tester, find.text('打开提示设置'));
    expect(switchValue(tester, '显示时间'), isFalse);
    expect(switchValue(tester, '显示电量'), isFalse);
    await tap(tester, find.text('显示时间'));
    expect(updates, hasLength(1));
    expect(updates.first.showTime, isTrue);
    expect(updates.first.showBattery, isFalse);
    expect(updates.first.showProgress, isTrue);
    final timeAfterFirstChange = switchValue(tester, '显示时间');
    await tap(tester, find.text('显示电量'));
    expect(updates, hasLength(2));
    expect(updates.last.showTime, isTrue);
    expect(updates.last.showBattery, isTrue);
    expect(updates.last.showProgress, isTrue);
    expect(updates.first.showBattery, isFalse);
    expect(timeAfterFirstChange, isTrue);
    expect(switchValue(tester, '显示时间'), isTrue);
    expect(switchValue(tester, '显示电量'), isTrue);
    expect(initial.showTime, isFalse);
    expect(initial.showBattery, isFalse);
    expect(storage.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('状态条接收父级新配置后继续操作保留新配置', (tester) async {
    await initialize(
      tester,
      ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.statusBar,
        statusConfig: ReaderAdvancedConfig(),
      ),
    );
    await tap(tester, find.text('显示时间'));
    expect(switchValue(tester, '显示时间'), isTrue);
    await show(
      tester,
      ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.statusBar,
        statusConfig: ReaderAdvancedConfig(showChapterName: true),
      ),
    );
    expect(switchValue(tester, '显示时间'), isFalse);
    expect(switchValue(tester, '显示章节名'), isTrue);
    await tap(tester, find.text('显示电量'));
    expect(switchValue(tester, '显示电量'), isTrue);
    expect(switchValue(tester, '显示章节名'), isTrue);
    expect(container.read(readerAdvConfigProvider)!.showTime, isFalse);
    expect(container.read(readerAdvConfigProvider)!.showBattery, isTrue);
    expect(container.read(readerAdvConfigProvider)!.showChapterName, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整页面双页与状态条连续修改分开保存，不覆盖已有页面选择', (tester) async {
    await initialize(
      tester,
      const ReaderSettingsSheet(
        fullPage: true,
        category: ReaderSettingsCategory.layout,
      ),
    );
    await tap(tester, find.text('平板/横屏双页'));
    await tap(tester, find.text('横屏双页').hitTestable());
    expect(storage.values['reader_double_horizontal_page'], 2);
    final before = container
        .read(readerSettingsRepositoryProvider)
        .current
        .pageLayout;
    await show(
      tester,
      ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.statusBar,
        statusConfig: ReaderAdvancedConfig(),
      ),
    );
    await tap(tester, find.text('显示时间'));
    expect(container.read(readerAdvConfigProvider)!.showTime, isTrue);
    final timeAfterFirstChange = switchValue(tester, '显示时间');
    await tap(tester, find.text('显示电量'));
    expect(container.read(readerAdvConfigProvider)!.showTime, isTrue);
    expect(container.read(readerAdvConfigProvider)!.showBattery, isTrue);
    expect(timeAfterFirstChange, isTrue);
    expect(switchValue(tester, '显示时间'), isTrue);
    expect(switchValue(tester, '显示电量'), isTrue);
    expect(
      container.read(readerSettingsRepositoryProvider).current.pageLayout,
      before,
    );
    expect(
      storage.writes.map((e) => e.$1).where((key) => key.startsWith('reader_')),
      ['reader_double_horizontal_page'],
    );
    expect(tester.takeException(), isNull);
  });
}
