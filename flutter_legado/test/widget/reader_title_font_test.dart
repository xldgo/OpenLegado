library;

import '../fixtures/routing_test_app.dart';

import '../fixtures/app_test_api.dart';

/// 共享标题字体选择、字体回退和设置导航；实际排版与绘制见标题分页测试。— Codex + UI

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/reader/presentation/font_screen.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';

import '../fixtures/reader_settings_repository.dart';

void main() {
  late AppReaderSettingsRepository repository;
  setUp(() => repository = createTestReaderSettingsRepository());
  group('共享标题字体选择', () {
    test('只写规范键，旧titleFont不参与读取或迁移', () async {
      SharedPreferences.setMockInitialValues({'titleFont': '旧字体'});
      expect((await repository.load()).titleFontFamily, '');
      await repository.update(titleFontFamily: 'KaiTi');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_title_font_family'), 'KaiTi');
      expect(prefs.getString('titleFont'), '旧字体');
    });

    test('标题字体从规范键恢复，清空后跟随正文', () async {
      SharedPreferences.setMockInitialValues({
        'reader_title_font_family': 'SimSun',
      });
      expect((await repository.load()).titleFontFamily, 'SimSun');
      await repository.update(titleFontFamily: '');
      expect(repository.current.titleFontFamily, '');
    });

    test('保存其他阅读设置不会覆盖刚选择的标题字体', () async {
      SharedPreferences.setMockInitialValues({});
      await repository.update(titleFontFamily: 'Georgia');
      await repository.updateScreen(keepScreenOnSeconds: 60);
      expect(repository.current.titleFontFamily, 'Georgia');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'reader_title_font_family',
        ),
        'Georgia',
      );
    });
  });

  group('effectiveTitleFontFamily 单源取值', () {
    test('titleFontFamily 非空优先于正文字体', () {
      const chrome = ReaderPageChromeConfig(titleFontFamily: 'KaiTi');
      expect(effectiveTitleFontFamily(chrome, 'SimSun'), 'KaiTi');
    });

    test('titleFontFamily 空值=跟随正文字体（null 正文=默认字体）', () {
      const chrome = ReaderPageChromeConfig();
      expect(effectiveTitleFontFamily(chrome, 'SimSun'), 'SimSun');
      expect(effectiveTitleFontFamily(chrome, null), isNull);
    });
  });

  group('PageChrome.titleFontFamily 与 layoutKey', () {
    test('titleFontFamily 并入 layoutKey（变化即触发重分页）', () {
      const base = ReaderPageChromeConfig();
      const a = ReaderPageChromeConfig(titleFontFamily: 'KaiTi');
      const b = ReaderPageChromeConfig(titleFontFamily: 'SimSun');
      expect(base.layoutKey, isNot(equals(a.layoutKey)));
      expect(a.layoutKey, isNot(equals(b.layoutKey)));
      expect(a.layoutKey.endsWith('_KaiTi'), isTrue);
    });

    test('fromSettings 透传 titleFontFamily', () {
      const cfg = ReaderPageLayoutSettings();
      expect(
        ReaderPageChromeConfig.fromSettings(
          cfg,
          titleFontFamily: 'KaiTi',
        ).titleFontFamily,
        'KaiTi',
      );
    });
  });

  group('Tt 面板标题字体行', () {
    testWidgets('默认显示「跟随正文」，点按跳转 FontScreen(target: title)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      String? capturedArgs;
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([...MockBookApi().overrides]),
          child: RoutingTestApp(
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.fonts) {
                capturedArgs = settings.arguments as String?;
                final target = capturedArgs ?? 'body';
                return MaterialPageRoute<void>(
                  builder: (_) => FontScreen(target: target),
                );
              }
              return MaterialPageRoute<void>(
                builder: (_) => ReaderFontPanel(titleOnly: true),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 空 titleFont → 行值显示「跟随正文」
      expect(find.text('跟随正文'), findsOneWidget);

      await tester.tap(find.text('标题字体'));
      await tester.pumpAndSettle();
      expect(capturedArgs, 'title', reason: '须以 arguments 传 title 目标');
      expect(find.byType(FontScreen), findsOneWidget);
      // FontScreen 标题目标页：标题与「当前标题字体」标识
      expect(find.text('当前标题字体：跟随正文'), findsOneWidget);
    });

    testWidgets('已选标题字体显示字体名（Custom_ 前缀剥离）', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_title_font_family': 'Custom_宋体',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([...MockBookApi().overrides]),
          child: RoutingTestApp(home: ReaderFontPanel(titleOnly: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('宋体'), findsOneWidget, reason: '行值应显示字体名（Custom_ 前缀剥离）');
      expect(find.text('跟随正文'), findsNothing);
    });
  });
}
