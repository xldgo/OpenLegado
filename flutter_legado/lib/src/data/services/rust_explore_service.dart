import '../bridge/rust_errors.dart';

import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/explore_service.dart';
import '../../domain/models/explore_action_result.dart';
import '../../models/models.dart';
import '../bridge/entity_dto_mapping.dart';
import '../bridge/content_dto_mapping.dart';
import '../../bridge/content_dto.dart';

/// 发现结果归一化与平台拦截集中在数据层。— Codex + Bridge
final class RustExploreService implements ExploreService {
  const RustExploreService();
  @override
  Future<List<ExploreCategory>> parseCategories(
    String exploreUrl, {
    BookSource? source,
  }) async {
    return (await rustFuture(
      () => bridge.exploreParseUrl(
        exploreUrl: exploreUrl,
        source: source == null ? null : bookSourceToDto(source),
      ),
      operation: 'exploreParseUrl',
    )).map(exploreCategoryFromDto).toList();
  }

  @override
  Future<List<SearchBook>> fetchBooks(
    BookSource source,
    String url,
    int page,
  ) async =>
      (await rustFuture(
            () => bridge.exploreFetchBooks(
              source: bookSourceToDto(source),
              url: url,
              page: page,
            ),
            operation: 'exploreFetchBooks',
          ))
          .map(
            (value) => _searchBookFromExplore(
              value,
              source.bookSourceUrl,
              source.bookSourceName,
            ),
          )
          .toList();
  @override
  Future<ExploreActionResult> evaluateAction({
    required BookSource source,
    required String actionJs,
  }) async {
    final value = await rustFuture(
      () => bridge.exploreEvalAction(
        source: bookSourceToDto(source),
        actionJs: actionJs,
      ),
      operation: 'exploreEvalAction',
    );
    return ExploreActionResult(
      raw: value.raw,
      actions: jsonDecode(value.actionsJson) as List<dynamic>,
      refreshExplore: value.refreshExplore,
    );
  }

  @override
  Future<String> evaluateUiJs({
    required BookSource source,
    required String jsStr,
  }) => rustFuture(
    () => bridge.exploreEvalUiJs(source: bookSourceToDto(source), jsStr: jsStr),
    operation: 'exploreEvalUiJs',
  );

  /// URL 归一规则保留，不再依赖 JSON 别名。
  SearchBook _searchBookFromExplore(
    WebSearchResultDto e,
    String sourceUrl,
    String sourceName,
  ) {
    final origin = e.sourceUrl.isEmpty ? sourceUrl : e.sourceUrl;
    String? nonempty(String? value) =>
        value == null || value.isEmpty ? null : value;
    return SearchBook(
      bookUrl: _absoluteUrl(origin, e.bookUrl),
      origin: origin,
      originName: sourceName,
      name: e.name,
      author: e.author,
      kind: nonempty(e.kind),
      coverUrl: _absoluteUrlOrNull(origin, e.coverUrl),
      intro: nonempty(e.intro),
      wordCount: nonempty(e.wordCount),
      latestChapterTitle: nonempty(e.latestChapter),
      bookType: e.bookType,
    );
  }

  /// 将可能为相对路径的 URL 解析为绝对 URL（对标原版 NetworkUtils.getAbsoluteURL）。
  /// 发现/搜索返回的 book_url 可能是相对路径（如 /book/65308/），直接传给
  /// webbookInfo/webbookChapters 会导致 reqwest “builder error”。以书源基地址补齐。
  String _absoluteUrl(String base, String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty || base.isEmpty) return u;
    if (u.contains('://') || u.startsWith('data:')) return u;
    try {
      return Uri.parse(base).resolve(u).toString();
    } catch (_) {
      return u;
    }
  }

  /// [_absoluteUrl] 的可空包装：空值返回 null（保持封面可空语义）。
  String? _absoluteUrlOrNull(String base, String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    return _absoluteUrl(base, u);
  }
}
