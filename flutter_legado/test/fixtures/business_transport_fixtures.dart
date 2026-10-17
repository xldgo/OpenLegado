import 'dart:convert';

import 'package:flutter_legado/src/bridge/business_dto.dart';

Object? _doc(Object? v) => v is String ? jsonDecode(v) : v;
Map<String, dynamic> _map(Object? v) =>
    Map<String, dynamic>.from(_doc(v) as Map);

RssSourceDto fixtureRssSourceDto(Object? raw) {
  final v = _map(raw);
  return RssSourceDto(
    sourceUrl: v['sourceUrl'] as String? ?? '',
    sourceName: v['sourceName'] as String? ?? '',
    sourceIcon: v['sourceIcon'] as String? ?? '',
    sourceGroup: v['sourceGroup'] as String?,
    sourceComment: v['sourceComment'] as String?,
    enabled: v['enabled'] as bool? ?? true,
    variableComment: v['variableComment'] as String?,
    jsLib: v['jsLib'] as String?,
    enabledCookieJar: v['enabledCookieJar'] as bool?,
    concurrentRate: v['concurrentRate'] as String?,
    header: v['header'] as String?,
    loginUrl: v['loginUrl'] as String?,
    loginUi: v['loginUi'] as String?,
    loginCheckJs: v['loginCheckJs'] as String?,
    coverDecodeJs: v['coverDecodeJs'] as String?,
    sortUrl: v['sortUrl'] as String?,
    singleUrl: v['singleUrl'] as bool? ?? false,
    articleStyle: v['articleStyle'] as int? ?? 0,
    ruleArticles: v['ruleArticles'] as String?,
    ruleNextPage: v['ruleNextPage'] as String?,
    ruleTitle: v['ruleTitle'] as String?,
    rulePubDate: v['rulePubDate'] as String?,
    ruleDescription: v['ruleDescription'] as String?,
    ruleImage: v['ruleImage'] as String?,
    ruleLink: v['ruleLink'] as String?,
    ruleContent: v['ruleContent'] as String?,
    contentWhitelist: v['contentWhitelist'] as String?,
    contentBlacklist: v['contentBlacklist'] as String?,
    shouldOverrideUrlLoading: v['shouldOverrideUrlLoading'] as String?,
    style: v['style'] as String?,
    enableJs: v['enableJs'] as bool? ?? true,
    loadWithBaseUrl: v['loadWithBaseUrl'] as bool? ?? true,
    injectJs: v['injectJs'] as String?,
    preloadJs: v['preloadJs'] as String?,
    startHtml: v['startHtml'] as String?,
    startStyle: v['startStyle'] as String?,
    startJs: v['startJs'] as String?,
    showWebLog: v['showWebLog'] as bool? ?? false,
    lastUpdateTime: v['lastUpdateTime'] as int? ?? 0,
    customOrder: v['customOrder'] as int? ?? 0,
    rssType: v['type'] as int? ?? 0,
    preload: v['preload'] as bool? ?? false,
    cacheFirst: v['cacheFirst'] as bool? ?? false,
    searchUrl: v['searchUrl'] as String?,
  );
}

List<RssSourceDto> fixtureRssSourceDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRssSourceDto).toList();
RssArticleDto fixtureRssArticleDto(Object? raw) {
  final v = _map(raw);
  return RssArticleDto(
    title: v['title'] as String? ?? '',
    link: v['link'] as String? ?? '',
    description: v['description'] as String?,
    pubDate: v['pubDate'] as String?,
    imageUrl: v['imageUrl'] as String?,
  );
}

List<RssArticleDto> fixtureRssArticleDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRssArticleDto).toList();
RssStarSnapshotDto fixtureRssStarSnapshotDto(Object? raw) {
  final v = _map(raw);
  return RssStarSnapshotDto(
    origin: v['origin'] as String? ?? '',
    sort: v['sort'] as String? ?? '',
    title: v['title'] as String? ?? '',
    starTime: (v['starTime'] ?? v['star_time']) as int? ?? 0,
    link: v['link'] as String?,
    pubDate: (v['pubDate'] ?? v['pub_date']) as String?,
    description: v['description'] as String?,
    content: v['content'] as String?,
    image: v['image'] as String?,
    variable: v['variable'] as String?,
  );
}

List<RssStarSnapshotDto> fixtureRssStarSnapshotDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRssStarSnapshotDto).toList();
RssReadRecordDto fixtureRssReadRecordDto(Object? raw) {
  final v = _map(raw);
  return RssReadRecordDto(
    origin: v['origin'] as String? ?? '',
    title: v['title'] as String? ?? '',
    link: v['link'] as String?,
    readTime: v['read_time'] as int? ?? 0,
  );
}

List<RssReadRecordDto> fixtureRssReadRecordDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRssReadRecordDto).toList();
SearchHistoryDto fixtureSearchHistoryDto(Object? raw) {
  final v = _map(raw);
  return SearchHistoryDto(
    word: v['word'] as String? ?? '',
    usage: v['usage'] as int? ?? 0,
    lastUseTime: v['lastUseTime'] as int? ?? 0,
  );
}

