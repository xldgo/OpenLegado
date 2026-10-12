/// 既有字体设置用例，适配完整设置页导航和简繁转换的新归属。
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/screens/reader_config_panel.dart';
import 'package:flutter_legado/src/screens/font_screen.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_settings_sheet.dart';

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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookApiProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            // 「字体」跳转 AppRoutes.fonts：以桩路由承接，验证链路不丢失
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.fonts) {
                return MaterialPageRoute<void>(
                  builder: (_) => const FontScreen(),
                );
              }
              return MaterialPageRoute<void>(
                builder: (_) => SingleChildScrollView(
                  child: ReaderFontPanel(
                    config: ReaderAdvancedConfig(),
                    // 模拟主 Sheet _commitAdv：变更经 save() 持久化
                    onChanged: (cfg) => unawaited(cfg.save()),
                  ),
                ),
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

      // ① 字重切「粗体」→ 持久化 textBold=1（既有字段链路）
      await tester.tap(find.text('粗体').last);
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('textBold'), 1);

      // ② 首行缩进 → 选「三字符」→ 持久化 paragraph_indent_chars=3
      // （save() 同时写日夜桶键 reader_layout_day_* 与旧键 reader_adv_*）
      await tester.ensureVisible(find.text('首行缩进').last);
      await tester.tap(find.text('首行缩进').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('三字符').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(prefs.getInt('reader_layout_day_paragraph_indent_chars'), 3);
      expect(prefs.getInt('reader_adv_paragraph_indent_chars'), 3);

      // ④ 斜体开关（双基准补齐）→ 持久化 reader_adv_italic
      // 前序 save() 已写过该键（默认 false），此处验证开关可置真
      expect(prefs.getBool('reader_adv_italic'), isFalse);
      await tester.ensureVisible(find.text('斜体').last);
      await tester.tap(find.text('斜体').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(prefs.getBool('reader_adv_italic'), isTrue);

      // ⑤ 「字体」跳转字体管理路由（AppRoutes.fonts → FontScreen）
      await tester.ensureVisible(find.text('字体').last);
      await tester.tap(find.text('字体').last);
      await tester.pumpAndSettle();
      expect(find.text('字体管理'), findsWidgets);

      // 简繁转换移到内容分组，仍沿用原 BookApi 持久化调用。
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookApiProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            key: UniqueKey(),
            home: Scaffold(
              body: ReaderConfigPanel(
                config: ReaderAdvancedConfig(),
                section: ReaderConfigSection.content,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await mockApi.getChineseConvertType(), 0);
      await tester.tap(find.text('简→繁').last);
      await tester.pumpAndSettle();
      expect(await mockApi.getChineseConvertType(), 2);
    });
  });
}
