import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/source_login_repository.dart';

/// 原凭据 FRB 直接适配，不改变 JSON、错误或运行时。— Codex + Bridge
final class RustSourceLoginRepository implements SourceLoginRepository {
  const RustSourceLoginRepository();

  /// 保存书源登录用户信息（对齐原版 BaseSource.putLoginInfo → `userInfo_<key>`）
  @override
  Future<void> putLoginInfo(String sourceUrl, String infoJson) =>
      bridge.sourcePutLoginInfo(sourceUrl: sourceUrl, infoJson: infoJson);

  /// 保存书源登录头（对齐原版 BaseSource.putLoginHeader → `loginHeader_<key>`）
  @override
  Future<void> putLoginHeader(String sourceUrl, String headerJson) =>
      bridge.sourcePutLoginHeader(sourceUrl: sourceUrl, headerJson: headerJson);

  /// 读取书源登录用户信息（无则空串）
  @override
  Future<String> getLoginInfo(String sourceUrl) =>
      bridge.sourceGetLoginInfo(sourceUrl: sourceUrl);

  /// 读取书源登录头（无则空串）
  @override
  Future<String> getLoginHeader(String sourceUrl) =>
      bridge.sourceGetLoginHeader(sourceUrl: sourceUrl);
}
