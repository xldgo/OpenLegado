import '../models/webview_request.dart';

/// Rust等待方的请求与结果通道；平台DOM执行单独注入。— Codex + Bridge
abstract interface class WebViewBridgeService {
  Stream<WebViewRequest> webviewRequestStream();
  Future<bool> submitWebviewResult(String key, String result);
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    Map<String, String> cookies,
  );
  Future<bool> cancelWebviewRequest(String key);
}

abstract interface class WebViewRequestExecutor {
  Future<WebViewExecutionResult> execute(WebViewRequest request);
}
