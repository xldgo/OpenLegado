# Rust 服务边界变更记录（RUST_SERVICE_BOUNDARY_LOG）

**日期**: 2026-10-19
**来源**: 原 `TWO_TRACK_DEV_SPEC.md` v1.3 文末「变更记录」整体迁入，保持原文与署名

> **本文是记录性文档，不构成新约束。**
> 仍有效的通用约束见 [TWO_TRACK_DEV_SPEC.md §3.6](TWO_TRACK_DEV_SPEC.md)；
> 背景与原理见 [TWO_TRACK_DEV_RATIONALE.md](TWO_TRACK_DEV_RATIONALE.md)。
> 各批次的实现状态、验证证据与遗留项只在 [REFACTORING_ACTIVE_PLAN.md](REFACTORING_ACTIVE_PLAN.md) 维护。
> 新增批次追加在文末，不改写既有条目。

---

本次边界更新：Codex + Bridge｜2026-10-16

### Rust 引擎装配与宿主边界（2026-10-16）

`legado-engine` 汇集存储、网络、限流、JS 数据资源与任务作用域，FFI 和 Server 共享注入实例。
FFI 根边界保留首次成功初始化的契约；业务闭包捕获窄数据能力，不反向持有根引擎。
Web/MCP 监听状态及 Tokio runtime 由宿主拥有；停止端口和等待实际任务结束是两个独立事实。
任务组有界关闭超时须报告仍有工作，不能提前清空登记或宣称同步 JS 已被强杀。
本次内部重构不更改 FRB 方法、JSON、生成绑定、依赖与应用版本。
真实 Flutter 应用使用新 Rust 实现前仍需重建 native 产物；Rust 单测不替代设备验收。

— Codex，2026-10-16

测试分层更新：Codex｜2026-10-17

---

### 轨道边界与口径订正（v1.3，2026-10-18）

**依据**：[ARCHITECTURE_REVIEW_20261018.md](ARCHITECTURE_REVIEW_20261018.md) 的只读取证，
核对基线为 `feature/rust-ffi-modernization`。仅订正与代码不符的表述，未改动任何流程职责。

| 位置 | 订正内容 |
|---|---|
| §2.1 | 删除已不存在的 `lib/src/screens/`（页面在 `features/*/presentation/`）；补录 `models` / `services` / `platform` / `constants` / `routes.dart` / `rust` 六个未定义归属项；新增「共享目录判定规则」四条 |
| §3.1 | codegen 后统一走 Python 构建入口，裸 `cargo build` 降为排障参考；标注 FRB 双侧 2.13.0 已核对 |
| §3.2 | 明确 `LEGADO_SKIP_RUST_BUILD` 仅 Android Gradle 读取、是环境变量非 dart-define，桌面端不适用 |
| §4 | 澄清被移除的是旧全能根接口，列出 `RustApiException` 与日志串两处同名残留 |
| §5.1 | 桌面端 Mock 只需 `USE_MOCK=true`；Android 跳过编译的写法单独给出 |

**核对后确认未过时、未改动**：FRB 双侧版本配对；§3.3 UI 轨禁区；§3.4 各平台构建入口；
§3.5 frb 构件配对纪律；§6 分支与冲突处理；§7.2 的 `test/helpers/native_reader_layout.dart` 口径。

**遗留未处理**（需单独立项，不属本次订正范围）：
1. `lib/src/services/` 仍有 1 处 `bridge/ffi` 引用（`app_update_service.dart` 等含业务逻辑），
   按 §2.1(3) 规则改动前须走契约评审——见 [REFACTORING_SCHEDULE_20261018.md](REFACTORING_SCHEDULE_20261018.md) SCH-X2。
2. 原 `lib/src/rust/` 占位目录于2026-10-23移除；Dart生成目录保持 `lib/src/bridge/`，后续记录见Active计划的FRB-EMPTY-DIR-20261023。
3. `routes.dart` 被 46 个文件反向引用，形成循环依赖，须独占批次处理——SCH-F3a。

— 主代理，2026-10-18

### 搜索与换源应用服务边界（2026-10-17）

`legado-engine/search_service`接管单源请求与解析、普通/精确/流式搜索、结果转换、
阅读记录标记及持久化，内部按model/records/source划分；SearchResources显式注入
存储、网络、SearchTasks、TaskGroup、宿主运行时Handle与FetcherDeps装配函数。
普通搜索替换旧会话，精确搜索独立登记；旧会话不能写库或向新会话发布结果。
服务不访问FFI当前实例、不持根EngineContext、不创建运行时；宿主保留JS绑定装配与协议转换。
FFI入口和DTO/生成绑定不变；动态文档格式仍在适配边界解析，不引入另一套传输协议。

