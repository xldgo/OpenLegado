import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/source_action_service.dart';
import '../../domain/models/source_action_result.dart';
import '../bridge/rust_json_decode.dart';

/// 回调动作在返回前按原队列回放一次，再由调用方判断默认操作。— Codex + Bridge
class RustSourceActionService implements SourceActionService {
  RustSourceActionService({required this._dispatchActions});
  final Future<void> Function(List<dynamic>) _dispatchActions;
  @override
  Future<ChapterPurchaseResult> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    final map = decodeRustJsonMap(
      await bridge.chapterPayAction(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
      ),
      'chapterPayAction',
    );
    final kind = switch (map['kind']) {
      'url' => ChapterPurchaseKind.url,
      'success' => ChapterPurchaseKind.success,
      'none' => ChapterPurchaseKind.none,
      _ => throw const FormatException('chapterPayAction返回未知kind'),
    };
    final value = map['value'];
    if (value is! String) {
      throw const FormatException('chapterPayAction缺少有效value');
    }
    return ChapterPurchaseResult(kind: kind, value: value);
  }

  @override
  Future<SourceCallbackResult> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async {
    final map = decodeRustJsonMap(
      await bridge.sourceCallBackBtn(
        event: event,
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        result: result,
        bookType: bookType,
      ),
      'sourceCallBackBtn',
    );
    final invoked = map['invoked'];
    final jsTrue = map['jsTrue'];
    final raw = map['raw'];
    final actions = map['actions'];
    if (invoked is! bool ||
        jsTrue is! bool ||
        raw is! String ||
        actions is! List) {
      throw const FormatException('sourceCallBackBtn返回字段无效');
    }
    final response = SourceCallbackResult(
      invoked: invoked,
      jsTrue: jsTrue,
      raw: raw,
      actions: actions,
    );
    if (response.actions.isNotEmpty) await _dispatchActions(response.actions);
    return response;
  }
}
