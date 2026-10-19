import '../../domain/contracts/webview_bridge_service.dart';
import '../../domain/models/webview_request.dart';

/// 无真实后台WebView请求，不伪造执行结果。— Codex + Bridge
class MockWebViewBridgeService implements WebViewBridgeService {
  @override
  Future<String> pageCall(String key, WebViewPageCall call) =>
      Future.error(UnsupportedError('Mock没有正在执行的页内宿主'));
  const MockWebViewBridgeService();
  @override
  Future<bool> completeWebviewRequest(
    String key,
    WebViewExecutionResult response,
  ) async => false;
  @override
  Stream<WebViewRequest> webviewRequestStream() => const Stream.empty();
  @override
  Future<bool> submitWebviewResult(String key, String result) async => false;
  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    Map<String, String> cookies,
  ) async => false;
  @override
  Future<bool> cancelWebviewRequest(String key) async => false;
}
