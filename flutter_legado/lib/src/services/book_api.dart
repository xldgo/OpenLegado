import '../domain/contracts/cover_rule_repository.dart';
import '../domain/contracts/source_switch_service.dart';
import '../domain/contracts/cover_search_service.dart';
import '../domain/contracts/explore_service.dart';
import '../domain/contracts/explore_state_repository.dart';
import '../domain/contracts/book_source_query_service.dart';
import '../domain/contracts/book_source_debug_service.dart';
import '../domain/contracts/auto_task_repository.dart';
import '../domain/contracts/auto_task_service.dart';
import '../domain/contracts/book_image_repository.dart';
import '../domain/contracts/audio_cache_repository.dart';
import '../domain/contracts/audio_cache_download_service.dart';
import '../domain/contracts/audio_book_service.dart';
import '../domain/contracts/video_danmaku_service.dart';
import '../domain/contracts/local_book_service.dart';
import '../domain/contracts/book_archive_service.dart';
import '../domain/contracts/book_export_service.dart';
import '../domain/contracts/review_service.dart';
import '../domain/contracts/cache_repository.dart';
import '../domain/contracts/database_maintenance_service.dart';
import '../domain/contracts/app_log_repository.dart';
import '../domain/contracts/dictionary_service.dart';
import '../domain/contracts/dict_rule_repository.dart';
import '../domain/contracts/highlight_repository.dart';
import '../domain/contracts/highlight_rule_repository.dart';
import '../domain/contracts/rule_sub_repository.dart';
import '../domain/contracts/rule_sub_service.dart';
import '../domain/contracts/replace_rule_repository.dart';
import '../domain/contracts/replace_rule_service.dart';
import '../domain/contracts/rss_source_repository.dart';
import '../domain/contracts/rss_article_repository.dart';
import '../domain/contracts/rss_read_record_repository.dart';
import '../domain/contracts/rss_star_repository.dart';
import '../domain/contracts/chapter_cache_repository.dart';
import '../domain/contracts/cache_download_service.dart';
import '../domain/contracts/reading_repository.dart';
import '../domain/contracts/backup_repository.dart';
import '../domain/contracts/webdav_service.dart';
import '../domain/contracts/search_service.dart';
import '../domain/contracts/search_history_repository.dart';
import '../domain/contracts/source_login_repository.dart';
import '../domain/contracts/cloud_tts_repository.dart';
import '../domain/contracts/read_aloud_voice_repository.dart';
import '../domain/contracts/tts_cache_repository.dart';
import '../domain/contracts/source_checker.dart';
import '../domain/contracts/book_source_repository.dart';
import '../domain/contracts/bookshelf_repository.dart';
import '../domain/contracts/book_group_repository.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';

/// 书籍 API 抽象接口
///
/// 保留待迁移能力与应用装配引用；已拆分领域由消费者的窄接口访问。
/// 实现类：
/// - [RustApi]：真实 FFI 实现（需要 Rust DLL）
/// - MockBookApi：纯 Dart Mock 实现（无 DLL 可跑，UI 轨开发用）
abstract class BookApi {
  SourceSwitchService get sourceSwitchService;
  CoverSearchService get coverSearchService;
  CoverRuleRepository get coverRuleRepository;
  ExploreService get exploreService;
  ExploreStateRepository get exploreStateRepository;
  BookSourceQueryService get bookSourceQueryService;
  BookSourceDebugService get bookSourceDebugService;
  AutoTaskRepository get autoTaskRepository;
  AutoTaskService get autoTaskService;
  BookImageRepository get bookImageRepository;
  AudioCacheRepository get audioCacheRepository;
  AudioCacheDownloadService get audioCacheDownloadService;
  AudioBookService get audioBookService;
  VideoDanmakuService get videoDanmakuService;

  LocalBookService get localBookService;
  BookArchiveService get bookArchiveService;
  BookExportService get bookExportService;
  ReviewService get reviewService;

