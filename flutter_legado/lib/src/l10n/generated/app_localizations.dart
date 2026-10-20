import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @themeFontSettings.
  ///
  /// In zh, this message translates to:
  /// **'字体设置'**
  String get themeFontSettings;

  /// No description provided for @themeFontImport.
  ///
  /// In zh, this message translates to:
  /// **'导入字体'**
  String get themeFontImport;

  /// No description provided for @themeFontPreview.
  ///
  /// In zh, this message translates to:
  /// **'天地玄黄，宇宙洪荒。\nThe quick brown fox 0123456789'**
  String get themeFontPreview;

  /// No description provided for @themeDynamicColor.
  ///
  /// In zh, this message translates to:
  /// **'动态取色'**
  String get themeDynamicColor;

  /// No description provided for @httpCache.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 缓存'**
  String get httpCache;

  /// No description provided for @coverCache.
  ///
  /// In zh, this message translates to:
  /// **'封面缓存'**
  String get coverCache;

  /// No description provided for @mangaCache.
  ///
  /// In zh, this message translates to:
  /// **'漫画缓存'**
  String get mangaCache;

  /// No description provided for @cacheBookThreadCount.
  ///
  /// In zh, this message translates to:
  /// **'书籍缓存下载线程数'**
  String get cacheBookThreadCount;

  /// No description provided for @preDownloadPrevious.
  ///
  /// In zh, this message translates to:
  /// **'向前预下载'**
  String get preDownloadPrevious;

  /// No description provided for @preDownloadNext.
  ///
  /// In zh, this message translates to:
  /// **'向后预下载'**
  String get preDownloadNext;

  /// No description provided for @featurePending.
  ///
  /// In zh, this message translates to:
  /// **'待实现'**
  String get featurePending;

  /// No description provided for @downloadAndCache.
  ///
  /// In zh, this message translates to:
  /// **'下载与缓存'**
  String get downloadAndCache;

  /// No description provided for @downloadAndCacheSummary.
  ///
  /// In zh, this message translates to:
  /// **'下载并发、预下载、图片缓存与清理'**
  String get downloadAndCacheSummary;

  /// No description provided for @downloadSettings.
  ///
  /// In zh, this message translates to:
  /// **'下载设置'**
  String get downloadSettings;

  /// No description provided for @imageCache.
  ///
  /// In zh, this message translates to:
  /// **'图片缓存'**
  String get imageCache;

  /// No description provided for @themeLiquidBottomBar.
  ///
  /// In zh, this message translates to:
  /// **'悬浮底栏液态玻璃'**
  String get themeLiquidBottomBar;

  /// No description provided for @themeLiquidBottomBarSummary.
  ///
  /// In zh, this message translates to:
  /// **'折射背景与滑动选中效果'**
  String get themeLiquidBottomBarSummary;

  /// 应用文案：阅读
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get appTitle;

  /// 应用文案：书架
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get bookshelf;

  /// 应用文案：搜索
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// 应用文案：书源
  ///
  /// In zh, this message translates to:
  /// **'书源'**
  String get sources;

  /// 应用文案：设置
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// 应用文案：我的
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get my;

  /// 应用文案：订阅
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get rss;

  /// 应用文案：发现
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get discover;

  /// 应用文案：确定
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// 应用文案：取消
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 应用文案：保存
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// 应用文案：删除
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// 应用文案：编辑
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// 应用文案：加载中...
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// 应用文案：错误
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// 应用文案：暂无数据
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// 应用文案：重试
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// 应用文案：加载失败
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// 应用文案：再按一次退出程序
  ///
  /// In zh, this message translates to:
  /// **'再按一次退出程序'**
  String get doubleClickExit;

  /// 应用文案：我是有底线的
  ///
  /// In zh, this message translates to:
  /// **'我是有底线的'**
  String get bottomLine;

  /// 应用文案：开始阅读
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get startReading;

  /// 应用文案：加入书架
  ///
  /// In zh, this message translates to:
  /// **'加入书架'**
  String get addToBookshelf;

  /// 应用文案：移除
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeFromBookshelf;

  /// 应用文案：更新目录
  ///
  /// In zh, this message translates to:
  /// **'更新目录'**
  String get updateToc;

  /// 应用文案：搜索书名或作者
  ///
  /// In zh, this message translates to:
  /// **'搜索书名或作者'**
  String get searchHint;

  /// 应用文案：不分组
  ///
  /// In zh, this message translates to:
  /// **'不分组'**
  String get groupByNone;

  /// 应用文案：按来源
  ///
  /// In zh, this message translates to:
  /// **'按来源'**
  String get groupBySource;

  /// 应用文案：按分组
  ///
  /// In zh, this message translates to:
  /// **'按分组'**
  String get groupByTag;

  /// 应用文案：更新目录
  ///
  /// In zh, this message translates to:
  /// **'更新目录'**
  String get updateAll;

  /// 应用文案：书架管理
  ///
  /// In zh, this message translates to:
  /// **'书架管理'**
  String get manageBookshelf;

  /// 应用文案：书源管理
  ///
  /// In zh, this message translates to:
  /// **'书源管理'**
  String get sourceManagement;

  /// 应用文案：不分组
  ///
  /// In zh, this message translates to:
  /// **'不分组'**
  String get groupByNoneLabel;

  /// 应用文案：按来源分组
  ///
  /// In zh, this message translates to:
  /// **'按来源分组'**
  String get groupBySourceLabel;

  /// 应用文案：按分组分组
  ///
  /// In zh, this message translates to:
  /// **'按分组分组'**
  String get groupByGroupLabel;

  /// 应用文案：列表视图
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// 应用文案：网格视图
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// 应用文案：添加书籍
  ///
  /// In zh, this message translates to:
  /// **'添加书籍'**
  String get addBook;

  /// 应用文案：添加本地
  ///
  /// In zh, this message translates to:
  /// **'添加本地'**
  String get addLocalBook;

  /// 应用文案：书架还空着，先去搜索书籍或从发现里添加吧！
  ///
  /// In zh, this message translates to:
  /// **'书架还空着，先去搜索书籍或从发现里添加吧！'**
  String get emptyBookshelf;

  /// 应用文案：
  ///
  /// In zh, this message translates to:
  /// **''**
  String get emptyBookshelfHint;

  /// 应用文案：加载书架...
  ///
  /// In zh, this message translates to:
  /// **'加载书架...'**
  String get loadingBookshelf;

  /// 应用文案：最近阅读
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get recentReading;

  /// 应用文案：全部
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allBooks;

  /// 应用文案：在读
  ///
  /// In zh, this message translates to:
  /// **'在读'**
  String get reading;

  /// 应用文案：未读
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get unread;

  /// 应用文案：未知章节
  ///
  /// In zh, this message translates to:
  /// **'未知章节'**
  String get unknownChapter;

  /// 应用文案：置顶
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinToTop;

  /// 应用文案：编辑信息
  ///
  /// In zh, this message translates to:
  /// **'编辑信息'**
  String get editInfo;

  /// 应用文案：分组
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get group;

  /// 应用文案：删除书籍
  ///
  /// In zh, this message translates to:
  /// **'删除书籍'**
  String get deleteBook;

  /// 应用文案：确定要从书架中删除
  ///
  /// In zh, this message translates to:
  /// **'确定要从书架中删除'**
  String get confirmDeleteBook;

  /// 应用文案：正在检查更新...
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get checkingUpdate;

  /// 应用文案：选择本地书籍文件
  ///
  /// In zh, this message translates to:
  /// **'选择本地书籍文件'**
  String get selectLocalBook;

  /// 应用文案：导入书源
  ///
  /// In zh, this message translates to:
  /// **'导入书源'**
  String get importSources;

  /// 应用文案：导出书源
  ///
  /// In zh, this message translates to:
  /// **'导出书源'**
  String get exportSources;

  /// 应用文案：添加书源
  ///
  /// In zh, this message translates to:
  /// **'添加书源'**
  String get addSource;

  /// 应用文案：书源名称
  ///
  /// In zh, this message translates to:
  /// **'书源名称'**
  String get sourceName;

  /// 应用文案：书源地址
  ///
  /// In zh, this message translates to:
  /// **'书源地址'**
  String get sourceUrl;

  /// 应用文案：书源类型
  ///
  /// In zh, this message translates to:
  /// **'书源类型'**
  String get sourceType;

  /// 应用文案：主题模式
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// 应用文案：跟随系统
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// 应用文案：浅色
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// 应用文案：深色
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// 应用文案：语言
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// 应用文案：跟随系统
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get langSystem;

  /// 应用文案：中文
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get langChinese;

  /// 应用文案：English
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// 应用文案：备份
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backup;

  /// 应用文案：恢复
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// 应用文案：云同步
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSync;

  /// 应用文案：清除缓存
  ///
  /// In zh, this message translates to:
  /// **'清除缓存'**
  String get clearCache;

  /// 应用文案：外观设置
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get appearanceSettings;

  /// 应用文案：阅读设置
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettings;

  /// 应用文案：网络设置
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get networkSettings;

  /// 应用文案：数据管理
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// 应用文案：其他
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get otherSettings;

  /// 应用文案：关于
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutSettings;

  /// 应用文案：默认字体大小
  ///
  /// In zh, this message translates to:
  /// **'默认字体大小'**
  String get defaultFontSize;

  /// 应用文案：默认行距
  ///
  /// In zh, this message translates to:
  /// **'默认行距'**
  String get defaultLineHeight;

  /// 应用文案：默认背景色
  ///
  /// In zh, this message translates to:
  /// **'默认背景色'**
  String get defaultBgColor;

  /// 应用文案：白色
  ///
  /// In zh, this message translates to:
  /// **'白色'**
  String get whiteColor;

  /// 应用文案：代理设置
  ///
  /// In zh, this message translates to:
  /// **'代理设置'**
  String get proxySettings;

  /// 应用文案：不使用代理
  ///
  /// In zh, this message translates to:
  /// **'不使用代理'**
  String get noProxy;

  /// 应用文案：请求超时
  ///
  /// In zh, this message translates to:
  /// **'请求超时'**
  String get requestTimeout;

  /// 应用文案：30 秒
  ///
  /// In zh, this message translates to:
  /// **'30 秒'**
  String get seconds30;

  /// 应用文案：秒
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get secondsUnit;

  /// 应用文案：备份数据
  ///
  /// In zh, this message translates to:
  /// **'备份数据'**
  String get backupData;

  /// 应用文案：备份书架和书源到本地
  ///
  /// In zh, this message translates to:
  /// **'备份书架和书源到本地'**
  String get backupDataDesc;

  /// 应用文案：恢复数据
  ///
  /// In zh, this message translates to:
  /// **'恢复数据'**
  String get restoreData;

  /// 应用文案：从备份文件恢复
  ///
  /// In zh, this message translates to:
  /// **'从备份文件恢复'**
  String get restoreDataDesc;

  /// 应用文案：清除临时文件和缓存数据
  ///
  /// In zh, this message translates to:
  /// **'清除临时文件和缓存数据'**
  String get clearCacheDesc;

  /// 应用文案：选择主题模式
  ///
  /// In zh, this message translates to:
  /// **'选择主题模式'**
  String get selectTheme;

  /// 应用文案：备份成功
  ///
  /// In zh, this message translates to:
  /// **'备份成功'**
  String get backupSuccess;

  /// 应用文案：备份失败
  ///
  /// In zh, this message translates to:
  /// **'备份失败'**
  String get backupFailed;

  /// 应用文案：恢复成功
  ///
  /// In zh, this message translates to:
  /// **'恢复成功'**
  String get restoreSuccess;

  /// 应用文案：恢复失败
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get restoreFailed;

  /// 应用文案：粘贴备份 JSON 数据
  ///
  /// In zh, this message translates to:
  /// **'粘贴备份 JSON 数据'**
  String get pasteBackupJson;

  /// 应用文案：确定要清除所有缓存数据吗？
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有缓存数据吗？'**
  String get confirmClearCache;

  /// 应用文案：缓存已清除
  ///
  /// In zh, this message translates to:
  /// **'缓存已清除'**
  String get cacheCleared;

  /// 应用文案：版本
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// 应用文案：开源协议
  ///
  /// In zh, this message translates to:
  /// **'开源协议'**
  String get license;

  /// 应用文案：项目地址
  ///
  /// In zh, this message translates to:
  /// **'项目地址'**
  String get projectUrl;

  /// 应用文案：立即同步
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// 应用文案：自动同步
  ///
  /// In zh, this message translates to:
  /// **'自动同步'**
  String get autoSync;

  /// 应用文案：定期同步书架数据
  ///
  /// In zh, this message translates to:
  /// **'定期同步书架数据'**
  String get autoSyncDesc;

  /// 应用文案：同步成功
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// 应用文案：保存配置
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get saveConfig;

  /// 应用文案：配置已保存
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get configSaved;

  /// 应用文案：上传书架
  ///
  /// In zh, this message translates to:
  /// **'上传书架'**
  String get uploadBookshelf;

  /// 应用文案：将本地书架上传到 WebDAV
  ///
  /// In zh, this message translates to:
  /// **'将本地书架上传到 WebDAV'**
  String get uploadBookshelfDesc;

  /// 应用文案：下载书架
  ///
  /// In zh, this message translates to:
  /// **'下载书架'**
  String get downloadBookshelf;

  /// 应用文案：从 WebDAV 下载书架覆盖本地
  ///
  /// In zh, this message translates to:
  /// **'从 WebDAV 下载书架覆盖本地'**
  String get downloadBookshelfDesc;

  /// 应用文案：合并同步
  ///
  /// In zh, this message translates to:
  /// **'合并同步'**
  String get mergeSync;

  /// 应用文案：双向合并本地与远程书架
  ///
  /// In zh, this message translates to:
  /// **'双向合并本地与远程书架'**
  String get mergeSyncDesc;

  /// 应用文案：WebDAV 服务器 URL
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 服务器 URL'**
  String get webdavServerUrl;

  /// 应用文案：用户名
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// 应用文案：密码
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// 应用文案：远程目录
  ///
  /// In zh, this message translates to:
  /// **'远程目录'**
  String get remoteDir;

  /// 应用文案：上次同步
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// 应用文案：搜索书名、作者...
  ///
  /// In zh, this message translates to:
  /// **'搜索书名、作者...'**
  String get searchBookHint;

  /// 应用文案：搜索中...
  ///
  /// In zh, this message translates to:
  /// **'搜索中...'**
  String get searching;

  /// 应用文案：未找到相关书籍
  ///
  /// In zh, this message translates to:
  /// **'未找到相关书籍'**
  String get noResults;

  /// 应用文案：换个关键词试试，或检查书源是否启用
  ///
  /// In zh, this message translates to:
  /// **'换个关键词试试，或检查书源是否启用'**
  String get noResultsHint;

  /// 应用文案：搜索书籍
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍'**
  String get searchBooks;

  /// 应用文案：输入书名或作者名开始搜索
  ///
  /// In zh, this message translates to:
  /// **'输入书名或作者名开始搜索'**
  String get searchBooksHint;

  /// 应用文案：搜索历史
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get searchHistory;

  /// 应用文案：清空
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearHistory;

  /// 应用文案：作者
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get author;

  /// 应用文案：来源
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get source;

  /// 应用文案：章
  ///
  /// In zh, this message translates to:
  /// **'章'**
  String get chapters;

  /// 应用文案：已加入书架
  ///
  /// In zh, this message translates to:
  /// **'已加入书架'**
  String get addedToBookshelf;

  /// 应用文案：字体大小
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// 应用文案：行距
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get lineHeight;

  /// 应用文案：翻页模式
  ///
  /// In zh, this message translates to:
  /// **'翻页模式'**
  String get flipMode;

  /// 应用文案：上下滚动
  ///
  /// In zh, this message translates to:
  /// **'上下滚动'**
  String get scrollMode;

  /// 应用文案：左右滑动
  ///
  /// In zh, this message translates to:
  /// **'左右滑动'**
  String get slideMode;

  /// 应用文案：仿真翻页
  ///
  /// In zh, this message translates to:
  /// **'仿真翻页'**
  String get simulateMode;

  /// 应用文案：无动画
  ///
  /// In zh, this message translates to:
  /// **'无动画'**
  String get noneMode;

  /// 应用文案：覆盖
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get coverMode;

  /// 应用文案：加载章节...
  ///
  /// In zh, this message translates to:
  /// **'加载章节...'**
  String get loadingChapter;

  /// 应用文案：暂无内容
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get noContent;

  /// 应用文案：目录
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get catalog;

  /// 应用文案：夜间
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get nightMode;

  /// 应用文案：朗读
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get readAloud;

  /// 应用文案：界面
  ///
  /// In zh, this message translates to:
  /// **'界面'**
  String get interfaceSetting;

  /// 应用文案：阅读设置
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettingsTitle;

  /// 应用文案：字体大小
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSizeLabel;

  /// 应用文案：小
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSmall;

  /// 应用文案：大
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontLarge;

  /// 应用文案：行距
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get lineHeightLabel;

  /// 应用文案：背景色
  ///
  /// In zh, this message translates to:
  /// **'背景色'**
  String get bgColor;

  /// 应用文案：翻页模式
  ///
  /// In zh, this message translates to:
  /// **'翻页模式'**
  String get flipModeLabel;

  /// 应用文案：上一章
  ///
  /// In zh, this message translates to:
  /// **'上一章'**
  String get previousChapter;

  /// 应用文案：下一章
  ///
  /// In zh, this message translates to:
  /// **'下一章'**
  String get nextChapter;

  /// 应用文案：暂无章节
  ///
  /// In zh, this message translates to:
  /// **'暂无章节'**
  String get noChapters;

  /// 应用文案：听书
  ///
  /// In zh, this message translates to:
  /// **'听书'**
  String get audioPlayer;

  /// 应用文案：播放
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// 应用文案：暂停
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// 应用文案：上一章
  ///
  /// In zh, this message translates to:
  /// **'上一章'**
  String get prevChapterAudio;

  /// 应用文案：下一章
  ///
  /// In zh, this message translates to:
  /// **'下一章'**
  String get nextChapterAudio;

  /// 主界面文案：首页
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// 主界面文案：帮助
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get help;

  /// 主界面文案：内容与规则
  ///
  /// In zh, this message translates to:
  /// **'内容与规则'**
  String get contentAndRules;

  /// 主界面文案：订阅源管理
  ///
  /// In zh, this message translates to:
  /// **'订阅源管理'**
  String get rssSourceManagement;

  /// 主界面文案：新建、导入、编辑或管理书源
  ///
  /// In zh, this message translates to:
  /// **'新建、导入、编辑或管理书源'**
  String get sourceManagementSummary;

  /// 主界面文案：新建、导入、编辑或管理订阅源
  ///
  /// In zh, this message translates to:
  /// **'新建、导入、编辑或管理订阅源'**
  String get rssSourceManagementSummary;

  /// 主界面文案：TXT 目录规则
  ///
  /// In zh, this message translates to:
  /// **'TXT 目录规则'**
  String get txtTocRules;

  /// 主界面文案：配置 TXT 目录规则
  ///
  /// In zh, this message translates to:
  /// **'配置 TXT 目录规则'**
  String get txtTocRulesSummary;

  /// 主界面文案：替换净化
  ///
  /// In zh, this message translates to:
  /// **'替换净化'**
  String get replaceRules;

  /// 主界面文案：配置替换净化规则
  ///
  /// In zh, this message translates to:
  /// **'配置替换净化规则'**
  String get replaceRulesSummary;

  /// 主界面文案：字典查询
  ///
  /// In zh, this message translates to:
  /// **'字典查询'**
  String get dictionaryLookup;

  /// 主界面文案：按字典规则查询内容
  ///
  /// In zh, this message translates to:
  /// **'按字典规则查询内容'**
  String get dictionaryLookupSummary;

  /// 主界面文案：字典规则
  ///
  /// In zh, this message translates to:
  /// **'字典规则'**
  String get dictionaryRules;

  /// 主界面文案：管理字典规则（增删改、启停、排序、导入）
  ///
  /// In zh, this message translates to:
  /// **'管理字典规则（增删改、启停、排序、导入）'**
  String get dictionaryRulesSummary;

  /// 主界面文案：高亮标注
  ///
  /// In zh, this message translates to:
  /// **'高亮标注'**
  String get highlightRules;

  /// 主界面文案：自动高亮标注规则
  ///
  /// In zh, this message translates to:
  /// **'自动高亮标注规则'**
  String get highlightRulesSummary;

  /// 主界面文案：外观
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// 主界面文案：主题配色与显示模式
  ///
  /// In zh, this message translates to:
  /// **'主题配色与显示模式'**
  String get appearanceSummary;

  /// 主界面文案：阅读界面
  ///
  /// In zh, this message translates to:
  /// **'阅读界面'**
  String get readingInterface;

  /// 主界面文案：字体、配色、翻页与屏幕显示
  ///
  /// In zh, this message translates to:
  /// **'字体、配色、翻页与屏幕显示'**
  String get readingInterfaceSummary;

  /// 主界面文案：同步与服务
  ///
  /// In zh, this message translates to:
  /// **'同步与服务'**
  String get syncAndServices;

  /// No description provided for @webServiceAutoStart.
  ///
  /// In zh, this message translates to:
  /// **'启动应用时开启 Web 服务'**
  String get webServiceAutoStart;

  /// No description provided for @readerShowIconLabels.
  ///
  /// In zh, this message translates to:
  /// **'显示图标文字'**
  String get readerShowIconLabels;

  /// No description provided for @webServiceAutoStartDescription.
  ///
  /// In zh, this message translates to:
  /// **'下次启动应用时生效，不改变当前运行状态'**
  String get webServiceAutoStartDescription;

  /// No description provided for @webServiceSettingsSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'Web 服务设置保存失败：{error}'**
  String webServiceSettingsSaveFailed(String error);

  /// No description provided for @webServiceChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在读取服务状态'**
  String get webServiceChecking;

  /// No description provided for @webServiceRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中，端口 {port}'**
  String webServiceRunning(int port);

  /// No description provided for @webServiceStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'Web 服务异常：{error}'**
  String webServiceStatusFailed(String error);

  /// 主界面文案：Web 服务
  ///
  /// In zh, this message translates to:
  /// **'Web 服务'**
  String get webService;

  /// 主界面文案：MCP 服务
  ///
  /// In zh, this message translates to:
  /// **'MCP 服务'**
  String get mcpService;

  /// 主界面文案：备份与恢复
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupAndRestore;

  /// 主界面文案：WebDav 设置/导入旧版本数据
  ///
  /// In zh, this message translates to:
  /// **'WebDav 设置/导入旧版本数据'**
  String get backupAndRestoreSummary;

  /// 主界面文案：缓存管理
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get cacheManagement;

  /// 主界面文案：书籍下载任务与缓存进度
  ///
  /// In zh, this message translates to:
  /// **'书籍下载任务与缓存进度'**
  String get cacheManagementSummary;

  /// 主界面文案：定时任务
  ///
  /// In zh, this message translates to:
  /// **'定时任务'**
  String get scheduledTasks;

  /// 主界面文案：管理按计划执行的 JavaScript 任务
  ///
  /// In zh, this message translates to:
  /// **'管理按计划执行的 JavaScript 任务'**
  String get scheduledTasksSummary;

  /// 主界面文案：运行定时任务
  ///
  /// In zh, this message translates to:
  /// **'运行定时任务'**
  String get runScheduledTasks;

  /// 主界面文案：重启后保留计划；Android 可能延后实际执行时间
  ///
  /// In zh, this message translates to:
  /// **'重启后保留计划；Android 可能延后实际执行时间'**
  String get runScheduledTasksSummary;

  /// 主界面文案：高级
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get advanced;

  /// 主界面文案：功能相关的一些设置
  ///
  /// In zh, this message translates to:
  /// **'功能相关的一些设置'**
  String get advancedSummary;

  /// 主界面文案：书签
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarks;

  /// 主界面文案：所有书签
  ///
  /// In zh, this message translates to:
  /// **'所有书签'**
  String get allBookmarks;

  /// 主界面文案：阅读记录
  ///
  /// In zh, this message translates to:
  /// **'阅读记录'**
  String get readingRecords;

  /// 主界面文案：阅读时间记录
  ///
  /// In zh, this message translates to:
  /// **'阅读时间记录'**
  String get readingRecordsSummary;

  /// 主界面文案：文件管理
  ///
  /// In zh, this message translates to:
  /// **'文件管理'**
  String get fileManagement;

  /// 主界面文案：管理私有文件夹的文件
  ///
  /// In zh, this message translates to:
  /// **'管理私有文件夹的文件'**
  String get fileManagementSummary;

  /// 主界面文案：退出
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exitApp;

  /// 主界面文案：确定退出阅读吗？
  ///
  /// In zh, this message translates to:
  /// **'确定退出阅读吗？'**
  String get confirmExitApp;

  /// 主界面文案：用浏览器写源或看书
  ///
  /// In zh, this message translates to:
  /// **'用浏览器写源或看书'**
  String get webServiceSummary;

  /// 主界面文案：带令牌保护的书源开发工具
  ///
  /// In zh, this message translates to:
  /// **'带令牌保护的书源开发工具'**
  String get mcpServiceSummary;

  /// 主界面文案：需先配置「Web 书源访问令牌」（我的 → 高级 → 其他设置）
  ///
  /// In zh, this message translates to:
  /// **'需先配置「Web 书源访问令牌」（我的 → 高级 → 其他设置）'**
  String get mcpTokenRequired;

  /// 主界面文案：累计阅读
  ///
  /// In zh, this message translates to:
  /// **'累计阅读'**
  String get booksRead;

  /// 主界面文案：阅读时长
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get readingDuration;

  /// No description provided for @setReadingGoal.
  ///
  /// In zh, this message translates to:
  /// **'设定阅读目标'**
  String get setReadingGoal;

  /// No description provided for @readingGoalMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标（分钟）'**
  String get readingGoalMinutesLabel;

  /// 主界面文案：今日阅读目标
  ///
  /// In zh, this message translates to:
  /// **'今日阅读目标'**
  String get todayReadingGoal;

  /// 主界面文案：分钟
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutesUnit;

  /// 主界面文案：阅读热力图
  ///
  /// In zh, this message translates to:
  /// **'阅读热力图'**
  String get readingHeatmap;

  /// 主界面文案：每日阅读时长
  ///
  /// In zh, this message translates to:
  /// **'每日阅读时长'**
  String get dailyReadingDuration;

  /// 主界面文案：编辑目标
  ///
  /// In zh, this message translates to:
  /// **'编辑目标'**
  String get editReadingGoal;

  /// 主界面文案：少
  ///
  /// In zh, this message translates to:
  /// **'少'**
  String get heatmapLess;

  /// 主界面文案：多
  ///
  /// In zh, this message translates to:
  /// **'多'**
  String get heatmapMore;

  /// 主界面文案：多（格 = 当日阅读书籍数）
  ///
  /// In zh, this message translates to:
  /// **'多（格 = 当日阅读书籍数）'**
  String get heatmapBooksLegend;

  /// 主界面文案：全选
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// 主界面文案：反选
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get invertSelection;

  /// 主界面文案：更多
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// 主界面文案：远程书籍
  ///
  /// In zh, this message translates to:
  /// **'远程书籍'**
  String get remoteBooks;

  /// 主界面文案：布局设置
  ///
  /// In zh, this message translates to:
  /// **'布局设置'**
  String get layoutSettings;

  /// 主界面文案：分组管理
  ///
  /// In zh, this message translates to:
  /// **'分组管理'**
  String get groupManagement;

  /// 主界面文案：添加网址
  ///
  /// In zh, this message translates to:
  /// **'添加网址'**
  String get addBookUrl;

  /// 主界面文案：选择模式
  ///
  /// In zh, this message translates to:
  /// **'选择模式'**
  String get selectionMode;

  /// 主界面文案：离线缓存
  ///
  /// In zh, this message translates to:
  /// **'离线缓存'**
  String get offlineCache;

  /// 主界面文案：导出书单
  ///
  /// In zh, this message translates to:
  /// **'导出书单'**
  String get exportBookList;

  /// 主界面文案：导入书单
  ///
  /// In zh, this message translates to:
  /// **'导入书单'**
  String get importBookList;

  /// 主界面文案：日志
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logs;

  /// 主界面文案：布局方式
  ///
  /// In zh, this message translates to:
  /// **'布局方式'**
  String get layoutStyle;

  /// 主界面文案：列表
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get listLayout;

  /// 主界面文案：分组方式
  ///
  /// In zh, this message translates to:
  /// **'分组方式'**
  String get groupStyle;

  /// 主界面文案：按分组显示
  ///
  /// In zh, this message translates to:
  /// **'按分组显示'**
  String get groupByGroup;

  /// 主界面文案：书架为空，无可导出的书单
  ///
  /// In zh, this message translates to:
  /// **'书架为空，无可导出的书单'**
  String get emptyExportBookList;

  /// 主界面文案：没有需要更新的书籍
  ///
  /// In zh, this message translates to:
  /// **'没有需要更新的书籍'**
  String get noBooksToUpdate;

  /// 主界面文案：准备中...
  ///
  /// In zh, this message translates to:
  /// **'准备中...'**
  String get preparing;

  /// 主界面文案：输入书籍详情页 URL（多行可加多本）
  ///
  /// In zh, this message translates to:
  /// **'输入书籍详情页 URL（多行可加多本）'**
  String get bookUrlHint;

  /// 主界面文案：书名（可选，无法获取详情时兑底）
  ///
  /// In zh, this message translates to:
  /// **'书名（可选，无法获取详情时兑底）'**
  String get bookNameOptionalHint;

  /// 主界面文案：输入书单 URL 或 JSON 数组
  ///
  /// In zh, this message translates to:
  /// **'输入书单 URL 或 JSON 数组'**
  String get bookListInputHint;

  /// 主界面文案：选择文件（txt/json）
  ///
  /// In zh, this message translates to:
  /// **'选择文件（txt/json）'**
  String get chooseBookListFile;

  /// 主界面文案：导入
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importAction;

  /// 主界面文案：书单格式不对（应为 URL 或 JSON 数组）
  ///
  /// In zh, this message translates to:
  /// **'书单格式不对（应为 URL 或 JSON 数组）'**
  String get invalidBookList;

  /// 主界面文案：退出选择
  ///
  /// In zh, this message translates to:
  /// **'退出选择'**
  String get exitSelection;

  /// 主界面文案：批量下载
  ///
  /// In zh, this message translates to:
  /// **'批量下载'**
  String get batchDownload;

  /// 主界面文案：移动分组
  ///
  /// In zh, this message translates to:
  /// **'移动分组'**
  String get moveBookGroup;

  /// 主界面文案：iOS 选择器显示全部文件，仅电子书格式（epub/txt/mobi/azw3/azw/pdf/umd/cbz）可导入
  ///
  /// In zh, this message translates to:
  /// **'iOS 选择器显示全部文件，仅电子书格式（epub/txt/mobi/azw3/azw/pdf/umd/cbz）可导入'**
  String get iosBookPickerHint;

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{count} 本'**
  String bookCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String minuteCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时'**
  String hourCount(String hours);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String secondCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时 {minutes} 分'**
  String hourMinuteCount(int hours, int minutes);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'每日时长加载失败：{error}'**
  String dailyDurationLoadFailed(String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'Web 服务切换失败: {error}'**
  String webServiceToggleFailed(String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'MCP 服务切换失败: {error}'**
  String mcpServiceToggleFailed(String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'端口 {port}（带令牌保护的书源开发工具）'**
  String mcpServicePort(int port);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{status} · 后台保活不可用，请保持 App 打开'**
  String webKeepAliveUnavailable(String status);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'确定删除选中的 {count} 本书籍吗？'**
  String confirmDeleteSelectedBooks(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 本书籍'**
  String deletedBookCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'网格（{count} 列）'**
  String gridColumnCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 本'**
  String selectedBookCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **' · 共 {count} 本'**
  String groupBookCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 本书籍'**
  String importedBookCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **' 等 {count} 本'**
  String importFailureMore(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{detail}{more}'**
  String importBookFailed(String detail, String more);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'{file}：本地书持久化失败（{error}）'**
  String localBookSaveFailed(String file, String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'正在更新 {index}/{total}：{book}'**
  String updatingBook(int index, int total, String book);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'目录更新完成：成功 {count}/{total} 本'**
  String bookTocUpdateFinished(int count, int total);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'添加网址完成：成功 {success}，跳过 {skipped}，失败 {failed}'**
  String addBookUrlFinished(int success, int skipped, int failed);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'书单导入完成：成功 {success}，跳过 {skipped}，失败 {failed}'**
  String bookListImportFinished(int success, int skipped, int failed);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'读取书单文件失败: {error}'**
  String bookListReadFailed(String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'拉取书单失败: {error}'**
  String bookListFetchFailed(String error);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'批量下载 {count} 本（对标原版批量下载）'**
  String batchDownloadCount(int count);

  /// 主界面动态文案
  ///
  /// In zh, this message translates to:
  /// **'移动分组 {count} 本（对标原版 GroupSelectSheet）'**
  String moveBookGroupCount(int count);

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get localBooks;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get audioBooks;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get videoBooks;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'网络未分组'**
  String get ungroupedOnlineBooks;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'本地未分组'**
  String get ungroupedLocalBooks;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultBookGroup;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'收起侧栏'**
  String get collapseSidebar;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'展开侧栏'**
  String get expandSidebar;

  /// 书架内置分类及侧栏操作文案
  ///
  /// In zh, this message translates to:
  /// **'书架分组'**
  String get bookshelfGroups;

  /// 按分组位掩码显示的默认分组标签，不用于重命名用户分组
  ///
  /// In zh, this message translates to:
  /// **'分组 {number}'**
  String bookGroupNumber(int number);

  /// 发现与订阅浏览界面：刷新
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// 发现与订阅浏览界面：登录
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// 发现与订阅浏览界面：关闭
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// 发现与订阅浏览界面：清空
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// 发现与订阅浏览界面：清除
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearAction;

  /// 发现与订阅浏览界面：提示
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get notice;

  /// 发现与订阅浏览界面：收藏
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// 发现与订阅浏览界面：收藏
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favoriteAction;

  /// 发现与订阅浏览界面：取消收藏
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unfavoriteAction;

  /// 发现与订阅浏览界面：已收藏
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get favorited;

  /// 发现与订阅浏览界面：已取消收藏
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get unfavorited;

  /// 发现与订阅浏览界面：RSS 收藏
  ///
  /// In zh, this message translates to:
  /// **'RSS 收藏'**
  String get rssFavorites;

  /// 发现与订阅浏览界面：规则订阅
  ///
  /// In zh, this message translates to:
  /// **'规则订阅'**
  String get ruleSubscriptions;

  /// 发现与订阅浏览界面：筛选发现源
  ///
  /// In zh, this message translates to:
  /// **'筛选发现源'**
  String get filterDiscoverySources;

  /// 发现与订阅浏览界面：当前没有发现源！
  ///
  /// In zh, this message translates to:
  /// **'当前没有发现源！'**
  String get emptyDiscoverySources;

  /// 发现与订阅浏览界面：选择发现分类
  ///
  /// In zh, this message translates to:
  /// **'选择发现分类'**
  String get selectDiscoveryCategory;

  /// 发现与订阅浏览界面：展开左侧书源并点击分类，在此浏览书籍
  ///
  /// In zh, this message translates to:
  /// **'展开左侧书源并点击分类，在此浏览书籍'**
  String get selectDiscoveryCategoryHint;

  /// 发现与订阅浏览界面：已卸载
  ///
  /// In zh, this message translates to:
  /// **'已卸载'**
  String get sourceRemoved;

  /// 发现与订阅浏览界面：已置顶
  ///
  /// In zh, this message translates to:
  /// **'已置顶'**
  String get sourcePinned;

  /// 发现与订阅浏览界面：登录成功
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get loginSuccess;

  /// 发现与订阅浏览界面：无分类
  ///
  /// In zh, this message translates to:
  /// **'无分类'**
  String get noCategories;

  /// 发现与订阅浏览界面：没有已加载的书籍
  ///
  /// In zh, this message translates to:
  /// **'没有已加载的书籍'**
  String get noLoadedBooks;

  /// 发现与订阅浏览界面：参数错误
  ///
  /// In zh, this message translates to:
  /// **'参数错误'**
  String get invalidArguments;

  /// 发现与订阅浏览界面：缺少发现分类参数
  ///
  /// In zh, this message translates to:
  /// **'缺少发现分类参数'**
  String get missingDiscoveryCategory;

  /// 发现与订阅浏览界面：筛选
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// 发现与订阅浏览界面：切换为舒适
  ///
  /// In zh, this message translates to:
  /// **'切换为舒适'**
  String get switchComfortableLayout;

  /// 发现与订阅浏览界面：切换为紧凑
  ///
  /// In zh, this message translates to:
  /// **'切换为紧凑'**
  String get switchCompactLayout;

  /// 发现与订阅浏览界面：按关键字过滤已加载的书籍（匹配书名或作者，忽略英文字母大小写）
  ///
  /// In zh, this message translates to:
  /// **'按关键字过滤已加载的书籍（匹配书名或作者，忽略英文字母大小写）'**
  String get loadedBooksFilterHint;

  /// 发现与订阅浏览界面：关键字（留空=不过滤）
  ///
  /// In zh, this message translates to:
  /// **'关键字（留空=不过滤）'**
  String get filterKeywordHint;

  /// 发现与订阅浏览界面：书源需要登录
  ///
  /// In zh, this message translates to:
  /// **'书源需要登录'**
  String get sourceLoginRequired;

  /// 发现与订阅浏览界面：登录后即可浏览该分类内容
  ///
  /// In zh, this message translates to:
  /// **'登录后即可浏览该分类内容'**
  String get sourceLoginRequiredHint;

  /// 发现与订阅浏览界面：去登录
  ///
  /// In zh, this message translates to:
  /// **'去登录'**
  String get goToLogin;

  /// 发现与订阅浏览界面：暂无书籍
  ///
  /// In zh, this message translates to:
  /// **'暂无书籍'**
  String get emptyBooks;

  /// 发现与订阅浏览界面：该分类下没有找到书籍
  ///
  /// In zh, this message translates to:
  /// **'该分类下没有找到书籍'**
  String get emptyCategoryBooksHint;

  /// 发现与订阅浏览界面：筛选后无匹配书籍
  ///
  /// In zh, this message translates to:
  /// **'筛选后无匹配书籍'**
  String get noFilteredBooks;

  /// 发现与订阅浏览界面：上滑加载上一页
  ///
  /// In zh, this message translates to:
  /// **'上滑加载上一页'**
  String get loadPreviousPageHint;

  /// 发现与订阅浏览界面：加载失败，点击重试
  ///
  /// In zh, this message translates to:
  /// **'加载失败，点击重试'**
  String get tapToRetryLoad;

  /// 发现与订阅浏览界面：发现分类加载失败
  ///
  /// In zh, this message translates to:
  /// **'发现分类加载失败'**
  String get discoveryCategoriesLoadFailed;

  /// 发现与订阅浏览界面：选择页码
  ///
  /// In zh, this message translates to:
  /// **'选择页码'**
  String get selectPage;

  /// 发现与订阅浏览界面：收起搜索
  ///
  /// In zh, this message translates to:
  /// **'收起搜索'**
  String get collapseSearch;

  /// 发现与订阅浏览界面：展开搜索
  ///
  /// In zh, this message translates to:
  /// **'展开搜索'**
  String get expandSearch;

  /// 发现与订阅浏览界面：换源
  ///
  /// In zh, this message translates to:
  /// **'换源'**
  String get changeSource;

  /// 发现与订阅浏览界面：删除 RSS 源
  ///
  /// In zh, this message translates to:
  /// **'删除 RSS 源'**
  String get deleteRssSource;

  /// 发现与订阅浏览界面：加载 RSS 源...
  ///
  /// In zh, this message translates to:
  /// **'加载 RSS 源...'**
  String get loadingRssSources;

  /// 发现与订阅浏览界面：当前没有订阅源！
  ///
  /// In zh, this message translates to:
  /// **'当前没有订阅源！'**
  String get emptyRssSources;

  /// 发现与订阅浏览界面：当前分组暂无订阅源
  ///
  /// In zh, this message translates to:
  /// **'当前分组暂无订阅源'**
  String get emptyGroupRssSources;

  /// 发现与订阅浏览界面：暂无阅读记录
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读记录'**
  String get noReadingRecords;

  /// 发现与订阅浏览界面：（无标题）
  ///
  /// In zh, this message translates to:
  /// **'（无标题）'**
  String get untitled;

  /// 发现与订阅浏览界面：刷新排序
  ///
  /// In zh, this message translates to:
  /// **'刷新排序'**
  String get refreshSort;

  /// 发现与订阅浏览界面：设置源变量
  ///
  /// In zh, this message translates to:
  /// **'设置源变量'**
  String get setSourceVariable;

  /// 发现与订阅浏览界面：编辑源
  ///
  /// In zh, this message translates to:
  /// **'编辑源'**
  String get editSource;

  /// 发现与订阅浏览界面：切换布局
  ///
  /// In zh, this message translates to:
  /// **'切换布局'**
  String get switchLayout;

  /// 发现与订阅浏览界面：加载文章...
  ///
  /// In zh, this message translates to:
  /// **'加载文章...'**
  String get loadingArticles;

  /// 发现与订阅浏览界面：暂无文章
  ///
  /// In zh, this message translates to:
  /// **'暂无文章'**
  String get emptyArticles;

  /// 发现与订阅浏览界面：下拉刷新获取最新内容
  ///
  /// In zh, this message translates to:
  /// **'下拉刷新获取最新内容'**
  String get refreshArticlesHint;

  /// 发现与订阅浏览界面：已读
  ///
  /// In zh, this message translates to:
  /// **'已读'**
  String get readArticle;

  /// 发现与订阅浏览界面：源变量可在 JS 中通过 source.getVariable() 获取
  ///
  /// In zh, this message translates to:
  /// **'源变量可在 JS 中通过 source.getVariable() 获取'**
  String get sourceVariableHint;

  /// 发现与订阅浏览界面：源变量已保存
  ///
  /// In zh, this message translates to:
  /// **'源变量已保存'**
  String get sourceVariableSaved;

  /// 发现与订阅浏览界面：将清空本源本地缓存的文章列表，确定继续吗？
  ///
  /// In zh, this message translates to:
  /// **'将清空本源本地缓存的文章列表，确定继续吗？'**
  String get confirmClearArticles;

  /// 发现与订阅浏览界面：本源文章缓存已清空
  ///
  /// In zh, this message translates to:
  /// **'本源文章缓存已清空'**
  String get articleCacheCleared;

  /// 发现与订阅浏览界面：未知来源
  ///
  /// In zh, this message translates to:
  /// **'未知来源'**
  String get unknownSource;

  /// 发现与订阅浏览界面：加载收藏...
  ///
  /// In zh, this message translates to:
  /// **'加载收藏...'**
  String get loadingFavorites;

  /// 发现与订阅浏览界面：暂无收藏文章
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏文章'**
  String get emptyFavoriteArticles;

  /// 发现与订阅浏览界面：浏览 RSS 文章时点亮星标即可收藏
  ///
  /// In zh, this message translates to:
  /// **'浏览 RSS 文章时点亮星标即可收藏'**
  String get favoriteArticlesHint;

  /// 发现与订阅浏览界面：文章详情
  ///
  /// In zh, this message translates to:
  /// **'文章详情'**
  String get articleDetails;

  /// 发现与订阅浏览界面：切换为纯文本
  ///
  /// In zh, this message translates to:
  /// **'切换为纯文本'**
  String get switchToPlainText;

  /// 发现与订阅浏览界面：切换为 WebView
  ///
  /// In zh, this message translates to:
  /// **'切换为 WebView'**
  String get switchToWebView;

  /// 发现与订阅浏览界面：在浏览器中打开
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开'**
  String get openInBrowser;

  /// 发现与订阅浏览界面：分享
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// 发现与订阅浏览界面：在浏览器中查看原文
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中查看原文'**
  String get viewOriginalInBrowser;

  /// 发现与订阅浏览界面：WebView 加载失败
  ///
  /// In zh, this message translates to:
  /// **'WebView 加载失败'**
  String get webViewLoadFailed;

  /// 发现与订阅浏览界面：当前平台不支持 WebView，已降级为纯文本显示
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持 WebView，已降级为纯文本显示'**
  String get webViewUnavailableHint;

  /// 发现与订阅浏览界面：查看原文链接
  ///
  /// In zh, this message translates to:
  /// **'查看原文链接'**
  String get viewOriginalLink;

  /// 发现与订阅浏览提示：置顶失败: {error}
  ///
  /// In zh, this message translates to:
  /// **'置顶失败: {error}'**
  String sourcePinFailed(String error);

  /// 发现与订阅浏览提示：已加入书架 {count} 本
  ///
  /// In zh, this message translates to:
  /// **'已加入书架 {count} 本'**
  String addedToShelfCount(int count);

  /// 发现与订阅浏览提示：加入书架失败: {error}
  ///
  /// In zh, this message translates to:
  /// **'加入书架失败: {error}'**
  String addToShelfFailed(String error);

  /// 发现与订阅浏览提示：筛选（已开启：{keyword}）
  ///
  /// In zh, this message translates to:
  /// **'筛选（已开启：{keyword}）'**
  String activeKeywordFilter(String keyword);

  /// 发现与订阅浏览提示：已加载的书籍中没有匹配「{keyword}」
  ///
  /// In zh, this message translates to:
  /// **'已加载的书籍中没有匹配「{keyword}」'**
  String noLoadedBooksMatch(String keyword);

  /// 发现与订阅浏览提示：第 {page} 页
  ///
  /// In zh, this message translates to:
  /// **'第 {page} 页'**
  String pageNumber(int page);

  /// 发现与订阅浏览提示：确定要删除「{name}」吗？
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{name}」吗？'**
  String confirmDeleteNamedSource(String name);

  /// 发现与订阅浏览提示：无法打开链接：{url}
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接：{url}'**
  String cannotOpenLink(String url);

  /// 发现与订阅浏览提示：确定要删除？
  /// {count} 条阅读记录
  ///
  /// In zh, this message translates to:
  /// **'确定要删除？\n{count} 条阅读记录'**
  String confirmDeleteReadingRecordCount(int count);

  /// 发现与订阅浏览提示：保存源变量失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'保存源变量失败：{error}'**
  String sourceVariableSaveFailed(String error);

  /// 发现与订阅浏览提示：布局保存失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'布局保存失败：{error}'**
  String layoutSaveFailed(String error);

  /// 发现与订阅浏览提示：清空失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'清空失败：{error}'**
  String clearFailed(String error);

  /// 发现与订阅浏览提示：操作失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(String error);

  /// 发现与订阅浏览提示：收藏操作失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'收藏操作失败：{error}'**
  String favoriteOperationFailed(String error);

  /// 订阅源管理与共用分组界面：搜索订阅源
  ///
  /// In zh, this message translates to:
  /// **'搜索订阅源'**
  String get searchRssSources;

  /// 订阅源管理与共用分组界面：已启用
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get enabled;

  /// 订阅源管理与共用分组界面：已禁用
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get disabled;

  /// 订阅源管理与共用分组界面：需登录
  ///
  /// In zh, this message translates to:
  /// **'需登录'**
  String get loginRequired;

  /// 订阅源管理与共用分组界面：未分组
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get ungrouped;

  /// 订阅源管理与共用分组界面：新增订阅源
  ///
  /// In zh, this message translates to:
  /// **'新增订阅源'**
  String get addRssSource;

  /// 订阅源管理与共用分组界面：本地导入
  ///
  /// In zh, this message translates to:
  /// **'本地导入'**
  String get importLocal;

  /// 订阅源管理与共用分组界面：网络导入
  ///
  /// In zh, this message translates to:
  /// **'网络导入'**
  String get importOnline;

  /// 订阅源管理与共用分组界面：二维码导入
  ///
  /// In zh, this message translates to:
  /// **'二维码导入'**
  String get importQrCode;

  /// 订阅源管理与共用分组界面：导入默认规则
  ///
  /// In zh, this message translates to:
  /// **'导入默认规则'**
  String get importDefaultRules;

  /// 订阅源管理与共用分组界面：启用选中
  ///
  /// In zh, this message translates to:
  /// **'启用选中'**
  String get enableSelected;

  /// 订阅源管理与共用分组界面：禁用选中
  ///
  /// In zh, this message translates to:
  /// **'禁用选中'**
  String get disableSelected;

  /// 订阅源管理与共用分组界面：添加到分组
  ///
  /// In zh, this message translates to:
  /// **'添加到分组'**
  String get addToGroup;

  /// 订阅源管理与共用分组界面：移除分组
  ///
  /// In zh, this message translates to:
  /// **'移除分组'**
  String get removeGroup;

  /// 订阅源管理与共用分组界面：选中置顶
  ///
  /// In zh, this message translates to:
  /// **'选中置顶'**
  String get pinSelected;

  /// 订阅源管理与共用分组界面：选中置底
  ///
  /// In zh, this message translates to:
  /// **'选中置底'**
  String get bottomSelected;

  /// 订阅源管理与共用分组界面：导出选中
  ///
  /// In zh, this message translates to:
  /// **'导出选中'**
  String get exportSelected;

  /// 订阅源管理与共用分组界面：分享源
  ///
  /// In zh, this message translates to:
  /// **'分享源'**
  String get shareSources;

  /// 订阅源管理与共用分组界面：选择区间
  ///
  /// In zh, this message translates to:
  /// **'选择区间'**
  String get selectRange;

  /// 订阅源管理与共用分组界面：没有匹配的订阅源
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的订阅源'**
  String get noMatchingRssSources;

  /// 订阅源管理与共用分组界面：点击右上角菜单「新增订阅源」或导入订阅源
  ///
  /// In zh, this message translates to:
  /// **'点击右上角菜单「新增订阅源」或导入订阅源'**
  String get addRssSourceHint;

  /// 订阅源管理与共用分组界面：置底
  ///
  /// In zh, this message translates to:
  /// **'置底'**
  String get moveToBottom;

  /// 订阅源管理与共用分组界面：删除订阅源
  ///
  /// In zh, this message translates to:
  /// **'删除订阅源'**
  String get deleteRssSources;

  /// 订阅源管理与共用分组界面：请先选择订阅源
  ///
  /// In zh, this message translates to:
  /// **'请先选择订阅源'**
  String get selectRssSourcesFirst;

  /// 订阅源管理与共用分组界面：已启用所选订阅源
  ///
  /// In zh, this message translates to:
  /// **'已启用所选订阅源'**
  String get selectedRssSourcesEnabled;

  /// 订阅源管理与共用分组界面：已禁用所选订阅源
  ///
  /// In zh, this message translates to:
  /// **'已禁用所选订阅源'**
  String get selectedRssSourcesDisabled;

  /// 订阅源管理与共用分组界面：已删除所选订阅源
  ///
  /// In zh, this message translates to:
  /// **'已删除所选订阅源'**
  String get selectedRssSourcesDeleted;

  /// 订阅源管理与共用分组界面：已置顶所选订阅源
  ///
  /// In zh, this message translates to:
  /// **'已置顶所选订阅源'**
  String get selectedRssSourcesPinned;

  /// 订阅源管理与共用分组界面：已置底所选订阅源
  ///
  /// In zh, this message translates to:
  /// **'已置底所选订阅源'**
  String get selectedRssSourcesBottom;

  /// 订阅源管理与共用分组界面：输入分组名称
  ///
  /// In zh, this message translates to:
  /// **'输入分组名称'**
  String get groupNameHint;

  /// 订阅源管理与共用分组界面：所选订阅源没有可移除的分组
  ///
  /// In zh, this message translates to:
  /// **'所选订阅源没有可移除的分组'**
  String get noRemovableSourceGroups;

  /// 订阅源管理与共用分组界面：请先选择两个以上的订阅源
  ///
  /// In zh, this message translates to:
  /// **'请先选择两个以上的订阅源'**
  String get selectTwoRssSourcesFirst;

  /// 订阅源管理与共用分组界面：格式错误，未解析到订阅源
  ///
  /// In zh, this message translates to:
  /// **'格式错误，未解析到订阅源'**
  String get invalidRssSources;

  /// 订阅源管理与共用分组界面：导入完成
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get importFinished;

  /// 订阅源管理与共用分组界面：无法获取文件路径
  ///
  /// In zh, this message translates to:
  /// **'无法获取文件路径'**
  String get filePathUnavailable;

  /// 订阅源管理与共用分组界面：扫码内容不是可识别的订阅源数据
  ///
  /// In zh, this message translates to:
  /// **'扫码内容不是可识别的订阅源数据'**
  String get invalidRssQrCode;

  /// 订阅源管理与共用分组界面：默认订阅源已同步
  ///
  /// In zh, this message translates to:
  /// **'默认订阅源已同步'**
  String get defaultRssSourcesSynced;

  /// 订阅源管理与共用分组界面：从 URL 导入订阅源
  ///
  /// In zh, this message translates to:
  /// **'从 URL 导入订阅源'**
  String get importRssSourcesFromUrl;

  /// 订阅源管理与共用分组界面：输入订阅源 URL 地址
  ///
  /// In zh, this message translates to:
  /// **'输入订阅源 URL 地址'**
  String get rssSourceUrlHint;

  /// 订阅源管理与共用分组界面：历史记录
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get history;

  /// 订阅源管理与共用分组界面：导入订阅源
  ///
  /// In zh, this message translates to:
  /// **'导入订阅源'**
  String get importRssSources;

  /// 订阅源管理与共用分组界面：自定义源分组
  ///
  /// In zh, this message translates to:
  /// **'自定义源分组'**
  String get customSourceGroup;

  /// 订阅源管理与共用分组界面：保留原名
  ///
  /// In zh, this message translates to:
  /// **'保留原名'**
  String get keepSourceName;

  /// 订阅源管理与共用分组界面：保留分组
  ///
  /// In zh, this message translates to:
  /// **'保留分组'**
  String get keepSourceGroup;

  /// 订阅源管理与共用分组界面：保留启用状态
  ///
  /// In zh, this message translates to:
  /// **'保留启用状态'**
  String get keepSourceEnabled;

  /// 订阅源管理与共用分组界面：显示源注释
  ///
  /// In zh, this message translates to:
  /// **'显示源注释'**
  String get showSourceComment;

  /// 订阅源管理与共用分组界面：已复制到剪贴板
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// 订阅源管理与共用分组界面：复制
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// 订阅源管理与共用分组界面：新增
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get importStatusNew;

  /// 订阅源管理与共用分组界面：更新
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get importStatusUpdated;

  /// 订阅源管理与共用分组界面：已有
  ///
  /// In zh, this message translates to:
  /// **'已有'**
  String get importStatusExisting;

  /// 订阅源管理与共用分组界面：打开
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// 订阅源管理与共用分组界面：添加分组
  ///
  /// In zh, this message translates to:
  /// **'添加分组'**
  String get addGroup;

  /// 订阅源管理与共用分组界面：分组名称
  ///
  /// In zh, this message translates to:
  /// **'分组名称'**
  String get groupName;

  /// 订阅源管理与共用分组界面：重命名分组
  ///
  /// In zh, this message translates to:
  /// **'重命名分组'**
  String get renameGroup;

  /// 订阅源管理与共用分组界面：输入新分组名称
  ///
  /// In zh, this message translates to:
  /// **'输入新分组名称'**
  String get newGroupNameHint;

  /// 订阅源管理与共用分组界面：删除分组
  ///
  /// In zh, this message translates to:
  /// **'删除分组'**
  String get deleteGroup;

  /// 订阅源管理与共用分组界面：暂无分组
  ///
  /// In zh, this message translates to:
  /// **'暂无分组'**
  String get emptyGroups;

  /// 订阅源管理与共用分组界面：重命名
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// 订阅源管理与共用分组界面：输入自定义源分组名称
  ///
  /// In zh, this message translates to:
  /// **'输入自定义源分组名称'**
  String get customSourceGroupName;

  /// 订阅源管理与共用分组界面：关闭替换分组 / 开启添加分组
  ///
  /// In zh, this message translates to:
  /// **'关闭替换分组 / 开启添加分组'**
  String get addGroupModeHint;

  /// 订阅源管理与共用分组界面：订阅源
  ///
  /// In zh, this message translates to:
  /// **'订阅源'**
  String get rssSourceNoun;

  /// 订阅源管理与共用分组界面：书源
  ///
  /// In zh, this message translates to:
  /// **'书源'**
  String get bookSourceNoun;

  /// 订阅源管理与共用分组界面：规则
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get ruleNoun;

  /// 订阅源管理与分组操作提示：切换启用状态失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'切换启用状态失败：{error}'**
  String sourceEnabledToggleFailed(String error);

  /// 订阅源管理与分组操作提示：删除失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(String error);

  /// 订阅源管理与分组操作提示：保存排序失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'保存排序失败：{error}'**
  String sortSaveFailed(String error);

  /// 订阅源管理与分组操作提示：确定要删除选中的 {count} 个订阅源吗？
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个订阅源吗？'**
  String confirmDeleteRssSourceCount(int count);

  /// 订阅源管理与分组操作提示：已为所选订阅源添加分组「{name}」
  ///
  /// In zh, this message translates to:
  /// **'已为所选订阅源添加分组「{name}」'**
  String addedSourceGroup(String name);

  /// 订阅源管理与分组操作提示：添加分组失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'添加分组失败：{error}'**
  String addGroupFailed(String error);

  /// 订阅源管理与分组操作提示：已从所选订阅源移除分组「{name}」
  ///
  /// In zh, this message translates to:
  /// **'已从所选订阅源移除分组「{name}」'**
  String removedSourceGroup(String name);

  /// 订阅源管理与分组操作提示：移除分组失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'移除分组失败：{error}'**
  String removeGroupFailed(String error);

  /// 订阅源管理与分组操作提示：已导出 {count} 个订阅源到剪贴板
  ///
  /// In zh, this message translates to:
  /// **'已导出 {count} 个订阅源到剪贴板'**
  String exportedRssSourcesToClipboard(int count);

  /// 订阅源管理与分组操作提示：导出失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// 订阅源管理与分组操作提示：订阅源分享（{count} 个）
  ///
  /// In zh, this message translates to:
  /// **'订阅源分享（{count} 个）'**
  String shareRssSourceCount(int count);

  /// 订阅源管理与分组操作提示：分享失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'分享失败：{error}'**
  String shareFailed(String error);

  /// 订阅源管理与分组操作提示：从文件导入失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'从文件导入失败：{error}'**
  String importFromFileFailed(String error);

  /// 订阅源管理与分组操作提示：获取订阅源失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'获取订阅源失败：{error}'**
  String fetchRssSourcesFailed(String error);

  /// 订阅源管理与分组操作提示：已导入 {count} 条默认订阅源
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 条默认订阅源'**
  String importedDefaultRssSourceCount(int count);

  /// 订阅源管理与分组操作提示：导入默认规则失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'导入默认规则失败：{error}'**
  String importDefaultRulesFailed(String error);

  /// 订阅源管理与分组操作提示：导入失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String rssSourceImportFailed(String error);

  /// 订阅源管理与分组操作提示：全选（{selected}/{total}）
  ///
  /// In zh, this message translates to:
  /// **'全选（{selected}/{total}）'**
  String selectAllCount(int selected, int total);

  /// 订阅源管理与分组操作提示：取消全选（{selected}/{total}）
  ///
  /// In zh, this message translates to:
  /// **'取消全选（{selected}/{total}）'**
  String deselectAllCount(int selected, int total);

  /// 订阅源管理与分组操作提示：分组「{name}」已存在
  ///
  /// In zh, this message translates to:
  /// **'分组「{name}」已存在'**
  String groupAlreadyExists(String name);

  /// 订阅源管理与分组操作提示：没有未分组的{noun}可归入该分组
  ///
  /// In zh, this message translates to:
  /// **'没有未分组的{noun}可归入该分组'**
  String noUngroupedItems(String noun);

  /// 订阅源管理与分组操作提示：确定要删除分组「{name}」吗？分组内{noun}将移出该分组。
  ///
  /// In zh, this message translates to:
  /// **'确定要删除分组「{name}」吗？分组内{noun}将移出该分组。'**
  String confirmDeleteItemGroup(String name, String noun);

  /// No description provided for @searchScope.
  ///
  /// In zh, this message translates to:
  /// **'搜索范围'**
  String get searchScope;

  /// No description provided for @stopSearch.
  ///
  /// In zh, this message translates to:
  /// **'停止搜索'**
  String get stopSearch;

  /// No description provided for @loadNextPage.
  ///
  /// In zh, this message translates to:
  /// **'加载下一页'**
  String get loadNextPage;

  /// No description provided for @preciseSearch.
  ///
  /// In zh, this message translates to:
  /// **'精准搜索'**
  String get preciseSearch;

  /// No description provided for @markReadBooks.
  ///
  /// In zh, this message translates to:
  /// **'标识读过的书籍'**
  String get markReadBooks;

  /// No description provided for @appLog.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get appLog;

  /// No description provided for @searchResultFilter.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果过滤'**
  String get searchResultFilter;

  /// No description provided for @searchResultFilterActive.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果过滤（已开启）'**
  String get searchResultFilterActive;

  /// No description provided for @copySourceFailures.
  ///
  /// In zh, this message translates to:
  /// **'复制全部失败详情'**
  String get copySourceFailures;

  /// No description provided for @searchBookOrAuthor.
  ///
  /// In zh, this message translates to:
  /// **'搜索书名、作者'**
  String get searchBookOrAuthor;

  /// No description provided for @noMatchingSearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'无匹配的历史关键词'**
  String get noMatchingSearchHistory;

  /// No description provided for @clearSearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空搜索历史'**
  String get clearSearchHistory;

  /// No description provided for @confirmClearSearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有搜索历史吗？'**
  String get confirmClearSearchHistory;

  /// No description provided for @emptySearchResults.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果为空'**
  String get emptySearchResults;

  /// No description provided for @disablePreciseSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭精准搜索'**
  String get disablePreciseSearch;

  /// No description provided for @switchAllSearchGroups.
  ///
  /// In zh, this message translates to:
  /// **'切换全部分组'**
  String get switchAllSearchGroups;

  /// No description provided for @specifiedBookSources.
  ///
  /// In zh, this message translates to:
  /// **'指定书源'**
  String get specifiedBookSources;

  /// No description provided for @currentBookSource.
  ///
  /// In zh, this message translates to:
  /// **'当前书源'**
  String get currentBookSource;

  /// No description provided for @allBookSources.
  ///
  /// In zh, this message translates to:
  /// **'全部书源'**
  String get allBookSources;

  /// No description provided for @searchBookSources.
  ///
  /// In zh, this message translates to:
  /// **'搜索书源'**
  String get searchBookSources;

  /// No description provided for @noMatchingBookSources.
  ///
  /// In zh, this message translates to:
  /// **'无匹配书源'**
  String get noMatchingBookSources;

  /// No description provided for @noGroupedBookSources.
  ///
  /// In zh, this message translates to:
  /// **'无分组书源'**
  String get noGroupedBookSources;

  /// No description provided for @searchBlockedWords.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果屏蔽词'**
  String get searchBlockedWords;

  /// No description provided for @searchBlockedWordsHelp.
  ///
  /// In zh, this message translates to:
  /// **'每行一个普通文本，匹配书名、作者或分类标签，忽略英文字母大小写'**
  String get searchBlockedWordsHelp;

  /// No description provided for @searchBlockedWordsHint.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽词（每行一个）'**
  String get searchBlockedWordsHint;

  /// No description provided for @searchContent.
  ///
  /// In zh, this message translates to:
  /// **'搜索内容'**
  String get searchContent;

  /// No description provided for @searchOptions.
  ///
  /// In zh, this message translates to:
  /// **'搜索选项'**
  String get searchOptions;

  /// No description provided for @searchUseReplacement.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get searchUseReplacement;

  /// No description provided for @searchUseRegex.
  ///
  /// In zh, this message translates to:
  /// **'正则'**
  String get searchUseRegex;

  /// No description provided for @searchCurrentChapter.
  ///
  /// In zh, this message translates to:
  /// **'仅当前章'**
  String get searchCurrentChapter;

  /// No description provided for @searchCachedChapters.
  ///
  /// In zh, this message translates to:
  /// **'仅本书（已缓存）'**
  String get searchCachedChapters;

  /// No description provided for @searchNetworkChapters.
  ///
  /// In zh, this message translates to:
  /// **'本书 + 网络'**
  String get searchNetworkChapters;

  /// No description provided for @searchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索...'**
  String get searchPlaceholder;

  /// No description provided for @searchResultsTruncated.
  ///
  /// In zh, this message translates to:
  /// **'（已截断）'**
  String get searchResultsTruncated;

  /// No description provided for @searchContentHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词开始搜索正文'**
  String get searchContentHint;

  /// No description provided for @searchThisBookOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本书'**
  String get searchThisBookOnly;

  /// No description provided for @displayListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get displayListSeparator;

  /// No description provided for @searchProgressSummary.
  ///
  /// In zh, this message translates to:
  /// **'结果 {count} · 进度 {searched}/{total}'**
  String searchProgressSummary(int count, int searched, int total);

  /// No description provided for @searchLoginRequiredCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个书源需要登录，请先在书源菜单中登录后重试'**
  String searchLoginRequiredCount(int count);

  /// No description provided for @bookSourceSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'书源搜索失败：{error}'**
  String bookSourceSearchFailed(String error);

  /// No description provided for @bookSourceSearchFailureCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个书源搜索失败，点击展开'**
  String bookSourceSearchFailureCount(int count);

  /// No description provided for @copiedSourceFailureCount.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {count} 条书源失败详情'**
  String copiedSourceFailureCount(int count);

  /// No description provided for @searchGroupCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分组'**
  String searchGroupCount(int count);

  /// No description provided for @searchSourceCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 书源'**
  String searchSourceCount(int count);

  /// No description provided for @latestChapterLabel.
  ///
  /// In zh, this message translates to:
  /// **'最新：{chapter}'**
  String latestChapterLabel(String chapter);

  /// No description provided for @bookSourcesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'书源加载失败: {error}'**
  String bookSourcesLoadFailed(String error);

  /// No description provided for @deletedSearchKeyword.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{keyword}」'**
  String deletedSearchKeyword(String keyword);

  /// No description provided for @emptySearchDisablePrecision.
  ///
  /// In zh, this message translates to:
  /// **'{scope}分组搜索结果为空，是否关闭精准搜索？'**
  String emptySearchDisablePrecision(String scope);

  /// No description provided for @emptySearchSwitchAllGroups.
  ///
  /// In zh, this message translates to:
  /// **'{scope}分组搜索结果为空，是否切换到全部分组？'**
  String emptySearchSwitchAllGroups(String scope);

  /// No description provided for @scanningSearchChapters.
  ///
  /// In zh, this message translates to:
  /// **'扫描章节 {scanned} / {total} ...'**
  String scanningSearchChapters(int scanned, int total);

  /// No description provided for @noContentMatches.
  ///
  /// In zh, this message translates to:
  /// **'未找到「{keyword}」相关内容'**
  String noContentMatches(String keyword);

  /// No description provided for @contentMatchCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 处匹配'**
  String contentMatchCount(int count);

  /// No description provided for @editorSourceUrl.
  ///
  /// In zh, this message translates to:
  /// **'源 URL'**
  String get editorSourceUrl;

  /// No description provided for @editorSourceName.
  ///
  /// In zh, this message translates to:
  /// **'源名称'**
  String get editorSourceName;

  /// No description provided for @editorSourceGroup.
  ///
  /// In zh, this message translates to:
  /// **'源分组'**
  String get editorSourceGroup;

  /// No description provided for @editorSourceComment.
  ///
  /// In zh, this message translates to:
  /// **'源注释'**
  String get editorSourceComment;

  /// No description provided for @editorLoginUrl.
  ///
  /// In zh, this message translates to:
  /// **'登录 URL'**
  String get editorLoginUrl;

  /// No description provided for @editorLoginUi.
  ///
  /// In zh, this message translates to:
  /// **'登录界面'**
  String get editorLoginUi;

  /// No description provided for @editorLoginCheckJs.
  ///
  /// In zh, this message translates to:
  /// **'登录检查 JS'**
  String get editorLoginCheckJs;

  /// No description provided for @editorCoverDecode.
  ///
  /// In zh, this message translates to:
  /// **'封面解密'**
  String get editorCoverDecode;

  /// No description provided for @editorBookUrlPattern.
  ///
  /// In zh, this message translates to:
  /// **'书籍 URL 正则'**
  String get editorBookUrlPattern;

  /// No description provided for @editorHeader.
  ///
  /// In zh, this message translates to:
  /// **'请求头'**
  String get editorHeader;

  /// No description provided for @editorVariableComment.
  ///
  /// In zh, this message translates to:
  /// **'变量说明'**
  String get editorVariableComment;

  /// No description provided for @editorConcurrentRate.
  ///
  /// In zh, this message translates to:
  /// **'并发率'**
  String get editorConcurrentRate;

  /// No description provided for @editorSearchUrl.
  ///
  /// In zh, this message translates to:
  /// **'搜索地址'**
  String get editorSearchUrl;

  /// No description provided for @editorCheckKeyword.
  ///
  /// In zh, this message translates to:
  /// **'校验关键字'**
  String get editorCheckKeyword;

  /// No description provided for @editorBookList.
  ///
  /// In zh, this message translates to:
  /// **'书籍列表规则'**
  String get editorBookList;

  /// No description provided for @editorBookName.
  ///
  /// In zh, this message translates to:
  /// **'书名规则'**
  String get editorBookName;

  /// No description provided for @editorAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者规则'**
  String get editorAuthor;

  /// No description provided for @editorKind.
  ///
  /// In zh, this message translates to:
  /// **'分类规则'**
  String get editorKind;

  /// No description provided for @editorWordCount.
  ///
  /// In zh, this message translates to:
  /// **'字数规则'**
  String get editorWordCount;

  /// No description provided for @editorLastChapter.
  ///
  /// In zh, this message translates to:
  /// **'最新章节规则'**
  String get editorLastChapter;

  /// No description provided for @editorIntro.
  ///
  /// In zh, this message translates to:
  /// **'简介规则'**
  String get editorIntro;

  /// No description provided for @editorCoverUrl.
  ///
  /// In zh, this message translates to:
  /// **'封面规则'**
  String get editorCoverUrl;

  /// No description provided for @editorBookUrl.
  ///
  /// In zh, this message translates to:
  /// **'详情页 URL 规则'**
  String get editorBookUrl;

  /// No description provided for @editorExploreUrl.
  ///
  /// In zh, this message translates to:
  /// **'发现地址规则'**
  String get editorExploreUrl;

  /// No description provided for @editorInfoInit.
  ///
  /// In zh, this message translates to:
  /// **'预处理规则'**
  String get editorInfoInit;

  /// No description provided for @editorTocUrl.
  ///
  /// In zh, this message translates to:
  /// **'目录 URL 规则'**
  String get editorTocUrl;

  /// No description provided for @editorCanRename.
  ///
  /// In zh, this message translates to:
  /// **'允许修改书名作者'**
  String get editorCanRename;

  /// No description provided for @editorDownloadUrls.
  ///
  /// In zh, this message translates to:
  /// **'下载URL规则'**
  String get editorDownloadUrls;

  /// No description provided for @editorPreUpdateJs.
  ///
  /// In zh, this message translates to:
  /// **'更新之前 JS'**
  String get editorPreUpdateJs;

  /// No description provided for @editorChapterList.
  ///
  /// In zh, this message translates to:
  /// **'目录列表规则'**
  String get editorChapterList;

  /// No description provided for @editorChapterName.
  ///
  /// In zh, this message translates to:
  /// **'章节名称规则'**
  String get editorChapterName;

  /// No description provided for @editorChapterUrl.
  ///
  /// In zh, this message translates to:
  /// **'章节 URL 规则'**
  String get editorChapterUrl;

  /// No description provided for @editorFormatJs.
  ///
  /// In zh, this message translates to:
  /// **'格式化规则'**
  String get editorFormatJs;

  /// No description provided for @editorIsVolume.
  ///
  /// In zh, this message translates to:
  /// **'Volume 标识'**
  String get editorIsVolume;

  /// No description provided for @editorChapterInfo.
  ///
  /// In zh, this message translates to:
  /// **'章节信息'**
  String get editorChapterInfo;

  /// No description provided for @editorIsVip.
  ///
  /// In zh, this message translates to:
  /// **'VIP 标识'**
  String get editorIsVip;

  /// No description provided for @editorIsPay.
  ///
  /// In zh, this message translates to:
  /// **'购买标识'**
  String get editorIsPay;

  /// No description provided for @editorNextTocUrl.
  ///
  /// In zh, this message translates to:
  /// **'目录下一页规则'**
  String get editorNextTocUrl;

  /// No description provided for @editorContent.
  ///
  /// In zh, this message translates to:
  /// **'正文规则'**
  String get editorContent;

  /// No description provided for @editorNextContentUrl.
  ///
  /// In zh, this message translates to:
  /// **'正文下一页 URL 规则'**
  String get editorNextContentUrl;

  /// No description provided for @editorSubContent.
  ///
  /// In zh, this message translates to:
  /// **'副文规则'**
  String get editorSubContent;

  /// No description provided for @editorReplaceRegex.
  ///
  /// In zh, this message translates to:
  /// **'替换规则'**
  String get editorReplaceRegex;

  /// No description provided for @editorTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get editorTitle;

  /// No description provided for @editorSourceRegex.
  ///
  /// In zh, this message translates to:
  /// **'资源正则'**
  String get editorSourceRegex;

  /// No description provided for @editorImageStyle.
  ///
  /// In zh, this message translates to:
  /// **'图片样式'**
  String get editorImageStyle;

  /// No description provided for @editorImageDecode.
  ///
  /// In zh, this message translates to:
  /// **'图片解密'**
  String get editorImageDecode;

  /// No description provided for @editorWebJs.
  ///
  /// In zh, this message translates to:
  /// **'WebView JS'**
  String get editorWebJs;

  /// No description provided for @editorPayAction.
  ///
  /// In zh, this message translates to:
  /// **'购买操作'**
  String get editorPayAction;

  /// No description provided for @editorCallbackJs.
  ///
  /// In zh, this message translates to:
  /// **'回调操作'**
  String get editorCallbackJs;

  /// No description provided for @editorReviewSummaryUrl.
  ///
  /// In zh, this message translates to:
  /// **'段评统计 URL'**
  String get editorReviewSummaryUrl;

  /// No description provided for @editorSummaryList.
  ///
  /// In zh, this message translates to:
  /// **'段评统计列表'**
  String get editorSummaryList;

  /// No description provided for @editorParagraphIndex.
  ///
  /// In zh, this message translates to:
  /// **'段落索引'**
  String get editorParagraphIndex;

  /// No description provided for @editorSummaryCount.
  ///
  /// In zh, this message translates to:
  /// **'段评数量'**
  String get editorSummaryCount;

  /// No description provided for @editorParagraphData.
  ///
  /// In zh, this message translates to:
  /// **'段落数据'**
  String get editorParagraphData;

  /// No description provided for @editorReviewDetailUrl.
  ///
  /// In zh, this message translates to:
  /// **'段评详情 URL'**
  String get editorReviewDetailUrl;

  /// No description provided for @editorReviewNextPage.
  ///
  /// In zh, this message translates to:
  /// **'段评下一页 URL'**
  String get editorReviewNextPage;

  /// No description provided for @editorDetailList.
  ///
  /// In zh, this message translates to:
  /// **'段评详情列表'**
  String get editorDetailList;

  /// No description provided for @editorCommentId.
  ///
  /// In zh, this message translates to:
  /// **'段评 ID'**
  String get editorCommentId;

  /// No description provided for @editorAvatar.
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get editorAvatar;

  /// No description provided for @editorNickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get editorNickname;

  /// No description provided for @editorBadge.
  ///
  /// In zh, this message translates to:
  /// **'徽章'**
  String get editorBadge;

  /// No description provided for @editorCommentContent.
  ///
  /// In zh, this message translates to:
  /// **'评论内容协议'**
  String get editorCommentContent;

  /// No description provided for @editorReviewQuoteUrl.
  ///
  /// In zh, this message translates to:
  /// **'段评回复URL'**
  String get editorReviewQuoteUrl;

  /// No description provided for @editorReplyList.
  ///
  /// In zh, this message translates to:
  /// **'子评论列表'**
  String get editorReplyList;

  /// No description provided for @editorReplyId.
  ///
  /// In zh, this message translates to:
  /// **'子评论 ID'**
  String get editorReplyId;

  /// No description provided for @editorReplyAvatar.
  ///
  /// In zh, this message translates to:
  /// **'子评论头像'**
  String get editorReplyAvatar;

  /// No description provided for @editorReplyName.
  ///
  /// In zh, this message translates to:
  /// **'子评论昵称'**
  String get editorReplyName;

  /// No description provided for @editorReplyBadge.
  ///
  /// In zh, this message translates to:
  /// **'子评论徽章'**
  String get editorReplyBadge;

  /// No description provided for @editorReplyContent.
  ///
  /// In zh, this message translates to:
  /// **'子评论内容协议'**
  String get editorReplyContent;

  /// No description provided for @editorIcon.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get editorIcon;

  /// No description provided for @editorIconUrl.
  ///
  /// In zh, this message translates to:
  /// **'图标 URL'**
  String get editorIconUrl;

  /// No description provided for @editorSortUrl.
  ///
  /// In zh, this message translates to:
  /// **'分类 URL'**
  String get editorSortUrl;

  /// No description provided for @editorLoginDetectionJs.
  ///
  /// In zh, this message translates to:
  /// **'登录检测 JS'**
  String get editorLoginDetectionJs;

  /// No description provided for @editorCoverDecodeJs.
  ///
  /// In zh, this message translates to:
  /// **'封面解码 JS'**
  String get editorCoverDecodeJs;

  /// No description provided for @editorRssVariableComment.
  ///
  /// In zh, this message translates to:
  /// **'源变量注释'**
  String get editorRssVariableComment;

  /// No description provided for @editorJsLibrary.
  ///
  /// In zh, this message translates to:
  /// **'JS 库'**
  String get editorJsLibrary;

  /// No description provided for @editorStartHtml.
  ///
  /// In zh, this message translates to:
  /// **'初始 HTML'**
  String get editorStartHtml;

  /// No description provided for @editorStartStyle.
  ///
  /// In zh, this message translates to:
  /// **'初始样式'**
  String get editorStartStyle;

  /// No description provided for @editorStartJs.
  ///
  /// In zh, this message translates to:
  /// **'初始 JS'**
  String get editorStartJs;

  /// No description provided for @editorPreloadJs.
  ///
  /// In zh, this message translates to:
  /// **'预加载 JS'**
  String get editorPreloadJs;

  /// No description provided for @editorArticleList.
  ///
  /// In zh, this message translates to:
  /// **'文章列表规则'**
  String get editorArticleList;

  /// No description provided for @editorNextPage.
  ///
  /// In zh, this message translates to:
  /// **'下一页规则'**
  String get editorNextPage;

  /// No description provided for @editorTitleRule.
  ///
  /// In zh, this message translates to:
  /// **'标题规则'**
  String get editorTitleRule;

  /// No description provided for @editorDateRule.
  ///
  /// In zh, this message translates to:
  /// **'日期规则'**
  String get editorDateRule;

  /// No description provided for @editorDescriptionRule.
  ///
  /// In zh, this message translates to:
  /// **'描述规则'**
  String get editorDescriptionRule;

  /// No description provided for @editorImageRule.
  ///
  /// In zh, this message translates to:
  /// **'图片规则'**
  String get editorImageRule;

  /// No description provided for @editorLinkRule.
  ///
  /// In zh, this message translates to:
  /// **'链接规则'**
  String get editorLinkRule;

  /// No description provided for @editorContentRule.
  ///
  /// In zh, this message translates to:
  /// **'内容规则'**
  String get editorContentRule;

  /// No description provided for @editorStyle.
  ///
  /// In zh, this message translates to:
  /// **'样式'**
  String get editorStyle;

  /// No description provided for @editorInjectJs.
  ///
  /// In zh, this message translates to:
  /// **'注入 JS'**
  String get editorInjectJs;

  /// No description provided for @editorContentWhitelist.
  ///
  /// In zh, this message translates to:
  /// **'内容白名单'**
  String get editorContentWhitelist;

  /// No description provided for @editorContentBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'内容黑名单'**
  String get editorContentBlacklist;

  /// No description provided for @editorOverrideUrl.
  ///
  /// In zh, this message translates to:
  /// **'URL 拦截'**
  String get editorOverrideUrl;

  /// No description provided for @editorType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get editorType;

  /// No description provided for @editorText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get editorText;

  /// No description provided for @editorAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get editorAudio;

  /// No description provided for @editorImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get editorImage;

  /// No description provided for @editorFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get editorFile;

  /// No description provided for @editorVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get editorVideo;

  /// No description provided for @editorWeb.
  ///
  /// In zh, this message translates to:
  /// **'网页'**
  String get editorWeb;

  /// No description provided for @editorList.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get editorList;

  /// No description provided for @editorSingleColumn.
  ///
  /// In zh, this message translates to:
  /// **'单列'**
  String get editorSingleColumn;

  /// No description provided for @editorTwoColumns.
  ///
  /// In zh, this message translates to:
  /// **'双列'**
  String get editorTwoColumns;

  /// No description provided for @editorWaterfall.
  ///
  /// In zh, this message translates to:
  /// **'瀑布'**
  String get editorWaterfall;

  /// No description provided for @editorThreeColumns.
  ///
  /// In zh, this message translates to:
  /// **'三列'**
  String get editorThreeColumns;

  /// No description provided for @editorBasic.
  ///
  /// In zh, this message translates to:
  /// **'基本'**
  String get editorBasic;

  /// No description provided for @editorDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get editorDetails;

  /// No description provided for @editorChapters.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get editorChapters;

  /// No description provided for @editorBookContent.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get editorBookContent;

  /// No description provided for @editorPreprocess.
  ///
  /// In zh, this message translates to:
  /// **'预处理'**
  String get editorPreprocess;

  /// No description provided for @editorListRules.
  ///
  /// In zh, this message translates to:
  /// **'列表规则'**
  String get editorListRules;

  /// No description provided for @editorReviewRules.
  ///
  /// In zh, this message translates to:
  /// **'段评规则'**
  String get editorReviewRules;

  /// No description provided for @editorEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get editorEnable;

  /// No description provided for @editorReviews.
  ///
  /// In zh, this message translates to:
  /// **'段评'**
  String get editorReviews;

  /// No description provided for @editorEventListener.
  ///
  /// In zh, this message translates to:
  /// **'事件监听'**
  String get editorEventListener;

  /// No description provided for @editorCustomButton.
  ///
  /// In zh, this message translates to:
  /// **'定制按钮'**
  String get editorCustomButton;

  /// No description provided for @editorOptions.
  ///
  /// In zh, this message translates to:
  /// **'选项'**
  String get editorOptions;

  /// No description provided for @editorSingleUrl.
  ///
  /// In zh, this message translates to:
  /// **'单 URL'**
  String get editorSingleUrl;

  /// No description provided for @editorPreload.
  ///
  /// In zh, this message translates to:
  /// **'预加载'**
  String get editorPreload;

  /// No description provided for @editorEnableJs.
  ///
  /// In zh, this message translates to:
  /// **'启用 JS'**
  String get editorEnableJs;

  /// No description provided for @editorLoadBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'以 base URL 加载'**
  String get editorLoadBaseUrl;

  /// No description provided for @editorShowWebLog.
  ///
  /// In zh, this message translates to:
  /// **'显示网页日志'**
  String get editorShowWebLog;

  /// No description provided for @editorCacheFirst.
  ///
  /// In zh, this message translates to:
  /// **'缓存优先'**
  String get editorCacheFirst;

  /// No description provided for @editorFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'{label}（{field}）'**
  String editorFieldLabel(String label, String field);

  /// No description provided for @enterEditorField.
  ///
  /// In zh, this message translates to:
  /// **'请输入{label}'**
  String enterEditorField(String label);

  /// No description provided for @editorSettingsSummary.
  ///
  /// In zh, this message translates to:
  /// **'设置, {summary}, {action}'**
  String editorSettingsSummary(String summary, String action);

  /// No description provided for @editorCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get editorCollapse;

  /// No description provided for @editorExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get editorExpand;

  /// No description provided for @editorJsonHint.
  ///
  /// In zh, this message translates to:
  /// **'JSON 格式'**
  String get editorJsonHint;

  /// No description provided for @editorSearchUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：https://example.com/search?q=searchKey'**
  String get editorSearchUrlHint;

  /// No description provided for @editorExploreUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：分类名::https://example.com/sort\n或 url 形式'**
  String get editorExploreUrlHint;

  /// No description provided for @editorGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'多个分组用逗号分隔'**
  String get editorGroupHint;

  /// No description provided for @editorSortHint.
  ///
  /// In zh, this message translates to:
  /// **'分类名::规则'**
  String get editorSortHint;

  /// No description provided for @editorRateHint.
  ///
  /// In zh, this message translates to:
  /// **'如：16/s'**
  String get editorRateHint;

  /// No description provided for @editorJsLibraryHint.
  ///
  /// In zh, this message translates to:
  /// **'源使用的 JavaScript 库'**
  String get editorJsLibraryHint;

  /// No description provided for @editorArticlesHint.
  ///
  /// In zh, this message translates to:
  /// **'ruleArticles，如 item 或 //item'**
  String get editorArticlesHint;

  /// No description provided for @editorCssHint.
  ///
  /// In zh, this message translates to:
  /// **'文章页面 CSS'**
  String get editorCssHint;

  /// No description provided for @newBookSource.
  ///
  /// In zh, this message translates to:
  /// **'新建书源'**
  String get newBookSource;

  /// No description provided for @editBookSource.
  ///
  /// In zh, this message translates to:
  /// **'编辑书源'**
  String get editBookSource;

  /// No description provided for @newRssSource.
  ///
  /// In zh, this message translates to:
  /// **'新建订阅源'**
  String get newRssSource;

  /// No description provided for @editRssSource.
  ///
  /// In zh, this message translates to:
  /// **'编辑订阅源'**
  String get editRssSource;

  /// No description provided for @editSourceContent.
  ///
  /// In zh, this message translates to:
  /// **'编辑内容'**
  String get editSourceContent;

  /// No description provided for @debugSource.
  ///
  /// In zh, this message translates to:
  /// **'调试源'**
  String get debugSource;

  /// No description provided for @moreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多选项'**
  String get moreOptions;

  /// No description provided for @testSource.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testSource;

  /// No description provided for @bookSourceCreated.
  ///
  /// In zh, this message translates to:
  /// **'书源已创建'**
  String get bookSourceCreated;

  /// No description provided for @bookSourceSaved.
  ///
  /// In zh, this message translates to:
  /// **'书源已保存'**
  String get bookSourceSaved;

  /// No description provided for @rssSourceUpdated.
  ///
  /// In zh, this message translates to:
  /// **'订阅源已更新'**
  String get rssSourceUpdated;

  /// No description provided for @rssSourceAdded.
  ///
  /// In zh, this message translates to:
  /// **'订阅源已添加'**
  String get rssSourceAdded;

  /// No description provided for @sourceSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String sourceSaveFailed(String error);

  /// No description provided for @clearCookies.
  ///
  /// In zh, this message translates to:
  /// **'清除Cookie'**
  String get clearCookies;

  /// No description provided for @cookiesCleared.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 已清除'**
  String get cookiesCleared;

  /// No description provided for @clearCookiesFailed.
  ///
  /// In zh, this message translates to:
  /// **'清除 Cookie 失败：{error}'**
  String clearCookiesFailed(String error);

  /// No description provided for @autoComplete.
  ///
  /// In zh, this message translates to:
  /// **'自动补全'**
  String get autoComplete;

  /// No description provided for @autoCompleteEnabled.
  ///
  /// In zh, this message translates to:
  /// **'自动补全已开启'**
  String get autoCompleteEnabled;

  /// No description provided for @autoCompleteDisabled.
  ///
  /// In zh, this message translates to:
  /// **'自动补全已关闭'**
  String get autoCompleteDisabled;

  /// No description provided for @copySource.
  ///
  /// In zh, this message translates to:
  /// **'拷贝源'**
  String get copySource;

  /// No description provided for @pasteSource.
  ///
  /// In zh, this message translates to:
  /// **'粘贴源'**
  String get pasteSource;

  /// No description provided for @importSourceQr.
  ///
  /// In zh, this message translates to:
  /// **'二维码导入'**
  String get importSourceQr;

  /// No description provided for @shareSourceQr.
  ///
  /// In zh, this message translates to:
  /// **'二维码分享'**
  String get shareSourceQr;

  /// No description provided for @shareSourceText.
  ///
  /// In zh, this message translates to:
  /// **'字符串分享'**
  String get shareSourceText;

  /// No description provided for @shareBookSource.
  ///
  /// In zh, this message translates to:
  /// **'分享书源'**
  String get shareBookSource;

  /// No description provided for @enterBookSourceUrlFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先填写书源 URL'**
  String get enterBookSourceUrlFirst;

  /// No description provided for @enterSourceUrlFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先填写源 URL'**
  String get enterSourceUrlFirst;

  /// No description provided for @sourceVariableCleared.
  ///
  /// In zh, this message translates to:
  /// **'源变量已清除'**
  String get sourceVariableCleared;

  /// No description provided for @sourceVariableInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入源变量（空则清除）'**
  String get sourceVariableInputHint;

  /// No description provided for @qrTooLong.
  ///
  /// In zh, this message translates to:
  /// **'内容过长，无法生成二维码，请使用字符串分享'**
  String get qrTooLong;

  /// No description provided for @qrGenerateFailed.
  ///
  /// In zh, this message translates to:
  /// **'二维码生成失败'**
  String get qrGenerateFailed;

  /// No description provided for @shareImage.
  ///
  /// In zh, this message translates to:
  /// **'分享图片'**
  String get shareImage;

  /// No description provided for @clipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板为空'**
  String get clipboardEmpty;

  /// No description provided for @pastedBookSource.
  ///
  /// In zh, this message translates to:
  /// **'已粘贴书源：{name}'**
  String pastedBookSource(String name);

  /// No description provided for @clipboardInvalidBookSource.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板内容不是有效的书源 JSON'**
  String get clipboardInvalidBookSource;

  /// No description provided for @bookSourceShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'书源分享'**
  String get bookSourceShareSubject;

  /// No description provided for @importedBookSource.
  ///
  /// In zh, this message translates to:
  /// **'已导入书源：{name}'**
  String importedBookSource(String name);

  /// No description provided for @qrInvalidBookSource.
  ///
  /// In zh, this message translates to:
  /// **'扫码内容不是有效的书源 JSON'**
  String get qrInvalidBookSource;

  /// No description provided for @sourceProtocolImportHint.
  ///
  /// In zh, this message translates to:
  /// **'legado 协议链接请使用「关联导入」页处理'**
  String get sourceProtocolImportHint;

  /// No description provided for @sourceUrlImportHint.
  ///
  /// In zh, this message translates to:
  /// **'URL 内容请使用书源管理页的网络导入处理'**
  String get sourceUrlImportHint;

  /// No description provided for @sourceSearchOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开搜索失败：{error}'**
  String sourceSearchOpenFailed(String error);

  /// No description provided for @sourceDebugFailed.
  ///
  /// In zh, this message translates to:
  /// **'调试失败：{error}'**
  String sourceDebugFailed(String error);

  /// No description provided for @focusSourceFieldFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先将光标放在要编辑的输入框'**
  String get focusSourceFieldFirst;

  /// No description provided for @bookSourceNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到书源，可能已被删除'**
  String get bookSourceNotFound;

  /// No description provided for @enterSourceName.
  ///
  /// In zh, this message translates to:
  /// **'请输入源名称'**
  String get enterSourceName;

  /// No description provided for @enterSourceUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入源 URL'**
  String get enterSourceUrl;

  /// No description provided for @unsavedChanges.
  ///
  /// In zh, this message translates to:
  /// **'未保存的修改'**
  String get unsavedChanges;

  /// No description provided for @discardSourceChanges.
  ///
  /// In zh, this message translates to:
  /// **'修改尚未保存，确定要放弃修改并退出吗？'**
  String get discardSourceChanges;

  /// No description provided for @discard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get discard;

  /// No description provided for @testSourceUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先输入源 URL'**
  String get testSourceUrlRequired;

  /// No description provided for @sourceTestNoArticles.
  ///
  /// In zh, this message translates to:
  /// **'连接成功，但未获取到文章（可能需要配置规则）'**
  String get sourceTestNoArticles;

  /// No description provided for @untitledArticle.
  ///
  /// In zh, this message translates to:
  /// **'(无标题)'**
  String get untitledArticle;

  /// No description provided for @sourceTestArticles.
  ///
  /// In zh, this message translates to:
  /// **'成功获取 {count} 篇文章：\n{titles}'**
  String sourceTestArticles(int count, String titles);

  /// No description provided for @sourceTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试失败：{error}'**
  String sourceTestFailed(String error);

  /// No description provided for @copiedRssSource.
  ///
  /// In zh, this message translates to:
  /// **'已复制订阅源到剪贴板'**
  String get copiedRssSource;

  /// No description provided for @rssSourceShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'订阅源分享：{name}'**
  String rssSourceShareSubject(String name);

  /// No description provided for @pastedRssSource.
  ///
  /// In zh, this message translates to:
  /// **'已从剪贴板粘贴订阅源'**
  String get pastedRssSource;

  /// No description provided for @pasteRssSourceFailed.
  ///
  /// In zh, this message translates to:
  /// **'粘贴失败，剪贴板不是有效的订阅源 JSON：{error}'**
  String pasteRssSourceFailed(String error);

  /// 书源调试与登录界面：书源调试
  ///
  /// In zh, this message translates to:
  /// **'书源调试'**
  String get bookSourceDebugTitle;

  /// 书源调试与登录界面：RSS 源调试
  ///
  /// In zh, this message translates to:
  /// **'RSS 源调试'**
  String get rssSourceDebugTitle;

  /// 书源调试与登录界面：清空日志
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get clearDebugLogs;

  /// 书源调试与登录界面：书源 URL
  ///
  /// In zh, this message translates to:
  /// **'书源 URL'**
  String get debugBookSourceUrlLabel;

  /// 书源调试与登录界面：输入要调试的书源地址
  ///
  /// In zh, this message translates to:
  /// **'输入要调试的书源地址'**
  String get debugBookSourceUrlHint;

  /// 书源调试与登录界面：搜索关键词
  ///
  /// In zh, this message translates to:
  /// **'搜索关键词'**
  String get debugKeywordLabel;

  /// 书源调试与登录界面：关键词 / URL / ++目录 / --正文
  ///
  /// In zh, this message translates to:
  /// **'关键词 / URL / ++目录 / --正文'**
  String get debugKeywordHint;

  /// 书源调试与登录界面：调试
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get debugAction;

  /// 书源调试与登录界面：停止
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stopAction;

  /// 书源调试与登录界面：运行中
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get debugRunning;

  /// 书源调试与登录界面：全不选
  ///
  /// In zh, this message translates to:
  /// **'全不选'**
  String get deselectAll;

  /// 书源调试与登录界面：成功
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get debugLogSuccess;

  /// 书源调试与登录界面：{visible} / {total} 条
  ///
  /// In zh, this message translates to:
  /// **'{visible} / {total} 条'**
  String debugLogCount(int visible, int total);

  /// 书源调试与登录界面：输入书源 URL 和关键词后点击“调试”开始
  ///
  /// In zh, this message translates to:
  /// **'输入书源 URL 和关键词后点击“调试”开始'**
  String get debugBookSourceEmptyHint;

  /// 书源调试与登录界面：没有匹配的日志条目
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的日志条目'**
  String get debugNoMatchingLogs;

  /// 书源调试与登录界面：点击“调试”开始执行
  ///
  /// In zh, this message translates to:
  /// **'点击“调试”开始执行'**
  String get debugRssEmptyHint;

  /// 书源调试与登录界面：错误：请输入书源 URL
  ///
  /// In zh, this message translates to:
  /// **'错误：请输入书源 URL'**
  String get debugBookSourceUrlRequired;

  /// 书源调试与登录界面：错误：请输入搜索关键词
  ///
  /// In zh, this message translates to:
  /// **'错误：请输入搜索关键词'**
  String get debugKeywordRequired;

  /// 书源调试与登录界面：⇒开始调试
  ///
  /// In zh, this message translates to:
  /// **'⇒开始调试'**
  String get debugStarting;

  /// 书源调试与登录界面：异常: {error}
  ///
  /// In zh, this message translates to:
  /// **'异常: {error}'**
  String debugException(String error);

  /// 书源调试与登录界面：错误：请先输入 RSS 源地址
  ///
  /// In zh, this message translates to:
  /// **'错误：请先输入 RSS 源地址'**
  String get debugRssUrlRequired;

  /// 书源调试与登录界面：=== 开始调试 RSS 源 ===
  ///
  /// In zh, this message translates to:
  /// **'=== 开始调试 RSS 源 ==='**
  String get debugRssStarting;

  /// 书源调试与登录界面：源地址: {url}
  ///
  /// In zh, this message translates to:
  /// **'源地址: {url}'**
  String debugSourceAddress(String url);

  /// 书源调试与登录界面：[1/2] 正在查询已注册的 RSS 源...
  ///
  /// In zh, this message translates to:
  /// **'[1/2] 正在查询已注册的 RSS 源...'**
  String get debugRssQuery;

  /// 书源调试与登录界面：未在书架注册该 RSS 源，将直接按 URL 抓取
  ///
  /// In zh, this message translates to:
  /// **'未在书架注册该 RSS 源，将直接按 URL 抓取'**
  String get debugRssUnregistered;

  /// 书源调试与登录界面：源名称: {name}
  ///
  /// In zh, this message translates to:
  /// **'源名称: {name}'**
  String debugSourceName(String name);

  /// 书源调试与登录界面：[2/2] 正在抓取文章列表...
  ///
  /// In zh, this message translates to:
  /// **'[2/2] 正在抓取文章列表...'**
  String get debugRssFetch;

  /// 书源调试与登录界面：未获取到文章（可能需要配置规则或源不可达）
  ///
  /// In zh, this message translates to:
  /// **'未获取到文章（可能需要配置规则或源不可达）'**
  String get debugRssNoArticles;

  /// 书源调试与登录界面：抓取完成，共 {count} 篇文章
  ///
  /// In zh, this message translates to:
  /// **'抓取完成，共 {count} 篇文章'**
  String debugRssArticlesFound(int count);

  /// 书源调试与登录界面：      链接: {url}
  ///
  /// In zh, this message translates to:
  /// **'      链接: {url}'**
  String debugArticleLink(String url);

  /// 书源调试与登录界面：  ...（其余 {count} 篇省略）
  ///
  /// In zh, this message translates to:
  /// **'  ...（其余 {count} 篇省略）'**
  String debugRssArticlesOmitted(int count);

  /// 书源调试与登录界面：=== 调试完成 ===
  ///
  /// In zh, this message translates to:
  /// **'=== 调试完成 ==='**
  String get debugFinished;

  /// 书源调试与登录界面：登录 {source}
  ///
  /// In zh, this message translates to:
  /// **'登录 {source}'**
  String loginToSource(String source);

  /// 书源调试与登录界面：手动输入
  ///
  /// In zh, this message translates to:
  /// **'手动输入'**
  String get manualLoginInput;

  /// 书源调试与登录界面：登录链接
  ///
  /// In zh, this message translates to:
  /// **'登录链接'**
  String get loginLink;

  /// 书源调试与登录界面：该书源未配置登录链接
  ///
  /// In zh, this message translates to:
  /// **'该书源未配置登录链接'**
  String get sourceLoginLinkMissing;

  /// 书源调试与登录界面：登录链接无效
  ///
  /// In zh, this message translates to:
  /// **'登录链接无效'**
  String get sourceLoginLinkInvalid;

  /// 书源调试与登录界面：无法打开登录链接
  ///
  /// In zh, this message translates to:
  /// **'无法打开登录链接'**
  String get sourceLoginLinkOpenFailed;

  /// 书源调试与登录界面：Cookie 名称不能为空
  ///
  /// In zh, this message translates to:
  /// **'Cookie 名称不能为空'**
  String get cookieNameRequired;

  /// 书源调试与登录界面：Header 名称不能为空
  ///
  /// In zh, this message translates to:
  /// **'Header 名称不能为空'**
  String get headerNameRequired;

  /// 书源调试与登录界面：登录信息已保存
  ///
  /// In zh, this message translates to:
  /// **'登录信息已保存'**
  String get loginInfoSaved;

  /// 书源调试与登录界面：保存失败，请重试
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get loginSaveFailed;

  /// 书源调试与登录界面：保存登录信息
  ///
  /// In zh, this message translates to:
  /// **'保存登录信息'**
  String get saveLoginInfo;

  /// 书源调试与登录界面：Token（可选）
  ///
  /// In zh, this message translates to:
  /// **'Token（可选）'**
  String get optionalLoginToken;

  /// 书源调试与登录界面：Bearer Token / API Key
  ///
  /// In zh, this message translates to:
  /// **'Bearer Token / API Key'**
  String get loginTokenHint;

  /// 书源调试与登录界面：Cookies
  ///
  /// In zh, this message translates to:
  /// **'Cookies'**
  String get loginCookies;

  /// 书源调试与登录界面：名称
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get loginCookieNameHint;

  /// 书源调试与登录界面：值
  ///
  /// In zh, this message translates to:
  /// **'值'**
  String get loginCookieValueHint;

  /// 书源调试与登录界面：Headers（可选）
  ///
  /// In zh, this message translates to:
  /// **'Headers（可选）'**
  String get optionalLoginHeaders;

  /// 书源调试与登录界面：请求头名称
  ///
  /// In zh, this message translates to:
  /// **'请求头名称'**
  String get loginHeaderNameHint;

  /// 书源调试与登录界面：请求头值
  ///
  /// In zh, this message translates to:
  /// **'请求头值'**
  String get loginHeaderValueHint;

  /// 书源调试与登录界面：在浏览器完成登录后，复制 Cookie 并切换到“手动输入”标签页粘贴。
  ///
  /// In zh, this message translates to:
  /// **'在浏览器完成登录后，复制 Cookie 并切换到“手动输入”标签页粘贴。'**
  String get browserLoginInstructions;

  /// 书源调试与登录界面：动作执行失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'动作执行失败：{error}'**
  String loginActionFailed(String error);

  /// 书源调试与登录界面：登录出错：{error}
  ///
  /// In zh, this message translates to:
  /// **'登录出错：{error}'**
  String sourceLoginFailed(String error);

  /// 书源调试与登录界面：登录头
  ///
  /// In zh, this message translates to:
  /// **'登录头'**
  String get loginHeader;

  /// 书源调试与登录界面：（无）
  ///
  /// In zh, this message translates to:
  /// **'（无）'**
  String get loginNoValue;

  /// 书源调试与登录界面：登录头已删除
  ///
  /// In zh, this message translates to:
  /// **'登录头已删除'**
  String get loginHeaderDeleted;

  /// 书源调试与登录界面：登录信息已清除
  ///
  /// In zh, this message translates to:
  /// **'登录信息已清除'**
  String get loginInfoCleared;

  /// 书源调试与登录界面：查看登录头
  ///
  /// In zh, this message translates to:
  /// **'查看登录头'**
  String get viewLoginHeader;

  /// 书源调试与登录界面：删除登录头
  ///
  /// In zh, this message translates to:
  /// **'删除登录头'**
  String get deleteLoginHeader;

  /// 书源调试与登录界面：清除登录信息
  ///
  /// In zh, this message translates to:
  /// **'清除登录信息'**
  String get clearLoginInfo;

  /// 书源调试与登录界面：登录表单解析失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'登录表单解析失败：{error}'**
  String loginFormParseFailed(String error);

  /// 书源调试与登录界面：该书源未配置登录表单
  ///
  /// In zh, this message translates to:
  /// **'该书源未配置登录表单'**
  String get sourceLoginFormMissing;

  /// 书源调试与登录界面：{label}（{seconds}秒）
  ///
  /// In zh, this message translates to:
  /// **'{label}（{seconds}秒）'**
  String loginButtonCountdown(String label, int seconds);

  /// 书源调试与登录界面：登录检测完成
  ///
  /// In zh, this message translates to:
  /// **'登录检测完成'**
  String get loginCheckCompleted;

  /// 书源调试与登录界面：即将跳转到其他应用打开：{url}
  ///
  /// In zh, this message translates to:
  /// **'即将跳转到其他应用打开：{url}'**
  String openingExternalApp(String url);

  /// 书源调试与登录界面：页面加载失败：{error}
  ///
  /// In zh, this message translates to:
  /// **'页面加载失败：{error}'**
  String loginPageLoadFailed(String error);

  /// 书源调试与登录界面：正在检测 Cookie…
  ///
  /// In zh, this message translates to:
  /// **'正在检测 Cookie…'**
  String get checkingLoginCookies;

  /// 书源调试与登录界面：检测
  ///
  /// In zh, this message translates to:
  /// **'检测'**
  String get checkLoginAction;

  /// 书源调试与登录界面：手动编辑 Cookie
  ///
  /// In zh, this message translates to:
  /// **'手动编辑 Cookie'**
  String get editLoginCookies;

  /// 书源调试与登录界面：需要登录
  ///
  /// In zh, this message translates to:
  /// **'需要登录'**
  String get loginRequiredTitle;

  /// 书源调试与登录界面：书源需要登录，请先在书源菜单中登录后重试
  ///
  /// In zh, this message translates to:
  /// **'书源需要登录，请先在书源菜单中登录后重试'**
  String get sourceLoginRetryHint;

  /// 动态登录表单的无详细错误兜底提示
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get loginFailed;

  /// 手动输入页与动态表单标题，保留现有中文分隔符
  ///
  /// In zh, this message translates to:
  /// **'登录 - {source}'**
  String loginFormTitle(String source);

  /// 经典登录表单顶栏确认操作
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirmLoginAction;

  /// 阅读设置文案；对应 HapeLee page_anim_slide
  ///
  /// In zh, this message translates to:
  /// **'滑动'**
  String get readerSlide;

  /// 阅读设置文案；对应 HapeLee page_anim_simulation
  ///
  /// In zh, this message translates to:
  /// **'仿真'**
  String get readerSimulation;

  /// 阅读设置文案；对应 HapeLee page_anim_scroll
  ///
  /// In zh, this message translates to:
  /// **'滚动'**
  String get readerScroll;

  /// 阅读设置文案；对应 HapeLee page_anim
  ///
  /// In zh, this message translates to:
  /// **'翻页动画'**
  String get readerPageAnimation;

  /// 阅读设置文案；对应 HapeLee font_size
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get readerFontSize;

  /// 阅读设置文案；对应 HapeLee background
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get readerBackground;

  /// 阅读设置文案；对应 HapeLee bookmark_mark_text_color
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get readerTextColor;

  /// 阅读设置文案；对应 HapeLee bg_color
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get readerBackgroundColor;

  /// 阅读设置文案；对应 HapeLee complete
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get readerDone;

  /// 阅读设置文案；对应 HapeLee arrays/NavBarColors/0
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get readerAuto;

  /// 阅读设置文案；对应 HapeLee default_font
  ///
  /// In zh, this message translates to:
  /// **'默认字体'**
  String get readerDefaultFont;

  /// 阅读设置文案；对应 HapeLee text_font
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get readerFont;

  /// 阅读设置文案；对应 HapeLee font_weight
  ///
  /// In zh, this message translates to:
  /// **'字重'**
  String get readerFontWeight;

  /// 阅读设置文案；对应 HapeLee read_config_italic
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get readerItalic;

  /// 阅读设置文案；对应 HapeLee arrays/text_font_weight/2
  ///
  /// In zh, this message translates to:
  /// **'细体'**
  String get readerWeightLight;

  /// 阅读设置文案；对应 HapeLee arrays/text_font_weight/0
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get readerWeightRegular;

  /// 阅读设置文案；对应 HapeLee arrays/text_font_weight/1
  ///
  /// In zh, this message translates to:
  /// **'粗体'**
  String get readerWeightBold;

  /// 阅读设置文案；对应 HapeLee indent_0
  ///
  /// In zh, this message translates to:
  /// **'无缩进'**
  String get readerIndentNone;

  /// 阅读设置文案；对应 HapeLee indent_1
  ///
  /// In zh, this message translates to:
  /// **'一字符'**
  String get readerIndentOne;

  /// 阅读设置文案；对应 HapeLee indent_2
  ///
  /// In zh, this message translates to:
  /// **'二字符'**
  String get readerIndentTwo;

  /// 阅读设置文案；对应 HapeLee indent_3
  ///
  /// In zh, this message translates to:
  /// **'三字符'**
  String get readerIndentThree;

  /// 阅读设置文案；对应 HapeLee paragraph_size
  ///
  /// In zh, this message translates to:
  /// **'段间距'**
  String get readerParagraphSpacing;

  /// 阅读设置文案；对应 HapeLee header
  ///
  /// In zh, this message translates to:
  /// **'页眉'**
  String get readerHeader;

  /// 阅读设置文案；对应 HapeLee footer
  ///
  /// In zh, this message translates to:
  /// **'页脚'**
  String get readerFooter;

  /// 阅读设置文案；对应 HapeLee main_body
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get readerBody;

  /// 阅读设置文案；对应 HapeLee padding_top
  ///
  /// In zh, this message translates to:
  /// **'上边距'**
  String get readerPaddingTop;

  /// 阅读设置文案；对应 HapeLee padding_bottom
  ///
  /// In zh, this message translates to:
  /// **'下边距'**
  String get readerPaddingBottom;

  /// 阅读设置文案；对应 HapeLee padding_left
  ///
  /// In zh, this message translates to:
  /// **'左边距'**
  String get readerPaddingLeft;

  /// 阅读设置文案；对应 HapeLee padding_right
  ///
  /// In zh, this message translates to:
  /// **'右边距'**
  String get readerPaddingRight;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/0
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get readerTipNone;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/1
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get readerTipBookName;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/2
  ///
  /// In zh, this message translates to:
  /// **'章节名'**
  String get readerTipChapterName;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/5
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get readerTipTime;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/9
  ///
  /// In zh, this message translates to:
  /// **'电量图标'**
  String get readerTipBatteryIcon;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/10
  ///
  /// In zh, this message translates to:
  /// **'电量百分比'**
  String get readerTipBatteryPercent;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/11
  ///
  /// In zh, this message translates to:
  /// **'页码'**
  String get readerTipPages;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/12
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get readerTipProgress;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/14
  ///
  /// In zh, this message translates to:
  /// **'页码+进度'**
  String get readerTipPagesProgress;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/15
  ///
  /// In zh, this message translates to:
  /// **'时间+电量'**
  String get readerTipTimeBattery;

  /// 阅读设置文案；对应 HapeLee arrays/read_tip/17
  ///
  /// In zh, this message translates to:
  /// **'时间+电量%'**
  String get readerTipTimeBatteryPercent;

  /// 阅读设置文案；对应 HapeLee hide_when_status_bar_show
  ///
  /// In zh, this message translates to:
  /// **'状态栏显示时隐藏'**
  String get readerHideWithStatusBar;

  /// 阅读设置文案；对应 HapeLee show
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get readerShow;

  /// 阅读设置文案；对应 HapeLee hide
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get readerHide;

  /// 阅读设置文案；对应 HapeLee content_edit_title
  ///
  /// In zh, this message translates to:
  /// **'章节标题'**
  String get readerChapterTitle;

  /// 阅读设置文案；对应 HapeLee title_left
  ///
  /// In zh, this message translates to:
  /// **'居左'**
  String get readerAlignLeft;

  /// 阅读设置文案；对应 HapeLee title_center
  ///
  /// In zh, this message translates to:
  /// **'居中'**
  String get readerAlignCenter;

  /// 阅读设置文案；对应 HapeLee showLine
  ///
  /// In zh, this message translates to:
  /// **'显示分隔线'**
  String get readerShowDivider;

  /// 阅读设置文案；对应 HapeLee auto_next_page
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get readerAutoPageTurn;

  /// 阅读设置文案；对应 HapeLee non_action
  ///
  /// In zh, this message translates to:
  /// **'无操作'**
  String get readerNoAction;

  /// 阅读设置文案；对应 HapeLee manga_reader_previous_page
  ///
  /// In zh, this message translates to:
  /// **'上一页'**
  String get readerPreviousPage;

  /// 阅读设置文案；对应 HapeLee manga_reader_next_page
  ///
  /// In zh, this message translates to:
  /// **'下一页'**
  String get readerNextPage;

  /// 阅读设置文案；对应 HapeLee menu
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get readerMenu;

  /// 阅读设置文案；对应 HapeLee manga_reader_click_area_short
  ///
  /// In zh, this message translates to:
  /// **'点击区域'**
  String get readerTapAreas;

  /// 阅读设置文案；对应 HapeLee selectText
  ///
  /// In zh, this message translates to:
  /// **'长按选择文本'**
  String get readerSelectText;

  /// 阅读设置文案；对应 HapeLee mouse_wheel_page
  ///
  /// In zh, this message translates to:
  /// **'鼠标滚轮翻页'**
  String get readerMouseWheelPage;

  /// 阅读设置文案；对应 HapeLee volume_key_page
  ///
  /// In zh, this message translates to:
  /// **'音量键翻页'**
  String get readerVolumeKeyPage;

  /// 阅读设置文案；对应 HapeLee volume_key_page_on_play
  ///
  /// In zh, this message translates to:
  /// **'朗读时音量键翻页'**
  String get readerVolumeKeyPageReading;

  /// 阅读设置文案；对应 HapeLee page_touch_slop_title
  ///
  /// In zh, this message translates to:
  /// **'滑动翻页阈值'**
  String get readerPageTouchSlop;

  /// 阅读设置文案；对应 HapeLee page_touch_slop_dialog_title
  ///
  /// In zh, this message translates to:
  /// **'滑动翻页阈值（0 = 系统默认值）'**
  String get readerPageTouchSlopDialog;

  /// 阅读设置文案；对应 HapeLee screen_direction
  ///
  /// In zh, this message translates to:
  /// **'屏幕方向'**
  String get readerScreenOrientation;

  /// 阅读设置文案；对应 HapeLee screen_portrait
  ///
  /// In zh, this message translates to:
  /// **'竖屏'**
  String get readerPortrait;

  /// 阅读设置文案；对应 HapeLee screen_landscape
  ///
  /// In zh, this message translates to:
  /// **'横屏'**
  String get readerLandscape;

  /// 阅读设置文案；对应 HapeLee screen_sensor
  ///
  /// In zh, this message translates to:
  /// **'自动(传感器)'**
  String get readerSensor;

  /// 阅读设置文案；对应 HapeLee screen_portrait_reversed
  ///
  /// In zh, this message translates to:
  /// **'反向竖屏'**
  String get readerPortraitReversed;

  /// 阅读设置文案；对应 HapeLee screen_landscape_reversed
  ///
  /// In zh, this message translates to:
  /// **'反向横屏'**
  String get readerLandscapeReversed;

  /// 阅读设置文案；对应 HapeLee keep_light
  ///
  /// In zh, this message translates to:
  /// **'保持亮屏'**
  String get readerKeepAwake;

  /// 阅读设置文案；对应 HapeLee arrays/screen_time_out/0
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get readerDefault;

  /// 阅读设置文案；对应 HapeLee arrays/screen_time_out/1
  ///
  /// In zh, this message translates to:
  /// **'1 分钟'**
  String get readerAwakeMinute;

  /// 阅读设置文案；对应 HapeLee arrays/screen_time_out/2
  ///
  /// In zh, this message translates to:
  /// **'5 分钟'**
  String get readerAwakeFiveMinutes;

  /// 阅读设置文案；对应 HapeLee arrays/screen_time_out/3
  ///
  /// In zh, this message translates to:
  /// **'10 分钟'**
  String get readerAwakeTenMinutes;

  /// 阅读设置文案；对应 HapeLee arrays/screen_time_out/4
  ///
  /// In zh, this message translates to:
  /// **'常亮'**
  String get readerAwakeAlways;

  /// 阅读设置文案；对应 HapeLee pt_hide_status_bar
  ///
  /// In zh, this message translates to:
  /// **'隐藏状态栏'**
  String get readerHideStatusBar;

  /// 阅读设置文案；对应 HapeLee pt_hide_navigation_bar
  ///
  /// In zh, this message translates to:
  /// **'隐藏导航栏'**
  String get readerHideNavigationBar;

  /// 阅读设置文案；对应 HapeLee read_body_to_lh
  ///
  /// In zh, this message translates to:
  /// **'扩展到刘海'**
  String get readerExtendCutout;

  /// 阅读设置文案；对应 HapeLee padding_display_cutouts
  ///
  /// In zh, this message translates to:
  /// **'填充刘海区域'**
  String get readerFillCutout;

  /// 阅读设置文案；对应 HapeLee double_page_horizontal
  ///
  /// In zh, this message translates to:
  /// **'平板/横屏双页'**
  String get readerDualPageMode;

  /// 阅读设置文案；对应 HapeLee arrays/double_page_title/0
  ///
  /// In zh, this message translates to:
  /// **'全局单页'**
  String get readerSinglePage;

  /// 阅读设置文案；对应 HapeLee arrays/double_page_title/1
  ///
  /// In zh, this message translates to:
  /// **'全局双页'**
  String get readerDoublePage;

  /// 阅读设置文案；对应 HapeLee arrays/double_page_title/2
  ///
  /// In zh, this message translates to:
  /// **'横屏双页'**
  String get readerLandscapeDoublePage;

  /// 阅读设置文案；对应 HapeLee jf_convert
  ///
  /// In zh, this message translates to:
  /// **'简繁转换'**
  String get readerChineseConversion;

  /// 阅读设置文案；对应 HapeLee arrays/chinese_mode/0
  ///
  /// In zh, this message translates to:
  /// **'不转换'**
  String get readerNoConversion;

  /// 阅读设置文案；对应 HapeLee arrays/chinese_mode/1
  ///
  /// In zh, this message translates to:
  /// **'繁→简'**
  String get readerToSimplified;

  /// 阅读设置文案；对应 HapeLee arrays/chinese_mode/2
  ///
  /// In zh, this message translates to:
  /// **'简→繁'**
  String get readerToTraditional;

  /// 阅读设置文案；对应 HapeLee auto_change_source
  ///
  /// In zh, this message translates to:
  /// **'自动换源'**
  String get readerAutoChangeSource;

  /// 阅读设置文案；对应 HapeLee progress_bar_behavior
  ///
  /// In zh, this message translates to:
  /// **'进度条行为'**
  String get readerProgressBarBehavior;

  /// 阅读设置文案；对应 HapeLee adjust_chapter_page
  ///
  /// In zh, this message translates to:
  /// **'调章内页'**
  String get readerAdjustChapterPage;

  /// 阅读设置文案；对应 HapeLee adjust_chapter_index
  ///
  /// In zh, this message translates to:
  /// **'调章节'**
  String get readerAdjustChapterIndex;

  /// 阅读设置文案；对应 HapeLee read_bar_style_follow_page
  ///
  /// In zh, this message translates to:
  /// **'工具栏跟随页面'**
  String get readerToolbarFollowPage;

  /// 阅读设置文案；对应 HapeLee brightness_bar_off
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get readerBrightnessOff;

  /// 阅读设置文案；对应 HapeLee brightness_bar_horizontal
  ///
  /// In zh, this message translates to:
  /// **'横向'**
  String get readerBrightnessHorizontal;

  /// 高级设置文案；对应 HapeLee main_activity
  ///
  /// In zh, this message translates to:
  /// **'主界面'**
  String get advancedMainScreen;

  /// 高级设置文案；对应 HapeLee pt_auto_refresh
  ///
  /// In zh, this message translates to:
  /// **'自动刷新'**
  String get advancedAutoRefresh;

  /// 高级设置文案；对应 HapeLee ps_auto_refresh
  ///
  /// In zh, this message translates to:
  /// **'打开软件时自动更新书籍'**
  String get advancedAutoRefreshDescription;

  /// 高级设置文案；对应 HapeLee pt_default_read
  ///
  /// In zh, this message translates to:
  /// **'自动跳转最近阅读'**
  String get advancedRecentReading;

  /// 高级设置文案；对应 HapeLee ps_default_read
  ///
  /// In zh, this message translates to:
  /// **'默认打开书架'**
  String get advancedRecentReadingDescription;

  /// 高级设置文案；对应 HapeLee show_discovery
  ///
  /// In zh, this message translates to:
  /// **'显示发现'**
  String get advancedShowDiscovery;

  /// 高级设置文案；对应 HapeLee show_rss
  ///
  /// In zh, this message translates to:
  /// **'显示订阅'**
  String get advancedShowRss;

  /// 高级设置文案；对应 HapeLee default_home_page
  ///
  /// In zh, this message translates to:
  /// **'默认主页'**
  String get advancedDefaultHomePage;

  /// 高级设置文案；对应 HapeLee default_home_page
  ///
  /// In zh, this message translates to:
  /// **'默认首页'**
  String get advancedDefaultHomePageDialog;

  /// 高级设置文案；对应 HapeLee set_local_password
  ///
  /// In zh, this message translates to:
  /// **'设置本地密码'**
  String get advancedLocalPassword;

  /// 高级设置文案；对应 HapeLee set_local_password_summary
  ///
  /// In zh, this message translates to:
  /// **'本地密码用来对备份的敏感信息加密和解密,如需在不同设备之间同步,本地密码需一致.'**
  String get advancedLocalPasswordDescription;

  /// 高级设置文案；对应 HapeLee user_agent
  ///
  /// In zh, this message translates to:
  /// **'用户代理'**
  String get advancedUserAgent;

  /// 高级设置文案；对应 HapeLee book_tree_uri_t
  ///
  /// In zh, this message translates to:
  /// **'书籍保存位置'**
  String get advancedBookSaveLocation;

  /// 高级设置文案；对应 HapeLee book_tree_uri_s
  ///
  /// In zh, this message translates to:
  /// **'从其它应用打开的书籍保存位置'**
  String get advancedBookSaveLocationDescription;

  /// 高级设置文案；对应 HapeLee source_edit_text_max_line
  ///
  /// In zh, this message translates to:
  /// **'源编辑框最大行数'**
  String get advancedSourceEditorMaxLines;

  /// 高级设置文案；对应 HapeLee check_source_config
  ///
  /// In zh, this message translates to:
  /// **'校验设置'**
  String get advancedCheckSourceSettings;

  /// 高级设置文案；对应 HapeLee anti_alias
  ///
  /// In zh, this message translates to:
  /// **'抗锯齿'**
  String get advancedAntiAlias;

  /// 高级设置文案；对应 HapeLee pref_anti_alias_summary
  ///
  /// In zh, this message translates to:
  /// **'绘制图片时抗锯齿'**
  String get advancedAntiAliasDescription;

  /// 高级设置文案；对应 HapeLee bitmap_cache_size
  ///
  /// In zh, this message translates to:
  /// **'图片绘制缓存'**
  String get advancedBitmapCache;

  /// 高级设置文案；对应 HapeLee image_retain_number
  ///
  /// In zh, this message translates to:
  /// **'漫画保留数量'**
  String get advancedMangaRetention;

  /// 高级设置文案；对应 HapeLee pre_download
  ///
  /// In zh, this message translates to:
  /// **'预下载'**
  String get advancedPreDownload;

  /// 高级设置文案；对应 HapeLee replace_enable_default_t
  ///
  /// In zh, this message translates to:
  /// **'默认启用替换净化'**
  String get advancedReplaceByDefault;

  /// 高级设置文案；对应 HapeLee replace_enable_default_s
  ///
  /// In zh, this message translates to:
  /// **'新加入书架的书是否启用替换净化'**
  String get advancedReplaceByDefaultDescription;

  /// 高级设置文案；对应 HapeLee media_button_on_exit_title
  ///
  /// In zh, this message translates to:
  /// **'全程响应耳机按键'**
  String get advancedHeadsetAlways;

  /// 高级设置文案；对应 HapeLee media_button_on_exit_summary
  ///
  /// In zh, this message translates to:
  /// **'即使退出软件也响应耳机按键'**
  String get advancedHeadsetAlwaysDescription;

  /// 高级设置文案；对应 HapeLee read_aloud_by_media_button_title
  ///
  /// In zh, this message translates to:
  /// **'耳机按键启动朗读'**
  String get advancedHeadsetReadAloud;

  /// 高级设置文案；对应 HapeLee read_aloud_by_media_button_summary
  ///
  /// In zh, this message translates to:
  /// **'通过耳机按键来启动朗读'**
  String get advancedHeadsetReadAloudDescription;

  /// 高级设置文案；对应 HapeLee ignore_audio_focus_title
  ///
  /// In zh, this message translates to:
  /// **'忽略音频焦点'**
  String get advancedIgnoreAudioFocus;

  /// 高级设置文案；对应 HapeLee ignore_audio_focus_summary
  ///
  /// In zh, this message translates to:
  /// **'允许与其他应用同时播放音频'**
  String get advancedIgnoreAudioFocusDescription;

  /// 高级设置文案；对应 HapeLee auto_clear_expired
  ///
  /// In zh, this message translates to:
  /// **'自动清除过期搜索数据'**
  String get advancedClearExpiredSearch;

  /// 高级设置文案；对应 HapeLee auto_clear_expired_summary
  ///
  /// In zh, this message translates to:
  /// **'超过一天的搜索数据'**
  String get advancedClearExpiredSearchDescription;

  /// 高级设置文案；对应 HapeLee show_add_to_shelf_alert_title
  ///
  /// In zh, this message translates to:
  /// **'返回时提示放入书架'**
  String get advancedAddToShelfPrompt;

  /// 高级设置文案；对应 HapeLee show_add_to_shelf_alert_summary
  ///
  /// In zh, this message translates to:
  /// **'阅读未放入书架的书籍在返回时提示放入书架'**
  String get advancedAddToShelfPromptDescription;

  /// 高级设置文案；对应 HapeLee show_manga_ui
  ///
  /// In zh, this message translates to:
  /// **'漫画浏览'**
  String get advancedMangaViewer;

  /// 高级设置文案；对应 HapeLee web_port_title
  ///
  /// In zh, this message translates to:
  /// **'Web 端口'**
  String get advancedWebPort;

  /// 高级设置文案；对应 HapeLee clear_cache
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get advancedClearCache;

  /// 高级设置文案；对应 HapeLee clear_cache_summary
  ///
  /// In zh, this message translates to:
  /// **'清除已下载书籍和字体缓存'**
  String get advancedClearCacheDescription;

  /// 高级设置文案；对应 HapeLee clear_webview_data
  ///
  /// In zh, this message translates to:
  /// **'清除 WebView 数据'**
  String get advancedClearWebView;

  /// 高级设置文案；对应 HapeLee clear_webview_data_summary
  ///
  /// In zh, this message translates to:
  /// **'清除内置浏览器所有数据'**
  String get advancedClearWebViewDescription;

  /// 高级设置文案；对应 HapeLee shrink_database
  ///
  /// In zh, this message translates to:
  /// **'压缩数据库'**
  String get advancedShrinkDatabase;

  /// 高级设置文案；对应 HapeLee shrink_database_summary
  ///
  /// In zh, this message translates to:
  /// **'减小数据库文件的大小'**
  String get advancedShrinkDatabaseDescription;

  /// 高级设置文案；对应 HapeLee add_to_text_context_menu_t
  ///
  /// In zh, this message translates to:
  /// **'文字操作显示搜索'**
  String get advancedSearchTextActions;

  /// 高级设置文案；对应 HapeLee record_log
  ///
  /// In zh, this message translates to:
  /// **'记录日志'**
  String get advancedRecordLog;

  /// 高级设置文案；对应 HapeLee record_debug_log
  ///
  /// In zh, this message translates to:
  /// **'记录调试日志'**
  String get advancedRecordDebugLog;

  /// 高级设置文案；对应 HapeLee record_heap_dump_t
  ///
  /// In zh, this message translates to:
  /// **'记录堆转储'**
  String get advancedHeapDump;

  /// 高级设置文案；对应 HapeLee record_heap_dump_s
  ///
  /// In zh, this message translates to:
  /// **'当应用发生OOM崩溃时保存堆转储'**
  String get advancedHeapDumpDescription;

  /// 按页面功能核对 HapeLee top_bar_button_style；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'顶栏按钮样式'**
  String get themeTopBarButtonStyle;

  /// 按页面功能核对 HapeLee top_bar_opacity；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'顶栏背景不透明度'**
  String get themeTopBarOpacity;

  /// 按页面功能核对 HapeLee bottom_bar_opacity；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'底栏背景不透明度'**
  String get themeBottomBarOpacity;

  /// 按页面功能核对 HapeLee base_card_corner_radius；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'卡片圆角'**
  String get themeBaseCardCornerRadius;

  /// 按页面功能核对 HapeLee pure_black；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'纯黑深色模式'**
  String get themePureBlack;

  /// 按页面功能核对 HapeLee change_icon；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'切换图标'**
  String get themeChangeIcon;

  /// 按页面功能核对 HapeLee change_icon_summary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'切换软件显示在桌面的图标'**
  String get themeChangeIconSummary;

  /// 按页面功能核对 HapeLee theme_pack；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'主题管理'**
  String get themeManagement;

  /// 按页面功能核对 HapeLee theme_list_summary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'使用、保存、导入或分享主题'**
  String get themeManagementDescription;

  /// 按页面功能核对 HapeLee import_theme；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导入主题'**
  String get themeImportTheme;

  /// 按页面功能核对 HapeLee bar_elevation；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导航栏阴影'**
  String get themeBarElevation;

  /// 按页面功能核对 HapeLee cover_config；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'封面设置'**
  String get themeCoverConfig;

  /// 按页面功能核对 HapeLee cover_config_summary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'通用封面规则及默认封面样式'**
  String get themeCoverConfigSummary;

  /// 按页面功能核对 HapeLee merge_top_bar_actions；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'合并顶栏按钮'**
  String get themeMergeTopBarActions;

  /// 按页面功能核对 HapeLee floating_bottom_bar；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'悬浮底栏'**
  String get themeFloatingBottomBar;

  /// 按页面功能核对 HapeLee book_info_page；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'书籍详情页'**
  String get themeBookInfoPage;

  /// 按页面功能核对 HapeLee book_info_follow_cover_color；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'界面颜色跟随封面取色'**
  String get themeBookInfoFollowCoverColor;

  /// 按页面功能核对 HapeLee book_info_follow_cover_color_summary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'仅在显示背景封面时生效'**
  String get themeBookInfoFollowCoverColorSummary;

  /// 按页面功能核对 HapeLee book_info_network_cover_background；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'网络封面背景设置'**
  String get themeBookInfoNetworkCoverBackground;

  /// 按页面功能核对 HapeLee book_info_default_cover_background；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'默认封面背景设置'**
  String get themeBookInfoDefaultCoverBackground;

  /// 按页面功能核对 HapeLee theme_manage_section_container；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'容器设置'**
  String get themeContainerSettings;

  /// 按页面功能核对 HapeLee blur_effects；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'模糊效果'**
  String get themeBlurEffects;

  /// 按页面功能核对 HapeLee primary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'主色调'**
  String get themePrimary;

  /// 按页面功能核对 HapeLee accent；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'强调色'**
  String get themeAccent;

  /// 按页面功能核对 HapeLee navbar_color；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'底部操作栏颜色'**
  String get themeNavbarColor;

  /// 按页面功能核对 HapeLee background_image；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'背景图片'**
  String get themeBackgroundImage;

  /// 按页面功能核对 HapeLee restore_default；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get themeRestoreDefault;

  /// 按页面功能核对 HapeLee cover_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'封面规则'**
  String get themeCoverRule;

  /// 按页面功能核对 HapeLee theme_name；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'主题名称'**
  String get themeThemeName;

  /// 按页面功能核对 HapeLee select_image；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get themeSelectImage;

  /// 按页面功能核对 HapeLee sort；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sourceSort;

  /// 按页面功能核对 HapeLee group_sources_by_domain；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'按域名分组显示'**
  String get sourceGroupSourcesByDomain;

  /// 按页面功能核对 HapeLee enable_selection；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'启用所选'**
  String get sourceEnableSelection;

  /// 按页面功能核对 HapeLee disable_selection；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用所选'**
  String get sourceDisableSelection;

  /// 按页面功能核对 HapeLee enable_explore；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'启用发现'**
  String get sourceEnableExplore;

  /// 按页面功能核对 HapeLee disable_explore；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用发现'**
  String get sourceDisableExplore;

  /// 按页面功能核对 HapeLee selection_to_top；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'置顶所选'**
  String get sourceSelectionToTop;

  /// 按页面功能核对 HapeLee selection_to_bottom；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'置底所选'**
  String get sourceSelectionToBottom;

  /// 按页面功能核对 HapeLee export_selection；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导出所选'**
  String get sourceExportSelection;

  /// 按页面功能核对 HapeLee share_selected_source；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'分享选中源'**
  String get sourceShareSelectedSource;

  /// 按页面功能核对 HapeLee check_select_source；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'校验所选'**
  String get sourceCheckSelectSource;

  /// 按页面功能核对 HapeLee check_selected_interval；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'选中所选区间'**
  String get sourceCheckSelectedInterval;

  /// 按页面功能核对 HapeLee more_menu；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'更多菜单'**
  String get sourceMoreMenu;

  /// 按页面功能核对 HapeLee tag_explore_enabled；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'标志:发现已启用'**
  String get sourceTagExploreEnabled;

  /// 按页面功能核对 HapeLee descending_order；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get sourceDescendingOrder;

  /// 按页面功能核对 HapeLee sort_manual；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'手动排序'**
  String get sourceSortManual;

  /// 按页面功能核对 HapeLee bookshelf_px_1；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'按更新时间'**
  String get sourceSortByUpdate;

  /// 按页面功能核对 HapeLee rule_name；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'规则名称'**
  String get ruleName;

  /// 按页面功能核对 HapeLee match_pattern；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'匹配规则'**
  String get ruleMatchPattern;

  /// 按页面功能核对 HapeLee replace_to；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get ruleReplaceTo;

  /// 按页面功能核对 HapeLee specific_scope；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'特定范围'**
  String get ruleSpecificScope;

  /// 按页面功能核对 HapeLee exclude_scope；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'排除范围'**
  String get ruleExcludeScope;

  /// 按页面功能核对 HapeLee edit_replace_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'编辑替换规则'**
  String get ruleEditReplaceRule;

  /// 按页面功能核对 HapeLee paste_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'粘贴规则'**
  String get rulePasteRule;

  /// 按页面功能核对 HapeLee use_regex；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'使用正则表达式'**
  String get ruleUseRegex;

  /// 按页面功能核对 HapeLee more_actions；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get ruleMoreActions;

  /// 按页面功能核对 HapeLee edit_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'编辑规则'**
  String get ruleEditRule;

  /// 按页面功能核对 HapeLee rule_pattern；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get ruleRegexPattern;

  /// 按页面功能核对 HapeLee add；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get ruleAdd;

  /// 按页面功能核对 HapeLee new_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'新增规则'**
  String get ruleNewRule;

  /// 按页面功能核对 HapeLee delete_selected；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'删除选中'**
  String get ruleDeleteSelected;

  /// 按页面功能核对 HapeLee test_sync_loading_text；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'测试中…'**
  String get backupTesting;

  /// 按页面功能核对 HapeLee menu_import_old_version；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导入旧版数据'**
  String get backupMenuImportOldVersion;

  /// 按页面功能核对 HapeLee webdav_device_name；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get backupWebdavDeviceName;

  /// 按页面功能核对 HapeLee backup_path；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'备份路径'**
  String get backupPath;

  /// 按页面功能核对 HapeLee select_backup_path；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'请选择备份路径'**
  String get backupSelectBackupPath;

  /// 按页面功能核对 HapeLee backup_summary；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'本地和 WebDav 一起备份'**
  String get backupSummary;

  /// 按页面功能核对 HapeLee restore_ignore；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'恢复忽略列表'**
  String get backupRestoreIgnore;

  /// 按页面功能核对 HapeLee only_latest_backup_t；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'仅保留最新备份'**
  String get backupKeepLatest;

  /// 按页面功能核对 HapeLee only_latest_backup_s；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'本地备份仅保留最新备份文件'**
  String get backupKeepLatestDescription;

  /// 按页面功能核对 HapeLee auto_check_new_backup_t；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'自动检查新备份'**
  String get backupCheckNew;

  /// 按页面功能核对 HapeLee auto_check_new_backup_s；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'打开软件时检查是否有新备份，有新备份时提示是否更新'**
  String get backupCheckNewDescription;

  /// 按页面功能核对 HapeLee use_replace_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'使用替换规则'**
  String get readerUseReplaceRule;

  /// 按页面功能核对 HapeLee load_word_count；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'加载字数'**
  String get readerLoadWordCount;

  /// 按页面功能核对 HapeLee export；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get readerExport;

  /// 按页面功能核对 HapeLee locate_current_reading；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'定位至当前阅读'**
  String get readerLocateCurrentReading;

  /// 按页面功能核对 HapeLee move_to_top；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'移至顶部'**
  String get readerMoveToTop;

  /// 按页面功能核对 HapeLee move_to_bottom；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'移至底部'**
  String get readerMoveToBottom;

  /// 按页面功能核对 HapeLee download_all；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'一键缓存'**
  String get readerDownloadAll;

  /// 按页面功能核对 HapeLee no_bookmark；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'暂无书签'**
  String get readerNoBookmark;

  /// 按页面功能核对 HapeLee sync_book_progress_t；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'同步阅读进度'**
  String get readerSyncProgress;

  /// 按页面功能核对 HapeLee chapter_change_source；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'单章换源'**
  String get readerChapterChangeSource;

  /// 按页面功能核对 HapeLee set_charset；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'设置编码'**
  String get readerSetCharset;

  /// 按页面功能核对 HapeLee disable_source；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用源'**
  String get readerDisableSource;

  /// 按页面功能核对 HapeLee open_fun；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'打开方式'**
  String get readerOpenFun;

  /// 按页面功能核对 HapeLee bookmark_add；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get readerBookmarkAdd;

  /// 按页面功能核对 HapeLee highlight_rule_config；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'高亮规则'**
  String get readerHighlightRuleConfig;

  /// 按页面功能核对 HapeLee replace_rule_title_setting；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'替换规则'**
  String get readerReplaceRuleTitleSetting;

  /// 按页面功能核对 HapeLee cover_book_progress；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'覆盖云端进度'**
  String get readerCoverBookProgress;

  /// 按页面功能核对 HapeLee reverse_content；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'反转内容'**
  String get readerReverseContent;

  /// 按页面功能核对 HapeLee re_segment；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'重新分段'**
  String get readerReSegment;

  /// 按页面功能核对 HapeLee manga_setting；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'漫画阅读设置'**
  String get mangaSetting;

  /// 按页面功能核对 HapeLee read_type；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get mangaReadType;

  /// 按页面功能核对 HapeLee enable_manga_gray；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'灰度'**
  String get mangaEnableMangaGray;

  /// 按页面功能核对 HapeLee brightness；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get mangaBrightness;

  /// 按页面功能核对 HapeLee disable_manga_click_scroll；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用点击翻页'**
  String get mangaDisableMangaClickScroll;

  /// 按页面功能核对 HapeLee disable_manga_scale；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用漫画缩放'**
  String get mangaDisableMangaScale;

  /// 按页面功能核对 HapeLee disable_manga_scroll_animation；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用翻页动画'**
  String get mangaDisableMangaScrollAnimation;

  /// 按页面功能核对 HapeLee hide_manga_title；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'隐藏漫画列表标题'**
  String get mangaHideMangaTitle;

  /// 按页面功能核对 HapeLee reverse_volume_key_page；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'反转音量键翻页方向'**
  String get mangaReverseVolumeKeyPage;

  /// 按页面功能核对 HapeLee manga_long_click；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'长按保存图片'**
  String get mangaLongClick;

  /// 按页面功能核对 HapeLee manga_cross_fade；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用加载淡入动画'**
  String get mangaCrossFade;

  /// 按页面功能核对 HapeLee manga_color_filter；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'滤镜'**
  String get mangaColorFilter;

  /// 按页面功能核对 HapeLee manga_reader_left_align；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'左对齐'**
  String get mangaReaderLeftAlign;

  /// 按页面功能核对 HapeLee manga_reader_hide_footer；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'隐藏页脚'**
  String get mangaReaderHideFooter;

  /// 按页面功能核对 HapeLee manga_check_page_label；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'页数'**
  String get mangaCheckPageLabel;

  /// 按页面功能核对 HapeLee manga_check_chapter_label；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get mangaCheckChapterLabel;

  /// 按页面功能核对 HapeLee manga_check_progress_label；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'总进度'**
  String get mangaCheckProgressLabel;

  /// 按页面功能核对 HapeLee cancel_select；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'退出选择模式'**
  String get sourceExitSelection;

  /// 按页面功能核对 HapeLee cancel_select；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'退出批量模式'**
  String get ruleExitBatchMode;

  /// 按页面功能核对 HapeLee cancel_select；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get ruleExitSelection;

  /// 按页面功能核对 HapeLee enabled_explore；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'发现已启用'**
  String get sourceDiscoveryEnabled;

  /// 按页面功能核对 HapeLee disabled_explore；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'发现已禁用'**
  String get sourceDiscoveryDisabled;

  /// 按页面功能核对 HapeLee sort_by_name；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'按名称'**
  String get sourceSortName;

  /// 按页面功能核对 HapeLee sort_by_respondTime；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'按响应时间'**
  String get sourceSortResponseTime;

  /// 按页面功能核对 HapeLee copy_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'复制规则'**
  String get ruleCopyRule;

  /// 按页面功能核对 HapeLee import_default_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'导入默认'**
  String get ruleImportDefault;

  /// 按页面功能核对 HapeLee dict_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'字典规则管理'**
  String get dictionaryRuleManagement;

  /// 按页面功能核对 HapeLee import_on_line；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'在线导入'**
  String get ruleImportOnline;

  /// 按页面功能核对 HapeLee web_dav_set；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 设置'**
  String get webdavSettings;

  /// 按页面功能核对 HapeLee web_dav_url；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 服务器地址'**
  String get webdavServerAddress;

  /// 按页面功能核对 HapeLee web_dav_url_s；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'输入你的服务器地址'**
  String get webdavServerAddressHint;

  /// 按页面功能核对 HapeLee web_dav_account；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 账号'**
  String get webdavAccount;

  /// 按页面功能核对 HapeLee web_dav_account_d；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'输入你的 WebDAV 账号'**
  String get webdavAccountHint;

  /// 按页面功能核对 HapeLee web_dav_pw；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 密码'**
  String get webdavPassword;

  /// 按页面功能核对 HapeLee web_dav_pw_s；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'输入你的密码'**
  String get webdavPasswordHint;

  /// 按页面功能核对 HapeLee test_sync_t；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'测试配置'**
  String get webdavTestConfig;

  /// 按页面功能核对 HapeLee sync_book_progress_t；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'同步书籍进度'**
  String get webdavSyncProgress;

  /// 按页面功能核对 HapeLee split_long_chapter；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'拆分长章节'**
  String get readerSplitLongChapters;

  /// 按页面功能核对 HapeLee swap_sort；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'倒序目录'**
  String get readerReverseChapterOrder;

  /// 按页面功能核对 HapeLee confirm_delete_bookmark；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'删除书签'**
  String get readerDeleteBookmark;

  /// 按页面功能核对 HapeLee book_change_source；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'换书源'**
  String get readerChangeBookSource;

  /// 按页面功能核对 HapeLee manga_reader_buy_chapter；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'章节购买'**
  String get readerPurchaseChapter;

  /// 按页面功能核对 HapeLee same_title_removed；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'删除重复标题'**
  String get readerRemoveDuplicateTitle;

  /// 按页面功能核对 HapeLee disabled；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get ruleFilterDisabled;

  /// 按页面功能核对 HapeLee no_group；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'无分组'**
  String get ruleNoGroup;

  /// 按页面功能核对 HapeLee no_group；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'（无分组）'**
  String get ruleNoGroupOption;

  /// 按页面功能核对 HapeLee full_screen；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'全屏编辑'**
  String get ruleFullscreenEditor;

  /// 按页面功能核对 HapeLee add_replace_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'添加替换规则'**
  String get ruleAddReplacement;

  /// 按页面功能核对 HapeLee highlight_tag_add_rule；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'添加规则'**
  String get ruleAddRule;

  /// 按页面功能核对 HapeLee deselect_all；只用于显示文案。
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get ruleDeselectAll;

  /// 参考 HapeLee action_search、bookmark，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'搜索书签'**
  String get bookmarkSearchHint;

  /// 参考 HapeLee search_empty、no_bookmark，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的书签'**
  String get bookmarkNoMatches;

  /// 参考 HapeLee bookmark_removed，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'书签已删除'**
  String get bookmarkDeleted;

  /// 参考 HapeLee delete_bookmark_message，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{chapter}」的书签吗？'**
  String confirmDeleteChapterBookmark(String chapter);

  /// 参考 HapeLee chapter_index_format，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 章'**
  String bookmarkChapterNumber(int number);

  /// 参考 HapeLee bookmark_mark_note，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'备注: {note}'**
  String bookmarkNoteText(String note);

  /// 参考 HapeLee action_search、read_record，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'搜索阅读记录'**
  String get readingRecordSearchHint;

  /// 参考 HapeLee read_record_options，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'排序与设置'**
  String get readingRecordOptions;

  /// 参考 HapeLee bookshelf_px_2，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'按书名排序'**
  String get readingRecordSortName;

  /// 参考 HapeLee reading_time_sort，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'按阅读时长'**
  String get readingRecordSortDuration;

  /// 参考 HapeLee last_read_time_sort，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'按最后阅读'**
  String get readingRecordSortLastRead;

  /// 参考 HapeLee enable_read_record，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'启用阅读记录'**
  String get readingRecordEnabled;

  /// 参考 HapeLee loading、read_record，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'加载阅读记录...'**
  String get readingRecordLoading;

  /// 参考 HapeLee search_empty、no_read_record，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的记录'**
  String get readingRecordNoMatches;

  /// 参考 HapeLee delete_read_record_message，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？'**
  String confirmDeleteNamedReadingRecord(String name);

  /// 参考 HapeLee clear_read_records_message，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'确定删除全部阅读记录吗？'**
  String get confirmClearReadingRecords;

  /// 参考 HapeLee reading_time_with_value，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'阅读时长：{duration}'**
  String readingRecordDurationText(String duration);

  /// 参考 HapeLee last_read_time_tag，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'最后阅读：{date}'**
  String readingRecordLastReadText(String date);

  /// 参考 HapeLee read_books_prefix、read_books_suffix，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'已读 {count} 本'**
  String readingRecordBooksRead(int count);

  /// 参考 HapeLee total_reading_time_format，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'累计 {duration}'**
  String readingRecordTotalDuration(String duration);

  /// 参考 HapeLee reload，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reload;

  /// 参考 HapeLee group_edit，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'编辑分组'**
  String get bookGroupEdit;

  /// 参考 HapeLee group_add，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'新建分组'**
  String get bookGroupNew;

  /// 参考 HapeLee sort，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get bookGroupSortMode;

  /// 参考 HapeLee loading、group_manage，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'加载分组...'**
  String get bookGroupLoading;

  /// 参考 HapeLee empty、group_manage，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'还没有分组'**
  String get bookGroupsEmpty;

  /// 参考 HapeLee book_count，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'{count} 本书'**
  String bookGroupBookCount(int count);

  /// 参考 HapeLee show、bookshelf，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'在书架显示'**
  String get bookGroupShownOnShelf;

  /// 参考 HapeLee hide、bookshelf，按本页面实际显示语境组成完整文案。
  ///
  /// In zh, this message translates to:
  /// **'在书架隐藏'**
  String get bookGroupHiddenOnShelf;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'编辑备注'**
  String get bookmarkEditNote;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'原文'**
  String get bookmarkOriginalText;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'备注（可选）'**
  String get bookmarkNoteLabel;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get bookmarkKeepEditing;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'备注尚未保存，放弃修改并关闭？'**
  String get bookmarkDiscardNote;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'保存失败，输入已保留，请重试。'**
  String get bookmarkNoteSaveFailed;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get bookmarkNoteSaving;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'备注已保存'**
  String get bookmarkNoteSaved;

  /// 书签备注编辑面板
  ///
  /// In zh, this message translates to:
  /// **'已添加书签'**
  String get bookmarkAdded;

  /// No description provided for @readAloudSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'朗读设置'**
  String get readAloudSettingsTitle;

  /// No description provided for @readAloudPlaybackGroup.
  ///
  /// In zh, this message translates to:
  /// **'播放与控制'**
  String get readAloudPlaybackGroup;

  /// No description provided for @readAloudFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'语速跟随系统'**
  String get readAloudFollowSystem;

  /// No description provided for @readAloudFollowSystemSummary.
  ///
  /// In zh, this message translates to:
  /// **'使用默认语速；关闭后可调整手动语速'**
  String get readAloudFollowSystemSummary;

  /// No description provided for @readAloudSpeed.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get readAloudSpeed;

  /// No description provided for @readAloudParagraphInterval.
  ///
  /// In zh, this message translates to:
  /// **'段间停顿'**
  String get readAloudParagraphInterval;

  /// No description provided for @readAloudSecondsUnit.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get readAloudSecondsUnit;

  /// No description provided for @readAloudVoiceGroup.
  ///
  /// In zh, this message translates to:
  /// **'引擎与声音'**
  String get readAloudVoiceGroup;

  /// No description provided for @readAloudEngines.
  ///
  /// In zh, this message translates to:
  /// **'朗读引擎与音色'**
  String get readAloudEngines;

  /// No description provided for @readAloudEnginesSummary.
  ///
  /// In zh, this message translates to:
  /// **'管理系统、HTTP 与云端朗读'**
  String get readAloudEnginesSummary;

  /// No description provided for @readAloudCloudEngines.
  ///
  /// In zh, this message translates to:
  /// **'云 TTS'**
  String get readAloudCloudEngines;

  /// No description provided for @readAloudHttpEngines.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 协议 TTS'**
  String get readAloudHttpEngines;

  /// No description provided for @readAloudSystemEngines.
  ///
  /// In zh, this message translates to:
  /// **'系统 TTS'**
  String get readAloudSystemEngines;

  /// No description provided for @readAloudSystemVoice.
  ///
  /// In zh, this message translates to:
  /// **'系统语音'**
  String get readAloudSystemVoice;

  /// No description provided for @readAloudSystemVoiceSummary.
  ///
  /// In zh, this message translates to:
  /// **'选择设备引擎与已安装的音色'**
  String get readAloudSystemVoiceSummary;

  /// No description provided for @readAloudSystemAdjustmentGroup.
  ///
  /// In zh, this message translates to:
  /// **'系统朗读调节'**
  String get readAloudSystemAdjustmentGroup;

  /// No description provided for @readAloudPitch.
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get readAloudPitch;

  /// No description provided for @readAloudVolume.
  ///
  /// In zh, this message translates to:
  /// **'音量'**
  String get readAloudVolume;

  /// No description provided for @readAloudSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存朗读设置失败：{error}'**
  String readAloudSaveFailed(String error);

  /// No description provided for @readAloudPlayer.
  ///
  /// In zh, this message translates to:
  /// **'朗读播放器'**
  String get readAloudPlayer;

  /// No description provided for @readAloudChapterText.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get readAloudChapterText;

  /// No description provided for @readAloudClassicPanel.
  ///
  /// In zh, this message translates to:
  /// **'返回经典面板'**
  String get readAloudClassicPanel;

  /// No description provided for @readAloudPreviousParagraph.
  ///
  /// In zh, this message translates to:
  /// **'上一段'**
  String get readAloudPreviousParagraph;

  /// No description provided for @readAloudNextParagraph.
  ///
  /// In zh, this message translates to:
  /// **'下一段'**
  String get readAloudNextParagraph;

  /// No description provided for @readAloudTextUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'开始朗读后显示本章正文'**
  String get readAloudTextUnavailable;

  /// No description provided for @readAloudParagraphProgress.
  ///
  /// In zh, this message translates to:
  /// **'第 {current}/{total} 段'**
  String readAloudParagraphProgress(int current, int total);

  /// No description provided for @readAloudTimer.
  ///
  /// In zh, this message translates to:
  /// **'定时停止'**
  String get readAloudTimer;

  /// No description provided for @readAloudMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String readAloudMinutes(int minutes);

  /// No description provided for @readAloudCustomMinutes.
  ///
  /// In zh, this message translates to:
  /// **'自定义分钟'**
  String get readAloudCustomMinutes;

  /// No description provided for @readAloudTimerRange.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–{max} 分钟'**
  String readAloudTimerRange(int max);

  /// No description provided for @readAloudStopAfterChapter.
  ///
  /// In zh, this message translates to:
  /// **'读完本章后停止'**
  String get readAloudStopAfterChapter;

  /// No description provided for @readAloudCancelTimer.
  ///
  /// In zh, this message translates to:
  /// **'取消定时'**
  String get readAloudCancelTimer;

  /// No description provided for @readAloudControlFailed.
  ///
  /// In zh, this message translates to:
  /// **'朗读操作失败：{error}'**
  String readAloudControlFailed(String error);

  /// No description provided for @readAloudStop.
  ///
  /// In zh, this message translates to:
  /// **'停止朗读'**
  String get readAloudStop;

  /// No description provided for @readAloudCapsuleGroup.
  ///
  /// In zh, this message translates to:
  /// **'播放胶囊'**
  String get readAloudCapsuleGroup;

  /// No description provided for @readAloudCapsuleAutoCollapse.
  ///
  /// In zh, this message translates to:
  /// **'自动收起胶囊'**
  String get readAloudCapsuleAutoCollapse;

  /// No description provided for @readAloudCapsuleAutoCollapseSummary.
  ///
  /// In zh, this message translates to:
  /// **'3 秒无操作后收起为封面'**
  String get readAloudCapsuleAutoCollapseSummary;

  /// No description provided for @readAloudDetachReminder.
  ///
  /// In zh, this message translates to:
  /// **'朗读脱离提醒'**
  String get readAloudDetachReminder;

  /// No description provided for @readAloudDetachReminderSummary.
  ///
  /// In zh, this message translates to:
  /// **'手动翻阅时继续朗读，点击提示可回到朗读位置；关闭后从当前阅读位置继续朗读'**
  String get readAloudDetachReminderSummary;

  /// No description provided for @readAloudReturnToPosition.
  ///
  /// In zh, this message translates to:
  /// **'去朗读页'**
  String get readAloudReturnToPosition;

  /// No description provided for @readAloudFromThisPage.
  ///
  /// In zh, this message translates to:
  /// **'从本页读'**
  String get readAloudFromThisPage;

  /// No description provided for @readerMenuTheme.
  ///
  /// In zh, this message translates to:
  /// **'菜单配色'**
  String get readerMenuTheme;

  /// No description provided for @readerMenuFollowApp.
  ///
  /// In zh, this message translates to:
  /// **'跟随应用'**
  String get readerMenuFollowApp;

  /// No description provided for @readerMenuFollowBackground.
  ///
  /// In zh, this message translates to:
  /// **'跟随阅读背景'**
  String get readerMenuFollowBackground;

  /// No description provided for @readerMenuCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get readerMenuCustom;

  /// No description provided for @readerMenuPalette.
  ///
  /// In zh, this message translates to:
  /// **'菜单配色风格'**
  String get readerMenuPalette;

  /// No description provided for @readerMenuTonalSpot.
  ///
  /// In zh, this message translates to:
  /// **'柔和'**
  String get readerMenuTonalSpot;

  /// No description provided for @readerMenuNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性'**
  String get readerMenuNeutral;

  /// No description provided for @readerMenuVibrant.
  ///
  /// In zh, this message translates to:
  /// **'鲜艳'**
  String get readerMenuVibrant;

  /// No description provided for @readerMenuExpressive.
  ///
  /// In zh, this message translates to:
  /// **'表现力'**
  String get readerMenuExpressive;

  /// No description provided for @readerMenuFidelity.
  ///
  /// In zh, this message translates to:
  /// **'保真'**
  String get readerMenuFidelity;

  /// No description provided for @readerMenuContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get readerMenuContent;

  /// No description provided for @readerMenuRainbow.
  ///
  /// In zh, this message translates to:
  /// **'彩虹'**
  String get readerMenuRainbow;

  /// No description provided for @readerMenuFruitSalad.
  ///
  /// In zh, this message translates to:
  /// **'水果沙拉'**
  String get readerMenuFruitSalad;

  /// No description provided for @readerMenuMonochrome.
  ///
  /// In zh, this message translates to:
  /// **'单色'**
  String get readerMenuMonochrome;

  /// No description provided for @readerMenuColorMode.
  ///
  /// In zh, this message translates to:
  /// **'自定义方式'**
  String get readerMenuColorMode;

  /// No description provided for @readerMenuSeedOnly.
  ///
  /// In zh, this message translates to:
  /// **'由主色生成'**
  String get readerMenuSeedOnly;

  /// No description provided for @readerMenuManual.
  ///
  /// In zh, this message translates to:
  /// **'分别指定颜色'**
  String get readerMenuManual;

  /// No description provided for @readerMenuEditingMode.
  ///
  /// In zh, this message translates to:
  /// **'编辑配色'**
  String get readerMenuEditingMode;

  /// No description provided for @readerMenuDay.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get readerMenuDay;

  /// No description provided for @readerMenuNight.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get readerMenuNight;

  /// No description provided for @readerMenuAccent.
  ///
  /// In zh, this message translates to:
  /// **'菜单主色'**
  String get readerMenuAccent;

  /// No description provided for @readerMenuBackground.
  ///
  /// In zh, this message translates to:
  /// **'菜单背景'**
  String get readerMenuBackground;

  /// No description provided for @readerMenuContainer.
  ///
  /// In zh, this message translates to:
  /// **'弹层背景'**
  String get readerMenuContainer;

  /// No description provided for @readerMenuTitleColor.
  ///
  /// In zh, this message translates to:
  /// **'顶栏文字颜色'**
  String get readerMenuTitleColor;

  /// No description provided for @readerMenuColorDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get readerMenuColorDefault;

  /// No description provided for @readerMenuColorHex.
  ///
  /// In zh, this message translates to:
  /// **'十六进制颜色'**
  String get readerMenuColorHex;

  /// No description provided for @readerMenuColorInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位或 8 位十六进制颜色'**
  String get readerMenuColorInvalid;

  /// No description provided for @eyeProtection.
  ///
  /// In zh, this message translates to:
  /// **'护眼模式'**
  String get eyeProtection;

  /// No description provided for @eyeProtectionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用护眼模式'**
  String get eyeProtectionEnabled;

  /// No description provided for @eyeProtectionEnabledSummary.
  ///
  /// In zh, this message translates to:
  /// **'为应用画面应用暖色滤镜，不改变原始配色'**
  String get eyeProtectionEnabledSummary;

  /// No description provided for @eyeProtectionAutoNight.
  ///
  /// In zh, this message translates to:
  /// **'跟随深色模式'**
  String get eyeProtectionAutoNight;

  /// No description provided for @eyeProtectionIntensity.
  ///
  /// In zh, this message translates to:
  /// **'滤镜强度'**
  String get eyeProtectionIntensity;

  /// No description provided for @eyeProtectionSchedule.
  ///
  /// In zh, this message translates to:
  /// **'定时启用'**
  String get eyeProtectionSchedule;

  /// No description provided for @eyeProtectionScheduleSummary.
  ///
  /// In zh, this message translates to:
  /// **'仅在指定时段生效，支持跨午夜'**
  String get eyeProtectionScheduleSummary;

  /// No description provided for @eyeProtectionStartTime.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get eyeProtectionStartTime;

  /// No description provided for @eyeProtectionEndTime.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get eyeProtectionEndTime;

  /// No description provided for @readRecordViewAggregate.
  ///
  /// In zh, this message translates to:
  /// **'汇总视图'**
  String get readRecordViewAggregate;

  /// No description provided for @readRecordViewTimeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线视图'**
  String get readRecordViewTimeline;

  /// No description provided for @readRecordViewLatest.
  ///
  /// In zh, this message translates to:
  /// **'最后阅读视图'**
  String get readRecordViewLatest;

  /// No description provided for @switchReadRecordView.
  ///
  /// In zh, this message translates to:
  /// **'切换阅读记录视图'**
  String get switchReadRecordView;

  /// No description provided for @readRecordOverview.
  ///
  /// In zh, this message translates to:
  /// **'阅读总览'**
  String get readRecordOverview;

  /// No description provided for @readRecordChapter.
  ///
  /// In zh, this message translates to:
  /// **'第{index}章'**
  String readRecordChapter(int index);

  /// No description provided for @readRecordTotalAchievement.
  ///
  /// In zh, this message translates to:
  /// **'累计阅读成就'**
  String get readRecordTotalAchievement;

  /// No description provided for @readRecordSummaryBooks.
  ///
  /// In zh, this message translates to:
  /// **'已读 {count} 本'**
  String readRecordSummaryBooks(int count);

  /// No description provided for @readRecordSummaryTime.
  ///
  /// In zh, this message translates to:
  /// **'累计阅读 {duration}'**
  String readRecordSummaryTime(String duration);

  /// No description provided for @readRecordToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get readRecordToday;

  /// No description provided for @readRecordYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get readRecordYesterday;

  /// No description provided for @readRecordDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days}天前'**
  String readRecordDaysAgo(int days);

  /// 阅读记录多选顶栏标题
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String readRecordSelectionCount(int count);

  /// No description provided for @readRecordSelectionHint.
  ///
  /// In zh, this message translates to:
  /// **'点按项目选择，返回退出'**
  String get readRecordSelectionHint;

  /// No description provided for @readRecordDayDuration.
  ///
  /// In zh, this message translates to:
  /// **'已读 {duration}'**
  String readRecordDayDuration(String duration);

  /// No description provided for @readRecordBookDuration.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长：{duration}'**
  String readRecordBookDuration(String duration);

  /// No description provided for @readRecordUnknownAuthor.
  ///
  /// In zh, this message translates to:
  /// **'未知作者'**
  String get readRecordUnknownAuthor;

  /// No description provided for @cloudTtsTitle.
  ///
  /// In zh, this message translates to:
  /// **'云端朗读引擎'**
  String get cloudTtsTitle;

  /// No description provided for @cloudTtsSummary.
  ///
  /// In zh, this message translates to:
  /// **'配置云端语音、音色与试听'**
  String get cloudTtsSummary;

  /// No description provided for @cloudTtsAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加云端引擎'**
  String get cloudTtsAdd;

  /// No description provided for @cloudTtsEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑云端引擎'**
  String get cloudTtsEdit;

  /// No description provided for @cloudTtsName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get cloudTtsName;

  /// No description provided for @cloudTtsBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务地址（留空使用官方地址）'**
  String get cloudTtsBaseUrl;

  /// No description provided for @cloudTtsModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get cloudTtsModel;

  /// No description provided for @cloudTtsApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key（编辑时留空保留）'**
  String get cloudTtsApiKey;

  /// No description provided for @cloudTtsVoice.
  ///
  /// In zh, this message translates to:
  /// **'音色 ID'**
  String get cloudTtsVoice;

  /// No description provided for @cloudTtsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'合成语速'**
  String get cloudTtsSpeed;

  /// No description provided for @cloudTtsFormat.
  ///
  /// In zh, this message translates to:
  /// **'音频格式'**
  String get cloudTtsFormat;

  /// No description provided for @cloudTtsStyle.
  ///
  /// In zh, this message translates to:
  /// **'风格'**
  String get cloudTtsStyle;

  /// No description provided for @cloudTtsInstructions.
  ///
  /// In zh, this message translates to:
  /// **'朗读指令'**
  String get cloudTtsInstructions;

  /// No description provided for @cloudTtsPreview.
  ///
  /// In zh, this message translates to:
  /// **'试听'**
  String get cloudTtsPreview;

  /// No description provided for @cloudTtsPreviewText.
  ///
  /// In zh, this message translates to:
  /// **'试听文本'**
  String get cloudTtsPreviewText;

  /// No description provided for @cloudTtsStop.
  ///
  /// In zh, this message translates to:
  /// **'停止试听'**
  String get cloudTtsStop;

  /// No description provided for @cloudTtsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无云端朗读引擎'**
  String get cloudTtsEmpty;

  /// No description provided for @cloudTtsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get cloudTtsEnabled;

  /// No description provided for @cloudTtsDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get cloudTtsDelete;

  /// No description provided for @cloudTtsDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此云端引擎及设备凭据？'**
  String get cloudTtsDeleteConfirm;

  /// No description provided for @cloudTtsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get cloudTtsSave;

  /// No description provided for @cloudTtsCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cloudTtsCancel;

  /// No description provided for @cloudTtsBook.
  ///
  /// In zh, this message translates to:
  /// **'本书'**
  String get cloudTtsBook;

  /// No description provided for @cloudTtsGlobal.
  ///
  /// In zh, this message translates to:
  /// **'全局'**
  String get cloudTtsGlobal;

  /// No description provided for @cloudTtsSample.
  ///
  /// In zh, this message translates to:
  /// **'你好，这是云端朗读试听。'**
  String get cloudTtsSample;

  /// No description provided for @cloudTtsProvider.
  ///
  /// In zh, this message translates to:
  /// **'服务商'**
  String get cloudTtsProvider;

  /// No description provided for @cloudTtsVoiceLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'音色目录加载失败'**
  String get cloudTtsVoiceLoadFailed;

  /// No description provided for @readAloudSplitMode.
  ///
  /// In zh, this message translates to:
  /// **'内容划分方式'**
  String get readAloudSplitMode;

  /// No description provided for @readAloudSplitParagraph.
  ///
  /// In zh, this message translates to:
  /// **'整段'**
  String get readAloudSplitParagraph;

  /// No description provided for @readAloudSplitSymbols.
  ///
  /// In zh, this message translates to:
  /// **'按符号'**
  String get readAloudSplitSymbols;

  /// No description provided for @readAloudSplitPage.
  ///
  /// In zh, this message translates to:
  /// **'整页'**
  String get readAloudSplitPage;

  /// No description provided for @readAloudSplitSymbolsTitle.
  ///
  /// In zh, this message translates to:
  /// **'划分标点'**
  String get readAloudSplitSymbolsTitle;

  /// No description provided for @readAloudSplitPageHint.
  ///
  /// In zh, this message translates to:
  /// **'整页朗读需要阅读器完成本章分页'**
  String get readAloudSplitPageHint;

  /// No description provided for @readAloudSplitSymbolsHint.
  ///
  /// In zh, this message translates to:
  /// **'连续标点保留在同一单元末尾'**
  String get readAloudSplitSymbolsHint;

  /// No description provided for @readAloudDefaultVoice.
  ///
  /// In zh, this message translates to:
  /// **'引擎默认音色'**
  String get readAloudDefaultVoice;

  /// No description provided for @readAloudPlayerInfoUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'音色与引擎信息暂不可用'**
  String get readAloudPlayerInfoUnavailable;

  /// No description provided for @readAloudNoEngine.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择朗读引擎'**
  String get readAloudNoEngine;

  /// 章内原文 UTF-16 位置，与朗读和阅读器使用同一坐标。
  ///
  /// In zh, this message translates to:
  /// **'原文位置 {current}/{total}'**
  String readAloudSourceProgress(int current, int total);

  /// No description provided for @readAloudTimerTimeMode.
  ///
  /// In zh, this message translates to:
  /// **'时间模式'**
  String get readAloudTimerTimeMode;

  /// No description provided for @readAloudTimerChapterMode.
  ///
  /// In zh, this message translates to:
  /// **'章节模式'**
  String get readAloudTimerChapterMode;

  /// No description provided for @readAloudTimerFinishChapter.
  ///
  /// In zh, this message translates to:
  /// **'到时后读完本章'**
  String get readAloudTimerFinishChapter;

  /// No description provided for @readAloudTimerFinishChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'倒计时结束后继续播放，到本章结束再停止。'**
  String get readAloudTimerFinishChapterHint;

  /// No description provided for @readAloudChapters.
  ///
  /// In zh, this message translates to:
  /// **'{chapters} 章'**
  String readAloudChapters(int chapters);

  /// No description provided for @readAloudCurrentChapter.
  ///
  /// In zh, this message translates to:
  /// **'当前章'**
  String get readAloudCurrentChapter;

  /// No description provided for @readAloudMediaButtons.
  ///
  /// In zh, this message translates to:
  /// **'通知和耳机前后按钮'**
  String get readAloudMediaButtons;

  /// No description provided for @readAloudMediaByChapter.
  ///
  /// In zh, this message translates to:
  /// **'切换章节'**
  String get readAloudMediaByChapter;

  /// No description provided for @readAloudMediaByParagraph.
  ///
  /// In zh, this message translates to:
  /// **'切换朗读段落'**
  String get readAloudMediaByParagraph;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
