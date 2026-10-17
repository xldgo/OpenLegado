import '../../bridge/business_dto.dart' as dto;
import '../../models/models.dart';
import '../../domain/models/app_log_entry.dart';
import '../../domain/models/rule_sub_update_result.dart';

// 实体和稳定结果逐字段映射；文档导入导出仍独立保留。— Codex + Bridge
int businessI32(int value) {
  if (value < -2147483648 || value > 2147483647) {
    throw RangeError.value(value, 'value', '超出i32范围');
  }
  return value;
}

RssSource rssSourceFromDto(dto.RssSourceDto v) => RssSource(
  sourceUrl: v.sourceUrl,
  sourceName: v.sourceName,
  sourceIcon: v.sourceIcon,
  sourceGroup: v.sourceGroup,
  sourceComment: v.sourceComment,
  enabled: v.enabled,
  variableComment: v.variableComment,
  jsLib: v.jsLib,
  enabledCookieJar: v.enabledCookieJar,
  concurrentRate: v.concurrentRate,
  header: v.header,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  loginCheckJs: v.loginCheckJs,
  coverDecodeJs: v.coverDecodeJs,
  sortUrl: v.sortUrl,
  singleUrl: v.singleUrl,
  articleStyle: v.articleStyle,
  ruleArticles: v.ruleArticles,
  ruleNextPage: v.ruleNextPage,
  ruleTitle: v.ruleTitle,
  rulePubDate: v.rulePubDate,
  ruleDescription: v.ruleDescription,
  ruleImage: v.ruleImage,
  ruleLink: v.ruleLink,
  ruleContent: v.ruleContent,
  contentWhitelist: v.contentWhitelist,
  contentBlacklist: v.contentBlacklist,
  shouldOverrideUrlLoading: v.shouldOverrideUrlLoading,
  style: v.style,
  enableJs: v.enableJs,
  loadWithBaseUrl: v.loadWithBaseUrl,
  injectJs: v.injectJs,
  preloadJs: v.preloadJs,
  startHtml: v.startHtml,
  startStyle: v.startStyle,
  startJs: v.startJs,
  showWebLog: v.showWebLog,
  lastUpdateTime: v.lastUpdateTime,
  customOrder: v.customOrder,
  rssType: v.rssType,
  preload: v.preload,
  cacheFirst: v.cacheFirst,
  searchUrl: v.searchUrl,
);
dto.RssSourceDto rssSourceToDto(RssSource v) => dto.RssSourceDto(
  sourceUrl: v.sourceUrl,
  sourceName: v.sourceName,
  sourceIcon: v.sourceIcon,
  sourceGroup: v.sourceGroup,
  sourceComment: v.sourceComment,
  enabled: v.enabled,
  variableComment: v.variableComment,
  jsLib: v.jsLib,
  enabledCookieJar: v.enabledCookieJar,
  concurrentRate: v.concurrentRate,
  header: v.header,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  loginCheckJs: v.loginCheckJs,
  coverDecodeJs: v.coverDecodeJs,
  sortUrl: v.sortUrl,
  singleUrl: v.singleUrl,
  articleStyle: businessI32(v.articleStyle),
  ruleArticles: v.ruleArticles,
  ruleNextPage: v.ruleNextPage,
  ruleTitle: v.ruleTitle,
  rulePubDate: v.rulePubDate,
  ruleDescription: v.ruleDescription,
  ruleImage: v.ruleImage,
  ruleLink: v.ruleLink,
  ruleContent: v.ruleContent,
  contentWhitelist: v.contentWhitelist,
  contentBlacklist: v.contentBlacklist,
  shouldOverrideUrlLoading: v.shouldOverrideUrlLoading,
  style: v.style,
  enableJs: v.enableJs,
  loadWithBaseUrl: v.loadWithBaseUrl,
  injectJs: v.injectJs,
  preloadJs: v.preloadJs,
  startHtml: v.startHtml,
  startStyle: v.startStyle,
  startJs: v.startJs,
  showWebLog: v.showWebLog,
  lastUpdateTime: v.lastUpdateTime,
  customOrder: businessI32(v.customOrder),
  rssType: businessI32(v.rssType),
  preload: v.preload,
  cacheFirst: v.cacheFirst,
  searchUrl: v.searchUrl,
);
RssReadRecordRow rssReadFromDto(dto.RssReadRecordDto v) => RssReadRecordRow(
  origin: v.origin,
  title: v.title,
  link: v.link,
  readTime: v.readTime,
);
SearchKeyword searchHistoryFromDto(dto.SearchHistoryDto v) =>
    SearchKeyword(word: v.word, usage: v.usage, lastUseTime: v.lastUseTime);
