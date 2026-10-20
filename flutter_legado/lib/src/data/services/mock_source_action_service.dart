import '../../domain/contracts/source_action_service.dart';
import '../../domain/models/source_action_result.dart';

/// 不模拟付费、平台动作或JS接管，保留默认操作。— Codex + Bridge
class MockSourceActionService implements SourceActionService {
  const MockSourceActionService();
  @override
  Future<ChapterPurchaseResult> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async =>
      const ChapterPurchaseResult(kind: ChapterPurchaseKind.none, value: '');
  @override
  Future<SourceCallbackResult> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async => SourceCallbackResult(invoked: false, jsTrue: false);
}
