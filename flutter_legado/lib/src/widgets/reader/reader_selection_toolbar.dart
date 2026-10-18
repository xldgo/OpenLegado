import '../../theme/app_motion.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader_selection_actions.dart';
import 'reader_selection_controller.dart';
import 'reader_selection_menu_config.dart';
import 'reader_selection_menu_config_sheet.dart';
import 'reader_menu_theme.dart';

/// 阅读器专用选区菜单；选择范围和手柄仍由原生 SelectionArea 管理。
class ReaderSelectionToolbar extends ConsumerStatefulWidget {
  const ReaderSelectionToolbar({
    super.key,
    required this.actionContext,
    required this.anchor,
    this.anchorBelow,
    this.selectionFocusNode,
    required this.text,
    required this.chapterPos,
    required this.onDismiss,
  });

  final Offset anchor;

  /// 原阅读页面的上下文；应用外层浮窗可能位于 Navigator 之外。
  final BuildContext actionContext;
  final Offset? anchorBelow;
  final FocusNode? selectionFocusNode;
  final String text;
  final int chapterPos;
  final VoidCallback onDismiss;

  /// 仅供缺少章节原文映射的旧段落入口使用，正常阅读由选区组件定位。
  static void show(
    BuildContext context, {
    required Offset anchor,
    required String text,
    required int chapterPos,
  }) {
    if (text.trim().isEmpty) return;
    final menuContext = readerMenuContextOf(context);
    final key = GlobalKey<_ReaderSelectionToolbarState>();
    late OverlayEntry entry;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => InheritedTheme.captureAll(
        menuContext,
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => key.currentState?.dismiss(),
                child: const SizedBox.expand(),
              ),
            ),
            ReaderSelectionToolbar(
              key: key,
              actionContext: menuContext,
              anchor: anchor,
              text: text,
              chapterPos: chapterPos,
              onDismiss: remove,
            ),
          ],
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  ConsumerState<ReaderSelectionToolbar> createState() =>
      _ReaderSelectionToolbarState();
}

