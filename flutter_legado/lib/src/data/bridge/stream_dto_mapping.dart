import '../../bridge/transfer_dto.dart' as dto;
import '../../domain/models/search_batch.dart';
import '../../domain/models/source_switch_batch.dart';
import '../../models/models.dart';

// 流事件只在数据边界转换；不编码或解析 JSON。— Codex + Bridge

SearchBook searchBookFromDto(dto.SearchBookDto value) => SearchBook(
  bookUrl: value.bookUrl,
  origin: value.origin,
  originName: value.originName,
  bookType: value.bookType,
  name: value.name,
  author: value.author,
  kind: value.kind,
  coverUrl: value.coverUrl,
  intro: value.intro,
  wordCount: value.wordCount,
  latestChapterTitle: value.latestChapterTitle,
  tocUrl: value.tocUrl,
  time: value.time,
  variable: value.variable,
  originOrder: value.originOrder,
  chapterWordCountText: value.chapterWordCountText,
  chapterWordCount: value.chapterWordCount,
  respondTime: value.respondTime,
  origins: value.origins,
);

SearchBatch searchBatchFromDto(dto.SearchSourceBatchDto value) => SearchBatch(
  sourceIndex: value.sourceIndex.toInt(),
  sourceUrl: value.sourceUrl,
  sourceName: value.sourceName,
  books: value.books.map(
    (book) => SearchResult.fromSearchBook(
      searchBookFromDto(book),
      hasReadRecord: book.hasReadRecord,
    ),
  ),
  error: value.error,
  finishedCount: value.finishedCount.toInt(),
  totalCount: value.totalCount.toInt(),
  isLast: value.isLast,
  hasMore: value.hasMore,
);

SourceMatch sourceMatchFromDto(dto.SourceMatchDto value) => SourceMatch(
  sourceUrl: value.sourceUrl,
  sourceName: value.sourceName,
  bookUrl: value.bookUrl,
  bookName: value.bookName,
  author: value.author,
  latestChapter: value.latestChapter,
  wordCount: value.wordCount,
  score: value.score,
  chapterWordCountText: value.chapterWordCountText,
  chapterWordCount: value.chapterWordCount,
  respondTime: value.respondTime,
  originOrder: value.originOrder,
  bookScore: value.bookScore,
);
SourceSwitchBatch switchBatchFromDto(dto.ChangeSourceBatchDto value) =>
    SourceSwitchBatch(
      sourceIndex: value.sourceIndex.toInt(),
      sourceUrl: value.sourceUrl,
      sourceName: value.sourceName,
      error: value.error,
      finishedCount: value.finishedCount.toInt(),
      totalCount: value.totalCount.toInt(),
      isLast: value.isLast,
      matches: value.matches.map(sourceMatchFromDto).toList(),
    );

Map<String, dynamic> captchaInfoFromDto(dto.CaptchaInfoDto value) => {
  'detected': value.detected,
  'captcha_type': value.captchaType,
  'matched_keyword': value.matchedKeyword,
};

Map<String, dynamic> redirectInfoFromDto(dto.RedirectInfoDto value) => {
  'redirected': value.redirected,
  'original_url': value.originalUrl,
  'final_url': value.finalUrl,
  'is_login_redirect': value.isLoginRedirect,
};

Map<String, dynamic> checkResultFromDto(dto.CheckResultDto value) => {
  'source_url': value.sourceUrl,
  'search_ok': value.searchOk,
  'toc_ok': value.tocOk,
  'content_ok': value.contentOk,
  'search_error': value.searchError,
  'toc_error': value.tocError,
  'content_error': value.contentError,
  'total_time_ms': value.totalTimeMs,
  'captcha': value.captcha == null ? null : captchaInfoFromDto(value.captcha!),
  'redirect': value.redirect == null
      ? null
      : redirectInfoFromDto(value.redirect!),
};

Map<String, dynamic> checkProgressFromDto(dto.CheckProgressDto value) => {
  'index': value.index.toInt(),
  'total': value.total.toInt(),
  'is_last': value.isLast,
  'source_name': value.sourceName,
  'result': checkResultFromDto(value.result),
};
