import '../models/login_v2.dart';

/// 同一动态表单复用书源和HTTP TTS会话。— Codex + Bridge
abstract interface class LoginV2Session {
  String get name;
  Future<LoginUiDescription> loadUi(Map<String, dynamic> state);
  Future<LoginActionResult> execute({
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  });
}
