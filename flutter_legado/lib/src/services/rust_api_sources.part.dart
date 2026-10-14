// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiSources mixin：书架 / 书源 / 校验 / 登录 / 验证码 / WebView 通道。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiSources on RustApiDecode implements BookApi {
  // ========== 书源操作 ==========

  /// 清除 Cookie（契约 §2.3 clearCookie，对齐原版 CookieStore.removeCookie）
  @override
  Future<void> clearCookie(String url) => bridge.clearCookie(url: url);

  @override
  Future<bool> looksLikeCurl(String text) => bridge.looksLikeCurl(text: text);

  @override
  Future<String> curlToAnalyzeUrl(String text) =>
      bridge.curlToAnalyzeUrl(text: text);

  @override
  Future<String> analyzeUrlToCurl(String text) =>
      bridge.analyzeUrlToCurl(text: text);

  /// 提取 JS 单文件书源配置（返回 BookSource JSON，需 QuickJS 构建）
  @override
  Future<String> extractJsSource(String content) =>
      bridge.jsSourceExtract(content: content);

  /// JS 书源语法检查（返回含 valid/message/line 的 JSON）
  @override
  Future<String> checkJsSourceSyntax(String content) =>
      bridge.jsSourceSyntaxCheck(content: content);

  /// 写回 JS 书源顶层配置的 lastUpdateTime（返回替换后脚本文本，无匹配时空串）
  @override
  Future<String> stampJsSourceLastUpdateTime(String content, int stamp) =>
      bridge.jsSourceStampLastUpdateTime(content: content, stamp: stamp);

  // ========== 书源登录 V2 动态状态协议（上游 #402/#488） — QoderCN ==========

  /// 判定书源登录 UI 是否为 V2 动态状态协议
  @override
  Future<bool> isLoginUiV2(String sourceJson) =>
      bridge.sourceIsLoginUiV2(sourceJson: sourceJson);

  /// 执行 loginUi v2 脚本，返回动态 UI 描述 JSON（`{"rows":[...]}`）
  @override
  Future<String> loginUiV2(String sourceJson, String stateJson) async =>
      // 平台桥接拦截：脚本可能以 webView 类桥接载荷作为整体返回（Task #114）— QoderCN
      PlatformBridgeService.instance.interceptResult(
        await bridge.sourceLoginUiV2(
          sourceJson: sourceJson,
          stateJson: stateJson,
        ),
      );

  /// 执行登录 V2 action 命令（返回命令 JSON：state/error/login/close）
  @override
  Future<String> loginActionV2(String sourceJson, String userInputJson) async =>
      // 平台桥接拦截（Task #114）— QoderCN
      PlatformBridgeService.instance.interceptResult(
        await bridge.sourceLoginActionV2(
          sourceJson: sourceJson,
          userInputJson: userInputJson,
        ),
      );

  // ========== 验证码交互通道（Task #90） ==========

  /// 订阅验证码请求事件流（长期存活）
  ///
  /// 事件 Map 字段见 [BookApi.verificationRequestStream]。
  /// 订阅时 Rust 侧先回放当前进行中的请求。
  @override
  Stream<Map<String, dynamic>> verificationRequestStream() {
    return bridge.verificationRequestStream().map(
      (item) => _decodeMap(item, 'verificationRequestStream'),
    );
  }

  /// 提交验证码结果，唤醒 JS 等待方（对齐 Kotlin `setResult`）
  @override
  Future<bool> submitVerificationResult(String key, String code) =>
      bridge.verificationSubmit(key: key, code: code);

  /// 取消验证码请求（对齐 Kotlin `checkResult`：以空结果唤醒等待方）
  @override
  Future<bool> cancelVerificationRequest(String key) =>
      bridge.verificationCancel(key: key);

  // ========== BackstageWebView DOM 通道（SOURCE_DIFF P1） ==========

  @override
  Stream<Map<String, dynamic>> webviewRequestStream() {
    return bridge.webviewRequestStream().map(
      (item) => _decodeMap(item, 'webviewRequestStream'),
    );
  }

  @override
  Future<bool> submitWebviewResult(String key, String result) =>
      bridge.webviewSubmit(key: key, result: result);

  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    String cookiesJson,
  ) => bridge.webviewSubmitResultWithCookies(
    key: key,
    result: result,
    cookiesJson: cookiesJson,
  );

  @override
  Future<bool> cancelWebviewRequest(String key) =>
      bridge.webviewCancel(key: key);
}
