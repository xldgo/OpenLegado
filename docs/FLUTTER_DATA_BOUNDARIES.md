# Flutter 初始化与数据访问职责拆分方案

本方案依据用户批准的渐进式重构方向，代码基线为
`feature/ui-reader-selection` 的 `74dda3c7b`。任务状态和验证结果只维护在
[活动计划](REFACTORING_ACTIVE_PLAN.md)，本文件记录设计与验收边界。

功能专属组件的归属迁移按[迁移方案](FEATURE_OWNERSHIP_MIGRATION_20261022.md)执行；
发现分类/书单/分页、任务调试、替换/RSS分组及系统TTS设置已归所属feature/widgets，
公共分组壳、登录基础组件及跨功能数据装配保持共享，不以目录迁移改变业务边界。
视频弹幕、浮窗按钮、长按倍速与设置弹窗集中在features/video/widgets，
其他设置页通过功能路径打开视频设置；平台浮窗服务仍保留平台/应用生命周期归属。
正文测量/编排、选区与翻页分别归features/reader/layout、selection、turn，
阅读私有控件及开书转场归widgets/navigation；朗读速度/定时/悬浮条及其转场归read_aloud/widgets。
旧widgets/reader不留转发壳；具体文件映射以Git重命名记录为准，不在文档维护第二份清单。
ReaderSourceAnchor属于domain/models，ReaderPositionStore的偏好读写属于data/repositories；
阅读会话消费两者，存储键与UTF-16锚点编码不因目录拆分改变。
布局传输契约在domain/contracts/reader_layout_transport.dart，结果、共享字形数据及诊断在
domain/models，串行会话在domain/services/reader_layout_session.dart；领域代码不依赖Flutter或FRB。
data/services/native_reader_layout_transport.dart独占原生句柄及DTO映射，应用装配通过
app/bootstrap/reader_layout_factory.dart提供默认实现，reader/layout的InheritedWidget只注入接口。
默认仍使用正式Rust传输；取消/释放边界与只读缓冲共享保持，不保留旧services排版转发入口。

音频跳过窗口经AudioBookService由Rust audio_skip_policy计算；播放器仅消费毫秒窗口并执行seek/切章。
ReadConfig.useGlobalAudioSkip完整透传，不能依据片头片尾是否为零推断作用域；相同输入的窗口结果可复用。
详情自动更新操作经BookshelfRepository.setCanUpdate提交稳定标识和目标状态，Rust事务读取最新书籍并只写策略字段；
界面在保存成功后接收返回快照，未入架仅更新临时展示对象，不将旧页面快照回写数据库。

后续设置领域的分类、键所有权、数据性质及迁移顺序统一见
[设置分类与访问架构方案](SETTINGS_ARCHITECTURE.md)。本文件保留已实施的数据边界，
不另外维护设置分类任务状态。

跨功能普通偏好使用 GeneralSettingsRepository，备份目录与有效进度同步使用
BackupSettingsRepository；图标和删除提醒分别扩展已有外观、书架仓储。日志服务
消费同源备份目录，保存和运行时应用分开，具体键及消费端见上述方案第 10 节。

阅读仓储使用 ReaderSettingsRepository / AppReaderSettingsRepository；字号、行距与翻页偏好
接入共享服务，高级配置保持独立格式。快捷、高级选择器与正文共用 PageTurnMode，
翻页只保存原名称键，旧有效索引只读回；字号和行距保持原double键、默认值与单位。
主题导入和配置注入消费同源值，保存失败回退，备份恢复显式重读。正文与标题字体
选择也进入该仓储；标题使用规范键reader_title_font_family，不读取旧titleFont。
字体目录由ReaderFontRepository管理，文件与注册归ReaderFontFiles，共享ReaderFontService
编排导入和加载。具体读写及备份恢复边界见上述方案第 11、13、14 节。

阅读结构化配色由 ReaderStyleRepository 单独拥有，ReaderStyle 同时包含日夜背景
和文字色，并复用共享设置服务。手动日夜覆盖归 ReaderThemeSession，仅当前阅读
会话有效；正文、预览和既有配置注入共享会话实例及颜色解析。纯色范围及上游差异见方案第 12 节，
不把颜色模板升级为另一套分页配置。

## Web服务生命周期

Web服务运行态由应用作用域的AppServicesController拥有，页面只订阅；启动入口执行一次
initializeWebService，前台恢复仅refreshWebStatus。ServiceSettings仅持久化自动启动意图
webAutoStart，经共享设置服务写入Rust配置webServiceAutoStart，默认false；运行开关不写设置。
运行查询、手动启停与自动启动共用LocalServerService和WebKeepAliveService，不新增FFI或平台桥。
旧webService偏好不读写、不迁移；查询失败不伪装停止，过期查询不覆盖新操作，页面刷新保留启动失败原因。

编写者：Codex + UI｜2026-10-21

## 错误边界

领域错误由`domain/errors/app_exception.dart`定义，不依赖FRB。数据适配器通过
`data/bridge/rust_errors.dart`统一转换同步、Future和Stream中的BridgeError，
保留可见消息、操作名、原始cause及堆栈；已转换的领域错误和普通异常不重复包装。
取消令牌、取消结果、流订阅和句柄释放继续由原调用方管理，不依据错误文本推断取消。

界面和公共展示工具只消费领域消息，使用`utils/error_message.dart`处理空消息回退；
登录引导保留自己的识别与展示规则，不依赖生成错误类型或动态message探测。
原RustApiException并入领域错误，不保留第二套同义类型。直接调用FRB仍返回原桥接错误，
领域转换只发生在数据适配边界，不改Rust签名或生成绑定。

编写者：Codex + Bridge/UI｜2026-10-18

## 书架导入编排

`features/bookshelf/application/BookshelfImportController`复用书架、书源、书源查询、
网络及搜索窄接口，承接网址匹配、远端书单拉取、解析、去重和串行入架。
不持有Widget或Ref，不另建书架存储；装配层注入读取当前书架的回调，保留网址添加
开始时、远端书单下载后分别读取快照的时序。匹配优先级、失败回退和统计规则保持原样。

页面负责对话框输入、mounted判断、刷新及本地化结果提示；只有完成结果触发原有刷新，
格式和拉取失败直接显示错误。导入结果不携带界面文案，Rust/FRB契约无需变更。
网址输入框使用内部控制器，随对话框真正卸载释放，避免退场动画读取已释放控制器。

编写者：Codex + UI｜2026-10-18

## 路由装配边界

`app/routing/route_names.dart`只定义路由名称，不导入页面或Flutter；
`route_arguments.dart`保存VideoScreenArgs，只依赖Book模型；详情页接收Book，不再有未读自动开读参数。
feature、公共Widget及服务只消费名称或参数，不能反向导入页面路由表。

`AppRouter`持有唯一页面工厂表，createRouter装配go_router和AppRoutePage；正式实例随LegadoApp的State存活，
主题变化不新建Router；Page身份同时包含入口key和完整URI，查询参数变化不沿用旧页面初始化状态。
Page.createRoute复用原封面、换源和朗读Route，settings始终为Page自身。
AppNavigation只统一稳定身份的URI编码与push/替换语义，局部Sheet和操作页继续直接Navigator，
生产不保留generateRoute、pushNamed或缺Router时的旧框架回退。胶囊展开直接复用原朗读Route以等待图片交接完成。

搜索、正文搜索、浏览器和任务参数使用明确类型；Book及动效引用放extra，稳定书籍键/搜索范围进入URI。
ReaderRouteEntry在initState缓存身份读取，门禁后最多激活一次；激活后门禁跟随实际全局阅读会话，
换源或换书不会继续拿旧快照授权新正文，重新授权也不重开旧书。不存在的书籍展示可重试错误。
新地址不使用最小Book覆盖目录/编辑所需的完整数据，这些操作页缺参沿用原首页兜底。
未知路径以正常匹配的首页承载，避免错误匹配状态妨碍后续导航；57项输入/结果及方案见
[路由清单](ROUTE_INPUTS_20261019.md)、[迁移约束](ROUTING_MIGRATION_PLAN_20261019.md)。

编写者：Codex + UI｜2026-10-19

## 视频播放会话

`features/video/application/VideoPlaybackController`复用既有读取、书源、弹幕、直链进度
和悬浮窗能力，拥有章节/播放目标编排、播放器初始化、定时进度及MPD文件归属。
`VideoScreen`在didChangeDependencies绑定一次依赖并注入，异步操作和退出写盘不再读取
页面context或Provider；页面保留渲染、提示、对话框、全屏系统栏与导航。

每次播放请求有独立代次；正文/弹幕/临时目录等异步结果回写前核验归属。初始化还捕获
具体播放器，seek/play完成后再次核验，避免迟到任务操作新实例。替换前等待旧播放器释放，
退出时移除监听、停止定时并释放资源；released可等待已拥有资源的释放，不宣称取消底层
网络请求。迟到网络结果被丢弃，迟到创建的MPD由对应操作自行删除。

悬浮窗移交中的MPD由接受结果决定归属：原生接受后保留，失败或未移交则清理；预置MPD
重试保留正在复用的路径，退出时统一释放。设置定义移至application/video_play_settings.dart，
读写键、默认值及SharedPreferences通道原样保留，对话框不再作为数据类型的导出入口。
现有video_player后端、悬浮窗原生协议、焦点和视觉样式保持不变。

编写者：Codex + UI｜2026-10-18

## 阅读器分页编排

