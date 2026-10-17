library;

import '../fixtures/app_test_api.dart';

/// 既有字体设置用例，适配完整设置页导航和简繁转换的新归属。

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_config_panel.dart';
import 'package:flutter_legado/src/features/reader/presentation/font_screen.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';

import '../fixtures/reader_settings_repository.dart';

void main() {
  group('阅读界面 · 字体设置', () {
    testWidgets('字体与排版入口打开字体控件，返回完整设置', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ReaderSettingsSheet(fullPage: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('字体与排版'), findsOneWidget);
      expect(find.text('字体'), findsNothing);

      await tester.tap(find.text('字体与排版'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('正文字体'), findsWidgets);
      expect(find.text('字体'), findsOneWidget);
      expect(find.text('字间距'), findsOneWidget);
      expect(find.text('首行缩进'), findsOneWidget);
      expect(find.text('标题字体'), findsNothing);
      expect(find.text('斜体'), findsOneWidget);
      expect(find.text('字重'), findsOneWidget);
      expect(find.text('简繁转换'), findsNothing);

      final context = tester.element(find.byType(ReaderFontPanel));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('字体'), findsNothing);
    });

    testWidgets('面板直测：字重/首行缩进持久化 + 简繁转换 + 字体跳转', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockApi = MockBookApi();
      final repository = createTestReaderSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([
            ...mockApi.overrides,
            readerSettingsRepositoryProvider.overrideWithValue(repository),
          ]),
          child: MaterialApp(
            // 「字体」跳转 AppRoutes.fonts：以桩路由承接，验证链路不丢失
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.fonts) {
                return MaterialPageRoute<void>(
                  builder: (_) => const FontScreen(),
                );
              }
              return MaterialPageRoute<void>(
                builder: (_) =>
                    SingleChildScrollView(child: const ReaderFontPanel()),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 面板控件清单
      expect(find.text('字体'), findsOneWidget);
      expect(find.text('字间距'), findsOneWidget);
      expect(find.text('简繁转换'), findsNothing);

      // ① 字重切「粗体」→ 共享排版仓储保存reader_text_bold=1
      await tester.tap(find.text('粗体').last);
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpAndSettle();
      expect(prefs.getInt('reader_text_bold'), 1);

      // ② 首行缩进 → 选「三字符」→ 持久化 paragraph_indent_chars=3
      // 保存统一的正文排版键。
      await tester.ensureVisible(find.text('首行缩进').last);
      await tester.tap(find.text('首行缩进').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('三字符').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(prefs.getInt('reader_paragraph_indent'), 3);

      // ④ 斜体开关（双基准补齐）→ 持久化 reader_adv_italic
      // 默认未保存时为false，此处验证开关可置真
      expect(repository.current.textLayout.italic, isFalse);
      await tester.ensureVisible(find.text('斜体').last);
      await tester.tap(find.text('斜体').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(prefs.getBool('reader_italic'), isTrue);

      // ⑤ 「字体」跳转字体管理路由（AppRoutes.fonts → FontScreen）
      await tester.ensureVisible(find.text('字体').last);
      await tester.tap(find.text('字体').last);
      await tester.pumpAndSettle();
      expect(find.text('字体管理'), findsWidgets);

      // 简繁转换移到内容分组，通过正文处理服务持久化。
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([
            ...mockApi.overrides,
            readerSettingsRepositoryProvider.overrideWithValue(repository),
          ]),
          child: MaterialApp(
            key: UniqueKey(),
            home: Scaffold(
              body: ReaderConfigPanel(section: ReaderConfigSection.content),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await mockApi.readingContentService.getChineseConvertType(), 0);
      await tester.tap(find.text('简→繁').last);
      await tester.pumpAndSettle();
      expect(await mockApi.readingContentService.getChineseConvertType(), 2);
    });
  });
}
