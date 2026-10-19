export '../app/bootstrap/application_dependencies.dart'
    show
        bookSourceEditServiceProvider,
        sourceLoginV2ServiceProvider,
        verificationServiceProvider,
        webViewBridgeServiceProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap/application_dependencies.dart'
    show webViewBridgeServiceProvider;

import '../domain/contracts/webview_bridge_service.dart';
import '../platform/native_webview_request_executor.dart';
import '../services/platform_bridge_service.dart';

/// 各交互能力独立替换，平台执行器不参与根数据装配。— Codex + UI

final webViewRequestExecutorProvider = Provider<WebViewRequestExecutor>(
  (ref) => NativeWebViewRequestExecutor(
    dispatch: PlatformBridgeService.instance.dispatchPayloadWithCookies,
    cancel: PlatformBridgeService.instance.cancelWebView,
    pageCall: ref.read(webViewBridgeServiceProvider).pageCall,
  ),
);
