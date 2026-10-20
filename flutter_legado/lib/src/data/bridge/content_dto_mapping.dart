import 'dart:convert';

import '../../bridge/content_dto.dart' as dto;
import '../../domain/models/review.dart';
import '../../models/models.dart';
import 'entity_dto_mapping.dart';

// 稳定抓取字段与既有模型适配；协议文档只在原边界解析。— Codex + Bridge
Book webBookInfoFromDto(dto.WebBookInfoDto v, BookSource source) => Book(
  bookUrl: v.bookUrl,
  name: v.name,
  author: v.author,
  origin: source.bookSourceUrl,
  originName: source.bookSourceName,
  coverUrl: v.coverUrl,
  intro: v.intro,
  kind: v.kind,
  latestChapterTitle: v.lastChapter,
  tocUrl: v.tocUrl,
  wordCount: v.wordCount,
  variable: v.variable,
  bookType: v.bookType,
);
BookChapter webChapterFromDto(dto.WebChapterDto v, String bookUrl) =>
    BookChapter(
      bookUrl: bookUrl,
      index: v.index,
      title: v.title,
      url: v.url,
      isVip: v.isVip,
      isVolume: v.isVolume,
      variable: v.variable,
      wordCount: v.wordCount,
    );
ExploreCategory exploreCategoryFromDto(dto.ExploreCategoryDto v) {
  String? optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  final style = v.style;
  return ExploreCategory(
    title: v.title,
    url: optional(v.url),
    type: v.kind,
    action: optional(v.action),
    chars: v.chars?.whereType<String>().where((v) => v.isNotEmpty).toList(),
    defaultValue: optional(v.defaultValue),
    viewName: optional(v.viewName),
    style: style == null
        ? null
        : FlexChildStyle(
            layoutFlexGrow: style.layoutFlexGrow,
            layoutFlexShrink: style.layoutFlexShrink,
            layoutAlignSelf: style.layoutAlignSelf,
            layoutFlexBasisPercent: style.layoutFlexBasisPercent,
            layoutWrapBefore: style.layoutWrapBefore,
            layoutJustifySelf: style.layoutJustifySelf,
          ),
  );
}

ReviewDetailItem reviewItemFromDto(dto.ReviewDetailItemDto v) =>
    ReviewDetailItem(
      id: v.id,
      avatar: v.avatar,
      name: v.name,
      badges: List.unmodifiable(v.badges),
      content: v.content,
      imageUrl: v.imageUrl,
      audioUrl: v.audioUrl,
      time: v.time,
      likeCount: v.likeCount,
      replyCount: v.replyCount,
      replies: List.unmodifiable(v.replies.map(reviewItemFromDto)),
    );
ReviewPage reviewPageFromDto(dto.ReviewPageDto v) => ReviewPage(
  items: v.items.map(reviewItemFromDto).toList(),
  nextPageUrl: v.nextPageUrl,
  hasReplyUrl: v.hasReplyUrl,
);
dto.ReviewRequestDto reviewRequestToDto(Map<String, dynamic> v) {
  String field(String k) {
    final x = v[k];
    return x == null
        ? ''
        : x is String
        ? x
        : jsonEncode(x);
  }

  return dto.ReviewRequestDto(
    chapterUrl: field('chapterUrl'),
    paraIndex: field('paraIndex'),
    paraData: field('paraData'),
    detailUrl: field('detailUrl'),
    replyUrl: field('replyUrl'),
    reviewId: field('reviewId'),
    book: v['book'] == null
        ? null
        : bookToDto(Book.fromJson(Map<String, dynamic>.from(v['book'] as Map))),
    chapter: v['chapter'] == null
        ? null
        : bookChapterToDto(
            BookChapter.fromJson(
              Map<String, dynamic>.from(v['chapter'] as Map),
            ),
          ),
  );
}
