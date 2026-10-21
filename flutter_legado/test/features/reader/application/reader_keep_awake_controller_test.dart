import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/application/reader_keep_awake_controller.dart';
import 'package:flutter_legado/src/platform/display/screen_awake.dart';

void main() {
  late List<bool> calls;
  late ReaderKeepAwakeController controller;

  void initialize() {
    calls = [];
    controller = ReaderKeepAwakeController(
      ScreenAwake(toggle: (enabled) async => calls.add(enabled)),
    );
    addTearDown(controller.dispose);
  }

  testWidgets('默认不阻止熄屏，五分钟到期仅释放平台亮屏', (tester) async {
    initialize();
    controller.setVisible(true);
    await tester.pump();
    expect(calls, [false]);
    controller.configure(300);
    await tester.pump();
    expect(calls, [false, true]);
    await tester.pump(const Duration(seconds: 299));
    expect(calls.last, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, [false, true, false]);
    await tester.pump(const Duration(minutes: 10));
    expect(calls, [false, true, false]);
  });

  testWidgets('真实交互重置完整时长，重复配置或重建不延长', (tester) async {
    initialize();
    controller.configure(60);
    controller.setVisible(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 50));
    controller.onInteraction();
    await tester.pump(const Duration(seconds: 50));
    controller.configure(60);
    controller.setVisible(true);
    await tester.pump(const Duration(seconds: 10));
    expect(calls, [true, false]);
    controller.onInteraction();
    await tester.pump();
    expect(calls.last, isTrue);
    controller.dispose();
    await tester.pump();
  });

  testWidgets('常亮无到期任务，改为默认立即解除', (tester) async {
    initialize();
    controller.configure(-1);
    controller.setVisible(true);
    await tester.pump(const Duration(days: 1));
    expect(calls, [true]);
    controller.configure(0);
    await tester.pump();
    expect(calls, [true, false]);
  });

  testWidgets('后台或被覆盖解除，隐藏时交互无效，返回重新计时', (tester) async {
    initialize();
    controller.configure(60);
    controller.setVisible(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 50));
    controller.setVisible(false);
    controller.onInteraction();
    await tester.pump(const Duration(minutes: 2));
    expect(calls, [true, false]);
    controller.setVisible(true);
    await tester.pump(const Duration(seconds: 59));
    expect(calls.last, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(calls.last, isFalse);
  });

  testWidgets('修改时长立即重计时，释放后迟到交互不能重新获取', (tester) async {
    initialize();
    controller.configure(60);
    controller.setVisible(true);
    await tester.pump(const Duration(seconds: 50));
    controller.configure(600);
    await tester.pump(const Duration(seconds: 599));
    expect(calls, [true]);
    controller.dispose();
    controller.configure(-1);
    controller.setVisible(true);
    controller.onInteraction();
    await tester.pump(const Duration(minutes: 20));
    expect(calls, [true, false]);
  });

  testWidgets('启用尚未返回时退出，最终必须解除且不并发调用', (tester) async {
    final pending = Completer<void>();
    final writes = <bool>[];
    final screen = ScreenAwake(
      toggle: (enabled) async {
        writes.add(enabled);
        if (enabled) await pending.future;
      },
    );
    final reader = ReaderKeepAwakeController(screen);
    reader.configure(-1);
    reader.setVisible(true);
    await tester.pump();
    reader.dispose();
    await tester.pump();
    expect(writes, [true]);
    pending.complete();
    await tester.pump();
    expect(writes, [true, false]);
  });

  testWidgets('旧页面释放不得关闭仍可见的新页面亮屏', (tester) async {
    final writes = <bool>[];
    final screen = ScreenAwake(toggle: (enabled) async => writes.add(enabled));
    final oldPage = ReaderKeepAwakeController(screen);
    final newPage = ReaderKeepAwakeController(screen);
    oldPage.configure(-1);
    oldPage.setVisible(true);
    await tester.pump();
    newPage.configure(-1);
    newPage.setVisible(true);
    oldPage.dispose();
    await tester.pump();
    expect(writes, [true]);
    newPage.dispose();
    await tester.pump();
    expect(writes, [true, false]);
  });

  testWidgets('平台失败后真实交互可重试，失败不冒充成功', (tester) async {
    var attempts = 0;
    final screen = ScreenAwake(
      toggle: (enabled) async {
        if (enabled && ++attempts == 1) throw StateError('测试平台拒绝');
      },
    );
    final reader = ReaderKeepAwakeController(screen);
    reader.configure(-1);
    reader.setVisible(true);
    await tester.pump();
    expect(attempts, 1);
    reader.onInteraction();
    await tester.pump();
    expect(attempts, 2);
    reader.dispose();
    await tester.pump();
  });
}
