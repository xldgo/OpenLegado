import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/display/display_corners.dart';

void main() {
  const corners = DisplayCorners(
    size: Size(400, 800),
    bottomLeft: DisplayCorner(center: Offset(50, 750), radius: 50),
    bottomRight: DisplayCorner(center: Offset(350, 750), radius: 50),
  );

  test('物理像素只转换一次，窗口和左右圆角保持同一坐标', () {
    final actual = DisplayCorners.fromPhysical({
      'width': 1200,
      'height': 2400,
      'bottomLeft': {'radius': 150, 'x': 150, 'y': 2250},
      'bottomRight': {'radius': 150, 'x': 1050, 'y': 2250},
    }, 3);
    expect(actual, corners);
    expect(
      DisplayCorners.fromPhysical({'width': double.nan, 'height': 1}, 1),
      isNull,
    );
    expect(DisplayCorners.fromPhysical({}, 0), isNull);
  });

  test('底部文字带按圆弧内收，原边距已足够时不再叠加', () {
    // 半径50、纵向距圆心40，对应横向距离30，再留4逻辑像素。
    expect(
      corners.extraInsets(const Rect.fromLTRB(16, 776, 384, 790)),
      const EdgeInsets.symmetric(horizontal: 8),
    );
    expect(
      corners.extraInsets(const Rect.fromLTRB(40, 776, 360, 790)),
      EdgeInsets.zero,
    );
    expect(
      corners.extraInsets(const Rect.fromLTRB(16, 716, 384, 730)),
      EdgeInsets.zero,
    );
  });

  test('双页只避让屏幕两端，中间书脊不增加留白', () {
    expect(
      corners.extraInsets(const Rect.fromLTRB(16, 776, 184, 790)),
      const EdgeInsets.only(left: 8),
    );
    expect(
      corners.extraInsets(const Rect.fromLTRB(216, 776, 384, 790)),
      const EdgeInsets.only(right: 8),
    );
  });

  test('左右非对称及窗口外圆心独立计算，不把窗口边当物理圆角', () {
    const asymmetric = DisplayCorners(
      size: Size(400, 800),
      bottomLeft: DisplayCorner(center: Offset(-100, 750), radius: 50),
      bottomRight: DisplayCorner(center: Offset(350, 750), radius: 50),
    );
    expect(
      asymmetric.extraInsets(const Rect.fromLTRB(16, 776, 384, 790)),
      const EdgeInsets.only(right: 8),
    );
  });

  test('系统已报告无圆角保留原边距，不回落到移动端近似', () {
    final square = DisplayCorners.fromPhysical({
      'width': 400,
      'height': 800,
    }, 1)!;
    expect(
      square.extraInsets(const Rect.fromLTRB(0, 786, 400, 800)),
      EdgeInsets.zero,
    );
  });

  test('移动端安全区采用近似，桌面不虚构圆角，边距离开圆角带即不补偿', () {
    final ios = DisplayCorners.fallback(
      const Size(390, 844),
      const EdgeInsets.only(bottom: 34),
      TargetPlatform.iOS,
    );
    expect(
      ios.extraInsets(const Rect.fromLTRB(16, 820, 374, 838)).left,
      greaterThan(16),
    );
    expect(
      ios.extraInsets(const Rect.fromLTRB(16, 740, 374, 754)),
      EdgeInsets.zero,
    );
    final desktop = DisplayCorners.fallback(
      const Size(900, 700),
      EdgeInsets.zero,
      TargetPlatform.windows,
    );
    expect(
      desktop.extraInsets(const Rect.fromLTRB(0, 680, 900, 700)),
      EdgeInsets.zero,
    );
  });
}
