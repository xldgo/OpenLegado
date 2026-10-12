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
