import '../models/source_action_result.dart';

/// 书源动作执行与结果回放，不管理页面导航、分享或阅读会话。— Codex + Bridge
abstract interface class SourceActionService {
  Future<ChapterPurchaseResult> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  });
  Future<SourceCallbackResult> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  });
}
