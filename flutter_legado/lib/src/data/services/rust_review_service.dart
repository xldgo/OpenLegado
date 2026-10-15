import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/review_service.dart';
import '../../domain/models/review.dart';
import '../bridge/book_content_decode.dart';

/// 段评规则和分页请求直接使用现有Rust能力。— Codex + Bridge
final class RustReviewService implements ReviewService {
  const RustReviewService();
  @override
  Future<ReviewSummary> reviewGetSummary(
    String sourceJson,
    Map<String, dynamic> request,
  ) async => decodeReviewSummary(
    await bridge.reviewGetSummary(
      sourceJson: sourceJson,
      requestJson: jsonEncode(request),
    ),
  );
  @override
  Future<ReviewPage> reviewGetDetail(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async => decodeReviewPage(
    await bridge.reviewGetDetail(
      sourceJson: sourceJson,
      requestJson: jsonEncode(request),
      page: page,
    ),
  );
  @override
  Future<ReviewPage> reviewGetReplies(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async => decodeReviewPage(
    await bridge.reviewGetReplies(
      sourceJson: sourceJson,
      requestJson: jsonEncode(request),
      page: page,
    ),
  );
}
