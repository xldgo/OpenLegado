import 'dart:convert';

import '../../../../domain/contracts/network_service.dart';
import '../../../../domain/contracts/rss_source_repository.dart';
import '../../../../domain/contracts/replace_rule_repository.dart';
import '../../../../domain/models/source_preview.dart';
import '../../../../models/models.dart';

/// 订阅导入准备只返回确认页数据，不导航、不执行确认后的写入。— Codex + UI
sealed class RuleSubImportPreview {
  const RuleSubImportPreview();
  bool get isEmpty;
}

class RuleSubBookSources extends RuleSubImportPreview {
  RuleSubBookSources(List<SourcePreview> items, List<BookSource> local)
    : items = List.unmodifiable(items),
      local = List.unmodifiable(local);
  final List<SourcePreview> items;
  final List<BookSource> local;
  @override
  bool get isEmpty => items.isEmpty;
}

class RuleSubRssSources extends RuleSubImportPreview {
  RuleSubRssSources(List<Map<String, dynamic>> items, List<RssSource> local)
    : items = List.unmodifiable(items),
      local = List.unmodifiable(local);
  final List<Map<String, dynamic>> items;
  final List<RssSource> local;
  @override
  bool get isEmpty => items.isEmpty;
}

class RuleSubReplaceRules extends RuleSubImportPreview {
  RuleSubReplaceRules(List<Map<String, dynamic>> items, List<ReplaceRule> local)
    : items = List.unmodifiable(items),
      local = List.unmodifiable(local);
  final List<Map<String, dynamic>> items;
  final List<ReplaceRule> local;
  @override
  bool get isEmpty => items.isEmpty;
}

class RuleSubImportService {
  RuleSubImportService({
    required this._network,
    required this._fetchBookSources,
    required this._rss,
    required this._replaceRules,
  });
  final NetworkService _network;
  final Future<List<SourcePreview>> Function(String) _fetchBookSources;
  final RssSourceRepository _rss;
  final ReplaceRuleRepository _replaceRules;

  Future<RuleSubImportPreview> prepare(
    RuleSub subscription, {
    List<BookSource> localBookSources = const [],
  }) async {
    // 操作开始时固定本地书源快照，后续界面更新不改变本次预览。
    final localBooks = List<BookSource>.of(localBookSources);
    switch (subscription.subType) {
      case RuleSub.bookSource:
        return RuleSubBookSources(
          await _fetchBookSources(subscription.url),
          localBooks,
        );
      case RuleSub.rssSource:
        final items = await _fetchJson(subscription.url);
        List<RssSource> local;
        try {
          local = await _rss.getRssSources();
        } catch (_) {
          local = [];
        }
        return RuleSubRssSources(items, local);
      case RuleSub.replaceRule:
        final items = await _fetchJson(subscription.url);
        List<ReplaceRule> local;
        try {
          local = await _replaceRules.getReplaceRules();
        } catch (_) {
          local = [];
        }
        return RuleSubReplaceRules(items, local);
      default:
        throw FormatException('未知订阅类型：${subscription.subType}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJson(String url) async {
    final response = await _network.httpGet(
      url,
      timeout: const Duration(seconds: 30),
    );
    if (!response.isSuccess) throw Exception('HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    final List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = [decoded];
    } else {
      throw const FormatException('订阅内容不是 JSON 数组或对象');
    }
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) item,
    ];
  }
}