`features/reader/application/reader_pagination_policy.dart`集中计算内容区/双页尺寸、
重排签名、完整章节缓存身份、目标页就绪与恢复、相邻章预载方向和异步任务归属。
策略只消费明确的参数和布局数据，不持有BuildContext、Ref或排版会话；普通测试可
独立核验配色不失效、几何失效、原文锚点、末页请求及预载距离规则。

`ReaderPageView`负责取得实际约束和文字环境、测量页眉/页脚/标题/段评、推进既有
ChapterPaginationSession，以及渲染、选区、翻页和状态发布。页眉/页脚/标题只在需要
重排后测量；纯配色、菜单和段评正数计数更新继续复用布局。主章和相邻章共用缓存键，
沿用ChapterLayoutCache三章与16MB估算预算，不缓存Widget或TextPainter。

异步分页与预载在等待后核对书籍、章节和布局代次，退出或任务失效后不发布旧结果。
这不等同取消底层章节网络请求。Dart文字测量、Rust断行/分页算法与FRB传输、原文坐标、
预载范围和翻页交互均保持；任务状态和验证证据只维护在活动计划。

编写者：Codex + UI｜2026-10-18

## 实施顺序

1. 提取初始化内部职责：应用 Bootstrap 编排，Bridge 加载原生库并调用 FRB，
   Platform 获取设备信息和目录，设置层生成纯数据配置快照。
   启动和阅读配置刷新复用同一个注入实现，消费者依赖可替换接口。
2. 引入书签窄接口：先由适配器委托现有 BookApi，迁移 Notifier、目录导出及测试。
   维持已完成的原子更新语义，不引入另一份 CRUD 实现。
3. 书签适配器直接调用 FRB；确认所有消费者已迁走后删除旧 BookApi 方法及临时
   适配器。Mock 实现同一窄接口，根实例只保留共享 Repository 的装配引用。
4. 整理书签功能目录，再按阅读记录、朗读引擎、书架与分组、书源、搜索、
   设置与备份、阅读会话外围逐域迁移。沿用 `lib/src/`，不创建无消费者的空目录。

## 第一步的模块边界

| 位置 | 职责 |
|---|---|
| `lib/src/app/bootstrap/` | 工厂装配、初始化顺序、失败策略、设置快照与注入协调 |
| `lib/src/data/bridge/` | 原生运行时适配、库加载、配置数据与注入接口 |
| `lib/src/platform/` | 设备 ID、数据库及缓存目录、本地书路径预热 |
| 现有 `RustApi` | 业务访问与生命周期委托，不读取设备、主题或设置 |
| Riverpod 注入层 | 提供同一个已初始化 BookApi 与阅读配置刷新接口 |

第一步保留顺序：原生库加载和 FRB 初始化 → 引擎初始化 → 数据库打开 → 本地书
路径预热 → TTS、JS、图片、音频缓存目录 → 设备 ID → 主题配置 → 主题模式 →
阅读配置。预热、各缓存目录、设备及配置注入仍尽力而为；库或数据库失败仍阻止启动。
主题配置写入成功后才读取并注入主题模式，保留原失败时的部分成功语义。

数据库、缓存目录和设备获取分支保持原行为，iOS 保留进程静态符号加载；桌面库
搜索顺序不变。JSON 键、数值类型、颜色格式、亮色调色板、阅读默认常量及回退
规则保持原样，不借重构修正快照内容。SharedPreferences 存储位置和键不变。

BookApi 生命周期签名与正式启动时实例身份不变；新增的 Dart 内部依赖注入不
改变 Rust FFI、FRB 生成代码、书源协议或数据库结构。已由测试直接初始化原生库
的入口显式提供生命周期委托，端到端入口使用应用工厂完成同样的完整初始化。

## 第二步的书签边界

`domain/contracts/bookmark_repository.dart` 定义只依赖现有书签模型的接口。
六项操作为全部查询、按书名与作者查询、新增、原子更新、删除及搜索；原文偏移、
书签 id、创建时间、查询排序、错误及搜索语义均沿用当前实现。
旧按书名查询没有应用调用方，不加入新接口。第二步先保留旧方法供迁移，第三步收口删除。

第二步使用临时 `BookApiBookmarkRepository` 适配器，所有方法
单向委托当前 BookApi，不另存状态，不初始化或重新打开数据库，不重写 CRUD。
第二步的 `providers/bookmark/bookmark_repository_provider.dart` 通过 Riverpod 监听根
BookApi Provider 并装配适配器；测试可直接覆盖窄接口，无需实现巨大 BookApi。

书签 Notifier 与目录导出改读窄接口。书签页、目录书签 Tab、正文菜单及选区
仍复用同一个 Notifier；第二步接口迁移保持原有状态管理、文案和用户交互。
该步不新增编辑界面，更新接口由既有 Mock 和真实 FFI 回归保护。

## 第三步的直接适配与收口

`RustBookmarkRepository` 直接调用现有六项 FRB，保留原字段、查询排序、
返回值及错误；不初始化原生库、不重新打开数据库、不增加缓存或业务规则。
原 JSON 解码守卫提取到 `data/bridge/rust_json_decode.dart`，巨大接口的
其他域仍委托相同守卫，避免两份格式判断和错误截断逻辑分叉。

`MockBookmarkRepository` 拥有唯一的会话书签列表，原全量查询、双键查询、
50ms 延迟、搜索和更新行为原样迁移。装配时注入原 MockBookApi ID 分配器，
不改变与其他 Mock 实体的原分配策略；独立测试也可使用自己的会话分配器。

应用工厂向 RustApi 注入正式 Repository；MockBookApi 装配自己的 Repository。
BookApi 只提供 `bookmarkRepository` 引用，Provider 直接共享这个引用，替换
根实例时跟随其引用。书签 Notifier、目录导出及页面继续只依赖窄接口。
旧 BookApi 的七项书签方法、原业务 part 中的书签实现和临时适配器删除。
旧 Rust/FRB 的仅按书名查询导出保留，不进入新领域接口，不修改原生契约。
不允许 Repository 反向调用 BookApi，不存在双向转发或两套 CRUD。

## 第四步的书签功能目录

书签页面、Notifier、State、对应 Freezed 生成物和 Repository Provider 集中到
`lib/src/features/bookmarks/`，备注面板放在其 `widgets/` 子目录。
`bookmarks.dart` 作为对外入口，显式导出页面、Notifier、状态、注入 Provider
与备注面板；目录页、阅读器、路由和相关测试通过此入口引用所需能力。
功能内部使用直接文件引用，不反向导入对外入口，也不保留旧目录的转发文件。

领域接口和正式、Mock 数据实现仍位于 `domain/contracts/`、
`data/repositories/`；共用控件及书签导出格式工具保留原位置。
同一 Provider 声明只移动一次，不重复装配，不改变其生命周期或实例身份。
State 和生成物一起移动，`part` / `part of` 的文件名保持一致，生成内容不手改。
这一步只调整文件位置与 import/export，不修改状态转换、字段、文案或界面布局。

## 第五步的阅读记录边界

`ReadRecordRepository` 负责全量查询、累计时长写入、按书名删除、清空及按年查询
每日秒数。正式实现直接使用现有五项 FRB，并复用 JSON 解码守卫；不打开数据库、
初始化运行时、增加缓存或在 Dart 重算每日时长。根对象只保留共享 Repository
装配引用，Provider 跟随根实例替换。Mock 的唯一记录列表迁入独立实现，保留
原来按书名替换及每日列表为空的语义，不增加另一份统计状态。

阅读记录页、按天视图、Notifier、State 和注入入口集中到
`lib/src/features/read_records/`，外部通过 `read_records.dart` 使用功能。
首页、热力图和阅读器的记录读写改用窄接口；书架查书继续用现有书架入口，
排序、同名时长合并、记录开关、累计毫秒、失败不阻断阅读等行为保持原样。
旧 BookApi 六项阅读记录方法及两份业务 part 实现删除；其中无代码调用方、
重复写入同一 FRB 的 `recordReadingTime` 别名不进入新接口。

正式存储与 Mock 的既有差异保持明确：Rust 决定 lastRead/deviceId 并按整秒差值
累计每日时长，Mock 完整保存输入记录；不会把 Mock 的行为误作移动平台证据。
本轮只改 Dart 接线，不修改 Rust/FRB、数据库、进度坐标、应用版本或 UI。

### 阅读记录后续三视图演进（2026-10-13）

用户授权阅读记录对齐参考版三视图，替代第五步的旧按书/按天页面。
当前契约以API_CONTRACT §2.12十项为准：真实每日明细、原始会话查询与删除，
累计/每日/会话在Rust事务内写入和清理。书籍身份按书名/作者区分，会话另保存
副本URL和章节序号；不据累计值推造历史会话。Mock独立复现相同的增量和删除语义。

ReadRecordListCalculator承担日期分组、作者搜索、最新记录与20分钟会话合并，
ReadRecordListProvider组合未过滤快照、会话查询和控制状态；页面只呈现并发起动作。
记录页搜索不影响首页/总览快照，变更通知统一驱动刷新。旧每日总时长组件及其
专用分组算法删除；仍保留每日秒数契约供现有调用方。章节标题通过既有目录接口
按副本URL/章节序号读取，缺失时展示章节序号，不在UI伪造正文或阅读区间。

编写者：Codex｜2026-10-13

## 第六步的朗读引擎边界

