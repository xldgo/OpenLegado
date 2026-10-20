import '../models/review.dart';

/// 段评规则仍在Rust执行，UI只传上下文和消费类型化结果。— Codex + Bridge
abstract interface class ReviewService {
  Future<ReviewSummary> reviewGetSummary(
    String sourceJson,
    Map<String, dynamic> request,
  );
  Future<ReviewPage> reviewGetDetail(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  );
  Future<ReviewPage> reviewGetReplies(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  );
}