`legado-engine/source_switch_service`接管换源过滤/评分、增强、预取、变量合并和事务提交；
内部按search/enrich/repository/apply分工。SwitchSearcher由宿主注入并直接调用Engine单源搜索，
候选转换共用result_to_candidate，不再调用FFI搜索执行器。运行时由宿主持有，服务只借Handle；
操作槽及TaskGroup保持实例归属，迟到结果仍受发布门控。
`source_batches`是普通搜索和换源共用的唯一调度实现，`source_catalog`共用启用源筛选；
保持32并发、普通搜索每源30秒及换源每源60秒超时，不因服务提取改变限流、暂停和错误策略。
评分同步先归还查询连接，再更新同一实例的config缓存，支持单连接内存实例。
本次不改数据库、外部依赖版本或应用行为；真实Flutter使用前仍需重建native产物。

编写者：Codex｜2026-10-17

### 发现与书源校验应用服务边界（2026-10-17）

`legado-engine/explore_service`接管分类/控件脚本、所属实例infoMap默认值与写回、
发现分页抓取的同步驱动；显式接收JsResources、SourceInfoMap、TaskGroup、宿主Handle
及source绑定装配函数，不回查FFI根实例、不另建运行时。平台动作仍使用既有收集队列。
`legado-fetcher/explore`负责发现HTTP/data URI、登录校验、规则解析和字段处理；
`explore_url`负责携带infoMap/page的URL求值，setup由捕获的FetcherDeps提供；
`explore_js`集中原jsLib降级加载，保留URL映射/完整脚本/sanitize/前缀/host声明的顺序。
FFI保留实体与文档适配、原路径重导出及宿主JS绑定装配；调试入口可继续传入自己的deps/任务。

`legado-engine/source_check_service`显式接收存储、网络、TaskGroup、OperationSlot与Handle，
保留单源独立任务和批量串行校验；选中禁用源仍校验，缺失URL保留占位与索引。
替换/取消/关闭回调受原操作发布门控保护，不新增数据库结果回写或更换底层SourceChecker。
本批不改FRB签名、DTO/生成绑定、外部依赖、数据库或可见行为；完整状态只记Active计划。

编写者：Codex｜2026-10-17

### 阅读应用服务边界（2026-10-17）

`legado-engine/reading_service`按toc/access/content/processing/pre_update划分目录事务、
读取编排、原文缓存与下载、内容设置/处理和刷新前钩子。ReadingResources显式接收存储、
抓取工厂、任务组、WebBookState、JS资源、搜索服务、宿主Handle及本地路径解析器；
不反向依赖FFI，不持根EngineContext或自建运行时。路径解析器由宿主捕获数据目录后注入。

目录刷新保持tocUrl/originBookUrl/bookUrl取址链、空目录保护、单事务重写和进度列排除；
原文读取和下载共用ChapterContent，缓存仍保存原文，规则/繁简/重复标题只作用于展示路径。
普通阅读尽力缓存与显式缓存保存的Result错误语义分别保留，不为合并代码而改变失败策略。
已取消任务的缓存及媒体副内容发布仍走原门控；不据此宣称同步解析被强杀或所有目录写入
新增了取消保证。preUpdateJs的reGetBook/refreshTocUrl直接复用所属Engine精搜与Fetcher详情，
不再从钩子回调FFI搜索/详情入口；稳定bookUrl与钩子更新字段保持原语义。

FFI保留宿主装配、旧入口和类型重导出；对外DTO/生成绑定、数据库和应用版本不变。
Engine仅新增对已有legado-book/legado-parser的workspace依赖边，外部锁定包版本不变。
正式应用使用前须重建native；实现状态与验证边界只记Active计划。

编写者：Codex｜2026-10-17


### 书源调试应用服务边界（2026-10-17）

`legado-engine/source_debug_service`负责关键字分流、搜索/发现/详情/目录/正文串联和日志。
SourceDebugResources显式接收可选存储、抓取工厂、infoMap、操作槽、宿主Handle及ExploreService；
只保存窄资源快照，不持根EngineContext，不新建运行时或在执行中回查FFI全局槽。
搜索/详情/目录/正文继续复用Fetcher，发现直接消费所属ExploreService与本次deps/infoMap/任务。
文档解析与日志展示规则原样保留，不借迁移更改调试协议或补全Server的独立调试端点。

