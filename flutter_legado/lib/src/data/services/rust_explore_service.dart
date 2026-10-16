import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/explore_service.dart';
import '../../domain/models/explore_action_result.dart';
import '../../models/models.dart';
import '../bridge/rust_json_decode.dart';

/// 发现结果归一化与平台拦截集中在数据层。— Codex + Bridge
final class RustExploreService implements ExploreService {
  const RustExploreService({required this._interceptResult});
  final Future<String> Function(String) _interceptResult;
  @override
  Future<List<ExploreCategory>> parseCategories(
    String exploreUrl, {
    BookSource? source,
  }) async {
    final list = decodeRustJsonList(
      await bridge.exploreParseUrl(
        exploreUrl: exploreUrl,
        sourceJson: source == null ? '' : jsonEncode(source.toJson()),
      ),
      'exploreParseUrl',
    );
    return list
        .map((value) => ExploreCategory.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SearchBook>> fetchBooks(
    BookSource source,
    String url,
    int page,
  ) async {
    final list = decodeRustJsonList(
      await _interceptResult(
        await bridge.exploreFetchBooks(
          sourceJson: jsonEncode(source.toJson()),
          url: url,
          page: page,
        ),
      ),
      'exploreFetchBooks',
    );
    return list
        .map(
          (value) => _searchBookFromExplore(
            value as Map<String, dynamic>,
            source.bookSourceUrl,
            source.bookSourceName,
          ),
        )
        .toList();
  }

  @override
  Future<ExploreActionResult> evaluateAction({
    required String sourceJson,
    required String actionJs,
  }) async {
    final value = decodeRustJsonMap(
      await bridge.exploreEvalAction(
        sourceJson: sourceJson,
        actionJs: actionJs,
      ),
      'exploreEvalAction',
    );
    return ExploreActionResult(
      raw: value['raw'] as String? ?? '',
      actions: value['actions'] as List<dynamic>? ?? const [],
      refreshExplore: value['refreshExplore'] as bool? ?? false,
    );
  }

  @override
  Future<String> evaluateUiJs({
    required String sourceJson,
    required String jsStr,
  }) => bridge.exploreEvalUiJs(sourceJson: sourceJson, jsStr: jsStr);

  /// 将发现分类返回的 WebSearchResult 归一化为 SearchBook。
  /// 兼容 snake_case 与 camelCase 两种键名；origin/originName 用所属书源补齐，
  /// 避免 Rust 侧字段命名差异导致 origin 丢失（未入库书详情页无法联网取目录/封面）。
  SearchBook _searchBookFromExplore(
    Map<String, dynamic> e,
    String sourceUrl,
    String sourceName,
  ) {
    String? pick(String camel, String snake) {
      final v = e[camel] ?? e[snake];
      final s = v?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    return SearchBook(
      bookUrl: _absoluteUrl(
        pick('origin', 'source_url') ?? sourceUrl,
        pick('bookUrl', 'book_url'),
      ),
      origin: pick('origin', 'source_url') ?? sourceUrl,
      originName: pick('originName', 'source_name') ?? sourceName,
      name: pick('name', 'name') ?? '',
      author: pick('author', 'author') ?? '',
      kind: pick('kind', 'kind'),
      coverUrl: _absoluteUrlOrNull(
        pick('origin', 'source_url') ?? sourceUrl,
        pick('coverUrl', 'cover_url'),
      ),
      intro: pick('intro', 'intro'),
      wordCount: pick('wordCount', 'word_count'),
      latestChapterTitle: pick('latestChapterTitle', 'latest_chapter'),
      tocUrl: pick('tocUrl', 'toc_url') ?? '',
      // 类型位标记（Rust WebSearchResult 序列化键为 type；漫画/听书/视频源
      // 据此分流阅读器，缺省 0=文本）— 发现页修复 A8
      bookType: e['type'] is int
          ? e['type'] as int
          : (int.tryParse(e['type']?.toString() ?? '') ?? 0),
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
