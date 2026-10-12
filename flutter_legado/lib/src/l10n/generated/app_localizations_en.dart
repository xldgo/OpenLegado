// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Legado';

  @override
  String get bookshelf => 'Bookshelf';

  @override
  String get search => 'Search';

  @override
  String get sources => 'Sources';

  @override
  String get settings => 'Settings';

  @override
  String get my => 'Me';

  @override
  String get rss => 'RSS Feeds';

  @override
  String get discover => 'Discovery';

  @override
  String get confirm => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get noData => 'No data';

  @override
  String get retry => 'Retry';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get doubleClickExit => 'Press again to exit';

  @override
  String get bottomLine => 'That\'s all';

  @override
  String get startReading => 'Start Reading';

  @override
  String get addToBookshelf => 'Add to Bookshelf';

  @override
  String get removeFromBookshelf => 'Remove';

  @override
  String get updateToc => 'Update TOC';

  @override
  String get searchHint => 'Search by title or author';

  @override
  String get groupByNone => 'No Group';

  @override
  String get groupBySource => 'By Source';

  @override
  String get groupByTag => 'By Tag';

  @override
  String get updateAll => 'Update TOC';

  @override
  String get manageBookshelf => 'Bookshelf Management';

  @override
  String get sourceManagement => 'Sources Management';

  @override
  String get groupByNoneLabel => 'No Group';

  @override
  String get groupBySourceLabel => 'Group by Source';

  @override
  String get groupByGroupLabel => 'Group by Tag';

  @override
  String get listView => 'List View';

  @override
  String get gridView => 'Grid View';

  @override
  String get addBook => 'Add Book';

  @override
  String get addLocalBook => 'Add Local Book';

  @override
  String get emptyBookshelf =>
      'Bookshelf is empty, search or add from discover!';

  @override
  String get emptyBookshelfHint => '';

  @override
  String get loadingBookshelf => 'Loading bookshelf...';

  @override
  String get recentReading => 'Recent Reading';

  @override
  String get allBooks => 'All';

  @override
  String get reading => 'Reading';

  @override
  String get unread => 'Unread';

  @override
  String get unknownChapter => 'Unknown Chapter';

  @override
  String get pinToTop => 'Pin to Top';

  @override
  String get editInfo => 'Edit Info';

  @override
  String get group => 'Group';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String get confirmDeleteBook => 'Are you sure you want to delete';

  @override
  String get checkingUpdate => 'Checking for updates...';

  @override
  String get selectLocalBook => 'Select local book file';

  @override
  String get importSources => 'Import Sources';

  @override
  String get exportSources => 'Export Sources';

  @override
  String get addSource => 'Add Source';

  @override
  String get sourceName => 'Source Name';

  @override
  String get sourceUrl => 'Source URL';

  @override
  String get sourceType => 'Source Type';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get langSystem => 'Follow System';

  @override
  String get langChinese => '中文';

  @override
  String get langEnglish => 'English';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String get cloudSync => 'Cloud Sync';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get readingSettings => 'Reading Interface Settings';

  @override
  String get networkSettings => 'Network';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get otherSettings => 'Other';

  @override
  String get aboutSettings => 'About';

  @override
  String get defaultFontSize => 'Default Font Size';

  @override
  String get defaultLineHeight => 'Default Line Height';

  @override
  String get defaultBgColor => 'Default Background';

  @override
  String get whiteColor => 'White';

  @override
  String get proxySettings => 'Proxy Settings';

  @override
  String get noProxy => 'No Proxy';

  @override
  String get requestTimeout => 'Request Timeout';

  @override
  String get seconds30 => '30 seconds';

  @override
  String get secondsUnit => 's';

  @override
  String get backupData => 'Backup Data';

  @override
  String get backupDataDesc => 'Backup bookshelf and sources locally';

  @override
  String get restoreData => 'Restore Data';

  @override
  String get restoreDataDesc => 'Restore from backup file';

  @override
  String get clearCacheDesc => 'Clear temp files and cached data';

  @override
  String get selectTheme => 'Select Theme Mode';

  @override
  String get backupSuccess => 'Backup successful';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreSuccess => 'Restore successful';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get pasteBackupJson => 'Paste backup JSON data';

  @override
  String get confirmClearCache =>
      'Are you sure you want to clear all cached data?';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get version => 'Version';

  @override
  String get license => 'License';

  @override
  String get projectUrl => 'Project URL';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get autoSync => 'Auto Sync';

  @override
  String get autoSyncDesc => 'Periodically sync bookshelf data';

  @override
  String get syncSuccess => 'Sync successful';

  @override
  String get saveConfig => 'Save Config';

  @override
  String get configSaved => 'Config saved';

  @override
  String get uploadBookshelf => 'Upload Bookshelf';

  @override
  String get uploadBookshelfDesc => 'Upload local bookshelf to WebDAV';

  @override
  String get downloadBookshelf => 'Download Bookshelf';

  @override
  String get downloadBookshelfDesc =>
      'Download bookshelf from WebDAV to overwrite local';

  @override
  String get mergeSync => 'Merge Sync';

  @override
  String get mergeSyncDesc =>
      'Bidirectional merge of local and remote bookshelf';

  @override
  String get webdavServerUrl => 'WebDAV Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get remoteDir => 'Remote Directory';

  @override
  String get lastSync => 'Last sync';

  @override
  String get searchBookHint => 'Search by title, author...';

  @override
  String get searching => 'Searching...';

  @override
  String get noResults => 'No books found';

  @override
  String get noResultsHint =>
      'Try different keywords, or check if sources are enabled';

  @override
  String get searchBooks => 'Search Books';

  @override
  String get searchBooksHint => 'Enter a title or author to start searching';

  @override
  String get searchHistory => 'Search History';

  @override
  String get clearHistory => 'Clear';

  @override
  String get author => 'Author';

  @override
  String get source => 'Source';

  @override
  String get chapters => 'chapters';

  @override
  String get addedToBookshelf => 'Added to bookshelf';

  @override
  String get fontSize => 'Font Size';

  @override
  String get lineHeight => 'Line Height';

  @override
  String get flipMode => 'Flip Mode';

  @override
  String get scrollMode => 'Scroll';

  @override
  String get slideMode => 'Slide';

  @override
  String get simulateMode => 'Simulate';

  @override
  String get noneMode => 'None';

  @override
  String get coverMode => 'Cover';

  @override
  String get loadingChapter => 'Loading chapter...';

  @override
  String get noContent => 'No content';

  @override
  String get catalog => 'Catalog';

  @override
  String get nightMode => 'Night';

  @override
  String get readAloud => 'Read Aloud';

  @override
  String get interfaceSetting => 'Interface';

  @override
  String get readingSettingsTitle => 'Reading Settings';

  @override
  String get fontSizeLabel => 'Font Size';

  @override
  String get fontSmall => 'S';

  @override
  String get fontLarge => 'L';

  @override
  String get lineHeightLabel => 'Line Height';

  @override
  String get bgColor => 'Background';

  @override
  String get flipModeLabel => 'Flip Mode';

  @override
  String get previousChapter => 'Previous';

  @override
  String get nextChapter => 'Next';

  @override
  String get noChapters => 'No chapters';

  @override
  String get audioPlayer => 'Audio';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get prevChapterAudio => 'Previous';

  @override
  String get nextChapterAudio => 'Next';

  @override
  String get home => 'Home';

  @override
  String get help => 'Help';

  @override
  String get contentAndRules => 'Content and Rules';

  @override
  String get rssSourceManagement => 'RSS Source Management';

  @override
  String get sourceManagementSummary =>
      'Create, import, edit or manage book sources';

  @override
  String get rssSourceManagementSummary =>
      'Create, import, edit or manage RSS sources';

  @override
  String get txtTocRules => 'Text Catalog Rules';

  @override
  String get txtTocRulesSummary => 'Configure TXT chapter rules';

  @override
  String get replaceRules => 'Replacement Rules';

  @override
  String get replaceRulesSummary =>
      'Configure text replacement and cleanup rules';

  @override
  String get dictionaryLookup => 'Dictionary Lookup';

  @override
  String get dictionaryLookupSummary => 'Look up text using dictionary rules';

  @override
  String get dictionaryRules => 'Dictionary Rules';

  @override
  String get dictionaryRulesSummary =>
      'Add, edit, enable, sort or import dictionary rules';

  @override
  String get highlightRules => 'Highlight Rules';

  @override
  String get highlightRulesSummary => 'Automatic highlighting rules';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSummary => 'Theme colors and display mode';

  @override
  String get readingInterface => 'Reading Interface Settings';

  @override
  String get readingInterfaceSummary =>
      'Font, colors, page turning and screen display';

  @override
  String get syncAndServices => 'Sync and Services';

  @override
  String get webService => 'Web Service';

  @override
  String get mcpService => 'MCP Service';

  @override
  String get backupAndRestore => 'Backup and Restore';

  @override
  String get backupAndRestoreSummary =>
      'WebDAV settings and data import from older versions';

  @override
  String get cacheManagement => 'Cache Management';

  @override
  String get cacheManagementSummary => 'Book downloads and cache progress';

  @override
  String get scheduledTasks => 'Scheduled Tasks';

  @override
  String get scheduledTasksSummary => 'Manage scheduled JavaScript tasks';

  @override
  String get runScheduledTasks => 'Run Scheduled Tasks';

  @override
  String get runScheduledTasksSummary =>
      'Keep schedules after restart; Android may delay execution';

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedSummary => 'Additional feature settings';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get allBookmarks => 'All bookmarks';

  @override
  String get readingRecords => 'Read Record';

  @override
  String get readingRecordsSummary => 'Reading time records';

  @override
  String get fileManagement => 'File Management';

  @override
  String get fileManagementSummary =>
      'Manage files in the app’s private folder';

  @override
  String get exitApp => 'Exit';

  @override
  String get confirmExitApp => 'Exit Legado?';

  @override
  String get webServiceSummary => 'Write book sources or read in a browser';

  @override
  String get mcpServiceSummary =>
      'Token-protected book source development tools';

  @override
  String get mcpTokenRequired =>
      'Configure the Web book source access token first (Me → Advanced → Other Settings)';

  @override
  String get booksRead => 'Books Read';

  @override
  String get readingDuration => 'Reading Time';

  @override
  String get todayReadingGoal => 'Today\'s Reading Goal';

  @override
  String get minutesUnit => 'Minutes';

  @override
  String get readingHeatmap => 'Reading Heatmap';

  @override
  String get dailyReadingDuration => 'Daily Reading Time';

  @override
  String get editReadingGoal => 'Edit Goal';

  @override
  String get heatmapLess => 'Less';

  @override
  String get heatmapMore => 'More';

  @override
  String get heatmapBooksLegend => 'More (each cell shows books read that day)';

  @override
  String get selectAll => 'Select All';

  @override
  String get invertSelection => 'Invert Selection';

  @override
  String get more => 'More';

  @override
  String get remoteBooks => 'Remote Books';

  @override
  String get layoutSettings => 'Layout Settings';

  @override
  String get groupManagement => 'Group Management';

  @override
  String get addBookUrl => 'Add URL';

  @override
  String get selectionMode => 'Selection Mode';

  @override
  String get offlineCache => 'Offline Cache';

  @override
  String get exportBookList => 'Export Book List';

  @override
  String get importBookList => 'Import Book List';

  @override
  String get logs => 'Logs';

  @override
  String get layoutStyle => 'Layout';

  @override
  String get listLayout => 'List';

  @override
  String get groupStyle => 'Grouping';

  @override
  String get groupByGroup => 'By Book Group';

  @override
  String get emptyExportBookList =>
      'The bookshelf is empty. There is no book list to export.';

  @override
  String get noBooksToUpdate => 'No books need updating';

  @override
  String get preparing => 'Preparing...';

  @override
  String get bookUrlHint => 'Enter book detail URLs, one per line';

  @override
  String get bookNameOptionalHint =>
      'Book name (optional; used if details cannot be fetched)';

  @override
  String get bookListInputHint => 'Enter a book list URL or JSON array';

  @override
  String get chooseBookListFile => 'Choose File (txt/json)';

  @override
  String get importAction => 'Import';

  @override
  String get invalidBookList => 'Invalid book list. Enter a URL or JSON array.';

  @override
  String get exitSelection => 'Exit Selection';

  @override
  String get batchDownload => 'Batch Download';

  @override
  String get moveBookGroup => 'Move to Group';

  @override
  String get iosBookPickerHint =>
      'The iOS picker shows all files. Only ebook formats (epub/txt/mobi/azw3/azw/pdf/umd/cbz) can be imported.';

  @override
  String bookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String minuteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String hourCount(String hours) {
    return '$hours hours';
  }

  @override
  String secondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String hourMinuteCount(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String dailyDurationLoadFailed(String error) {
    return 'Failed to load daily reading time: $error';
  }

  @override
  String webServiceToggleFailed(String error) {
    return 'Failed to toggle Web service: $error';
  }

  @override
  String mcpServiceToggleFailed(String error) {
    return 'Failed to toggle MCP service: $error';
  }

  @override
  String mcpServicePort(int port) {
    return 'Port $port (token-protected book source development tools)';
  }

  @override
  String webKeepAliveUnavailable(String status) {
    return '$status · Background keep-alive unavailable; keep the app open';
  }

  @override
  String confirmDeleteSelectedBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the $count selected books?',
      one: 'Delete the selected book?',
    );
    return '$_temp0';
  }

  @override
  String deletedBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count books',
      one: 'Deleted 1 book',
    );
    return '$_temp0';
  }

  @override
  String gridColumnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Grid ($count columns)',
      one: 'Grid (1 column)',
    );
    return '$_temp0';
  }

  @override
  String selectedBookCount(int count) {
    return '$count selected';
  }

  @override
  String groupBookCount(int count) {
    return ' · $count total';
  }

  @override
  String importedBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count books',
      one: 'Imported 1 book',
    );
    return '$_temp0';
  }

  @override
  String importFailureMore(int count) {
    return ' and $count failed books';
  }

  @override
  String importBookFailed(String detail, String more) {
    return 'Import failed: $detail$more';
  }

  @override
  String localBookSaveFailed(String file, String error) {
    return '$file: failed to save local book ($error)';
  }

  @override
  String updatingBook(int index, int total, String book) {
    return 'Updating $index/$total: $book';
  }

  @override
  String bookTocUpdateFinished(int count, int total) {
    return 'Contents updated: $count/$total books succeeded';
  }

  @override
  String addBookUrlFinished(int success, int skipped, int failed) {
    return 'URLs added: $success succeeded, $skipped skipped, $failed failed';
  }

  @override
  String bookListImportFinished(int success, int skipped, int failed) {
    return 'Book list imported: $success succeeded, $skipped skipped, $failed failed';
  }

  @override
  String bookListReadFailed(String error) {
    return 'Failed to read book list file: $error';
  }

  @override
  String bookListFetchFailed(String error) {
    return 'Failed to fetch book list: $error';
  }

  @override
  String batchDownloadCount(int count) {
    return 'Batch download $count books';
  }

  @override
  String moveBookGroupCount(int count) {
    return 'Move $count books to a group';
  }

  @override
  String get localBooks => 'Local';

  @override
  String get audioBooks => 'Audio';

  @override
  String get videoBooks => 'Video';

  @override
  String get ungroupedOnlineBooks => 'Ungrouped Online Books';

  @override
  String get ungroupedLocalBooks => 'Ungrouped Local Books';

  @override
  String get defaultBookGroup => 'Default';

  @override
  String get collapseSidebar => 'Collapse Sidebar';

  @override
  String get expandSidebar => 'Expand Sidebar';

  @override
  String get bookshelfGroups => 'Bookshelf Groups';

  @override
  String bookGroupNumber(int number) {
    return 'Group $number';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get login => 'Log in';

  @override
  String get close => 'Close';

  @override
  String get clear => 'Clear';

  @override
  String get clearAction => 'Clear';

  @override
  String get notice => 'Notice';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoriteAction => 'Favorite';

  @override
  String get unfavoriteAction => 'Remove from favorites';

  @override
  String get favorited => 'Added to favorites';

  @override
  String get unfavorited => 'Removed from favorites';

  @override
  String get rssFavorites => 'RSS Favorites';

  @override
  String get ruleSubscriptions => 'Rule Subscriptions';

  @override
  String get filterDiscoverySources => 'Filter Discovery sources';

  @override
  String get emptyDiscoverySources => 'No Discovery sources';

  @override
  String get selectDiscoveryCategory => 'Select a Discovery category';

  @override
  String get selectDiscoveryCategoryHint =>
      'Expand a source on the left and select a category to browse books here';

  @override
  String get sourceRemoved => 'Source removed';

  @override
  String get sourcePinned => 'Source pinned to top';

  @override
  String get loginSuccess => 'Logged in';

  @override
  String get noCategories => 'No categories';

  @override
  String get noLoadedBooks => 'No books loaded';

  @override
  String get invalidArguments => 'Invalid parameters';

  @override
  String get missingDiscoveryCategory =>
      'Discovery category parameters are missing';

  @override
  String get filter => 'Filter';

  @override
  String get switchComfortableLayout => 'Switch to comfortable layout';

  @override
  String get switchCompactLayout => 'Switch to compact layout';

  @override
  String get loadedBooksFilterHint =>
      'Filter loaded books by title or author (case-insensitive)';

  @override
  String get filterKeywordHint => 'Keyword (leave blank to show all)';

  @override
  String get sourceLoginRequired => 'This source requires login';

  @override
  String get sourceLoginRequiredHint => 'Log in to browse this category';

  @override
  String get goToLogin => 'Log in';

  @override
  String get emptyBooks => 'No books yet';

  @override
  String get emptyCategoryBooksHint => 'No books found in this category';

  @override
  String get noFilteredBooks => 'No matching books';

  @override
  String get loadPreviousPageHint => 'Swipe up to load the previous page';

  @override
  String get tapToRetryLoad => 'Loading failed. Tap to retry';

  @override
  String get discoveryCategoriesLoadFailed =>
      'Failed to load Discovery categories';

  @override
  String get selectPage => 'Select a page';

  @override
  String get collapseSearch => 'Hide search';

  @override
  String get expandSearch => 'Show search';

  @override
  String get changeSource => 'Change source';

  @override
  String get deleteRssSource => 'Delete RSS source';

  @override
  String get loadingRssSources => 'Loading RSS sources...';

  @override
  String get emptyRssSources => 'No RSS sources yet';

  @override
  String get emptyGroupRssSources => 'No RSS sources in this group';

  @override
  String get noReadingRecords => 'No reading records';

  @override
  String get untitled => '(Untitled)';

  @override
  String get refreshSort => 'Refresh sorting';

  @override
  String get setSourceVariable => 'Set source variable';

  @override
  String get editSource => 'Edit source';

  @override
  String get switchLayout => 'Switch layout';

  @override
  String get loadingArticles => 'Loading articles...';

  @override
  String get emptyArticles => 'No articles yet';

  @override
  String get refreshArticlesHint =>
      'Pull down to refresh for the latest content';

  @override
  String get readArticle => 'Read';

  @override
  String get sourceVariableHint =>
      'Access the source variable in JavaScript with source.getVariable()';

  @override
  String get sourceVariableSaved => 'Source variable saved';

  @override
  String get confirmClearArticles =>
      'Clear the locally cached article list for this source?';

  @override
  String get articleCacheCleared => 'Article cache cleared for this source';

  @override
  String get unknownSource => 'Unknown source';

  @override
  String get loadingFavorites => 'Loading favorites...';

  @override
  String get emptyFavoriteArticles => 'No favorite articles yet';

  @override
  String get favoriteArticlesHint =>
      'Tap the star when browsing an RSS article to add it to favorites';

  @override
  String get articleDetails => 'Article details';

  @override
  String get switchToPlainText => 'Switch to plain text';

  @override
  String get switchToWebView => 'Switch to WebView';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get share => 'Share';

  @override
  String get viewOriginalInBrowser => 'View original in browser';

  @override
  String get webViewLoadFailed => 'WebView failed to load';

  @override
  String get webViewUnavailableHint =>
      'WebView is unavailable on this platform. Showing plain text instead';

  @override
  String get viewOriginalLink => 'View original link';

  @override
  String sourcePinFailed(String error) {
    return 'Failed to pin source: $error';
  }

  @override
  String addedToShelfCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count books to the bookshelf',
      one: 'Added 1 book to the bookshelf',
    );
    return '$_temp0';
  }

  @override
  String addToShelfFailed(String error) {
    return 'Failed to add to bookshelf: $error';
  }

  @override
  String activeKeywordFilter(String keyword) {
    return 'Filter (active: $keyword)';
  }

  @override
  String noLoadedBooksMatch(String keyword) {
    return 'No loaded books match “$keyword”';
  }

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String confirmDeleteNamedSource(String name) {
    return 'Delete “$name”?';
  }

  @override
  String cannotOpenLink(String url) {
    return 'Cannot open link: $url';
  }

  @override
  String confirmDeleteReadingRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count reading records?',
      one: 'Delete 1 reading record?',
    );
    return '$_temp0';
  }

  @override
  String sourceVariableSaveFailed(String error) {
    return 'Failed to save source variable: $error';
  }

  @override
  String layoutSaveFailed(String error) {
    return 'Failed to save layout: $error';
  }

  @override
  String clearFailed(String error) {
    return 'Failed to clear: $error';
  }

  @override
  String operationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String favoriteOperationFailed(String error) {
    return 'Favorite action failed: $error';
  }

  @override
  String get searchRssSources => 'Search RSS sources';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get loginRequired => 'Requires login';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get addRssSource => 'Add RSS source';

  @override
  String get importLocal => 'Import from file';

  @override
  String get importOnline => 'Import from URL';

  @override
  String get importQrCode => 'Import from QR code';

  @override
  String get importDefaultRules => 'Import default rules';

  @override
  String get enableSelected => 'Enable selected';

  @override
  String get disableSelected => 'Disable selected';

  @override
  String get addToGroup => 'Add to group';

  @override
  String get removeGroup => 'Remove group';

  @override
  String get pinSelected => 'Move selected to top';

  @override
  String get bottomSelected => 'Move selected to bottom';

  @override
  String get exportSelected => 'Export selected';

  @override
  String get shareSources => 'Share sources';

  @override
  String get selectRange => 'Select range';

  @override
  String get noMatchingRssSources => 'No matching RSS sources';

  @override
  String get addRssSourceHint =>
      'Choose Add RSS source from the top-right menu, or import RSS sources';

  @override
  String get moveToBottom => 'Move to bottom';

  @override
  String get deleteRssSources => 'Delete RSS sources';

  @override
  String get selectRssSourcesFirst => 'Select RSS sources first';

  @override
  String get selectedRssSourcesEnabled => 'Selected RSS sources enabled';

  @override
  String get selectedRssSourcesDisabled => 'Selected RSS sources disabled';

  @override
  String get selectedRssSourcesDeleted => 'Selected RSS sources deleted';

  @override
  String get selectedRssSourcesPinned => 'Selected RSS sources moved to top';

  @override
  String get selectedRssSourcesBottom => 'Selected RSS sources moved to bottom';

  @override
  String get groupNameHint => 'Enter a group name';

  @override
  String get noRemovableSourceGroups =>
      'Selected RSS sources have no groups to remove';

  @override
  String get selectTwoRssSourcesFirst => 'Select at least two RSS sources';

  @override
  String get invalidRssSources =>
      'Invalid format. No RSS sources could be parsed';

  @override
  String get importFinished => 'Import complete';

  @override
  String get filePathUnavailable => 'File path unavailable';

  @override
  String get invalidRssQrCode =>
      'The QR code does not contain recognized RSS source data';

  @override
  String get defaultRssSourcesSynced => 'Default RSS sources synced';

  @override
  String get importRssSourcesFromUrl => 'Import RSS sources from URL';

  @override
  String get rssSourceUrlHint => 'Enter an RSS source URL';

  @override
  String get history => 'History';

  @override
  String get importRssSources => 'Import RSS sources';

  @override
  String get customSourceGroup => 'Custom source group';

  @override
  String get keepSourceName => 'Keep existing names';

  @override
  String get keepSourceGroup => 'Keep existing groups';

  @override
  String get keepSourceEnabled => 'Keep enabled state';

  @override
  String get showSourceComment => 'Show source comments';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get importStatusNew => 'New';

  @override
  String get importStatusUpdated => 'Update';

  @override
  String get importStatusExisting => 'Existing';

  @override
  String get open => 'Open';

  @override
  String get addGroup => 'Add group';

  @override
  String get groupName => 'Group name';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get newGroupNameHint => 'Enter a new group name';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get emptyGroups => 'No groups yet';

  @override
  String get rename => 'Rename';

  @override
  String get customSourceGroupName => 'Enter a custom source group name';

  @override
  String get addGroupModeHint => 'Off: replace groups / On: add to groups';

  @override
  String get rssSourceNoun => 'RSS sources';

  @override
  String get bookSourceNoun => 'book sources';

  @override
  String get ruleNoun => 'rules';

  @override
  String sourceEnabledToggleFailed(String error) {
    return 'Failed to change enabled state: $error';
  }

  @override
  String deleteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String sortSaveFailed(String error) {
    return 'Failed to save sorting: $error';
  }

  @override
  String confirmDeleteRssSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count selected RSS sources?',
      one: 'Delete 1 selected RSS source?',
    );
    return '$_temp0';
  }

  @override
  String addedSourceGroup(String name) {
    return 'Added selected RSS sources to group “$name”';
  }

  @override
  String addGroupFailed(String error) {
    return 'Failed to add group: $error';
  }

  @override
  String removedSourceGroup(String name) {
    return 'Removed selected RSS sources from group “$name”';
  }

  @override
  String removeGroupFailed(String error) {
    return 'Failed to remove group: $error';
  }

  @override
  String exportedRssSourcesToClipboard(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported $count RSS sources to clipboard',
      one: 'Exported 1 RSS source to clipboard',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String shareRssSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Share $count RSS sources',
      one: 'Share 1 RSS source',
    );
    return '$_temp0';
  }

  @override
  String shareFailed(String error) {
    return 'Sharing failed: $error';
  }

  @override
  String importFromFileFailed(String error) {
    return 'Failed to import from file: $error';
  }

  @override
  String fetchRssSourcesFailed(String error) {
    return 'Failed to fetch RSS sources: $error';
  }

  @override
  String importedDefaultRssSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count default RSS sources',
      one: 'Imported 1 default RSS source',
    );
    return '$_temp0';
  }

  @override
  String importDefaultRulesFailed(String error) {
    return 'Failed to import default rules: $error';
  }

  @override
  String rssSourceImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String selectAllCount(int selected, int total) {
    return 'Select all ($selected/$total)';
  }

  @override
  String deselectAllCount(int selected, int total) {
    return 'Deselect all ($selected/$total)';
  }

  @override
  String groupAlreadyExists(String name) {
    return 'Group “$name” already exists';
  }

  @override
  String noUngroupedItems(String noun) {
    return 'No ungrouped $noun to add to this group';
  }

  @override
  String confirmDeleteItemGroup(String name, String noun) {
    return 'Delete group “$name”? Its $noun will be removed from this group.';
  }

  @override
  String get readAloudSettingsTitle => 'Read-aloud settings';

  @override
  String get readAloudPlaybackGroup => 'Playback and controls';

  @override
  String get readAloudFollowSystem => 'Use default speech rate';

  @override
  String get readAloudFollowSystemSummary =>
      'Use the default rate. Turn off to adjust speech speed.';

  @override
  String get readAloudSpeed => 'Speech rate';

  @override
  String get readAloudParagraphInterval => 'Pause between paragraphs';

  @override
  String get readAloudSecondsUnit => 's';

  @override
  String get readAloudVoiceGroup => 'Engines and voices';

  @override
  String get readAloudEngines => 'Speech engines';

  @override
  String get readAloudEnginesSummary => 'Manage system and HTTP speech engines';

  @override
  String get readAloudSystemVoice => 'System voice';

  @override
  String get readAloudSystemVoiceSummary =>
      'Choose a device engine and an installed voice';

  @override
  String get readAloudSystemAdjustmentGroup => 'System speech adjustments';

  @override
  String get readAloudPitch => 'Pitch';

  @override
  String get readAloudVolume => 'Volume';

  @override
  String readAloudSaveFailed(String error) {
    return 'Could not save read-aloud settings: $error';
  }

  @override
  String get readAloudPlayer => 'Read-aloud player';

  @override
  String get readAloudChapterText => 'Text';

  @override
  String get readAloudClassicPanel => 'Return to classic panel';

  @override
  String get readAloudPreviousParagraph => 'Previous paragraph';

  @override
  String get readAloudNextParagraph => 'Next paragraph';

  @override
  String get readAloudTextUnavailable =>
      'Start reading aloud to display the chapter text';

  @override
  String readAloudParagraphProgress(int current, int total) {
    return 'Paragraph $current/$total';
  }

  @override
  String get readAloudTimer => 'Sleep timer';

  @override
  String readAloudMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get readAloudCustomMinutes => 'Custom minutes';

  @override
  String readAloudTimerRange(int max) {
    return 'Enter 1–$max minutes';
  }

  @override
  String get readAloudStopAfterChapter => 'Stop after this chapter';

  @override
  String get readAloudCancelTimer => 'Cancel timer';

  @override
  String readAloudControlFailed(String error) {
    return 'Read-aloud control failed: $error';
  }

  @override
  String get readAloudStop => 'Stop reading aloud';

  @override
  String get readAloudCapsuleGroup => 'Playback capsule';

  @override
  String get readAloudCapsuleAutoCollapse => 'Auto-collapse capsule';

  @override
  String get readAloudCapsuleAutoCollapseSummary =>
      'Collapse to the cover after 3 seconds of inactivity';

  @override
  String get readAloudDetachReminder => 'Keep speaking when browsing';

  @override
  String get readAloudDetachReminderSummary =>
      'Browse without interrupting speech, then return to the spoken passage. When off, speech follows your reading position.';

  @override
  String get readAloudReturnToPosition => 'Go to speaking page';

  @override
  String get readAloudFromThisPage => 'Read from this page';

  @override
  String get readerMenuTheme => 'Menu colors';

  @override
  String get readerMenuFollowApp => 'Follow app';

  @override
  String get readerMenuFollowBackground => 'Follow reading background';

  @override
  String get readerMenuCustom => 'Custom';

  @override
  String get readerMenuPalette => 'Menu palette style';

  @override
  String get readerMenuTonalSpot => 'Tonal spot';

  @override
  String get readerMenuNeutral => 'Neutral';

  @override
  String get readerMenuVibrant => 'Vibrant';

  @override
  String get readerMenuExpressive => 'Expressive';

  @override
  String get readerMenuFidelity => 'Fidelity';

  @override
  String get readerMenuContent => 'Content';

  @override
  String get readerMenuRainbow => 'Rainbow';

  @override
  String get readerMenuFruitSalad => 'Fruit salad';

  @override
  String get readerMenuMonochrome => 'Monochrome';

  @override
  String get readerMenuColorMode => 'Custom color mode';

  @override
  String get readerMenuSeedOnly => 'Generate from accent';

  @override
  String get readerMenuManual => 'Set individual colors';

  @override
  String get readerMenuEditingMode => 'Edit colors for';

  @override
  String get readerMenuDay => 'Light mode';

  @override
  String get readerMenuNight => 'Dark mode';

  @override
  String get readerMenuAccent => 'Menu accent';

  @override
  String get readerMenuBackground => 'Menu background';

  @override
  String get readerMenuContainer => 'Popup background';

  @override
  String get readerMenuTitleColor => 'Top bar text color';

  @override
  String get readerMenuColorDefault => 'Default';

  @override
  String get readerMenuColorHex => 'Hex color';

  @override
  String get readerMenuColorInvalid => 'Enter a 6- or 8-digit hex color';

  @override
  String get eyeProtection => 'Eye comfort';

  @override
  String get eyeProtectionEnabled => 'Enable eye comfort';

  @override
  String get eyeProtectionEnabledSummary =>
      'Apply a warm color filter without changing saved colors';

  @override
  String get eyeProtectionAutoNight => 'Follow dark mode';

  @override
  String get eyeProtectionIntensity => 'Filter intensity';

  @override
  String get eyeProtectionSchedule => 'Schedule';

  @override
  String get eyeProtectionScheduleSummary =>
      'Apply only during the selected hours, including overnight';

  @override
  String get eyeProtectionStartTime => 'Start time';

  @override
  String get eyeProtectionEndTime => 'End time';
}