操作槽按实例替换会话；回调失败仍在退出发布门控后取消，避免重入锁。
入口丢弃停止本次发布，实际阻塞worker仍持凭据直到工作结束；不宣称同步JS或HTTP被强杀。
FFI保留宿主JS绑定/目录能力装配、类型重导出和流事件适配；调试与校验操作槽仍相互独立。
原HTTP/JS和会话测试随服务迁移，媒体副内容的迟到落库门禁留在FFI层复验真实宿主注入。
本批不改FRB签名、DTO/生成绑定、数据库、版本或音频/TTS业务，状态与证据只记Active计划。

编写者：Codex｜2026-10-17


### 段评应用服务边界（2026-10-17）

`legado-engine/review_service`以model/rules/js分离请求与应用结果、HTTP规则和JS编排。
ReviewResources只接收所属NetworkContext、JsResources与宿主Handle，不保存根EngineContext，
不自建运行时或在请求/解析中重新发现FFI全局实例。规则解析复用Fetcher的JS分析器适配，
mainJs复用原编排器；两者保留原source作用域和JSON字符串形式的book/chapter脚本参数。

摘要缺失/禁用仍返回空，详情与回复缺规则仍报原错误；保留规则路径page下限、直连URL优先、
相对地址、请求头覆盖、CookieJar内部标记、回复分页和嵌套条目转换。原JS路径的页码处理保持。
本批未新增取消、限流、登录校验或关闭保证，也未调整段评UI、排版与Server的本地评论功能。

请求实体和应用结果不依赖FFI DTO；摘要复用Parser模型，页面保留has_reply_url应用信息。
FFI保留JSON文档解析与DTO转换；可空条目字段及nextPageUrl仍由原DTO序列化，避免直接使用
Parser的skip_serializing_if改变既有文档形状。签名、DTO字段、生成绑定与存储不变。

测试复用同crate的本地HTTP夹具；共同辅助仅在cfg(test)编译，POST按Content-Length完整读取，
不增加外部宿主或独立RPC协议。实现状态与验证限制只记Active计划。

编写者：Codex｜2026-10-17


### 词典与封面规则应用服务边界（2026-10-17）

`legado-engine/dictionary_service`负责词典查询、规则CRUD/排序/导入、JS作用域与释义处理；
`cover_service`负责封面配置和串行规则搜索；两者共享`rule_text`取体实现，不互调FFI业务入口。
各服务显式接收可选StorageContext、NetworkContext、JsResources和宿主Handle，
只捕获所属实例能力，不持根EngineContext、不创建运行时或在请求期间回查当前宿主。
默认封面JSON由宿主注入，服务仅在需要回退时解析，不依赖FFI的assets目录。

词典保持空表种子、trim保留大小写、排序和按名称导入保留ID；导入明确报错，查询单规则失败跳过。
封面保持单配置保存、缺配置回退、禁用源不执行与相对URL补全。共享取体沿用data URI、
AnalyzeUrl方法/请求头/body、followRedirects/retry和15秒外层超时，不另造网络请求策略。
词典及导入不主动补CookieJar，封面按配置只补不覆盖，内部标记仍由Net剥离后发送。
不新增任务取消/限流、事务、HTML渲染、字典分标签或其他用户可见行为。

FFI保留宿主能力装配、规则DTO和JSON文档转换；DictEntry与CoverRuleConfig在原路径重导出，
传输字段、序列化空值和持久化文档不变。Engine的regex直接依赖使用工作区已有锁定版本，
不升级外部包。测试复用本地HTTP夹具，仅增加可配置响应头以检查真实Set-Cookie门控。
完整进度与验证边界只记Active计划；音频/TTS业务继续暂缓。

编写者：Codex｜2026-10-17

### 本地书籍导入与导出应用服务边界（2026-10-17）

`legado-engine/book_import_service`负责格式检测、元数据解析及书架入库；
`book_export_service`负责导出正文组装、选项应用和预览。导入显式接收所属存储和路径解析器，
导出显式接收所属存储及图片获取器，不持有根引擎、不回查当前宿主或重新装配阅读/搜索服务。
图片获取器由 FFI 捕获所属 NetworkContext 和宿主运行时 Handle；TXT 等非 PDF 导出不调用它。

