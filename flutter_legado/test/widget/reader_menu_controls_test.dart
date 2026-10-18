import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_menu_controls.dart';
import 'package:flutter_legado/src/theme/app_glass_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  bool ready = false,
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: AppGlassHost(
      available: ready,
      child: GlassTheme(
        data: GlassThemeData.simple(quality: GlassQuality.minimal),
        child: ReaderMenuControlTheme(
          child: Scaffold(
            body: Center(
              child: SizedBox(width: 280, child: Center(child: child)),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('资源未就绪仍使用Glass按钮，点击与键盘激活各执行一次', (tester) async {
    var calls = 0;
    await _show(
      tester,
      ReaderMenuControlButton(
        icon: Icons.arrow_back,
        label: '退出阅读',
        standalone: true,
        onPressed: () => calls++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassButton), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(tester.getSize(find.byType(GlassButton)), const Size(48, 48));
    await tester.tap(find.byTooltip('退出阅读'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用Glass按钮不触发回调，语义状态正确且无重复标签', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _show(
        tester,
        const ReaderMenuControlButton(
          icon: Icons.skip_next,
          label: '下一章',
          onPressed: null,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下一章'));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('下一章'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(find.bySemanticsLabel('下一章'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  for (final ready in [false, true]) {
    testWidgets('进度条离散拖动及禁用沿用输入范围：资源就绪$ready', (tester) async {
      var value = 1.0;
      var calls = 0;
      var enabled = true;
      late StateSetter rebuild;
      await _show(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return ReaderMenuProgressSlider(
              value: value,
              max: 4,
              divisions: 4,
              onChanged: enabled
                  ? (next) => setState(() {
                      value = next;
                      calls++;
                    })
                  : null,
              label: '章节进度',
              color: Colors.blue,
            );
          },
        ),
        ready: ready,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(GlassSlider), const Offset(190, 0));
      await tester.pumpAndSettle();
      expect(value, 4);
      expect(calls, greaterThan(0));
      final previousCalls = calls;
      rebuild(() => enabled = false);
      await tester.pump();
      await tester.drag(find.byType(GlassSlider), const Offset(-190, 0));
      await tester.pumpAndSettle();
      expect(value, 4);
      expect(calls, previousCalls);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('阅读控件继承局部亮度：$brightness', (tester) async {
      await _show(
        tester,
        ReaderMenuControlButton(
          icon: Icons.more_horiz,
          label: '更多',
          onPressed: () {},
        ),
        ready: true,
        brightness: brightness,
      );
      await tester.pumpAndSettle();
      expect(
        GlassTheme.brightnessOf(tester.element(find.byType(GlassButton))),
        brightness,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
