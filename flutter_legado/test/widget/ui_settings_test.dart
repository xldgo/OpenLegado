// 保留底栏文字和大屏模式的解析规则，不逐项复述主题默认常量。
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';

void main() {
  test('BottomBarLabelMode 解析：合法直取/未知回退 auto', () {
    expect(BottomBarLabelMode.fromName('labeled'), BottomBarLabelMode.labeled);
    expect(
      BottomBarLabelMode.fromName('unlabeled'),
      BottomBarLabelMode.unlabeled,
    );
    expect(BottomBarLabelMode.fromName(null), BottomBarLabelMode.auto);
    expect(BottomBarLabelMode.fromName('__bad__'), BottomBarLabelMode.auto);
  });

  test('TabletInterfaceMode 解析：合法直取/未知回退 auto', () {
    expect(
      TabletInterfaceMode.fromName('landscape'),
      TabletInterfaceMode.landscape,
    );
    expect(TabletInterfaceMode.fromName('off'), TabletInterfaceMode.off);
    expect(TabletInterfaceMode.fromName(null), TabletInterfaceMode.auto);
    expect(TabletInterfaceMode.fromName('always'), TabletInterfaceMode.always);
  });
}
