// [UI-fix v2.0.5 | 2026-08-08] 偏好键常量：对齐原版 PreferKey/preference key，
// 便于后续行为接线与数据迁移（主题设置页 + 其他设置页） — Qoder

/// 原版偏好键常量（io.legado.app.constant.PreferKey 子集 + preference XML key）
///
/// 命名与原版完全一致，值即 SharedPreferences 键名。
/// 仅收录本次"主题设置页/其他设置页"对齐涉及的键，其余键仍在各自服务内维护。
class PrefKeys {
  PrefKeys._();

  /// 恢复忽略策略，保持原单个JSON存储键并始终排除备份。
  static const restoreIgnore = 'restoreIgnore';

  // ===== 主题设置页（pref_config_theme.xml）=====

  /// 启动图标（仅 Android 生效，原版 launcherIcon）
  static const launcherIcon = 'launcherIcon';

  /// 导航栏阴影高度（原版 barElevation，0~32）
  static const barElevation = 'barElevation';

  /// 底部操作栏皮肤跟随背景（仅 Android 生效）
  static const bottomBarSkin = 'bottomBarSkin';

  /// 使用壁纸取色（Android 12+/iOS 动态色均可用——R1 接通 dynamic_color；
  /// 默认 false）
  static const wallpaperColorFollow = 'wallpaperColorFollow';

  /// 壁纸变化时自动更新取色（仅 Android 生效，默认 true）
  static const wallpaperColorAutoUpdate = 'wallpaperColorAutoUpdate';

  /// 日间主色调（ARGB int）
  static const cPrimary = 'colorPrimary';

  /// 日间强调色（ARGB int）
  static const cAccent = 'colorAccent';

  /// 日间背景色（ARGB int）
  static const cBackground = 'colorBackground';

  /// 日间底部操作栏颜色（ARGB int）
  static const cBBackground = 'colorBottomBackground';

  /// 夜间主色调（ARGB int）
  static const cNPrimary = 'colorPrimaryNight';

  /// 夜间强调色（ARGB int）
  static const cNAccent = 'colorAccentNight';

  /// 夜间背景色（ARGB int）
  static const cNBackground = 'colorBackgroundNight';

  /// 夜间底部操作栏颜色（ARGB int）
  static const cNBBackground = 'colorBottomBackgroundNight';

  /// 日间背景图片路径
  static const bgImage = 'backgroundImage';

  /// 夜间背景图片路径
  static const bgImageN = 'backgroundImageNight';

  // ===== UI 布局同步重构开关族（UI_SYNC_REFACTOR_PLAN_20260905.md，
  // key 名对齐参考仓 PreferKey，经 SharedPreferences 透存，Rust 不解释）=====

  /// 顶栏按钮样式：plain/tonal/outlined/glass/liquidGlass（参考仓默认 tonal）
  static const topBarButtonStyle = 'topBarButtonStyle';

  /// 顶栏按钮合并进胶囊容器（参考仓 mergeTopBarActions，默认 false）
  static const mergeTopBarActions = 'mergeTopBarActions';

  /// 使用 MediumFlexible 大顶栏形态（参考仓 useFlexibleTopAppBar，默认 true）
  static const useFlexibleTopAppBar = 'useFlexibleTopAppBar';

  /// 顶栏普通背景不透明度 0–1 double，默认 1
  static const topBarBackgroundOpacity = 'topBarBackgroundOpacity';

  /// 底栏 label 显示档位：auto/labeled/unlabeled（参考仓默认 auto）
  static const labelVisibilityMode = 'labelVisibilityMode';

  /// 底栏普通背景不透明度 0–1 double，默认 1
  static const bottomBarBackgroundOpacity = 'bottomBarBackgroundOpacity';

  /// 悬浮底栏（参考仓 useFloatingBottomBar，默认关）
  static const useFloatingBottomBar = 'useFloatingBottomBar';

  /// 悬浮底栏液态玻璃，默认关闭。
  static const useFloatingBottomBarLiquidGlass =
      'useFloatingBottomBarLiquidGlass';