`reading_service::ContentProcessing`仅持有存储，承接原有正文处理配置和实现，供阅读与导出共用。
替换规则、简繁转换、章级重复标题开关和原始缓存的处理顺序不变，不为导出另写一套净化算法。
普通阅读继续通过 ReadingService 委托，导出直接使用同一存储构造的 ContentProcessing。

导入保留原传入标识作为 bookUrl，仅读取文件时解析相对路径；格式检测/元数据入口仍直接消费传入路径。
导出保留原本地解析器与在线原始缓存来源，不借本批修改相对导出路径、缺缓存回退或图片请求策略。
FFI保留宿主装配、选项 JSON 解析及原类型路径重导出；签名、DTO、生成绑定、数据库和版本不变。
测试中的两个内存数据库用于验证独立实例，不表示应用新增数据库或双库模式。
状态与本地验证证据只记 Active 计划；音频/TTS、压缩和编码薄入口不在本批范围内。

编写者：Codex｜2026-10-17

### 备份与WebDAV应用服务边界（2026-10-17）

`legado-engine/backup_service`管理已有六组数据的备份文件、逐项恢复、目录扫描和旧版导入。
服务只持所属StorageContext，目录条目与旧版导入统计使用Engine自身模型；FFI保留原DTO映射、
旧版导入结果JSON及恢复统计JSON的外壳，备份文件本身继续在服务内按已有文档格式读写。
不为本批引入新的数据库、事务、历史格式回退或备份集合；恢复成功计数与失败跳过策略保持。
阅读记录恢复使用与创建相同的DB实体，保持磁盘book_name/read_time字段不变，避免误用Core实体
将其读成空书名和零时长；仍按已有upsert策略写入，不借机改变其他记录字段的恢复策略。

`webdav_service`只接收所属CustomHosts和宿主运行时Handle，配置参数为Net的WebDavConfig，
执行中不查询FFI全局、不保存根EngineContext或自建Runtime。HTTP认证、路径、目录协议、
全量/增量同步算法继续复用Net的WebDavClient和BookSyncManager。
服务承接本地文件读写及同步调用，FFI保留配置文档解析和既有同步结果JSON包装。
未将整文件传输改为流式上传，也未更换客户端策略或补充取消/重试/冲突解决行为。

Runtime选择仍在FFI：优先当前Handle，否则使用持久兜底Runtime，避免返回临时Runtime的失效Handle。
直接Engine调用者须保证传入Runtime存活，服务不承担调度器所有权。
测试复用现有crate内HTTP夹具，验证真实方法、路径、认证、请求体和文件落盘，不新增宿主协议。
FFI签名/DTO/生成绑定、UI、schema和版本不变；当前状态与发现的缺陷统一记录在Active计划。

编写者：Codex｜2026-10-17

### RSS应用服务边界（2026-10-17）

`legado-engine/rss_service`按sources/articles/records拆分源管理、文章加载缓存和收藏/已读。
RssService仅持所属StorageContext；文章加载方法额外接收所属NetworkContext和宿主Handle，
不持根EngineContext、不自行创建Runtime或在执行中查找FFI全局资源。
普通源管理、收藏与已读的宿主装配不启动网络或运行时；FFI保留源文档解析/导出和DTO映射。
RssArticle在Engine定义并从原FFI路径重导出，收藏返回DB记录后由FFI映射原RssStarDto。

RSS源44字段映射统一在DB仓储，find_all保持坏行报错供备份使用，find_all_skip_invalid
供页面列表保留原逐行跳过策略；共用相同查询和字段映射，不借去重改变错误处理。
列表排序、原子更新、默认分组删除、导入逐项写入及错误文本沿用原路径。

文章保持cacheFirst和最多500条缓存读取、RSS/Atom解析、非标准内容200字符摘要回退，
保持按源Cookie开关添加内部标记和尽力写入文章缓存，不引入额外JS、规则、事务或取消策略。
清理文章缓存不改变收藏/已读身份；收藏时间与已读操作继续复用原DB仓储及默认字段。
本批不改FRB签名、DTO、生成绑定、schema、版本或音频/TTS。状态与证据仅在Active计划维护。

编写者：Codex｜2026-10-17


### 图片获取与缓存服务边界（2026-10-17）

