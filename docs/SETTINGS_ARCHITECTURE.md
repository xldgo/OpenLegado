# OpenLegado 设置分类与访问架构方案

本方案以 `feature/ui-reader-selection` 的 `423921865` 为本地基线，参考
HapeLee/legado-with-MD3 的 `60a7cca34dd3e0be456e0f05c10c036c64b70e35`。
本文保存职责划分、字段归属、迁移方法与验收标准；实施授权、当前任务与验证结果
只维护在 [活动计划](REFACTORING_ACTIVE_PLAN.md)。第6节保留历史基线盘点，
第10～23节说明普通偏好、阅读分组与旧服务清理边界；后续按第7节的领域顺序推进。

## 1. 设计目标

每项设置有一个明确的业务归属、持久化写入入口和实际消费路径。设置页可以组合
多个领域，但页面名称不决定数据层职责。分类完成后，按领域迁移现有读写；功能
没有接线的选项单独登记，保留原说明和值，追加“待实现”并禁用。

当前未发布快速开发阶段，后续迁移直接使用目标模型和规范键名，不默认增加旧数据
迁移、旧键双读、绝对路径自愈或长期兼容入口；该口径由用户在2026-10-15明确。
新增偏好键采用业务前缀与lower_snake_case，Dart成员采用lowerCamelCase；这是项目
对存储字符串的约定，不是Flutter对字符串键的官方强制要求。保持现有功能、默认值
和应用版本；复用已经建立的 AppSettingsStore、
AppSettingsService、类型化 Repository 与 Riverpod 装配。分类不要求修改数据库、
Rust/FRB、设置页布局或已可用的阅读、朗读功能。

## 2. 三种划分各自回答的问题

| 维度 | 回答的问题 | 示例 |
|---|---|---|
| 业务域 | 谁解释、修改和消费这项设置 | 耳机控制属于朗读，UserAgent 属于下载与网络 |
| 数据性质 | 如何保存及管理生命周期 | 普通偏好、结构化配置、实体、凭据、临时状态 |
| 功能状态 | 设置是否真实影响行为 | 已接线、未接线、受平台限制、待核验 |

同一设置页允许引用多个领域接口；同一个领域也可以出现在多个页面。字段归属
只登记一次，其他领域通过公共接口读取或在 UI 中派生展示快照，不能维护另一份
独立权威值。同一地址指“存储类型 + 实际存储键”，不能只比较 Dart 常量名称。

## 3. 业务分类与现有接口

| 业务分类 | 访问入口 | 本轮设计取舍 |
|---|---|---|
| 应用入口与语言 | HomeSettingsRepository、LocaleSettingsRepository、WelcomeSettingsRepository | 保留已迁移接口；默认首页、显隐、语言及欢迎配置不重复分配 |
| 外观与界面 | AppearanceSettingsRepository、ThemeColorsSettingsRepository、UiSettingsRepository、SystemBarSettingsRepository、EyeProtectionSettingsRepository | 保留现有拆分；按配色、界面几何、系统栏和护眼各自订阅，不合并成全局大对象 |
| 书架与阅读记录 | BookshelfSettingsRepository、ReadRecordSettingsRepository | 保留列表、分组、记录偏好的唯一来源；书籍和记录实体仍用各自业务 Repository |
| 阅读设置 | ReaderSettingsRepository | 统一普通阅读偏好和不可变分组；样式与字体目录保留专用仓储，不保留旧高级配置副本 |
| 朗读与媒体 | ReadAloudSettingsRepository | 现有七项保持，新增内容划分方式及符号集合；耳机控制、退出控制和音频焦点拟归此域，功能接线状态独立核验 |
| 搜索与书源校验 | SearchSettingsRepository、现有校验配置入口 | 已迁移搜索参数保留；校验规则及校验会话保持原独立边界 |
| 下载、缓存与请求 | 拟新增 DownloadCacheSettingsRepository | 管理图片缓存、正文预下载、相关并发和 UserAgent 等普通偏好 |
| 备份策略 | BackupSettingsRepository | 首批管理备份目录和有效进度同步开关；连接凭据、恢复集合及未接线策略维持专用边界 |
| 应用行为与诊断 | GeneralSettingsRepository | 首批管理默认导出位置、返回入架提醒、Web 端口；其余字段按实际功能逐步接入 |
| 隐私与凭据 | 现有 PrivacyController、PrivacyCredentialRepository 及书源/TTS 登录接口 | 普通验证策略、凭据与临时解锁分别管理；不因设置页迁移而重做认证或改变凭据格式 |

本方案预留三个普通偏好仓储；名称表示业务职责，不照搬上游 Gateway 命名。
现有接口已经有实际消费者，因此保留它们，不为了统一命名重新移动整仓目录。
按第 6 节的实际盘点，General 与 Backup 已有可迁移消费者；DownloadCache 的
已定位字段均未接线，先保留值并禁用相应行，随功能落地再建立有效访问入口，
不为了分类表完整而先创建没有实际消费者的仓储。

阅读入口使用ReaderSettingsRepository，与其他领域设置接口保持一致。接口、数据实现、
Provider、文件名、消费者和测试统一使用AppReaderSettingsRepository与
readerSettingsRepositoryProvider；ReaderConfigRepository旧名称及转发接口不保留。
ReaderSettings表达同源普通偏好，按正文排版、页面几何、屏幕状态、操作、自动翻页、
菜单配色及亮度控件组织不可变分组；样式与字体文件目录各用专用仓储。
ReaderAdvancedConfig及loadAdvanced/saveAdvanced、独立Provider和整份保存路径均已
删除，当前分组和规范键见第11～22节，不把历史B1清单当作仍在运行的旧入口。

GeneralSettings 是有范围的应用偏好集合，并不对应“其他设置”页面的全部内容。
耳机控制、缓存、备份、语言和主题等有明确归属的字段不能放入这个集合。默认
文件位置和返回入架提示可先保留为应用行为，避免为单个字段新增完整仓储；若
以后出现独立的文件/阅读行为模型和多个相关消费者，再成组提取。

上游也保留较宽的 OtherSettings，本方案采用其按域访问的方向，并结合当前
OpenLegado 的实际接口确定分组；内部类划分不要求一对一复制。

## 4. 数据性质与存储边界

| 数据性质 | 本项目例子 | 管理方式 |
|---|---|---|
| 普通标量偏好 | 开关、数字、枚举编码、单个路径、颜色覆盖 | 类型化 Repository 经共享 AppSettingsService 访问原 Preferences 或 Rust config: 存储 |
| 结构化配置或配置集合 | 阅读点击动作列表、主题预设列表、远程连接列表 | 专用 Repository 负责完整格式、读改写和集合操作；保持原格式 |
| 持久化业务实体 | 书籍、书源、书签、阅读记录、HTTP/云 TTS 引擎 | 现有业务 Repository 与 Rust SQLite，不放入普通偏好快照 |
| 凭据 | 密码、Token、登录 Header/Cookie、隐私验证材料 | 现有凭据接口；普通设置模型不复制敏感内容 |
| 临时状态 | 弹层显隐、输入草稿、播放进度、解锁授权、加载错误 | 相应 UI/会话持有，按生命周期释放 |

AppSettingsStore 接受String、bool、int、double、null及SettingsStringList；null表示删除原键。
不为迁移阅读点击动作列表而把原 StringList 改成 JSON，也不把可变集合直接塞进
共享快照。SettingsStringList复制并冻结字符串列表，读入的StringList也先冻结，再放入
已保存基底；Preferences适配仍用setStringList落盘。共享服务拒绝直接写入可变List。
动作列表的完整格式由ReaderSettingsRepository及其Codec拥有；其他结构化集合继续由
专用仓储管理，标量字段与集合字段各自的键不能出现重叠写入。九宫格接线见第20节。

日志继续使用 `crash_record_log`、`crash_record_http_log`、`crash_record_heap_dump`
现有键；PrefKeys 中的 `recordLog` 等预留键不是新的持久化来源。
朗读普通偏好原先使用 Rust config:，归类后仍使用这些原地址。内容划分新增 `contentSplitMode`（paragraph/symbols/page）和 `contentSplitSymbols`（合法符号的JSON数组），同样由ReadAloudSettingsRepository读写；默认整段，空符号集合回退句末标点，页面范围是当前阅读器布局数据，不作为持久化设置。

## 5. 访问、状态与运行时应用

```text
设置页 / 实际功能消费者
          ↓
Notifier、Controller 或交互编排
          ↓
领域 SettingsRepository（纯模型、原键编码和默认值）
          ↓
AppSettingsService（IO、串行写入、加载与重读）
          ├── AppSettingsStore（内存快照、订阅、失败回退）
          └── SettingsStorage（原 Preferences / Rust config:）
```

普通偏好仓储沿用当前契约形态：`current`、`watch()`、`load()`、字段更新及
`reload()`；更新返回 Future，保存错误传到页面。仓储从共享快照解码，不再
维护独立已保存缓存、存储实例或普通偏好写队列。加载错误、保存等待和编辑草稿
属于界面状态，不进入持久化领域模型。

修改尽量提交用户实际修改的字段，不使用尚未加载的默认完整对象覆盖其他键。
集合的完整读改写可以保留专用协调机制；它与普通标量写队列的职责不同。
多键更新沿用当前逐项保存语义：已成功字段保留，失败和未保存字段回退，调用方
收到失败。不能将现有流程描述为整批事务。

保存偏好与应用到平台/运行时分开处理。例如更换服务端口、调整缓存容量或修改
音频焦点，需要由对应服务/控制器消费设置；通用 AppSettingsService 不负责启动
服务器、控制播放器或设置原生图标。保存失败不能提示成功；已保存但运行时应用
失败时明确报告应用失败，不能伪称偏好已整体回滚。

Rust/JS 所需的主题和阅读配置由现有 Bootstrap/配置注入层生成同源快照，保持
原字段和值；UI 不额外维护一套专供 Rust 的偏好。若后续确需改变 FFI 参数或
添加能力，先在 API_CONTRACT 冻结边界，再开展对应实现任务。

恢复备份后通过仓储 reload 重读实际存储，再通知消费者；重建 Notifier 本身
不能代替刷新共享快照。单域刷新失败独立报告，不阻断其他已授权域。

## 6. 分类清单的记录方式

先完成代码盘点，再生成以下字段的逐项清单。清单放在本文的后续清单章节，
Active 只登记任务状态，不在多个文件维护相互竞争的进度表。

