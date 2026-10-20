import '../../domain/contracts/source_login_v2_service.dart';
import '../../domain/models/login_v2.dart';
import '../../models/book_source.dart';

/// 保持无引擎时的空表单和关闭命令，不模拟实际登录。— Codex + Bridge
class MockSourceLoginV2Service implements SourceLoginV2Service {
  const MockSourceLoginV2Service();
  @override
  Future<bool> isLoginUiV2(BookSource source) async => false;
  @override
  Future<LoginUiDescription> loadUi(
    BookSource source,
    Map<String, dynamic> state,
  ) async => LoginUiDescription(rows: []);
  @override
  Future<LoginActionResult> execute(
    BookSource source, {
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  }) async => LoginActionResult(close: true);
}
