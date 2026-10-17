# FFI 传输层现代化方案

初始基线：`feature/ui-reader-selection` / `361cced7e`；后按用户授权 rebase 至 `1b871c3c4`（2026-10-17）。
本文件记录源码核查、建议与验收方法；任务状态仅维护于 [Active](REFACTORING_ACTIVE_PLAN.md)。

## 1. 目标与范围

保留 Rust EngineContext、Flutter 页面行为与既有领域模型，分领域将内部 FFI 载荷改为强类型。
仅单源校验窄接口改为接收 BookSource 实体，避免 Dart 重复解析原先由 Rust 导入器处理的书源 JSON；
现有配置文档、导入导出与网络协议继续在各自边界解析。
准备阶段仅核查；实施批按下文冻结并修改 FFI 契约与绑定，依赖、数据库和应用版本保持不变。
无 GitNexus 可调用工具，本次采用本地源码检查；不声称图索引已更新。
不使用子代理，不触发远程 CI，不自动提交、推送或构建安装 Flutter 应用；按批重建 native 库并验证真实 FFI。

以下方案为实施建议，具体字段和签名仍须在每批实现前核对并冻结契约。
不为现代化而增加 crate、重写业务或将所有持久化/导入 JSON 一并替换。

## 2. 当前实现与原提案的修正

| 项目 | 当前源码依据 | 实施结论 |
| --- | --- | --- |
| DTO | `rust/legado-ffi/src/ffi.rs` 的书架、书源、书签、阅读记录导出仍大量返回 String；Rust 底层已有实体 | 在桥接边界定义 DTO 并直接转换底层实体；禁止内部仍 JSON 往返、仅外层包 Struct |
| 二进制 | `api/cbz_api.rs` 返回 `{base64,len}`；`ffi.rs` 图片缓存读写和 `fetch_image_with_decode` 也有 base64 | CBZ、图片解码和缓存读写都应改；同时覆盖 Dart→Rust，不能只改读取 |
| 编解码 | `frb_generated.rs` 当前函数和默认 StreamSink 使用 SseCodec | Vec<u8> 映射 Uint8List 可以去掉 base64，但 SSE 仍有编解码/复制；不直接宣称零拷贝 |
| 封面/字体 | `cover_api.rs` 是封面规则 CRUD/搜索；当前 ffi.rs 没有字体字节导出 | 不按文件名加入二进制范围；以后只迁移实际存在的字节接口 |
| 音频 | `audio_cache_download` 字节留在 Rust 流式下载落盘；`tts_speak` 返回音频路径及缓存/MIME 信息 | 保留文件播放方案；结果元数据可以类型化，不把整段音频搬入 Dart 内存 |
| 现有流 | `search_multi_stream`、`source_check_stream`、`source_switch_search_stream` 已使用 StreamSink<String> | 首先改为类型化事件及明确取消；不重建第二套搜索执行链 |
| 现有句柄 | `ffi.rs` 已有 opaque TtsRequest，具有同步 cancel 和音频缓存租约 | 审核并复用，不将 TTS 描述为尚未句柄化 |
| 排版 | `layout_bridge.rs` 使用全局会话表、字符串 ID、JSON 配置/块/结果，并有数量与批次限制 | 适合 LayoutSession 句柄化；与布局 DTO 同批处理，保留所有资源限制与取消语义 |