| 字段 | 内容 |
|---|---|
| 用户可见名称 | 当前标题及原说明 |
| 设置项与业务域 | 稳定名称、所属类型化接口 |
| 原存储协议 | 存储类型、真实键、值类型、默认值与单位 |
| 写入所有者 | 唯一持久化入口，以及迁移前需要替换的调用点 |
| 消费路径 | 保存值如何到达真实页面、Rust 或平台服务 |
| 数据性质 | 标量偏好、结构化配置、实体、凭据或临时状态 |
| 功能证据 | 已接线、未接线、平台限制或待核验，附具体代码位置 |
| 处理建议 | 保留并迁移、禁用待实现、保持专用边界或确认失效后清理 |

查找时同时覆盖常量、直接字符串、专用 getter/setter、配置注入和原生调用。
命名搜索只帮助定位，功能状态以“保存 → 实际消费”的调用链为依据。
对普通偏好，读取设置页展示值不算业务消费；对凭据，认证时读取属于有效消费。

### 6.1 本地清单范围与证据口径

以下清单对应本地基线 `423921865`，覆盖 B1 指定的其他设置、WebDAV 设置、外观
剩余入口、基础/高级阅读设置及 SettingsService 的 69 个公开异步方法。字体、视频
及远程连接作为这些入口的相邻边界登记，不据此宣称全仓所有功能设置已穷尽。
此前已迁移的十二类普通偏好沿用第 3 节归属，不在此重抄其完整键表。

表中的名称为功能简称；原标题和说明以所链接的现有界面源码为准，后续禁用时
保留原说明并追加“待实现”。`已接线`只表示代码调用链存在，不代表本轮进行过
设备回归；`未接线`表示仅见设置展示/保存、备份搬运或无调用方的方法，没有
消费该值的生产路径。原存储值仍保留，不能按功能状态删除用户数据。

证据入口如下，表中使用简称引用这些文件及其中的方法：

| 简称 | 源码及核对范围 |
|---|---|
| 其他页 | [OtherSettingsScreen](../flutter_legado/lib/src/screens/other_settings_screen.dart)：`_loadSettings`、各字段回调及端口/Hosts/Token 对话框 |
| 旧服务 | [SettingsService](../flutter_legado/lib/src/services/settings_service.dart)：真实键、默认值、读写结果与方法调用方 |
| 日志 | [CrashLogService](../flutter_legado/lib/src/services/crash_log_service.dart)：开关、`putDebug`、`logHttp`、`logMessage`、备份路径 |
| 同步 | [SyncNotifier](../flutter_legado/lib/src/providers/sync/sync_notifier.dart) 与 [WebDavSettingsScreen](../flutter_legado/lib/src/screens/webdav_settings_screen.dart)：连接、进度开关、备份/恢复、同步时间 |
| 外观 | [ThemeConfigScreen](../flutter_legado/lib/src/features/appearance/theme_config_screen.dart) 与 [LauncherIconService](../flutter_legado/lib/src/services/launcher_icon_service.dart)：剩余直接读写及原生切换 |
| 基础阅读 | [ReaderNotifier](../flutter_legado/lib/src/providers/reader/reader_notifier.dart) 与 [配置注入](../flutter_legado/lib/src/app/bootstrap/settings_runtime_configuration.dart)：基础设置、主题引用与 JS 快照 |
| 高级存储 | 基线 PreferencesReaderConfigRepository 的 75 个配置字段；现入口为 [AppReaderSettingsRepository](../flutter_legado/lib/src/data/repositories/app_reader_settings_repository.dart) 与 [ReaderAdvConfigNotifier](../flutter_legado/lib/src/providers/reader/reader_settings_provider.dart)，翻页收拢边界见第 11 节 |
| 阅读消费 | [ReaderScreen](../flutter_legado/lib/src/screens/reader_screen.dart)、[ReaderPageView](../flutter_legado/lib/src/widgets/reader/reader_page_view.dart)、[ReaderAdvancedConfig](../flutter_legado/lib/src/models/reader_advanced_config.dart)：正文参数、平台调用、点击映射与翻页 |
| 页壳/菜单 | [ReaderPageChrome](../flutter_legado/lib/src/widgets/reader/reader_page_chrome.dart)、[ReaderTextContent](../flutter_legado/lib/src/widgets/reader/reader_text_content.dart)、[ReaderMenuTheme](../flutter_legado/lib/src/widgets/reader/reader_menu_theme.dart)、[ReaderMenuPanel](../flutter_legado/lib/src/widgets/reader/reader_menu_panel.dart)、[ReaderStatusStrip](../flutter_legado/lib/src/widgets/reader/reader_status_strip.dart)：信息栏、标题与菜单几何/颜色 |
| Rust 服务 | [net_api.rs](../rust/legado-ffi/src/api/net_api.rs)、[server_api.rs](../rust/legado-ffi/src/api/server_api.rs)、[server.rs](../rust/legado-server/src/server.rs)：Hosts 应用、独立 MCP 生命周期及令牌鉴权 |

### 6.2 其他设置：普通偏好及服务边界

本表普通偏好的原存储均为 SharedPreferences，当前写入者为其他页调用旧服务；
三个日志键由其他页调用 CrashLogService 写入。表内拟定仓储均指第 3 节的接口，
不要求为未接线项立即增加运行时服务。

| 功能 / 真实键 | 类型、默认值和单位 | 拟定归属 | 消费证据与处理 |
|---|---|---|---|
| 自动刷新 / `auto_refresh` | bool / false | Bookshelf | 未接线；`autoRefreshBook` 是常量名称，不是持久化键 |
| 仅更新阅读书籍 / `onlyUpdateRead` | bool / false | Bookshelf | 未接线；设置条件显隐不等于更新任务应用该值 |
| UserAgent / `userAgent` | String / 空串 | DownloadCache | 未接线；Rust 请求的缺省 UA 来自 DEFAULT_USER_AGENT，未读取此偏好 |
| Web 服务保活 / `webServiceWakeLock` | bool / false | General | 未接线；SettingsScreen 的前台服务路径不读取此开关 |
| 默认书籍目录 / `defaultBookTreeUri` | String / 空串；清空删除键 | General | 已接线；TocScreen 导出书签时传给文件选择器 initialDirectory，范围仅此路径 |
| 书源编辑最大行数 / `sourceEditMaxLine` | int / 99；10–99999 | General | 未接线；仅其他页读写 |
| 抗锯齿 / `antiAlias` | bool / false | ReaderSettings | 未接线；没有将此值传给文字或图片绘制 |
| 图片缓存容量 / `bitmapCacheSize` | int / 50 MB；1–1024 | DownloadCache | 未接线；备份搬运不是缓存容量应用 |
| 图片保留数 / `imageRetainNum` | int / 100；0–999 | DownloadCache | 未接线；仅其他页读写 |
| 正文预下载 / `preDownloadNum` | int / 10 章；0–9999 | DownloadCache | 未接线；Rust 中同名注释不是 Preferences 读取 |
| 默认启用替换 / `replaceEnableDefault` | bool / true | ReaderSettings | 未接线；现有正文处理使用自己的缺省策略 |
| 退出时保留媒体按键 / `mediaButtonOnExit` | bool / true | ReadAloud | 未接线；现有媒体会话没有读取此值 |
| 媒体按键启动朗读 / `readAloudByMediaButton` | bool / false | ReadAloud | 未接线；当前按键控制不消费此开关 |
| 忽略音频焦点 / `ignoreAudioFocus` | bool / false | ReadAloud | 未接线；现有音频焦点策略未读取此值，不能因此认定没有音频焦点管理 |
| 自动清理过期缓存 / `autoClearExpired` | bool / true | DownloadCache | 未接线；手动清缓存能力保持独立 |
| 返回时加入书架提醒 / `showAddToShelfAlert` | bool / true | General | 已接线；ReaderScreen 退出未入架书籍时读取 |
| 自动更新版本 / `autoUpdateVariant` | bool / true | General | 未接线；更新服务没有消费此值 |
| 显示漫画界面 / `showMangaUi` | bool / true | Ui | 未接线；当前漫画路由按书籍类型选择 |
| Web 端口 / `webPort` | int / 1122；1024–60000 | General | 已接线；SettingsScreen 启动服务读取；其他页保存后另调 setServerPort |
| 更新与搜索线程数 / `threadCount` | int / 16；1–999 | DownloadCache | 未接线；不能把 Rust 现有并发限额当成此键的消费 |
| 选中文字操作 / `process_text` | bool / true | General | 未接线；Manifest 的 PROCESS_TEXT 查询声明未受此值控制 |
| 记录日志 / `crash_record_log` | bool / false | General | 未接线；唯一受控入口 putDebug 没有生产调用方；logMessage 不检查此开关 |
| 记录 HTTP 请求 / `crash_record_http_log` | bool / false | General | 未接线；logHttp 没有生产调用方，方法内部也未检查此开关 |
| 记录堆转储 / `crash_record_heap_dump` | bool / false | General | 未接线；仅开关读写，OOM 路径记录 RSS 不受此值控制，也不产生堆转储 |

日志接口及其他页的“已接通”注释与调用链不符，以上以实际调用为依据；崩溃捕获、
普通消息记录和现有日志查看/导出不是这些开关控制的能力，后续不能一并禁用。
可见行的禁用在 B2 实施，B1 不改界面。

下面的地址不是可直接复制进普通偏好模型的标量：

| 功能 / 原地址 | 数据性质与缺省 | 当前路径和归属 |
|---|---|---|
| 本地密码 / Preferences `localPassword` | 凭据 String / 空串；清空删除 | 其他页独有读写，无认证消费者；与隐私密码、Web Token 分开，待实现，不能并入普通快照 |
| 自定义 Hosts / Rust `config:customHosts` | JSON 对象字符串 / 空串清除 | 已接线；setCustomHosts 更新 DNS/HTTP 客户端并保存，启动可回读；保持网络服务窄接口，不能用通用 setConfig 代替运行时应用 |
| MCP 端口 / Rust `config:mcpPort` | 数字字符串；界面缺省 0；0 停止，1024–65530 启动 | 已接线；setMcpPort 处理停止/重启/绑定并保存；保留服务接口。Rust 的 1236 常量不是当前界面未保存状态的默认值 |
| Web 书源令牌 / Rust `config:jsSourceApiToken` | 凭据 String / 空串 | 已接线；启动独立 MCP 读取并供 X-Legado-Token 鉴权；保持凭据/服务边界，不在普通模型复制 |
| 书源校验配置 / 现有 CheckSource 配置入口 | 结构化校验配置及运行会话 | 由 CheckSourceNotifier / 校验仓储读取并执行；保持书源域，不迁入 General |

语言、默认首页、发现/订阅显隐和启动直读分别沿用 Locale、Home、Welcome 已迁移
接口。视频设置按第 6.6 节登记。清缓存、清 WebView、压缩数据库等是一次性服务
动作，不是普通持久化开关；保留现有执行路径及错误反馈。

