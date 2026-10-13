import 'package:material_ui/material_ui.dart';

import 'ui_settings_scope.dart';

import 'app_menu.dart';
import 'setting_cards.dart';

/// 跨平台分组列表组件库。
///
/// 提供分组设置页的「tonal 表面背景 + 大圆角分组容器 + outlineVariant
/// 分隔」构件。组件读取当前主题，供应用设置页与阅读器局部主题共用。
///
/// 典型用法：
/// ```dart
/// SettingsBody(
///   child: ListView(children: [
///     SettingsSectionHeader('分组'),
///     SettingsGroup(children: [SettingTile(title: '设置项')]),
///   ]),
/// )
/// ```
///
/// 分组列表外层容器：使用 Scaffold 的表面背景色并留出左右安全边距。
class SettingsBody extends StatelessWidget {
  /// 子 Widget（通常为 Column / ListView，内容自带滚动则用 [child]）
  final Widget child;

  /// 分组卡片外侧的左右留白。
  final EdgeInsets padding;

  const SettingsBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 分组标题：MD3 风格的小标题（labelMedium / onSurfaceVariant，位于容器上方）。
class SettingsSectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const SettingsSectionHeader(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 含中文/混排标题保持原样（避免「WebDav 设置」→「WEBDAV 设置」）；
    // 纯拉丁短标题仍用大写。
    final hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    final label = hasCjk ? text : text.toUpperCase();
    return Padding(
      padding: padding,
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: hasCjk ? 0.2 : 0.6,
        ),
      ),
    );
  }
}

