import 'dart:convert';

import 'webview_page_bridge.dart';

import '../domain/contracts/webview_bridge_service.dart';
import '../domain/models/webview_request.dart';
import '../services/platform_bridge_service.dart';

/// 平台载荷字段映射与Cookie解码不进入监听控件。— Codex + Bridge
class NativeWebViewRequestExecutor implements WebViewRequestExecutor {
  NativeWebViewRequestExecutor({
    required this._dispatch,
    this._cancel,
    this._pageCall,
  });
  final Future<String> Function(String, WebViewPageCall)? _pageCall;
  final Future<void> Function(String)? _cancel;
  @override
  Future<void> cancel(String key) async {
    await _cancel?.call(key);
  }

  final Future<WebViewEvalOutcome> Function(Map<String, dynamic>) _dispatch;
  @override
  Future<WebViewExecutionResult> execute(WebViewRequest request) async {
    final outcome = await _dispatch({
      if (_pageCall != null)
        'pageBridge': WebViewPageBridge((call) => _pageCall(request.key, call)),
      'key': request.key,
      'headers': request.headers,
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
    return WebViewExecutionResult(
      result: outcome.result,
      finalUrl: outcome.finalUrl.isEmpty ? request.url : outcome.finalUrl,
      error:
          outcome.error ??
          (outcome.result.startsWith('[ERROR]') ? outcome.result : null),
      cookies: cookies,
    );
  }
}
