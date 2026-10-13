/// 登录控件消费的窄会话；不依赖书源实体、Flutter 或数据库。— Codex + Bridge
abstract interface class SourceLoginSession {
  String get key;
  String get name;
  bool get isV2;
  bool get hasLoginScript;
  Future<String> loadUi(String state);
  Future<String> executeV2(String input);
  Future<Map<String, dynamic>> execute(String script);
  Future<String> getInfo();
  Future<void> putInfo(String value);
  Future<String> getHeader();
  Future<void> putHeader(String value);
  Future<String> requestHeaders();
}
