import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_source_repository.dart';
import 'package:flutter_legado/src/features/rss/presentation/rss_source_edit_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/rss_repository_provider.dart';
import 'package:flutter_legado/src/widgets/source_editor.dart';

void main() {
  testWidgets('订阅源选项随基本页滚动，切换页签保留展开及输入，保存原有开关', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockRssSourceRepository();
    const source = RssSource(sourceUrl: 'https://feed.test', sourceName: '订阅源');
    await repository.addRssSource(source);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...MockBookApi().overrides,
          rssSourceRepositoryProvider.overrideWithValue(repository),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const RssSourceEditScreen(source: source),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final options = find.byType(SourceEditorOptions).hitTestable();
    expect(options, findsOneWidget);
    expect(find.byType(CheckboxListTile).hitTestable(), findsNothing);
    await tester.tap(find.text('选项'));
    await tester.pumpAndSettle();
    final enabled = find.widgetWithText(CheckboxListTile, '启用');
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('sf_sourceName'));
    await tester.ensureVisible(name);
    await tester.enterText(name, '更新后的订阅源');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '预处理'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceEditorOptions).hitTestable(), findsNothing);
    await tester.tap(find.widgetWithText(Tab, '基本'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SourceEditorTab).hitTestable(),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(enabled).value, isFalse);
    expect(tester.widget<TextFormField>(name).controller!.text, '更新后的订阅源');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    final saved = (await repository.getRssSources()).single;
    expect(saved.sourceName, '更新后的订阅源');
    expect(saved.enabled, isFalse);
    expect(find.byType(RssSourceEditScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
