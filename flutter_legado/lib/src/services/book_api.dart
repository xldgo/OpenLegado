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
import '../models/models.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';

/// 书籍 API 抽象接口
///
/// 定义所有数据层公开方法签名，供 UI 层依赖。
/// 实现类：
/// - [RustApi]：真实 FFI 实现（需要 Rust DLL）
/// - MockBookApi：纯 Dart Mock 实现（无 DLL 可跑，UI 轨开发用）
abstract class BookApi {
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

  // ========== 换源与封面搜索 ==========

  /// 搜索可替换的书源
  ///
  /// [sourceUrls] 可选：仅搜指定书源；null/空=搜全部启用源
  /// （留项#12，Task #131，加法式新增，契约见 API_CONTRACT.md §2.4）
  Future<List<Map<String, dynamic>>> searchSource(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  });

  /// 换源搜索流式版（T6 / 契约 §2.4 `searchSourceStream`）
  ///
  /// 每完成一个书源推送一批次 Map，字段：`source_index` / `source_url` /
  /// `source_name` / `error`(String?) / `finished_count` / `total_count` /
  /// `is_last` / `matches`（当前已过滤评分候选全量快照）。
  /// DB 复用推单批即结束；enrich 开启时末批为增强后重排快照。
  Stream<Map<String, dynamic>> searchSourceStream(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  });

  /// 搜索书籍封面候选列表
  ///
  /// 按书名搜索网络封面候选（API_CONTRACT.md §3 需求 3，用于 `change_cover_screen`）。
  /// 每个元素字段：`url`（封面地址，必需）/ `width`（像素，未知填 0）/ `height`（像素，未知填 0）。
  /// 无候选时返回空列表（非异常）。
  Future<List<Map<String, dynamic>>> searchCover(String bookName);

  /// 切换书源
  Future<String> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  );

  /// 切换书源（预拉缓存版，2026-09-24 加法式；对齐上游「换源感知等待」方案）
  ///
  /// 搜索期已按开关预拉候选详情/目录（有界并发 + 单候选 60s 超时 + 单失败
  /// 隔离）：命中预拉缓存 → 缓存详情+目录直接用（**零网络**，选中即落地）；
  /// 未命中 → 现场抓取（执行链与 [switchSource] 一致，且可在提交前经
  /// [cancelSwitchSourceApply] 取消——DB 零变更）。
  /// 返回更新后的书籍 JSON（与 [switchSource] 相同）。
  Future<String> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  );

  /// 取消进行中的「换源（预拉缓存版）」应用（对齐上游 `cancelChangeSource`）
  ///
  /// apply 代数 +1 并 bump 目录刷新代数：未提交的 apply 在提交前比对代数
  /// 即中止（DB 零变更），在途目录分页链在下一页边界中止。
  Future<void> cancelSwitchSourceApply();

  /// 更新换源列表项用户评分（-1/0/1，对标原版 SourceConfig 书维度评分）
  Future<void> updateSearchBookScore(String bookUrl, int score);

  /// 删除换源列表项（按 bookUrl，对标换源页长按「删除」）
  Future<void> deleteSearchBook(String bookUrl);

  // ========== 本地书籍操作 ==========

  /// 导入本地书籍
  Future<Book> importLocalBook(String filePath);

  /// 扫描本地书籍
  Future<List<Map<String, dynamic>>> scanLocalBooks(String dirPath);

  /// 检测书籍文件格式
  Future<String> detectFormat(String filePath);

  /// 解析书籍元数据
  Future<String> parseMetadata(String filePath);

  // ========== 本地 TXT 全文搜索（Task #98 缺口#4，加法式新增） ==========

  /// 搜索本地 TXT 文件内容（纯文本模式，章节感知）
  ///
  /// 对齐 Android 原版搜索页内“搜本地书正文”场景。
  /// 返回搜索结果列表，每项字段（snake_case）：
  /// `chapter_index`（章节序号）/ `chapter_title`（章节标题）/
  /// `char_offset`（匹配在章节内的字符偏移）/ `matched_text`（匹配文本）/
  /// `context`（上下文摘要）/ `context_match_start` / `context_match_end`
  /// （匹配在上下文中的起止位置）。
  Future<List<Map<String, dynamic>>> txtSearch(
    String path,
    String query, {
    bool caseSensitive = false,
    int maxResults = 500,
  });

  /// 使用正则表达式搜索本地 TXT 文件内容
  ///
  /// 返回格式同 [txtSearch]。
  Future<List<Map<String, dynamic>>> txtSearchRegex(
    String path,
    String pattern, {
    bool caseSensitive = false,
    int maxResults = 500,
  });

  /// 在本地 TXT 文件指定章节内搜索
  ///
  /// [chapterIndex] 为章节序号（从 0 开始）。返回格式同 [txtSearch]。
  Future<List<Map<String, dynamic>>> txtSearchInChapter(
    String path,
    String query,
    int chapterIndex, {
    bool caseSensitive = false,
    int maxResults = 50,
  });

  /// 统计本地 TXT 文件内关键词匹配总数（不返回完整结果，供 UI 显示计数）
  Future<int> txtSearchCount(
    String path,
    String query, {
    bool caseSensitive = false,
  });

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

  // ========== 图片磁盘缓存（对齐原版 BookHelp.saveImage/getImage，契约 §2.46） ==========

  /// 将图片字节落盘缓存（对齐原版 `BookHelp.writeImage`，契约 §2.46）
  ///
  /// [bookUrl] 书 URL（缓存目录按书隔离）；[url] 图片 URL（文件名 =
  /// MD5(url) 中段 16 字符 + 后缀，对齐原版 `MD5Utils.md5Encode16`）；
  /// [bytes] 图片原始字节。成功返回 `true`；写盘失败/输入非法返回
  /// `false`（静默降级，**不抛异常**——缓存失败不影响在线加载）。
  /// [P4-2a | 2026-09-29] 加法式新增（契约 §2.46 image_cache FFI）。
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  });

  /// 读取图片磁盘缓存（对齐原版 `BookHelp.getImage`/`isImageExist` 本地优先
  /// 语义，契约 §2.46）
  ///
  /// 命中返回图片字节；未命中或读失败返回 `null`（调用方降级走网络加载，
  /// 对齐原版 `MangaVH.mangaImagePath` L31-34 本地优先语义）。
  /// [P4-2a | 2026-09-29] 加法式新增（契约 §2.46 image_cache FFI）。
  Future<List<int>?> getImageCache(String bookUrl, String url);

  // ========== 音频章节文件缓存（对齐原版 AudioCacheManager，契约 §2.47） ==========

  /// 查询某章音频是否已缓存（只读、幂等，契约 §2.47 `audioCacheQuery`）
  ///
  /// 键规则严格对齐原版 `AudioCacheKey.from`：
  /// `md5Encode16(chapterUrl.ifBlank { chapterTitle })`（MD5 小写 hex 中段
  /// 16 字符、UTF-8、不 trim、大小写敏感；不含 bookUrl）。命中 = 键匹配
  /// **且** `.complete` 标记存在 **且** 音频文件 size > 0。
  /// 目录不存在/无权限/解析异常一律返回 `false`（失败降级，**不抛异常**
  /// ——缓存是加速器不是数据源）。[chapterIndex] 不参与键计算（对齐原版），
  /// 仅为与清理面保持同形签名。
  /// [B1 | 2026-10-04] 加法式新增（契约 §2.47 audio_cache FFI）。
  Future<bool> audioCacheQuery({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  });

  /// 列出该书已缓存音频章节的下标数组（只读、幂等，契约 §2.47 `audioCacheList`）
  ///
  /// 扫描 `{缓存根}/book_{md5_16(bookUrl)}` 内五段式文件名，仅收录通过
  /// `.complete` + size>0 校验的条目，章节下标去重升序；无缓存/失败返回空数组。
  /// [B1 | 2026-10-04] 加法式新增（契约 §2.47 audio_cache FFI）。
  Future<List<int>> audioCacheList({required String bookUrl});

  /// 清理某章音频缓存（幂等，契约 §2.47 `audioCacheClearChapter`）
  ///
  /// 只删该章键下的音频文件与 `.complete` 标记，不触碰同目录其他章节；
  /// 返回实际删除的文件数（含标记）；不存在/已删返回 `0`，不抛异常。
  /// [B1 | 2026-10-04] 加法式新增（契约 §2.47 audio_cache FFI）。
  Future<int> audioCacheClearChapter({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  });

  /// 清理该书全部音频缓存（幂等，契约 §2.47 `audioCacheClearBook`）
  ///
  /// 删除书级目录内全部文件（含标记）并尝试移除目录，返回实际删除的文件数；
  /// 不存在返回 `0`，不跨书、不抛异常。
  /// [B1 | 2026-10-04] 加法式新增（契约 §2.47 audio_cache FFI）。
  Future<int> audioCacheClearBook({required String bookUrl});

  // ========== 音频章节预下载写入面（对齐原版 AudioCacheService + AudioCacheManager，契约 §2.48） ==========

  /// 单章音频预下载安装（幂等，契约 §2.48 `audioCacheDownload`）
  ///
  /// Rust 全权执行下载安装（对齐 `AudioCacheManager.cacheChapter:132-199`）：
  /// 已提交缓存（key16 + `.complete` + size>0）直接返回 `already_cached` 不重下；
  /// 否则以 [playUrl] 经 AnalyzeUrl + 书源 headers/cookie/重试/限流语义**流式**
  /// 下载（字节零穿越 FFI），安装为五段式文件名 + `.complete` 标记。
  /// [chapterUrl]/[chapterTitle] 参与缓存键计算（同 [audioCacheQuery]）。
  /// 返回 JSON：`{"status":"installed"|"already_cached","path":…,"sizeBytes":N,
  /// "extension":…}`。**失败上抛异常不降级**（写入是显式用户动作，错误须驱动
  /// 调用方循环 failCount——有意区别于 §2.47 只读面的降级风格）。
  /// [B2 | 2026-10-03] 加法式新增（契约 §2.48 audio_cache 写入面）。
  Future<String> audioCacheDownload({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
    required String playUrl,
  });

  /// 取消在途音频预下载（契约 §2.48 `audioCacheCancel`）
  ///
  /// 进程级取消代数 +1：在途下载在流式块边界中止并删除部分文件（对齐原版
  /// 服务 stop 语义单槽化）。返回 `true` = 置位时快照到在途下载（尽力提示，
  /// 不作同步保证）；`false` = 当前无在途。调用方循环侧取消 = 调用本方法 +
  /// 停止发起后续章节调用。
  /// [B2 | 2026-10-03] 加法式新增（契约 §2.48 audio_cache 写入面）。
  Future<bool> audioCacheCancel();

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

  // ========== WebBook 操作 ==========

  /// 搜索书籍（书源规则驱动）
  Future<String> webbookSearch(String sourceJson, String query, int page);

  /// 获取书籍详情
  Future<String> webbookInfo(String sourceJson, String bookUrl);

  /// 获取章节列表
  ///
  /// [tocUrl] / [bookName] 可选：发现/搜索已带入时传给 Rust，跳过重复拉详情页。
  Future<String> webbookChapters(
    String sourceJson,
    String bookUrl, {
    String tocUrl = '',
    String bookName = '',
  });

  /// 获取章节正文
  Future<String> webbookContent(String sourceJson, String chapterJson);

  /// 流式书源调试（对齐 Kotlin Debug.Callback.printLog）
  ///
  /// 每条 Map：`state`（int）/ `msg`（String）。
  /// `state=-1` 失败、`1000` 完成。
  Stream<Map<String, dynamic>> debugBookSourceStream(
    String sourceUrl,
    String key,
  );

  /// 取消正在进行的书源调试
  Future<void> cancelDebugBookSource();

  // ========== 发现页操作 ==========

  /// 解析 exploreUrl 为分类列表
  ///
  /// [sourceJson] — `@js:` / `<js>` exploreUrl 必填书源 JSON
  Future<List<ExploreCategory>> exploreParseUrl(
    String exploreUrl, {
    String sourceJson = '',
  });

  /// 抓取发现分类的书籍列表
  Future<List<SearchBook>> exploreFetchBooks(
    String sourceJson,
    String url,
    int page,
  );

  /// 写入发现 infoMap（toggle/select 控件，对标 Android InfoMap）
  Future<void> exploreInfoMapPut(String sourceUrl, String key, String value);

  /// 初始化发现 infoMap 默认值（键不存在时写入）
  Future<void> exploreInfoMapEnsureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  );

  /// 读取发现 infoMap 快照（JSON 对象；UI 回显 toggle/select/text 已存值，
  /// 对齐原版 InfoMap 持久化语义）。加法式新增（2026-08-14 发现页修复 B①）。
  Future<String> exploreInfoMapSnapshot(String sourceUrl);

  /// 执行发现页控件 action JS（对标 Android evalButtonClick）
  ///
  /// 返回 map：`raw` / `actions` / `refreshExplore`。
  Future<Map<String, dynamic>> exploreEvalAction({
    required String sourceJson,
    required String actionJs,
  });

  /// 执行发现页 viewName 动态标题 JS（对标 Android evalUiJs）
  Future<String> exploreEvalUiJs({
    required String sourceJson,
    required String jsStr,
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

  /// 图片下载 + imageDecode 解码（返回 JSON：{ base64, len }）
  ///
  /// 对齐原版 ImageUtils.decodeImageStream：漫画/图片站图片 bytes 经书源
  /// imageDecode JS（配合 jsLib）解密后才可显示；无 imageDecode 规则时
  /// 返回原始图片 base64。[sourceJson] 为书源 JSON（单对象）。
  Future<String> fetchImageWithDecode(String url, String sourceJson);

  /// 读取本地 cbz 漫画单页图片字节（返回 JSON：{ base64, len }）
  ///
  /// [cbz 批 D | 2026-10-03] 与 Rust FFI `cbz_read_page` 对齐：本地 `.cbz`
  /// 书（bookType=LOCAL|image=0x1040）章节正文为 `cbz://<条目名>` 行列表，
  /// 漫画阅读器逐行调用本方法取图后渲染。
  ///
  /// - [path] — 本地书 bookUrl（绝对路径，或相对可迁移标识）
  /// - [entry] — ZIP 条目名（兼容带/不带 `cbz://` 前缀）
  Future<String> cbzReadPage({required String path, required String entry});

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

  /// 按书名执行启用封面规则搜封面（契约 §2.4.8，Task #74 加法式新增）
  ///
  /// 返回候选封面 URL 列表（Rust 裸 JSON Array 解析，§1.4 铁律）；
  /// 无启用规则或全部失败返回空列表（非异常）。
  Future<List<String>> searchCoverRules(String name);

  /// 读取封面规则配置（契约 §2.4 F4，对齐 BookCover.getCoverRule）
  ///
  /// 返回 `{enable, searchUrl, coverRule}`；表空时回退默认规则。
  Future<Map<String, dynamic>> getCoverRule();

  /// 保存封面规则（契约 §2.4 F4，对齐 BookCover.saveCoverRule）
  Future<bool> saveCoverRule(Map<String, dynamic> rule);

  /// 删除封面规则配置（契约 §2.4 F4，对齐 BookCover.delCoverRule）
  Future<bool> deleteCoverRule();

  // ========== 书籍格式解析 ==========

  /// 解析 TXT 文件
  Future<List<BookChapter>> parseTxt(String filePath);

  /// 解析 EPUB 文件
  Future<List<BookChapter>> parseEpub(String filePath);

  /// 导出书籍（将章节内容写入文件）
  Future<String> exportBook(String bookUrl, String format, String outDir);

  // ========== 音频播放 ==========

  /// 获取章节媒体信息
  ///
  /// 音频书取址（对齐 `AudioPlay` → `WebBook.getContent`）。
  /// 返回 Map 含 `mediaUrl`（可播地址）/ `url` / `isVolume` / `fromCache` 等，见契约 §2.26。
  Future<Map<String, dynamic>> getAudioChapterMedia(
    String bookUrl,
    int chapterIndex,
  );

  /// 获取音频播放进度
  Future<Map<String, dynamic>?> getAudioProgress(
    String bookUrl,
    int chapterIndex,
  );

  /// 保存音频播放进度
  Future<void> saveAudioProgress(
    String bookUrl,
    int chapterIndex,
    int positionMs,
  );

  // ========== 视频弹幕 ==========

  /// 查询某章弹幕数据（契约 §2.49，V-B1 视频弹幕数据链）
  ///
  /// 只读、幂等：读章节 variable 列 `danmaku` 键（对齐原版
  /// `BookChapter.putDanmaku`）；`<10000` 字符直返原文（B 站 XML 或
  /// 内联文本），`≥10000` 字符走大数据文件读回（`RuleBigDataHelp` 同构）。
  /// 无记录 / 书或章不在 DB / 读失败 → `null`（降级不抛——弹幕是增强层
  /// 不是数据源）。写入侧在 Rust 抓取链内部完成（媒体分支副内容捕获），
  /// 不经本接口。
  Future<String?> getVideoDanmaku({
    required String bookUrl,
    required int chapterIndex,
  });

  /// 解析 B 站弹幕 XML 为结构化弹幕项（契约 §2.50，V-B2 视频弹幕解析）
  ///
  /// 纯函数（Rust 侧 `parse_video_danmaku`）：`<d p="时间秒,类型,字号,颜色,...">`
  /// → [VideoDanmakuItem] 列表（按 timeMs 升序）；类型 2/3/8 静默丢弃对齐原版；
  /// type7 保留 JSON 属性原文（V-B2 不渲染，登记边界）；解析失败/非 XML/空
  /// → `null`（对齐原版 SAX 失败→null 静默无弹幕）。Dart 侧仅 JSON 解码。
  Future<List<VideoDanmakuItem>?> parseVideoDanmaku({required String raw});

  // ========== 段评（书源 ruleReview，对齐原版）==========

  /// 段评摘要（P2-9，对标 loadReviewSummary + parseSummary）
  ///
  /// 返回 JSON `{"counts":{"1":5},"keys":{"1":"paraData"}}`。
  /// 规则缺失/未启用返回空 maps（非异常）。
  Future<String> reviewGetSummary(String sourceJson, String requestJson);

  /// 段评详情分页（P2-9，对标 ReviewDetailDialog + parseDetailPage）
  ///
  /// 返回 JSON `{"items":[...],"nextPageUrl":String?,"hasReplyUrl":bool}`。
  Future<String> reviewGetDetail(
    String sourceJson,
    String requestJson,
    int page,
  );

  /// 按需加载段评回复（上游 #519）
  ///
  /// 返回 JSON 对象字符串 `{"items": [回复列表], "nextPageUrl": String?}`；
  /// 回复条目字段：id/avatar/name/badges/content/imageUrl/audioUrl/time。
  ///
  /// # 参数
  /// - `sourceJson`: BookSource JSON（含 ruleReview）
  /// - `requestJson`: 请求上下文 JSON，支持
  ///   reviewId/paraIndex/paraData/chapterUrl/replyUrl 字段
  /// - `page`: 回复页码（从 1 开始）
  Future<String> reviewGetReplies(
    String sourceJson,
    String requestJson,
    int page,
  );

  // ========== 书籍导出 ==========

  /// 导出书籍（返回 ExportResult JSON）
  Future<Map<String, dynamic>> bookExport({
    required String bookUrl,
    required String format,
    required bool includeToc,
  });

  /// 带选项导出（对齐 ExportBookService / API_CONTRACT §2.43.4）
  ///
  /// [optionsJson] 示例：`{"encoding":"GBK","startChapter":0,"endChapter":9,"fileNameTemplate":"{name} 作者：{author}"}`
  Future<Map<String, dynamic>> bookExportWithOptions({
    required String bookUrl,
    required String format,
    required bool includeToc,
    String optionsJson = '',
  });

  /// 获取导出预览信息
  Future<Map<String, dynamic>> bookExportInfo({
    required String bookUrl,
    required String format,
  });

  // ========== 自动任务（auto_task FFI） ==========

  /// 构建书籍更新定时任务
  Future<Map<String, dynamic>> autoTaskBuildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  });

  /// 批量更新 cron 表达式
  Future<List<Map<String, dynamic>>> autoTaskUpdateCronBatch({
    required String rulesJson,
    required String idsJson,
    required String cron,
  });

  /// 准备导入任务
  Future<List<Map<String, dynamic>>> autoTaskPrepareImported({
    required String localTasksJson,
    required String importedJson,
  });

  /// 执行任务协议
  Future<Map<String, dynamic>> autoTaskExecute({required String protocolJson});

  /// 带任务 ID 执行任务协议
  Future<Map<String, dynamic>> autoTaskExecuteWithId({
    required String protocolJson,
    required String taskId,
  });

  /// 规范化脚本
  Future<String> autoTaskNormalizeScript({required String script});

  /// 判断书籍是否允许刷新目录
  Future<bool> autoTaskCanRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  });

  /// 查找书籍更新任务
  Future<Map<String, dynamic>?> autoTaskFindBookUpdateTask({
    required String tasksJson,
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  });

  /// 解析 cron 表达式计算下次执行时间
  Future<int> autoTaskNextDueAt({required String cron, required int fromMs});

  // ========== 自动任务数据库 CRUD ==========

  /// 列出所有自动任务规则（按 customOrder 排序）
  Future<List<Map<String, dynamic>>> autoTaskListRules();

  /// 创建自动任务规则（返回任务 ID）
  Future<String> autoTaskCreateRule({required String ruleJson});

  /// 更新自动任务规则
  Future<void> autoTaskUpdateRule({required String ruleJson});

  /// 删除自动任务规则
  Future<void> autoTaskDeleteRule({required String id});

  /// 根据 ID 查询自动任务规则
  Future<Map<String, dynamic>?> autoTaskFindRuleById({required String id});

  // ========== 音频播放模式（audio FFI） ==========

  /// 将播放模式写入 readConfig JSON
  Future<String> audioWithPlayMode({String? readConfig, required int playMode});

  /// 解析听书书籍
  Future<Map<String, dynamic>?> audioResolvePlayBook({
    String? requestedBookUrl,
    String? cachedBookJson,
  });

  // ========== 压缩包导入 ==========

  /// 导入 ZIP 压缩包中的书籍文件
  Future<Map<String, dynamic>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  });

  /// 导入 RAR 压缩包中的书籍文件
  Future<Map<String, dynamic>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  });

  /// 列出 ZIP 压缩包中的书籍文件名
  Future<List<String>> archiveListZipFiles({required String zipPath});

  /// 列出 RAR 压缩包中的书籍文件名
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  });

  /// 检测 TXT 文件编码
  Future<Map<String, dynamic>> archiveDetectEncoding({
    required String filePath,
  });

  /// 转换 TXT 文件编码
  Future<Map<String, dynamic>> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  });

  /// 判断文件是否为压缩包格式
  Future<bool> archiveIsArchive({required String filePath});
}
