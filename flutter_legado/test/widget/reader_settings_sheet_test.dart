/// 既有阅读设置入口用例，适配快捷面板进入完整分组页面的导航。
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/widgets/reader/reader_settings_sheet.dart';

void main() {
  testWidgets('阅读快捷面板进入完整设置，再进入翻页与操作', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
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

    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('背景'), findsOneWidget);
    expect(find.text('翻页动画'), findsOneWidget);

    await tester.ensureVisible(find.text('全部阅读设置'));
    await tester.tap(find.text('全部阅读设置'));
    await tester.pumpAndSettle();

    expect(find.text('阅读界面'), findsOneWidget);
    for (final title in [
      '字体与排版',
      '背景与配色',
      '翻页与操作',
      '标题与信息',
      '页面与屏幕',
      '内容与工具栏',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('翻页与操作'));
    await tester.pumpAndSettle();
    expect(find.text('自动翻页'), findsWidgets);
    expect(find.text('点击区域'), findsOneWidget);
  });
}
