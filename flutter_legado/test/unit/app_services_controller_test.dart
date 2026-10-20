import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/settings/application/app_services_controller.dart';
import 'package:flutter_legado/src/domain/contracts/local_server_service.dart';
import 'package:flutter_legado/src/domain/contracts/service_settings_repository.dart';
import 'package:flutter_legado/src/domain/contracts/general_settings_repository.dart';
import 'package:flutter_legado/src/domain/contracts/server_access_repository.dart';
import 'package:flutter_legado/src/domain/models/service_settings.dart';
import 'package:flutter_legado/src/domain/models/general_settings.dart';
import 'package:flutter_legado/src/domain/models/local_server_status.dart';
import 'package:flutter_legado/src/services/web_keep_alive_service.dart';

class _Server extends Mock implements LocalServerService {}

class _General extends Mock implements GeneralSettingsRepository {}

class _Access extends Mock implements ServerAccessRepository {}

class _Settings implements ServiceSettingsRepository {
  _Settings(this.calls);
  final List<String> calls;
  Future<ServiceSettings>? pendingLoad;
  @override
  ServiceSettings current = const ServiceSettings();
  @override
  Future<ServiceSettings> load() async => pendingLoad ?? current;
  @override
  Future<void> reload() async {}
  @override
  Stream<ServiceSettings> watch() => const Stream.empty();
  @override
  Future<void> settled() async {}
  @override
  Future<void> update(
    ServiceSettings Function(ServiceSettings) transform,
  ) async {
    current = transform(current);
    calls.add('保存');
  }
}

