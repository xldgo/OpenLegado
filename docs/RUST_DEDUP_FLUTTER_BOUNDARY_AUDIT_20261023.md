# Rust 重复功能与 Flutter 业务边界审计

## 1. 基线与范围

- 审计分支：`feature/rust-boundary-audit`。
- 基线：`dev / 60ab0885772d49e9545cb753fd5e9dfaf71878c0`。
- 工作树：`build/worktrees/rust-boundary-audit`。
- 用户要求先检查；本轮不修改生产代码、FFI 契约、数据库、依赖或版本。
- 排除正在处理的音频跳过规则、书籍状态修改、导出格式与解析清洗，不把这些内容重复立项。
- 主目录的未提交工作不纳入此基线，不复制、覆盖或提交其他任务的修改。
- 方法：源码检索、重复片段候选定位、逐项阅读及生产调用追踪。片段相似或函数同名只作为线索。
- 本文是专题证据，不另行维护实施状态；后续授权的实现批次登记到 Active 计划。

## 2. Worktree 处置依据

原 `chore/dep-audit` 为 `808cce378197a453a7a9c43d6ce750b7e4c51b82`。
移除前 `git status --short`、`git clean -nd` 均无输出，
`git rev-list --left-right --count dev...chore/dep-audit` 为 `106 0`，
`git log dev..chore/dep-audit --oneline` 无输出。
因此原工作树没有未提交内容或分支独有提交，已用普通 `git worktree remove` 移除，没有强制删除。
原分支引用保留；新分支从上述已提交 HEAD 创建。

## 3. Rust 可以收敛的重复实现

### R1：云 TTS 的服务地址与共性输入校验

八个 Provider 实现各自检查 HTTP(S)、主机、用户名密码、查询和片段；
引擎启用状态、类型、ID 与凭据控制字符检查也重复出现。

代表证据：

- [OpenAI](../rust/legado-core/src/cloud_tts_openai.rs)：`prepare`，第 33、90–102 行。
- [MiMo](../rust/legado-core/src/cloud_tts_mimo.rs)：第 51、90–102 行。
- [Azure](../rust/legado-core/src/cloud_tts_azure.rs)：`endpoint`，第 8–42 行。
- [Polly](../rust/legado-core/src/cloud_tts_polly.rs)：`endpoint`，第 96–140 行。
- [百炼](../rust/legado-core/src/cloud_tts_alibaba.rs)：第 29–78 行。
- [Gemini](../rust/legado-core/src/cloud_tts_gemini.rs)：第 62–106 行。
- [火山 V1](../rust/legado-core/src/cloud_tts_volcengine.rs)：第 37–88 行。
- [火山 V3](../rust/legado-core/src/cloud_tts_volcengine_v3.rs)：第 34–88 行。

建议在 core 的云 TTS 模块内提取小型共用校验函数，Provider 继续拥有默认地址、
端点后缀、区域、模型、鉴权方式与错误上下文。无需新 crate 或依赖。

不能把所有 URL 都套同一规则：百炼返回的音频下载地址允许携带签名查询参数
（同文件第 150 行之后），合成服务地址则拒绝查询；AWS 等也有自己的签名流程。
本项是去重机会，没有据此确认现有请求错误。

### R2：三处 SSE 事件分帧

- [MiMo](../rust/legado-core/src/cloud_tts_mimo.rs)：第 122–142 行。
- [百炼](../rust/legado-core/src/cloud_tts_alibaba.rs)：第 119–139 行。
- [火山 V3](../rust/legado-core/src/cloud_tts_volcengine_v3.rs)：第 137–151 行。

三处都逐行读取、按空行提交事件、收集多行 `data:`、处理 `event:`，并在末尾补一次提交。
建议共用一个只生成事件名与数据的分帧器；保留各 Provider 的音频解码、错误事件、
`[DONE]` 解释及完成条件。火山数字事件码和 MiMo/百炼的结束语义不等价，不能合并为一个结束判断。

这是协议事件边界去重，不涉及本轮排除的书源字段解析、导出格式或正文清洗。

### R3：相对 URL 拼接有重复，而且实现已分叉

相关实现包括：

- [搜索服务](../rust/legado-engine/src/search_service/source.rs)：`resolve_url`，第 591 行；第 455、463 行用于书籍和封面地址。
- [HTML 格式化](../rust/legado-core/src/html_formatter.rs)：`get_absolute_url`，第 293 行；第 217 行有生产调用。
- [AnalyzeUrl](../rust/legado-parser/src/analyze_url.rs)：`get_absolute_url`，第 1161 行。
- [URL 模板](../rust/legado-net/src/url_template.rs)：`resolve_url`，第 194 行，使用 `Url::join`。
- [JS URL API](../rust/legado-js/src/host_api/misc_api.rs)：`resolve_url`，第 169 行。
- [JS 段评](../rust/legado-js/src/js_source/js_source_review.rs)：`resolve_url`，第 205 行。

