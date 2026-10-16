import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/book_source_edit_service.dart';
import '../domain/contracts/source_login_v2_service.dart';
import '../domain/contracts/verification_service.dart';
import '../domain/contracts/webview_bridge_service.dart';
import '../platform/native_webview_request_executor.dart';
import '../services/platform_bridge_service.dart';
import 'providers.dart';

/// 各交互能力独立替换，平台执行器不参与根数据装配。— Codex + UI
final bookSourceEditServiceProvider = Provider<BookSourceEditService>(
  (ref) => ref.watch(bookApiProvider).bookSourceEditService,
);
final sourceLoginV2ServiceProvider = Provider<SourceLoginV2Service>(
  (ref) => ref.watch(bookApiProvider).sourceLoginV2Service,
);
final verificationServiceProvider = Provider<VerificationService>(
  (ref) => ref.watch(bookApiProvider).verificationService,
);
final webViewBridgeServiceProvider = Provider<WebViewBridgeService>(
  (ref) => ref.watch(bookApiProvider).webViewBridgeService,
);
final webViewRequestExecutorProvider = Provider<WebViewRequestExecutor>(
  (ref) => NativeWebViewRequestExecutor(
    dispatch: PlatformBridgeService.instance.dispatchPayloadWithCookies,
  ),
);