> 2026-10-13 T2a/T2b 后继约束：HTTP 不再执行失败 GET 探活；合成结果显式区分音频、失败、空产物、Mock 与取消。`HttpTtsCancellation` 由段落引擎持有，正式适配器映射到同步可取消的 FRB 请求句柄；Rust 统一源变量/登录、请求规则、重试、限流与缓存。登录控件增加 `SourceLoginSession` 窄接口，TTS 适配使用 `httpTts:<id>`，不构造 BookSource。下文第六～八步保留当时结构提取的说明，当前协议以 API_CONTRACT §2.42 为准。



用户调整领域顺序，先处理朗读引擎，书架与分组后置。按职责分三批推进：

1. `HttpTtsRepository` 管理 HTTP 引擎配置，正式实现直接使用已有 FRB，
   Mock 独立拥有列表。配置页、默认种子导入和注入入口集中到
   `features/read_aloud/`；播放会话、朗读条选择器与关联导入共同使用窄接口。
   保留当前七项配置操作、默认样例、ID、字段和导入失败边界，删除无调用方
   的 `getHttpTtsList` 别名。根对象只提供装配引用，不保留旧 CRUD 转发。
2. HTTP 合成与配置存储分离，明确本地产物、缓存和合成失败的结果；系统 TTS
   继续作为独立平台能力。先核对当前探活与估算回退，行为调整另行确认。
3. 在前两批稳定后提取播放会话所需的引擎协议，复用已有完成、进度、暂停、
   停止和会话代数保护；后续功能按用户需求逐项增加，不整体重写 AudioNotifier。

第一批不改变书级/全局偏好、系统语音设置、音频焦点、后台媒体会话、合成、
正文获取、数据库及 Rust/FRB。系统引擎固定标识仍为 `system://default`，
不把平台语音虚构成 HTTP 配置或新增第二份权威引擎状态。

第二批的 `HttpTtsSynthesizer` 与配置 Repository 分开；正式适配直接调用 FRB，
返回本地产物或明确的无产物结果，不另存音频缓存。原合成失败后 GET 探活的
替换顺序、状态码解析及 30 秒超时保留；探活成功没有音频，播放会话仍提示并
估算推进。该回退策略存在听不到声音却继续推进的边界，行为调整留待后续裁决。
无应用调用方的原始 Map 合成及缓存设置包装从 BookApi 删除；Rust 原生导出保留，
缓存目录只由现有 Bootstrap / NativeRustRuntime 注入。

系统 TTS 的数据类型和 `SystemTts` 接口位于 `platform/tts/`，插件实现单独存放；
语音设置与 AudioNotifier 只依赖接口。系统和 HTTP 注入位于 `features/read_aloud/`，
HTTP 共享根装配引用，系统实例仍按原播放会话持有，不添加另一份生命周期。
插件的操作串行化、停止确认、分片、进度、暂停恢复及设置键均保留。

第三批提取 `ReadAloudEngine` 与段落级 `ReadAloudSession`，HTTP 文件播放与系统
朗读适配共用起播、暂停、恢复和停止协议。请求是不可变参数快照；完成、进度
及异步错误携带同一会话归属，完成只能消费一次。会话有效性委托现有播放 token
和合成代数，不新增第二组全局计数或书籍、章节权威状态。
HTTP 合成结果过期后不能装载播放器；播放器事件保留归属标签，并由 HTTP 适配
换算为段内 UTF-16 偏移。系统回调沿用插件停止确认和真实偏移，暂停恢复创建
新回调会话。两条路径的过期完成、进度与错误均不能推进或改写当前朗读。
AudioNotifier 继续拥有正文队列、原文映射、段间停顿、定时、媒体会话和音频焦点；
音频书仍直接使用共享播放器，其回调不进入 TTS 会话。插件及播放器沿用原有
生命周期，不由新增 Provider 重复销毁。HTTP 失败估算与系统失败暂停保持原样。
异步控制错误也校验发起时的 token / 合成代数：当前系统错误保留原提示，当前
HTTP 暂停或停止错误改为可见提示并保持暂停/空闲，旧会话错误只记诊断日志，
不再改写新会话；文件播放控制错误不作为未处理的 Future 错误逃逸。

HTTP 原位续播继续沿用该边界：适配器保留已加载段落的音频与请求文字长度，
暂停使旧回调会话失效，恢复在同一播放器上换绑新会话而不重新合成。
AudioNotifier 保留原请求的段内起点与章内映射，按会话等待暂停确认；停止、
切章、换段与换引擎清除旧暂停屏障。共享播放器核对预期 tag 后才允许换绑，
音频书的普通 resume 不受影响。装载未完成时暂停取消请求并停止，后续重新起播；
插件平台替身覆盖 Dart 协议，Android/iOS 的后台与真实中断仍需设备验收。
方法与来源见 [朗读对齐文档](TTS_ALIGNMENT.md)，任务状态只维护 Active 计划。

HTTP 预合成由独立 `HttpTtsSynthesisQueue` 管理前台优先、任务提升、并发与窗口取消；
AudioNotifier 提供正文/配置快照及章节加载入口，不保存第二份音频缓存。
Rust 仍是规则求值、音频文件和索引的权威，`TtsCacheRepository` 提供窄接口，
管理页与设置页不直接操作文件系统。音频的原生句柄移交成可释放租约，播放后
停止播放器再释放；后台只完成索引登记并释放。清理保护合成中与播放中音频，
退出清理使用捕获的配置和状态快照，不再访问已销毁 Ref。即听即焚和分钟保留
消费上游设置键，不添加数据库迁移。方法与接口详见 API_CONTRACT §2.42。

## 第九步的书架与分组边界

先引入 `BookshelfRepository` 十项现有书架操作与 `BookGroupRepository` 五项
现有分组操作。书籍所属分组写入归书架接口，分组定义与显隐写入归分组接口。
两个临时 `BookApi*Repository` 适配器只单向委托当前 BookApi，不存书籍或分组、
不初始化数据库、不新增业务算法，不在新旧接口各实现一份 CRUD。
Provider 监听同一个根 BookApi，分别共享适配器；根被替换时两者跟随替换，
测试可以只覆盖窄接口，不创建 BookApi 或原生运行时。

本批迁移书架 Notifier、书架管理 Notifier、书架页、书架管理页和分组页中对应
数据访问。来源查询、换源、目录刷新与本地书解析仍用既有业务入口；书架布局、
分组过滤与视频聚合、Tab 位置、拖拽排序、批处理错误边界和展示状态保持原样。
不移动整套功能目录，不修改阅读位置、Rust/FRB、数据库、版本或界面。
保留原分组写入的能力差异：正式 updateBookGroup 只传名称、封面和顺序，Mock
替换完整对象；专用显隐接口与页面当前调用方式不借本次重构改写。

第二批用 `RustBookshelfRepository` 与 `RustBookGroupRepository` 直接接入现有
FRB，复用 JSON 守卫，保留空单本结果、全对象写入、置顶、排序与分组参数。
MockBookshelfStore 拥有唯一书籍列表及惰性加载 Future；书架 Repository 与旧
章节、进度和本地导入模块共用此存储，样例资产与章节缓存生成算法不变。
分组列表归 MockBookGroupRepository，种子及根 ID 分配顺序保持。
BookApi 只装配两个共享引用；所有剩余书籍消费者改读这些引用或窄 Provider，
删除旧十五项方法、两份业务 part 实现及临时适配器，不保留反向委托。
阅读位置写入仍走既有 updateReadingProgress；系统生命周期与书源解析不搬进
Repository，音频会话的根实例缓存及退出写入归属保持原样。

## 第十一步的书架功能目录

三个页面、书架与管理 Notifier、State 及对应 Freezed 生成物集中到
`lib/src/features/bookshelf/`。仅书架使用的网格项、列表项和分组名称辅助函数
放在 `widgets/`，多页面共用的 BookCover 与通用控件保留原位置。
`bookshelf.dart` 显式导出页面、Notifier、状态与展示扩展、注入 Provider，以及
需要跨功能使用或独立测试的书架组件。路由、其他页面及测试通过此入口引用，
功能内部直接引用所需文件，不反向导入自身入口，不保留旧目录转发文件。

领域接口和正式/Mock Repository 保持既有位置；根实例与注入链不重建。
这批只改变路径和 import/export，不调整分组过滤、排序、批处理、页面布局、
选中状态、阅读位置或加载顺序。两个 State 的生成物与声明同址，由当前锁定
生成器完整生成并检查重复执行稳定性，同时确认无关生成物没有 Git 差异；
避免仅筛选两个输出导致其他既有生成文件被清理，不混入模型或 FRB 更新。
仓库自动化直接引用旧路径时同步到新目录，工作流职责与触发策略保持。

## 第十二步的书源数据边界

BookSourceRepository 封装十一项已有数据操作：全量及启用列表、增改删、启停、
导入导出、排序偏好和源变量。正式实现直接使用现有 FRB 与共用 JSON 守卫；
写入成功后调用装配点注入的失效通知，保持 CoverDecodeLoader 原注册表刷新
语义与时序，数据实现不依赖 Flutter 控件、BookApi 或封面加载器。

MockBookSourceStore 拥有唯一源列表，原默认种子与校验任务借用同一存储；
排序配置通过注入的写入回调共用根配置表。保留列表副本、空目标更新/启停的
空操作、变量写入延迟及缺失报错，导入依旧仅返回数量，不新增合并规则。
根 BookApi 仅持有同一个 Repository，Provider 跟随根替换，所有十一项旧方法
和业务实现删除；业务消费者更新访问对象，搜索/登录/校验/JS 解析与替换规则
仍用原能力，混合操作保留其顺序、根实例与失败处理。

