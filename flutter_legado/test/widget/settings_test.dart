import '../fixtures/routing_test_app.dart';
import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/local_server_status.dart';

// 设置枢纽菜单 / 其他设置页 widget 测试
//
// 对齐 2026-08-13「我的」设置树（pref_main / pref_config_other）：
// - SettingsScreen：字典规则、备份与恢复全页、无导出日志
// - OtherSettingsScreen：语言/主界面/清理缓存；无创意「阅读/网络」分组

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/features/settings/presentation/other_settings_screen.dart';
import 'package:flutter_legado/src/features/settings/presentation/settings_screen.dart';
import 'package:flutter_legado/src/features/cache/presentation/download_cache_settings_screen.dart';
import 'package:flutter_legado/src/features/settings/presentation/webdav_settings_screen.dart';
import 'package:flutter_legado/src/services/web_keep_alive_service.dart';

import 'package:flutter_legado/src/providers/web_keep_alive_provider.dart';

import '../mocks/mocks.dart';

class _WebKeepAlive extends Mock implements WebKeepAliveService {}

void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;
  late _WebKeepAlive keepAlive;

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
      (_) async => const LocalServerStatus(running: false, port: 1122),
    );
    keepAlive = _WebKeepAlive();
    when(() => keepAlive.start())
        .thenAnswer((_) async => WebKeepAliveStatus.notApplicable);
    when(() => keepAlive.stop())
        .thenAnswer((_) async => WebKeepAliveStatus.idle);
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        webKeepAliveServiceProvider.overrideWithValue(keepAlive),
      ]),
    );
    addTearDown(container.dispose);
  });

  Widget wrap(Widget child, {Map<String, WidgetBuilder>? routes}) {
    return UncontrolledProviderScope(
      container: container,
      child: RoutingTestApp(home: child, routes: routes ?? const {}),
    );
  }

  /// 分组整体构建后，定位行并等待滚动布局完成。
  Future<void> dragTo(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen 枢纽菜单', () {
    testWidgets('下载与缓存入口进入真实独立页，返回仍为设置枢纽', (tester) async {
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      final navigation = AppRouter(
        routes: {
          ...AppRouter().routes,
          AppRoutes.home: (_) => const SettingsScreen(),
        },
      ).createRouter();
      addTearDown(navigation.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: navigation),
        ),
      );
      await tester.pumpAndSettle();
      await dragTo(tester, '下载与缓存');
      await tester.tap(find.text('下载与缓存'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadCacheSettingsScreen), findsOneWidget);
      expect(find.text('下载设置'), findsOneWidget);
      navigation.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(DownloadCacheSettingsScreen), findsNothing);
    });
    testWidgets('渲染顶部管理入口与设置/其他分组', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // 顶部管理入口（对标 pref_main；字典规则非「词典规则」）
      expect(find.text('书源管理'), findsOneWidget);
      expect(find.text('定时任务'), findsNWidgets(2));
      expect(find.text('TXT 目录规则'), findsOneWidget);
      expect(find.text('替换净化'), findsOneWidget);
      expect(find.text('字典规则'), findsOneWidget);
      expect(find.text('主题模式'), findsNothing);

      expect(find.text('我的'), findsOneWidget);
      // 外观组包含外观和阅读界面，高级与备份分别归入其他和同步与服务。
      await dragTo(tester, '备份与恢复');
      expect(find.text('设置', skipOffstage: false), findsNothing);
      expect(find.text('外观'), findsNWidgets(2));
      expect(find.text('高级'), findsOneWidget);
      expect(find.text('阅读界面'), findsOneWidget);
      expect(find.text('备份与恢复'), findsOneWidget);
      expect(find.text('主题设置'), findsNothing);

      // 已删除创意项
      expect(find.text('导出日志'), findsNothing);
      expect(find.text('词典规则'), findsNothing);
    });

    testWidgets('滚动可见其他分组（书签/阅读记录/关于）', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await dragTo(tester, '关于');
      await tester.pumpAndSettle();

      expect(find.text('书签'), findsOneWidget);
      expect(find.text('阅读记录'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    // [2026-10-06 登记待修 → 本批已修复] iOS 实机开启 Web 服务不可用：
    // 根因见 docs/IOS_WEB_SERVICE_ROOT_CAUSE_SURVEY_20261006.md（缺陷 A/B/C
    // 已随本批修复：绑定前置+0.0.0.0、Info.plist 补本地网络用途描述）。
    // 原「iOS 标记暂不可用」用例按登记要求改为本「iOS 可用」断言。
    testWidgets('Web 服务卡：iOS 可用（副题为正常文案，开关可用）', (tester) async {
      // debugDefaultTargetPlatformOverride 须在测试体内复位（框架在
      // addTearDown 之前校验 foundation 调试变量已归位），故用 try/finally。
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(wrap(const SettingsScreen()));
        await tester.pumpAndSettle();
        await dragTo(tester, 'Web 服务');
        await tester.pumpAndSettle();

        expect(find.text('用浏览器写源或看书'), findsOneWidget);
        expect(find.text('暂不可用，将在后续版本修复'), findsNothing);
        final card = find
            .ancestor(
              of: find.text('Web 服务'),
              matching: find.byType(SettingSwitchRow),
            )
            .first;
        expect(
          tester
              .widget<Switch>(
                find.descendant(of: card, matching: find.byType(Switch)),
              )
              .onChanged,
          isNotNull,
          reason: 'iOS 上 Web 服务开关应可用（门控已移除）',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Web 服务卡：非 iOS 维持原形态（副题与开关可用）', (tester) async {
      // 明示 android 防上一用例平台残留；try/finally 理由同上
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(wrap(const SettingsScreen()));
        await tester.pumpAndSettle();
        await dragTo(tester, 'Web 服务');
        await tester.pumpAndSettle();

        expect(find.text('用浏览器写源或看书'), findsOneWidget);
        expect(find.text('暂不可用，将在后续版本修复'), findsNothing);
        final card = find
            .ancestor(
              of: find.text('Web 服务'),
              matching: find.byType(SettingSwitchRow),
            )
            .first;
        expect(
          tester
              .widget<Switch>(
                find.descendant(of: card, matching: find.byType(Switch)),
              )
              .onChanged,
          isNotNull,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // [Web 端口缺陷修复 | 2026-10-06] 开关启动须使用「其他设置 → Web 服务端口」
    // 配置（PrefKeys.webPort）：原实现在此调 startServer() 不传参，恒用默认
    // 1122，设置页端口形同虚设（对齐原版 WebService.kt:244 启动读配置端口）。
    testWidgets('Web 服务开关：启动使用配置端口 webPort=8080', (tester) async {
      SharedPreferences.setMockInitialValues({'webPort': 8080});
      final startedPorts = <int>[];
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      ).thenAnswer((inv) async {
        startedPorts.add(inv.namedArguments[#port] as int);
      });
      when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
        (_) async => const LocalServerStatus(running: true, port: 8080),
      );

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, 'Web 服务');
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Web 服务'),
            matching: find.byType(SettingSwitchRow),
          )
          .first;
      final switchFinder = find.descendant(
        of: card,
        matching: find.byType(Switch),
      );
      // 直接触发 onChanged（等价用户点开关）：NestedScrollView 下
      // ensureVisible/tap 会把卡片滚出视口导致 finder 失效
      tester.widget<Switch>(switchFinder).onChanged!(true);
      await tester.pumpAndSettle();

      expect(startedPorts, [8080], reason: '应把「其他设置」配置端口传给 startServer');
    });

    testWidgets('Web 服务开关：未配置端口回落默认 1122', (tester) async {
      final startedPorts = <int>[];
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      ).thenAnswer((inv) async {
        startedPorts.add(inv.namedArguments[#port] as int);
      });
      when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
        (_) async => const LocalServerStatus(running: true, port: 1122),
      );

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, 'Web 服务');
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Web 服务'),
            matching: find.byType(SettingSwitchRow),
          )
          .first;
      final switchFinder = find.descendant(
        of: card,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(switchFinder).onChanged!(true);
      await tester.pumpAndSettle();

      expect(startedPorts, [1122], reason: '未设置 webPort 时默认 1122（对齐原版）');
    });

    testWidgets('Web 服务开关：越界 webPort 回落默认 1122（防手改 prefs）', (tester) async {
      SharedPreferences.setMockInitialValues({'webPort': 500});
      final startedPorts = <int>[];
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      ).thenAnswer((inv) async {
        startedPorts.add(inv.namedArguments[#port] as int);
      });
      when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
        (_) async => const LocalServerStatus(running: true, port: 1122),
      );

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, 'Web 服务');
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Web 服务'),
            matching: find.byType(SettingSwitchRow),
          )
          .first;
      final switchFinder = find.descendant(
        of: card,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(switchFinder).onChanged!(true);
      await tester.pumpAndSettle();

      expect(startedPorts, [1122], reason: '越界端口（<1024）按默认 1122 兜底');
    });

    // 页面只验证保活能力接线；音轨、共享会话与平台失败由服务单元测试覆盖。
    testWidgets('Web 服务开关：start 成功接保活 true，stop 成功接保活 false', (tester) async {
      var running = false;
      when(() => keepAlive.start())
          .thenAnswer((_) async => WebKeepAliveStatus.active);

      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      ).thenAnswer((_) async => running = true);
      when(() => mockApi.localServerService.stopServer())
          .thenAnswer((_) async => running = false);
      when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
        (_) async => LocalServerStatus(running: running, port: 1122),
      );

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, 'Web 服务');
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Web 服务'),
            matching: find.byType(SettingSwitchRow),
          )
          .first;
      final switchFinder = find.descendant(
        of: card,
        matching: find.byType(Switch),
      );

      tester.widget<Switch>(switchFinder).onChanged!(true);
      await tester.pumpAndSettle();

      verify(() => keepAlive.start()).called(1);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      tester.widget<Switch>(switchFinder).onChanged!(false);
      await tester.pumpAndSettle();

      verify(() => keepAlive.stop()).called(1);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });

    // [2026-10-07 | 方案 A 兜底] 保活启动失败不得阻断 Web 服务：开关仍开启、
    // 副题提示「后台保活不可用，请保持 App 打开」。
    testWidgets('Web 服务开关：保活失败回退提示且不阻断服务开启', (tester) async {
      when(() => keepAlive.start())
          .thenAnswer((_) async => WebKeepAliveStatus.failed);

      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      ).thenAnswer((_) async {});
      when(() => mockApi.localServerService.getServerStatus()).thenAnswer(
        (_) async => const LocalServerStatus(running: true, port: 1122),
      );

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, 'Web 服务');
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Web 服务'),
            matching: find.byType(SettingSwitchRow),
          )
          .first;
      final switchFinder = find.descendant(
        of: card,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(switchFinder).onChanged!(true);
      await tester.pumpAndSettle();

      expect(find.textContaining('后台保活不可用'), findsOneWidget);
      expect(
        tester.widget<Switch>(switchFinder).value,
        isTrue,
        reason: '保活失败不阻断 Web 服务开关（方案 A 兜底）',
      );
    });

    testWidgets('从我的页直接进入备份与恢复全页 WebDAV/备份设置', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsScreen(),
          routes: {
            AppRoutes.webdavSettings: (_) => const WebDavSettingsScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 我的页直接进入备份与恢复，不经过设置主页。
      await dragTo(tester, '备份与恢复');
      await tester.drag(find.byType(ListView), const Offset(0, 140));
      await tester.pumpAndSettle();
      await tester.tap(find.text('备份与恢复'));
      await tester.pumpAndSettle();

      // 全页（非底部弹窗）：AppBar + 配置项
      expect(find.text('备份与恢复'), findsWidgets);
      expect(find.text('WebDAV 服务器地址'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('备份'), 80);
      await tester.pumpAndSettle();
      expect(find.text('备份'), findsOneWidget);
      expect(find.text('恢复'), findsOneWidget);
      expect(find.text('恢复忽略列表'), findsOneWidget);
    });
  });

  group('OtherSettingsScreen 其他设置', () {
    testWidgets('自动启动只保存偏好，重新打开仍显示保存值，不立即启动服务', (tester) async {
      final configs = <String, String>{};
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((inv) async => configs[inv.positionalArguments[0]]);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenAnswer((inv) async {
            configs[inv.positionalArguments[0] as String] =
                inv.positionalArguments[1] as String;
          });
      await tester.pumpWidget(wrap(const OtherSettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, '启动应用时开启 Web 服务');
      final row = find.widgetWithText(SettingSwitchRow, '启动应用时开启 Web 服务');
      expect(tester.widget<SettingSwitchRow>(row).value, isFalse);
      tester.widget<SettingSwitchRow>(row).onChanged!(true);
      await tester.pumpAndSettle();
      expect(configs['webServiceAutoStart'], 'true');
      expect(tester.widget<SettingSwitchRow>(row).value, isTrue);
      verifyNever(
        () => mockApi.localServerService.startServer(port: any(named: 'port')),
      );
      await tester.pumpWidget(
        wrap(const OtherSettingsScreen(key: ValueKey('reopen'))),
      );
      await tester.pumpAndSettle();
      await dragTo(tester, '启动应用时开启 Web 服务');
      expect(tester.widget<SettingSwitchRow>(row).value, isTrue);
    });

    testWidgets('自动启动保存失败保留原开关并显示原因', (tester) async {
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.configRepository.setConfig(any(), any()))
          .thenThrow(StateError('存储失败'));
      await tester.pumpWidget(wrap(const OtherSettingsScreen()));
      await tester.pumpAndSettle();
      await dragTo(tester, '启动应用时开启 Web 服务');
      final row = find.widgetWithText(SettingSwitchRow, '启动应用时开启 Web 服务');
      tester.widget<SettingSwitchRow>(row).onChanged!(true);
      await tester.pumpAndSettle();
      expect(tester.widget<SettingSwitchRow>(row).value, isFalse);
      expect(find.textContaining('Web 服务设置保存失败：'), findsOneWidget);
      expect(find.textContaining('存储失败'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('保留语言和主界面，下载与缓存设置迁到独立页', (tester) async {
      when(() => mockApi.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(wrap(const OtherSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('语言'), findsWidgets);
      expect(find.text('主界面'), findsOneWidget);

      // 创意分组已删
      expect(find.text('阅读设置'), findsNothing);
      expect(find.text('网络设置'), findsNothing);
      expect(find.text('缓存管理'), findsNothing);

      expect(find.text('清理缓存'), findsNothing);
      expect(find.text('压缩数据库'), findsNothing);
      expect(find.text('更新和搜索线程数'), findsNothing);
    });
  });
}
