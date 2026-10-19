import '../fixtures/routing_test_app.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/app.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';
import 'package:flutter_legado/src/widgets/crash_log_dialog.dart';

/// [P2-13 2026-09-18] 启动崩溃日志弹窗回归测试
///
/// 缺陷（P2-13）：`_LegadoAppState.initState` 曾在 **State 自身 context**
/// 上 `showDialog`。该 context 是 MaterialApp（及其内部 Navigator）的
/// **祖先**，`showDialog` → `Navigator.of(context)` 只能向上查找，
/// 其上方没有 Navigator → `Null check operator used on a null value`。
/// 异常被 main.dart 注册的 `FlutterError.onError` 捕获后
/// `CrashLogService.logError` 重写 `crash_log.txt` 并重新置崩溃标记
/// → 下次启动再次弹窗、再次抛异常，形成启动崩溃循环
/// （crash_log.txt 每次启动都被刷新）。
///
/// 修复（P2-13）：弹窗改挂 `PlatformBridgeService.navigatorKey.currentContext`
/// （MaterialApp.navigatorKey 装配的全局 Navigator，与 DeepLinkService
/// attach 模式同源）。
///
/// 调度（P2-13b → 现行）：闪屏路由 /welcome 存续期间，`pushReplacement(home)`
/// 会把位于栈顶的弹窗路由一并替换（用户看不到提示、crash_log 永不清除），
/// 那时用 TopRouteWatcher 等闪屏退出。闪屏路由已按上游移除（冷启动直接进
/// 主页），现在只需逐帧等待 Navigator 装配成功即可弹出。
///
/// 本测试复刻生产结构（MaterialApp 装配生产 navigatorKey + 生产调度入口）
/// 验证：
/// 1. 携带 lastCrashLog 启动 → 弹窗正常弹出，全程无异常；
/// 2. navigatorKey 未装配 → 静默跳过，不抛异常、不丢数据。
///
/// 说明：完整 LegadoApp 依赖 Rust FFI（见 test/widget_test.dart 注释），
/// 无法在纯 widget 测试环境运行；故通过 [LegadoApp.scheduleCrashLogDialog]
/// （生产调度入口，app.dart initState 的同一调用）+ 复刻调度路径的
/// harness 覆盖修复逻辑。

/// 与生产 crash_log.txt 一致的样例崩溃日志（CrashLogService.logError 格式）
const _sampleCrashLog =
    '===== 崩溃日志 =====\n'
    '时间: 2026-09-18 09:30:00\n'
    '错误: TestException: 启动崩溃循环回归样例\n'
    '----- 堆栈信息 -----\n'
    '#0 _LegadoAppState.showDialog (file:///legado/lib/app.dart)\n'
    '===== 日志结束 =====\n';

void main() {
  testWidgets('启动携带 lastCrashLog：崩溃弹窗经全局 navigatorKey 弹出，全程无异常', (
    tester,
  ) async {
    // 生产结构：根 harness（复刻 LegadoApp，应用根 widget）包裹装配了
    // 生产全局 navigatorKey 的 MaterialApp（app.dart build() 同源）；
    // harness initState 复刻 LegadoApp.initState 的生产调度路径
    await tester.pumpWidget(
      _CrashDialogHarness(
        lastCrashLog: _sampleCrashLog,
        child: RoutingTestApp(
          navigatorKey: PlatformBridgeService.navigatorKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );

    // 首帧后 Navigator 已装配 → postFrameCallback 弹窗
    await tester.pump();

    // 1) 弹窗已挂在全局 Navigator 上
    expect(find.byType(CrashLogDialog), findsOneWidget);
    // 2) 弹窗内容正确渲染（崩溃时间取自日志行）
    expect(find.text('崩溃时间: 2026-09-18 09:30:00'), findsOneWidget);
    // 3) 弹窗的 context 上方确有 Navigator（修复点：旧实现挂在
    // Navigator 的祖先 context 上，此处向上查找必失败）
    final dialogContext = tester.element(find.byType(CrashLogDialog));
    expect(
      dialogContext.findAncestorWidgetOfExactType<Navigator>(),
      isNotNull,
      reason: '弹窗必须挂在 Navigator 子树内（navigatorKey.currentContext）',
    );
    // 4) 全程无异常（原缺陷在此处抛 "Null check operator used on a null value"）
    expect(tester.takeException(), isNull);

    // 5) 用户点「确定」→ 弹窗正常关闭、无异常（关闭后 clearCrashLog 删除
    // crash_log.txt，下次启动 getLastCrashLog 为 null → 不再弹、不再重写，
    // 崩溃循环断开；测试环境未 init 服务，clearCrashLog 静默早退）
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(CrashLogDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigatorKey 未装配：静默跳过弹窗，不抛异常', (tester) async {
    // 宿主用独立 key（生产 key 未装配）→ currentContext 为 null
    final isolatedKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _CrashDialogHarness(
        lastCrashLog: _sampleCrashLog,
        child: RoutingTestApp(
          navigatorKey: isolatedKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
    await tester.pump();

    expect(PlatformBridgeService.navigatorKey.currentContext, isNull);
    // 生产调度入口返回 false（未调度），不抛异常；崩溃日志仍在磁盘，
    // 下次启动继续提示，不丢数据
    expect(LegadoApp.showCrashLogDialog(_sampleCrashLog), isFalse);
    expect(find.byType(CrashLogDialog), findsNothing);
    // 重试期间每次尝试都会主动预约下一帧，pumpAndSettle 可把 90 帧重试
    // 全部排空；否则残余回调会落到后续用例的帧里——那时生产
    // navigatorKey 已由下一个用例装配，旧回调会误弹崩溃提示。
    await tester.pumpAndSettle();
    expect(find.byType(CrashLogDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lastCrashLog 为空：不调度弹窗', (tester) async {
    await tester.pumpWidget(
      _CrashDialogHarness(
        child: RoutingTestApp(
          navigatorKey: PlatformBridgeService.navigatorKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CrashLogDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// 复刻 [app.dart] `_LegadoAppState.initState` 的崩溃弹窗调度路径
/// （现行：initState 调 [LegadoApp.scheduleCrashLogDialog] 逐帧重试，
/// 直至 Navigator 装配完成才弹窗）。
/// harness 置于应用根部（复刻 LegadoApp 作为应用根 widget 的位置），
/// 使测试可脱离 FFI 依赖验证生产调度入口。
class _CrashDialogHarness extends StatefulWidget {
  final String? lastCrashLog;

  /// 被包裹的应用内容（如装配了生产 navigatorKey 的 MaterialApp）
  final Widget? child;

  const _CrashDialogHarness({this.lastCrashLog, this.child});

  @override
  State<_CrashDialogHarness> createState() => _CrashDialogHarnessState();
}

class _CrashDialogHarnessState extends State<_CrashDialogHarness> {
  @override
  void initState() {
    super.initState();
    // 复刻现行生产调用点（app.dart initState）：逐帧重试至 Navigator 就绪。
    // LegadoApp 是应用根 widget，不随路由切换卸载，故 isAlive 恒为 true
    //（与生产 `() => mounted` 等价）。
    if (widget.lastCrashLog != null && widget.lastCrashLog!.isNotEmpty) {
      LegadoApp.scheduleCrashLogDialog(widget.lastCrashLog!, () => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const Scaffold(body: Center(child: Text('harness')));
  }
}