这一批不搬书源页面目录，不调整 SourceNotifier 状态转换、导入策略或书源
格式。现有消费者与隔离数据库的 Windows FFI 回归保护行为，移动端构建及
真实站点验收另行执行，不修改 Rust/FRB、版本或依赖。

## 第十三步的书源功能目录

管理、编辑、导入确认和 JS 编辑四个页面及其七个 part 文件，SourceNotifier、
SourceState 及 Freezed 生成物集中到 `features/book_sources/`；书源卡片、规则
帮助面板和书源分组管理包装放入该功能的 `widgets/`。登录、调试、校验与
SourceImportService 保留现有路径，这批不改其实现或生命周期。

`book_sources.dart` 显式导出页面、状态、Notifier、Repository Provider 与需要
跨功能引用的专用组件；外部消费者使用该入口，内部直接引用所需文件，不反向
导入自身入口。所有旧路径移除，无转发文件；part 与 part of 保持同库关系。
共享的 SourceEditor、SourceSelectionBar、GroupManageDialog 保留 widgets。
AppColorsExt 是三种导入确认共用的配色辅助，抽至 `theme/import_status_colors.dart`，
书源、订阅源及替换规则均直接引用它，避免为共用配色依赖另一个功能的页面。

本批只调整路径、import/export 与共享辅助类位置；方法体、状态字段、规则字段、
页面布局、导航参数和异常处理保持。完整生成使用原锁文件和 Pub 镜像复核，
重复生成不产生新内容；不手工改写生成物或升级依赖。任务状态与证据见 Active。

## 第十四步的导入职责拆分

| 位置 | 职责 |
|---|---|
| `domain/models/import_result.dart` | 多种导入共用的结果计数、错误与汇总 |
| `domain/models/source_preview.dart` | 保留原始 JSON，宽松提取展示字段 |
| `domain/services/source_import_parser.dart` | 统一 JSON 对象/数组解析、预览及必填校验 |
| `data/services/source_import_service.dart` | 预览输入、逐条替换与入库、导入结果和错误边界 |
| `platform/source_import_file_reader.dart` | UTF-8 文件读取，缺失返回 null，读取失败保留异常 |
| `app/bootstrap/source_import_factory.dart` | 为一次导入绑定同一根的 Repository、GET、替换规则和文件能力 |

导入服务只接收 BookSourceRepository 及三个明确的回调，不依赖 BookApi、
Flutter 组件或 dart:io。应用工厂沿用 bridgeHttpGet 与 30 秒超时，不创建
另一个网络客户端，不初始化原生库或缓存服务实例。两个 Notifier 保持每次
获取服务的原生命周期；已开始的导入保留其根引用，后续获取跟随 Provider
替换。JSON 扫码预览直接调用纯解析器，不创建导入服务或根实例。

预览不应用替换规则、不写库，保留字符串数字、字符串布尔、未知字段及原始
JSON Map。确认导入仍依次校验每项、应用书源作用域替换、以单元素数组提交
Repository；规则调用失败继续使用原文，一条写入失败不阻断后续条目。
成功计数继续按完成的条目计算，不改为 Repository 返回数量；非对象失败、
缺必填字段跳过，既有非字符串必填字段的确认失败边界保持。

HTTP 状态、JSON 类型/语法、文件缺失/读取失败维持原文案与异常边界。
旧本地 TimeoutException 与 dart:async 同名，但无生产抛出点；本批删除
该类型及不可达分支，真实异步超时仍进入原 URL 失败提示，未扩展错误策略。
共享导入结果与预览模型直接由其消费者引用，不经导入服务聚合导出。
旧 `services/source_import_service.dart` 移除，不保留转发。

本批不改变页面布局、状态转换、Rust/FRB、书源格式、数据库事务、依赖或
版本。纯解析、输入、序列编排与实例装配由定向测试保护；移动平台、实际网络
和设备交互验收另行执行，状态及证据只记录在 Active。

## 第十五步的书源校验边界

| 位置 | 职责 |
|---|---|
| `domain/contracts/source_checker.dart` | 单源校验、批量进度流、取消三项窄接口 |
| `data/services/rust_source_checker.dart` | 原 FRB 直接适配与共同 JSON 守卫 |
| `data/services/mock_source_checker.dart` | 原 Mock 结果与延时，读取唯一 MockBookSourceStore |
| `features/book_sources/source_checker_provider.dart` | 分享根引用，新获取跟随根替换 |
| 原 CheckSourceNotifier | 校验配置、界面状态及一次会话的实例/订阅生命周期 |

根 BookApi 仅提供 SourceChecker 引用，正式装配由 Bootstrap 注入，Mock 与
书源 Repository/默认种子共用同一存储；三项旧方法及两份 part 的实现移除。
单源 JSON、批量 URL 顺序、configJson 的 null→空串、进度解码与错误上下文
不变，数据实现不引用 BookApi 或 Flutter 组件，也不初始化原生库或数据库。

开始校验在首次异步准备前绑定调用实例并设置准备标记，避免配置读取期间重复
启动。准备、订阅和每个事件使用同一会话代数；取消绑定发起实例，不从替换后的
根获取。取消先隔离回调，再调用取消并解除订阅，下一轮等待清理 Future 完成。
清除消息和销毁也隔离会话，准备完成及旧进度/异常/完成事件不得恢复过期状态，
重复末条不得重复发起失效分组回写。当前配置失败仍上抛，流创建失败解除运行态，
当前流错误保持 cancelled；显式取消失败仍传递原异常，订阅清理执行于 finally。

关键词/配置键、默认值、存储格式、结果消息和正常完成的失效分组处理原样保留。
Mock 显式取消仍为空操作，UI 通过订阅及会话代数停止接收；正式 Rust 取消标志
仍是进程级，不因新 Dart 实例变成独立原生任务，也不承诺即时中断在途网络请求。
本批不扩大 Rust 并发或中断契约，不调整页面、数据库、版本、依赖或生成代码。

契约行数保持 294，BookApi 从 243 减为 240，SourceChecker 独立承担 3 项。
窄接口覆盖、共享存储、会话竞态及消费者由定向测试保护；已有 Windows DLL
在隔离数据库执行离线单源、批量与取消，不以此代替实际站点或移动设备验收。
任务状态和证据仅记录在 Active。

## 第十六步的登录凭据边界

| 位置 | 职责 |
|---|---|
| `domain/contracts/source_login_repository.dart` | 原始 userInfo/loginHeader 的四项读写 |
| `data/repositories/{rust,mock}_source_login_repository.dart` | FRB 直接适配或根实例的唯一字符串存储 |
| `domain/models/source_login_credentials.dart` | 手动编辑的不可变快照，不代替原始仓库协议 |
| `domain/services/source_login_codec.dart` | 原 Token/Cookie/Header 宽松转换与旧配置解析 |
| `data/services/source_login_service.dart` | 加载回退、Header→Info 顺序保存、旧键尽力清理 |
| `app/bootstrap/source_login_factory.dart` | 注入同一根的 Repository 与原配置键回调 |
| `features/book_sources/source_login_providers.dart` | 共享存储和服务引用，跟随根替换 |
| 原 SourceLoginNotifier/Screen | 按 URL 隔离草稿、请求身份、输入回填与保存呈现 |

Root 只提供 SourceLoginRepository 引用，四项旧方法与两份 part 中的实现
移除；Mock 两个 Map 归入唯一 Repository，不保留两套凭据数据。
仓库继续接受原始字符串，经典表单的任意 JSON 字段、V2/JS 写入结果和
WebView 登录头格式保持。手动快照不扩展为整个登录系统的统一存储模型。

登录服务顺序读取 Info 和 Header，仅两项均为空时读取旧配置；回退只转换
展示，加载不写库、不清旧键。保存开始时生成两份 JSON，先 Header 后 Info，
两次成功后才尽力清理旧键；第二次失败保留已完成的第一项，不伪造原子事务。
转换保持 Cookie 大小写判断、首个等号拆分、重复 Header 覆盖及原容错规则。

手动 Notifier 使用按 URL 的 family + autoDispose，页面订阅时保留该源草稿，
无消费者时释放。load 无数据明确清空，后发请求、编辑或清空使旧回填失效；
销毁后不再修改状态。save 固定源、服务和输入快照，在途重复调用返回同一
Future；错误保留输入、结束等待并可重试，已开始的保存仍完成原写入顺序。
页面切源清空输入控制器并加载新源，Token 的用户输入同步使旧加载失效，
回填前核对源与编辑代数。保存成功先关闭等待遮罩，再返回 true 退出页面；
失败只关闭遮罩，保留页面和输入。

经典登录框仅注入凭据 Repository 和原 exploreEvalAction 回调，不拥有整个
BookApi。WebView 仅注入 Repository，原 iOS/Android Cookie 分支保持；
阅读器购买网页也使用相同窄接口。V2 判定和动态脚本继续原入口，本批不拆分。
目录位置、界面布局、Rust/FRB、数据库、版本与依赖不变，专题状态与证据见 Active。

## 经授权追加的备注编辑

