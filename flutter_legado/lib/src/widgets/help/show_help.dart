import 'package:material_ui/material_ui.dart';

import 'help_assets.dart';
import 'help_screen.dart';

/// 显示帮助文档，统一使用 Markdown 阅读 Sheet。
void showHelp(BuildContext context, String fileName, {String title = '帮助'}) {
  showHelpDocument(
    context,
    assetPath: HelpAssets.mdPath(fileName),
    title: title,
  );
}

/// 显示 storageHelp.md（对标 BaseImportBookActivity / FileAssociationActivity）
void showStorageHelp(BuildContext context) {
  showHelpDocument(context, assetPath: HelpAssets.storageHelp);
}

/// 帮助、更新日志及免责声明共用入口，继承打开位置的局部主题。
Future<void> showHelpDocument(
  BuildContext context, {
  required String assetPath,
  String title = '帮助',
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => LayoutBuilder(
      builder: (context, constraints) {
        // 高度按安全区域与把手后的实际空间计算，横屏充分利用可用高度。
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        return SizedBox(
          height: constraints.maxHeight * (landscape ? 1 : 0.9),
          child: HelpScreen(assetPath: assetPath, title: title),
        );
      },
    ),
  );
}
