import 'package:flutter/foundation.dart';

import '../../../domain/contracts/local_server_service.dart';
import '../../../domain/contracts/service_settings_repository.dart';
import '../../../domain/contracts/general_settings_repository.dart';
import '../../../domain/contracts/server_access_repository.dart';
import '../../../domain/models/local_server_status.dart';
import '../../../services/web_keep_alive_service.dart';

class AppServicesState {
  const AppServicesState({
    this.web = false,
    this.mcp = false,
    this.autoTask = false,
    this.webBusy = false,
    this.mcpBusy = false,
    this.keepAliveUnavailable = false,
    this.mcpPort = 0,
    this.tokenConfigured = true,
    this.webStatus,
  });
  final bool web,
      mcp,
      autoTask,
      webBusy,
      mcpBusy,
      keepAliveUnavailable,
      tokenConfigured;
  final int mcpPort;
  final LocalServerStatus? webStatus;
  AppServicesState copyWith({
    bool? web,
    bool? mcp,
    bool? autoTask,
    bool? webBusy,
    bool? mcpBusy,
    bool? keepAliveUnavailable,
    bool? tokenConfigured,
    int? mcpPort,
    LocalServerStatus? webStatus,
  }) => AppServicesState(
    web: web ?? this.web,
    mcp: mcp ?? this.mcp,
    autoTask: autoTask ?? this.autoTask,
    webBusy: webBusy ?? this.webBusy,
    mcpBusy: mcpBusy ?? this.mcpBusy,
    keepAliveUnavailable: keepAliveUnavailable ?? this.keepAliveUnavailable,
    tokenConfigured: tokenConfigured ?? this.tokenConfigured,
    mcpPort: mcpPort ?? this.mcpPort,
    webStatus: webStatus ?? this.webStatus,
  );
}

/// 控制运行态、偏好及保活的顺序；页面仅展示状态和错误。— Codex + UI
class AppServicesController extends ChangeNotifier {
  AppServicesController({
    required this.server,
    required this.settings,
    required this.general,
    required this.access,
    required this.startKeepAlive,
    required this.stopKeepAlive,
    required this.refreshAuto,
    required this.cancelAuto,
    required this.log,
  });
  final LocalServerService server;
  final ServiceSettingsRepository settings;
  final GeneralSettingsRepository general;
  final ServerAccessRepository access;
  final Future<WebKeepAliveStatus> Function() startKeepAlive;
  final Future<void> Function() stopKeepAlive, refreshAuto, cancelAuto;
  final void Function(String, Object?) log;
  AppServicesState _state = const AppServicesState();
  AppServicesState get state => _state;
  bool _closed = false, _portWarningLogged = false;
  int _generation = 0;
  void _publish(AppServicesState state) {
    if (_closed) return;
    _state = state;
    notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      await settings.reload();
      final config = settings.current;
      final token = await access.getToken();
      if (_closed || generation != _generation) return;
      _publish(
        _state.copyWith(
          web: config.webEnabled,
          autoTask: config.autoTaskEnabled,
          mcpPort: config.mcpPort,
          mcp: config.mcpPort > 0,
          tokenConfigured: (token ?? '').trim().isNotEmpty,
        ),
      );
      if (config.webEnabled) {
        final status = await server.getServerStatus();
        if (!_closed && generation == _generation) {
          _publish(_state.copyWith(webStatus: status));
        }
      }
      if (!_closed && generation == _generation && config.autoTaskEnabled) {
        await refreshAuto();
      }
    } catch (e) {
      if (!_closed) log('读取服务状态失败', e);
    }
  }

  Future<int> _webPort() async {
    final port = (await general.load()).webPort;
    if (port >= 1024 && port <= 60000) return port;
    if (!_portWarningLogged) {
      _portWarningLogged = true;
      log('Web端口越界，回退1122', port);
    }
    return 1122;
  }

  Future<void> setWeb(bool enabled) async {
    if (_closed || _state.webBusy) return;
    _generation++;
    _publish(_state.copyWith(webBusy: true));
    try {
      if (enabled) {
        await server.startServer(port: await _webPort());
        final status = await server.getServerStatus();
        final keepAlive = await startKeepAlive();
        await settings.update((s) => s.copyWith(webEnabled: true));
        _publish(
          _state.copyWith(
            web: true,
            webStatus: status,
            keepAliveUnavailable: keepAlive == WebKeepAliveStatus.failed,
          ),
        );
      } else {
        await server.stopServer();
        await stopKeepAlive();
        await settings.update((s) => s.copyWith(webEnabled: false));
        _publish(_state.copyWith(web: false, keepAliveUnavailable: false));
      }
    } finally {
      _publish(_state.copyWith(webBusy: false));
    }
  }

  Future<void> setMcp(bool enabled) async {
    if (_closed || _state.mcpBusy) return;
    _generation++;
    _publish(_state.copyWith(mcpBusy: true));
    try {
      final port = enabled ? (_state.mcpPort > 0 ? _state.mcpPort : 1236) : 0;
      await server.setMcpPort(port);
      await settings.reload();
      _publish(_state.copyWith(mcp: enabled, mcpPort: port));
    } finally {
      _publish(_state.copyWith(mcpBusy: false));
    }
  }

  Future<void> setAutoTask(bool enabled) async {
    if (_closed) return;
    _generation++;
    _publish(_state.copyWith(autoTask: enabled));
    try {
      await settings.update((s) => s.copyWith(autoTaskEnabled: enabled));
    } catch (e) {
      log('保存自动任务开关失败', e);
    }
    if (enabled) {
      await refreshAuto();
    } else {
      await cancelAuto();
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    super.dispose();
  }
}