/// 分组脚注：卡片下方的灰色说明文字。
class SettingsSectionFooter extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const SettingsSectionFooter(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// tonal 圆角分组容器：在 children 之间绘制 outlineVariant 分隔线。
///
/// 容器视觉由 cardTheme 驱动（tonal surfaceContainer 层次）；
/// 默认分隔线避开相邻行的图标列，无图标时左侧留 16dp，右侧始终留 16dp。
/// [separatorIndent] 可显式覆盖左侧缩进。
/// [LAYOUT_MOTION_AUDIT L2] 分组圆角 16dp（HapeLee SplicedColumnGroup，
/// 已确认；cardTheme 全局 20 保留，此处显式覆盖）；
/// [flat] 为 true 时走扁平模式（Column + 条件 80% pill 分隔，
/// HapeLee 设置页式，9 屏迁移用），默认 false 保持卡片兼容。
class SettingsGroup extends StatelessWidget {
  /// 可选的卡片内标题，不参与设置行之间的分隔线。
  final String? title;

  /// 标题后的小字号说明，与标题同行，空间不足时自然换行。
  final String? titleSuffix;
  final bool showDividers;
  final List<Widget> children;
  final double? separatorIndent;
  final EdgeInsets margin;
  final bool flat;

  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.titleSuffix,
    this.showDividers = true,
    this.separatorIndent,
    this.margin = const EdgeInsets.symmetric(horizontal: 0),
    this.flat = false,
  });

  bool _hasLeading(Widget row) => switch (row) {
    SettingTile(:final icon, :final leading) => icon != null || leading != null,
    SettingSwitchRow(:final icon, :final leading) =>
      icon != null || leading != null,
    SettingMenuRow(:final icon) => icon != null,
    ListTile(:final leading) => leading != null,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    if (title != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                text: title!,
                children: [
                  if (titleSuffix != null)
                    TextSpan(
                      text: ' · $titleSuffix',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (showDividers && i != children.length - 1) {
        // 图标行的文字起点为 16dp 内边距 + 24dp 图标列 + 16dp 间距。
        final hasLeading =
            _hasLeading(children[i]) || _hasLeading(children[i + 1]);
        rows.add(
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: separatorIndent ?? (hasLeading ? 56 : 16),
            endIndent: 16,
            color: theme.dividerColor,
          ),
        );
      }
    }

    if (flat) {
      // 扁平模式需自备透明 Material，否则 ListTile 的 ink 溅在远端
      // Material 祖先上会被中间 ColoredBox（SettingsBody）遮住而断言失败
      return Padding(
        padding: margin,
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      );
    }
    // 分组只绘制一个底色；点击反馈共用同一 Material，并由外层圆角裁剪。
    return Padding(
      padding: margin,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: theme.listTileTheme.copyWith(
            tileColor: Colors.transparent,
            shape: const RoundedRectangleBorder(),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }
}

/// M3 设置行：图标 + 标题 +（可选副标题）+ 尾部（值 / 开关 / 箭头）。
///
/// [LAYOUT_MOTION_AUDIT L2] 对齐 HapeLee SettingItem：
/// 图标为裸 Icon（onSurfaceVariant，HapeLee 无 32dp 方块容器；
/// 传 [iconBackground] 时仍走旧 tonal 方块兼容）；
/// 值文本走 primary-labelMediumEmphasized；
/// [showChevron] 为 true 且可点击时尾部补 Chevron（M3 有箭头；
/// 原 P2 移除注释仅对 Miuix 成立，此处反转）。
/// [MD3 全量清点 P2] 行是否可点由 onTap 存在性决定。
class SettingTile extends StatelessWidget {
  /// 可选；嵌套设置页常见无图标行
  final IconData? icon;

  /// 自定义前导件（优先于 [icon]）。用于忙态 spinner 等非静态图标；
  /// 行语义包装件 [SettingSwitchRow] 亦经此透传。
  final Widget? leading;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// 尾部值文本（如「默认」）；自定义 [trailing] 优先。
  final String? value;

  /// 当前值的图标或色块预览，与 [value] 使用同一尾部布局。
  final Widget? valuePreview;

  /// 可点击时是否显示行尾 Chevron（默认 true；开关行传 false）
  final bool showChevron;
  final VoidCallback? onTap;

  /// 行是否可用（同 ListTile.enabled：false 时文字/图标灰显且不可点）
  final bool enabled;

  /// 行高密度（透传 ListTile.dense；null 走 ListTileTheme）
  final bool? dense;

  /// 覆盖主题默认行内边距（透传 ListTile.contentPadding；
  /// 密排开关行如 WebDav 组内 vertical12/horizontal8 用）
  final EdgeInsetsGeometry? contentPadding;

  const SettingTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.iconColor,
    this.iconBackground,
    this.subtitle,
    this.trailing,
    this.value,
    this.valuePreview,
    this.showChevron = true,
    this.onTap,
    this.enabled = true,
    this.dense,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget? trailing = this.trailing;
    if (trailing == null && (value != null || valuePreview != null)) {
      trailing = _SettingValue(
        value: value,
        preview: valuePreview,
        enabled: enabled,
        showChevron: onTap != null && showChevron,
      );
    }
    // 可点击且无自定义尾部/值文本时补 M3 Chevron
    trailing ??= (onTap != null && showChevron)
        ? Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          )
        : null;

    Widget? leading = this.leading;
    if (leading == null && icon != null) {
      if (iconBackground != null || iconColor != null) {
        // 显式传色时保留旧 tonal 方块（兼容沉浸域调用）
        leading = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground ?? scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon!,
            size: 19,
            color: iconColor ?? scheme.onPrimaryContainer,
          ),
        );
      } else {
        // 默认裸图标（HapeLee SettingItem 无容器）
        leading = Icon(icon, size: 24, color: scheme.onSurfaceVariant);
      }
    }

    // [UI_SYNC_REFACTOR R3] 设置行分隔线（参考仓 enableItemDivider：
    // 行底 1dp 胶囊线，长度 80dp 缩进 16，默认关）
    final tile = ListTile(
      leading: leading,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: enabled ? scheme.onSurfaceVariant : theme.disabledColor,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      enabled: enabled,
      dense: dense,
      contentPadding: contentPadding,
    );
    return UiSettingsScope.of(
          context,
          UiSettingsAspect.dividers,
        ).enableItemDivider
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Container(
                    width: 80,
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          )
        : tile;
  }
}