ReplaceRule replaceRuleFromDto(dto.ReplaceRuleDto v) => ReplaceRule(
  id: v.id,
  name: v.name,
  group: v.group,
  pattern: v.pattern,
  replacement: v.replacement,
  scope: v.scope,
  scopeTitle: v.scopeTitle,
  scopeContent: v.scopeContent,
  scopeSource: v.scopeSource,
  excludeScope: v.excludeScope,
  isEnabled: v.isEnabled,
  isRegex: v.isRegex,
  timeoutMillisecond: v.timeoutMillisecond,
  order: v.order,
);
DictRule dictionaryRuleFromDto(dto.DictionaryRuleDto v) => DictRule(
  id: v.id,
  name: v.name,
  urlRule: v.urlRule,
  showRule: v.showRule,
  enabled: v.enabled,
  sortNumber: v.sortNumber,
);
RuleSub ruleSubscriptionFromDto(dto.RuleSubscriptionDto v) => RuleSub(
  id: v.id,
  url: v.url,
  name: v.name,
  subType: v.subType,
  lastUpdate: v.lastUpdate,
  version: v.version,
  isEnabled: v.isEnabled,
  createdAt: v.createdAt,
  customOrder: v.customOrder,
  autoUpdate: v.autoUpdate,
  updateInterval: v.updateInterval,
  silentUpdate: v.silentUpdate,
);
dto.RuleSubscriptionDto ruleSubscriptionToDto(RuleSub v) =>
    dto.RuleSubscriptionDto(
      id: v.id,
      url: v.url,
      name: v.name,
      subType: v.subType,
      lastUpdate: v.lastUpdate,
      version: v.version,
      isEnabled: v.isEnabled,
      createdAt: v.createdAt,
      customOrder: businessI32(v.customOrder),
      autoUpdate: v.autoUpdate,
      updateInterval: businessI32(v.updateInterval),
      silentUpdate: v.silentUpdate,
      js: null,
      showRule: null,
      sourceUrl: null,
    );
RssFeedArticle rssArticleFromDto(dto.RssArticleDto v) => RssFeedArticle(
  title: v.title,
  url: v.link,
  description: v.description,
  pubDate: v.pubDate,
  imageUrl: v.imageUrl,
);
RssStar rssStarFromDto(dto.RssStarSnapshotDto v) => RssStar(
  origin: v.origin,
  sort: v.sort,
  title: v.title,
  starTime: v.starTime,
  link: v.link ?? '',
  pubDate: v.pubDate,
  description: v.description,
  content: v.content,
  image: v.image,
  variable: v.variable,
);
DictEntry dictEntryFromDto(dto.DictEntryDto v) => DictEntry(
  word: v.word,
  phonetic: v.phonetic,
  definitions: List.unmodifiable(v.definitions),
);
AppLogEntry appLogFromDto(dto.AppLogDto v) => AppLogEntry(
  timestamp: v.timestamp,
  level: v.level.name,
  message: v.message,
);
RuleSubCheckResult subscriptionCheckFromDto(dto.SubscriptionCheckDto v) =>
    RuleSubCheckResult(
      id: v.id,
      url: v.url,
      name: v.name,
      dueForUpdate: v.dueForUpdate,
      hasUpdate: v.hasUpdate,
      remoteVersion: v.remoteVersion,
      error: v.error,
    );
RuleSubApplyResult subscriptionApplyFromDto(dto.SubscriptionApplyDto v) =>
    RuleSubApplyResult(
      id: v.id,
      url: v.url,
      success: v.success,
      itemsAdded: v.itemsAdded.toInt(),
      itemsUpdated: v.itemsUpdated.toInt(),
      itemsRemoved: v.itemsRemoved.toInt(),
      totalItems: v.totalItems.toInt(),
      error: v.error,
    );
