/// 书源或RSS源变量按源身份保存，不属于普通设置。— Codex + Bridge
abstract interface class SourceVariableRepository {
  Future<String?> read(String sourceUrl);
  Future<void> write(String sourceUrl, String value);
}
