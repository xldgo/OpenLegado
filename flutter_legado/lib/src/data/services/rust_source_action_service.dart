import '../bridge/rust_errors.dart';

import 'dart:convert';

import '../../bridge/source_tools_dto.dart' as dto;
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/source_action_service.dart';
import '../../domain/models/source_action_result.dart';

/// 回调动作在返回前按原队列回放一次，再由调用方判断默认操作。— Codex + Bridge
class RustSourceActionService implements SourceActionService {
  RustSourceActionService({required this._dispatchActions});
  final Future<void> Function(List<dynamic>) _dispatchActions;
  @override
  Future<ChapterPurchaseResult> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    final result = await rustFuture(
      () =>
          bridge.chapterPayAction(bookUrl: bookUrl, chapterIndex: chapterIndex),
      operation: 'chapterPayAction',
    );
    final kind = switch (result.kind) {
      dto.ChapterPurchaseKindDto.url => ChapterPurchaseKind.url,
      dto.ChapterPurchaseKindDto.success => ChapterPurchaseKind.success,
      dto.ChapterPurchaseKindDto.none => ChapterPurchaseKind.none,
    };
    return ChapterPurchaseResult(kind: kind, value: result.value);
  }

  @override
  Future<SourceCallbackResult> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async {
    final payload = await rustFuture(
      () => bridge.sourceCallBackBtn(
        event: event,
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        result: result,
        bookType: bookType,
      ),
      operation: 'sourceCallBackBtn',
    );
    // 只解析真正动态动作文档，保留未知字段与原有平台队列。
    final actions = jsonDecode(payload.actionsJson);
    if (actions is! List) {
      throw const FormatException('sourceCallBackBtn动作必须为数组');
    }
    final response = SourceCallbackResult(
      invoked: payload.invoked,
      jsTrue: payload.jsTrue,
      raw: payload.raw,
      actions: actions,
    );
    if (response.actions.isNotEmpty) await _dispatchActions(response.actions);
    return response;
  }
}
