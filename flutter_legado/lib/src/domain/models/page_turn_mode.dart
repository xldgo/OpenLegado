/// 翻页模式
///
/// 对齐安卓原版 5 种翻页动画：覆盖/滑动/仿真/滚动/无动画
/// 注意：cover 追加在末尾（index=4），避免破坏已有持久化索引映射
enum PageTurnMode {
  scroll, // 上下滚动
  slide, // 左右滑动
  simulate, // 仿真翻页
  none, // 无动画（直接切换）
  cover; // 覆盖（新页从右向左覆盖旧页，旧页不动）

  /// 获取显示名称
  String get displayName {
    switch (this) {
      case PageTurnMode.scroll:
        return '滚动';
      case PageTurnMode.slide:
        return '滑动';
      case PageTurnMode.simulate:
        return '仿真';
      case PageTurnMode.none:
        return '无动画';
      case PageTurnMode.cover:
        return '覆盖';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case PageTurnMode.scroll:
        return '📜';
      case PageTurnMode.slide:
        return '👈';
      case PageTurnMode.simulate:
        return '📖';
      case PageTurnMode.none:
        return '⚡';
      case PageTurnMode.cover:
        return '📄';
    }
  }

  /// 从持久化名称恢复枚举值（兼容旧版 int 索引存储）
  static PageTurnMode fromStorage(String? name, int? legacyIndex) {
    // 优先使用 name 存储（新版）
    if (name != null && name.isNotEmpty) {
      for (final mode in PageTurnMode.values) {
        if (mode.name == name) return mode;
      }
    }
    // 回退：旧版 int 索引映射（0=scroll,1=slide,2=simulate,3=none）
    if (legacyIndex != null &&
        legacyIndex >= 0 &&
        legacyIndex < PageTurnMode.values.length) {
      return PageTurnMode.values[legacyIndex];
    }
    // 默认覆盖模式（对齐安卓原版）
    return PageTurnMode.cover;
  }
}