  /// 显示底栏（参考仓 showBottomView，默认开）
  static const showBottomView = 'showBottomView';

  /// 平板/大屏导航形态：auto/always/landscape/off（参考仓默认 auto）
  static const tabletInterface = 'tabletInterface';

  /// 详情页跟随封面取色换肤（参考仓 bookInfoFollowCoverColor，默认开）
  static const bookInfoFollowCoverColor = 'bookInfoFollowCoverColor';

  /// 详情页网络封面背景三档：off/off_for_default/on（参考仓默认 on）
  static const bookInfoNetworkCoverBackground =
      'bookInfoNetworkCoverBackground';

  /// 详情页默认封面背景三档（参考仓默认 on）
  static const bookInfoDefaultCoverBackground =
      'bookInfoDefaultCoverBackground';

  /// 覆写基础卡片圆角（参考仓 overrideBaseCardCornerRadius，默认关）
  static const overrideBaseCardCornerRadius = 'overrideBaseCardCornerRadius';

  /// 基础卡片圆角值 4-28（参考仓 baseCardCornerRadius，默认 16）
  static const baseCardCornerRadius = 'baseCardCornerRadius';

  /// 启用毛玻璃（参考仓 enableBlur，默认关——低端机掉帧保护）
  static const enableBlur = 'enableBlur';

  /// 顶栏模糊 sigma，逻辑像素 double，默认 24
  static const topBarBlurSigma = 'topBarBlurSigma';

  /// 顶栏模糊底色不透明度 0–1 double，默认 0.73
  static const topBarBlurTintOpacity = 'topBarBlurTintOpacity';

  /// 底栏模糊 sigma，逻辑像素 double，默认 8
  static const bottomBarBlurSigma = 'bottomBarBlurSigma';

  /// 底栏模糊底色不透明度 0–1 double，默认 0.40
  static const bottomBarBlurTintOpacity = 'bottomBarBlurTintOpacity';

  /// 设置行分隔线开关（参考仓 enableItemDivider，默认关）
  static const enableItemDivider = 'enableItemDivider';

  /// 大屏侧栏展开态持久化（参考仓 navExtended）
  static const railExtended = 'railExtended';

  /// 主题引擎 paletteStyle（参考仓 paletteStyle，'none'=关闭参数化）
  static const themeStyle = 'themeStyle';

  /// 主题引擎对比度（参考仓 customContrast，'0.0'/'0.5'/'1.0'）
  static const themeContrastLevel = 'themeContrastLevel';

  /// AMOLED 纯黑（参考仓 pure_black/isAmoled，默认关）
  static const themeAmoled = 'themeAmoled';

  // ===== 封面设置（pref_config_cover.xml）=====

  /// 仅 Wifi 加载封面（默认 false）
  static const loadCoverOnlyWifi = 'loadCoverOnlyWifi';

  /// 优先使用默认封面（默认 false）
  static const useDefaultCover = 'useDefaultCover';

  /// 默认封面显示书名（默认 true）
  static const coverShowName = 'coverShowName';

  /// 默认封面显示作者（默认 true）
  static const coverShowAuthor = 'coverShowAuthor';

  // ===== 其他设置页（pref_config_other.xml）=====

  /// 启动时自动刷新书架（默认 false）
  static const autoRefreshBook = 'auto_refresh';

  /// 仅更新已读书籍（默认 false，依赖 auto_refresh 可见）
  static const onlyUpdateRead = 'onlyUpdateRead';

  /// 冷启动默认进入上次阅读（默认 false；对齐上游 OtherSettings.defaultToRead）
  static const defaultToRead = 'defaultToRead';

  /// 显示发现（默认 true）
  static const showDiscovery = 'showDiscovery';

  /// 显示订阅/RSS（默认 true）
  static const showRss = 'showRss';

  /// 默认首页（bookshelf/explore/rss/my）
  static const defaultHomePage = 'defaultHomePage';

  /// 本地密码（用于 Web 服务鉴权）
  static const localPassword = 'localPassword';

  /// 浏览器标识 UserAgent
  static const userAgent = 'userAgent';