`legado-engine/image_service`负责复合URL、书源/内嵌请求头优先级、默认UA/Referer、
Cookie写回标记、图片下载状态与imageDecode。ImageService只持所属JsResources，
下载另外接收NetworkContext与宿主Handle，不保存根EngineContext或查找FFI全局。
FFI继续解析书源JSON文档、装配既有资源与持久运行时，FRB签名和字节返回不变。

解密每图创建独立VM，保留source上下文和完整复合URL的src绑定，避免const/let重复声明。
可选jsLib加载失败仍尝试内联规则；规则失败/空结果回退原字节，下载入口对配置了解密规则
却仍无可识别图片签名的结果报原错误。签名检查不是完整图片格式解码验证。

`image_cache_service`只持调用时注入的根目录，负责书级目录/MD5中段文件名、后缀和文件IO。
目录选择留在宿主，保持非空LEGADO_IMAGE_CACHE_DIR > MediaState注入目录 > 临时目录；
每次FFI操作重新装配目录快照，后续注入影响下一次操作，不改变进行中的操作归属。
MediaState现有音频/TTS字段不改。MD5直接复用仓库已有0.8.1，只有Engine依赖关系增加。

读失败/不存在返回None，写失败返回false；成功读取空文件仍返回Some(empty)，
Dart仓储对空字节的既有处理不变。同类失败保持进程级一次告警，不作为目录或内容状态。
缓存键/目录命名与已有文件兼容；下载和缓存仍为独立操作，不新增自动缓存、清理、重试、
取消或格式检查。已薄化CBZ接口不变；当前字节仍使用SSE，不宣称零拷贝。
状态和验证结果仅维护于Active计划。

编写者：Codex｜2026-10-17


### 规则订阅服务与双宿主边界（2026-10-17）

`legado-engine/rule_subscription_service`集中订阅存储操作与更新准备。
RuleSubscriptionService在宿主数据库闭包内借用连接，不持根EngineContext或自行获取第二条连接；
FFI沿用with_database，Web沿用AppState.with_database的阻塞调度和任务取消保护。
同步操作完成后仅把RuleSubRecord快照带到异步网络阶段，不持连接或服务跨await。

公共异步check_update只做远程版本比较，FFI专用check_update_with_interval额外执行原间隔判定，
保留尚未到期仍然实际拉取的行为；Web不新增该计算或返回字段。
网络继续显式消费所属CustomHosts并复用Net原客户端、超时、TLS和UA后缀策略，不切换共享Cookie客户端。
服务不保存Runtime或用block_on嵌套进入Web运行时，FFI同步等待由宿主负责。

PreparedUpdate区分FetchFailed、MergeFailed与Ready，Ready保存原合并结果和待回写版本元数据。
FFI严格传播版本写入错误，Web保持内部写入错误忽略、外层调度错误记录日志；该差异由宿主决定。
FFI检查/应用结果类型从原模块重导出，现有DTO映射不变；Web继续保留snake_case字段、
缺订阅形状及网络失败仅success/error的响应，不因共享业务结果而暴露额外字段。

prepare_update仍对空本地数组执行原合并算法，只生成统计并回写订阅版本/时间，未导入目标实体表。
该已知功能缺口继续归属Active中的RULE-SUB-UPDATE-GAPS-20261016，不以本批架构收口销账。
不新增订阅能力、自动任务、导入/事务/取消策略，不改FFI签名/DTO/生成绑定、UI、schema或依赖版本。
状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-17


### 书源管理与提交后限速发布（2026-10-18）

`legado-engine/book_source_service`在宿主数据库闭包内借用连接，集中完整实体CRUD、启停、变量
单列更新、类型化批量导入和编辑字段更新；不持根EngineContext、不重新获取池连接。
source_catalog保留原选择/排序语义，只复用服务的启用查询。

SourceWrite仅持成功写入的返回值与限速变更，不持数据库、注册表或根引擎；宿主在原提交位置
调用publish并显式指定所属RateLimiterRegistry。FFI在with_database成功返回后发布，Web创建/
编辑仍在阻塞闭包内提交后发布，在线Room更新仍在异步数据库操作成功返回后发布。
任何写入/提交失败均不返回可发布结果；若新调用者另开外层事务，须等待最外层提交后发布。
不在Drop中隐式刷新，也不改变请求取消或数据库任务的原生命周期。

