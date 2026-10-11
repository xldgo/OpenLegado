import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/help/help_markdown_builders.dart';
import 'package:flutter_legado/src/widgets/help/help_markdown_styles.dart';
import 'package:flutter_legado/src/widgets/reader/review_column.dart';

Widget _helpMarkdownHarness(String data) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    // Markdown 插件尚未迁移，使用与应用入口一致的上下文适配。
    // ignore: deprecated_member_use
    builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    home: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
          body: Markdown(
            data: data,
            styleSheet: helpMarkdownStyleSheet(theme),
            builders: helpMarkdownBuilders(theme),
          ),
        );
      },
    ),
  );
}

void main() {
  group('helpMarkdownBuilders', () {
    testWidgets('切换主题后 Markdown 和 Cupertino 动态颜色保持一致', (tester) async {
      var dark = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) =>
                // ignore: deprecated_member_use
                MaterialUiCompatibilityBridge(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  ReviewColumnBadge(count: 3, onTap: () {}),
                  CupertinoButton(
                    onPressed: () => setState(() => dark = !dark),
                    child: const Text('切换主题'),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) => Markdown(
                        data: '# 帮助文档\n\n正文\n\n- [x] 已完成',
                        styleSheet: helpMarkdownStyleSheet(Theme.of(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final badge = find.byType(ReviewColumnBadge);
      expect(
        CupertinoTheme.of(tester.element(badge)).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('切换主题'));
      await tester.pumpAndSettle();
      final context = tester.element(badge);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(CupertinoTheme.of(context).brightness, Brightness.dark);
      final background = tester.widget<Container>(
        find.descendant(of: badge, matching: find.byType(Container)),
      );
      expect(
        (background.decoration! as BoxDecoration).color,
        CupertinoColors.systemBlue.darkColor.withValues(alpha: 0.22),
      );
      final markdown = tester.widget<Markdown>(find.byType(Markdown));
      expect(
        markdown.styleSheet?.p?.color,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
      expect(find.text('帮助文档'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('h2 标题下渲染可见分隔线', (tester) async {
      await tester.pumpWidget(_helpMarkdownHarness('## 新人必读\n\n正文内容'));

      expect(find.text('新人必读'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('h1 标题下渲染可见分隔线', (tester) async {
      await tester.pumpWidget(_helpMarkdownHarness('# 帮助文档\n\n正文'));

      expect(find.text('帮助文档'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });
}
