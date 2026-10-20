import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 菜单数据只保存页面的选项与操作，显示交给标准 MD3 组件。
sealed class AppMenuEntry<T> {
  const AppMenuEntry();
}

final class AppMenuItem<T> extends AppMenuEntry<T> {
  const AppMenuItem({
    this.value,
    required this.child,
    this.enabled = true,
    this.checked,
    this.leadingIcon,
  });

  final T? value;
  final Widget child;
  final bool enabled;
  final bool? checked;
  final Widget? leadingIcon;
}

final class AppMenuDivider<T> extends AppMenuEntry<T> {
  const AppMenuDivider();
}

List<Widget> _menuChildren<T>(
  List<AppMenuEntry<T>> entries,
  ValueChanged<T>? onSelected,
) => [
  for (final entry in entries)
    switch (entry) {
      AppMenuDivider<T>() => const Divider(
        height: 16,
        indent: 16,
        endIndent: 16,
      ),
      AppMenuItem<T>(checked: final checked?) => CheckboxMenuButton(
        value: checked,
        onChanged: entry.enabled && onSelected != null
            ? (_) => onSelected(entry.value as T)
            : null,
        child: entry.child,
      ),
      AppMenuItem<T>() => MenuItemButton(
        leadingIcon: entry.leadingIcon,
        onPressed: entry.enabled && onSelected != null
            ? () => onSelected(entry.value as T)
            : null,
        child: entry.child,
      ),
    },
];

/// 同一菜单入口用于图标、文字及长按菜单，定位与滚动由 MenuAnchor 处理。
class AppMenuAnchor<T> extends StatefulWidget {
  const AppMenuAnchor({
    super.key,
    required this.itemBuilder,
    required this.builder,
    this.onSelected,
    this.controller,
    this.onOpen,
    this.onClose,
  });

  final List<AppMenuEntry<T>> Function(BuildContext) itemBuilder;
  final MenuAnchorChildBuilder builder;
  final ValueChanged<T>? onSelected;
  final MenuController? controller;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<AppMenuAnchor<T>> createState() => _AppMenuAnchorState<T>();
}

class _AppMenuAnchorState<T> extends State<AppMenuAnchor<T>> {
  late final _controller = widget.controller ?? MenuController();
  LocalHistoryEntry? _history;
  bool _disposed = false;

  void _onOpen() {
    widget.onOpen?.call();
    final route = ModalRoute.of(context);
    if (route == null) return;
    // 系统返回先关闭菜单，保留当前页面。
    _history = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        _history = null;
        if (!_disposed) _controller.close();
      },
    );
    route.addLocalHistoryEntry(_history!);
  }

  void _onClose() {
    final history = _history;
    _history = null;
    history?.remove();
    if (!_disposed) widget.onClose?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    _onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _controller,
    consumeOutsideTap: true,
    useRootOverlay: true,
    animated: true,
    onOpen: _onOpen,
    onClose: _onClose,
    menuChildren: _menuChildren(widget.itemBuilder(context), widget.onSelected),
    builder: widget.builder,
  );
}

/// 共用菜单按钮；顶栏图标仍消费统一的 IconButtonTheme。
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.icon,
    this.tooltip,
    this.enabled = true,
    this.child,
    this.onOpen,
    this.onClose,
  });

  final List<AppMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T>? onSelected;
  final Widget? icon;
  final String? tooltip;
  final bool enabled;
  final Widget? child;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => AppMenuAnchor<T>(
    itemBuilder: itemBuilder,
    onSelected: onSelected,
    onOpen: onOpen,
    onClose: onClose,
    builder: (context, controller, _) {
      void toggle() =>
          controller.isOpen ? controller.close() : controller.open();
      if (child == null) {
        return IconButton(
          tooltip: tooltip ?? '更多操作',
          icon: icon ?? const Icon(Symbols.more_vert_rounded),
          onPressed: enabled ? toggle : null,
        );
      }
      final trigger = Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(onTap: enabled ? toggle : null, child: child),
      );
      return tooltip == null
          ? trigger
          : Tooltip(message: tooltip!, child: trigger);
    },
  );
}