完整实体保存不改字段；编辑字段输入与完整BookSource模型区分，未暴露字段从库内保留。
concurrentRate缺键保持且不刷新，null/空串清除，有值更新；未知path仍按默认实体补齐，
保持按path查询、按body URL写入的既有行为。删除/启停/变量修改不额外刷新限速。

类型化导入继续复用BookSourceRepository.insert_batch，保留规则对象和variable；RoomSourceImport
从同一组选中值生成原JSON文档及限速变更，再复用RoomImporter原列映射与事务，不混合两种格式。
Room在线更新的网络、筛选和计数仍由既有路径负责；失败整批回滚，成功提交后才发布。
FFI只解析文档和装配资源；Web保留请求DTO/三态反序列化、任务保护与响应。已无消费者的私有
refresh_source_rate_limit包装移除，许可获取和同一注册表的宿主装配保留。
本批不改变FFI签名/生成绑定、UI、schema、版本或依赖；状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 替换规则管理与执行服务（2026-10-18）

`legado-engine/replace_rule_service`借用宿主已取得的数据库连接，集中规则CRUD、启停、
新增默认值和编辑可选字段合并；ReplaceRuleFields只代表现有编辑入口允许写入的字段。
新增仍默认启用、order=0，更新仍保留scope/order，None保留、空串清除语义不变。
FFI继续提供原参数和JSON文档解析，不新增公共DTO或改写生成绑定。

书源导入沿用core的书源作用域规则和顺序执行，不注入JS执行器；查询失败由FFI原位置
返回输入文档，单条规则失败由core保留当前文本。正文/导出的规则处理不改，未扩入MCP。

预览接收已解析规则及宿主入口捕获的JsResources，不在超时工作线程查询宿主全局槽位。
每次匹配仍创建独立QuickJS VM，保留source/replace-rule-preview来源、64MB沙箱及result绑定；
来源变量与登录能力属于同一注入实例，不持根EngineContext或自建Runtime。
复用core既有逐规则超时及替换实现，执行失败仍返回原警告字符串，非法文档仍为FFI输入错误。
未启用QuickJS时维持原不可用提示，不额外引入取消或后台任务关闭协议。

本批不解决scope/order写入与Flutter排序持久化缺口；该后置项仍由Active计划单独登记。
FFI契约、UI、数据库、应用/依赖版本不变；状态和验证证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 书源登录与章节购买动作（2026-10-18）

`legado-engine/source_action_service`分别承接V1登录、V2渲染/动作及章节购买编排。
宿主入口一次捕获StorageContext、JsResources、SourceLoginCache与setup回调；回调仅持
登录和infoMap能力，不持根EngineContext。未开库的登录仍可使用同一内存服务，购买仍报原错误。
数据库查询分别借还连接，脚本执行不持数据库连接，也不新建或拥有Tokio Runtime。

V1保持getLoginJs去壳、动作名处理、sanitize jsLib与共享解析器setup；setup错误和脚本
执行错误仍按原路径忽略，最后返回登录头或空值，不借本批改变既有错误策略。
V2仍用core协议处理空状态/表单及命令，每次调用创建独立VM并注入原baseUrl/source绑定；
命令的login数据在脚本执行完成后写入同一登录服务，覆盖脚本中的中间值。
购买沿用本地书短路及书/章节/源检查顺序，原book/chapter/title/baseUrl/result/src绑定保持；
成功只按书籍URL与章节URL清理数据库正文缓存，URL/none结果不清理。

V2和购买只共用原本一致的独立VM构造及JSON到JS值转换，64MB沙箱、来源tag、
实例Cookie/来源请求头和无QuickJS行为保持。V1解析器、V2协议和购买绑定仍各自独立。
FFI保留文档解析与原签名，LoginActionV2Request及PayActionResult从原模块路径重导出；
原core算法、FFI DTO和生成绑定不变。未补购买模板能力，不涉及音频/TTS、schema、版本或依赖。
状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 书源事件回调（2026-10-18）

`SourceActionService`的callback模块承接书籍/书源/可选章节查询、JS执行、动作收集及返回门控。
调用时显式借用所属TaskGroup，沿用先登记任务、再查询数据的顺序；JS执行不持数据库连接。
缺源、监听关闭和空脚本仍按原路径返回invoked=false，不额外改变提前返回的取消语义。

回调复用书源动作已有的独立VM构造及JSON到JS值转换，保持event/book/chapter/result绑定，
章节缺失绑定null，空字符串result与null区分；原来源tag、实例网络能力和动作顺序不变。
仅原JS成功后的with_active门控负责拒绝迟到返回，脚本错误仍上抛，工作真正结束才释放凭据。
取消不会中止同步HTTP，也不能撤销已执行的网络或登录副作用；UI动作仅随有效结果回放。

