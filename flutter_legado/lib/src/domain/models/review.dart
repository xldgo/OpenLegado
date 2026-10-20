/// 段评摘要与分页快照，不参与小说原文坐标。— Codex + Bridge
final class ReviewSummary {
  ReviewSummary({required Map<int, int> counts, required Map<int, String> keys})
    : counts = Map.unmodifiable(counts),
      keys = Map.unmodifiable(keys);
  final Map<int, int> counts;
  final Map<int, String> keys;
}

final class ReviewPage {
  ReviewPage({
    required List<ReviewDetailItem> items,
    this.nextPageUrl,
    this.hasReplyUrl = false,
  }) : items = List.unmodifiable(items);
  final List<ReviewDetailItem> items;
  final String? nextPageUrl;
  final bool hasReplyUrl;
}

/// 段评详情条目（对齐原版 ReviewRuleParser.DetailItem）
class ReviewDetailItem {
  final String? id;
  final String? avatar;
  final String? name;
  final List<String> badges;
  final String? content;
  final String? imageUrl;
  final String? audioUrl;
  final String? time;
  final int? likeCount;
  final int? replyCount;
  final List<ReviewDetailItem> replies;

  const ReviewDetailItem({
    this.id,
    this.avatar,
    this.name,
    this.badges = const [],
    this.content,
    this.imageUrl,
    this.audioUrl,
    this.time,
    this.likeCount,
    this.replyCount,
    this.replies = const [],
  });

  factory ReviewDetailItem.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'];
    return ReviewDetailItem(
      id: json['id']?.toString(),
      avatar: json['avatar'] as String?,
      name: json['name'] as String?,
      badges:
          (json['badges'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      content: json['content'] as String?,
      imageUrl: json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      time: json['time'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt(),
      replyCount: (json['replyCount'] as num?)?.toInt(),
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map(
                  (e) =>
                      ReviewDetailItem.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }
}
