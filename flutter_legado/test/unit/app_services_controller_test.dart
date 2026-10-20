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
  @override
  ServiceSettings current = const ServiceSettings();
  @override
  Future<ServiceSettings> load() async => current;
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
  setUp(() {
    calls = [];
    server = _Server();
    general = _General();
    access = _Access();
    settings = _Settings(calls);
    when(() => general.load())
        .thenAnswer((_) async => const GeneralSettings(webPort: 2345));
    when(() => access.getToken()).thenAnswer((_) async => 'token');
    when(() => server.startServer(port: 2345)).thenAnswer((_) async {
      calls.add('启动2345');
    });
    when(() => server.getServerStatus()).thenAnswer((_) async {
      calls.add('状态');
      return const LocalServerStatus(running: true, port: 2345);
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
    expect(calls, ['启动2345', '状态', '保活', '保存']);
    expect(settings.current.webEnabled, isTrue);
    expect(controller.state.webBusy, isFalse);
  });
  test('MCP失败保留原开关并解除忙状态', () async {
    when(() => server.setMcpPort(1236)).thenThrow(StateError('端口占用'));
    await expectLater(controller.setMcp(true), throwsStateError);
    expect(controller.state.mcp, isFalse);
    expect(controller.state.mcpBusy, isFalse);
  });
  test('页面卸载不打断已经开始的服务与持久化事务，不再发布界面状态', () async {
    final port = Completer<GeneralSettings>();
    when(() => general.load()).thenAnswer((_) => port.future);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.setWeb(true);
    final before = notifications;
    controller.dispose();
    port.complete(const GeneralSettings(webPort: 2345));
    await first;
    expect(settings.current.webEnabled, isTrue);
    expect(notifications, before);
    // 其它测试由tearDown释放；本例的第二次释放由明确的幂等保护处理。
  });
  test('加载已保存的Web开关不自动启动服务', () async {
    settings.current = const ServiceSettings(webEnabled: true);
    await controller.load();
    expect(controller.state.web, isTrue);
    verifyNever(() => server.startServer(port: any(named: 'port')));
    expect(calls, ['状态']);
  });
}