### 6.3 备份、同步和远程连接

以下实际键均在 SharedPreferences。连接字段目前由 SyncNotifier 通过旧服务
写入；普通同步开关也存在页面直接写旧服务的路径，后续必须同时迁走两处。

| 功能 / 真实键 | 类型 / 缺省 | 数据归属 | 消费证据与处理 |
|---|---|---|---|
| WebDAV 地址 / `sync_webdav_url` | String / 空串 | 连接配置 | 已接线；buildConfigJson → WebDAV 上传/下载 |
| WebDAV 用户名 / `sync_webdav_username` | String / 空串 | 连接配置 | 已接线；同一请求配置，不复制到普通备份策略模型 |
| WebDAV 密码 / `sync_webdav_password` | String / 空串 | 连接凭据 | 已接线；认证使用，保留原存储与专用访问边界 |
| WebDAV 子目录 / `sync_webdav_remote_dir` | String / `/legado/` | 连接配置 | 已接线；normalizedRemoteDir 保证末尾斜杠 |
| 设备名 / `sync_webdav_device_name` | String / 空串 | 连接配置 | 未接线；保存/显示，但不进入当前 buildConfigJson 或文件命名 |
| 同步书籍进度 / `sync_book_progress` | bool / true | Backup | 已接线；uploadBookProgress、syncBookProgressForBook 检查该值；不据此宣称后台自动同步已实现 |
| 进度同步增强 / `sync_book_progress_plus` | bool / false | Backup | 未接线；仅保存及展示 |
| 自动同步 / `sync_auto` | bool / false | Backup | 未接线；没有消费此值的调度路径；手动 WebDAV 同步仍有效 |
| 上次同步 / `sync_last_time` | int 毫秒 / null | 同步结果元数据 | 已接线；同步后写入、界面显示，用户不编辑，不作为普通策略字段 |
| 仅保留最新备份 / `onlyLatestBackup` | bool / true | Backup | 未接线；未见按此值删除旧备份的路径 |
| 启动检查新备份 / `autoCheckNewBackup` | bool / true | Backup | 未接线；未见启动检查消费者 |
| 本地备份目录 / `app_backup_path` | String / null；清空删除 | Backup | 已接线；WebDAV 页本地备份和 CrashLogService 复制/查看备份崩溃日志都读取；现由 CrashLogService 持久化，B2 应让两处共用仓储 |
| 恢复忽略项 / `restoreIgnore` | JSON 字符串；已知项均 false | 结构化备份配置 | 已接线；RestoreIgnorePrefs 与本地恢复使用；专用适配保存原整对象格式，不改为多个新键 |
| 远程服务器列表 / `remote_servers` | JSON 数组字符串 / `[]` | 连接集合，含凭据 | 已接线；RemoteBookNotifier 列表 CRUD、WebDAV 目录请求；保持专用集合所有者 |
| 选中远程服务器 / `remote_server_id` | int / -1（默认 WebDAV） | 连接选择 | 已接线；RemoteBookNotifier 加载及切换；与服务器列表同域，不迁入 General |

备份排除列表、服务端连接列表不是“多个普通开关的快照”。恢复后既要刷新已迁移
普通仓储，也要重读相应连接/结构化配置；不能仅重建页面仍使用旧共享快照。
路径字段由 Backup 持有，日志服务只消费该路径并管理文件，不再当配置写入者。

### 6.4 外观剩余入口

| 功能 / Preferences 键 | 类型 / 缺省 | 归属与处理 |
|---|---|---|
| 桌面图标 / `launcherIcon` | String / `iconMain`；可选 icon1–icon6 | Appearance；已接线，仅 Android/iOS 支持；主题页保存后调用 LauncherIconService，平台失败必须与保存失败区分 |
| 顶栏阴影 / `barElevation` | int / 0 | Ui；未接线且已禁用，当前仍由主题页读取，保留值及原说明 |
| 壁纸自动更新配色 / `wallpaperColorAutoUpdate` | bool / true | Appearance；未接线且已禁用，当前仍由主题页读取 |
| 仅 Wi-Fi 加载封面 / `loadCoverOnlyWifi` | bool / false | Ui；未接线且已禁用，保留原键 |
| 使用默认封面 / `useDefaultCover` | bool / false | Ui；未接线且已禁用，保留原键 |
| 封面显示书名 / `coverShowName` | bool / true | Ui；未接线且已禁用，保留原键 |
| 封面显示作者 / `coverShowAuthor` | bool / true | Ui；未接线且已禁用，保留原键 |
| 日间透明导航栏 / `transparentNavBar` | bool / false | SystemBar；已有仓储，未接线且已禁用，不建立重复写入者 |
| 夜间透明导航栏 / `transparentNavBarNight` | bool / false | SystemBar；同上 |

主题预设仍是 `themeConfigList` JSON 数组字符串，空串解码为空列表，所有者为
PreferencesThemePresetRepository；已经使用检查写入结果的 setStringPrefChecked。
它保留独立列表格式和串行读改写，不并入 AppSettingsStore 的标量快照。
日夜背景图片、配色和其他已迁移领域均保持原仓储。

### 6.5 阅读设置B1基线：基础值、75个高级字段及格式边界

目标统一归 ReaderSettingsRepository；原存储均为 SharedPreferences。基础值在B1基线中
由ReaderNotifier / SettingsService写入，高级值由原PreferencesReaderConfigRepository
保存完整配置，字体页直接写字体键。B3的逐批接线见第11～22节，已迁字段只经其所属仓储写入。

| 功能 / 真实键 | 类型、缺省与单位 | 消费/处理 |
|---|---|---|
| 字号 / `reader_font_size` | double / 20；UI 限 12–32 | 已接线；ReaderNotifier → 正文；配置注入生成 JS 快照 |
| 行高 / `reader_line_height` | double / 1.7；UI 限 1–3 | 已接线；ReaderNotifier → 正文 |
| 背景预设 / `reader_bg_color_index` | int；旧 getter 缺省 0，可空读取 null | 已接线；null 表示未选择，不能迁移成显式 0；ReaderNotifier、配置注入共同读取 |
| 自定义背景 / `reader_custom_bg_color` | int ARGB / null | 已接线；配合下一开关恢复颜色 |
| 使用自定义背景 / `reader_bg_use_custom` | bool / false | 已接线；选预设时写 false，自定义时写 true |
| 实际翻页名称 / `reader_flip_mode_name` | String / null | 已接线；PageTurnMode.fromStorage 优先读取 name；均缺失时默认 cover |
| 实际翻页旧索引 / `reader_flip_mode` | int / -1 | 已接线；name 缺失才读取；0=scroll、1=slide、2=simulate、3=none、4=cover |
| 亮度 / `reader_brightness` | double / -1 跟随系统 | 已接线；ReaderBrightnessControl，漫画亮度设置也写此键；保持共享消费者 |
| 正文字体 / `reader_font_family` | String / 未选系统字体 | 已接线；FontScreen 写入，ReaderPageView 恢复字体并测量 |
| 自定义字体集合 / `reader_custom_fonts` | StringList / 空列表；每项为family\|path | 已接线；字体导入、选择及运行时加载，当前没有删除界面；独立目录仓储管理 |
| 目录加载字数 / `reader_toc_load_word_count` | bool / true | TocScreen显示/菜单保存使用ReaderSettingsRepository，不读取原toc_load_word_count |
| 章节系统浏览器 / `reader_chapter_in_system_browser` | bool / false | 章节点击和长按选择使用ReaderSettingsRepository，不读取原readUrlInBrowser |
| 默认文本替换、抗锯齿 | 见第 6.2 节原键 | 同属 ReaderSettings，未接线，B3 不假装实现 |

AMOLED 背景判断目前既直接读取 PrefKeys.themeAmoled，又从 UiSettingsNotifier
读取；它的写入所有权已经在 UiSettingsRepository，B3 改为从该公共接口取值，
阅读域不重分配该键。阅读位置、书级配置及书籍实体不属于上述全局设置。

下面按功能组记录B1基线的字段、键与消费者，不把已转出的字段算入当前高级模型。
翻页、配色、字体、正文排版、页面布局、屏幕状态条、操作及菜单按第11～22节使用新入口；旧高级模型、独立Provider与整份保存入口已在第22节移除。

