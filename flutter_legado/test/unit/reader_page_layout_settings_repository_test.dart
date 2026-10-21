import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';

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

  test('页面缺省及恢复入口一致，不读取旧键或日夜分桶', () async {
    storage.values.addAll({
      'reader_adv_margin_top': 99.0,
      'reader_layout_night_margin_left': 99.0,
      'titleSize': 9,
      'tipFooterLeft': 1,
      'doubleHorizontalPage': 3,
    });
    expect(
      (await repository.load()).pageLayout,
      const ReaderPageLayoutSettings(),
    );
    expect(
      storage.reads.toSet().intersection(storage.values.keys.toSet()),
      isEmpty,
    );
    expect(
      ReaderPageLayoutSettings.resetPaddingFor(PaddingRegion.body),
      const ReaderPagePadding(top: 6, bottom: 6, left: 16, right: 16),
    );
    expect(
      ReaderPageLayoutSettings.resetPaddingFor(PaddingRegion.header),
      const ReaderPagePadding(left: 16, right: 16),
    );
    expect(
      repository.current.pageLayout.bodyPadding,
      ReaderPageLayoutSettings.resetPaddingFor(PaddingRegion.body),
    );
    await repository.updatePageLayout();
    await repository.updateTitle();
    await repository.updatePageEdge(ReaderPageEdge.header);
    expect(storage.writes, isEmpty);
  });

  test('真实Preferences保存全部27项，新实例恢复且其他设置保持', () async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 23.0,
      'reader_letter_spacing': 0.24,
    });
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.load();
    await actual.updatePageLayout(
      top: 31,
      bottom: 32,
      left: 21,
      right: 22,
      doubleHorizontalPage: 2,
    );
    await actual.updateTitle(
      mode: 1,
      size: 3,
      topSpacing: 11,
      bottomSpacing: 12,
    );
    await actual.updatePageEdge(
      ReaderPageEdge.header,
      top: 1,
      bottom: 2,
      left: 18,
      right: 19,
      mode: 1,
      showLine: true,
      leftTip: 1,
      middleTip: 4,
      rightTip: 9,
    );
    await actual.updatePageEdge(
      ReaderPageEdge.footer,
      top: 7,
      bottom: 8,
      left: 20,
      right: 21,
      mode: 1,
      showLine: false,
      leftTip: 2,
      middleTip: 3,
      rightTip: 5,
    );
    final freshService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(freshService.dispose);
    final restored = await AppReaderSettingsRepository(freshService).load();
    expect(restored.fontSize, 23);
    expect(restored.textLayout.letterSpacing, 0.24);
    expect(
      restored.pageLayout,
      const ReaderPageLayoutSettings(
        bodyPadding: ReaderPagePadding(
          top: 31,
          bottom: 32,
          left: 21,
          right: 22,
        ),
        doubleHorizontalPage: 2,
        title: ReaderTitleSettings(
          mode: 1,
          size: 3,
          topSpacing: 11,
          bottomSpacing: 12,
        ),
        header: ReaderPageEdgeSettings(
          padding: ReaderPagePadding(top: 1, bottom: 2, left: 18, right: 19),
          mode: 1,
          showLine: true,
          leftTip: 1,
          middleTip: 4,
          rightTip: 9,
        ),
        footer: ReaderPageEdgeSettings(
          padding: ReaderPagePadding(top: 7, bottom: 8, left: 20, right: 21),
          mode: 1,
          showLine: false,
          leftTip: 2,
          middleTip: 3,
          rightTip: 5,
        ),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(29));
    expect(prefs.getDouble('reader_header_padding_left'), 18);
    expect(prefs.getInt('reader_title_size'), 3);
    expect(prefs.getInt('reader_footer_mode'), 1);
    expect(prefs.getBool('reader_footer_show_line'), isFalse);
  });

  test('页眉页脚模式从真实Preferences读取时按区域夹取上下界', () async {
    for (final (input, header, footer) in [
      (-5, 0, 0),
      (0, 0, 0),
      (1, 1, 1),
      (2, 2, 1),
      (9, 2, 1),
    ]) {
      SharedPreferences.setMockInitialValues({
        'reader_header_mode': input,
        'reader_footer_mode': input,
      });
      final actualService = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      addTearDown(actualService.dispose);
      final actual = AppReaderSettingsRepository(actualService);
      final layout = (await actual.load()).pageLayout;
      expect(layout.header.mode, header, reason: '页眉读取 $input');
      expect(layout.footer.mode, footer, reason: '页脚读取 $input');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reader_header_mode'), input);
      expect(prefs.getInt('reader_footer_mode'), input);
    }
  });

  test('页眉页脚模式写入真实Preferences后新实例保持独立范围', () async {
    for (final (input, header, footer) in [
      (-5, 0, 0),
      (0, 0, 0),
      (1, 1, 1),
      (2, 2, 1),
      (9, 2, 1),
    ]) {
      SharedPreferences.setMockInitialValues({});
      final actualService = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      addTearDown(actualService.dispose);
      final actual = AppReaderSettingsRepository(actualService);
      await actual.load();
      await actual.updatePageEdge(ReaderPageEdge.header, mode: input);
      await actual.updatePageEdge(ReaderPageEdge.footer, mode: input);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reader_header_mode'), header, reason: '页眉写入 $input');
      expect(prefs.getInt('reader_footer_mode'), footer, reason: '页脚写入 $input');
      final freshService = AppSettingsService(
        storages: {
          SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
        },
      );
      addTearDown(freshService.dispose);
      final restored = await AppReaderSettingsRepository(freshService).load();
      expect(restored.pageLayout.header.mode, header);
      expect(restored.pageLayout.footer.mode, footer);
    }
  });

  test('各区域只保存传入字段，显式零值不覆盖其他区域', () async {
    await repository.load();
    await repository.updatePageEdge(ReaderPageEdge.header, leftTip: 0, top: 12);
    await repository.updateTitle(size: 5);
    await repository.updatePageLayout(left: 0, doubleHorizontalPage: 1);
    await repository.updatePageEdge(ReaderPageEdge.footer, showLine: false);
    expect(repository.current.pageLayout.header.leftTip, 0);
    expect(repository.current.pageLayout.header.padding.top, 12);
    expect(repository.current.pageLayout.title.size, 5);
    expect(repository.current.pageLayout.bodyPadding.left, 0);
    expect(repository.current.pageLayout.bodyPadding.right, 16);
    expect(storage.writes.map((entry) => entry.$1).toSet(), {
      'reader_header_padding_top',
      'reader_header_tip_left',
      'reader_title_size',
      'reader_page_margin_left',
      'reader_double_horizontal_page',
      'reader_footer_show_line',
    });
  });

  test('范围沿用原值，边距dp与标题整数增量保持类型', () async {
    await repository.load();
    await repository.updatePageLayout(
      top: -2,
      left: 200,
      doubleHorizontalPage: 20,
    );
    await repository.updateTitle(
      mode: 8,
      size: 80,
      topSpacing: -1,
      bottomSpacing: 999,
    );
    await repository.updatePageEdge(
      ReaderPageEdge.header,
      top: 800,
      right: -1,
      mode: -1,
    );
    expect(repository.current.pageLayout.bodyPadding.top, 0);
    expect(repository.current.pageLayout.bodyPadding.left, 100);
    expect(repository.current.pageLayout.doubleHorizontalPage, 3);
    expect(
      repository.current.pageLayout.title,
      const ReaderTitleSettings(
        mode: 2,
        size: 20,
        topSpacing: 0,
        bottomSpacing: 100,
      ),
    );
    expect(repository.current.pageLayout.header.padding.top, 400);
    expect(repository.current.pageLayout.header.padding.right, 0);
    expect(storage.values['reader_page_margin_top'], isA<double>());
    expect(storage.values['reader_title_size'], isA<int>());
  });

  test('保存失败回退并传播，后续重试发布新快照', () async {
    await repository.load();
    final observed = <ReaderPageLayoutSettings>[];
    final sub = repository
        .watch()
        .map((settings) => settings.pageLayout)
        .listen(observed.add);
    addTearDown(sub.cancel);
    storage.writeFailure = true;
    await expectLater(
      repository.updatePageLayout(left: 25, right: 25),
      throwsStateError,
    );
    await expectLater(repository.updateTitle(size: 5), throwsStateError);
    await expectLater(
      repository.updatePageEdge(ReaderPageEdge.footer, leftTip: 3),
      throwsStateError,
    );
    expect(repository.current.pageLayout, const ReaderPageLayoutSettings());
    expect(storage.values, isEmpty);
    storage.writeFailure = false;
    await repository.updateTitle(size: 5);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.title.size, 5);
    expect(storage.values['reader_title_size'], 5);
  });

  test('其他阅读设置不覆盖页面设置，也不再写旧页面键', () async {
    await repository.updatePageLayout(top: 31, left: 21);
    await repository.updateTitle(size: 3);
    await repository.updatePageEdge(ReaderPageEdge.footer, leftTip: 3);
    await repository.updateScreen(keepScreenOnSeconds: 60);
    expect(repository.current.pageLayout.bodyPadding.top, 31);
    expect(repository.current.pageLayout.title.size, 3);
    expect(repository.current.pageLayout.footer.leftTip, 3);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'reader_adv_margin_top',
      'reader_adv_header_padding_top',
      'reader_adv_footer_padding_left',
      'titleMode',
      'titleSize',
      'tipHeaderLeft',
      'tipFooterLeft',
      'showFooterLine',
      'doubleHorizontalPage',
      'reader_unified_layout_v1',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(storage.values['reader_keep_screen_on_seconds'], 60);
    expect(prefs.containsKey('keep_light'), isFalse);
  });

  test('外部恢复重读所有区域，失败保留有效快照', () async {
    await repository.load();
    storage.values.addAll({
      'reader_page_margin_top': 31.0,
      'reader_header_tip_left': 1,
      'reader_footer_show_line': false,
      'reader_title_size': 5,
      'reader_double_horizontal_page': 2,
    });
    storage.readFailure = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.pageLayout, const ReaderPageLayoutSettings());
    storage.readFailure = false;
    await repository.reload();
    expect(repository.current.pageLayout.bodyPadding.top, 31);
    expect(repository.current.pageLayout.header.leftTip, 1);
    expect(repository.current.pageLayout.footer.showLine, isFalse);
    expect(repository.current.pageLayout.title.size, 5);
    expect(repository.current.pageLayout.doubleHorizontalPage, 2);
  });

  test('页壳从同源分组投影，保留系统栏与标题字体外部输入及既有页脚规则', () {
    const layout = ReaderPageLayoutSettings(
      header: ReaderPageEdgeSettings(
        mode: 1,
        padding: ReaderPagePadding(top: 5, left: 12),
        leftTip: 7,
      ),
      title: ReaderTitleSettings(
        mode: 1,
        size: 3,
        topSpacing: 10,
        bottomSpacing: 11,
      ),
    );
    final chrome = ReaderPageChromeConfig.fromSettings(
      layout,
      hideStatusBar: true,
      titleFontFamily: 'KaiTi',
    );
    expect(chrome.headerMode, 1);
    expect(chrome.headerPaddingTop, 5);
    expect(chrome.tipHeaderLeft, 7);
    expect(chrome.titleMode, 1);
    expect(chrome.titleSize, 3);
    expect(chrome.titleTopSpacing, 10);
    expect(chrome.titleBottomSpacing, 11);
    expect(chrome.hideStatusBar, isTrue);
    expect(chrome.titleFontFamily, 'KaiTi');
    expect(chrome.showPageHeader, isTrue);
    for (final (mode, visible) in [(0, true), (1, false)]) {
      final snapshot = ReaderPageChromeConfig.fromSettings(
        ReaderPageLayoutSettings(footer: ReaderPageEdgeSettings(mode: mode)),
      );
      expect(snapshot.showPageFooter, visible);
    }
    // 仅锁定页壳既有规则，2不是可保存的页脚选项。— footer_semantics + UI
    expect(const ReaderPageChromeConfig(footerMode: 2).showPageFooter, isTrue);
    for (final hideStatusBar in [false, true]) {
      for (final (mode, visible) in [
        (0, hideStatusBar),
        (1, true),
        (2, false),
      ]) {
        final snapshot = ReaderPageChromeConfig.fromSettings(
          ReaderPageLayoutSettings(header: ReaderPageEdgeSettings(mode: mode)),
          hideStatusBar: hideStatusBar,
        );
        expect(snapshot.showPageHeader, visible);
      }
    }
  });
}
