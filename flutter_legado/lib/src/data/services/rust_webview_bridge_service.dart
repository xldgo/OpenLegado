import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../bridge/task_dto.dart' as dto;
import '../../domain/contracts/webview_bridge_service.dart';
import '../../domain/models/webview_request.dart';
import '../bridge/task_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// Cookie回流仍经Rust合并落库后唤醒等待方。— Codex + Bridge
class RustWebViewBridgeService implements WebViewBridgeService {
  const RustWebViewBridgeService();
  @override
  Future<String> pageCall(String key, WebViewPageCall call) => rustFuture(
    () => bridge.webviewPageCall(
      key: key,
      call: dto.WebViewPageCallDto(
        target: switch (call.target) {
          WebViewPageTarget.source => dto.WebViewPageTargetDto.source,
          WebViewPageTarget.cache => dto.WebViewPageTargetDto.cache,
          WebViewPageTarget.java => dto.WebViewPageTargetDto.java,
        },
        method: call.method,
        args: call.args,
      ),
    ),
    operation: 'webviewPageCall',
  );
  @override
  Future<bool> completeWebviewRequest(
    String key,
    WebViewExecutionResult response,
  ) => rustFuture(
    () => bridge.webviewComplete(
      key: key,
      response: dto.WebViewResponseDto(
        result: response.result,
        finalUrl: response.finalUrl,
        error: response.error,
        cookies: response.cookies,
      ),
    ),
    operation: 'webviewComplete',
  );
  @override
  Stream<WebViewRequest> webviewRequestStream() => managedRustStream(
    (request) => rustStream(
      () => bridge.webviewRequestStream(request: request),
      operation: 'webviewRequestStream',
    ),
  ).map(webViewFromDto);
  @override
  Future<bool> submitWebviewResult(String key, String result) => rustFuture(
    () => bridge.webviewSubmit(key: key, result: result),
    operation: 'webviewSubmit',
  );
  @override
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    Map<String, String> cookies,
  ) => rustFuture(
    () => bridge.webviewSubmitResultWithCookies(
      key: key,
      result: result,
      cookies: cookies,
    ),
    operation: 'webviewSubmitResultWithCookies',
  );
  @override
  Future<bool> cancelWebviewRequest(String key) => rustFuture(
    () => bridge.webviewCancel(key: key),
    operation: 'webviewCancel',
  );
}