| 高级字段 / 真实键 | 原类型、缺省及范围 | 实际消费路径 |
|---|---|---|
| 自动翻页 / `reader_adv_auto_page_turn` | bool / false | ReaderScreen 定时器 |
| 翻页间隔 / `reader_adv_auto_interval` | double / 10 秒；3–120 | ReaderScreen 定时器 |
| 翻页方向 / `reader_adv_auto_forward` | bool / true | ReaderScreen 选择上一/下一页 |
| 九宫格动作 / `reader_adv_tap_actions_v1` | StringList / 九个枚举索引字符串；默认见 defaultTapActions | ReaderAdvancedConfig.actionForPosition → ReaderScreen 点击；结构化字段 |
| 段距 / `reader_adv_paragraph_spacing` | double / 2 dp；0–48 | ReaderScreen → 排版配置 |
| 字距 / `reader_adv_letter_spacing` | double / 0 em；-0.5–1 | ReaderScreen → 文字测量与排版 |
| 首行缩进 / `reader_adv_paragraph_indent_chars` | int / 2 字；0–3 | ReaderScreen → 断行/缩进 |
| 两端对齐 / `reader_adv_text_full_justify` | bool / true | ReaderScreen → 最终行布局 |
| 字重 / `textBold` | int / 0；0–2 | ReaderScreen → 文字测量与渲染 |
| 斜体 / `reader_adv_italic` | bool / false | 同上 |
| 正文颜色 / `reader_adv_custom_text_color` | int ARGB / 0 跟随主题 | ReaderPageView 正文颜色 |
| 正文上/下边距 / `reader_adv_margin_top`、`reader_adv_margin_bottom` | double / 各 24 dp；0–400 | ReaderScreen → 正文实际尺寸 |
| 正文左/右边距 / `reader_adv_margin_left`、`reader_adv_margin_right` | double / 各 20 dp；0–100 | 同上 |
| 页眉上/下内距 / `reader_adv_header_padding_top`、`reader_adv_header_padding_bottom` | double / 各 0 dp；0–400 | ReaderPageChrome 几何 → ReaderTextContent |
| 页眉左/右内距 / `reader_adv_header_padding_left`、`reader_adv_header_padding_right` | double / 各 16 dp；0–100 | 同上 |
| 页脚上/下内距 / `reader_adv_footer_padding_top`、`reader_adv_footer_padding_bottom` | double / 各 6 dp；0–400 | 同上 |
| 页脚左/右内距 / `reader_adv_footer_padding_left`、`reader_adv_footer_padding_right` | double / 各 16 dp；0–100 | 同上 |
| 页眉分隔线 / `showHeaderLine` | bool / false | ReaderPageChrome / ReaderTextContent |
| 页脚分隔线 / `showFooterLine` | bool / true | 同上 |
| 页眉模式 / `headerMode` | int / 0；0–2 | ReaderPageChrome 页眉显隐判断 |
| 页脚模式 / `footerMode` | int / 0；0–2 | ReaderPageChrome.showPageFooter |
| 页眉左/中/右提示 / `tipHeaderLeft`、`tipHeaderMiddle`、`tipHeaderRight` | int / 依次 2、0、3 | ReaderTextContent 提示栏 |
| 页脚左/中/右提示 / `tipFooterLeft`、`tipFooterMiddle`、`tipFooterRight` | int / 依次 7、0、6 | 同上 |
| 标题模式 / `titleMode` | int / 0；0–2 | ReaderPageView 标题与页壳 |
| 标题字号增量 / `titleSize` | int / 0；0–20 | ReaderPageView；与正文字号相加 |
| 标题上/下间距 / `titleTopSpacing`、`titleBottomSpacing` | int / 各 0；0–100 | ReaderPageView 标题几何 |
| 标题字体 / `titleFont` | String / 空串跟随正文 | ReaderPageChrome 标题字体；FontScreen 和高级仓储均写此键，需要统一 |
| 电量 / `reader_adv_show_battery` | bool / false | ReaderStatusStrip |
| 时间 / `reader_adv_show_time` | bool / false | 同上 |
| 进度 / `reader_adv_show_progress` | bool / false | 同上 |
| 章节 / `reader_adv_show_chapter_name` | bool / false | 同上 |
| 高级翻页模式 / `flip_mode` | int / 1=slide；0=simulation、2=cover、3=none、4=scroll | 未接线；高级面板保存此值，正文读取 PageTurnMode 的另外两个键，没有桥接 |
| 屏幕方向 / `screenOrientation` | int / 0；0–5 | ReaderScreen → SystemChrome |
| 保持亮屏 / `keep_light` | int / 0 | 未接线；ReaderScreen 明确尚未应用，不把设置面板回调算作平台消费 |
| 隐藏状态栏 / `hideStatusBar` | bool / false | ReaderScreen → SystemBarController、正文尺寸 |
| 隐藏导航栏 / `hideNavigationBar` | bool / false | 同上 |
| 进度条操作 / `progressBarBehavior` | String / 缺失实际解码为 page；chapter 才走 chapter | ReaderMenuPanel / ReaderScreen 进度跳转；不能照模型构造默认值改存储缺省 |
| 滚动无动画 / `noAnimScrollPage` | bool / false | ReaderScreen → ReaderPageView 程序化滚动 |
| 自动换源 / `autoChangeSource` | bool / true | ReaderScreen 自动换源判断 |
| 文字选择 / `selectText` | bool / true | ReaderScreen → ReaderPageView 原生选区 |
| 亮度显示模式 / `showBrightnessView` | 写 String 0/1/2；读也接受 int/bool；缺省 0 | ReaderMenuPanel；保留实际写入类型及旧解码规则 |
| 亮度位置 / `brightnessVwPos` | String；0=左、1=右；缺省右 | ReaderMenuPanel |
| 标题附加区 / `showReadTitleAddition` | bool / true | 未接线且已禁用；高级面板注明待顶栏实现 |
| 阅读菜单风格 / `readBarStyle` | int / 0；0–2；读取也接受数字字符串 | ReaderMenuTheme / ReaderMenuPanel |
| 阅读菜单调色板 / `readMenuPaletteStyle` | String / 空串跟随 | ReaderMenuTheme |
| 阅读菜单颜色模式 / `readMenuColorMode` | int / 0 | ReaderMenuTheme |
| 日/夜强调色 / `readMenuAccentColor`、`readMenuAccentColorNight` | int ARGB / 各 0 | ReaderMenuTheme |
| 日/夜背景色 / `readMenuBgColor`、`readMenuBgColorNight` | int ARGB / 各 0 | 同上 |
| 日/夜容器色 / `readMenuContainerColor`、`readMenuContainerColorNight` | int ARGB / 各 0 | 同上 |
| 日/夜文本色 / `readMenuTextColor`、`readMenuTextColorNight` | int ARGB / 各 0 | ReaderMenuPanel |
| 音量键翻页 / `volumeKeyPage` | bool / true | ReaderScreen 硬件按键处理 |
| 播放时音量键翻页 / `volumeKeyPageOnPlay` | bool / false | 同上；结合朗读状态 |
| 鼠标滚轮翻页 / `mouseWheelPage` | bool / true | ReaderPageView 分页模式滚轮 |
| 横向双页 / `doubleHorizontalPage` | int / 0；0–3 | ReaderScreen → ReaderPageView 分栏判断 |
| 中文断行 / `useZhLayout` | bool / false | 排版配置 → 当前 Rust 纯计算断行 |
| 标点悬挂 / `hangingPunctuation` | bool / false | FlutterTextShaper / 排版配置 |
| 滑动阈值 / `pageTouchSlop` | int / 0；0–9999 | ReaderPageView 手势阈值 |
| 边缘点击阈值 / `pageTouchClick` | int / 0；0–399 | actionForPosition 按实际内容宽度计算死区；已接线，不可误禁用 |
| 正文进入刘海区 / `readBodyToLh` | bool / false | ReaderScreen 内容区域与 Insets |
| 避让开孔 / `paddingDisplayCutouts` | bool / false | 同上 |

B1审计时的高级存储包含下列解码/迁移键，仅作历史输入记录，不是新增用户设置：

- `reader_adv_left_action`、`reader_adv_center_action`、`reader_adv_right_action`：旧三列
  int动作，B1基线在九宫格缺失时回读并复制到三行，保存时回写中间一行；该转换已移除。
- `reader_adv_paragraph_indent`：旧 bool 缩进，整数档位缺失时 true→2、false→0。
- `reader_adv_letter_spacing_migrated`：字距 px→em 一次性转换标记；读取及保存均涉及。
- `settingsMigrated_v271`：历史默认值转换标记，涉及信息栏四开关和 tipFooterLeft。
- `reader_layout_is_night`、`reader_layout_share_*`、`reader_layout_day_*`、
  `reader_layout_night_*`、`shareLayout`、`reader_unified_layout_v1`、`readBarStyleFollowPage`：
  ReaderSettingsMigration 的既有转换输入/中间标记，运行时仍使用上表的统一键。

上述旧转换用于追溯B1基线，不作为新迁移的兼容要求。正文排版的字距px转换、旧bool缩进
及旧日夜布局转换已经移除；旧九宫格/三列转换与回写、页脚和状态条旧默认转换及菜单旧开关
转换也已删除。上述表格保留B1审计证据，现行入口见第11～22节。后续迁移直接
采用目标模型和规范键，不为未发布应用增加旧值双读、转换标识或兼容副本。
翻页两套 int 编码不能相互直接赋值；实际模式默认 cover，高级副本默认 slide。
收拢时应保留实际生效来源，并让全部可见选择器读写同一个领域值，不再保留仅
保存而不生效的独立副本。这项正确性问题优先于单纯重命名仓储。

### 6.6 相邻专用边界及旧服务清理清单

| 原地址 / 接口 | 归属与依据 |
|---|---|
| Preferences `delete_book_alert` / bool，默认 true | Bookshelf；BookInfoScreen 删除确认流程消费，扩展已有仓储，避免新建单字段接口 |
| Preferences `videoPlay.autoPlay`（bool / true）、`videoPlay.startFull`（bool / false）、`videoPlay.longPressSpeed`（int / 30，实际倍速除以 10）、`videoPlay.fullBottomProgressBar`（bool / true）、`videoPlay.defaultFloatWindow`（bool / false） | VideoPlaySettings → VideoScreen；独立视频域，不能随其他设置页搬进 General；本批只登记相邻入口，视频各项平台行为留该功能核验 |
| Rust 的简繁转换设置 / getChineseConvertType、setChineseConvertType | ReaderConfigPanel 调用既有功能接口，正文转换由 Rust 完成；保持服务语义，不生成 Preferences 镜像 |
| 阅读位置及书级阅读配置 | 原业务 Repository / ReaderPositionStore；不是全局普通偏好，章节原文偏移与书籍实体存储不动 |
| 隐私密码/授权 | 原 PrivacyCredentialRepository 与进程会话；本批不合并本地密码、WebDAV 密码或令牌 |

B1基线的SettingsService曾有69个公开异步方法，按以下互不重叠的组归档；
以下表格仅保留审计来源，当前保留接口见第23节。无调用方判定排除
定义、生成代码、测试和其他对象的同名方法；例如 AppLocaleNotifier.setLocale
不是 SettingsService.setLocale 的消费者。

| 方法组 / 数量 | 原地址与调用方 | 后续处理 |
|---|---|---|
| 字号、行高、背景、翻页、亮度 / 13 | 第 6.5 节基础值；ReaderNotifier、配置注入、阅读/漫画亮度控件 | B3 同时迁移真实消费者再删除方法 |
| 书架 Tab/布局、语言、阅读记录开关/排序 / 10 | `bookshelf_tab_position`、`bookshelf_layout`、`app_locale`、`enableReadRecord`、`readRecordSort`；普通入口已迁移，无此旧服务方法的生产调用方 | 确认测试已切换后删除旧方法，原键和值保留 |
| 旧代理与超时 / 8 | `net_proxy_type` String/none、`net_proxy_host` String/空、`net_proxy_port` int/0、`net_request_timeout` int/30 秒；无生产调用方 | 作为失效方法候选；不以此否定网络模块的其他请求/代理能力，不迁移成另一份新权威配置 |
| WebDAV 连接 / 10 | 第 6.3 节五个连接字段；SyncNotifier | 凭据/连接专用入口迁移后清理旧方法 |
| 远程服务器列表/选中项 / 4 | `remote_servers`、`remote_server_id`；RemoteBookNotifier | 同一连接集合边界，保留原格式 |
| 同步开关 / 6 | `sync_book_progress`、`sync_book_progress_plus`、`sync_auto`；SyncNotifier 与 WebDAV 页 | Backup；两处写入同时切换，功能状态独立处理 |
| 上次同步时间 / 2 | `sync_last_time`；SyncNotifier | 保留同步结果元数据边界 |
| 删除提醒与目录字数 / 4 | `delete_book_alert`、`toc_load_word_count`；BookInfoScreen、TocScreen | 分别迁入 Bookshelf / ReaderSettings |
| 恢复排除列表 / 2 | `restoreIgnore`；WebDAV 页 | 结构化适配接替，不转成普通字段 |
| 通用读写/删除/颜色助手 / 10 | get/setBoolPref、get/setIntPref、getIntPrefOrNull、getStringPref、setStringPref、setStringPrefChecked、setColorPrefs、removePref | 其他页、WebDAV、外观、ReaderScreen、TocScreen、主题预设仍有消费者；不能整类先删。可空整数与颜色助手目前无生产调用方 |

