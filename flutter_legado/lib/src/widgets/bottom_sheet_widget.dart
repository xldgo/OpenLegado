import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_sheet_theme.dart';
import 'settings_widgets.dart' show SheetDragHandle;

/// 通用底部弹窗 — 带标题的底部弹窗
class AppBottomSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? leading;
  final Widget? _content;
  final bool? centerTitle;
  final Widget? titleSuffix;
  final bool avoidKeyboard;

  /// 默认由外壳滚动；含固定筛选区和独立列表的正文自行管理滚动。— Codex + UI
  final bool scrollable;

  /// 正文默认铺满，文字留白由设置行、表单等内容组件负责。— Codex + UI
  final EdgeInsets contentPadding;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.contentPadding = EdgeInsets.zero,
  }) : leading = null,
       _content = null,
       centerTitle = null,
       titleSuffix = null,
       avoidKeyboard = false,
       scrollable = true;

  /// 共用固定标题、滚动正文与键盘避让，操作由调用方提供。— Codex + UI
  const AppBottomSheet.content({
    super.key,
    required this.title,
    required Widget child,
    this.leading,
    this.trailing,
    this.centerTitle,
    this.titleSuffix,
    this.avoidKeyboard = true,
    this.scrollable = true,
    this.contentPadding = EdgeInsets.zero,
  }) : children = const [],
       _content = child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final centered =
        centerTitle ?? theme.extension<AppSheetTheme>()?.centerTitle ?? true;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final showHandle =
        context
            .dependOnInheritedWidgetOfExactType<_SheetHandleScope>()
            ?.showHandle ??
        false;
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle?.fontSize ?? 16) *
        1.5;
    final toolbarHeight = math.max(kMinInteractiveDimension, titleHeight);
    // 大字体时让标题始终位于横条下方，普通字号共用60dp头部。— Codex + UI
    final topInset = showHandle
        ? math.max(12.0, 24 - (toolbarHeight - titleHeight) / 2)
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0,
      ),
      child: SafeArea(
        top: !avoidKeyboard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 横条与标题共用头部，左右按钮保留48dp操作区。— Codex + UI
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topInset,
                    16,
                    showHandle ? 0 : 4,
                  ),
                  child: SizedBox(
                    height: toolbarHeight,
                    child: NavigationToolbar(
                      centerMiddle: centered,
                      leading: leading,
                      trailing: trailing,
                      middle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              textAlign: centered
                                  ? TextAlign.center
                                  : TextAlign.start,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          if (titleSuffix != null) ...[
                            const SizedBox(width: 8),
                            Flexible(child: titleSuffix!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (showHandle)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Semantics(
                      label: MaterialLocalizations.of(context)
                          .modalBarrierDismissLabel,
                      button: true,
                      onTap: () => Navigator.maybePop(context),
                      child: const Center(
                        child: SheetDragHandle(margin: EdgeInsets.zero),
                      ),
                    ),
                  ),
              ],
            ),
            // 内容
            Flexible(
              child: ListTileTheme.merge(
                shape: const RoundedRectangleBorder(),
                child: scrollable
                    ? SingleChildScrollView(
                        padding: contentPadding,
                        child:
                            _content ??
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: children,
                            ),
                      )
                    : Padding(padding: contentPadding, child: _content),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示底部弹窗的便捷方法
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    Widget? trailing,
    bool isScrollControlled = true,
    EdgeInsets contentPadding = EdgeInsets.zero,
  }) {
    return showContent<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      constraints: null,
      useSafeArea: false,
      // [LAYOUT_PLAN P4] 对话框 Sheet 半径对齐 Expressive 28dp（原 16dp）。
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AppBottomSheet(
        title: title,
        trailing: trailing,
        contentPadding: contentPadding,
        children: children,
      ),
    );
  }

  /// 通用弹层入口，继承打开位置的主题，保留调用方的关闭策略。— Codex + UI
  static Future<T?> showContent<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
    bool useSafeArea = true,
    bool? showDragHandle,
    bool isDismissible = true,
    bool enableDrag = true,
    BoxConstraints? constraints = const BoxConstraints(maxWidth: 640),
    ShapeBorder? shape,
  }) => showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final displayHandle =
          showDragHandle ??
          (enableDrag &&
              (Theme.of(sheetContext).bottomSheetTheme.showDragHandle ??
                  false));
      // 显隐传给公共头部，入口不再单独叠加一行横条。— Codex + UI
      return _SheetHandleScope(
        showHandle: displayHandle,
        child: builder(sheetContext),
      );
    },
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    showDragHandle: false,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    constraints: constraints,
    shape: shape,
    clipBehavior: Clip.antiAlias,
  );
}

class _SheetHandleScope extends InheritedWidget {
  const _SheetHandleScope({required this.showHandle, required super.child});

  final bool showHandle;

  @override
  bool updateShouldNotify(_SheetHandleScope oldWidget) =>
      showHandle != oldWidget.showHandle;
}

/// 快捷项等宽铺满可用宽度，大字体或窄屏时减少列数。— Codex + UI
class AppSheetPresetGrid extends StatelessWidget {
  const AppSheetPresetGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
    this.minItemWidth = 64,
  }) : assert(maxColumns > 0),
       assert(minItemWidth > 0);

  final List<Widget> children;
  final int maxColumns;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (children.isEmpty) return const SizedBox.shrink();
      const spacing = 8.0;
      final minWidth = MediaQuery.textScalerOf(context).scale(minItemWidth);
      final columns = ((constraints.maxWidth + spacing) / (minWidth + spacing))
          .floor()
          .clamp(1, math.min(maxColumns, children.length));
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
