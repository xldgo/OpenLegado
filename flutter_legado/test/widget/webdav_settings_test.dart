import '../fixtures/app_test_api.dart';

// WebDAV / 备份与恢复页 widget 测试
//
// 对齐 BackupConfigFragment + pref_config_backup：AppBar「备份与恢复」
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/settings/presentation/webdav_settings_screen.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../mocks/mocks.dart';

void main() {
  final bodyScrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    container = ProviderContainer(
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  Widget wrap() {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WebDavSettingsScreen()),
    );
  }

  testWidgets('渲染 WebDAV 配置组与备份/恢复组', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // AppBar 标题
    expect(find.text('备份与恢复'), findsWidgets);

    for (final label in const [
      'WebDAV 服务器地址',
      'WebDAV 账号',
      'WebDAV 密码',
      '子目录',
      '设备名称',
      '同步书籍进度',
      '同步书籍进度增强',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        80,
        scrollable: bodyScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.text('备份路径'),
      80,
      scrollable: bodyScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('备份'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('恢复忽略列表'), findsOneWidget);
    expect(find.text('仅保留最新备份'), findsOneWidget);
  });

  testWidgets('点击服务器地址弹出编辑对话框并保存', (tester) async {
    when(() => mockApi.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => mockApi.configRepository.setConfig(any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('WebDAV 服务器地址'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'https://dav.example.com');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('https://dav.example.com'), findsOneWidget);
  });

  testWidgets('有效的进度同步开关仍支持整行点击和持久化', (tester) async {
    // 该行由 SwitchListTile 迁移为统一 SettingSwitchRow（M3 设置开关行），
    // 行为要求不变：整行可点即切换（参考版 SwitchSettingItem onClick 语义）
    when(() => mockApi.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('同步书籍进度'),
      80,
      scrollable: bodyScrollable,
    );
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('同步书籍进度'),
      matching: find.byType(SettingSwitchRow),
    );
    expect(row, findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    final switchFinder = find.descendant(
      of: row,
      matching: find.byType(Switch),
    );
    final before = tester.widget<Switch>(switchFinder).value;

    // 点标题（非开关本体）即切换：等价原 SwitchListTile 整行语义
    await tester.tap(find.text('同步书籍进度'));
    await tester.pumpAndSettle();

    final after = tester.widget<Switch>(switchFinder).value;
    expect(after, !before);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sync_book_progress'), after);
  });

  testWidgets('未配置 WebDAV 时点击恢复给出提示', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('恢复'),
      100,
      scrollable: bodyScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('未配置 WebDAV，请长按「恢复」从本地恢复'), findsOneWidget);
  });
}
