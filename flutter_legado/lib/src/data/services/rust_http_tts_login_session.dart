import '../bridge/rust_errors.dart';

import 'dart:convert';

import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/source_login_session.dart';
import '../../models/models.dart';

/// 按引擎 ID 读取当前配置与独立登录缓存，复用 Rust 登录协议。— Codex + Bridge
final class RustHttpTtsLoginSession implements SourceLoginSession {
  const RustHttpTtsLoginSession(this.engine);
  final HttpTts engine;
  @override
  String get key => 'httpTts:${engine.id}';
  @override
  String get name => engine.name;
  @override
  bool get hasLoginScript => (engine.loginUrl ?? '').trim().isNotEmpty;
  @override
  bool get isV2 {
    try {
      final value = jsonDecode(engine.loginUi ?? '');
      return value is Map && value['version'] == 2;
    } catch (_) {
      return false;
    }
  }

  Future<String> _call(String operation, [String payload = '']) => rustFuture(
    () => bridge.httpTtsLogin(
      engineId: engine.id,
      operation: operation,
      payload: payload,
    ),
    operation: 'httpTtsLogin',
  );
  @override
  Future<String> loadUi(String state) => _call('ui', state);
  @override
  Future<String> executeV2(String input) => _call('action', input);
  @override
  Future<Map<String, dynamic>> execute(String script) async =>
      (jsonDecode(await _call('eval', script)) as Map).cast<String, dynamic>();
  @override
  Future<String> getInfo() => _call('info');
  @override
  Future<void> putInfo(String value) async {
    await _call('putInfo', value);
  }

  @override
  Future<String> getHeader() => _call('header');
  @override
  Future<void> putHeader(String value) async {
    await _call('putHeader', value);
  }

  @override
  Future<String> requestHeaders() => _call('headers');
}
