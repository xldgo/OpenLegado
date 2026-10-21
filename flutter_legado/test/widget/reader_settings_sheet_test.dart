library;

import '../fixtures/app_test_api.dart';

/// 既有阅读设置入口用例，适配快捷面板进入完整分组页面的导航。

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/providers/book_open_motion_provider.dart';

void main() {
  testWidgets('阅读快捷面板进入完整设置，再进入翻页与操作', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const brightnessChannel = MethodChannel(
      'github.com/aaassseee/screen_brightness',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // 桌面测试不具备亮度插件，明确返回不支持，避免等待真实平台调用。
    messenger.setMockMethodCallHandler(brightnessChannel, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(brightnessChannel, null),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...MockBookApi().overrides]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ReaderSettingsSheet.show(context),
                child: const Text('打开阅读设置'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开阅读设置'));
    await tester.pumpAndSettle();

    expect(find.text('阅读设置'), findsNothing);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('背景'), findsOneWidget);
    expect(find.text('翻页动画'), findsOneWidget);
    await tester.ensureVisible(find.text('开书动画 A/B（临时）'));
    await tester.tap(find.text('开书动画 A/B（临时）'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxMenuButton, BookOpenMotion.top.label),
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(ReaderSettingsSheet)),
    );
    expect(scope.read(bookOpenMotionProvider), BookOpenMotion.top);

    await tester.ensureVisible(find.text('全部阅读设置'));
    await tester.tap(find.text('全部阅读设置'));
    await tester.pumpAndSettle();

    expect(find.text('阅读界面'), findsOneWidget);
    for (final title in ['字体与排版', '背景与配色', '翻页与操作', '页面布局', '屏幕与工具栏', '内容处理']) {
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('翻页与操作'));
    await tester.pumpAndSettle();
    expect(find.text('自动翻页'), findsWidgets);
    expect(find.text('点击区域'), findsOneWidget);
    expect(scope.read(bookOpenMotionProvider), BookOpenMotion.top);
  });
}