  CacheRepository get cacheRepository;
  DatabaseMaintenanceService get databaseMaintenanceService;
  AppLogRepository get appLogRepository;
  DictionaryService get dictionaryService;
  DictRuleRepository get dictRuleRepository;
  HighlightRepository get highlightRepository;
  HighlightRuleRepository get highlightRuleRepository;
  RuleSubRepository get ruleSubRepository;
  RuleSubService get ruleSubService;
  ReplaceRuleRepository get replaceRuleRepository;
  ReplaceRuleService get replaceRuleService;
  RssSourceRepository get rssSourceRepository;
  RssArticleRepository get rssArticleRepository;
  RssReadRecordRepository get rssReadRecordRepository;
  RssStarRepository get rssStarRepository;
  ChapterCacheRepository get chapterCacheRepository;
  CacheDownloadService get cacheDownloadService;
  ReadingRepository get readingRepository;
  BackupRepository get backupRepository;
  WebDavService get webDavService;

  /// 搜索执行与历史共享装配。
  SearchService get searchService;
  SearchHistoryRepository get searchHistoryRepository;

  CloudTtsRepository get cloudTtsRepository;

  /// 共享书源配置访问，登录与校验仍由各自能力承担。
  BookSourceRepository get bookSourceRepository;

  /// 与发起校验的会话共享同一实例。
  SourceChecker get sourceChecker;

  /// 经典、手动与 WebView 登录共用的凭据存储。
  SourceLoginRepository get sourceLoginRepository;

  /// 共享书架数据访问，不持有阅读器会话状态。
  BookshelfRepository get bookshelfRepository;

  /// 共享分组定义与显示配置访问。
  BookGroupRepository get bookGroupRepository;

  /// 共享应用装配的书签数据访问实例；书签 CRUD 由窄接口承担。
  BookmarkRepository get bookmarkRepository;

  /// 共享应用装配的阅读记录实例；数据读写由窄接口承担。
  ReadRecordRepository get readRecordRepository;

  /// 共享 HTTP 朗读引擎配置实例，不包含系统语音或播放状态。
  HttpTtsRepository get httpTtsRepository;
  ReadAloudVoiceRepository get readAloudVoiceRepository;

  /// 共享 HTTP 合成能力；缓存目录由应用生命周期单独注入。
  HttpTtsSynthesizer get httpTtsSynthesizer;
  TtsCacheRepository get ttsCacheRepository;

  // ========== 初始化/版本 ==========

  /// 初始化运行时和数据库连接
  Future<void> initialize();

  /// 获取引擎版本号
  Future<String> getVersion();

  // ========== 书源操作 ==========

  /// 清除指定 URL 所属二级域名的 Cookie（契约 §2.3 clearCookie，2026-08-12 P1-2）
  ///
  /// 对齐原版 `CookieStore.removeCookie` / 编辑页 `menu_clear_cookie`。
  Future<void> clearCookie(String url);

  /// 判断文本是否形似 cURL 命令（契约 §2.3 looksLikeCurl，2026-08-12 P1-14）
  Future<bool> looksLikeCurl(String text);

  /// cURL → AnalyzeUrl 模板（契约 §2.3 curlToAnalyzeUrl，2026-08-12 P1-14）
  Future<String> curlToAnalyzeUrl(String text);

  /// AnalyzeUrl → cURL（契约 §2.3 analyzeUrlToCurl，2026-08-12 P1-14）
  Future<String> analyzeUrlToCurl(String text);

  /// 提取 JS 单文件书源配置（返回 BookSource JSON，需 QuickJS 构建）
  Future<String> extractJsSource(String content);

  /// JS 书源语法检查（返回含 valid/message/line 的 JSON）
  Future<String> checkJsSourceSyntax(String content);

  /// 写回 JS 书源顶层配置的 lastUpdateTime（返回替换后脚本文本，无匹配时空串）
  Future<String> stampJsSourceLastUpdateTime(String content, int stamp);

  // ========== 书源校验（Task #87） ==========

  // ========== 书源登录 V2 动态状态协议（上游 #402/#488） — QoderCN ==========

  /// 判定书源登录 UI 是否为 V2 动态状态协议
  ///
  /// [sourceJson] — BookSource JSON。
  Future<bool> isLoginUiV2(String sourceJson);