/// 普通设置行与菜单设置行共用的值样式；长文本为标题保留空间。
class _SettingValue extends StatelessWidget {
  const _SettingValue({
    this.value,
    this.preview,
    required this.enabled,
    required this.showChevron,
  });

  final String? value;
  final Widget? preview;
  final bool enabled;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?preview,
            if (preview != null && value != null) const SizedBox(width: 8),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMediumEmphasized?.copyWith(
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单选菜单设置行：整行打开菜单，右侧显示当前值，不绘制跳转箭头。
/// 配置保存由调用方负责；选项与当前值可附带图标预览。
class SettingMenuRow<T> extends StatelessWidget {
  const SettingMenuRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.valuePreview,
    this.optionBuilder,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;
  final Widget? valuePreview;
  final Widget Function(T value, String label)? optionBuilder;

  @override
  Widget build(BuildContext context) => AppMenuAnchor<T>(
    itemBuilder: (_) => [
      for (final entry in options.entries)
        AppMenuItem(
          value: entry.key,
          checked: entry.key == value,
          enabled: onChanged != null,
          child:
              optionBuilder?.call(entry.key, entry.value) ?? Text(entry.value),
        ),
    ],
    onSelected: onChanged,
    builder: (context, controller, _) => SettingTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showChevron: false,
      enabled: onChanged != null,
      value: options[value] ?? '未设置',
      valuePreview: valuePreview,
      onTap: onChanged == null
          ? null
          : () => controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// 数值步进设置行：名称、减号、带单位的当前值和加号。
/// 只负责步进与边界限制，联动及持久化交给调用方。
class SettingStepperRow extends StatelessWidget {
  const SettingStepperRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.unit,
    this.showPlus = false,
  }) : assert(min <= max),
       assert(step > 0);

  final String title;
  final double value;
  final double min;
  final double max;
  final double step;
  final String? unit;
  final bool showPlus;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    final label =
        '${showPlus && value >= 0 ? '+' : ''}$number${unit == null ? '' : ' $unit'}';
    return SettingTile(
      title: title,
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '减小$title',
            onPressed: onChanged != null && value > min
                ? () => onChanged!((value - step).clamp(min, max))
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          IconButton(
            tooltip: '增大$title',
            onPressed: onChanged != null && value < max
                ? () => onChanged!((value + step).clamp(min, max))
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// M3 设置开关行（对齐参考版 `SwitchSettingItem`）
///
/// 语义与 `SettingTile` 同族（图标 + 标题 + 副标题 + 尾部），尾部固定为
/// `Switch`：整行可点即切换（参考版非 Miuix 分支 `onClick = onCheckedChange(!checked)`），
/// 语义经 `MergeSemantics` 合并为单一开关节点（与 `SwitchListTile` 同法）。
/// `onChanged == null` 时行禁用（文字灰显、不可点、开关灰置），同 `SwitchListTile`。
/// [icon] 为静态图标；[leading] 自定义前导件（忙态 spinner 等）优先于 [icon]。
/// [dense]/[contentPadding] 供密排行保留原参数（如 WebDav 组内 vertical12/horizontal8）。
class SettingSwitchRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;

  const SettingSwitchRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.dense,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: SettingTile(
        icon: icon,
        leading: leading,
        title: title,
        subtitle: subtitle,
        showChevron: false,
        enabled: onChanged != null,
        dense: dense,
        contentPadding: contentPadding,
        // 同 SwitchListTile：控件不参与焦点，整行即单一焦点/语义目标
        trailing: ExcludeFocus(
          child: Switch(value: value, onChanged: onChanged),
        ),
        onTap: onChanged == null ? null : () => onChanged(!value),
      ),
    );
  }
}

/// MD3 拖拽把手（Bottom Sheet 顶部短横条，对齐 M3 drag handle 规格）。
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color:
            theme.bottomSheetTheme.dragHandleColor ??
            theme.colorScheme.onSurfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
