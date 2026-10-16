import '../../app/bootstrap/application_dependencies.dart';
import '../../app/bootstrap/login_v2_session_factory.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/rust_http_tts_login_session.dart';
import '../../models/models.dart';
import '../../widgets/classic_login_dialog.dart';
import '../../widgets/login_v2_dialog.dart';
import '../../screens/webview_login_screen.dart';

/// HTTP TTS 使用独立来源 ID，复用既有登录控件和 WebView。— Codex + UI
Future<void> showHttpTtsLogin(
  BuildContext context,
  WidgetRef ref,
  HttpTts engine,
) async {
  final session = RustHttpTtsLoginSession(engine);

  if (session.isV2) {
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          LoginV2Dialog(session: createHttpTtsLoginV2Session(session)),
    );
  } else if ((engine.loginUi ?? '').trim().isNotEmpty &&
      engine.loginUi!.trim() != '[]') {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClassicLoginDialog.session(session: session),
    );
  } else {
    final url = engine.loginUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('该引擎未配置网页登录地址或登录表单');
    }
    final headers = await session.requestHeaders();
    // 验证返回的是请求头对象，WebView 与合成走相同源规则。
    if (jsonDecode(headers) is! Map) throw const FormatException('登录请求头格式错误');
    if (!context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WebViewLoginScreen(
          repository: ref.read(sourceLoginRepositoryProvider),
          sourceUrl: url,
          sourceName: engine.name,
          loginUrl: url,
          header: headers,
          loginSession: session,
        ),
      ),
    );
  }
}