FFI仅装配宿主服务及任务组，保留原签名和暂未分流的book_type参数，SourceCallBackBtnResult
从原API路径重导出，DTO映射和FRB绑定不变。不为登录/购买新增任务或取消策略，
不涉及音频/TTS播放逻辑、数据库、UI、版本或依赖。状态与验证证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 书架与进度保存服务（2026-10-18）

BookshelfService捕获所属StorageContext，集中书架保存的陈旧书源字段保护、原地upsert、
进度章节范围/标题计算、字段级更新、锁类错误重试、排序及原Room文档导入。
FFI只装配存储能力及解析原文档。重试每次独立借还连接，200/400ms退避期间不持连接，
不重新查找宿主根实例。原合并宽容分支、负偏移、缺书错误与事务行为均保持。
不改变换源或Web专用写入语义，不新增仓储算法、任务取消或运行时。
FFI签名/DTO/生成绑定、数据库和UI均不变；状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 自动任务实体与执行服务（2026-10-18）

AutoTaskService显式接收StorageContext及JsResources，集中完整实体与core计算模型适配、
导入合并、Cron回写和执行结果组装。FFI只解析原执行文档、装配资源并保留原API路径。
Custom JS每次创建独立变量flow，沿用原QuickJsExecutor的执行与VM缓存语义；
脚本错误仍转换为失败TaskResult，无QuickJS构建保留原错误，不附加源级登录配置。
CRUD、非Custom执行及调度计算保持原行为，不新增调度器、取消策略或Runtime。
FFI签名/DTO/生成绑定、schema、依赖与UI不变，状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 章节缓存与剩余宿主边界（2026-10-18）

reading_service::ChapterCacheService只持StorageContext，承接当前目录有效性过滤、
字数映射、清理时复位章级开关、统计及VACUUM。写入继续调用原
save_chapter_content_with_storage；空正文在未开库时仍返回false，压缩失败仍返回0。
清理顺序、LIKE转义、非事务语义与原错误保持，不借迁移改变缓存产品规则。
CachedChapterEntry从原API路径重导出，FRB仍使用原CachedChapterDto。
标注的自动时间碰撞顺延归HighlightRepository，宿主只提供一次时间；
显式主键保留INSERT OR REPLACE，不新增事务或宣称消除并发分配竞态。

剩余入口按实际职责保留，不以清空api目录为目标：

| 入口 | 保留职责 |
|---|---|
| read_record/bookmark/book_group/config/search_history/privacy | 薄仓储调用、输入默认值与结果映射 |
| archive_import/cbz | 路径及结果适配，算法已在legado-book |
| download | Engine所属队列的模型与DTO适配；实际下载由实例服务承接 |
| server/net | 宿主运行时、监听服务及网络配置恢复/重建接线 |
| verification/webview | 平台事件桥、回传及Cookie写入后唤醒；原core通道仍为进程级 |
| layout_bridge | 正式FRB句柄及类型适配，计算已在legado-layout |

已下沉领域的FFI继续负责原文档解析、资源装配和结果映射。音频/TTS、订阅实际落库、
替换规则写入缺口及剩余固定诊断类型化沿用既定后置安排；不宣称全部全局状态消失。
公开FFI/生成绑定、schema、依赖、应用版本与UI不变，状态与验证仅维护于Active计划。

编写者：Codex｜2026-10-18


### 非音频固定结果传输（2026-10-18）

规则解析、旧版导入统计及WebDAV全量同步的固定外层由FRB DTO传输，
Dart正式适配器映射成domain/models中的独立结果，不把生成DTO交给UI。
规则结果顺序与计数、旧导入逐文件部分成功和消息优先提示保持；
WebDAV的books/sources仍为真实文档字符串，类型化不改变同步或恢复行为。
Mock只提供同形占位数据，不宣称发生真实解析、导入或远端同步。

三项返回类型原位更换，使用方必须配套更新生成绑定及Native库；
不保留第二套JSON返回入口。配置/脚本/正文/实际文档继续用字符串，
仍用SSE，不宣称零拷贝。字段与接口以API_CONTRACT为准，状态与证据仅维护于Active。

编写者：Codex + Bridge｜2026-10-18
