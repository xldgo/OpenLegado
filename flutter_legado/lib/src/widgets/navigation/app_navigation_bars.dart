import '../app_menu.dart';

import 'dart:io' show File;

import '../../theme/app_surface_material.dart';
import '../app_surface_backdrop.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localization.dart';
import '../../services/bottom_bar_skin_service.dart';

/// [UI_SYNC_REFACTOR S1c] 主框架导航组件族（对齐参考仓 ShortNavigationBar/
/// AppNavigationBar/FloatingBottomBar/Rail）
///
/// 三态统一消费底栏皮肤图标：标准栏/悬浮胶囊/Rail 全部走 [SkinNavIcon]；
/// Rail 头部提供搜索与展开切换；长按书架图标显示分组菜单。

/// 导航项规格（图标/文案/皮肤槽位）
class AppNavSpec {
  final IconData symbol;
  final String label;
  final String? skinSlot;

  const AppNavSpec({required this.symbol, required this.label, this.skinSlot});
}

/// 底栏皮肤图标（缺图回退系统 glyph；原 home_screen 私有件公共化）
class SkinNavIcon extends StatelessWidget {
  final String skin;
  final String slot;
  final bool selected;
  final Widget fallback;

  const SkinNavIcon({
    super.key,
    required this.skin,
    required this.slot,
    required this.selected,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BottomBarSkinIcons>(
      future: BottomBarSkinService.instance.iconsForSlot(skin, slot),
      builder: (context, snap) {
        final icons = snap.data;
        final path = selected
            ? (icons?.selected ?? icons?.normal)
            : (icons?.normal ?? icons?.selected);
        if (path == null) return fallback;
        final child = Image.file(
          // ignore: avoid_slow_placeholder_io
          File(path),
          width: 24,
          height: 24,
          errorBuilder: (_, _, _) => fallback,
        );
        return child;
      },
    );
  }
}

/// 标准底栏（ShortNavigationBar 等效：label 三档+透明度+皮肤图标）
class AppShortNavigationBar extends StatelessWidget {
  final List<AppNavSpec> specs;
  final int currentIndex;
  final String activeSkin;
  final NavigationDestinationLabelBehavior labelBehavior;
  final AppSurfaceMaterial material;
  final ValueChanged<int> onSelect;

  const AppShortNavigationBar({
    super.key,
    required this.specs,
    required this.currentIndex,
    required this.activeSkin,
    required this.labelBehavior,
    required this.material,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(
      material: material,
      child: NavigationBar(
        backgroundColor: material.color,
        surfaceTintColor: Colors.transparent,
        labelBehavior: labelBehavior,
        selectedIndex: currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final spec in specs)
            NavigationDestination(
              icon: _icon(spec, selected: false),
              selectedIcon: _icon(spec, selected: true),
              label: spec.label,
            ),
        ],
      ),
    );
  }

  Widget _icon(AppNavSpec spec, {required bool selected}) {
    Widget fallback() => Icon(spec.symbol, size: 24, fill: selected ? 1 : 0);
    if (spec.skinSlot == null || activeSkin.isEmpty) return fallback();
    return SkinNavIcon(
      skin: activeSkin,
      slot: spec.skinSlot!,
      selected: selected,
      fallback: fallback(),
    );
  }
}

/// 悬浮底栏（64dp Stadium 胶囊；对齐参考 FloatingBottomBar 实色版）
class AppFloatingBottomBar extends StatefulWidget {
  final List<AppNavSpec> specs;
  final int currentIndex;
  final String activeSkin;
  final ValueChanged<int> onSelect;
  final AppSurfaceMaterial material;

  const AppFloatingBottomBar({
    super.key,
    required this.specs,
    required this.currentIndex,
    required this.activeSkin,
    required this.onSelect,
    required this.material,
  });

  @override
  State<AppFloatingBottomBar> createState() => _AppFloatingBottomBarState();
}

class _AppFloatingBottomBarState extends State<AppFloatingBottomBar> {
  int _pressedIndex = -1;

  Widget _icon(int index, {required bool selected}) {
    final spec = widget.specs[index];
    Widget fallback({required bool sel}) =>
        Icon(spec.symbol, size: 24, fill: sel ? 1 : 0);
    if (widget.activeSkin.isEmpty || spec.skinSlot == null) {
      return fallback(sel: selected);
    }
    return SkinNavIcon(
      skin: widget.activeSkin,
      slot: spec.skinSlot!,
      selected: selected,
      fallback: fallback(sel: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(32);

    // 材质面只负责填充、圆角与内容；阴影交给外层，避免被模糊层裁剪。
    final surface = Container(
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.material.color,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.specs.length; i++)
            Expanded(child: _item(i, cs)),
        ],
      ),
    );