class _ReaderSelectionToolbarState extends ConsumerState<ReaderSelectionToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 320),
  );
  final _cardKey = GlobalKey();
  Rect? _moreAnchor;
  LocalHistoryEntry? _history;
  bool _moreOpen = false;
  bool _closing = false;
  bool _disposed = false;

  BuildContext get _host => widget.actionContext;

  void _closeMore() {
    if (!_moreOpen) return;
    setState(() => _moreOpen = false);
    final history = _history;
    _history = null;
    history?.remove();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _motion.value = _closing ? 0 : 1;
    } else if (!_closing) {
      _motion.forward();
    }
  }

  Future<void> dismiss() async {
    if (_closing) return;
    _closing = true;
    _closeMore();
    try {
      if (AppMotion.reduced(context)) {
        _motion.value = 0;
      } else {
        await _motion.reverse().orCancel;
      }
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDismiss();
  }

  void _perform(ReaderSelectionAction action) {
    if (_closing) return;
    final actions = ReaderSelectionActions(
      context: _host,
      ref: ref,
      selection: ReaderTextSelection(
        widget.chapterPos,
        widget.chapterPos + widget.text.length,
        widget.text,
      ),
    );
    unawaited(actions.run(action, dismiss));
  }

  Future<void> _manage() async {
    if (_closing) return;
    final host = _host;
    final config = ref.read(readerSelectionMenuProvider);
    final notifier = ref.read(readerSelectionMenuProvider.notifier);
    await dismiss();
    if (!host.mounted) return;
    final updated = await ReaderSelectionMenuConfigSheet.show(host, config);
    if (updated == null) return;
    try {
      await notifier.save(updated);
    } catch (error) {
      if (host.mounted) {
        ScaffoldMessenger.maybeOf(host)
            ?.showSnackBar(SnackBar(content: Text('保存菜单配置失败：$error')));
      }
    }
  }

  void _openMore() {
    if (_closing || _moreOpen) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    _moreAnchor = origin & box.size;
    setState(() => _moreOpen = true);
    final route = ModalRoute.of(widget.actionContext);
    if (route == null) return;
    _history = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        _history = null;
        if (!_disposed && _moreOpen) unawaited(dismiss());
      },
    );
    route.addLocalHistoryEntry(_history!);
  }

  @override
  void dispose() {
    _disposed = true;
    _history?.remove();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(readerSelectionMenuProvider);
    final media = MediaQuery.of(context);
    final width = math.max(1.0, media.size.width - 32);
    // 菜单焦点属于同一选区节点，打开折叠菜单不会被判断为正文失焦。
    return FocusScope(
      parentNode: widget.selectionFocusNode,
      child: Stack(
        children: [
          CustomSingleChildLayout(
            delegate: _SelectionMenuLayout(
              widget.anchor,
              widget.anchorBelow,
              media.padding,
            ),
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final closing = _motion.status == AnimationStatus.reverse;
                final value = Curves.easeOutCubic.transform(_motion.value);
                return FadeTransition(
                  opacity: _motion,
                  child: Transform.scale(
                    scale: closing ? .96 + .04 * value : .94 + .06 * value,
                    child: child,
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: Material(
                  key: _cardKey,
                  color: Theme.of(context).colorScheme.surfaceBright,
                  elevation: config.expanded ? 12 : 6,
                  borderRadius: BorderRadius.circular(12),
                  child: config.expanded
                      ? _expanded(config, media.size.height)
                      : _compact(config),
                ),
              ),
            ),
          ),
          if (_moreOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                child: const SizedBox.expand(),
              ),
            ),
            CustomSingleChildLayout(
              delegate: _SelectionMenuLayout(
                _moreAnchor!.topRight,
                _moreAnchor!.bottomRight,
                media.padding,
              ),
              child: _foldedMenu(config, media.size.height),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action(ReaderSelectionAction action, bool showIcons) => _MenuAction(
    label: action.label,
    icon: showIcons ? action.icon : null,
    onPressed: () => _perform(action),
  );

  Widget _expanded(ReaderSelectionMenuConfig config, double height) =>
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(300, math.max(48, height - 48)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Wrap(
              children: [
                for (final item in config.visibleItems)
                  _action(item.action, config.showIcons),
                _MenuAction(
                  label: '菜单管理',
                  icon: config.showIcons ? Icons.settings_outlined : null,
                  onPressed: _manage,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _compact(ReaderSelectionMenuConfig config) {
    final primary = config.inGroup(SelectionMenuGroup.primary);
    final collapsed = config.inGroup(SelectionMenuGroup.collapsed);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primary.isNotEmpty)
          Flexible(
            child: AnimatedScale(
              scale: _moreOpen ? .96 : 1,
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: _moreOpen ? .82 : 1,
                duration: const Duration(milliseconds: 200),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in primary)
                        _action(item.action, config.showIcons),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (primary.isNotEmpty)
          const SizedBox(height: 28, child: VerticalDivider(width: 1)),
        if (collapsed.isEmpty)
          IconButton(
            tooltip: '菜单项管理',
            onPressed: _manage,
            icon: const Icon(Icons.settings_outlined),
          )
        else
          IconButton(
            tooltip: '更多',
            onPressed: _openMore,
            icon: const Icon(Icons.more_vert),
          ),
      ],
    );
  }

  Widget _foldedMenu(ReaderSelectionMenuConfig config, double height) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: .94 + .06 * value, child: child),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceBright,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 240,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(360, height - 48),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.arrow_back),
                      title: const Text('返回主要菜单'),
                      onTap: _closeMore,
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in config.inGroup(
                              SelectionMenuGroup.collapsed,
                            ))
                              ListTile(
                                leading: config.showIcons
                                    ? Icon(item.action.icon, size: 20)
                                    : null,
                                title: Text(item.action.label),
                                onTap: () => _perform(item.action),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('菜单项管理'),
                      onTap: _manage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({required this.label, this.icon, required this.onPressed});
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(height: 4),
            ],
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    ),
  );
}

/// 优先置于选区下方并给手柄留白，空间不足时放上方，避免覆盖选区。
class _SelectionMenuLayout extends SingleChildLayoutDelegate {
  _SelectionMenuLayout(this.above, this.below, this.padding);
  final Offset above;
  final Offset? below;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(1, constraints.maxWidth - padding.horizontal - 32),
        maxHeight: math.max(1, constraints.maxHeight - padding.vertical - 24),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = padding.left + 16;
    final right = math.max(
      left,
      size.width - padding.right - 16 - childSize.width,
    );
    final top = padding.top + 12;
    final bottom = math.max(
      top,
      size.height - padding.bottom - 12 - childSize.height,
    );
    final belowY = (below ?? above).dy + 18;
    final y = belowY <= bottom ? belowY : above.dy - childSize.height - 4;
    return Offset(
      (above.dx - childSize.width / 2).clamp(left, right),
      y.clamp(top, bottom),
    );
  }

  @override
  bool shouldRelayout(_SelectionMenuLayout old) =>
      above != old.above || below != old.below || padding != old.padding;
}
