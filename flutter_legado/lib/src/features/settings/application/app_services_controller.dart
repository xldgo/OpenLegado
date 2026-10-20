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
    this.webError,
    this.webStatusReadError,
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
  final Object? webError;
  final Object? webStatusReadError;
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
    Object? webError,
    bool clearWebError = false,
    Object? webStatusReadError,
    bool clearWebStatusReadError = false,
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
    webError: clearWebError ? null : webError ?? this.webError,
    webStatusReadError: clearWebStatusReadError
        ? null
        : webStatusReadError ?? this.webStatusReadError,
  );
}

/// 应用作用域拥有服务运行态；自动启动偏好与启停操作独立。— Codex + UI
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
  int _webGeneration = 0, _webIntent = 0;
  Future<void>? _webStartup;
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
          autoTask: config.autoTaskEnabled,
          mcpPort: config.mcpPort,
          mcp: config.mcpPort > 0,
          tokenConfigured: (token ?? '').trim().isNotEmpty,
        ),
      );
      if (!_closed && generation == _generation && config.autoTaskEnabled) {
        await refreshAuto();
      }
    } catch (e) {
      if (!_closed) log('读取服务状态失败', e);
    }
    await refreshWebStatus();
  }

  /// 仅冷启动执行一次；页面重建和前台恢复不重复应用自动启动偏好。
  Future<void> initializeWebService() => _webStartup ??= _startWebOnLaunch();

  Future<void> _startWebOnLaunch() async {
    final intent = _webIntent;
    try {
      final config = await settings.load();
      if (_closed || intent != _webIntent) return;
      if (!config.webAutoStart) {
        await refreshWebStatus();
        return;
      }
      final status = await server.getServerStatus();
      if (_closed || intent != _webIntent) return;
      if (status.running) {
        final keepAlive = await startKeepAlive();
        if (_closed || intent != _webIntent) return;
        _publish(
          _state.copyWith(
            web: true,
            webStatus: status,
            clearWebError: true,
            clearWebStatusReadError: true,
            keepAliveUnavailable: keepAlive == WebKeepAliveStatus.failed,
          ),
        );
      } else {
        await setWeb(true);
      }
    } catch (error) {
      // 用户已手动操作时，迟到的启动查询不得覆盖新的状态。
      if (!_closed && intent == _webIntent) {
        _publish(_state.copyWith(webError: error));
      }
      log('自动启动Web服务失败', error);
    }
  }

  /// 只核对运行态，失败保留最后确认值并明确报告错误，不重启服务。
  Future<void> refreshWebStatus() async {
    if (_closed || _state.webBusy) return;
    final generation = ++_webGeneration;
    try {
      final status = await server.getServerStatus();
      if (_closed || generation != _webGeneration || _state.webBusy) return;
      final wasRunning = _state.web;
      _publish(
        _state.copyWith(
          web: status.running,
          webStatus: status,
          clearWebStatusReadError: true,
          keepAliveUnavailable: status.running ? null : false,
        ),
      );
      if (wasRunning &&
          !status.running &&
          generation == _webGeneration &&
          !_state.webBusy) {
        await stopKeepAlive();
      }
    } catch (error) {
      if (!_closed && generation == _webGeneration) {
        _publish(_state.copyWith(webStatusReadError: error));
        log('读取Web服务状态失败', error);
      }
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
    _webIntent++;
    _webGeneration++;
    _publish(
      _state.copyWith(
        webBusy: true,
        clearWebError: true,
        clearWebStatusReadError: true,
      ),
    );
    try {
      if (enabled) {
        await server.startServer(port: await _webPort());
        final status = await server.getServerStatus();
        if (!status.running) throw StateError('Web服务未成功启动');
        // 应用作用域已释放时，已接受的服务操作可收尾，但不再申请保活资源。
        if (_closed) return;
        _publish(_state.copyWith(web: true, webStatus: status));
        final keepAlive = await startKeepAlive();
        _publish(
          _state.copyWith(
            web: true,
            webStatus: status,
            keepAliveUnavailable: keepAlive == WebKeepAliveStatus.failed,
          ),
        );
      } else {
        await server.stopServer();
        final status = await server.getServerStatus();
        if (status.running) throw StateError('Web服务未成功停止');
        _publish(_state.copyWith(web: false, webStatus: status));
        await stopKeepAlive();
        _publish(_state.copyWith(web: false, keepAliveUnavailable: false));
      }
    } catch (error) {
      try {
        final status = await server.getServerStatus();
        _publish(
          _state.copyWith(
            web: status.running,
            webStatus: status,
            webError: error,
          ),
        );
      } catch (_) {
        _publish(_state.copyWith(webError: error));
      }
      rethrow;
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
    _webGeneration++;
    _webIntent++;
    super.dispose();
  }
}
