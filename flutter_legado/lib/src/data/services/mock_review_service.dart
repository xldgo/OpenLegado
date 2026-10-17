import 'dart:convert';

import '../../domain/contracts/review_service.dart';
import '../../domain/models/review.dart';
import '../bridge/review_document_decode.dart';

/// 保留旧段评样例与分页，不请求网络。— Codex + Bridge
final class MockReviewService implements ReviewService {
  const MockReviewService();
  @override
  Future<ReviewSummary> reviewGetSummary(
    String sourceJson,
    Map<String, dynamic> request,
  ) async {
    return decodeReviewSummary(
      jsonEncode({
        'counts': {'1': 3, '2': 1},
        'keys': {'1': 'mock-para-1', '2': 'mock-para-2'},
      }),
    );
  }

  @override
  Future<ReviewPage> reviewGetDetail(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async {
    return decodeReviewPage(
      jsonEncode({
        'items': [
          {
            'id': 'mock_detail_$page-1',
            'name': '读者甲',
            'content': 'Mock 段评内容一（第$page 页）',
            'badges': <String>['作者'],
            'time': '刚刚',
            'replyCount': 2,
            'replies': <Map<String, dynamic>>[],
          },
          {
            'id': 'mock_detail_$page-2',
            'name': '读者乙',
            'content': 'Mock 段评内容二（第$page 页）',
            'badges': <String>[],
            'replyCount': 0,
            'replies': <Map<String, dynamic>>[],
          },
        ],
        'nextPageUrl': page < 2 ? 'mock://next' : null,
        'hasReplyUrl': true,
      }),
    );
  }

  @override
  Future<ReviewPage> reviewGetReplies(
    String sourceJson,
    Map<String, dynamic> request,
    int page,
  ) async {
    // Mock 返回两条示例回复，便于 UI 轨联调段评回复弹窗
    return decodeReviewPage(
      jsonEncode({
        'items': [
          {
            'id': 'mock_reply_$page-1',
            'name': '读者甲',
            'content': 'Mock 回复内容一（第$page 页）',
            'badges': <String>['沙发'],
            'time': '刚刚',
          },
          {
            'id': 'mock_reply_$page-2',
            'name': '读者乙',
            'content': 'Mock 回复内容二（第$page 页）',
            'badges': <String>[],
          },
        ],
        'nextPageUrl': null,
      }),
    );
  }
}
