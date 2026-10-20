import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/source_login_repository.dart';

/// 原凭据 FRB 直接适配，不改变 JSON、错误或运行时。— Codex + Bridge
final class RustSourceLoginRepository implements SourceLoginRepository {
  const RustSourceLoginRepository();

  /// 保存书源登录用户信息（对齐原版 BaseSource.putLoginInfo → `userInfo_<key>`）
  @override
  Future<void> putLoginInfo(String sourceUrl, String infoJson) => rustFuture(
    () => bridge.sourcePutLoginInfo(sourceUrl: sourceUrl, infoJson: infoJson),
    operation: 'sourcePutLoginInfo',
  );

  /// 保存书源登录头（对齐原版 BaseSource.putLoginHeader → `loginHeader_<key>`）
  @override
  Future<void> putLoginHeader(String sourceUrl, String headerJson) =>
      rustFuture(
        () => bridge.sourcePutLoginHeader(
          sourceUrl: sourceUrl,
          headerJson: headerJson,
        ),
        operation: 'sourcePutLoginHeader',
      );

  /// 读取书源登录用户信息（无则空串）
  @override
  Future<String> getLoginInfo(String sourceUrl) => rustFuture(
    () => bridge.sourceGetLoginInfo(sourceUrl: sourceUrl),
    operation: 'sourceGetLoginInfo',
  );

  /// 读取书源登录头（无则空串）
  @override
  Future<String> getLoginHeader(String sourceUrl) => rustFuture(
    () => bridge.sourceGetLoginHeader(sourceUrl: sourceUrl),
    operation: 'sourceGetLoginHeader',
  );
}