书签页、目录书签列表及阅读选区新增共用底部输入面板。界面只处理原文呈现、
备注输入、保存等待和取消确认，经同一个 Notifier 与窄接口持久化。
新增时原文与备注分开保存，默认空备注；编辑只改变 content，保留 id、time、
原文和章节位置。写入成功后才更新列表并关闭；失败保留输入和旧列表。
用户关闭前确认未保存修改，遮罩和拖拽不直接关闭，保存期间禁止重复提交。
本批不改变 Rust/FRB 契约或数据库结构，完整状态与验收边界记录于 Active 计划。

## 状态归属

| 内容 | 归属 |
|---|---|
| 界面显隐、选区、滚动与翻页动画 | Flutter 页面及会话 |
| 字体测量、正文绘制 | Flutter 平台适配 |
| 中文断行、分页、行内元素纯计算 | Rust `legado-layout` |
| 布局结果缓存与任务协调 | Flutter 阅读会话 |
| 书架、书源、书签、持久化阅读位置 | Rust 数据层 |
| 主题、阅读偏好 | 现有设置持久化层；Rust 接收只读快照 |
| 搜索展示状态 | Flutter Notifier |
| 搜索调度、取消与并发控制 | Rust 业务层 |
| TTS 插件、媒体会话与音频中断 | 平台适配与播放会话 |

允许 UI 保存展示快照和缓存，写入、刷新、失效规则须明确。Dart Repository
封装访问、转换和错误，数据库事务及业务规则不从 Rust 复制到 Dart。

## 第一步验收

- 固定输入下比较主题及阅读 JSON 的完整字段和值，并覆盖所有主题模式、背景
  索引、非法索引及字号取整；快照不得持有可变输入的引用。
- 覆盖初始化顺序、成功后重复调用、库与数据库失败，以及非关键步骤失败后
  继续初始化；主题模式读取失败不得撤销已经成功的主题配置注入。
- 覆盖设置刷新委托、Mock 空操作、工厂选择及根 Provider 实例身份。
- 定向静态分析和现有启动、阅读设置、契约回归通过；真实原生库验证不替代
  Android/iOS 设备行为，不触发全量 CI 或自动提交推送。

## 第二步验收

- 单独覆盖窄接口即可测试 Notifier，不触发 BookApi 或原生运行时创建。
- 加载、搜索和增删的状态及失败行为保持；按书名与作者查询隔离同名书。
- 根 Provider 替换后适配器跟随替换，多个书签消费者共用同一适配器。
- Mock 与真实 Windows FFI 经新适配器重复更新保留 id、创建时间和其他记录；
  更新失败保留原记录，异常原样传递。
- 既有目录及选区交互回归通过；定向静态分析、契约与启动回归通过。

## 第三步验收

- 接口六项与正式、Mock 实现一致，旧 BookApi 方法不再存在，契约计数闭合。
- 查询返回的集合不能改写 Mock 内部存储，独立会话不串数据；新增沿用原 ID
  分配，更新保留 id 和时间，失败完整保留原记录。
- 多个消费者与根实例共享同一 Repository，替换根实例后跟随替换，不触发初始化。
- 共用 JSON 守卫的原始字段、异常和预览长度保持；非法结构不能回退为空结果。
- 现有 DLL 执行真实书签查询、连续更新、搜索和删除，启动与配置刷新仍正常。
- 目录、选区及备注面板回归通过；不以组件测试或 Windows FFI 代替移动设备验收。

## 音色目录边界（T4a）

ReadAloudVoiceRepository 独立于 HTTP 源配置、合成和平台 TTS。Rust core
解析源目录，DB 在保存源的同一事务同步目录；FFI 只转 JSON 和传递平台发现结果。
Flutter 原始导入保留目录字段，普通 HttpTts 仍为 16 字段，不重复存目录。
系统插件发现真实设备音色，Rust 不访问插件；Mock 只在会话内模拟目录。

HTTP 每引擎选择以既有 config 持久化，由消费时解析为 ReadAloudRequest 参数；
不在 TtsConfig 再保存另一份 tone/speaker/emotion 权威副本。发音人、情感与
源上下文进入合成缓存，播放器倍速仍独立。目录页只展示、选择及委托标记更新，
不复制 SQL 或 HTTP 业务规则。源级 catalog 的无效/空输入遵循上游 no-op；
显式失效系统选择在播放时报错，发现目录仍可恢复，无自动历史回填。

三个目录 FRB 方法与 schema v111 见 API_CONTRACT §2.42；当前状态仅在 Active。

## 云端 Provider 边界（T4b-1）

Rust core 只准备请求、声明音色和适配音频格式；fetcher 注入异步传输，并复用
既有缓存门禁/租约与取消。不把云端配置保存成 HTTP TTS，不由页面发送 provider
网络请求，不让 Provider 反向依赖 FFI。T4b-1 的 CloudTtsEngine 是 Provider 内存输入；T4b-2 新增独立元数据模型，
凭据由设备安全存储拥有，配置元数据、原生合成与 ReadAloudEngine 各走窄接口。

编写者：Codex｜2026-10-13

## 云端产品边界（T4b-2）

CloudTtsRepository 只访问独立云端元数据；CloudTtsCredentialStore 只访问设备安全存储。
CloudTtsSettings 负责串行协调两者及失败补偿，不承诺跨存储崩溃原子性。
读取 API Key 只发生在合成前，不回显到编辑器，不进入普通配置 JSON 或 optionsJson。
Rust 合成重新查当前元数据并检查 credentialKey，防止读取期间配置更新后使用旧密钥。

CloudReadAloudEngine 处理一个段落内的长文本分片，不读取书章、不改变正文队列。
FileReadAloudEngine 复用 HTTP/云端的播放、暂停恢复与租约协议；AudioNotifier
继续拥有选段、切章、媒体会话、焦点和定时。共用播放器由协调层停止一次，两个
文件引擎共享停止屏障再释放租约。云端尚无后台预合成窗口，HTTP 队列保持原有职责。
试听有独立播放器与会话，退出时取消请求，不把试听完成回写到正文队列。

云端结果/取消暂复用 HttpTtsSynthesisResult、HttpTtsCancellation，避免增加第二套
文件租约；这不代表复用 HTTP 源表、Cookie 或源规则。平台插件/设备行为及真实云账号
另行验收；普通配置备份不含 API Key，恢复元数据后可能需要重新填写设备凭据。

编写者：Codex｜2026-10-14

## MiMo Provider 扩展（T4b-3）

云端元数据校验、音色发现和执行均通过 Rust core 的 cloud_tts_provider 分派。
PreparedCloudSpeech 明确鉴权头和响应类型；fetcher 负责网络/取消，Provider
负责 SSE/Base64/PCM→WAV 纯计算，Flutter 页面不解析网络协议。OpenAI 保持
直接音频与 Bearer，MiMo 使用 api-key 与 EventStream，错误文本门禁按类型隔离。

Flutter CloudTtsProviderProfile 只定义表单默认值与可选格式/风格，不发送请求。
新建时切换服务商清空地址/密钥并重新读取目录，保存后元数据 Provider 不可改；
如需另一服务新建配置。共享 CloudReadAloudEngine、FileReadAloudEngine、凭据
存储与租约不再增设一套。MiMo 源 speed 不生效，播放倍速仍独立由播放器实现。
云端目录附加 styles/sampleRate 是描述信息，FRB 五个签名、schema v112 不变。

编写者：Codex｜2026-10-14

## 第十七步的搜索访问边界

SearchService 负责原 searchBooks、preciseSearch、searchMulti、searchMultiStream、
cancelSearch、pauseSearch、resumeSearch 七项访问，不持有 Flutter 展示状态或另建
原生会话。SearchHistoryRepository 负责原五项历史查询/前缀/新增/删除/清空。
正式适配器直接 FRB，共用既有 JSON 守卫；Mock 搜索延迟及结果保持，历史唯一
存储由独立 Repository 拥有，原重复插入与 bookName 忽略行为不在本轮修正。

SearchBatch 保存已经解码的结果及源/错误/进度/末批/可空 hasMore；数据层统一
解析原 JSON，保留 hasReadRecord，缺失 hasMore 不改写已有分页状态。正文搜索
共用同一历史 Repository，书架精确搜索共用同一 SearchService。根仅分享装配
引用，Provider 跟随根替换；Notifier 的订阅、取消顺序、过期过滤、分桶和节流
保持，固定会话实例及纯增量聚合分离为后续批次，不提前引入另一份调度实现。

编写者：Codex｜2026-10-14

## 第十八步的搜索会话与生命周期

SearchSession 是纯 Dart 执行会话，固定 SearchService、一次查询各页的订阅、
暂停恢复串行队列与幂等关闭。没有原生句柄，不改变 Rust 全局调度语义；
Notifier 仍拥有查询代数、结果桶和 150ms 展示节流。新关键词在首次 await 前
取得身份、绑定能力并隔离上一轮；原生取消先于解绑，清理和在途控制的屏障
结束后才启动最新请求。自然结束保留查询绑定供续页，不对已结束会话重复
发送原生取消；流异常/同步启动失败不保留活动订阅。

停止、清空、重开和 Provider 销毁同步使旧结果失效并清理节流。停止期间
立即保留并展示已出结果，不在 await 之后覆盖新查询；前后台软暂停与恢复
有序处理，完成后仅更新当前会话。页面仍使用全局 Notifier，不调整路由
或自动释放策略；页退出按既有语义停止任务，Provider 销毁是额外资源收口。

编写者：Codex｜2026-10-14