静态可推导的反例：搜索服务以 `https://example.com` 为 base、`cover.jpg` 为相对地址，
其 `rfind('/')` 命中协议斜杠，拼为 `https://cover.jpg`。
AnalyzeUrl 对相同的纯主机 base 已有专门分支防止此问题（第 1201 行附近）。
搜索实现对 `data:` 也没有其他实现中的保留分支。这说明修复没有共享到所有调用方。

建议分开“通用 URL 解析”与“书源规则 base 预处理”：底层统一解析相对路径、协议相对路径、
查询/片段与特殊 scheme；各适配入口保留其空值、无效输入和规则选项处理策略。
core 已依赖 `url`，parser/net/js/engine 可向下复用，不需要引入相反方向依赖。

不宜直接全局替换为某一现有函数：AnalyzeUrl 还处理 `,JSON` 选项和书源标识片段，
JS API 则有自己的报错语义。此处只审计网络地址组合；书源 JSON 和正文清洗保持排除。
上述反例来自静态执行路径推导，本轮未运行真实书源或原生调用。

后续B4实施边界核对：`AnalyzeUrl`和正文图片消费原文规则，中文与复合请求头不能被
规范URL序列化提前改写；模板模块原有`Url::join`规范化、`java.toURL`结构化字段则有
不同输出约定。故本批只收敛四处原文组合路径，不把它们与这两类入口强行统一。
保留从AnalyzeUrl提取的路径组合语义，不扩展父目录归一化、查询/片段或特殊scheme规则。
实施结果和验证证据只登记Active，本审计原行号仍对应审计基线。

### R4：已有 WebDAV 流式上传能力没有被应用服务复用

- [Net 客户端](../rust/legado-net/src/webdav.rs)：`put_file`，第 100 行，使用异步文件和 `ReaderStream`。
- [Engine 服务](../rust/legado-engine/src/webdav_service/mod.rs)：`webdav_upload_file`，第 37 行，仍 `std::fs::read` 整文件，再调用 `put_owned`。
- [FFI 入口](../rust/legado-ffi/src/api/webdav_api.rs)：`webdav_upload_file`，第 65 行，委托 Engine。

两种机制实现同一个文件上传目标；正式入口没有使用已经存在的流式实现。
Net 的注释称 FFI 已走流式路径，与当前调用链不符。
建议 Engine 复用 `put_file`，保持原来的本地文件错误上下文与 HTTP 失败语义。
这是减少大文件驻留的明确方向；本轮没有测量峰值内存，不能宣称具体收益。

## 4. 应裁决旧实现，而非机械合并

### C1：旧音频预加载模块未找到仓库内生产消费者

初次审计的`rust/legado-core/src/audio_preload.rs`（可由
`git show 837fdf86a:rust/legado-core/src/audio_preload.rs`追溯）定义了
`AudioPreloadStore`、`AudioDiskCache`、`PlaylistManager`。
对这些类型逐个查找，使用点局限于该文件自身与测试；当时`lib.rs`仍公开模块。
当前正式音频缓存由 [audio_cache_service.rs](../rust/legado-engine/src/audio_cache_service.rs) 管理。

这些实现不应为了复用而强行接入正式缓存。B6再次核对引用并按用户授权清理，
删除边界及验证见Active计划；仓库引用调查不等于对外部Rust调用方的证明。
Server中的同名`AudioChapterInfo`是独立响应模型，不在删除范围。

### C2：旧的模板式合成入口与仍在用的缓存工具在同一文件

初次审计的`rust/legado-core/src/tts_speak.rs`（同一基线可追溯）中，
`speak_text`（第 256 行）、`build_speak_url` 及其旧响应/结果类型未找到仓库内生产调用，
相关调用局限于本文件测试；正式 HTTP TTS 已经过 Engine 和 Fetcher 的规则合成链。

同文件的 `SpeakCache`、MIME 工具仍被
[HTTP Fetcher](../rust/legado-fetcher/src/tts_fetcher.rs) 和
[Cloud Fetcher](../rust/legado-fetcher/src/cloud_tts.rs) 使用。
B6将保留部分归位到[speak_cache.rs](../rust/legado-core/src/speak_cache.rs)，
只改模块归属，不改缓存/MIME算法、文件名或租约机制；旧管线和专属测试不保留转发。
缓存覆盖保留原四项，旧模板键测试混入的自动任务ID断言移入其已有用例，
没有因清理模板管线而丢掉其他功能覆盖。

## 5. Flutter 值得下沉的逻辑

