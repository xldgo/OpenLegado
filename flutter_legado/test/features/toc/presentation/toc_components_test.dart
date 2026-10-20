import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/toc/presentation/components/toc_item_tile.dart';
import 'package:flutter_legado/src/features/toc/presentation/components/toc_volume_tile.dart';
import 'package:flutter_legado/src/features/toc/presentation/components/toc_overflow_menu.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  for (final failed in [false, true]) {
    testWidgets('章节${failed ? '重试' : '下载'}点击与选择独立', (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TocItemTile(
              chapter: const BookChapter(title: '第五章', index: 5),
              isCurrent: false,
              isLocal: false,
              isCached: false,
              isDownloading: false,
              isError: failed,
              loadWordCount: true,
              wordCount: null,
              onSelect: () => actions.add('select'),
              onDownload: () => actions.add('download'),
              onRetry: () => actions.add('retry'),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(failed ? '重新下载本章' : '下载本章'));
      expect(actions, [failed ? 'retry' : 'download']);
      await tester.tap(find.text('第五章'));
      expect(actions.last, 'select');
    });
  }
  testWidgets('卷标题不包含可点击章节项或下载操作', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TocVolumeTile(
            chapter: BookChapter(title: '第一卷', isVolume: true),
          ),
        ),
      ),
    );
    expect(find.text('第一卷'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
  for (final tab in [0, 1, 2]) {
    testWidgets('目录菜单按Tab $tab 显示并分发动作', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                TocOverflowMenu(
                  tab: tab,
                  isLocalTxt: true,
                  readConfig: const ReadConfig(),
                  loadWordCount: true,
                  onSelected: (action) => selected = action,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('加载字数'), tab == 0 ? findsOneWidget : findsNothing);
      expect(
        find.text('导出 Markdown'),
        tab == 1 ? findsOneWidget : findsNothing,
      );
      if (tab == 1) {
        await tester.tap(find.text('导出 Markdown'));
        await tester.pumpAndSettle();
        expect(selected, 'exportMd');
      }
    });
  }
}
