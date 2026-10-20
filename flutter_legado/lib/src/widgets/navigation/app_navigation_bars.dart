import '../app_menu.dart';

import 'dart:io' show File;
import 'dart:math' as math;

import '../../theme/app_surface_material.dart';
import '../../theme/app_glass_theme.dart';
import '../../theme/app_motion.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

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
  final double size;

  const SkinNavIcon({
    super.key,
    required this.skin,
    required this.slot,
    required this.selected,
    required this.fallback,
    this.size = 24,
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
          width: size,
          height: size,
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

/// 悬浮底栏：保持应用导航接口，玻璃模型仅在本组件内适配。— Codex + UI
class AppFloatingBottomBar extends StatelessWidget {
  final List<AppNavSpec> specs;
  final int currentIndex;
  final String activeSkin;
  final ValueChanged<int> onSelect;
  final AppSurfaceMaterial material;
  final bool useLiquidGlass;
  final bool showLabels;

  const AppFloatingBottomBar({
    super.key,
    required this.specs,
    required this.currentIndex,
    required this.activeSkin,
    required this.onSelect,
    required this.material,
    this.useLiquidGlass = false,
    this.showLabels = true,
  });

  Widget _icon(int index, {required bool selected, double size = 24}) {
    final spec = specs[index];
    final fallback = Icon(spec.symbol, size: size, fill: selected ? 1 : 0);
    if (activeSkin.isEmpty || spec.skinSlot == null) return fallback;
    return SkinNavIcon(
      skin: activeSkin,
      slot: spec.skinSlot!,
      selected: selected,
      fallback: fallback,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(32);
    final useGlass = useLiquidGlass && AppGlassScope.availableOf(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final navigationLabels = Theme.of(context)
        .navigationBarTheme
        .labelTextStyle;
    final selectedWeight =
        navigationLabels?.resolve({WidgetState.selected})?.fontWeight ??
        FontWeight.w600;
    final unselectedWeight =
        navigationLabels?.resolve({})?.fontWeight ?? FontWeight.w500;
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 11) *
        (labelStyle?.height ?? 1.3);
    final barHeight = showLabels
        // 字体行度量按完整逻辑像素预留，避免大字下小数舍入产生溢出。
        ? math.max(64.0, (28 + 2 + labelHeight + 8).ceilToDouble())
        : 64.0;
    final Widget capsule;
    if (useGlass) {
      final reduced = AppMotion.reduced(context);
      capsule = GlassTabBar.bottom(
        tabs: [
          for (var i = 0; i < specs.length; i++)
            GlassTab(
              icon: _icon(i, selected: false, size: 28),
              activeIcon: _icon(i, selected: true, size: 28),
              label: showLabels ? specs[i].label : null,
              semanticLabel: specs[i].label,
            ),
        ],
        selectedIndex: currentIndex,
        onTabSelected: onSelect,
        settings: AppGlassStyle.resolve(material),
        selectedIconColor: cs.onSurface,
        unselectedIconColor: cs.onSurfaceVariant,
        selectedLabelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        textStyle: labelStyle,
        selectedLabelStyle: TextStyle(fontWeight: selectedWeight),
        unselectedLabelStyle: TextStyle(fontWeight: unselectedWeight),
        iconSize: 28,
        iconLabelSpacing: 0,
        horizontalPadding: 0,
        verticalPadding: 0,
        barHeight: barHeight,
        barBorderRadius: 32,
        magnification: reduced ? 1 : 1.15,
        interactionBehavior: reduced
            ? GlassInteractionBehavior.none
            : GlassInteractionBehavior.full,
      );
    } else {
      capsule = DecoratedBox(
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
        child: AppSurfaceBackdrop(
          material: material,
          borderRadius: radius,
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: material.color,
              borderRadius: radius,
            ),
            child: Row(
              children: [
                for (var i = 0; i < specs.length; i++)
                  Expanded(
                    child: _plainItem(
                      context,
                      i,
                      cs,
                      labelStyle,
                      i == currentIndex ? selectedWeight : unselectedWeight,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    // 对齐库示例：玻璃胶囊留白20，只有Android额外避让系统导航区。
    // 普通胶囊及玻璃未就绪时的回退继续沿用原间距。— Codex + UI
    return SafeArea(
      top: false,
      bottom: !useGlass || defaultTargetPlatform == TargetPlatform.android,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, useGlass ? 20 : 12),
        child: capsule,
      ),
    );
  }

  Widget _plainItem(
    BuildContext context,
    int index,
    ColorScheme cs,
    TextStyle? labelStyle,
    FontWeight labelWeight,
  ) {
    final selected = currentIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: specs[index].label,
      onTap: () => onSelect(index),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(index),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 200),
                ),
                curve: Curves.fastOutSlowIn,
                width: selected ? 64 : 48,
                height: showLabels ? 28 : 32,
                decoration: BoxDecoration(
                  color: selected ? cs.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: _icon(index, selected: selected),
              ),
              if (showLabels) ...[
                const SizedBox(height: 2),
                Text(
                  specs[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle?.copyWith(
                    fontWeight: labelWeight,
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
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