准备期的后台暂停只保存意图，原生启动后才应用；期间已恢复则不补发暂停。
Provider 失效重建时恢复新的生命周期，旧历史与范围加载不得回填；不会
改用 autoDispose 或改变搜索页历史/范围持久化。页面退出仍延迟展示回写，
但微任务携带原查询身份，不能停止随后打开的新查询。

## 第十九步的纯搜索聚合与功能目录

SearchResultAggregator 只消费 SearchResult 并维护当前查询的增量桶，不引用
Flutter、Riverpod、FFI、网络或存储。原始 name|author|origin 是入桶前预去重键，
清洗后 name/author 的 NUL 双键是桶内归并键，两者保持。相同计数按首到序
稳定排序，元数据取首条，来源集合有序累加且已读标记跨源 OR；清空或新查询
重置，续页追加。一次性 applyPrecisionSearch 使用同一算法，空 key 原样返回。

features/search 集中页面、State/Freezed、Notifier、能力 Provider、搜索专属
筛选面板；外部经 search.dart，内部直接引用依赖，不反向引用功能入口。共享
SearchBarWidget、AppSearchField 和 DynamicSearchAppBar 保留通用 widgets。
数据层接口/实现、SearchSession 和纯聚合保留 domain/data 边界，不搬进页面目录；
正文搜索只是移动现有页面与引用，算法、路由、交互及持久化均不改变。

编写者：Codex｜2026-10-14


## 第二十步：普通设置访问与搜索试点

用户批准以类型化访问与唯一状态来源收敛普通设置，不迁移存储介质。
参考 HapeLee/legado-with-MD3 main `60a7cca34dd3e0be456e0f05c10c036c64b70e35`
的 AppConfigStore 与 ReadAloudSettingsRepository；借鉴职责，不移植 DataStore。

### 分层与命名

- AppSettingsStore 为纯 Dart 状态核心，只拥有已读/已保存快照和带身份的待保存变更。
- AppSettingsService 协调初始化、串行存储写入、重新加载和失败，不包含领域默认值。
- SearchSettingsRepository 提供不可变 SearchSettings、当前快照、变化订阅和类型化更新；
  `loadRuntime`/`reloadRuntime` 只读取 Rust config 键，供原生搜索启动前同步，避免把
  SharedPreferences 平台能力带入搜索调度。
  正式投影实现只解码、编码及委托同一 Service，不建立另一份可变设置。
- SettingsStorage 为存储适配边界。配置适配器第一阶段绑定同一 BookApi 的既有配置
  方法，确保未迁移消费者与 Mock 的唯一配置表仍互通；SharedPreferences 适配器
  沿用原键和类型。后续全域迁移后再删除根配置入口，不新建重复数据库或原生接口。
- 文件使用小写下划线，类型 UpperCamelCase，Provider/成员 lowerCamelCase；保留
  Riverpod，不为了命名引入额外 AppSettingsRepository 或改用另一套状态框架。

### 试点范围与所有权

| 字段 | 既有位置 | 类型/读取语义 |
|---|---|---|
| precisionSearch | Rust config:precisionSearch | 字符串严格等于 true 时开启 |
| resultFilter | Rust config:searchResultFilter | 字符串，读取 trim，默认空 |
| scope | Rust config:searchScope | 沿用分组与 ::URL 编码，默认空 |
| searchGroup | Rust config:searchGroup | 沿用单分组/空字符串 |
| showReadRecord | SharedPreferences showSearchReadRecord | bool，默认 false |

搜索页面只订阅并展示这些值，输入框及临时范围选择仍是 UI/会话状态。
原生精确搜索会读数据库，因此新搜索/续页在订阅原生流前等待配置加载与已排队写入。
范围初始读取不得覆盖加载期间的用户选择。保留会话 token、取消顺序、150ms 节流、
结果聚合、单源下次不恢复及显式路由范围等既有语义。

### 状态及失败规则

更新先提交待保存差量，使所有读侧即时可见；串行按调用顺序落盘。成功更新已保存
快照并移除自己的待保存项；失败只撤销自己的项，后续操作继续，不覆盖更新的值。
初始化/重新读取只更新已保存基底，不能盖掉在途用户修改。不存在和读取失败区分，
后者向调用方报错，允许重试；禁止吞保存错误后报告成功。

跨 SharedPreferences/SQLite、多键逐项写入不承诺事务。某项成功、后项失败时保留
已成功落盘事实，撤销未成功项并返回错误；UI 以实际快照恢复，不伪造全批回滚。
重要关联项的原子事务另行设计。订阅拿到不可变快照，只对字段变化通知。

迁移期间旧域仍可能写同一配置表，提供显式重新加载；搜索入口重新核对已迁移的
Rust 配置并等待自己的写入，备份恢复后使用相同 reload。暂不宣称具备原生跨进程
推送或全部旧写入自动监听。默认不扫描整张 config 表，避免读取凭据和业务载荷。

### 验收与后续

覆盖初始化合并、晚到读、连续同键写、旧失败不覆盖新值、部分成功、失败后重试、
字段订阅、不可变快照、存储失败及共享根替换。搜索回归验证恢复、精确重搜与过滤、
范围持久化、加载期间用户操作、退出及流准备；移动设备与全量 CI 不在本批自动运行。
后续逐域迁移普通偏好及 Rust 运行时快照同步；实体、排版预设、
安全凭据与临时授权继续由各自 Repository/会话拥有。

编写者：Codex｜2026-10-14

## 第二十一步：朗读普通偏好

`ReadAloudSettings` 保存纯数据和派生有效语速，`ReadAloudSettingsRepository` 负责
七项偏好的默认值、限值和旧语速编码；正式实现委托同一 `AppSettingsService`。
朗读设置 Provider 只等待初始化并订阅快照，加载/错误不写入设置模型，
也不再维护第二套写入队列。
移除 `ReadAloudPreferencesNotifier` 的直接配置访问和独立写队列，保留现有消费者的
状态投影入口，由它委托朗读窄接口并订阅共享快照。播放参数应用仍由 AudioNotifier
在原有调用点执行，不因为打开设置界面、订阅快照或重建 Widget 自动重启播放。

| 键 | 默认与语义 |
|---|---|
| ttsFollowSys | 缺失/空、true、1 为跟随；跟随使用标准 1 倍速 |
| ttsSpeechRate | 默认 5；倍率 = (rate + 5) / 10，限制 0.5–3；存储标记保留 |
| ttsParagraphInterval | 默认 0，限制 0–5000 ms |
| readAloudDetachReminderEnabled | 除 false、0 外默认开启 |
| audioPreDownloadNum | 默认 10，限制 0–100 |
| ttsPreSynthesisConcurrency | 默认 3，限制 1–8 |
| audioCacheCleanTime | 默认 10，限制 0–1440 分钟 |

旧 `read_aloud_follow_system_speed` 仅在 Rust 跟随键缺失/空时迁移；先成功写入新键，
再删除旧偏好，失败保留真实落盘结果并向调用方报告。重复初始化复用同一在途任务，
已有新值优先。手动语速缺失时由现有播放启动逻辑迁入书级值，不调整书籍数据结构。
引擎/音色实体、系统平台偏好、凭据、胶囊展示状态和音频书片头片尾配置不属于本批。

编写者：Codex｜2026-10-14

## 第二十二步：全局外观普通偏好

沿用 SharedPreferences 的 app_theme_mode（字符串）、app_font_scale（整数）和
app_palette_id（字符串），不搬迁存储、不修改备份格式。AppearanceSettings 为纯模型，
AppearanceSettingsRepository 负责默认值与编码，委托既有 AppSettingsService。
ThemeNotifier 只订阅快照并映射 Material ThemeMode，移除独立持久化与状态回退逻辑。

启动主题来源与运行中的设置仓储共享同一服务；仍在原生初始化、数据库和环境注入后
写入主题配置及模式。保留原协议字段、亮色角色与模式 0/1/2，不修改 FRB 或 Rust。
运行时注入失败独立报告、可重试，不能撤销已经保存的偏好。保存失败移除自己的待保存
差量，通知所有消费者回退；较早失败不能覆盖后来选择。备份恢复后显式重新加载快照。

主题和调色板入口接住保存错误并提示；字体对话框保存期间防重复提交、失败保留输入，
成功才关闭，未保存时保留原遮罩关闭行为。主题文件的模式和调色板先统一保存再同步，
原生失败不阻断剩余偏好的落盘；多键仍不承诺跨插件事务。模型不依赖 Material；未知调色板仍由既有渲染映射回退，不改变存储值。
本批不迁移自定义颜色/预设、阅读排版或其他首页偏好。后续用户明确授权 Android
构建安装及本地提交，实际结果和依赖升级记录统一见 Active 计划；不推送或触发 CI。

编写者：Codex｜2026-10-14

## 第二十三步：主界面导航偏好

HomeSettings 只保存 showDiscovery、showRss 与 defaultHomePage 三项纯数据；
HomeSettingsRepository 定义读取、订阅、显式字段更新和恢复后重读，正式实现
AppHomeSettingsRepository 委托共享 AppSettingsService。保留 SharedPreferences 原键、
布尔/字符串类型及默认 true/true/bookshelf，不修改数据库或备份格式。

初始化前的更新仍作为明确差量立即生效，随后读取不能覆盖它，也不保存其他未加载字段。
错误类型只回退展示，未知首页原字符串保留；空更新不写入。串行写入、失败撤销自身差量、
较早失败不盖后来选择及多键部分成功，都沿用共享服务，不增加领域写队列。
MainPrefsNotifier 仅投影快照及加载状态/错误，根替换或释放后忽略旧结果。
两个开关和默认页选择由页面捕获保存异常并提示；恢复后的 reload 重读同一仓储。

