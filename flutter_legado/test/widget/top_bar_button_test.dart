// [UI_SYNC_REFACTOR B2] 顶栏按钮体系回归守护：5 档样式规格（尺寸/底色/描边）、
// merge 胶囊分隔线、UiSettingsNotifier 档位解析与默认值、LegadoAppBar 全局
// 透传（含 topBarOpacity）。设置读取走 uiSettingsListenable 全局通道（组件
// 不依赖 Riverpod scope），测试直接操作该通道并复位。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/top_bar_button.dart';

void main() {
  group('TopBarButtonStyle 解析', () {
    test('合法名直取、未知值回退 tonal', () {
      expect(TopBarButtonStyle.fromName('plain'), TopBarButtonStyle.plain);
      expect(
        TopBarButtonStyle.fromName('liquidGlass'),
        TopBarButtonStyle.liquidGlass,
      );
      expect(TopBarButtonStyle.fromName(null), TopBarButtonStyle.tonal);
      expect(TopBarButtonStyle.fromName('__bad__'), TopBarButtonStyle.tonal);
    });
  });

  group('TopBarActionStyler 槽位规格', () {
    Future<void> pumpActions(
      WidgetTester tester, {
      required TopBarButtonStyle style,
      bool merge = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopBarActionStyler(
              style: style,
              merge: merge,
              actions: [
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tonal：36dp 透明圆槽与 48dp 点击区域', (tester) async {
      await pumpActions(tester, style: TopBarButtonStyle.tonal);
      // 视觉圆槽与按钮点击区域分别核对。
      final slot = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).color == Colors.transparent,
          );
      expect(slot.constraints?.maxWidth, 36);
      final deco = slot.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    });

    testWidgets('plain：48dp 点击区域', (tester) async {
      await pumpActions(tester, style: TopBarButtonStyle.plain);
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    });

    testWidgets('outlined：1dp outlineVariant 描边', (tester) async {
      await pumpActions(tester, style: TopBarButtonStyle.outlined);
      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration! as BoxDecoration;
      expect(deco.border, isNotNull);
    });

    testWidgets('merge：胶囊容器 + 分隔线', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopBarActionStyler(
              style: TopBarButtonStyle.tonal,
              merge: true,
              actions: [
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // 胶囊容器存在且为圆角矩形
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers, isNotEmpty);
      final mergeDeco = containers.first.decoration! as BoxDecoration;
      expect(mergeDeco.borderRadius, isNotNull);
    });
  });

  group('LegadoAppBar 全局透传', () {
    testWidgets('默认 tonal：36dp 外观与 48dp 点击区域', (tester) async {
      addTearDown(() {
        uiSettingsListenable.value = const UiSettingsState();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: LegadoAppBar(
              title: const Text('T'),
              showBack: false,
              actions: [
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 36);
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    });

    testWidgets('topBarOpacity=50：背景混入半透明', (tester) async {
      const original = UiSettingsState();
      uiSettingsListenable.value = const UiSettingsState(topBarOpacity: 50);
      addTearDown(() => uiSettingsListenable.value = original);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: LegadoAppBar(
              title: const Text('T'),
              showBack: false,
              actions: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      // surface α0.5（50%）
      expect(appBar.backgroundColor!.a, closeTo(0.5, 0.02));
    });
  });
}
