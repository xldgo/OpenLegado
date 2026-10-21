import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/display/display_cutout_insets.dart';
import 'package:flutter_legado/src/services/system_bar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const physical = <String, Object>{
    'width': 1080,
    'height': 1920,
    'left': 0,
    'top': 120,
    'right': 0,
    'bottom': 60,
  };

  test('物理像素按DPR转换，旋转前的窗口尺寸不能匹配新窗口', () {
    final actual = DisplayCutoutInsets.fromPhysical(physical, 3)!;
    expect(actual.size, const Size(360, 640));
    expect(actual.padding, const EdgeInsets.only(top: 40, bottom: 20));
    expect(actual.matches(const Size(360, 640)), isTrue);
    expect(actual.matches(const Size(640, 360)), isFalse);
    expect(actual, DisplayCutoutInsets.fromPhysical(physical, 3));
  });

  test('合法的零缺口与无法读取区分，不能退回系统状态栏高度', () {
    final actual = DisplayCutoutInsets.fromPhysical({
      ...physical,
      'top': 0,
      'bottom': 0,
    }, 3)!;
    expect(actual.padding, EdgeInsets.zero);
    expect(DisplayCutoutInsets.fromPhysical(null, 3), isNull);
  });

  test('拒绝非法DPR、缺字段、负数、非有限尺寸和超过窗口的边距', () {
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      expect(DisplayCutoutInsets.fromPhysical(physical, ratio), isNull);
    }
    for (final payload in <Object>[
      [],
      {},
      {...physical}..remove('left'),
      {...physical, 'top': -1},
      {...physical, 'right': '20'},
      {...physical, 'width': 0},
      {...physical, 'height': double.infinity},
      {...physical, 'left': 1000, 'right': 100},
      {...physical, 'top': 1900, 'bottom': 60},
    ]) {
      expect(DisplayCutoutInsets.fromPhysical(payload, 3), isNull);
    }
  });

  const channel = MethodChannel('legado/system_bar');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform读取四边缺口通道并统一换算', () async {
      debugDefaultTargetPlatformOverride = platform;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return physical;
      });
      final result = await SystemBarService.displayCutoutInsets(3);
      expect(calls, ['getDisplayCutoutInsets']);
      expect(result!.padding, const EdgeInsets.only(top: 40, bottom: 20));
    });
  }

  test('通道不可用只返回未知，不伪造缺口', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await SystemBarService.displayCutoutInsets(3), isNull);
  });

  test('桌面不调用移动端缺口通道', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    messenger.setMockMethodCallHandler(channel, (_) async {
      fail('桌面不应访问移动端缺口');
    });
    expect(await SystemBarService.displayCutoutInsets(1), isNull);
  });
}
