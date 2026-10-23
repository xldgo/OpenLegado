import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';

/// M3 设置开关行（`SettingSwitchRow`，对齐参考版 `SwitchSettingItem`）测试
///
/// 只保留项目封装的整行点击、整行禁用与语义合并，不复测原生Switch回调。
void main() {
  Widget wrap(Widget child, {UiSettings settings = const UiSettings()}) =>
      UiSettingsScope(
        settings: settings,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('整行点击即切换（标题处点击传 !value）', (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      wrap(SettingSwitchRow(title: '自动刷新', value: false, onChanged: calls.add)),
    );

    await tester.tap(find.text('自动刷新'));
    await tester.pump();

    expect(calls, [true]);
  });

  testWidgets('onChanged 为 null 时行禁用：不可点、ListTile 停用、开关灰置', (tester) async {
    await tester.pumpWidget(
      wrap(const SettingSwitchRow(title: '同步书籍进度增强', value: false)),
    );

    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    // 禁用行点击不抛异常也不产生任何回调（无可点 InkWell 目标即静默）
    await tester.tap(find.text('同步书籍进度增强'), warnIfMissed: false);
    await tester.pump();
  });

  testWidgets('语义合并为单一开关节点（MergeSemantics 包住整行）', (tester) async {
    await tester.pumpWidget(
      wrap(SettingSwitchRow(title: '自动刷新', value: true, onChanged: _noop)),
    );

    expect(
      find.ancestor(
        of: find.byType(SettingTile),
        matching: find.byType(MergeSemantics),
      ),
      findsOneWidget,
    );
    // 控件不参与焦点（同 SwitchListTile：ExcludeFocus 包 Switch）
    expect(
      find.ancestor(
        of: find.byType(Switch),
        matching: find.byType(ExcludeFocus),
      ),
      findsOneWidget,
    );
  });
}

void _noop(bool _) {}