  /// Web 服务唤醒锁（仅 Android 生效，默认 false）
  static const webServiceWakeLock = 'webServiceWakeLock';

  /// 默认书籍保存位置
  static const defaultBookTreeUri = 'defaultBookTreeUri';

  /// 源编辑框最大行数（默认 99）
  static const sourceEditMaxLine = 'sourceEditMaxLine';

  /// 图片抗锯齿（默认 false）
  static const antiAlias = 'antiAlias';

  /// 图片解码缓存大小 MB（默认 50，1~1024）
  static const bitmapCacheSize = 'bitmapCacheSize';

  /// 图片文件保留数量（默认 100，0~999）
  static const imageRetainNum = 'imageRetainNum';

  /// 当前章之后的预下载章数（默认10，0～100）。
  static const preDownloadNum = 'preDownloadNum';

  /// 当前章之前的预下载章数（默认0，0～100）。
  static const preDownloadNumPrev = 'preDownloadNumPrev';

  /// 新增书籍默认启用替换净化（默认 true）
  static const replaceEnableDefault = 'replaceEnableDefault';

  /// 退出应用时中断朗读（媒体按钮，仅 Android 生效，默认 true）
  static const mediaButtonOnExit = 'mediaButtonOnExit';

  /// 媒体按钮触发朗读（仅 Android 生效，默认 false）
  static const readAloudByMediaButton = 'readAloudByMediaButton';

  /// 朗读时忽略音频焦点（仅 Android 生效，默认 false）
  static const ignoreAudioFocus = 'ignoreAudioFocus';

  /// 自动清除过期搜索数据（默认 true）
  static const autoClearExpired = 'autoClearExpired';

  /// 显示添加书架提示（默认 true）
  static const showAddToShelfAlert = 'showAddToShelfAlert';

  /// 自动更新到最佳变种版本（仅 Android 生效，默认 true）
  static const autoUpdateVariant = 'autoUpdateVariant';

  /// 显示漫画界面（默认 true）
  static const showMangaUi = 'showMangaUi';

  /// Web 服务端口（默认 1122，1024~60000）
  static const webPort = 'webPort';

  /// 更新书籍并发数（默认 16，1~999）
  static const threadCount = 'threadCount';

  /// 文本操作菜单显示应用（仅 Android 生效，默认 true）
  static const processText = 'process_text';

  // [UI-fix v2.0.5 | 2026-08-08] 注：以下三个日志键与 Android 原版
  // AppConfig 同名，但当前桌面端日志开关真源为 CrashLogService
  // （crash_record_* 键），本组键预留未来对齐 Android AppConfig 用，
  // 暂未接线，请勿与 CrashLogService 键名双轨混用 — Qoder

  /// 记录日志（预留键，暂未接线；当前真源为 CrashLogService 的
  /// crash_record_log 键）
  static const recordLog = 'recordLog';

  /// 记录 HTTP 请求日志（预留键，暂未接线；当前真源为 CrashLogService
  /// 的 crash_record_http_log 键）
  static const recordHttpLog = 'recordHttpLog';

  /// 记录内存堆转储（预留键，暂未接线；当前真源为 CrashLogService
  /// 的 crash_record_heap_dump 键）
  static const recordHeapDump = 'recordHeapDump';

  // ===== 书架管理（BookshelfManageActivity）=====

  /// 点击书名打开书籍信息（对齐原版 openBookInfoByClickTitle，默认 false）
  static const openBookInfoByClickTitle = 'openBookInfoByClickTitle';

  // ===== 检查更新（LocalConfig）=====

  /// 忽略的更新版本号（对齐 LocalConfig.ignoreUpdateVersion）
  static const ignoreUpdateVersion = 'ignoreUpdateVersion';

  // ===== 备份与恢复（pref_config_backup.xml）=====

  /// 本地备份仅保留最新备份文件（默认 true）
  static const onlyLatestBackup = 'onlyLatestBackup';

  /// 打开软件时自动检查新备份（默认 true）
  static const autoCheckNewBackup = 'autoCheckNewBackup';
}
