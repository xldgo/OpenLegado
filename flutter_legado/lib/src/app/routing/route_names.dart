/// 页面只依赖路由名称，不导入页面装配。— Codex + UI
abstract final class AppRoutes {
  static const home = '/';
  static const reader = '/reader';
  static const readerComic = '/reader-comic';
  static const search = '/search';
  static const sources = '/sources';
  static const sourceEdit = '/sources/edit';
  static const exploreShow = '/explore_show';
  static const settings = '/settings';
  static const privacy = '/privacy';
  static const otherSettings = '/other_settings';
  // [UI_SYNC_REFACTOR S6 | 2026-09-08] 设置主页（集中化分组入口）— Qoder
  static const cacheSettings = '/cache_settings';
  static const cacheDownloads = '/cache_downloads';
  // [UI-fix v2.0.17 | 2026-08-11] 离线缓存页（对齐原版 CacheActivity 书籍列表）— Reasonix
  static const offlineCache = '/offline_cache';
  static const rss = '/rss';
  static const ruleSub = '/rule_sub';
  static const audio = '/audio';
  static const bookInfo = '/book_info';
  static const editBookInfo = '/edit_book_info';
  static const changeSource = '/change_source';
  static const readingStats = '/reading_stats'; // 历史别名，重定向到阅读记录
  static const readRecord = '/read_record';
  static const readRecordOverview = '/read_record_overview';
  static const bookmarks = '/bookmarks';
  static const replaceRules = '/replace_rules';
  // [A3 形态对齐 | full-stack-engineer + UI] 替换规则整页编辑器
  static const replaceRuleEdit = '/replace_rule_edit';
  static const autoTasks = '/auto_tasks';
  static const sourceDebug = '/sources/debug';
  static const rssSourceEdit = '/rss/edit';
  static const readAloudConfig = '/read_aloud_config';
  static const readAloudSettings = '/read_aloud_settings';
  static const readAloudPlayer = '/read_aloud_player';
  static const themeConfig = '/theme_config';
  static const bottomBarSkin = '/bottom_bar_skin';
  static const importBooks = '/import_books';
  static const remoteBooks = '/remote_books';
  static const bookGroups = '/book_groups';
  static const bookshelfManage = '/bookshelf/manage';
  static const searchContent = '/search_content';
  // [UI-fix v2.0.3 | 2026-08-08] 新增独立目录页路由（对齐原版 TocActivity） — Qoder
  static const toc = '/toc';
  static const about = '/about';
  static const appLog = '/app_log';
  // discover 路由已删除（原版不存在的功能）
  // [UI-fix v2.0.2 | 2026-08-06] 结构治理：删除 rssConfig 路由（原版无此页，订阅源管理统一走 rssSourceManage）— Qoder
  static const rssSourceManage = '/rss/manage';
  static const rssFavorites = '/rss/favorites';
  static const rssSourceDebug = '/rss/source_debug';
  static const changeCover = '/change_cover';
  static const txtTocRules = '/txt_toc_rules';
  static const dict = '/dict';
  // [C2 批2 | full-stack-engineer + UI] 字典规则管理页（对齐原版 DictRuleActivity）
  static const dictRule = '/dict_rule';
  static const fonts = '/fonts';
  static const highlightRules = '/highlight_rules';
  static const fileManage = '/file_manage';
  static const qrcode = '/qrcode';
  static const welcome = '/welcome';
  static const welcomeConfig = '/welcome_config';
  static const browser = '/browser';
  static const video = '/video';
  static const webdavSettings = '/webdav_settings';
  // rssArticles 和 rssArticleDetail 通过 Navigator.push 传参，不在此注册
}
