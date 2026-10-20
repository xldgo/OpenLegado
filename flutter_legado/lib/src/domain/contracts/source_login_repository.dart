/// 原始登录信息与登录头读写，不解析凭据或执行登录脚本。— Codex + UI
abstract interface class SourceLoginRepository {
  /// 保存书源登录用户信息（对齐原版 `BaseSource.putLoginInfo` → `userInfo_<key>`；
  /// V2 login 命令自动落库 + 手动登录共用）
  ///
  /// [sourceUrl] — 书源 URL；[infoJson] — 用户信息 JSON（原样存储）。
  /// 加法式新增（2026-08-14 发现页修复 R1）。
  Future<void> putLoginInfo(String sourceUrl, String infoJson);

  /// 保存书源登录头（对齐原版 `BaseSource.putLoginHeader` → `loginHeader_<key>`，
  /// 请求路径自动合并）
  ///
  /// [sourceUrl] — 书源 URL；[headerJson] — header map JSON（如 `{"Cookie":"..."}`）。
  /// 加法式新增（2026-08-14 发现页修复 R1）。
  Future<void> putLoginHeader(String sourceUrl, String headerJson);

  /// 读取书源登录用户信息（无则空串）
  ///
  /// 加法式新增（2026-08-14 发现页修复 R1）。
  Future<String> getLoginInfo(String sourceUrl);

  /// 读取书源登录头（无则空串）
  ///
  /// 加法式新增（2026-08-14 发现页修复 R1）。
  Future<String> getLoginHeader(String sourceUrl);
}