  /// 执行 loginUi v2 脚本，返回动态 UI 描述 JSON（`{"rows":[...]}`）
  ///
  /// [stateJson] — 当前状态 JSON（首次渲染传 `"{}"`）。
  Future<String> loginUiV2(String sourceJson, String stateJson);

  /// 执行登录 V2 action 命令
  ///
  /// [userInputJson] — `{"action":"...","stateJson":"...","formJson":{...}}`；
  /// 返回命令 JSON：`state`(对象→更新状态重渲染) / `error`(对象→键值错误) /
  /// `login`(对象→登录成功) / `close`(布尔→关闭)。
  Future<String> loginActionV2(String sourceJson, String userInputJson);

  // ========== 验证码交互通道（Task #90） ==========

  /// 订阅验证码请求事件流（长期存活，对齐 Kotlin SourceVerificationHelp）
  ///
  /// 书源 JS 经 `getVerificationCode` 钩子挂起等待时，每个请求推送
  /// 一条事件 Map，字段：`key`（resultKey）/ `source_url` / `source_name` /
  /// `image_url` / `title` / `use_browser`（桌面端恒 false，浏览器模式
  /// 已降级）/ `created_at_ms`。订阅时先回放当前进行中的请求。
  /// UI 拿到事件后弹验证码对话框；用户输入经 [submitVerificationResult]
  /// 回传；关闭对话框调 [cancelVerificationRequest]。
  Stream<Map<String, dynamic>> verificationRequestStream();

  /// 提交验证码结果，唤醒 JS 等待方（对齐 Kotlin `setResult`）
  ///
  /// [key] — 请求事件中的 resultKey；[code] — 用户输入的验证码。
  /// 返回是否命中进行中的请求。
  Future<bool> submitVerificationResult(String key, String code);

  /// 取消验证码请求（对齐 Kotlin `checkResult`：UI 关闭对话框未提交）
  ///
  /// 以空结果唤醒等待方（等待侧报「验证结果为空」，对齐 Kotlin 语义）。
  Future<bool> cancelVerificationRequest(String key);

  /// BackstageWebView DOM 执行请求事件流（SOURCE_DIFF P1）
  ///
  /// 字段：`key` / `action` / `html` / `url` / `js` / `source_regex` /
  /// `override_url_regex` / `cache_first` / `delay_time` / `is_rule` /
  /// `result` / `source_key` / `cookie` / `created_at_ms`。订阅后 Rust
  /// 侧 `@webjs`/正文 webJs/`java.webView*` 可走真实 DOM。
  /// `source_key` / `cookie` 为项 B 加法式字段（缺省空串），旧端
  /// 忽略未知字段不破坏反序列化。
  Stream<Map<String, dynamic>> webviewRequestStream();

  /// 提交 WebView 执行结果，唤醒 Rust 等待方
  Future<bool> submitWebviewResult(String key, String result);

  /// 提交 WebView 执行结果 + 域 cookie 回流（项 B/B1，加法式条目）
  ///
  /// [cookiesJson] — JSON 对象：域键或 http(s) URL → `k1=v1; k2=v2`
  /// cookie 串（空串 / `{}` 表示无回流，语义同 [submitWebviewResult]）。
  /// Rust 侧按 ETLD+1 归一域键后 merged upsert 落库并同步 JS 桥
  /// 共享客户端内存 CookieStore，最后唤醒等待方（先持久化后唤醒）。
  /// 旧 [submitWebviewResult] 冻结不动（旧端不做 cookie 回流）。
  Future<bool> submitWebviewResultWithCookies(
    String key,
    String result,
    String cookiesJson,
  );

  /// 取消 WebView 请求（空结果唤醒）
  Future<bool> cancelWebviewRequest(String key);

  // ========== 阅读器操作 ==========

  /// 设置阅读器繁简转换类型并持久化
  ///
  /// 语义对齐 Android `AppConfig.chineseConverterType`：
  /// 0=不转换 / 1=繁转简（t2s） / 2=简转繁（s2t）；非法取值归一为 0。
  Future<void> setChineseConvertType(int type);

  /// 获取当前繁简转换类型（0=不转换 / 1=繁转简 / 2=简转繁）
  Future<int> getChineseConvertType();

