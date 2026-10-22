// [UI_SYNC_REFACTOR B2] 顶栏按钮体系回归守护：5 档样式规格（尺寸/底色/描边）、
// merge 胶囊分隔线、UiSettingsNotifier 档位解析与默认值、LegadoAppBar 全局
// 透传（含 topBarBackgroundOpacity）。通用组件从 UiSettingsScope 读取只读设置。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';

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

  group('LegadoAppBar 全局透传', () {
    testWidgets('普通背景设为零不关闭已启用的模糊材质', (tester) async {
      await tester.pumpWidget(
        const UiSettingsScope(
          settings: UiSettings(enableBlur: true, topBarBackgroundOpacity: 0),
          child: MaterialApp(
            home: Scaffold(
              appBar: LegadoAppBar(
                title: Text('材质'),
                showBack: false,
                backgroundColor: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('topBarBackgroundOpacity=0.5：作用域变化即时更新背景', (tester) async {
      const page = MaterialApp(
        home: Scaffold(
          appBar: LegadoAppBar(title: Text('T'), showBack: false, actions: []),
        ),
      );
      await tester.pumpWidget(
        const UiSettingsScope(settings: UiSettings(), child: page),
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!.a, 1);
      // 保留相同页面子树，仅变更作用域快照，验证组件自身订阅会触发更新。
      await tester.pumpWidget(
        const UiSettingsScope(
          settings: UiSettings(topBarBackgroundOpacity: 0.5),
          child: page,
        ),
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor!.a, closeTo(0.5, 0.02));
    });
  });
}
