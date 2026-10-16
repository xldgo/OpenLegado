import 'dart:convert';

import '../domain/contracts/webview_bridge_service.dart';
import '../domain/models/webview_request.dart';
import '../services/platform_bridge_service.dart';

/// 平台载荷字段映射与Cookie解码不进入监听控件。— Codex + Bridge
class NativeWebViewRequestExecutor implements WebViewRequestExecutor {
  NativeWebViewRequestExecutor({required this._dispatch});
  final Future<WebViewEvalOutcome> Function(Map<String, dynamic>) _dispatch;
  @override
  Future<WebViewExecutionResult> execute(WebViewRequest request) async {
    final outcome = await _dispatch({
      'action': request.action,
      'html': request.html,
      'url': request.url,
      'js': request.js,
      'sourceRegex': request.sourceRegex,
      'overrideUrlRegex': request.overrideUrlRegex,
      'cacheFirst': request.cacheFirst,
      'delayTime': request.delayTime,
      'isRule': request.isRule,
      'result': request.result,
      'sourceKey': request.sourceKey,
      'cookie': request.cookie,
    });
    final cookies = <String, String>{};
    if (outcome.cookiesJson.isNotEmpty) {
      final raw = jsonDecode(outcome.cookiesJson);
      if (raw is! Map<String, dynamic> || raw.values.any((v) => v is! String)) {
        throw const FormatException('WebView返回的Cookie不是字符串映射');
      }
      cookies.addAll(raw.cast<String, String>());
    }
    return WebViewExecutionResult(result: outcome.result, cookies: cookies);
  }
}
