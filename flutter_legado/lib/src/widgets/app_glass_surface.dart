import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_glass_theme.dart';
import '../theme/app_surface_material.dart';
import 'app_surface_backdrop.dart';

/// 共用表面只绘制背景，前景须透明；原控件继续负责输入与语义。— Codex + UI
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.material,
    required this.child,
    this.topRadius = 0,
    this.bottomRadius = 0,
    this.visibility = const AlwaysStoppedAnimation(1),
  });

  final AppSurfaceMaterial material;
  final Widget child;
  final double topRadius;
  final double bottomRadius;
  final Animation<double> visibility;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlassScope.availableOf(context);
    final radius = BorderRadius.vertical(
      top: Radius.circular(topRadius),
      bottom: Radius.circular(bottomRadius),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: glass
                  ? GlassTheme(
                      // 阅读菜单可能使用与应用相反的亮度，质量仍继承宿主。
                      data: GlassThemeData.of(context)
                          .copyWith(brightness: Theme.of(context).brightness),
                      child: GlassMaterializeTransition(
                        animation: visibility,
                        scaleFrom: 1,
                        contentSigma: 0,
                        child: GlassContainer(
                          shape: LiquidVerticalRoundedRectangle(
                            topRadius: topRadius,
                            bottomRadius: bottomRadius,
                          ),
                          useOwnLayer: true,
                          settings: AppGlassStyle.resolve(material),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    )
                  : AppSurfaceBackdrop(
                      material: material,
                      borderRadius: radius,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: material.color,
                          borderRadius: radius,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
