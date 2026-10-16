import 'dart:convert';

import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/webview_bridge_service.dart';
import '../../domain/models/webview_request.dart';
import '../bridge/source_request_json.dart';

/// Cookie回流仍经Rust合并落库后唤醒等待方。— Codex + Bridge
class RustWebViewBridgeService implements WebViewBridgeService {
  const RustWebViewBridgeService();
  @override
  Stream<WebViewRequest> webviewRequestStream() =>
      bridge.webviewRequestStream().map(decodeWebViewRequest);
  @override
  Future<bool> submitWebviewResult(String key, String result) =>
      bridge.webviewSubmit(key: key, result: result);
  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    Map<String, String> cookies,
  ) => bridge.webviewSubmitResultWithCookies(
    key: key,
    result: result,
    cookiesJson: cookies.isEmpty ? '' : jsonEncode(cookies),
  );
  @override
  Future<bool> cancelWebviewRequest(String key) =>
      bridge.webviewCancel(key: key);
}