存储问题与功能问题分别处理：旧服务的大部分 setter 吞掉异常且未检查底层 bool
结果；主题预设使用的检查版 setter 和高级阅读仓储的 `_write` 已能报告失败。
后续统一服务时保留这些有效错误传播，再迁走普通 setter，不能为“统一入口”
把已经有效的失败处理降级。优先迁移 General 的真实消费者、备份路径和有效同步
开关，成组禁用未接线行；未接线仓储字段仅为保留原值，不算功能落地。

## 7. 迁移顺序与批次范围

### B1：完成分类和消费核验

先盘点 OtherSettingsScreen、WebDavSettingsScreen、剩余外观图标入口、
ReaderNotifier/ReaderConfigRepository 及 SettingsService 的剩余公开方法。
查清真实键、数据性质和消费端，形成逐项清单；候选领域名不要求立即生成代码。
归属明显的先确定，尚未证明功能的标记待核验，不凭猜测删除或禁用。

### B2：集中迁移其余普通偏好

保留现有仓储，先建立有实际消费者的 General、Backup 入口；DownloadCache 按
功能接入建立，尚未接线时不先创建空壳。朗读、书架、图标新增字段进入已有领域。
每批同时切换设置页和实际消费者，接住保存
错误、回退展示并接入备份恢复重读。经核验未接线的行保留原说明并追加“待实现”
后禁用，原键和原值保留；下一阶段按真实功能接线后启用。

日志的存储读写归入设置边界，CrashLogService 保留记录执行和文件管理；实际
记录器使用同一来源，不能保留另一套已保存开关。系统或服务动作仍在对应控制器。

### B3：统一阅读设置访问

收拢ReaderNotifier中字号、行距、背景、翻页参数的直接读写，以ReaderSettingsRepository
统一普通偏好入口；按第11～22节分组迁移点击、页面、屏幕与菜单设置，移除旧高级
配置模型和整份读写。外观域AMOLED等开关使用其公共设置入口，不让阅读领域成为
同一键的第二个所有者。未发布阶段直接采用目标模型与规范键，不为旧数据保留兼容副本。
同步修改 Rust 配置快照的读取入口，保留字段值与注入顺序；分页、文字测量、选区、
翻页动画、位置坐标与缓存策略不在本批改动范围。

### B4：清理重复入口，再落地待实现功能

全仓确认迁移字段不存在旧读写消费者后，删除对应SettingsService专用方法及
重复适配；已无消费者的通用写入/删除和助手也一并清理，不长期保留只为旧测试存在的入口。实体列表、凭据与原生服务的独有
能力分别保留。禁用项按功能成组落地，核对上游语义和平台限制，实际验证通过
后移除“待实现”提示并启用；不借设置归类一次性实现所有未接线功能。

## 8. 每批验收与回滚

- 明确目标存储键、类型、默认值、枚举编码、单位和删除语义；未发布阶段不为旧数据增加兼容层。
- 设置页和实际消费者能读到同一来源；保存成功、失败回退、重试与恢复重读有必要回归。
- 未接线行保留原说明和值，禁用且不可写；平台限制有明确说明，不冒充已实现。
- 结构化配置和凭据保持原格式，普通偏好快照不扩展为实体、授权状态或密码集合。
- Flutter 静态检查与改动相关测试通过；根据接线实际需要做一次定向设备验证，
  不重复触发全量 CI，不为罕见低影响时序增加额外机制或大范围测试。
- 回滚撤销本批 Dart 接线，不删除用户设置、不改存储位置；若涉及原生/FFI 的真实
  能力新增，按该功能任务单独确定验证、数据兼容和回滚范围。

## 9. 上游依据与本地入口

上游源码均固定到同一提交，以下只提供设计依据，不是本项目的状态源：

