import 'package:material_ui/material_ui.dart';

/// 通用底部弹窗 — 带标题的底部弹窗
class AppBottomSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? leading;
  final Widget? _content;
  final bool centerTitle;
  final bool avoidKeyboard;
  final EdgeInsets contentPadding;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  }) : leading = null,
       _content = null,
       centerTitle = false,
       avoidKeyboard = false,
       contentPadding = const EdgeInsets.all(16);

  /// 共用固定标题、滚动正文与键盘避让，操作由调用方提供。— Codex + UI
  const AppBottomSheet.content({
    super.key,
    required this.title,
    required Widget child,
    this.leading,
    this.trailing,
    this.centerTitle = false,
    this.avoidKeyboard = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  }) : children = const [],
       _content = child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0,
      ),
      child: SafeArea(
        top: !avoidKeyboard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [UI_SYNC_REFACTOR S5] 标题栏（titleMedium+Medium 强调，对齐参考
            // AppModalBottomSheet titleMediumEmphasized；把手由主题
            // showDragHandle 统一提供，消双把手；标题下无分隔线）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  ?leading,
                  Expanded(
                    child: Text(
                      title,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.start,
                      maxLines: centerTitle ? 1 : null,
                      overflow: centerTitle ? TextOverflow.ellipsis : null,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // ignore: use_null_aware_elements
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: contentPadding,
                child:
                    _content ??
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
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
      builder: (_) =>
          AppBottomSheet(title: title, trailing: trailing, children: children),
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
    builder: builder,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    constraints: constraints,
    shape: shape,
  );
}
