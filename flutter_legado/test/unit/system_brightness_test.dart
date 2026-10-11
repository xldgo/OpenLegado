// 既有亮度服务用例，适配 Android/iOS 共用的应用亮度接口。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/services/system_brightness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('github.com/aaassseee/screen_brightness');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  var brightness = 0.6;
  var changed = false;

  setUp(() {
    calls = [];
    brightness = 0.6;
    changed = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getApplicationScreenBrightness':
          return brightness;
        case 'hasApplicationScreenBrightnessChanged':
          return changed;
        case 'setApplicationScreenBrightness':
          brightness = (call.arguments as Map)['brightness'] as double;
          changed = true;
          return null;
        case 'resetApplicationScreenBrightness':
          changed = false;
          return null;
      }
      throw MissingPluginException();
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('未设置应用亮度时跟随系统', () async {
    expect(await SystemBrightness.isFollowingSystem(), isTrue);
    expect(calls.single.method, 'hasApplicationScreenBrightnessChanged');
  });

  test('开启跟随系统清除应用亮度覆盖', () async {
    changed = true;
    await SystemBrightness.setFollowSystem(true);
    expect(changed, isFalse);
    expect(calls.single.method, 'resetApplicationScreenBrightness');
  });

  test('插件缺失时不声明支持，操作失败不伪装成功', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    expect(await SystemBrightness.isSupported(), isFalse);
    await expectLater(
      SystemBrightness.setFollowSystem(true),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test('手动亮度模式不显示为跟随系统', () async {
    changed = true;
    expect(await SystemBrightness.isFollowingSystem(), isFalse);
  });

  test('关闭跟随系统保持当前亮度，使用应用接口', () async {
    await SystemBrightness.setFollowSystem(false);
    expect(changed, isTrue);
    expect(brightness, 0.6);
    expect(calls.map((call) => call.method), [
      'getApplicationScreenBrightness',
      'setApplicationScreenBrightness',
    ]);
    expect(calls.last.arguments, {'brightness': 0.6});
  });

  test('手动亮度读取与设置使用同一范围', () async {
    expect(await SystemBrightness.getBrightness(), 0.6);
    expect(await SystemBrightness.isSupported(), isTrue);
    await SystemBrightness.setBrightness(1.5);
    expect(brightness, 1.0);
  });
}
