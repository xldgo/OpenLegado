import 'dart:convert';

import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/source_login_v2_service.dart';
import '../../domain/models/login_v2.dart';
import '../../models/book_source.dart';
import '../bridge/login_v2_json.dart';
import '../bridge/entity_dto_mapping.dart';

/// 先执行既有平台拦截，再解析V2命令；不接管凭据持久化。— Codex + Bridge
class RustSourceLoginV2Service implements SourceLoginV2Service {
  RustSourceLoginV2Service({required this._interceptResult});
  final Future<String> Function(String) _interceptResult;
  @override
  Future<bool> isLoginUiV2(BookSource source) =>
      bridge.sourceIsLoginUiV2(source: bookSourceToDto(source));
  @override
  Future<LoginUiDescription> loadUi(
    BookSource source,
    Map<String, dynamic> state,
  ) async => decodeLoginUi(
    await _interceptResult(
      await bridge.sourceLoginUiV2(
        source: bookSourceToDto(source),
        stateJson: jsonEncode(state),
      ),
    ),
  );
  @override
  Future<LoginActionResult> execute(
    BookSource source, {
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  }) async => decodeLoginAction(
    await _interceptResult(
      await bridge.sourceLoginActionV2(
        source: bookSourceToDto(source),
        userInputJson: encodeLoginAction(
          action: action,
          state: state,
          form: form,
        ),
      ),
    ),
  );
}