| 项目 | 当前证据 | 建议边界与代价 |
|---|---|---|
| F1 搜索跨源聚合 | [Dart 聚合器](../flutter_legado/lib/src/domain/services/search_result_aggregator.dart) 第 4 行维护去重、四桶、来源合并及排序；[SearchNotifier](../flutter_legado/lib/src/features/search/search_notifier.dart) 第 317、386 行生产调用；[Rust 聚合器](../rust/legado-core/src/search_aggregate.rs) 第 269 行另有同目标算法 | Rust 持有每次搜索的增量聚合状态，输出批次或快照；Dart 保留展示、选项和页面状态。不要每来一批把全部历史结果传回 Rust 再聚合。书名/作者清洗属于排除项，本轮不另做修改；实际接线需等该部分口径确定。 |
| F2 阅读统计和会话归并 | [概览计算](../flutter_legado/lib/src/features/read_records/read_record_overview_calculator.dart) 第 102、137 行计算小时交集、跨设备日合计、排行及周期统计；[列表计算](../flutter_legado/lib/src/features/read_records/read_record_list_calculator.dart) 第 76 行含会话去重及 20 分钟合并 | 优先把会话归并和聚合查询放 Rust/DB，按周期取结果，避免每次把完整历史拉到 Flutter。页面周期选择、日历格子、图表坐标、本地化和纯展示排序继续留 Flutter。必须明确本地时区及夏令时边界，不能直接以固定 24 小时替代当前日历语义。 |
| F3 WebDAV 连接测试 | [设置页](../flutter_legado/lib/src/features/settings/presentation/webdav_settings_screen.dart) 第 363 行自行建立 Dart HTTP 客户端，拼 Basic Auth 并发 PROPFIND；正式传输走 [Rust 服务](../rust/legado-engine/src/webdav_service/mod.rs) | 为同一服务增加只读 probe，复用 Rust 客户端及 CustomHosts，返回认证/超时/HTTP 分类；页面只显示结果。探测是 Depth 0，不能直接拿 Depth 1 的 list_dir 冒充。需新增领域与 FFI 契约。 |
| F4 正文搜索与命中坐标 | [搜索控制器](../flutter_legado/lib/src/features/search/application/content_search_controller.dart) 第 103 行起逐章取全文、匹配并截摘要；[匹配器](../flutter_legado/lib/src/domain/services/content_search_matcher.dart) 第 2 行运行 Dart 正则/大小写匹配；结果页再次匹配摘要 | 更适合一次提交搜索请求，Rust 负责读取/缓存范围、匹配、取消与结果流，返回摘要和摘要内命中范围；Flutter 直接绘制高亮。现有 [TXT 搜索](../rust/legado-book/src/txt_search.rs) 第 229 行是局部参考，字符计数不是 UTF-16，且只面向 TXT，不能直接复用为全部在线书搜索。正则方言和 Unicode 坐标必须先固定。 |
| F5 云 TTS 能力元数据和请求分片 | [Dart Provider 表](../flutter_legado/lib/src/domain/contracts/cloud_tts_provider.dart) 第 51 行重复保存格式、默认音色、限制等；[分片算法](../flutter_legado/lib/src/domain/models/read_aloud_content.dart) 第 110 行处理字形簇、UTF-16 和 UTF-8 字节限制；Rust Provider 再次检查限制 | 先让 Rust 提供能力描述，再考虑纯分片算法；UI 文案、表单展示、系统 TTS 回调、播放器和媒体会话保留 Flutter/平台层。Rust 限制同时存在字符、UTF-16 和字节口径，不能把当前 Dart limit 不加区分地搬过去。无需重构播放架构。 |
| F6 媒体类型识别 | [BookTypePolicy](../flutter_legado/lib/src/domain/services/book_type_policy.dart) 第 18、66、187 行维护类型换算及视频/漫画源启发式；[详情服务](../flutter_legado/lib/src/data/services/book_detail_service.dart) 第 28 行起用于开读准备；Rust 的 [类型映射](../rust/legado-js/src/js_source/js_source_marshaller.rs) 第 13 行另有基础换算 | 后续把“识别为何种媒体”的只读规则集中到 Rust，返回媒体类型；Flutter 决定打开哪个页面。不是把导航搬 Rust，也不在本轮介入书籍状态写入。需覆盖已有误标视频和 HTML 图片源样例，不能只替换基础 switch。 |

F1 的 Rust JSON 聚合函数位于 [api/search.rs](../rust/legado-ffi/src/api/search.rs) 第 314 行，
当前 `ffi.rs` 与生成 Dart 接口未发现对应聚合方法，正式 Dart 搜索服务也未接入。
因此不能将其描述为“已经完整下沉”；它目前提供 Rust 算法和跨端夹具依据。

F5 当前的 [Rust 朗读状态](../rust/legado-core/src/read_aloud.rs) 第 128 行按固定标点分段，
没有 Dart 的原文偏移与三种划分模式，且主要经 Server 路径使用。
不能以“Rust 已有分段”直接替换应用朗读算法；Web/MCP 现有能力本轮不扩展。

## 6. 不应计作重复问题或强行下沉的内容

