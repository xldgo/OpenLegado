/// 服务访问令牌独立于普通设置快照，不混入UI偏好。— Codex + Bridge
abstract interface class ServerAccessRepository {
  Future<String?> getToken();
  Future<void> setToken(String token);
}