官方说明：[codec](https://cjycode.com/flutter_rust_bridge/guides/miscellaneous/codec)、
[零拷贝条件](https://cjycode.com/flutter_rust_bridge/guides/types/translatable/zero-copy)、
[Stream](https://cjycode.com/flutter_rust_bridge/guides/types/translatable/stream)、
[Opaque 释放](https://cjycode.com/flutter_rust_bridge/guides/types/arbitrary/rust-auto-opaque/dispose)。
版本核对：[FRB 2.13.0 StreamSink 源码](https://github.com/fzyzcjy/flutter_rust_bridge/blob/v2.13.0/frb_rust/src/stream/stream_sink.rs)。
官方在线指南可能随版本变化，实际选择以项目 2.13.0 生成器、运行时源码和生成结果为准。

## 3. Task 1：契约类型化

首批完整迁移书签 CRUD/查询和每日阅读明细查询。原书签新增主要使用标量，不能按示例假定所有接口都是 JSON 输入。
下一批为 Book/Chapter 和搜索结果所需 DTO，随后处理字段嵌套较多的 BookSource。
书源含规则、登录配置及可扩展字段，不属于低风险试点；先列出字段完整性用例。

- DTO 定义在 legado-ffi 边界模块中，由 `crate::ffi` 导出并被现有 rust_input 发现；不暴露数据库连接或内部锁。
- Rust 用显式 From/TryFrom 连接已有领域模型；Dart data 适配器转换到现有领域模型，页面不依赖生成 DTO。
- 生成 Struct 保证字段/类型匹配，不替代 URL、范围、时间单位、业务状态等运行期校验。
- 逐项明确空值/缺省值、负值、i64 ID/毫秒映射、可空查询结果、嵌套集合及枚举错误策略。
- 实际操作结果按现有语义保留，例如 update 原本返回 void 时不因示例随意变为 BookDto。
- 书源导入导出、备份、HTTP/REST、JS 规则及确实属于 JSON 文本的用户数据保留 JSON 边界。
- 一批同时修改 API、生成物、Rust 实现和 Dart 消费者；没有实际消费者要求时不长期维持双版本接口。

## 4. Task 2：二进制直传与 codec 验证

优先迁移 `cbz_read_page`、`fetch_image_with_decode`、`get_image_cache`、`save_image_cache`。
底层图片缓存已支持 Vec<u8>/字节切片，优先修薄桥接层，保留现有缓存键、图片解码和错误降级语义。

1. 以 Vec<u8>/Option<Vec<u8>> 对接 Uint8List，去除边界 base64 和冗余 len；含 MIME 等信息时返回带字节字段的 DTO。
2. 首先沿用当前 codec 验证正确性。针对大字节结果评估 2.13.0 的 CST/DCO 路径、生成配置和 LLVM/平台依赖。
3. 只有确认生成代码和真实调用路径支持外部 TypedData 后，才能将对应方向/平台称为零拷贝；不把它扩展到解压、图片解码和 Dart→Rust。
4. 不为单个大载荷无条件切换全项目 codec；确认是否支持局部选择，并比较生成/构建成本与收益。
5. 限制压缩包条目与响应大小，保留未命中、坏包、空字节、缓存 I/O 失败与取消规则，防止完整大对象滞留。

Base64 字符长度约为 `4*ceil(n/3)`，并非总进程内存恰好增加 33%。
峰值取决于原字节、JSON 字符串、桥接缓冲和 Dart 解码对象是否同时存活，需要测量。

## 5. Task 3：类型化流与取消

复用现有搜索/校验/换源执行链和 EngineContext TaskGroup，不为每次事件穿透持有根 Engine。

- 定义带有结果批次、进度、单源失败、完成或取消语义的 DTO/Enum；终态最多一次，终态之后不发布。
- 搜索保留按源批次，换源保留当前累计快照与排序/增强语义；逐条发送或改为增量需要消费者和行为证据支持。
- Rust 回调直接产生事件 DTO，不先拼 JSON 再解析。共享 Server/HTTP 边界继续在其适配层序列化。
- Dart 取消订阅须显式取消对应操作；sink 发送失败也取消。StreamSink 本身不会自动管理项目 CancellationToken。
- 无事件产生时仍须可以取消，不能等下一次 sink.add 失败才发现取消。
- 不将暂停订阅视为生产者背压。限定并发和内部队列，必要时合并进度；可靠结果的有界传输需单独定义批次/确认策略。
- 保留已实现的真实阻塞任务寿命跟踪、迟到写入拒绝和宿主关闭规则；取消不宣称强制终止同步 JS。
- 不将适合即时查询的普通列表或 CRUD 全部改成流。

## 6. Task 4：句柄化资源

首选 LayoutSession，直接封装 PaginationSession 与取消状态，替换字符串会话表。
同时迁移 Config、Block、Page/紧凑列结果，保留现有列式布局优势，避免盲目改成大量逐字 Dart 对象。

- 句柄方法采用明确的开放/完成/取消状态；push/finish 并发有序，finish 后不能再 push。
- 可以采用内部 Option<State> 和显式 finish/close，而非未经 codegen 验证就依赖 finish(self) 的消费方式。
- cancel 必须可在长计算期间及时设置标志，不被持有整个排版状态的锁阻塞。
- Flutter 生命周期内显式 cancel/close 后 dispose，try/finally 覆盖错误路径；GC 仅作内存回收兜底。
- dispose 释放 Dart 持有引用，不保证所有在途 Arc 或任务立刻终止；Drop 不执行等待式异步关闭。
- 删除 ID Map 后仍保留最大并发会话数、单批内容块/行内项限制、内存预算和失效保护；JSON 字节限制改为等价的载荷预算。
- TTS 复用 TtsRequest，确认取消与租约释放；持久化下载 ID 仍是业务标识，不因句柄化一律删除。

## 7. 实施顺序与交付

| 顺序 | 交付范围 | 主要验收 |
| --- | --- | --- |
| P1 | Bookmark + ReadRecordDetail 类型化试点 | 字段/ID/时间/空值语义、实际 FFI 往返、原消费者测试通过 |
| P2 | CBZ/图片读写字节直传，局部 codec 评估 | 真实 CBZ 字节一致、缓存命中/未命中、大小限制、原图片读取测试；记录传输收益 |
| P3 | Book/Chapter/BookSource DTO + 现有流事件类型化 | 核心字段无丢失、批次/排序不变、真实 Stream 取消与迟到结果测试 |
| P4 | LayoutSession 与布局 DTO 同步迁移，复核既有 TTS 句柄 | 页面结果/原文映射不变、完成/取消/释放/并发限制、排版 profile 对照 |

四项工作允许按实际依赖调整，但不拆成大量无独立交付的小组；每项只做必要验证。
每批先冻结 API_CONTRACT，再 Rust DTO/导出及 Dart 仓储联动，使用
`python scripts/dev.py generate bridge` 同次生成双方绑定，保持 FRB 2.13.0 三侧一致。
随后显式重建 native 库，执行相关 Rust 测试、Flutter 分析/测试及至少一个真实宿主 FFI 往返。
只验证 content hash 不足以证明来源，继续使用现有 Python 指纹/摘要门禁。
codegen 不替代依赖恢复；使用现有 lockfile，不自动升级依赖。

性能仅在相关批次比较：相同环境、构建模式、样本和重复次数下测端到端耗时及进程/Dart/native 内存；
区分跨桥接耗时、解压/解码耗时与完整排版耗时。沿用 `scripts/reader_layout_profile.py` 的 profile 口径。
不以 Debug 时间证明产品性能，不预先承诺零分配、零拷贝或固定百分比提升。
Android/iOS 构建与设备验证按用户实际授权和环境记录，不默认启动全量 CI。

## 8. Codec 取舍与性能口径

核对本机 FRB 2.13.0 的 internal_config_parser 与 function/real 解析器：full_dep=false
强制 PDE 调度，其载荷使用 SSE；函数上的 codec 注解会被覆盖。启用 CST/DCO 需要切换
full_dep 及生成接线，影响整套桥接和各平台构建。当前保留已验证的 SSE，不为四个图片接口
扩展全局 codec 迁移；此决定完成局部评估，不表示实现了零拷贝。

同一 release 进程对相同 1538 页交替执行旧 pack_pages + JSON 序列化和新
pack_pages_binary，预热一轮、有效 25 轮。中位数分别为 13704µs 与 7290µs，
P95 为 15191µs 与 8425µs。这里只比较 Rust 打包工作，新路径尚未计入 FRB 编码和 Dart
列适配，不能外推整体 FFI、首屏、翻页或内存收益。原始计时与可重跑的独立基准源保存在
忽略目录 build/ffi-phase3/wire-benchmark；不引入生产依赖。

二进制数值列 490392 字节与完整旧 JSON 1855936 字节口径不同，不能相减作为内存节省。
未运行应用设备 profile、RSS/堆对照或 Android/iOS 构建；这些不由 Windows Debug
真实 FFI 测试替代。原有 profile 采集入口保留；新 call 计时含字段映射与返回适配，旧
JSON 编解码计时归零，进行设备对照时须使用整次调用/整章指标。

## 9. 剩余主链路的迁移边界

普通搜索、精搜、多源搜索统一接收 URL 列表，直接返回 SearchBookDto 或 AnnotatedCandidateDto；
换源搜索接收四项显式选项，返回候选 DTO，应用换源直接返回 BookDto。
原有 Server 和测试 JSON 入口只做边界转换，共用同一搜索/换源实现，不再作为正式 FFI 的中间步骤。

单源校验接收 BookSourceDto 与 SourceCheckConfigDto，批量校验接收 URL 列表、配置和独立请求句柄。
用户保存的校验配置仍是 JSON 文档，在 Dart 数据适配器转换一次；单次错误报告失败，批量错误回落默认值，
保持原有行为。校验结果和进度直接按 DTO 返回。

目录查询与刷新直接返回 ChapterListDto。正文获取返回 TextResponseDto：普通正文原样透传，
已有 JS 平台协议只在 Rust 边界识别并转为动作枚举和参数；Dart 继续使用现有平台执行器。
这不改变 JS 协议，也不将未知 action 的普通 JSON 正文解释为平台动作。

严格 Clippy 的既有参数数目、冗余借用、测试锁跨 await、文档与断言问题随本批修复；
内部参数分组保留原业务逻辑，不添加 lint allow，不通过跳过检查解决。
相关验证覆盖真实本地 HTTP 的搜索、精搜、校验、目录、正文和两种换源应用，
以及原生布局句柄、字节直传、实体往返和流取消。实际结果统一登记 Active。

本轮不将全部 FFI 字符串等同于需要删除的 JSON；尚未列入上述范围的其他领域接口仍按各自契约维护。
导入、导出、JS、HTTP/REST 和配置文档中的 JSON 保持原有协议。

阅读域后续补齐累计阅读、每日整秒统计、阅读会话、书架分组和正文标注/规则。
累计阅读与分组复用既有字段投影，新增会话/日统计和标注/规则 DTO 连接原实体；
分组新增/更新仍使用原标量接口，领域中未由分组列表返回的字段继续采用原默认值。
标注和规则的样式文档保持字符串，Dart 与 Rust 间不再序列化整个实体。
高亮旧 JSON 保存入口没有生产消费者，移除后测试直接调用同一实体实现。
非正规则 ID 按旧 Dart 序列化语义归一为 0；直接编码前显式拒绝超范围 i32，
保留未知标题长度 -1、可空 scope、毫秒/秒区分以及原排序和错误传播。
该批不新建流或资源句柄，也不将阅读器、总览、分组页面改为消费生成 DTO。

后续网络/书源批使用独立content_dto承载HTTP响应、WebBook部分抓取快照、发现控件与段评模型。
抓取部分结果不伪装为完整持久化Book，Dart适配器补入原有书源身份/稳定书籍归属；
发现保留相对URL归一和控件默认值。段评上下文的书籍/章节直接转换到领域实体，
动态书源配置文档与JS动作列表继续在已有协议边界解析；正式HTTP字节不再经过base64。

## 10. 回退与边界

后续各领域继续保持专用传输模块：content_dto承载抓取快照，media_dto承载朗读/音色/缓存，
task_dto承载下载观察及交互事件，business_dto承载RSS/规则/历史/日志等稳定实体。
Flutter页面消费既有领域模型，生成DTO仅在data适配器流转。

HTTP TTS普通编辑与文档导入分开：普通编辑直接传16字段，导入文档由Rust保留内嵌音色目录、
数组loginUi和既有逐条提交语义。音频合成仍返回本地文件路径；TtsRequest继续拥有取消和音频文件租约。
不会为了字节直传把已落盘音频全部搬回Dart。

章节下载观察流先订阅实例watch通知，再读初始完整快照；变化可合并，但每次读的是最新状态。
不做后台定时轮询，也不把观察句柄当下载任务。业务任务ID保留可持久化身份，退订只取消观察；
宿主关闭则由所属TaskGroup结束观察。缓存队列与离线缓存页订阅快照，后者用请求代数拒绝迟到查询。
调试、验证码、WebView以独立取消凭据管理订阅；退订验证码/WebView不替代用户提交/业务取消。

稳定业务结果直接从原生实体转换，不允许“原生先JSON序列化、FFI再反解”的中间适配。
真正书源/规则/登录/备份文档、动态JS动作及格式化日志导出维持原协议。
备份文件列表改传摘要结构，既有领域API仍将其转换为文件描述文本；本轮不重新设计备份界面。
词典和规则订阅排序使用FRB公共Int64List，避免与dart:typed_data同名类型混用。

此任务限定于已冻结的领域载荷。未列入冻结范围的自动任务脚本协议、平台登录表单、
本地书籍导入诊断、书籍导出与压缩工具等接口继续按原契约维护，不宣称全仓已无JSON String。
真实JSON导入测试保留；仅旧传输中无法由DTO表示的坏JSON测试改为字段、空结果、原生错误与真实wire验证。

按领域保留可回退的完整变更，不拆开生成绑定与原生库配对；回退后也必须重建对应 native。
不改数据库 schema/备份格式，不做 EngineContext 二次重构，不扩展未授权 UI。
不以静态审计替代运行验证；每批实际命令、结果与未测边界登记在 Active，不在此重复维护状态。

编写者：Codex｜2026-10-17
