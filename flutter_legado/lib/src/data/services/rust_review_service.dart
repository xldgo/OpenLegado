import '../bridge/rust_errors.dart';
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
    final value = await rustFuture(
      () => bridge.reviewGetSummary(
        sourceJson: sourceJson,
        request: reviewRequestToDto(request),
      ),
      operation: 'reviewGetSummary',
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
    await rustFuture(
      () => bridge.reviewGetDetail(
        sourceJson: sourceJson,
        request: reviewRequestToDto(request),
        page: page,
      ),
      operation: 'reviewGetDetail',
    ),
  );
  @override
  Future<ReviewPage> reviewGetReplies(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async => reviewPageFromDto(
    await rustFuture(
      () => bridge.reviewGetReplies(
        sourceJson: sourceJson,
        request: reviewRequestToDto(request),
        page: page,
      ),
      operation: 'reviewGetReplies',
    ),
  );
}
