import 'dart:convert';

import '../../models/misc.dart' show LoginKeyValue;
import '../models/source_login_credentials.dart';

/// 手动界面的 JSON 转换，沿用已有宽松解析与字段合并。— Codex + UI
final class SourceLoginCodec {
  const SourceLoginCodec();

  SourceLoginCredentials decode(String infoJson, String headerJson) =>
      SourceLoginCredentials(
        token: _extractToken(infoJson),
        cookies: _extractCookies(headerJson),
        headers: _extractHeaders(headerJson),
      );

  /// 旧配置只在新存储两项均为空时使用，不在这里写入或清理。
  SourceLoginCredentials decodeLegacy(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final token = data['token'] as String? ?? '';
    final headerMap = <String, String>{
      for (final e in _parseEntries(data['headers'])) e.name: e.value,
    };
    final cookie = _parseEntries(data['cookies'])
        .map((e) => '${e.name}=${e.value}')
        .join('; ');
    if (cookie.isNotEmpty) headerMap['Cookie'] = cookie;
    return decode(
      token.isEmpty ? '' : jsonEncode({'token': token}),
      jsonEncode(headerMap),
    );
  }

  /// 在首个异步写入前完成两份 JSON，避免两次写入读取不同编辑状态。
  ({String infoJson, String headerJson}) encode(SourceLoginCredentials value) {
    final headerMap = <String, String>{
      for (final e in value.headers)
        if (e.name.isNotEmpty) e.name: e.value,
    };
    final cookie = value.cookies.map((e) => '${e.name}=${e.value}').join('; ');
    if (cookie.isNotEmpty) headerMap['Cookie'] = cookie;
    return (
      infoJson: jsonEncode({'token': value.token}),
      headerJson: jsonEncode(headerMap),
    );
  }

  /// 从 userInfo JSON 提取 token（含 token 字段则取之，否则原样作为 token）
  String _extractToken(String infoJson) {
    if (infoJson.isEmpty) return '';
    try {
      final info = jsonDecode(infoJson);
      if (info is Map<String, dynamic> && info['token'] is String) {
        return info['token'] as String;
      }
      return infoJson;
    } catch (_) {
      return infoJson;
    }
  }

  /// 从 loginHeader JSON 拆出 Cookie 键值对列表
  List<LoginKeyValue> _extractCookies(String headerJson) {
    if (headerJson.isEmpty) return const [];
    try {
      final map = jsonDecode(headerJson) as Map<String, dynamic>;
      final cookieStr = map.entries
          .firstWhere(
            (e) => e.key.toLowerCase() == 'cookie',
            orElse: () => const MapEntry('', ''),
          )
          .value
          .toString();
      if (cookieStr.isEmpty) return const [];
      return cookieStr
          .split(';')
          .map((pair) => pair.trim())
          .where((pair) => pair.contains('='))
          .map((pair) {
            final idx = pair.indexOf('=');
            return LoginKeyValue(
              name: pair.substring(0, idx).trim(),
              value: pair.substring(idx + 1).trim(),
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 从 loginHeader JSON 提取非 Cookie 的 header 键值对列表
  List<LoginKeyValue> _extractHeaders(String headerJson) {
    if (headerJson.isEmpty) return const [];
    try {
      final map = jsonDecode(headerJson) as Map<String, dynamic>;
      return map.entries
          .where((e) => e.key.toLowerCase() != 'cookie')
          .map((e) => LoginKeyValue(name: e.key, value: e.value.toString()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 解析键值对列表
  List<LoginKeyValue> _parseEntries(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LoginKeyValue.fromJson)
        .toList();
  }
}
