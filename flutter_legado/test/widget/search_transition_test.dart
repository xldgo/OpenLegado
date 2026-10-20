import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_scaffold.dart';
import 'package:flutter_legado/src/widgets/dynamic_search_app_bar.dart';
import 'package:flutter_legado/src/widgets/app_search_field.dart';

void main() {
  testWidgets('展开收起占位连续、保留输入、焦点释放并支持中途反向', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var expanded = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return AppScaffold(
              topBar: DynamicSearchAppBar(
                title: '列表',
                searchController: controller,
                searchHint: '关键词',
                expanded: expanded,
                onExpandedChanged: (value) => setState(() => expanded = value),
                onChanged: (_) {},
              ),
              body: const SizedBox.expand(key: ValueKey('search-body')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('search-body'));
    final closed = tester.getTopLeft(body).dy;
    expect(find.byType(AppSearchField), findsNothing);
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pump();
    expect(tester.getTopLeft(body).dy, closed);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getTopLeft(body).dy;
    expect(middle, greaterThan(closed));
    expect(middle, lessThan(closed + 64));
    update(() => expanded = false);
    await tester.pump();
    expect(tester.getTopLeft(body).dy, closeTo(middle, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(body).dy, closed);
    update(() => expanded = true);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(body).dy, closed + 64);
    await tester.enterText(find.byType(TextField), '保留输入');
    await tester.tap(find.byTooltip('收起搜索'));
    await tester.pump();
    expect(tester.getTopLeft(body).dy, closed + 64);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus ?? false, isFalse);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(body).dy, greaterThan(closed));
    expect(tester.getTopLeft(body).dy, lessThan(closed + 64));
    await tester.pumpAndSettle();
    expect(find.byType(AppSearchField), findsNothing);
    update(() => expanded = true);
    await tester.pumpAndSettle();
    expect(controller.text, '保留输入');
    expect(tester.takeException(), isNull);
  });
  testWidgets('常驻底栏与滚动位置不随搜索过渡重建', (tester) async {
    final controller = TextEditingController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    var expanded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => AppScaffold(
            topBar: DynamicSearchAppBar(
              title: '列表',
              searchController: controller,
              searchHint: '关键词',
              expanded: expanded,
              onExpandedChanged: (v) => setState(() => expanded = v),
              onChanged: (_) {},
              persistentBottom: const PreferredSize(
                preferredSize: Size.fromHeight(32),
                child: SizedBox(height: 32, child: Text('固定内容')),
              ),
            ),
            body: ListView.builder(
              controller: scroll,
              itemCount: 100,
              itemExtent: 40,
              itemBuilder: (_, i) => Text('条目$i'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(300);
    await tester.pump();
    await tester.tap(find.byTooltip('展开搜索'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 300);
    expect(find.text('固定内容'), findsOneWidget);
    await tester.tap(find.byTooltip('收起搜索'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 300);
    expect(tester.takeException(), isNull);
  });
}