当前逻辑页签和用户导航意图属于 HomeScreen；页索引由可见页签集合派生。
PageView 子页以逻辑身份设稳定键，显隐变化后在新布局完成时同步位置；
隐藏当前页回书架，隐藏前置页保留当前页。帧后定位和翻页回调校验修订号及最新集合，
不会让旧定位盖掉较新的点击。默认页在首次加载成功后应用一次，预加载亦适用；
隐藏或未知目标回书架；用户点击、返回或开始滑动后不再由晚到默认值接管。
底栏/侧栏外观、双击、滑动及懒构建保持，其他设置和阅读器不属于本批。
实际进度、测试和未验证边界统一登记于 Active 计划。

编写者：Codex｜2026-10-14

## 第二十四步：顶栏、底栏和侧栏布局偏好

UiLayoutSettings 为十项布局偏好的纯模型，按钮样式、底栏标签和大屏模式枚举
移入模型，保留原选项与字符串编码。UiLayoutSettingsRepository 定义当前快照、
订阅、加载、恢复后重读及显式字段更新；AppUiLayoutSettingsRepository 负责
类型解释、默认值和透明度 0–100 限值，委托同一 AppSettingsService 读写。

本批覆盖 topBarButtonStyle、mergeTopBarActions、useFlexibleTopAppBar、
topBarOpacity、labelVisibilityMode、bottomBarOpacity、useFloatingBottomBar、
showBottomView、tabletInterface、railExtended。保留 SharedPreferences 原键、类型、
默认值和备份格式；读取仅产生快照，不补写默认值或改写未知枚举。
更新只保存显式字段，串行落盘、失败撤销差量与订阅通知由共享服务负责。

UiSettingsNotifier 对这十项只做界面状态投影，不再直接访问存储或自行排队保存。
保留现有消费者的状态和方法入口，未迁移的十七项设置继续原有路径；加载这些
字段时只合并对应值，不覆盖已恢复的布局快照。封面、卡片、模糊、阅读菜单、
其他主题参数和系统栏偏好不属于本批，后续分别迁移。

外观页的相关开关、选项及透明度对话框接住保存错误，状态随共享快照回退并提示；
侧栏展开按钮采用相同保存行为，不改变导航或动画。备份恢复后显式重读布局仓储，
读取失败独立提示。颜色、阅读排版、Rust/FRB 与数据库均保持。
实际进度、定向验证与设备验收边界统一登记于 Active 计划。

编写者：Codex｜2026-10-14

## 第二十五步：系统栏普通偏好

SystemBarSettings 保存 transparentStatusBar、immNavigationBar、transparentNavBar、
transparentNavBarNight 四项布尔值。SystemBarSettingsRepository 提供读取、订阅、
恢复后重读和显式字段更新，AppSystemBarSettingsRepository 解释默认值并委托共享
AppSettingsService；沿用 SharedPreferences 原键及 true/true/false/false 默认值。
读取不补写默认值，更新只保存指定字段，不改变备份格式或存储位置。

SystemBarNotifier 只投影偏好与加载状态/错误，删除直接存储访问、独立写入队列和
按字段维护的加载修订号。共享服务负责读取、保存及失败回退的顺序；运行时系统栏
样式继续由 SystemBarBinder 与 SystemBarController 处理，阅读器显隐仍由当前页面
拥有，不移入偏好仓储。Notifier 释放或根替换沿用已有状态投影的归属检查。

外观页的日夜透明开关直接订阅同一快照，移除局部状态和重复读取。四项开关保存失败
均提示并回退，备份恢复后显式重读；恢复失败独立提示。日夜透明开关本轮仅统一既有
偏好的访问，不增加平台样式接线；阴影高度、壁纸取色、阅读器配置与原生服务保持。
已存在的系统栏控制回归继续保留；旧独立队列的加载修订测试改为四项恢复用例，
不为罕见且低影响的重载中间状态新增机制。实际验证和未测边界统一见 Active 计划。

编写者：Codex｜2026-10-14

## 第二十六步：集中迁移完整界面偏好

按用户加速迁移指令，将第二十四步的十项布局和剩余十七项合并为 UiSettings。
模型位于 domain/models/ui_settings.dart，保留全部字段、默认值及 copyWith，
增加值比较；主题与组件直接消费纯模型。UiSettingsRepository 定义二十七项
类型化访问，AppUiSettingsRepository 负责原编码与现有保存限值，委托共享
AppSettingsService。原 ui_layout_settings 模型、仓储与 Provider 入口已替换，
不保留等价两套访问或旧名称别名。

迁移范围包括封面背景、卡片圆角、模糊、分隔线、壁纸取色、主题参数和阅读菜单
偏好。UiSettingsNotifier 只加载、订阅和转发用户更新；删除直接 SettingsService
访问、独立写队列、加载期间字段合并及重复状态模型。既有单项 setter 保留，
恢复入口改为 reload 完整快照。SharedPreferences 原键、标量类型、默认值和现有
保存限值不变；字符串不因展示回退而被重写，不搬迁存储或改变备份格式。

外观页的对应开关和选项统一接住保存失败。圆角的覆写开关与数值、各模糊配置的
半径与透明度，以一次 Repository 更新提交，页面等待结果并提示；修正原模糊
对话框通过 ValueChanged 丢弃 Future 的路径。多键仍逐项落盘：已成功字段保留，
失败只撤销未成功差量，不宣称原子事务。图标、封面资源选项、阴影高度和壁纸
自动更新仍属其他入口，后续按功能块集中迁移，不将本步等同于全部设置迁移完成。

实际进度、集中回归及设备边界统一登记于 Active 计划。

编写者：Codex｜2026-10-14

## 第二十七步：常用偏好五域集中迁移

书架、阅读记录、语言、护眼和欢迎页分别使用类型化 SettingsRepository，
App 实现共用 AppSettingsService，保留 SharedPreferences 的原键、类型和默认值。
GroupMode、阅读记录排序/展示枚举、护眼模型与时间判定移入 domain；原状态或
主题模块继续导出实际使用的类型，滤镜矩阵及页面业务状态仍在原职责模块。

| 领域 | 范围 | 实际消费者 |
|---|---|---|
| 书架五项 | 列表/网格、列数、分组模式、选中位置、书名打开详情 | BookshelfNotifier、管理页 |
| 阅读记录三项 | 记录开关、排序、展示方式 | ReadRecordNotifier、ReaderNotifier |
| 语言一项 | app_locale | AppLocaleNotifier、其他设置页 |
| 护眼六项 | 开关、强度、跟随深色、定时、起止时间 | 公共设置组、阅读快捷按钮、滤镜 |
| 欢迎及启动九项 | 时长、自定义、日夜图、日夜图标/文字、默认开读 | 配置页、启动页、其他设置页 |

Notifier 只订阅和投影共享偏好；实体数据、过滤、路由、选区及读取计时仍由现有
功能层处理。书架布局更新不重置因实际分组列表变化而调整的索引；切换选中分组
时才应用选中偏好。记录偏好不另建写队列，记录开关与阅读器使用同一来源。
语言归一化沿用生成的支持列表，系统 Locale 解析留在界面层；护眼时间及滤镜
规则不变，强度更新仅保存强度，不整份覆写其他偏好。

欢迎配置页只保留拖动期间的时长预览，结束后保存，失败显示原快照。启动页读取
本次启动的展示快照，原计时、淡入、默认主页和已登记的直达路由语义保持；
图片选择仍使用原插件，只把路径更新交给仓储。相关开关、菜单、图片删除和布局
对话框保存失败提示并回退；备份恢复后逐域重读，单域错误独立报告。

旧 SettingsService 的专用方法暂留至整体消费者清理阶段，本批生产消费者已迁出；
不提前删除为旧测试或其他入口保留的方法，也不迁移阅读排版或主题预设。
多键保存继续保留已成功字段，不承诺事务。实际验证、代码状态和设备边界统一
登记于 Active 计划。

编写者：Codex｜2026-10-14


## 第二十八步：主题颜色与背景偏好

ThemeColorsSettings 保存八项 nullable ARGB 整数与日夜背景路径；ThemeColorRole
区分八个颜色槽位，模型不导入 Flutter、Material 或偏好键。数据层的
AppThemeColorsSettingsRepository 将槽位映射到原 SharedPreferences 键，复用
AppSettingsService 的快照、串行 IO 和失败回退；不另建缓存或写队列。

ThemeColorsNotifier 订阅同一来源，只投影状态并转交加载、更新和重读。
颜色选择与恢复默认统一等待保存结果；应用预设、文件导入和背景操作失败向页面
传播，不能吞掉异常后提示成功。null 颜色删除覆盖键，空背景路径删除路径键；
未传字段保持。多键保存保留已经成功的字段，不宣称事务式回滚。外部恢复后显式
调用 reload，不能只重建 Notifier 后复用共享服务的旧缓存。

ThemeActions 仍编排主题交互，命名主题使用独立 ThemePresetRepository，保留
原 themeConfigList JSON 格式和列表的串行读改写；该队列处理实体集合，与普通
标量设置的共享队列职责不同，不为了去重而混入 AppSettingsSnapshot。
ThemeFileService 继续处理实际平台文件选择和导入导出，平台图标操作保持独立。

