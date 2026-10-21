import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_padding_config_sheet.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_tip_config_sheet.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
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

  SettingMenuRow<int> modeRow(WidgetTester tester) =>
      tester.widget<SettingMenuRow<int>>(
        find.byWidgetPredicate(
          (w) => w is SettingMenuRow<int> && w.title == '显示模式',
        ),
      );

  testWidgets('正文边距左右联动、分开修改和恢复默认不覆盖其他区域', (tester) async {
    await initialize(
      tester,
      const ReaderPaddingConfigSheet(
        embedded: true,
        region: PaddingRegion.body,
      ),
    );
    expect(row(tester, '上边距').value, 6);
    expect(row(tester, '左边距').value, 16);
    await tap(tester, find.byTooltip('增大左边距'));
    expect(row(tester, '左边距').value, 17);
    expect(row(tester, '右边距').value, 17);
    await tap(tester, find.text('左右边距联动'));
    await tap(tester, find.byTooltip('增大左边距'));
    expect(row(tester, '左边距').value, 18);
    expect(row(tester, '右边距').value, 17);
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
    expect(row(tester, '上边距').value, 6);
    expect(storage.values.containsKey('reader_page_margin_top'), isFalse);
    storage.writeFailure = false;
    await tap(tester, find.byTooltip('增大上边距'));
    expect(storage.values['reader_page_margin_top'], 7.0);
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
    expect(row(tester, '标题字号增量').value, 4);
    storage.writeFailure = false;
    await tap(tester, find.byTooltip('增大标题字号增量'));
    await tap(tester, find.byTooltip('增大标题上间距'));
    expect(storage.values['reader_title_size'], 5);
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

  testWidgets('标题独立字重、行距与绝对字号通过设置控件保存', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.title,
      ),
    );
    expect(row(tester, '标题字重').value, 500);
    await tap(tester, find.byTooltip('增大标题字重'));
    expect(storage.values['reader_title_font_weight'], 600);
    await tap(tester, find.text('标题字号相对正文'));
    expect(row(tester, '标题字号').value, 4);
    expect(storage.values['reader_title_size_relative'], false);
    await tap(tester, find.byTooltip('增大标题字号'));
    expect(storage.values['reader_title_size'], 5);
    final slider = find.descendant(
      of: find
          .ancestor(of: find.text('标题行距'), matching: find.byType(Row))
          .first,
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(storage.values['reader_title_line_height'], isA<double>());
    expect(storage.values['reader_title_line_height'], isNot(1.2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题标记分段通过公共sheet保存，重新进入仍可编辑', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.title,
      ),
    );
    await tap(tester, find.text('标题分段'));
    await tap(tester, find.text('按标记').hitTestable());
    expect(storage.values['reader_title_segment_type'], 2);
    await tap(tester, find.text('分段规则'));
    await tester.enterText(find.byType(TextField), '章,节');
    await tap(tester, find.text('保存'));
    expect(storage.values['reader_title_segment_delimiter'], '章,节');
    await tap(tester, find.text('分段规则'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '章,节',
    );
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
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

  testWidgets('页脚模式仅有显示和隐藏，隐藏保存1并收起配置项，显示后恢复', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.footer,
      ),
    );
    final headerBefore = container
        .read(readerSettingsRepositoryProvider)
        .current
        .pageLayout
        .header;
    expect(modeRow(tester).options, {0: '显示', 1: '隐藏'});
    expect(modeRow(tester).value, 0);
    expect(find.text('左侧提示'), findsOneWidget);
    await tap(tester, find.text('显示模式'));
    expect(find.text('状态栏显示时隐藏'), findsNothing);
    expect(find.text('隐藏').hitTestable(), findsOneWidget);
    await tap(tester, find.text('隐藏').hitTestable());
    expect(storage.values['reader_footer_mode'], 1);
    expect(modeRow(tester).value, 1);
    for (final label in ['左侧提示', '中间提示', '右侧提示', '显示分隔线']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.byType(ReaderPaddingConfigSheet), findsNothing);
    await tap(tester, find.text('显示模式'));
    await tap(tester, find.text('显示').hitTestable());
    expect(storage.values['reader_footer_mode'], 0);
    expect(modeRow(tester).value, 0);
    for (final label in ['左侧提示', '中间提示', '右侧提示', '显示分隔线']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(ReaderPaddingConfigSheet), findsOneWidget);
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .pageLayout
          .header,
      headerBefore,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('页脚模式保存失败回退显示并反馈，重试隐藏后收起配置项', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.footer,
      ),
    );
    storage.writeFailure = true;
    await tap(tester, find.text('显示模式'));
    await tap(tester, find.text('隐藏').hitTestable());
    expect(find.text('页面布局保存失败，请重试'), findsOneWidget);
    expect(modeRow(tester).value, 0);
    expect(find.text('左侧提示'), findsOneWidget);
    expect(storage.values.containsKey('reader_footer_mode'), isFalse);
    expect(storage.writes.where((entry) => entry.$1 == 'reader_footer_mode'), [
      ('reader_footer_mode', 1),
    ]);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('显示模式'));
    await tap(tester, find.text('隐藏').hitTestable());
    expect(storage.values['reader_footer_mode'], 1);
    expect(modeRow(tester).value, 1);
    expect(find.text('左侧提示'), findsNothing);
    expect(find.byType(ReaderPaddingConfigSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页眉保留状态栏联动、显示和隐藏三档，页脚设置独立', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.header,
      ),
    );
    final repository = container.read(readerSettingsRepositoryProvider);
    await repository.updatePageEdge(ReaderPageEdge.footer, mode: 1);
    await tester.pumpAndSettle();
    expect(modeRow(tester).options, {0: '状态栏显示时隐藏', 1: '显示', 2: '隐藏'});
    expect(modeRow(tester).value, 0);
    for (final (label, mode, visible) in [
      ('显示', 1, true),
      ('隐藏', 2, false),
      ('状态栏显示时隐藏', 0, true),
    ]) {
      await tap(tester, find.text('显示模式'));
      await tap(tester, find.text(label).hitTestable());
      expect(storage.values['reader_header_mode'], mode);
      expect(modeRow(tester).value, mode);
      expect(find.text('左侧提示'), visible ? findsOneWidget : findsNothing);
      expect(
        find.byType(ReaderPaddingConfigSheet),
        visible ? findsOneWidget : findsNothing,
      );
      expect(repository.current.pageLayout.footer.mode, 1);
      expect(storage.values['reader_footer_mode'], 1);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('页眉选择书名后清空页脚原槽，两个配置页立即同源刷新', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.header,
      ),
    );
    await tap(tester, find.text('左侧提示'));
    await tap(tester, find.text('书名').hitTestable());
    final repository = container.read(readerSettingsRepositoryProvider);
    expect(repository.current.pageLayout.header.leftTip, 7);
    expect(repository.current.pageLayout.footer.leftTip, 0);
    await show(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.footer,
      ),
    );
    final row = tester.widget<SettingMenuRow<int>>(
      find.byWidgetPredicate(
        (w) => w is SettingMenuRow<int> && w.title == '左侧提示',
      ),
    );
    expect(row.value, 0);
    await tap(tester, find.text('左侧提示'));
    await tap(tester, find.text('书名').hitTestable());
    expect(repository.current.pageLayout.header.leftTip, 0);
    expect(repository.current.pageLayout.footer.leftTip, 7);
    await show(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.header,
      ),
    );
    final moved = tester.widget<SettingMenuRow<int>>(
      find.byWidgetPredicate(
        (w) => w is SettingMenuRow<int> && w.title == '左侧提示',
      ),
    );
    expect(moved.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('提示移动保存失败保留原配置，重试才清空原槽', (tester) async {
    await initialize(
      tester,
      const ReaderTipConfigSheet(
        embedded: true,
        section: ReaderTipSection.header,
      ),
    );
    storage.writeFailure = true;
    await tap(tester, find.text('右侧提示'));
    await tap(tester, find.text('书名').hitTestable());
    final repository = container.read(readerSettingsRepositoryProvider);
    expect(find.text('页面布局保存失败，请重试'), findsOneWidget);
    expect(repository.current.pageLayout.header.rightTip, 3);
    expect(repository.current.pageLayout.footer.leftTip, 7);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('右侧提示'));
    await tap(tester, find.text('书名').hitTestable());
    expect(repository.current.pageLayout.header.rightTip, 7);
    expect(repository.current.pageLayout.footer.leftTip, 0);
    expect(tester.takeException(), isNull);
  });
}
