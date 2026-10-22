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

[audio_preload.rs](../rust/legado-core/src/audio_preload.rs) 定义了
`AudioPreloadStore`、`AudioDiskCache`、`PlaylistManager`。
对这些类型逐个查找，使用点局限于该文件自身与测试；`lib.rs` 仍公开模块。
当前正式音频缓存由 [audio_cache_service.rs](../rust/legado-engine/src/audio_cache_service.rs) 管理。

后续可以作为旧代码删除候选核对，不应为了复用而强行接入正式缓存。
仓库内无调用不等于证明不存在外部 Rust API 消费者；本轮没有删除。

### C2：旧的模板式合成入口与仍在用的缓存工具在同一文件

[tts_speak.rs](../rust/legado-core/src/tts_speak.rs) 中，
`speak_text`（第 256 行）、`build_speak_url` 及其旧响应/结果类型未找到仓库内生产调用，
相关调用局限于本文件测试；正式 HTTP TTS 已经过 Engine 和 Fetcher 的规则合成链。

但同文件的 `SpeakCache`、MIME 工具仍被
[HTTP Fetcher](../rust/legado-fetcher/src/tts_fetcher.rs) 和
[Cloud Fetcher](../rust/legado-fetcher/src/cloud_tts.rs) 使用。
只能在确认后拆分和删除旧管线，不能整文件移除，也不能再造一套正式缓存。

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

编写者：Codex + Rust / UI｜2026-10-23