1. `fetcher/source_setup.rs` 直接 re-export JS 层实现；并不是两套 setup 算法。
2. `fetcher/explore.rs` 的书名作者函数直接委托 core；不重复建设。清洗本身亦已排除。
3. JS `symmetric_crypto.rs` 已调用 core 的 `symmetric_encrypt/decrypt`；脚本参数和对象适配应保留。
4. Engine 自动任务服务已委托 core 的构建、cron 和匹配算法；同名薄适配不等于重复业务实现。
5. net 的并发信号量、按域限流、固定窗口限流，以及 fetcher 的按来源注册表职责不同，不能合成一个限流器。
6. Flutter 布局测量、RenderParagraph 选区、动画、播放器/系统 TTS、音频焦点与平台生命周期不适合搬 Rust。
7. DTO 转换、正常 JSON 编解码和本地化展示不因是“纯计算”就值得新增一次 FFI。
8. 列表搜索、排序、日历步进等局部展示逻辑可以留 Dart；下沉目标是统一业务事实和数据处理，不是清空 Dart 逻辑。
9. 未把 cfg 分支、trait 实现、DTO 字段重复或测试夹具相似直接列为生产重复功能。

## 7. 建议实施次序与验证边界

1. **小范围复用**：R4 WebDAV 上传复用；R1 云 TTS 公共校验；R2 SSE 分帧。各自小批，不绑成大重构。
2. **独立网络正确性批次**：R3 统一 URL 组合；先锁定实际入口语义，保护 data/协议相对/纯主机/相对层级/规则 base。
3. **最小新增边界**：F3 WebDAV probe；契约先行，用本地 HTTP 服务验证状态码、认证、超时与现有 Hosts。
4. **领域状态下沉**：F1 搜索增量聚合，再 F2 阅读统计；前者等待清洗任务口径落定，后者独立冻结时区/归并规则。
5. **单独评估收益**：F4 正文搜索、F5 TTS 能力/分片、F6 媒体识别。不存在必须全部搬 Rust 的结论。
6. C1/C2 仅作为有调用证据的清理候选；用户确认后才删除，不以新增转发层延续旧管线。

只运行每批直接受影响的定向测试，复用现有云 TTS、搜索聚合、阅读统计与正文搜索夹具。
算法以 Rust 行为测试为主，Dart 验证编排、错误和显示；删除原算法后不永久维护两套同义测试。
初次审计没有运行测试、构建、性能分析或设备验证，没有改动生产代码，也没有证明实际性能提升。

## 8. B5 连接测试的实现与验证口径

契约见[API_CONTRACT §2.28](API_CONTRACT.md)。页面通过WebDavService调用只读
webdav_probe；Engine注入已有CustomHosts及运行时，Net复用WebDavClient发出
Depth0 PROPFIND。成功200/207、认证401/403、其他HTTP、超时、网络错误和非法地址
以类型化结果返回；Flutter仅映射为现有测试状态及提示，不再拼认证头或建立HTTP客户端。

与原流程的明确差异：只需要响应头，返回后立即丢弃正文，消除原先收到响应头后
无独立超时地等待完整正文的路径；地址格式也由Rust判定。网络异常不再截取原始
请求错误文本，使用稳定分类提示，防止服务器地址或凭据随异常进入界面。
测试配置仍不创建目录、不执行同步、不保存配置；并不证明有远端写权限。

协议用例采用真实本地HTTP：状态分类、Depth0、认证与空凭据、服务器路径、
未发送完整正文、5秒内没有响应头及响应前断连。应用服务用例验证注入Hosts、
不拼同步目录，并复用原有上传/同步回归。Dart只验证桥接映射、结果展示、禁用期间
不重复请求、失败可重试和测试不触发保存/同步，不重写HTTP协议算法或机械样式断言。

本机启用系统代理，Hosts夹具域名dav.test需要在测试子进程的NO_PROXY追加后运行；
不修改系统代理、生产客户端或父进程环境。绑定使用固定2.13.0生成器在隔离目录产出，
依赖锁文件保持。定向验证证据及未测边界统一回填Active计划，不另立进度源。

## 9. B7a 时间线归并边界

参考本地上游ReadRecordViewModel.kt的timelineMap和mergeContinuousSessions，
及ReadRecordSession.kt的20分钟间隔常量。沿用当前产品的开始日期分组、
书名/作者搜索、同书同作者相邻归并、首项URL/章节和最大结束时间，不改变计时数据。
上游合并末尾直接取current.endTime，现有Flutter采用最大值，本批保留现有逻辑。

Rust的[时间线查询](../rust/legado-db/src/repository/read_record_timeline.rs)从数据库
读取原始会话，返回带date与sessionIds的投影；[页面Provider](../flutter_legado/lib/src/features/read_records/read_record_list_provider.dart)
不再接收原始会话做归并。原始会话接口继续供小时统计等消费者使用，日期卡片、
章节名读取、文本格式、选择和导航留Flutter。周期统计及其他列表视图本批未迁移。

