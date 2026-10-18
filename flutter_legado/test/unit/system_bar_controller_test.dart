import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/providers/theme/system_bar_controller.dart';
import 'package:flutter_legado/src/services/system_bar_service.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/utils/app_route_observer.dart';

const dayBars = (
  transparentStatusBar: false,
  immNavigationBar: false,
  appBarColor: Color(0xffffffff),
  navigationBarColor: Color(0xffeeeeee),
);
const nightBars = (
  transparentStatusBar: true,
  immNavigationBar: true,
  appBarColor: Color(0xff000000),
  navigationBarColor: Color(0xff111111),
);
const hiddenBars = (statusBarVisible: false, navigationBarVisible: false);
const visibleBars = (statusBarVisible: true, navigationBarVisible: true);

Future<void> flushOperations() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class RecordingRouteAware with RouteAware {
  final events = <String>[];
  @override
  void didPush() => events.add('进入');
  @override
  void didPushNext() => events.add('覆盖');
  @override
  void didPopNext() => events.add('返回');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('弹层保持页面归属，其上方独立页面及透明朗读页面正常切换', () {
    final observer = SystemBarRouteObserver();
    final reader = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final editor = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final sheet = AppRouter().generateRoute(
      const RouteSettings(name: AppRoutes.changeSource),
    );
    final player = AppRouter().generateRoute(
      const RouteSettings(name: AppRoutes.readAloudPlayer),
    );
    expect(sheet, isA<PopupRoute<dynamic>>());
    expect(player, isA<PageRoute<dynamic>>());
    final aware = RecordingRouteAware();
    observer.didPush(reader, null);
    observer.subscribe(aware, reader);
    observer.didPush(sheet, reader);
    expect(aware.events, ['进入']);
    observer.didPush(editor, sheet);
    observer.didPop(editor, sheet);
    observer.didPop(sheet, reader);
    observer.didPush(player, reader);
    observer.didPop(player, reader);
    expect(aware.events, ['进入', '覆盖', '返回', '覆盖', '返回']);
    observer.unsubscribe(aware);
  });

  test('阅读期间缓存应用新设置，退出后恢复最新样式', () async {
    final applied = <Object>[];
    final controller = SystemBarController(
      applyApplication: (bars) async => applied.add(bars),
      applyReader: (bars) async => applied.add(bars),
    );
    addTearDown(controller.dispose);
    final owner = Object();
    controller.updateApplication(dayBars);
    await flushOperations();
    controller.updateReader(owner, hiddenBars);
    await flushOperations();
    controller.updateApplication(nightBars);
    await flushOperations();
    expect(applied, [dayBars, hiddenBars]);
    controller.releaseReader(owner);
    await flushOperations();
    expect(applied, [dayBars, hiddenBars, nightBars]);
  });

  test('较慢的应用设置完成后执行最新阅读显隐，过期排队项跳过', () async {
    final firstApply = Completer<void>();
    final applied = <Object>[];
    final controller = SystemBarController(
      applyApplication: (bars) async {
        applied.add(bars);
        await firstApply.future;
      },
      applyReader: (bars) async => applied.add(bars),
    );
    addTearDown(controller.dispose);
    controller.updateApplication(dayBars);
    await flushOperations();
    final owner = Object();
    controller.updateReader(owner, visibleBars);
    controller.updateReader(owner, hiddenBars);
    await flushOperations();
    expect(applied, [dayBars]);
    firstApply.complete();
    await flushOperations();
    expect(applied, [dayBars, hiddenBars]);
  });

  test('页面离开及返回重新取得归属，旧阅读器释放不影响当前页面', () async {
    final applied = <Object>[];
    final controller = SystemBarController(
      applyApplication: (bars) async => applied.add(bars),
      applyReader: (bars) async => applied.add(bars),
    );
    addTearDown(controller.dispose);
    final firstReader = Object();
    final secondReader = Object();
    controller.updateApplication(dayBars);
    controller.updateReader(firstReader, hiddenBars);
    await flushOperations();
    controller.releaseReader(firstReader);
    await flushOperations();
    controller.updateReader(firstReader, hiddenBars);
    await flushOperations();
    controller.updateReader(secondReader, visibleBars);
    await flushOperations();
    controller.releaseReader(firstReader);
    await flushOperations();
    expect(applied, [hiddenBars, dayBars, hiddenBars, visibleBars]);
    controller.releaseReader(secondReader);
    await flushOperations();
    expect(applied.last, dayBars);
  });

  test('前台恢复重新应用当前阅读请求，销毁后不再下发排队请求', () async {
    final applied = <Object>[];
    final controller = SystemBarController(
      applyApplication: (bars) async => applied.add(bars),
      applyReader: (bars) async => applied.add(bars),
    );
    controller.updateReader(Object(), hiddenBars);
    await flushOperations();
    controller.reapply();
    await flushOperations();
    expect(applied, [hiddenBars, hiddenBars]);
    controller.updateApplication(nightBars);
    controller.updateReader(Object(), visibleBars);
    controller.dispose();
    await flushOperations();
    expect(applied, [hiddenBars, hiddenBars]);
  });

  test('平台下发失败不会阻断后续恢复', () async {
    final applied = <Object>[];
    final controller = SystemBarController(
      applyApplication: (bars) async => applied.add(bars),
      applyReader: (_) async => throw StateError('模拟平台下发失败'),
    );
    addTearDown(controller.dispose);
    final owner = Object();
    controller.updateApplication(dayBars);
    controller.updateReader(owner, hiddenBars);
    await flushOperations();
    controller.releaseReader(owner);
    await flushOperations();
    expect(applied, [dayBars]);
  });

  test('共享平台路径保持阅读显隐请求，应用恢复显式显示两个系统栏', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await SystemBarService.applyReader(
      statusBarVisible: false,
      navigationBarVisible: true,
    );
    await SystemBarService.apply(
      transparentStatusBar: dayBars.transparentStatusBar,
      immNavigationBar: dayBars.immNavigationBar,
      appBarColor: dayBars.appBarColor,
      navigationBarColor: dayBars.navigationBarColor,
    );
    final overlays = calls
        .where(
          (call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays',
        )
        .map((call) => call.arguments)
        .toList();
    expect(overlays, [
      ['SystemUiOverlay.bottom'],
      ['SystemUiOverlay.top', 'SystemUiOverlay.bottom'],
    ]);
    await flushOperations();
  });
}