  /// 章级「删除重复标题」开关（契约 §2.9.10，Task #50 加法式新增）
  ///
  /// 对齐原版 [BookHelp.setRemoveSameTitle] 章级 opt-out 语义：
  /// [enable]=true 恢复全局默认（去除重复标题）；false 该章保留原始标题。
  /// 状态由实现侧持久化（重启后保持）。错误码：书籍不存在 → Internal；
  /// 章节不存在 → Db。切换后正文读取按章应用该开关。
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  );

  /// 权威查询章级「删除重复标题」开关（caches KV，对齐原版 opt-out 态）
  ///
  /// true=去除重复标题（全局默认）；false=该章 opt-out。
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex);

  /// 试算正文开头是否含可移除的重复标题（对齐原版空提示）
  Future<bool> canRemoveSameTitle(String chapterTitle, String rawContent);

  // ========== 配置操作 ==========

  /// 获取配置值
  Future<String?> getConfig(String key);

  /// 设置配置值
  Future<void> setConfig(String key, String value);

  /// 删除配置
  Future<void> deleteConfig(String key);

  /// 获取所有配置
  Future<Map<String, String>> getAllConfigs();

  // ========== 章节购买 ==========

  /// 执行章节购买动作（契约 §2.43.2，对照 Kotlin ReadBookActivity.payAction）
  ///
  /// 返回结果元组：kind='url'（购买页地址，UI 打开内置浏览器）/
  /// 'success'（购买成功，Rust 侧已清当前章正文缓存）/'none'（无需或不支持）；
  /// value 为 JS 返回原文。本地书由 Rust 侧短路 kind=none。
  Future<({String kind, String value})> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  });

  /// 书源 callBackBtn（P2-2，对齐 SourceCallBack + 中途 UI 队列）
  ///
  /// 返回 map：`invoked` / `jsTrue` / `raw` / `actions`。
  /// UI 应先 `PlatformBridgeService.dispatchActions(actions)`，
  /// 若 `!invoked || !jsTrue` 再执行 noCall 默认行为。
  Future<Map<String, dynamic>> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  });

  // ========== 规则解析 ==========

  /// 使用规则解析内容
  Future<String> parseRule(String content, String rule, String ruleType);

  // ========== 网络操作 ==========

  /// HTTP GET 请求
  Future<String> httpGet(String url);

  /// HTTP POST 请求
  Future<String> httpPost(String url, String body);

  /// HTTP GET 二进制响应（F3-14）
  ///
  /// 返回 JSON `{"status": int, "bodyBase64": string, "url": string}`。
  /// [headersJson] 为空时不附加请求头；否则为 JSON 对象字符串。
  Future<String> httpGetBytes(String url, {String headersJson = ''});

  // ========== JS 引擎 ==========

  /// 执行 JS 脚本
  Future<String> evalJs(String script);

  /// 获取 JS 引擎版本
  Future<String> getJsEngineVersion();

  // ========== 服务器管理 ==========

  /// 启动服务器
  Future<void> startServer({int port = 1122});

  /// 停止服务器
  Future<void> stopServer();

  /// 获取服务器状态
  Future<String> getServerStatus();

  /// 设置服务器端口
  Future<void> setServerPort(int port);

  /// 设置自定义 hosts 映射（契约 §2.20.3，Task #74 加法式新增）
  ///
  /// [hostsJson] 为 JSON 对象 `域名 → 单 IP 字符串或 IP 数组`（对齐原版
  /// `AppConfig.hostMap`）；空串/空对象 = 清除映射恢复系统 DNS。
  /// 应用后网络层 DNS 即时生效，Rust 侧持久化到 `config:customHosts`
  ///（回读经既有 [getConfig]）。非法 JSON/非对象 → Internal 错误。
  Future<void> setCustomHosts(String hostsJson);

  /// 设置独立 MCP 服务端口（契约 §2.22.5，Task #74 加法式新增）
  ///
  /// port>0：启动/重启独立 MCP 服务（合法区间 1024..65530，越界或占用
  /// 报 Internal）；port≤0：停止独立服务。Rust 侧持久化到 `config:mcpPort`
  ///（回读经既有 [getConfig]）。
  Future<void> setMcpPort(int port);
}
