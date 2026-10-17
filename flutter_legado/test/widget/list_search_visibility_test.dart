import '../fixtures/app_test_api.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
// 沿用现有文件导入测试的目录桩，仅覆写 path_provider 的传递平台接口。
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/files/presentation/file_manage_screen.dart';
import 'package:flutter_legado/src/features/rules/presentation/replace_rules_screen.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../mocks/mocks.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  setUpAll(registerFallbacks);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('替换规则默认隐藏，展开后实时筛选，收起不改已有条件', (tester) async {
    final api = MockRustApi();
    when(() => api.replaceRuleRepository.getReplaceRules()).thenAnswer(
      (_) async => [
        const ReplaceRule(id: 1, name: '甲规则', pattern: '甲'),
        const ReplaceRule(id: 2, name: '乙规则', pattern: '乙'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: const MaterialApp(home: ReplaceRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    final closedHeight = tester.getSize(find.byType(AppBar)).height;
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '甲规则');
    await tester.pumpAndSettle();
    expect(find.text('乙规则'), findsNothing);
    await tester.tap(find.byTooltip('收起搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '甲规则',
    );
    final expandedHeight = tester.getSize(find.byType(AppBar)).height;
    await tester.tap(find.byTooltip('批量操作'));
    await tester.pump();
    expect(tester.getSize(find.byType(AppBar)).height, expandedHeight);
    await tester.pump(const Duration(milliseconds: 60));
    final shrinkingHeight = tester.getSize(find.byType(AppBar)).height;
    expect(shrinkingHeight, greaterThan(closedHeight));
    expect(shrinkingHeight, lessThan(expandedHeight));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBar)).height, closedHeight);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('乙规则'), findsNothing);
    await tester.tap(find.byTooltip('退出批量模式'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '甲规则',
    );
    await tester.tap(find.byTooltip('清除搜索关键词'));
    await tester.pumpAndSettle();
    expect(find.text('乙规则'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('文件管理默认隐藏，筛选真实临时目录并能清除恢复', (tester) async {
    final dir = Directory.systemTemp.createTempSync('legado_search_widget_');
    File('${dir.path}/alpha.txt').writeAsStringSync('a');
    File('${dir.path}/beta.txt').writeAsStringSync('b');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(dir.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      dir.deleteSync(recursive: true);
    });
    // 真实目录流必须在真实异步区域启动，不能留给测试的虚拟时钟处理。
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: FileManageScreen()));
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.text('alpha.txt').evaluate().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('alpha.txt'), findsOneWidget);
    expect(find.text('beta.txt'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();
    expect(find.text('beta.txt'), findsNothing);
    await tester.tap(find.byTooltip('收起搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'alpha',
    );
    await tester.tap(find.byTooltip('清除搜索关键词'));
    await tester.pumpAndSettle();
    expect(find.text('beta.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
