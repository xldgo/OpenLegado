/// 后台DOM请求；源身份、Cookie与规则参数保持完整。— Codex + Bridge
class WebViewRequest {
  const WebViewRequest({
    required this.key,
    this.action = 'webView',
    this.html = '',
    this.url = '',
    this.js = '',
    this.sourceRegex = '',
    this.overrideUrlRegex = '',
    this.cacheFirst = false,
    this.delayTime = 0,
    this.isRule = false,
    this.result = '',
    this.sourceKey = '',
    this.cookie = '',
    this.createdAtMs = 0,
  });
  final String key;
  final String action;
  final String html;
  final String url;
  final String js;
  final String sourceRegex;
  final String overrideUrlRegex;
  final bool cacheFirst;
  final int delayTime;
  final bool isRule;
  final String result;
  final String sourceKey;
  final String cookie;
  final int createdAtMs;
}

class WebViewExecutionResult {
  WebViewExecutionResult({
    required this.result,
    Map<String, String> cookies = const {},
  }) : cookies = Map.unmodifiable(cookies);
  final String result;
  final Map<String, String> cookies;
}