- [领域设置模型目录](https://github.com/HapeLee/legado-with-MD3/tree/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/domain/model/settings)。
- [OtherConfigViewModel](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/ui/config/otherConfig/OtherConfigViewModel.kt)：同页使用多个领域 Gateway。
- [FeatureSettingsRepositories](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/data/repository/FeatureSettingsRepositories.kt)：业务快照与原键转换。
- [AppConfigStore](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/help/config/AppConfigStore.kt)：共享配置快照与写入协调。
- [ReadStyleRepository](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/data/repository/ReadStyleRepository.kt)：阅读样式文件的独立格式边界。

本地入口包括 domain/contracts/*settings_repository.dart、data/services/app_settings_service.dart、
data/settings/app_settings_store.dart、data/repositories/app_*settings_repository.dart，以及
现有 ReaderSettingsRepository、隐私凭据接口
和各实体 Repository。
已完成批次的架构依据继续保留在 [数据边界说明](FLUTTER_DATA_BOUNDARIES.md)。

## 10. 首批普通偏好的代码边界

首批使用既有存储位置、键、类型与默认值；空目录仍删除原键，AppSettingsService
与 AppSettingsStore 负责保存、订阅和失败回退，领域模型不包含页面加载状态。

| 字段 | 唯一领域访问入口 | 消费端 |
|---|---|---|
| defaultBookTreeUri、showAddToShelfAlert、webPort | [AppGeneralSettingsRepository](../flutter_legado/lib/src/data/repositories/app_general_settings_repository.dart) | 其他设置页、目录书签导出、阅读退出、Web 服务启动 |
| app_backup_path、sync_book_progress | [AppBackupSettingsRepository](../flutter_legado/lib/src/data/repositories/app_backup_settings_repository.dart) | WebDAV 设置页、SyncNotifier、CrashLogService |
| launcherIcon | 原 AppAppearanceSettingsRepository 新增字段 | 外观页、LauncherIconService |
| delete_book_alert | 原 AppBookshelfSettingsRepository 新增字段 | BookInfoScreen 菜单与删除确认 |

General/Backup 和外观/书架的消费者订阅同一服务快照，去掉已迁移字段的页面保存
副本；备份恢复时重读两个新领域，外观和书架沿用既有恢复入口。SyncState 中的
进度开关只作界面及业务消费投影，其写入委托 BackupSettingsRepository。

CrashLogService 初始化时注入使用相同 AppSettingsService 的 BackupSettingsRepository，
不再自己读取或保存 app_backup_path，也不提供路径 setter；日志列表、读取、清理和
崩溃备份从该仓储取目录。启动只提前装配共享服务，不提前执行 Rust 初始化或
额外设置 IO，仍先初始化日志文件和捕获器。文件记录能力保持原样。

保存端口失败时不调用 setServerPort；图标保存失败时不调用原生切换。保存成功
但运行时失败仍保留已保存值，显示实际应用失败原因，不把已成功写入伪装成回滚。
目录选择、返回提醒、同步和删除提醒的保存错误由页面接住，订阅值跟随服务回退。

其他页的 22 个未接线选项及 WebDAV 页的设备名、进度增强、仅留最新备份、启动
检查四项禁用，保留原显示值及原说明，追加“待实现”；没有原说明时仅加提示。
既有有效开关、Hosts/MCP/Token、视频入口及手动维护动作保持可用。未接线键仍
按原协议只读展示，不为其创建 DownloadCache 空壳或在此补做运行时功能。
自动同步在当前 WebDAV 页没有独立可见行，其遗留方法的裁决留在清理批次。

首批普通偏好不改阅读仓储名称或高级格式，不合并 WebDAV 凭据与连接
集合，不清除原键，也不删除尚未整体迁走的 SettingsService。B3 的翻页重复来源
与 ReaderSettingsRepository 统一的具体边界见下节。

对应定向回归入口为 [领域设置测试](../flutter_legado/test/unit/general_backup_settings_test.dart)、
[设置页测试](../flutter_legado/test/widget/general_backup_settings_test.dart) 和
[日志备份目录测试](../flutter_legado/test/unit/crash_log_backup_settings_test.dart)；
具体执行结果只记录在活动计划。

## 11. 阅读翻页的唯一来源

[ReaderSettingsRepository](../flutter_legado/lib/src/domain/contracts/reader_settings_repository.dart)
提供普通偏好的current/watch/load/update/reload；字号、字体及各阅读分组使用同源快照，
背景样式由ReaderStyleRepository管理。第11节最初迁移时保留过的74项高级字段已按
后续各节拆出，第22节删除loadAdvanced/saveAdvanced及ReaderAdvancedConfig；
不保留独立高级配置缓存或可写副本。

[PageTurnMode](../flutter_legado/lib/src/domain/models/page_turn_mode.dart) 是唯一翻页
枚举，独立于页面和 Flutter 绘制；ReaderState、快捷菜单、高级面板和正文均使用
这个类型。ReaderNotifier 中的模式仅投影仓储值，不再自己读写持久化键。
ReaderAdvancedConfig 的 FlipMode 字段、独立枚举及其存储读写移除。

| 地址 | 规则 |
|---|---|
| reader_flip_mode_name | 原名称优先读取；新修改只保存此键 |
| reader_flip_mode | 只回读原有效索引：0 滚动、1 滑动、2 仿真、3 无动画、4 覆盖；不再双写 |
| flip_mode | 原高级面板未生效的副本，不读取、不转换、不写入；已有持久值保留 |

无有效存储时仍默认覆盖。两个有效键冲突时沿用原名称优先规则，不将另一枚举
的整数解释为当前模式，也不为了改入口而主动清除已有设置。

两个选择器提交同一字段；选择即时生效，保存失败共享值回退并提示，重试仍可用。
高级参数快照不再含翻页，保存其他字段不会恢复旧模式。备份恢复后重读翻页领域，
已经打开的选择器和正文订阅同一新值。

本次不改字号、行高、背景及字体的现有存储入口，也不改正文布局、选区、翻页
动画实现或 Rust 配置协议。后续基础偏好收拢继续扩展 ReaderSettings 和同一仓储，
不新增相同职责的兼容层。

对应回归入口为 [仓储测试](../flutter_legado/test/unit/reader_settings_repository_test.dart)
与 [入口交互测试](../flutter_legado/test/widget/reader_page_turn_settings_test.dart)；
实际执行结果只记录在活动计划。

## 12. 同一阅读样式的日夜配色

[ReaderStyle](../flutter_legado/lib/src/domain/models/reader_style.dart) 使用稳定 id、
名称、day 与 night 两组 ReaderColors；每组包含背景和文字 ARGB。空背景表示默认
背景，空文字色表示按 sRGB 背景亮度自动选择。正文、模板预览和书源配置注入共用
该模型的颜色解析，渲染不再从高级配置读取另一份正文文字色。

[ReaderStyleRepository](../flutter_legado/lib/src/domain/contracts/reader_style_repository.dart)
拥有结构化样式集合及选中样式；[AppReaderStyleRepository](../flutter_legado/lib/src/data/repositories/app_reader_style_repository.dart)
在原 Preferences 位置保存独立 reader_styles JSON 字符串。AppSettingsService 只
协调这个字符串地址的 IO、订阅和失败回退，集合的序列化、默认模板与按样式修改
均留在专用仓储；不扩展标量 Store 为通用实体列表。

内置微信读书与预设1～5的日夜背景、文字色逐项来自
[固定上游默认数据](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/assets/defaultData/readConfig.json)。
只复刻配色，不把上游模板的字号、边距、标题等字段覆盖现有排版。自定义修改保存
到当前样式的当前日夜一侧；另一侧及其他模板保持，选择其他模板后返回仍读取保存值。
已有颜色转入额外的自定义样式，避免升级后自动改选微信读书；原已保存键不主动清除。

转换只在 reader_styles 不存在时读取原背景索引、自定义颜色及高级文字色；新文档
存在后不再回读这些旧来源。原背景服务方法和高级模型的 customTextColor 字段及
写入移除，其余高级字段保持原格式。ReaderState 只投影最终颜色及阅读亮度，
颜色不进入分页几何缓存键；模板切换不重置章节、阅读锚点或播放状态。

ReaderThemeSession 只在内存保存跟随应用、日间或夜间，默认跟随应用；
进入和退出阅读页清除手动覆盖，目录、阅读设置及应用后台仍属于同一会话。
菜单使用有效阅读亮度选择原有日夜菜单颜色，跟随应用的菜单样式仍尊重原选项。
模板保存失败提示并回退，备份忽略集合及恢复重读包含 reader_styles；会话覆盖不落盘、
不进入备份。启动与 Provider 消费同一个设置服务和会话实例，既有 JS 配置注入的
字段类型不变；具体颜色语义见 API_CONTRACT。

### 与上游的对齐范围

上游在当前样式内修改日夜颜色，保存配置列表到 readConfig.json；普通样式选择
保留已编辑值。另有 applyPreset，复制 DefaultData 中的原始模板覆盖当前样式，
用于恢复内置预设。依据为
[ReadBookStyleConfigRepository](https://github.com/HapeLee/legado-with-MD3/blob/60a7cca34dd3e0be456e0f05c10c036c64b70e35/app/src/main/java/io/legado/app/data/repository/ReadBookStyleConfigRepository.kt)。

当前对齐六套纯色数据、同样式日夜分开修改、样式选择与保存恢复；不宣称完整背景
功能或界面一致。上游的图片背景、墨水屏、透明度、状态栏样式字段、恢复预设、
样式增删和独立导入导出尚未全部接入。手动明暗覆盖已按上游 ReadSessionState
调整为阅读会话状态；配色与样式选择长期保存，退出后不恢复手动覆盖。
上游完整样式可保存排版并提供共享排版，当前继续共用
已有一套排版，与已批准的本轮纯色范围一致。

对应回归为 [上游配色样本](../flutter_legado/test/fixtures/upstream_reader_colors.json)、
[仓储测试](../flutter_legado/test/unit/reader_style_repository_test.dart)、
[入口交互](../flutter_legado/test/widget/reader_style_settings_test.dart) 和既有配置注入、
菜单、阅读器测试。执行结果与尚未验证的设备边界只维护于活动计划。

编写者：Codex｜2026-10-14

## 13. 字号与行距统一访问

ReaderSettings 在已有翻页模式之外投影 fontSize 与 lineHeight；仓储读取原
Preferences double 键 reader_font_size、reader_line_height，默认20和1.7。
阅读交互保持字号12～32、行距1～3的原限制；主题导入继续沿用原正数校验和
逐字段写入语义，未传字段不修改，不改变历史值和导入格式。

ReaderNotifier 从仓储加载与订阅同源值，保留即时显示，保存结束后投影有效快照；
失败传播到控件并提示，重试可继续。恢复与外部导入通过同一仓储修改或显式reload，
不能绕过服务直接写键后期待已缓存消费者自动重读。共享服务继续逐字段保存，
前一字段成功而后一字段失败时，只回退失败和未保存字段，不描述为整批事务。

SettingsRuntimeConfiguration 与阅读器使用同一AppSettingsService：JS textSize读取
同源字号，保持原四舍五入和整数类型；lineSpacingExtra仍为原值8，其他既有字段、
FFI签名及初始化顺序保持。本次不把Flutter行高倍率改造成另一种书源排版单位。

快捷字号、完整字号与行距控件等待更新结果并接住失败。备份恢复的原阅读仓储重读
同时覆盖三项基础偏好。删除SettingsService中的字号/行距四个旧方法，其他方法
仍留给尚未迁走的消费者；正文和标题字体、字体列表以及剩余高级字段另行迁移。
不修改分页算法、原文坐标、选区、翻页动画和缓存规则；字号变化继续触发现有重排，
阅读位置仍用现有原文锚点。定向回归覆盖设置保存和失败、导入、恢复、配置注入、
已打开章节的锚点保留；执行结果和设备边界只记录在活动计划。

编写者：Codex｜2026-10-14

## 14. 字体选择、目录与平台加载

ReaderSettings 保存fontFamily和titleFontFamily。正文偏好键reader_font_family在
选择默认时删除；标题键reader_title_font_family保存空串时跟随正文。
按用户未发布快速开发口径直接采用规范标题键，不读取或迁移旧titleFont。
ReaderAdvancedConfig不再包含标题字体，保存整份排版快照不会写回字体选择；
标题字体传入ReaderPageChromeConfig的最终布局快照，测量和绘制继续同参。

ReaderFontRepository / AppReaderFontRepository单独管理reader_custom_fonts目录，
保持StringList和family|path编码，每条ReaderFont只含字体族和相对文件路径。
字体文件仍保存于当前Documents/fonts；列表不是字体内容、在线字体目录或新的
字体下载服务。重复导入同一字体族更新目录条目，其他字体保持；目录写入成功后
发布不可变快照，失败不会显示为已保存字体。当前没有字体删除界面，本轮不新增。

ReaderFontFiles负责文件导入、Documents相对路径定位及FontLoader注册，不读写
偏好。ReaderFontService编排导入、目录保存和选择；只有目录保存成功才修改选择。
字体页与正文共用此服务及注册记录，按文件路径、大小和修改时间复用注册；新进程
重新注册。加载选中字体的修订仍参与现有布局失效，不改变分页算法、索引或动画。
不增加旧绝对路径自愈、旧键双读或迁移标识；文件不存在时回退字体能力并记录错误，
字体管理页提示缺失，不宣称缺失文件已加载。

FontScreen、ReaderFontPanel、ReaderConfigPanel与ReaderPageView通过同源仓储
读取或订阅字体；不再直接访问偏好，选择失败回退并提示。正文/标题的默认语义
分别保持，返回字体页不再通过保存整份高级配置模拟通知。备份恢复显式重读字体
选择和目录，恢复忽略的阅读配置集合包含三个字体键；不宣称只恢复目录就能恢复
设备上不存在的字体文件。本轮保持JS快照中原font字段，未改Rust/FRB或依赖。

对应验证覆盖目录持久化与读写失败、导入选择顺序、重复字体条目、Documents文件
读取、注册复用与新实例注册、选择失败重试、共享标签、正文直接订阅字体更新、
标题跟随与独立选择及原文锚点保持。结果和未测设备边界只维护在活动计划。

编写者：Codex｜2026-10-15


## 15. 目录与章节链接偏好

目录字数开关tocLoadWordCount（默认true）和章节打开方式chapterInSystemBrowser
（默认false）归ReaderSettingsRepository。键统一为reader_toc_load_word_count、
reader_chapter_in_system_browser，直接采用目标键，不读取或迁移旧键。
存储仍为现有Preferences，不新增数据库表、独立设置服务或本地可写副本。

TocScreen从仓储当前快照读取，订阅该字段刷新字数胶囊和菜单勾选；开关不改变
章节字数的获取、缓存状态和轮询。保存失败由共享服务回退，并在目录提示，允许重试。
删除SettingsService对应的旧getter/setter；其他尚未迁走的方法保持。

章节标题点击在加载同源偏好后打开内置或系统浏览器；长按选择写回同一仓储。
保存失败明确提示，但仍执行用户本次选择，显式打开方式不再次依赖保存结果。
复制链接不写偏好。网页地址解析、卷标题/本地书守卫、系统打开失败反馈保持。
这两项不进入Rust所需的JS快照，不改变FFI签名或配置注入顺序。

备份恢复已有的阅读仓储reload同时重读两项；阅读配置忽略集合纳入规范键。
对应仓储、目录缓存状态、阅读菜单交互及恢复过滤回归复用现有测试文件。
执行结果和设备未测边界仅记录在活动计划。

编写者：Codex｜2026-10-15


## 16. 正文排版的不可变分组

ReaderSettings.textLayout持有ReaderTextLayoutSettings，只表达正文排版规则，
不依赖dart:ui、TextPainter、渲染对象或平台插件。读取和订阅仍由同一
ReaderSettingsRepository提供，不新增第二个仓储或缓存。updateTextLayout只提交
传入字段，使字体面板和中文排版面板不会相互写回旧快照。

| 字段 | Preferences规范键 | 默认与有效范围 |
|---|---|---|
| paragraphSpacing | reader_paragraph_spacing | 2dp；0～48 |
| letterSpacing | reader_letter_spacing | 0em；-0.5～1 |
| paragraphIndent | reader_paragraph_indent | 2字符；0～3 |
| textFullJustify | reader_text_full_justify | true |
| textBold | reader_text_bold | 0常规；1粗体、2细体 |
| italic | reader_italic | false |
| useZhLayout | reader_use_zh_layout | false |
| hangingPunctuation | reader_hanging_punctuation | false |

字距缺省0em取自当前实际存储解码，显式0不会被当成未传字段。范围由仓储统一处理。
按未发布开发口径不读取或迁移reader_adv_*、textBold、useZhLayout及hangingPunctuation
中的对应旧值；移除字距px转换、bool缩进转换及旧分桶的这些字段转换，不增加新标识。
存储位置仍为Preferences，字段从ReaderAdvancedConfig的构造、copy、加载和保存中移除。
其他高级配置仍由原入口管理；本轮不删除其他组的历史代码。

ReaderFontPanel不再接收高级配置或回传整份配置，它直接订阅共享设置并保存单字段。
ReaderConfigPanel的中文断行、对齐与悬挂使用同一来源；保存失败回退控件并提示，
重试可继续。ReaderScreen将同源八项值传入ReaderPageView，保持原单位、有效默认、
测量与分页参数及原文锚点路径；不修改断行、分页、选区、翻页算法或绘制方式。

备份恢复已有阅读仓储reload覆盖这八项，阅读配置忽略集合纳入规范键。
JS书源配置中的既有段距、字距和字重快照保持原值，不扩展本轮到FFI或业务契约修改。
回归覆盖真实Preferences恢复、逐字段保存、旧高级快照隔离、保存失败重试、
两个控件入口及实际ReaderScreen接参；执行结果和未测平台仅登记在活动计划。

编写者：Codex｜2026-10-15


## 17. 页面边距、标题及页眉页脚分组

ReaderSettings.pageLayout持有ReaderPageLayoutSettings，按bodyPadding、title、
header、footer与doubleHorizontalPage组成不可变快照。ReaderPagePadding只含
四向dp数值，ReaderTitleSettings保存标题的显示模式、字号增量和上下间距；
ReaderPageEdgeSettings保存某一边缘的模式、四向边距、分隔线与三个提示编号。
这些模型不依赖Flutter类型，ReaderPageChromeConfig负责最终渲染投影。

| 分组 | Preferences键 | 默认与范围 |
|---|---|---|
| 正文边距 | reader_page_margin_top/bottom/left/right | 24/24/20/20dp；上下0～400、左右0～100 |
| 双页 | reader_double_horizontal_page | 0；0～3，原有效编码保持 |
| 标题 | reader_title_mode/size/top_spacing/bottom_spacing | 均0；模式0～2、字号增量0～20、间距0～100 |
| 页眉边距 | reader_header_padding_top/bottom/left/right | 0/0/16/16dp；范围同正文 |
| 页脚边距 | reader_footer_padding_top/bottom/left/right | 6/6/16/16dp；范围同正文 |
| 模式与分隔线 | reader_header_mode、reader_footer_mode、reader_header_show_line、reader_footer_show_line | 模式缺省0；页眉0～2、页脚0～1；分隔线false/true |
| 提示 | reader_header_tip_left/middle/right、reader_footer_tip_left/middle/right | 页眉2/0/3，页脚7/0/6；沿用现有提示编号 |

存储仍为Preferences，直接使用新键，不读取或迁移该组旧reader_adv_*、驼峰键和
旧日夜分桶，不增加兼容标识。ReaderPageLayoutCodec集中定义地址、解码和局部写入映射，
不执行IO或缓存；ReaderSettingsRepository使用同一AppSettingsService加载、订阅和保存。
updatePageLayout只写传入正文字段及双页；updatePageEdge指定页眉或页脚，
updateTitle只写传入标题字段。边距左右联动一次提交两项，但落盘仍是逐字段操作，
不宣称整批事务；失败按现有共享服务保留已成功字段并回退未成功字段。

原“恢复默认边距”对正文采用6/6/16/16，与首次缺省不同，本轮分别保留。
页眉恢复0/0/16/16，页脚恢复6/6/16/16。页眉和页脚模式分别定义选项与有效范围，
不共用同一张选项表；含义见第18节。恢复默认入口与首次缺省的区别分别验证。

ReaderPaddingConfigSheet不再接收或回传高级配置副本，只保留当前区域和左右联动
这两个交互状态；边距、重置及分隔线直接访问页面设置。ReaderTipConfigSheet的
页面字段同源保存并订阅；状态条也从ReaderSettings.statusStrip读写（见第19节），
不再传入高级配置和保存回调。保存失败提示、回退控件并允许重试。

ReaderScreen从同源分组向ReaderPageView传正文边距和双页，并通过
ReaderPageChromeConfig.fromSettings生成页眉页脚与标题快照；hideStatusBar和标题字体
分别由原屏幕配置、共享字体选择传入。保持既有几何、原文锚点、选区、翻页与朗读分页
发布，不改排版算法、Rust/FRB或JS快照。备份恢复reload包含全部27项，阅读配置
忽略集合覆盖规范键。

移除该组在ReaderAdvancedConfig构造、复制及存储中的字段和旧默认转换，删除旧日夜
布局迁移逻辑及其专属测试；reader_settings_migration仅暂留未迁菜单风格转换。
剩余高级配置的队列和复制测试继续保留；用新页面仓储、控件与实际阅读器
接参回归替代已失效的迁移测试。执行结果和设备边界只记录在活动计划。

编写者：Codex｜2026-10-15


## 18. 页眉与页脚的显示模式

两组模式虽然同为整数，但含义不同。按参考版
[TypographyTabs.kt](https://github.com/HapeLee/legado-with-MD3/blob/4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5/app/src/main/java/io/legado/app/ui/book/read/sheet/TypographyTabs.kt#L1241-L1250)
与[页装饰显示判断](https://github.com/HapeLee/legado-with-MD3/blob/4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5/app/src/main/java/io/legado/app/feature/reader/legacy/LegacyReaderPageDecorationFactory.kt#L333-L339)，
固定采用以下语义：

| 区域 | 0 | 1 | 2 |
|---|---|---|---|
| 页眉 | 状态栏显示时隐藏 | 显示 | 隐藏 |
| 页脚 | 显示 | 隐藏 | 无此选项 |

默认均为0。ReaderPageLayoutCodec在解码及保存时分别限制页眉0～2、页脚0～1，
不读取旧键或做数据迁移。菜单使用对应选项，隐藏模式下收起该区域的提示、边距及
分隔线控件；恢复显示后从同一共享快照读回已有配置。页眉不受页脚修改影响。
设置保存失败仍由AppSettingsService回退，并在控件中提示及允许重试。

ReaderPageChromeConfig仍以footerMode != 1决定信息页脚显示，保持既有正文几何链路。
基础页码回退是独立的测量和绘制分支，不属于此模式选项修正；其与参考版的差异及
后续处理仅登记在活动计划，不借选项修正改变有效正文高度或页数。

编写者：Codex｜2026-10-15


## 19. 屏幕与阅读状态条分组

ReaderSettings.screen持有ReaderScreenSettings，statusStrip持有ReaderStatusStripSettings。
前者表达系统显示和安全区，后者表达阅读时附加信息；两者不依赖Flutter或平台类型，
继续由同一ReaderSettingsRepository读取、订阅、重读和逐字段保存，不另建缓存或服务。

| 分组字段 | Preferences规范键 | 默认与有效范围 |
|---|---|---|
| screen.orientation | reader_screen_orientation | 0；0～5，跟随系统/竖屏/横屏/传感器/反向竖屏/反向横屏 |
| screen.hideStatusBar | reader_hide_status_bar | false |
| screen.hideNavigationBar | reader_hide_navigation_bar | false |
| screen.extendIntoCutout | reader_extend_into_cutout | false |
| screen.avoidDisplayCutouts | reader_avoid_display_cutouts | false |
| statusStrip.showBattery | reader_status_show_battery | false |
| statusStrip.showTime | reader_status_show_time | false |
| statusStrip.showProgress | reader_status_show_progress | false |
| statusStrip.showChapterName | reader_status_show_chapter_name | false |

updateScreen与updateStatusStrip只保存显式传入字段；false有效，方向在解码和写入时
统一限制0～5。沿用AppSettingsService的写队列、订阅及失败回退，不承诺多字段原子事务。
新键加入备份的阅读配置忽略集合，已有阅读仓储reload覆盖全部九项。按未发布口径
不读取或迁移旧screenOrientation、hideStatusBar、hideNavigationBar、readBodyToLh、
paddingDisplayCutouts及reader_adv_show_*，删除settingsMigrated_v271默认转换及其专属
测试；保留尚未迁走的点击与菜单旧入口。

ReaderConfigPanel和ReaderTipConfigSheet直接订阅对应共享分组；状态条设置不再接收
statusConfig、onStatusChanged或保存局部高级副本。连续修改、保存失败提示与回退、
重新保存及外部重读都使用同一来源，静态弹层与完整设置页一致。

ReaderScreen订阅screen分组，按当前快照调用既有SystemBarController及SystemChrome。
菜单打开期间临时显示系统栏，离开阅读路由释放显示归属，返回后应用当前设置；
隐藏状态栏、导航栏和缺口几何仍沿用原公式。ReaderPageChrome、ReaderPageView和
ReaderStatusStrip接收同源值，页眉页脚、正文及附加信息不保存第二份可写配置。
不调整方向编码、分页算法、选区、翻页、Rust/FRB或JS配置快照。

保持亮屏仍缺少平台执行能力。保留keep_light键、原选择及选项，将设置行禁用并
追加“待实现”说明；不新增依赖、不将仅存储的选择宣称为已生效功能。
执行结果、设备及iOS未测边界仅登记在活动计划。

编写者：Codex｜2026-10-15


## 20. 自动翻页与操作分组

ReaderSettings.autoPageTurn保存ReaderAutoPageTurnSettings；interaction保存
ReaderInteractionSettings。两组都是纯Dart不可变值，继续使用同一个阅读仓储和共享
设置服务，不单独保存UI副本。ReaderInteractionCodec集中解码、范围和局部写入映射。

| 字段 | Preferences规范键 | 默认与有效范围 |
|---|---|---|
| autoPageTurn.enabled | reader_auto_page_turn_enabled | false |
| autoPageTurn.intervalSeconds | reader_auto_page_turn_interval_seconds | double / 10；3～120秒 |
| autoPageTurn.forward | reader_auto_page_turn_forward | true；前进/后退 |
| interaction.tapActions | reader_tap_actions | StringList / 九格动作名称，沿用原九宫格默认排列 |
| interaction.selectText | reader_select_text | true |
| interaction.noAnimScrollPage | reader_no_anim_scroll_page | false |
| interaction.volumeKeyPage | reader_volume_key_page | true |
| interaction.volumeKeyPageOnPlay | reader_volume_key_page_on_play | false |
| interaction.mouseWheelPage | reader_mouse_wheel_page | true |
| interaction.pageTouchSlop | reader_page_touch_slop | int / 0；0～9999，保持原阈值单位 |
| interaction.pageTouchClick | reader_page_touch_click | int / 0；0～399，保持原边缘规则 |
| interaction.progressBarBehavior | reader_progress_bar_behavior | page；page/chapter |

updateAutoPageTurn与updateInteraction只写传入字段，不覆盖其他分组。九宫格输入在
提交时复制冻结，快照中的动作列表不可变；存储仍为StringList，元素改用none、prevPage、
nextPage、toggleControls、openCatalog名称，不再依赖枚举顺序。读取损坏列表回退本字段
默认值；不读旧reader_adv_tap_actions_v1、旧三列或其他旧操作键，也不回写兼容副本。
AppSettingsService承接同一写队列、逐字段失败回退和订阅，未增加第二份已保存缓存。

TapAction与默认排列归纯数据模型；reader_tap_hit_test负责Flutter正文坐标的九宫格
命中。正文外忽略、边缘防误触及分区公式沿用原实现，配置模型不再导入dart:ui。
ReaderPageView的滑动阈值改读共享仓储，滚动模式仍使用系统阈值，不改手势识别算法。

设置页、菜单自动翻页按钮、浮条启停和间隔、音量键、正文选区开关、滚轮、滚动动画
和进度条行为读取同源值。ReaderScreen只在自动翻页分组改变时同步定时器，修改其他
设置不重置计时；保存失败后显示提示并按回退快照同步运行状态。原计时器的四舍五入、
方向与翻页调用保持；设置页滑块与既有浮条统一支持3～120秒，避免浮条选择大于60秒
后打开设置导致Slider越界。

浮条定位容器使用StackFit.expand，防止默认状态条全关时占位组件把Stack收缩为零，
导致浮条定位到屏幕外。不调整正文分页、选区或翻页动画。漫画音量键继续属于原Rust
配置域，与小说Preferences键分开；不改漫画、Rust/FFI、JS快照或数据库。
新键纳入备份的阅读设置忽略集合，已有仓储reload覆盖两组；未测平台边界见活动计划。

编写者：Codex｜2026-10-15


## 21. 阅读菜单配色与亮度控件分组

ReaderSettings.menuTheme保存ReaderMenuThemeSettings，brightnessControl保存
ReaderBrightnessControlSettings。两组都是纯Dart不可变值，通过原阅读仓储和共享设置
服务读取、订阅、局部更新及失败回退；ReaderMenuSettingsCodec集中解释键、范围与默认。
实际亮度值仍由原亮度控制流程管理，本组只决定菜单控件的显示方式和位置。

| 字段 | Preferences规范键 | 默认与有效范围 |
|---|---|---|
| menuTheme.mode | reader_menu_theme_mode | int / 0；0跟随应用、1阅读背景生成、2自定义 |
| menuTheme.paletteStyle | reader_menu_palette_style | 空串跟随应用调色板 |
| menuTheme.colorMode | reader_menu_color_mode | int / 0；0种子生成、1手动表面颜色 |
| menuTheme.accentColor | reader_menu_accent_color | int / 0；日间主色 |
| menuTheme.accentColorNight | reader_menu_accent_color_night | int / 0；夜间主色 |
| menuTheme.backgroundColor | reader_menu_background_color | int / 0；日间菜单背景 |
| menuTheme.backgroundColorNight | reader_menu_background_color_night | int / 0；夜间菜单背景 |
| menuTheme.containerColor | reader_menu_container_color | int / 0；日间弹层背景 |
| menuTheme.containerColorNight | reader_menu_container_color_night | int / 0；夜间弹层背景 |
| menuTheme.textColor | reader_menu_text_color | int / 0；日间标题文字 |
| menuTheme.textColorNight | reader_menu_text_color_night | int / 0；夜间标题文字 |
| brightnessControl.mode | reader_brightness_control_mode | int / 0；0关闭、1横向、2纵向 |
| brightnessControl.onLeft | reader_brightness_control_on_left | false；纵向侧栏位置 |

颜色保存ARGB整数，零值保留原回退语义。updateMenuTheme只保存传入字段，日夜值独立；
设置页的“编辑配色”仅为本地编辑状态，不写入共享仓储，重新进入跟随当前界面明暗。
updateBrightnessControl同样只保存传入字段；选择关闭或横向不覆盖既有侧栏位置，
菜单侧栏的左右切换只写onLeft。失败时显示提示并回退对应字段，允许再次操作。

ReaderMenuThemeHost消费共享菜单分组，保留原颜色生成及缓存条件、正文应用主题、
稳定的导航和弹层上下文。菜单本体读取同源模式、标题日夜颜色及亮度控件设置。
标题颜色仍独立于菜单来源；跟随应用模式的有效明暗以应用菜单主题为准。
不改配色算法、毛玻璃、菜单手势、正文分页或原生选区。

13项纳入阅读配置备份忽略集合及仓储reload；未增加独立缓存。删除高级配置中的
对应字段、读写和reader_settings_migration.dart最后一项菜单旧开关转换，不读旧值、
不自动改写旧键。同时移除通用UiSettings中没有界面消费者的readMenuBrightnessVertical
和readMenuBrightnessPos及其常量、仓储映射和Notifier写入口，不迁入无效值。
保留尚未迁移的自动换源、保持亮屏及标题附加区；后两项仍禁用。
Rust/FRB、JS快照和数据库不变；验证结果及平台边界仅登记在活动计划。

编写者：Codex｜2026-10-15


## 22. 剩余阅读设置与旧高级入口收尾

最后三项配置归入现有类型，不新建通用“高级设置”容器。ReaderSettings保存
自动换源和菜单标题附加区，ReaderScreenSettings保存保持亮屏时长；更新继续使用
原共享设置服务，订阅、备份恢复重读和逐字段失败回退均沿用同一来源。

| 字段 | Preferences规范键 | 默认与范围 |
|---|---|---|
| autoChangeSource | reader_auto_change_source | bool / true |
| showTitleAddition | reader_show_title_addition | bool / true；当前未启用 |
| screen.keepScreenOnSeconds | reader_keep_screen_on_seconds | int / 0；-1、0、60、300、600秒，当前未启用 |

update只修改传入的自动换源或标题附加区字段；updateScreen保存亮屏时长，与方向、
系统栏及安全区设置独立。保持亮屏的已有选项不变，未支持的时长读取和写入均解释为0，
不补写存储。三项不读取autoChangeSource、showReadTitleAddition和keep_light旧键，
不迁移旧值，不新增转换标记或兼容副本；新键纳入阅读设置备份忽略集合。

自动换源开关直接保存共享字段，失败显示提示并回退；ReaderScreen在章节错误发生时
读取共享当前值，保留原网络书判断、首个非同源候选选择、三次尝试上限、详情地址
保留及重开书流程。本轮不重构换源业务，也不把设置启用等同于立即发起搜索。
保持亮屏和标题附加区继续禁用，保留原说明并追加“待实现”，不执行新的平台操作。

ReaderAdvancedConfig及其复制、loadAdvanced/saveAdvanced、直接SharedPreferences
访问和独立写队列删除；readerAdvConfigProvider及其独立加载和可写状态删除。
AppReaderSettingsRepository只依赖AppSettingsService，领域接口不再导入旧UI模型。
ReaderConfigPanel仅接收展示分区，不传配置副本、回调或整份保存；ReaderSettingsSheet
直接加载统一仓储并订阅共享设置，不再等待独立高级Provider或传递无关配置。
ReaderScreen不再保留高级配置副本；原onOpenAdvancedConfig在菜单内没有消费者，
其参数和失效回调一并移除，实际“设置”按钮及其导航保持。

删除旧模型/Provider/独立队列的专属测试。原字体、排版、操作、菜单、页面和状态条
用例仍验证跨字段隔离，改为共享仓储更新其他字段；共享服务的并发加载、迟到读取、
序列化落盘和失败回退测试继续覆盖现行实现。新回归验证三项真实Preferences恢复、
不可变快照、范围、失败重试、外部重读及自动换源的实际触发和切换结果。
本轮不改分页、翻页、选区、Rust/FRB、JS快照、数据库或实际亮度执行流程。

编写者：Codex｜2026-10-15


## 23. 旧SettingsService失效入口清理

本节规定B4的保留边界；第6节的方法数量与消费者属于B1历史审计，不作为当前接口表。
进入本批时SettingsService还有56个公开异步方法，逐项核对生产调用和方法引用后
删除30个，只保留26个。SystemBrightness、AppLocaleNotifier、SyncNotifier的同名
方法分别承担原生亮度、语言及同步编排，不能误算成旧SettingsService的消费者。

| 删除组 | 方法数 | 判定依据 |
|---|---:|---|
| 旧亮度存储 | 2 | 阅读和漫画操作SystemBrightness，旧Preferences亮度读写无调用方 |
| 书架Tab/布局 | 4 | 由BookshelfSettingsRepository管理，旧方法无调用方 |
| 语言 | 2 | LocaleSettingsRepository及AppLocaleNotifier已是有效入口 |
| 旧代理和超时 | 8 | net_proxy_*与net_request_timeout旧方法无生产消费者，不迁成新权威配置 |
| 书籍进度同步 | 2 | BackupSettingsRepository为唯一普通偏好来源；SyncNotifier同名方法只是编排 |
| 删除书籍提醒 | 2 | BookshelfSettingsRepository为有效来源 |
| 阅读记录开关/排序 | 4 | ReadRecordSettingsRepository为有效来源 |
| 通用写入/删除及助手 | 6 | setBoolPref、setIntPref、setStringPref、removePref、getIntPrefOrNull、setColorPrefs无消费者 |

| 保留组 | 方法数 | 现有消费者 |
|---|---:|---|
| WebDAV连接 | 10 | SyncNotifier；原五字段、缺省、凭据及容错语义保持 |
| 远程服务器集合/选中项 | 4 | RemoteBookNotifier；JSON格式与默认服务器常量保持 |
| 同步扩展、自动同步、上次同步时间 | 6 | SyncNotifier；本批不改变功能接线或同步元数据边界 |
| 恢复忽略配置 | 2 | WebDavSettingsScreen；结构化配置及相关公开常量保持 |
| 通用读取与主题预设写入 | 4 | getBoolPref/getIntPref/getStringPref保留未接线选项原值和主题预设读取；setStringPrefChecked供主题预设写入并报告失败 |

删除方法专用的私有键常量，但不遍历或清空用户Preferences，不迁移原值，不新增
兼容层和替代服务。26个保留方法的实现逐一保持，主题预设检查写入结果的能力不变；
当前连接/恢复适配中已有的错误处理也不借本轮清理调整。

SettingsService不再描述为阅读设置服务，只作为尚存连接、结构化恢复及未迁移
读取的底层适配。后续先迁移这些实际消费者，再删除其剩余入口；不整类先删，
不为分类完整而建立没有有效消费者的仓储。未实现选项保持原说明、待实现提示和禁用状态。

删除仅验证旧亮度、语言及代理/超时读写的8项专属测试，保留已有WebDAV测试，
不新增只反映方法删除的测试框架。现有领域仓储、同步/远程书库、恢复及设置界面
回归继续验证实际行为；执行结果与平台边界仅登记在活动计划。

编写者：Codex｜2026-10-15
