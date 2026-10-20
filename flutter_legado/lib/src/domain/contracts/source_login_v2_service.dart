import '../../models/book_source.dart';
import '../models/login_v2.dart';

/// V2脚本执行，不承载手动凭据编辑或控件状态。— Codex + Bridge
abstract interface class SourceLoginV2Service {
  Future<bool> isLoginUiV2(BookSource source);
  Future<LoginUiDescription> loadUi(
    BookSource source,
    Map<String, dynamic> state,
  );
  Future<LoginActionResult> execute(
    BookSource source, {
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  });
}