List<SearchHistoryDto> fixtureSearchHistoryDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureSearchHistoryDto).toList();
ReplaceRuleDto fixtureReplaceRuleDto(Object? raw) {
  final v = _map(raw);
  return ReplaceRuleDto(
    id: v['id'] as int? ?? 0,
    name: v['name'] as String? ?? '',
    group: v['group'] as String?,
    pattern: v['pattern'] as String? ?? '',
    replacement: v['replacement'] as String? ?? '',
    scope: v['scope'] as String?,
    scopeTitle: v['scopeTitle'] as bool? ?? false,
    scopeContent: v['scopeContent'] as bool? ?? true,
    scopeSource: v['scopeSource'] as bool? ?? false,
    excludeScope: v['excludeScope'] as String?,
    isEnabled: v['isEnabled'] as bool? ?? true,
    isRegex: v['isRegex'] as bool? ?? true,
    timeoutMillisecond: v['timeoutMillisecond'] as int? ?? 3000,
    order: v['sortOrder'] as int? ?? 0,
  );
}

List<ReplaceRuleDto> fixtureReplaceRuleDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureReplaceRuleDto).toList();
DictEntryDto fixtureDictEntryDto(Object? raw) {
  final v = _map(raw);
  return DictEntryDto(
    word: v['word'] as String? ?? '',
    phonetic: v['phonetic'] as String? ?? '',
    definitions: (v['definitions'] as List? ?? []).cast<String>(),
  );
}

List<DictEntryDto> fixtureDictEntryDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureDictEntryDto).toList();
DictionaryRuleDto fixtureDictionaryRuleDto(Object? raw) {
  final v = _map(raw);
  return DictionaryRuleDto(
    id: v['id'] as int? ?? 0,
    name: v['name'] as String? ?? '',
    urlRule: v['urlRule'] as String? ?? '',
    showRule: v['showRule'] as String? ?? '',
    enabled: v['enabled'] as bool? ?? true,
    sortNumber: v['sortNumber'] as int? ?? 0,
  );
}

List<DictionaryRuleDto> fixtureDictionaryRuleDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureDictionaryRuleDto).toList();
RuleSubscriptionDto fixtureRuleSubscriptionDto(Object? raw) {
  final v = _map(raw);
  return RuleSubscriptionDto(
    id: v['id'] as int? ?? 0,
    url: v['url'] as String? ?? '',
    name: v['name'] as String? ?? '',
    subType: v['sub_type'] as String? ?? '',
    lastUpdate: v['last_update'] as int? ?? 0,
    version: v['version'] as String? ?? '',
    isEnabled: v['is_enabled'] as bool? ?? true,
    createdAt: v['created_at'] as int? ?? 0,
    customOrder: v['customOrder'] as int? ?? 0,
    autoUpdate: v['autoUpdate'] as bool? ?? false,
    updateInterval: v['updateInterval'] as int? ?? 0,
    silentUpdate: v['silentUpdate'] as bool? ?? false,
    js: v['js'] as String?,
    showRule: v['showRule'] as String?,
    sourceUrl: v['sourceUrl'] as String?,
  );
}

List<RuleSubscriptionDto> fixtureRuleSubscriptionDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRuleSubscriptionDto).toList();
SubscriptionCheckDto fixtureSubscriptionCheckDto(Object? raw) {
  final v = _map(raw);
  return SubscriptionCheckDto(
    id: v['id'] as int? ?? 0,
    url: v['url'] as String? ?? '',
    name: v['name'] as String? ?? '',
    dueForUpdate: v['dueForUpdate'] as bool? ?? false,
    hasUpdate: v['hasUpdate'] as bool? ?? false,
    remoteVersion: v['remoteVersion'] as String?,
    error: v['error'] as String?,
  );
}

List<SubscriptionCheckDto> fixtureSubscriptionCheckDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureSubscriptionCheckDto).toList();
SubscriptionApplyDto fixtureSubscriptionApplyDto(Object? raw) {
  final v = _map(raw);
  return SubscriptionApplyDto(
    id: v['id'] as int? ?? 0,
    url: v['url'] as String? ?? '',
    success: v['success'] as bool? ?? false,
    itemsAdded: BigInt.from(v['itemsAdded'] as int? ?? 0),
    itemsUpdated: BigInt.from(v['itemsUpdated'] as int? ?? 0),
    itemsRemoved: BigInt.from(v['itemsRemoved'] as int? ?? 0),
    totalItems: BigInt.from(v['totalItems'] as int? ?? 0),
    error: v['error'] as String?,
  );
}

List<SubscriptionApplyDto> fixtureSubscriptionApplyDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureSubscriptionApplyDto).toList();
RestoreStatsDto fixtureRestoreStatsDto(Object? raw) {
  final v = _map(raw);
  return RestoreStatsDto(
    books: BigInt.from(v['books'] as int? ?? 0),
    bookmarks: BigInt.from(v['bookmarks'] as int? ?? 0),
    replaceRules: BigInt.from(v['replaceRules'] as int? ?? 0),
    bookSources: BigInt.from(v['bookSources'] as int? ?? 0),
    rssSources: BigInt.from(v['rssSources'] as int? ?? 0),
    readRecords: BigInt.from(v['readRecords'] as int? ?? 0),
  );
}

List<RestoreStatsDto> fixtureRestoreStatsDtoList(Object? raw) =>
    (_doc(raw) as List).map(fixtureRestoreStatsDto).toList();
List<AppLogDto> fixtureLogs(Object? raw) => (_doc(raw) as List).map((e) {
  final v = _map(e);
  return AppLogDto(
    timestamp: v['timestamp'] as int,
    level: LogLevelDto.values.byName(v['level'] as String),
    message: v['message'] as String,
  );
}).toList();
List<CachedChapterDto> fixtureCached(Object? raw) =>
    (_doc(raw) as List).map((e) {
      final v = _map(e);
      return CachedChapterDto(
        url: v['url'] as String,
        wordCount: v['wordCount'] as String,
      );
    }).toList();