按生产消费者检索，导航栏阴影、壁纸自动更新、四项默认封面与日夜透明导航栏
尚未接入实际渲染/平台能力。本轮设置行禁用，保留原说明并追加“待实现”，原值
保留且不可通过
这些行继续修改。封面规则查询、系统栏沉浸、动态色、颜色及背景选择等有效入口
保持可用。后续接线必须同时验证保存值、实际消费和运行效果，再启用对应设置。

不改变 Rust/FRB、数据库、存储位置或主题文件格式。测试范围和交付状态只在
Active 计划登记。

编写者：Codex｜2026-10-14


## 开书准备

BookDetailService.resolveReading统一书源匹配与媒体类型解析，供书架、公共开书工具和详情复用。
prepareReading负责详情开读前临时书落库、媒体位回写和非文本目录准备，保留notShelf及原有失败继续开读规则。
返回BookReadingPreparation纯数据，不持Context、Ref或路由；UI负责异步完成后的当前路由校验、
ReaderNotifier装载、封面起点、导航及返回刷新。未修改Rust/FFI或书架显式入架行为。

编写者：Codex + UI｜2026-10-19


## 订阅导入准备

RuleSubImportService承接订阅网络拉取、JSON根类型解析、候选过滤和本地快照；书源继续复用
SourceImportService，不另建确认/写入实现。返回三类预览，由原确认页完成用户选择与入库。
本地RSS/替换规则读取失败保留原空列表回退，书源快照在开始时捕获；页面不直接读网络或解析JSON。
页面持有本次加载DialogRoute并精确关闭，用户取消或离开后丢弃迟到结果；不声称取消底层网络。

编写者：Codex + UI｜2026-10-19


## 界面测试边界

书架回归挂载实际BookshelfScreen，只对窄依赖与目标页面使用替身；自行拼接Scaffold不能代表书架行为。

| 行为 | 实际回归文件（flutter_legado/test/） |
|---|---|
| 空态、搜索入口与返回 | widget/bookshelf_test.dart |
| 零进度直开、长按详情、连点防重与返回进度 | widget/bookshelf_refresh_on_return_test.dart |
| 列表/网格批量勾选及封面元素保持 | widget/bookshelf_batch_mode_test.dart、bookshelf_grid_mode_test.dart |
| 菜单关闭与目标导航 | widget/bookshelf_card_menu_overlay_test.dart |
| 公共开书媒体分流 | widget/book_open_utils_orchestration_test.dart |
| 详情显式阅读与返回刷新 | widget/screens_coverage_batch1_test.dart |
| 分享文案纯函数 | unit/book_share_text_test.dart |

阅读器正文分类仅随文本变化求值；外层组合只订阅其使用的字段，页码/总页数由正文与菜单局部订阅。
朗读显隐及菜单模式不消费播放位置采样；跟随高亮保留现有局部监听。测试核对分类次数、通知次数、
实际菜单拖动和原生排版测量次数，不把这些行为计数等同于profile耗时或设备视觉证据。

编写者：Codex + UI｜2026-10-19

## 界面文件元数据与诊断写入

背景图、欢迎图与本地书标签通过fileMetadataProvider异步读取文件元数据，订阅期间同路径复用；
已知文件变化可显式invalidate，缺失或不可读按原无图/无大小回退。绘制阶段只消费快照。
普通诊断日志由BoundedLogWriter按字节限制排队、合并、异步写入；超额时丢弃较旧待写普通行，
导出等待flush。崩溃主文件继续即时同步落盘，备份与历史清理由异步任务完成。
应用根释放其注册的深链、任务观察、悬浮处理器及UI回调，不改变用户开关或清除原生持久任务。

编写者：Codex + UI｜2026-10-19

## 正文搜索与服务运行编排

ContentSearchController拥有章节扫描、范围过滤、历史与取消代次；页面传入查询选项和当前章快照，
展示不可变结果。取消阻断后续工作，不声明正在进行的底层请求已被强制终止；单章失败仍跳过，
诊断保留操作上下文。content_search_matcher同时服务于搜索和结果高亮。
AppServicesController消费设置、服务、访问凭据窄接口及注入的保活/任务回调；页面只持有展示订阅。
已接受的服务动作在页面卸载后继续完成必要持久化，停止向销毁的界面发布状态。

编写者：Codex + UI｜2026-10-19

## 静态依赖门禁

`dart run tool/check_architecture.dart`解析import/export/part与条件分支的语法树，
检查features/widgets/providers直接桥接依赖，以及domain对界面、平台和数据实现的反向依赖。
规则不要求改用其他状态管理方式；ChangeNotifier形式的页面Controller仍通过构造器接收窄接口，
页面拥有订阅并在卸载时释放。静态检查与业务运行测试分别维护。

编写者：Codex + UI｜2026-10-19


## 测试必须经过被保护的实现

依赖替身只替换外部输入；被测页面、控制器和算法必须使用生产实现。
测试内自建页面或服务后仅断言其自身，不构成对应功能的回归保护。
原audio_screen_test、cache_settings_test与reader_test已删除；实际音频焦点、
缓存清理、阅读器交互分别由audio_focus_wiring_test、cache_boundary_test及现有
reader组件/连续翻页测试覆盖，不再维护平行的演示页面。

图库二维码解码集中在features/tools/application/qr_image_decoder.dart。
页面继续通过compute执行；测试使用同一入口验证URL、中文与无效图片，
不复制解码和UTF-8恢复算法。图片失败占位素材经rootBundle加载并实际解码，
不以磁盘存在、固定长度或PNG头代替资产包可用性。

Widget测试的pump耗时不用于宣称设备FPS、掉帧或真实冷启动达标。
原performance目录中的代理计时门禁已移除；真实组件交互测试继续保留。
设备性能需独立profile测量；本批没有提供性能提速或真机性能结论。

编写者：Codex + UI｜2026-10-19

## 阅读器测试职责与原生依赖

选区、复制、高亮和翻页手势测试直接消费用例给定的PageInfo与行边界。
reader_page_fixture只测量已给定行的字形几何，并填充正式ReaderGlyph结构，
使绘制、命中和选区继续经过生产字形路径；不执行断行、分页，不生成算法预期。
双页用例明确给出左右页，原文偏移仍由真实选区结果验证。

| 验证职责 | 当前用例 | 原生依赖 |
|---|---|---|
| 长按、手柄拖动、复制、缩进排除、Unicode命中及双页顺序 | widget/reader_native_selection_test.dart | 无；native指Flutter原生选区，并非Rust FFI |
| 跨行高亮留白、混合字体符号高度与文字缩放 | widget/reader_selection_height_test.dart | 无 |
| 测量环境、显式零字距、字形簇、诊断采样不改变测量载荷 | widget/flutter_text_shaper_test.dart | 无 |
| 正式FRB代表载荷、会话容量与取消释放 | ffi/reader_layout_runtime_test.dart | 保留 |
| 真实分页后的容器溢出、重排、行内段评与布局缓存 | 现有分页集成用例 | 仍保留，不宣称本批已全部解除原生依赖 |

纯计算算法样例由Rust测试负责；Flutter测量测试不再借助Rust生成断点后比较。
旧reader_layout_contract_test与reader_layout_diagnostics_test合并到Flutter测量测试，
其职责限定为测量输入与诊断统计，不将之描述为完整阅读链路或真机视觉证据。
本批不调整CI任务或删减真实FFI契约测试；全模块flutter test仍可能需要当前平台原生库。

编写者：Codex + UI｜2026-10-19


## 宿主原生测试加载入口

`test/helpers/native_ffi.dart`统一解析当前宿主的debug产物，Windows/Linux/macOS分别为
legado_ffi.dll、liblegado_ffi.so、liblegado_ffi.dylib；可用LEGADO_TEST_FFI_LIBRARY显式指定。
显式空路径、缺库、空库或加载失败均报错，不静默跳过，也不回退到release或默认加载器。
业务测试通过NativeRustRuntime.libraryResolver注入，直接FRB测试与阅读器会话测试复用
同一入口；生产加载策略不变。旧测试专用LEGADO_TEST_DLL入口已移除。

通用业务测试不再以Platform.isWindows决定是否注册真实断言。加载器用例以临时文件验证
路径选择与错误策略；它不验证这些文件可作为动态库加载。真正的调用、载荷及生命周期
由test/ffi与分页集成用例负责，平台实测结果统一记录在Active计划。

编写者：Codex + Bridge｜2026-10-19


## 普通组与原生组的执行边界

原生测试文件以库级`@Tags(['native'])`标记，dart_test.yaml登记标签。
`flutter test --exclude-tags native`执行普通组，`flutter test --tags native`执行原生组；
直接`flutter test`仍执行全部，不允许原生库缺失时用占位测试替代原有断言。

CI普通组显式设置不存在的库路径，用于暴露错误初始化；Linux原生组单次构建并指定当前源码产物。
Windows宿主冒烟沿用独立Integration Smoke，不复制整套业务矩阵。
独立测试改动根据当前及基线版本的native分组选择原生组；共享夹具、测试支持输入和
test/ffi仍保守运行两组。普通组继续使用不存在的库路径，错误引入原生依赖时直接失败。
分组是执行边界，不将少跑测试或未初始化Rust等同于测试通过。
编排、触发和汇总规则见CI_ORCHESTRATION_20261010.md，验证进度只登记于Active计划。

编写者：Codex + UI｜2026-10-19
