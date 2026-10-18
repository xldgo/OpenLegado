import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';

void main() {
  test('默认模糊底色使用 0.73 与 0.40，不解释为颜色字节', () {
    const settings = UiSettings(enableBlur: true);
    final top = AppSurfaceMaterial.topBar(
      color: Colors.white,
      settings: settings,
    );
    final bottom = AppSurfaceMaterial.bottomBar(
      color: Colors.white,
      settings: settings,
    );
    expect(top.color.a, closeTo(0.73, 1e-6));
    expect(bottom.color.a, closeTo(0.40, 1e-6));
    expect(top.blurSigma, 24);
    expect(bottom.blurSigma, 8);
  });

  for (final opacity in [0.0, 0.5, 1.0]) {
    test('普通/模糊分别选取背景参数：$opacity', () {
      final settings = UiSettings(
        topBarBackgroundOpacity: opacity,
        topBarBlurTintOpacity: 1 - opacity,
      );
      final normal = AppSurfaceMaterial.topBar(
        color: Colors.black,
        settings: settings,
      );
      final blurred = AppSurfaceMaterial.topBar(
        color: Colors.black,
        settings: settings.copyWith(enableBlur: true),
      );
      expect(normal.color.a, opacity);
      expect(normal.hasBlur, isFalse);
      expect(blurred.color.a, 1 - opacity);
      expect(blurred.hasBlur, isTrue);
    });
  }

  test('保留输入颜色 alpha，显式透明色不产生底色或过滤器', () {
    const settings = UiSettings(
      topBarBackgroundOpacity: 0.5,
      enableBlur: false,
    );
    final translucent = AppSurfaceMaterial.topBar(
      color: Colors.red.withValues(alpha: 0.4),
      settings: settings,
    );
    expect(translucent.color.a, closeTo(0.2, 1e-6));
    final transparent = AppSurfaceMaterial.topBar(
      color: Colors.transparent,
      settings: settings.copyWith(enableBlur: true),
    );
    expect(transparent.color.a, 0);
    expect(transparent.hasBlur, isFalse);
  });

  test('零模糊强度保留模糊模式底色，有限值规范防止无效滤镜', () {
    final material = AppSurfaceMaterial.resolve(
      color: Colors.white,
      blurEnabled: true,
      backgroundOpacity: 1,
      blurTintOpacity: 0.4,
      blurSigma: 0,
    );
    expect(material.color.a, closeTo(0.4, 1e-6));
    expect(material.hasBlur, isFalse);
    final invalid = AppSurfaceMaterial.resolve(
      color: Colors.white,
      blurEnabled: true,
      backgroundOpacity: -1,
      blurTintOpacity: double.nan,
      blurSigma: double.infinity,
    );
    expect(invalid.color.a, 1);
    expect(invalid.blurSigma, 0);
  });
}
