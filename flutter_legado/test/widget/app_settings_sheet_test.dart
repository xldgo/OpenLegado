import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/app_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/app_settings_form.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(900, 480)]) {
    testWidgets('设置 Sheet 在 $size 下键盘避让、局部主题、固定操作和长表单可用', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final local = AppTheme.dark.copyWith(
        colorScheme: AppTheme.dark.colorScheme.copyWith(
          primary: const Color(0xff123456),
        ),
      );
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Theme(
              data: local,
              child: Builder(
                builder: (c) => TextButton(
                  onPressed: () async {
                    result = await AppBottomSheet.showContent<String>(
                      context: c,
                      showDragHandle: true,
                      builder: (s) => AppSettingsSheet(
                        title: '设置',
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
                        onSave: () => Navigator.pop(s, 'saved'),
                        child: AppSettingsForm(
                          children: [
                            for (var i = 0; i < 16; i++)
                              TextFormField(
                                key: ValueKey('field-$i'),
                                decoration: InputDecoration(labelText: '字段 $i'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final form = find.byType(AppSettingsForm);
      expect(
        Theme.of(tester.element(form)).colorScheme.primary,
        local.colorScheme.primary,
      );
      expect(
        tester.getSize(find.byType(AppBottomSheet)).width,
        lessThanOrEqualTo(640),
      );
      final sheetBounds = tester.getRect(find.byType(AppBottomSheet));
      final formBounds = tester.getRect(form);
      expect(formBounds.left, closeTo(sheetBounds.left + 16, .01));
      expect(formBounds.right, closeTo(sheetBounds.right - 16, .01));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '保存');
      expect(
        tester.getBottomLeft(save).dy,
        lessThanOrEqualTo(size.height - 200),
      );
      expect(tester.getTopLeft(save).dy, greaterThanOrEqualTo(0));
      await tester.ensureVisible(find.byKey(const ValueKey('field-15')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('field-15')), '尾部输入');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result, 'saved');
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('保存禁用与自定义关闭由调用方控制，取消返回结果', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                result = await AppBottomSheet.showContent<String>(
                  context: c,
                  builder: (s) => AppSettingsSheet(
                    title: '编辑',
                    onSave: null,
                    onClose: () => Navigator.pop(s, 'cancelled'),
                    child: const AppSettingsForm(children: [Text('内容')]),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(result, 'cancelled');
    expect(tester.takeException(), isNull);
  });
  testWidgets('表单统一间距、标题说明与错误提示使用当前主题', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppSettingsForm(
            title: '分组',
            description: '说明',
            errorText: '保存失败',
            children: [
              Text('名称', key: ValueKey('name')),
              Text('风格', key: ValueKey('style')),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('style'))).dy -
          tester.getBottomLeft(find.byKey(const ValueKey('name'))).dy,
      12,
    );
    expect(find.text('分组'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('保存失败')).style!.color,
      AppTheme.dark.colorScheme.error,
    );
    final semantics = find.ancestor(
      of: find.text('保存失败'),
      matching: find.byType(Semantics),
    );
    expect(
      tester.widget<Semantics>(semantics.first).properties.liveRegion,
      true,
    );
    expect(tester.takeException(), isNull);
  });
}