void main() {
  late _Server server;
  late _General general;
  late _Access access;
  late _Settings settings;
  late AppServicesController controller;
  late List<String> calls;
  late bool running;
  setUp(() {
    calls = [];
    running = false;
    server = _Server();
    general = _General();
    access = _Access();
    settings = _Settings(calls);
    when(() => general.load())
        .thenAnswer((_) async => const GeneralSettings(webPort: 2345));
    when(() => access.getToken()).thenAnswer((_) async => 'token');
    when(() => server.startServer(port: 2345)).thenAnswer((_) async {
      calls.add('启动2345');
      running = true;
    });
    when(() => server.stopServer()).thenAnswer((_) async {
      calls.add('停止');
      running = false;
    });
    when(() => server.getServerStatus()).thenAnswer((_) async {
      calls.add('状态');
      return LocalServerStatus(running: running, port: 2345);
    });
    controller = AppServicesController(
      server: server,
      settings: settings,
      general: general,
      access: access,
      startKeepAlive: () async {
        calls.add('保活');
        return WebKeepAliveStatus.active;
      },
      stopKeepAlive: () async {
        calls.add('停保活');
      },
      refreshAuto: () async {
        calls.add('任务刷新');
      },
      cancelAuto: () async {
        calls.add('任务取消');
      },
      log: (_, _) {},
    );
  });
  tearDown(() => controller.dispose());
  test('Web启动顺序与配置端口保持，重复点击不并发启动', () async {
    final port = Completer<GeneralSettings>();
    when(() => general.load()).thenAnswer((_) => port.future);
    final first = controller.setWeb(true);
    await controller.setWeb(true);
    expect(controller.state.webBusy, isTrue);
    port.complete(const GeneralSettings(webPort: 2345));
    await first;
    expect(calls, ['启动2345', '状态', '保活']);
    expect(settings.current.webAutoStart, isFalse);
    expect(controller.state.web, isTrue);
    expect(controller.state.webBusy, isFalse);
  });
  test('MCP失败保留原开关并解除忙状态', () async {
    when(() => server.setMcpPort(1236)).thenThrow(StateError('端口占用'));
    await expectLater(controller.setMcp(true), throwsStateError);
    expect(controller.state.mcp, isFalse);
    expect(controller.state.mcpBusy, isFalse);
  });
  test('控制器释放后不发布已经开始的服务操作的迟到状态', () async {
    final port = Completer<GeneralSettings>();
    when(() => general.load()).thenAnswer((_) => port.future);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.setWeb(true);
    final before = notifications;
    controller.dispose();
    port.complete(const GeneralSettings(webPort: 2345));
    await first;
    expect(controller.state.web, isFalse);
    expect(calls, ['启动2345', '状态']);
    expect(notifications, before);
    // 其它测试由tearDown释放；本例的第二次释放由明确的幂等保护处理。
  });
  test('页面读取只反映实际运行态，不应用自动启动偏好', () async {
    settings.current = const ServiceSettings(webAutoStart: true);
    await controller.load();
    expect(controller.state.web, isFalse);
    verifyNever(() => server.startServer(port: any(named: 'port')));
    expect(calls, ['状态']);
  });

  test('默认冷启动保持关闭，手动开启不保存自动启动意图', () async {
    await controller.initializeWebService();
    await controller.load();
    expect(controller.state.web, isFalse);
    verifyNever(() => server.startServer(port: any(named: 'port')));
    await controller.setWeb(true);
    expect(controller.state.web, isTrue);
    expect(settings.current.webAutoStart, isFalse);
    expect(calls, isNot(contains('保存')));
  });

  test('冷启动按配置端口自动启动一次，页面与前台刷新不重复启动', () async {
    settings.current = const ServiceSettings(webAutoStart: true);
    await Future.wait([
      controller.initializeWebService(),
      controller.initializeWebService(),
    ]);
    await controller.load();
    await controller.refreshWebStatus();
    expect(controller.state.web, isTrue);
    verify(() => server.startServer(port: 2345)).called(1);
    expect(calls.where((call) => call == '保活'), hasLength(1));
  });

  test('手动停止不改变自动启动偏好，回前台不自动重启', () async {
    settings.current = const ServiceSettings(webAutoStart: true);
    await controller.initializeWebService();
    await controller.setWeb(false);
    await controller.refreshWebStatus();
    await controller.initializeWebService();
    expect(controller.state.web, isFalse);
    expect(settings.current.webAutoStart, isTrue);
    verify(() => server.startServer(port: 2345)).called(1);
  });

  test('自动启动失败保留偏好并报告错误，手动操作可以重试', () async {
    settings.current = const ServiceSettings(webAutoStart: true);
    when(() => server.startServer(port: 2345)).thenThrow(StateError('端口占用'));
    await controller.initializeWebService();
    await controller.load();
    expect(controller.state.web, isFalse);
    expect(controller.state.webBusy, isFalse);
    expect(controller.state.webError, isA<StateError>());
    expect(settings.current.webAutoStart, isTrue);
    when(() => server.startServer(port: 2345))
        .thenAnswer((_) async => running = true);
    await controller.setWeb(true);
    expect(controller.state.web, isTrue);
    expect(controller.state.webError, isNull);
  });

  test('设置读取晚到不能覆盖用户手动停止的意图', () async {
    final loaded = Completer<ServiceSettings>();
    settings.pendingLoad = loaded.future;
    final startup = controller.initializeWebService();
    await controller.setWeb(false);
    loaded.complete(const ServiceSettings(webAutoStart: true));
    await startup;
    expect(controller.state.web, isFalse);
    verifyNever(() => server.startServer(port: any(named: 'port')));
  });

  test('刷新中的旧停止状态不覆盖已经启动的新状态', () async {
    final oldStatus = Completer<LocalServerStatus>();
    when(() => server.getServerStatus()).thenAnswer((_) => oldStatus.future);
    final refresh = controller.refreshWebStatus();
    when(
      () => server.getServerStatus(),
    ).thenAnswer((_) async => LocalServerStatus(running: running, port: 2345));
    await controller.setWeb(true);
    oldStatus.complete(const LocalServerStatus(running: false, port: 2345));
    await refresh;
    expect(controller.state.web, isTrue);
    expect(controller.state.webStatus!.running, isTrue);
  });

  test('运行状态读取失败保留最后确认值并显示错误，后续可恢复', () async {
    await controller.setWeb(true);
    when(() => server.getServerStatus()).thenThrow(StateError('状态读取失败'));
    await controller.refreshWebStatus();
    expect(controller.state.web, isTrue);
    expect(controller.state.webStatusReadError, isA<StateError>());
    running = false;
    when(
      () => server.getServerStatus(),
    ).thenAnswer((_) async => LocalServerStatus(running: running, port: 2345));
    await controller.refreshWebStatus();
    expect(controller.state.web, isFalse);
    expect(controller.state.webStatusReadError, isNull);
    expect(calls.last, '停保活');
  });

  test('启动返回但服务未运行时拒绝开启，不启动保活', () async {
    when(() => server.startServer(port: 2345)).thenAnswer((_) async {});
    await expectLater(controller.setWeb(true), throwsStateError);
    expect(controller.state.web, isFalse);
    expect(controller.state.webBusy, isFalse);
    expect(calls, isNot(contains('保活')));
  });
}