原Dart去重忽略deviceId且直接丢弃重复项，使展示项只携带一个副本ID；DB允许不同
设备的相同区间并存。新查询只折叠展示，收集全部原始ID，避免删除后残留副本；
计时扣减继续走原始会话事务，归并跨度（含中间间隔）不作为实际阅读增量。

算法用例归Rust，Dart仅测试桥接、通知/仓储替换、错误和删除交互；Mock默认明确
不支持新查询，页面测试注入类型化时间线夹具，不复制Rust归并算法。验证证据与
完成范围见Active计划。没有DB迁移、新依赖、原生库运行或性能收益结论。

## 10. B7b 周期统计与日历边界

[Rust统计查询](../rust/legado-db/src/repository/read_record_statistics.rs)直接读取每日明细、
累计记录及正式书架，统一周期时长、本数/天数、排行、日历封面与当天单书明细。
累计总时长继续来自累计表；日历与周期排行仅由有效正数明细产生，不补造缺失历史。
同日同名同作者跨设备归并，空作者仍构成身份；同日最长并列时保留最后阅读较新者。
当天明细不复用前十排行，完整返回并按时长、名称、作者排序。

类型化DTO分别返回days和chart，Flutter只映射成已有图表/日历模型，保留日期导航与
文案格式。参数化Provider负责迟到查询归属，既有成功变更通知及书架变化触发失效，
不增加另一套锁或代次。首页固定all查询，最近阅读另取累计记录，不再拉全量每日明细。
Mock默认明确不支持统计查询，测试直接提供结果夹具，不复制Rust算法。

本批不处理本地小时/DST会话求交集、记录页汇总/最后阅读列表、最近阅读开书匹配；
不改计时写入、数据库、依赖、应用版本或UI样式。聚合算法测试归Rust，Dart保留查询
编排、刷新/失败、导航隔离和交互回归。FRB绑定通过生成器更新，原生库未重新加载，
设备与性能未测；具体证据及批次状态以Active计划为准。

## 11. B7c 平台小时边界与会话聚合

平台本地时区、夏令时及日历归Flutter：以DateTime(year,month,day,hour)生成0..24点
共25个Unix毫秒边界，不用起点加固定24小时构造一天。Rust不再独立解析本地日期，
直接消费边界；允许相邻边界相等的跳时槽和跨度超过一小时的回拨槽。

[小时查询](../rust/legado-db/src/repository/read_record_hourly.rs)先用SQL筛选与当天半开
范围相交的有效会话，只读取起止时间，再将各会话与24个槽求交集。各槽毫秒汇总后
取秒，不借每日总量补造小时图，也不把时间线的设备副本折叠规则引入原有小时口径。
查询不写会话或计时表；调用方保证边界形状，不排序、补齐或静默改时区。
用户复核后确认唯一Flutter入口固定生成，运行时形状检查注释保留，移除其非法输入
测试，继续验证真实的跨日、夏令时和毫秒汇总行为。

Flutter的小时Provider只传时间戳和映射图表坐标，订阅既有成功变更，异步归属交由
Riverpod；无消费者的全量会话Provider及对应转出删除，原始会话查询接口继续保留。
原Dart小时聚合测试由Rust组合场景承接，Dart仅验证边界传递、i64列表映射、刷新与
错误/迟到结果；不对DB约束禁止的空或倒序会话绕过约束造测试。未做多时区真机或
性能测量，不把合成的夏令时边界用例当作平台时区验收。状态和证据统一见Active。

## 12. B7d 记录列表投影与重复数据链清理

[列表查询](../rust/legado-db/src/repository/read_record_list.rs)统一返回按日汇总、最后阅读
和未过滤累计总时长；页面与摘要共用同一搜索参数查询。明细先按正时长、合法日期和
书名/作者搜索筛选，再按身份与日期归并，保留设备时长叠加和最后阅读最大值。
latest只在原始明细完全没有同名书时使用累计项，不因筛选结果为空而补造历史，
累计作者集合字符串不拆分。这是现有口径的职责迁移，不是新的历史数据兼容层。

新增FFI命名为read_record_views，原始read_record_list()继续返回原记录，互不替代。
类型化列表字段含bookName/author/date/durationMs/lastRead；Flutter只做界面选中键、
日期卡片组织/合计、格式化、书架封面匹配和导航。时间线仍由B7a单独查询，不混入
累计或每日数据。视图切换复用同一列表投影，摘要直接使用latest和totalTimeMs。

旧全量Dataset移除，最近阅读仍有消费者的累计Provider归位独立文件，不留旧路径转发。
偏好Notifier原来的records/totalReadTimeMs、业务排序及无人调用的删除/查书包装移除，
只保留共享偏好加载、记录开关、搜索状态和偏好持久化；计时和删除仓储事务不变。
列表下拉刷新、当天明细重试、首页统计重试均指向实际查询，不再失效旧快照。