    // 留白必须留在裁剪层之外：BackdropFilter 的采样范围和圆角要与可见胶囊
    // 严格重合，否则模糊会溢出到胶囊左右 16、底部 12 的留白里。
    final capsule = AppSurfaceBackdrop(
      material: widget.material,
      borderRadius: radius,
      child: surface,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: capsule,
        ),
      ),
    );
  }

  /// 单个导航项：视觉态（按压/选中缩放）与语义态（名称、选中、互斥组）分开表达。
  Widget _item(int index, ColorScheme cs) {
    final spec = widget.specs[index];
    final selected = widget.currentIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: spec.label,
      onTap: () => widget.onSelect(index),
      // 图标与皮肤图片不单独进语义树，名称已由 label 表达，避免重复播报。
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressedIndex = index),
        onTapCancel: () => setState(() => _pressedIndex = -1),
        onTapUp: (_) {
          setState(() => _pressedIndex = -1);
          widget.onSelect(index);
        },
        child: Center(
          child: AnimatedScale(
            scale: _pressedIndex == index ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.fastOutSlowIn,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              width: selected ? 64 : 48,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? cs.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: selected ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                child: _icon(index, selected: selected),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 大屏侧栏：标准可滚动NavigationRail，书架分组收敛到长按书架图标。
class AppRailBar extends StatelessWidget {
  final List<AppNavSpec> specs;
  final int currentIndex;
  final String activeSkin;
  final bool extended;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleExtended;
  final VoidCallback onSearch;

  /// 书架导航项索引；其他页面不承载分组菜单。
  final int? bookshelfIndex;
  final List<String>? groups;
  final int? selectedGroupIndex;
  final ValueChanged<int>? onGroupSelected;

  const AppRailBar({
    super.key,
    required this.specs,
    required this.currentIndex,
    required this.activeSkin,
    required this.extended,
    required this.onSelect,
    required this.onToggleExtended,
    required this.onSearch,
    this.bookshelfIndex,
    this.groups,
    this.selectedGroupIndex,
    this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget railIcon(AppNavSpec spec, {required bool selected}) {
      Widget fallback() => Icon(spec.symbol, size: 24, fill: selected ? 1 : 0);
      if (spec.skinSlot == null || activeSkin.isEmpty) return fallback();
      return SkinNavIcon(
        skin: activeSkin,
        slot: spec.skinSlot!,
        selected: selected,
        fallback: fallback(),
      );
    }

    Widget destinationIcon(int index, {required bool selected}) {
      final hasGroupMenu =
          index == bookshelfIndex &&
          groups != null &&
          groups!.length >= 2 &&
          onGroupSelected != null;
      final icon = Tooltip(
        message: specs[index].label,
        // 分组长按交给入口手势，避免Tooltip抢占同一个长按动作；鼠标提示保留。
        triggerMode: hasGroupMenu
            ? TooltipTriggerMode.manual
            : TooltipTriggerMode.longPress,
        child: railIcon(specs[index], selected: selected),
      );
      if (!hasGroupMenu) return icon;
      return AppMenuAnchor<int>(
        onSelected: onGroupSelected,
        itemBuilder: (_) => [
          for (var i = 0; i < groups!.length; i++)
            AppMenuItem<int>(
              value: i,
              checked: selectedGroupIndex == i,
              child: Text(groups![i]),
            ),
        ],
        builder: (_, controller, _) => GestureDetector(
          key: const ValueKey('rail-bookshelf-groups'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          onLongPress: controller.open,
          child: Semantics(
            hint: context.l10n.bookshelfGroups,
            child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
          ),
        ),
      );
    }

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelect,
      extended: extended,
      minWidth: 80,
      minExtendedWidth: 200,
      groupAlignment: -1,
      scrollable: true,
      backgroundColor: cs.surfaceContainerLow,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.selected,
      leading: Builder(
        builder: (context) {
          final animation = NavigationRail.extendedAnimation(context);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final progress = animation.value;
              return SizedBox(
                width: 80 + 120 * progress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: extended
                            ? context.l10n.collapseSidebar
                            : context.l10n.expandSidebar,
                        icon: Icon(
                          extended
                              ? Symbols.menu_open_rounded
                              : Symbols.menu_rounded,
                        ),
                        onPressed: onToggleExtended,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 56 + 120 * progress,
                        height: 56,
                        child: FloatingActionButton(
                          heroTag: null,
                          tooltip: context.l10n.search,
                          onPressed: onSearch,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.search_rounded),
                              SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                alignment: AlignmentDirectional.centerStart,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(context.l10n.search),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      destinations: [
        for (var i = 0; i < specs.length; i++)
          NavigationRailDestination(
            icon: destinationIcon(i, selected: false),
            selectedIcon: destinationIcon(i, selected: true),
            label: Text(
              specs[i].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
