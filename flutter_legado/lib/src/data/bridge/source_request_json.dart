import '../../domain/models/verification_request.dart';
import '../../domain/models/webview_request.dart';
import 'rust_json_decode.dart';

/// 通道字段映射在适配器完成，拒绝缺少身份的请求。— Codex + Bridge
VerificationRequest decodeVerificationRequest(String raw) {
  final m = decodeRustJsonMap(raw, 'verificationRequestStream');
  return VerificationRequest(
    key: _key(m),
    sourceUrl: _text(m, 'source_url'),
    sourceName: _text(m, 'source_name'),
    imageUrl: _text(m, 'image_url'),
    title: _text(m, 'title'),
    useBrowser: m['use_browser'] == true,
    createdAtMs: _integer(m, 'created_at_ms'),
  );
}

WebViewRequest decodeWebViewRequest(String raw) {
  final m = decodeRustJsonMap(raw, 'webviewRequestStream');
  return WebViewRequest(
    key: _key(m),
    action: _text(m, 'action', 'webView'),
    html: _text(m, 'html'),
    url: _text(m, 'url'),
    js: _text(m, 'js'),
    sourceRegex: _text(m, 'source_regex'),
    overrideUrlRegex: _text(m, 'override_url_regex'),
    cacheFirst: m['cache_first'] == true,
    delayTime: _integer(m, 'delay_time'),
    isRule: m['is_rule'] == true,
    result: _text(m, 'result'),
    sourceKey: _text(m, 'source_key'),
    cookie: _text(m, 'cookie'),
    createdAtMs: _integer(m, 'created_at_ms'),
  );
}

String _key(Map<String, dynamic> m) {
  final key = m['key'];
  if (key is! String || key.isEmpty) throw const FormatException('通道请求缺少有效key');
  return key;
}

String _text(Map<String, dynamic> m, String key, [String fallback = '']) =>
    m[key]?.toString() ?? fallback;
int _integer(Map<String, dynamic> m, String key) {
  final value = m[key];
  if (value == null) return 0;
  if (value is! int) throw FormatException('通道字段$key不是整数');
  return value;
}