算法组合测试由Rust承接，Dart保留查询/通知/仓储替换、偏好、删除交互与重试；Mock
直接提供列表投影，不从其原始数据重写归并。无DB迁移、新依赖、版本变动、原生库
加载或设备/性能验收；结果及证据统一维护于Active计划。

## 13. B7e 固定输入与订阅生命周期检查精简

周期标签表覆盖完整枚举，TabBar点击索引由同一表产生，移除越界回退和重复范围检查；
仍保留索引变化才动画的条件。热力图和日期标签只消费Rust已归一化日期，直接转换，
不再默默忽略格式错误或回退原文；日期分组仅用于汇总/时间线，移除空串兜底。
柱状图rawMaxSec<=0与紧随其后的rawMaxSec<60返回相同值，删除被覆盖分支。

六处变更通知回调均为同步处理，Provider销毁时已经调用subscription.cancel；依据
[Dart取消订阅契约](https://api.dart.dev/dart-async/StreamSubscription/cancel.html)，调用后
不再接收事件，Future仅表示资源清理结束，因此去掉回调内重复mounted检查。
onDispose取消、跨await的生命周期处理及其他真实数据校验保留。这里是特定调用链
的精简，不建立全仓禁止mounted、日期解析或输入校验的规则；验证状态见Active。

## 14. B8a 云TTS请求限制的权威来源

Core的`CloudTtsProviderType::speech_limits()`提供应用请求分片阈值，FFI经类型化
`CloudTtsSpeechLimitsDto`传出。查询只接受已有Provider枚举，不读取引擎、凭据、数据库
或网络；正式Dart仓储只映射值，未知Provider由已有字符串到枚举转换拒绝。

UTF-16单位与Unicode字符数不同：OpenAI的4096字符硬限制不等于应用4000 UTF-16
阈值；百炼600、Polly3000仍采用原先的保守UTF-16上限，火山另限1024 UTF-8字节。
已有Provider请求校验保留各自单位，长度常量从同一Core模块读取，不以元数据代替
外部请求校验。Mock提供明确的离线夹具，不把夹具表当作另一份生产规则来源。

Flutter配置表删除长度字段；控制器查询结果由当前队列与后台预合成共同消费，
单段云引擎独立消费同一接口。查询等待期间沿用已有代次/会话校验，失败上抛而不
回退配置表。原文映射、字形簇分片算法、预合成窗口、播放器及缓存身份保持。
UI名称/默认模型/格式和表单能力仍留Dart，本批不声称全部云TTS元数据已收敛。

复用原有Provider长度边界测试，补一项多字节文本经实际请求准备的查询一致性验证；
Dart验证桥接传参/单位映射、查询失败与等待期间停止，并复用播放、预合成及表单回归。
不增加逐字段机械断言，不调用真实云服务；验证与未测边界统一记录Active计划。

## 15. B8b 默认请求与表单能力描述

Core的`cloud_tts/capabilities.rs`统一八家Provider的新建模型、默认音色、格式、风格、
目录发现方式、凭据/参数开关及既有编辑范围。DB构建默认合成请求时复用音色与首选
格式；OpenAI和火山的格式/倍率校验、Polly采样率及MiMo音色风格列表复用同一描述。
协议编码映射（如WAV转PCM）继续留Provider，不能用一份格式清单替代协议转换。

Azure等协议入口已有较宽的数值接受范围，描述中的数值区间沿用原界面编辑范围，
不借收敛改变既有配置或远端请求语义。模型/音色动态约束、服务响应和真实凭据仍由
原执行链处理；静态能力不证明账号已取得某音色的权限。

`cloud_tts_capabilities`只返回类型化快照，经正式仓储映射后由表单消费；Mock单独提供
离线夹具。引擎表单打开前加载整张能力表，音色编辑同样先读取所属Provider能力，
失败经现有页面错误面展示，重新操作即可重试，不新增本地业务表回退或自动重试。
组件只接收快照，不新增全局可变注册表、初始化锁或后台缓存。

Flutter的名称、字段标签、提示及显示顺序归位`cloud_tts_provider_labels.dart`；原领域
文件仅保留无默认配置的能力数据模型。编辑保留原模型/音色参数及未展示字段，不读写
历史键或自动改写引擎。HTTP/系统音色编辑不依赖云能力，播放及分片算法不变。

新增一项Core组合行为用例，将描述中的默认值、格式、可编辑倍率及采样率送入实际
Provider准备逻辑；复用DB配置及Flutter各家表单/试听回归。Dart只补能力映射、失败与
管理页重试后消费返回默认模型的行为测试，不复制Provider算法或锁定样式常量。
验证、生成hash、提交和未测限制统一记录Active计划。

## 16. 内容划分与本地上游的差异核对

核对基线：OpenLegado c249cf508；本地参考源码
`build/upstream/legado-with-MD3` / c4182eb9b（2026-10-19），没有联网更新上游。
本节只核对切分层及追踪到的云合成调用链，不把辅助函数差异直接等同最终设备表现。

| 项目 | OpenLegado | 本地上游证据与差异 |
|---|---|---|
| 用户默认模式 | 缺省paragraph，整段 | ContentSplitPolicies.resolve/forMode将Default解析成Paragraph；实际设置口径一致。内部SentenceLevel策略不同于用户设置缺省，不混为一谈。 |
| 符号模式 | 相同14种标点、空选择回退句末集合；连续选中标点留前一单元，保留UTF-16起点 | ReadAloudContentSplit.kt:148/155/212同样处理；结束引号不在所选集合，两侧均可能将其留到下一单元。 |
| 换行及空白 | read_aloud_content.dart:53处理CRLF/CR/LF/U+2028/U+2029，_appendTrimmed裁两端空白并修正起点、忽略空白段 | ReadAloudContentSplit.kt:194的lineParagraphs仅按LF切分，此层保留非空片段的原始空白；其他上游过滤/清洗是另一步，不声称最终会朗读空白。 |
| 页面模式 | read_aloud_content.dart:23直接将一个完整页面范围作为一个单元，页面内可含多个段落 | ReaderReadAloudChapter.kt:105/108先建段落，再按pageStarts切开每段；paragraphs(Page)仍取这些保留段落边界的片段，不把同页段落整体合并。 |
| 段末元信息 | ReadAloudUnit只有start/text，播放cue携带原文位置和当前单元编号 | ReaderReadAloudParagraph另有isParagraphEnd，跨页切片与符号重切后仍区分真实段末；这是模型差异，不据此断言当前停顿一定错误。 |
| 云请求长度分片 | splitSpeechRequests在朗读单元之内按UTF-16/UTF-8限制再次分片，优先句末/词边界/字形簇 | 此次追踪的HttpReadAloudService→CloudTtsAudioSynthesizer.kt:78→各Provider链路直接使用传入text，未找到等价的通用长度分片步骤；上游角色/台词规划是另一层，不混作请求长度算法。 |

当前本地行为探针得到：短句接超长句、limit600时分片长度为3/600/100；601字得到
600/1；英文Mr.可能单独成片。这些来自我方splitSpeechRequests，不称为已复刻的
上游策略。符号引号探针结果为`他说：“你好！`和`”然后离开。`；其暂缓状态只记Active。

本轮没有调整任何生产切分逻辑、请求长度或原文坐标，没有新增持久测试；只读源码、
运行忽略目录内的Dart行为探针并记录差异。单引号/括号吸收、短片平衡与缩写识别等
优化尚未实施，不能把前一轮建议写成已经采用的规则。

编写者：Codex + Rust / UI｜2026-10-23

## 17. B8c 页面切分与真实段末归属

按本地参考c4182eb9b的ReaderReadAloudChapter.kt:96–125，先建原段落，
再按严格位于该段内部的页起点切片，多个段落即使同页也不合并。
阅读器仍提供完整真实页范围，复用既有一致性校验；共同页起点去重，避免
标题等零文本页导致空朗读单元。不采用猜测页宽或字数的后备切分。

ReadAloudUnit携带start/text/sourceParagraphIndex/isParagraphEnd，end派生；
slice用段内UTF-16偏移，只有包含原单元末尾的最后一片继承真实段末。
符号模式只换元信息传递，不改变断点；结束引号问题继续按Active记录暂缓。
SpeechRequestPart仅代表云请求长度范围，不携带段落身份；播放cue从所属
ReadAloudUnit切片取得原文范围与段末，unitIndex单独用于导航和缓存的播放索引。
没有将真实段末标记改为新的停顿条件，段间间隔仍按现有播放单元执行。

新增页面合并复现用例在旧代码输出两单元，正确结果为四单元；修复后验证
跨页段尾、同页后续段落与Unicode范围。复用现有符号、云长度、播放列表、
章末和预合成回归，并覆盖暂停重排后从原文锚点继续，避免为模型字段逐个
重复立测试。验证命令、数量、首轮装配失败和未测边界只维护于Active计划。

本批没有移动云请求分片算法到Rust，没有改变换行/裁空白策略、请求阈值、
数据库或FRB；源码参照不代替设备听感与连续后台播放验收。

编写者：Codex + UI｜2026-10-23

## 18. B8d 无状态朗读规划边界

审查原方案后将批量结果按输入顺序返回，移除重复inputIndex和无额外字段的计划包装。
当前布局finish释放会话，完整章节/页缓存仍在Flutter，因此不直接查询已完成的布局句柄，
也不引入全局章节注册表；以既有原文与真实页范围调用Core纯函数。

Core/read_aloud_partition复用SourceRange，整段/符号/页面统一输出UTF-16半开范围与
原段落编号/真实段末。页面核验保留真实可达的缺页、范围及字形簇边界错误；既有换行、
空白和引号切分保持。云请求按Provider内部限制批量分片，不再接受自定义limit，移除旧
参数已不可达的零上限检查；单个超长字形簇仍可由实际正文触发，保留明确失败。

Flutter规划端口异步取得范围后仅截取原文；前台生成播放cue前、后台窗口yield前和试听
起播前复用既有会话身份，防止停止/切章后的旧计算发布。暂停恢复提交剩余文本并沿用
原文基点。页界登记不执行重复FFI计算；真正生成页面朗读计划时统一核验。
系统TTS/HTTP不执行云长度分片，播放器、媒体控制、缓存身份和停顿粒度保持。

迁移前行为录制只用于基线夹具，最终生产没有采集代码。92组去重样例由Rust组合测试
核对，删除已被替代Dart算法用例；Dart端使用相同的明确范围夹具验证编排，不重写算法。
正式Mock端没有夹具时明确不支持，避免假装拥有Rust切分能力。原限制只读查询仍保留为
既有公开能力，当前切分消费Provider本身，不使用Dart重复规则。验证与历史基线失败见Active。

本批将锁文件已有unicode-segmentation1.13.3纳入Core直接依赖，不引入新包或升级版本。
没有测量性能或加载新原生库，不能把职责收敛表述为已证明的速度/内存收益。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

## 19. B9 查询级增量搜索聚合

Core现有跨源规则已覆盖原始三元组预去重、ECMAScript等价归一化、四桶、来源保序、
阅读标记OR与首到平局。本批提取查询级SearchAggregation，一次性入口直接复用，
保留其空关键词原样返回；不重写清洗规则，也不介入解析或正文搜索。

直接将完整Book经SearchBookDto往返会丢失DTO未覆盖元数据。新增只读聚合句柄只
接收规则需要的字段，返回新建组的批内输入索引和原生代表ID；Flutter只保存这些
首条完整SearchResult，快照按ID覆盖归一化名称/作者、来源和阅读标记。Rust保留
聚合状态，Dart不保存全部历史批次，也不在每次更新时重传历史数据。

Dart适配按add→snapshot→close顺序串行异步FFI，避免线程池调度改变批次顺序；
无全局会话ID表或额外注册机制。other始终存在于查询，精准参数只决定快照投影；
自然结束仍可续页，新关键词、清空或页面/Provider生命周期结束才释放。

界面维持150ms快照节流，流自然结束等待末次快照。停止与流错误必须先让网络回调
失效，再等待已接收输入的最终快照，避免等待中接收新批次；新的查询可在此期间
启动，原seq和聚合对象身份用于拒绝迟到快照。网络暂停/取消仍由原SearchSession
负责，聚合close只释放本查询数据，不调用进程级网络取消。

算法语义由原夹具和96组录制快照在Rust验证，Dart纯算法副本及同义用例删除。
Dart保留桥接、完整元数据、串行调用、末批等待、停止重搜、流错误、续页、范围、
前后台和失败横幅回归。Mock只查询明确输入/输出夹具，未配置能力明确报不支持。
验证、首次测试断言问题、提交及未测边界仅维护于Active计划。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

## 20. B10a 正文匹配与摘要范围

本地MD3的SearchContentRepository.searchPosition使用Kotlin Regex.findAll，普通查找
使用区分大小写的indexOf；getResultAndQueryIndex围绕实际matchLength取12单位摘要。
原版目前也采用区分大小写匹配，但摘要为20单位，存在版本差异。本批只收敛匹配职责，
不借此重做搜索范围或摘要样式，保留本项目普通忽略大小写、30单位上下文及结果上限。

Core/content_search按每次查询编译，通过既有安全regex/fancy-regex支持常用上游模式，
以14组JDK Pattern输出核对范围；未引入新正则依赖或宣称覆盖全部Java方言。普通模式
小写文本匹配后映射到原文，避免İ等转换长度变化令后续命中偏移。UTF-8字节边界与
UTF-16位置一次建表，摘要对齐Unicode标量边界，保留换行替空格与省略号后的命中位置。

结果携带原文范围、摘要及摘要内范围；页面直接高亮这一条命中，不再次执行原正则。
例如(?<=a{40})甲在正文可命中，截成30单位上下文后无法再次匹配；旧页面二次匹配会
丢高亮，新接线按已返回范围显示。Rust组合场景与Flutter实际选项/提交/结果绘制分别
验证算法和消费，Dart不复制算法；原7项Dart匹配测试移除。

查询句柄不可变，不新增注册表或串行锁；Controller的一次search在finally释放。
停止/替换/清空后的原生迟到结果复用已有generation拒绝发布，等待释放归任务自身。
本批没有迁移章节IO、缓存筛选或真正取消网络；这些不能因换成原生匹配就宣称完成。
验证数量、失败修正、提交及边界仅维护于Active计划。

编写者：Codex + Rust / UI / Bridge｜2026-10-23
