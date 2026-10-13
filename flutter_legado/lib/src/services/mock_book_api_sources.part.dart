// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiSources mixin：书架 / 书源 / 校验 / 登录 / 验证码。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiSources on MockBookApiStore implements BookApi {
  // ========== 书源操作 ==========

  /// Mock：短延迟；无真实 Cookie 存储，调用即成功（对齐 void 语义）
  @override
  Future<void> clearCookie(String url) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (url.trim().isEmpty) {
      throw Exception('url 不能为空');
    }
  }

  @override
  Future<bool> looksLikeCurl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final t = text.trimLeft().toLowerCase();
    return t == 'curl' ||
        t.startsWith('curl ') ||
        t.startsWith('curl.exe') ||
        t.startsWith('curl\t');
  }

  @override
  Future<String> curlToAnalyzeUrl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('[CURL_EMPTY_INPUT]');
    // Mock：仅支持最简 `curl <url>` / `curl -L <url>`
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty || !parts.first.toLowerCase().startsWith('curl')) {
      throw Exception('[CURL_INVALID]');
    }
    String? url;
    var follow = false;
    for (final p in parts.skip(1)) {
      if (p == '-L' || p == '--location') {
        follow = true;
        continue;
      }
      if (p.startsWith('-')) continue;
      url = p.replaceAll("'", '').replaceAll('"', '');
      break;
    }
    if (url == null || url.isEmpty) throw Exception('[CURL_MISSING_URL]');
    if (follow) return url;
    return '$url,{"followRedirects":false}';
  }

  @override
  Future<String> analyzeUrlToCurl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('[CURL_EMPTY_INPUT]');
    final comma = RegExp(r'\s*,\s*\{').firstMatch(trimmed);
    final url = (comma == null ? trimmed : trimmed.substring(0, comma.start))
        .trim();
    if (url.isEmpty) throw Exception('[CURL_MISSING_URL]');
    var follow = true;
    if (comma != null) {
      final opt = trimmed.substring(comma.start);
      if (opt.contains('"followRedirects":false')) follow = false;
    }
    final quoted = url.contains('?') || url.contains(' ') ? "'$url'" : url;
    return follow ? 'curl -g -L $quoted' : 'curl -g $quoted';
  }

  @override
  Future<String> extractJsSource(String content) async {
    // Mock 占位：返回基于脚本内容的假书源 JSON
    return jsonEncode({
      'bookSourceUrl': 'mock://js-source',
      'bookSourceName': 'Mock JS 书源',
      'bookSourceType': 0,
      'enabled': true,
      'mainJs': content,
    });
  }

  @override
  Future<String> checkJsSourceSyntax(String content) async {
    // Mock 占位：非空即视为语法合法
    return jsonEncode({
      'valid': content.trim().isNotEmpty,
      'message': content.trim().isNotEmpty ? 'Mock 语法检查通过' : 'JS源内容为空',
      'line': null,
    });
  }

  @override
  Future<String> stampJsSourceLastUpdateTime(String content, int stamp) async {
    // Mock 占位：原样返回（不模拟写回）
    return content;
  }

  // ========== 书源登录 V2 动态状态协议（上游 #402/#488） — QoderCN ==========

  @override
  Future<bool> isLoginUiV2(String sourceJson) async => false;

  @override
  Future<String> loginUiV2(String sourceJson, String stateJson) async =>
      '{"rows":[]}';

  @override
  Future<String> loginActionV2(String sourceJson, String userInputJson) async =>
      '{"close":true}';

  // ========== 验证码交互通道（Task #90） ==========

  @override
  Stream<Map<String, dynamic>> verificationRequestStream() async* {
    // Mock 占位：无 JS 引擎，不会产生验证码请求
  }

  @override
  Future<bool> submitVerificationResult(String key, String code) async {
    // Mock 占位：无进行中的请求，返回未命中
    return false;
  }

  @override
  Future<bool> cancelVerificationRequest(String key) async {
    // Mock 占位：无进行中的请求，返回未命中
    return false;
  }

  @override
  Stream<Map<String, dynamic>> webviewRequestStream() async* {
    // Mock 占位：无真实 WebView 通道
  }

  @override
  Future<bool> submitWebviewResult(String key, String result) async => false;

  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    String cookiesJson,
  ) async =>
      false;

  @override
  Future<bool> cancelWebviewRequest(String key) async => false;
}
