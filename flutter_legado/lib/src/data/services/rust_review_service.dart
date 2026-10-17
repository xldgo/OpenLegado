import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/review_service.dart';
import '../../domain/models/review.dart';
import '../bridge/content_dto_mapping.dart';

/// 段评规则和分页请求直接使用现有Rust能力。— Codex + Bridge
final class RustReviewService implements ReviewService {
  const RustReviewService();
  @override
  Future<ReviewSummary> reviewGetSummary(
    String sourceJson,
    Map<String, dynamic> request,
  ) async {
    final value = await bridge.reviewGetSummary(
      sourceJson: sourceJson,
      request: reviewRequestToDto(request),
    );
    return ReviewSummary(
      counts: Map.fromEntries(value.counts.entries.where((e) => e.value > 0)),
      keys: value.keys,
    );
  }

  @override
  Future<ReviewPage> reviewGetDetail(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async => reviewPageFromDto(
    await bridge.reviewGetDetail(
      sourceJson: sourceJson,
      request: reviewRequestToDto(request),
      page: page,
    ),
  );
  @override
  Future<ReviewPage> reviewGetReplies(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async => reviewPageFromDto(
    await bridge.reviewGetReplies(
      sourceJson: sourceJson,
      request: reviewRequestToDto(request),
      page: page,
    ),
  );
}
