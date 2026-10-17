import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../models/book.dart';
import '../../../../widgets/ui_settings_scope.dart';
import '../../../../widgets/custom_refresh_indicator.dart';
import '../../../../widgets/list_footer.dart';

/// 封面背景与加载装饰；刷新和正文由页面提供。— Codex + UI
class BookDetailBackdrop extends StatelessWidget {
  const BookDetailBackdrop({
    super.key,
    required this.book,
    required this.coverSeed,
    required this.isLoading,
    required this.onRefresh,
    required this.child,
  });
  final Book book;
  final Color? coverSeed;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    final isDefaultCover = !hasCover;
    final ui = UiSettingsScope.of(context, UiSettingsAspect.details);
    final mode = isDefaultCover
        ? ui.bookInfoDefaultCoverBackground
        : ui.bookInfoNetworkCoverBackground;
    // [UI-fix v2.0.166] 虚化源降采样：σ24 下 1/3 屏宽与全尺寸视觉无差，
    // 解码+滤波开销降一个量级（进详情转场掉帧根因之一）
    final blurWidth = (MediaQuery.sizeOf(context).width / 3).round().clamp(
      120,
      480,
    );
    final seed = coverSeed;
    final seedOverlay = seed == null
        ? cs.secondaryContainer
        : Color.lerp(cs.secondaryContainer, seed, 0.42)!;
    // [UI_SYNC_REFACTOR R1] enableBlur 关闭时 on 档退化为不模糊显示（对齐参考仓全局开关语义）
    final useBlur = mode == 'on' && hasCover && ui.enableBlur;
    final showBackdrop = !(mode == 'off_for_default' && isDefaultCover);

    final Widget backdrop = !showBackdrop
        ? ColoredBox(color: cs.surface)
        : Stack(
            children: [
              if (hasCover)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 480,
                  child: RepaintBoundary(
                    child: useBlur
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 24,
                              sigmaY: 24,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: blurWidth,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: blurWidth,
                          ),
                  ),
                )
              else
                ColoredBox(color: cs.surfaceContainerHighest),
              if (hasCover)
                Positioned.fill(
                  child: ColoredBox(color: seedOverlay.withValues(alpha: 0.34)),
                ),
            ],
          );

    // [G1 | 台账 0917 批六] hero 底部渐隐：≤35% 封面完整（仅 seed 10-18% 微染），
    // 35%→48% surface 由 α0 渐隐至全覆盖（亮态融入亮 surface / 暗态融入暗
    // surface，均走 cs.surface 槽位，明暗双态天然生效），48% 以下为纯 surface
    // 底色区——信息 chips/四按钮/在读·最新/标签/简介不再透封面，对齐 ref 08
    // 「模糊封面仅占顶部约 45%（y≈870/1920 完全消失）」
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.2, 0.35, 0.48, 1.0],
          colors: [
            cs.surface.withValues(alpha: 0),
            seedOverlay.withValues(alpha: 0.10),
            seedOverlay.withValues(alpha: 0.18),
            cs.surface,
            cs.surface,
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景层：封面/档位/seed 变化时 Crossfade 800（对齐参考仓 tween(800)）
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          child: KeyedSubtree(
            key: ValueKey('$coverUrl|$mode|${seed?.toARGB32()}'),
            child: backdrop,
          ),
        ),
        Positioned.fill(child: gradient),
        SafeArea(
          top: false,
          // [LAYOUT_PLAN P4 收尾] 下拉 M3 化：裸 RefreshIndicator → CustomRefreshIndicator
          child: CustomRefreshIndicator(onRefresh: onRefresh, child: child),
        ),
        // 顶栏加载条（对标原版 refreshProgressBar.isAutoLoading）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TopNetworkLoadingBar(isLoading: isLoading),
        ),
      ],
    );
  }
}
