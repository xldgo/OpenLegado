# 朗读系统与 MD3 上游的功能差异

本文保存最初按用户要求完成的源码调查。用户随后指定实施基线 `2d5ce051a`，并批准优先 Flutter；首批起点与朗读偏好设置的进度见 Active 计划，下列差异表仍是改动前快照。依据代码路径核对能力，不把配置字段、界面入口或历史测试记录视为功能已完整接通。任务状态只维护在 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。

## 1. 固定对照与证据边界

- 调查时本项目：`feature/ui-reader-refinement`，基线 `a5db7714b9fddfc1490a75685b08d5a855b0c41a`。
- 工作区：`build/worktrees/reader-overlay`，已从旧分支切换到上述最新分支；主目录的未提交 `AGENTS.md` 未带入或修改。
- MD3 上游：`HapeLee/legado-with-MD3`，本轮查询 `main` 为 `070ca1a9b2e491654f70c105bca9939968023940`，以下链接全部固定到该提交。
- 范围：阅读器朗读入口、播放器、设置、引擎与音色、播放队列、定时、媒体会话、缓存，以及上游角色配音与配乐扩展。
- 本轮只做源码调查及文档整理，没有编译、安装、设备操作或运行测试。既有功能的设备可用性仍以相应任务的实际证据为准。
- Android 原版 `gedoor/legado` 当前公开 `main` 查询为 `9bb0569269ed557753fc3866250970de6d454fcf`，未提供本次需要的四份旧朗读源码，按路径查询提交历史也没有结果。因此不宣称完成当前原版交叉核对；涉及默认行为取舍，实施前仍需核对可用的固定原版源码或设备。此限制不影响下列 MD3 与本项目的源码对照。

上游下载的核对材料仅放在忽略目录 `build/read-aloud-upstream/`，不把第三方源码加入本项目。

## 2. 基础播放与正文联动

上游依据：[起点转换](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/ReadAloudStartPosition.kt)、[可见正文位置](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/readaloud/ReaderVisibleTextPositionPolicy.kt)、[系统朗读](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/service/TTSReadAloudService.kt)、[HTTP 朗读](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt)。

| 功能 | MD3 上游 | 本项目与差异 |
|---|---|---|
| 普通朗读起点 | 接收绝对章内位置；滚动视口可求首个可见正文位置，排除章节标题 | `ReaderScreen._startReadAloud` 只传章节，没有传当前正文 UTF-16 锚点；不保证从眼前正文开始 |
| 选区朗读起点 | 可以把章内位置传到朗读服务 | 已传选区 `start`，但 `AudioNotifier` 只映射为段号，再朗读整段，段内偏移丢失；精准选区不等于精准起读 |
| 播放、暂停、停止 | 服务会话统一管理 | 已有系统与 HTTP 两条真实播放路径及相应控制；不能作为未实现项重写 |
| 上下段、上下章 | 播放队列区分手动移动、自然结束和位置 | 已有控制；段号是 Notifier 私有字段加 ChangeNotifier 通知，章节是 Riverpod 状态，数据通知分为两套 |
| 暂停时移动 | 服务有独立暂停与移动处理 | `next`、`previous`、`jumpTo` 均继续调用 `play`；段落按钮对暂停另有处理，需要明确同类操作是否保持暂停，而不是笼统声称缺少切换能力 |
| 朗读正文进度 | 系统 TTS 的 `onRangeStart` 更新章内位置，参与阅读页跟随；HTTP 路径维护朗读单元位置 | 系统服务未接 `setProgressHandler`；正文显示未订阅朗读原文范围，没有完整的朗读高亮、翻页跟随与正文进度回写链路 |
| 暂停续读 | 系统路径追踪已朗读范围，并处理迟到事件 | 本项目已实现停止屏障、分片、暂停与恢复；缺少对外发布的正文范围，不应推翻已有事件防护 |
| 内容划分 | 默认、整段、整页、按符号；符号集合可选 | 固定按换行或空行切段；没有划分设置。上游实际 `ContentSplitPolicies.resolve` 把默认解析为整段，不能照旧注释误写成默认按句 |
| 段间停顿 | 有 `ttsParagraphInterval` | 当前自然结束后立即推进，无对应设置与实际等待 |
| 无引擎处理 | 引擎选择器有系统、HTTP 与云端路径 | 系统 TTS 已可手动选择；自动默认选择仍只筛选兼容 GET HTTP 源，不自动选系统 TTS |
| 合成／播放失败 | HTTP 播放错误删除当前缓存，累计连续五次错误暂停；预合成另有失败重试 | 真实管线失败后仍有探活请求，随后按字符数估算时长无声推进；系统 TTS 失败则暂停，两条路径行为不一致 |
| 语速跟随 | 由朗读服务消费配置；当前源码的跟随值使用标准速率倍率 | `ttsFollowSys` 的读取和回落 1.0x 在控制条 State 内，挂载／重开控制条会触发 `updateConfig`；需要移入统一播放配置，不能假定现有含义是读取系统设置中的语速滑块 |
| 语速、音调、音量、音色 | 系统服务与音色预设、HTTP／云端合成各有适用范围 | 系统路径实际使用这些参数；HTTP 的 `audioSpeak` 虽接收参数，真实 Rust 合成只使用文本、URL、语速，音调／音量／音色没有接通 |

本项目核对路径：`lib/src/screens/reader_screen.dart`、`lib/src/widgets/reader/reader_selection_actions.dart`、`lib/src/providers/audio/audio_notifier.dart`、`lib/src/services/system_tts_service.dart`、`lib/src/services/rust_api_media_format.part.dart`、`rust/legado-ffi/src/api/tts_speak_api.rs`。

## 3. 面板、设置与后台控制

上游依据：[播放器](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/player/ReadAloudPlayerScreen.kt)、[完整设置内容](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/read/sheet/ReadAloudConfigContent.kt)、[全局胶囊](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/ReadAloudBarCapsule.kt)、[应用外浮层](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/service/readaloud/ReadAloudOverlayWindow.kt)。

| 功能 | MD3 上游 | 本项目与差异 |
|---|---|---|
| 经典／播放器界面 | 可选择默认界面并相互切换 | 已有阅读器多行 `ReadAloudBar` 与独立 `AudioScreen`，但不是上游两种界面的统一入口和会话呈现 |
| 独立播放器正文 | 展示当前与后续正文、定位活动行，支持点击文本及进度定位 | 现有听书页有章节、播放和调节控件，缺少上游这种正文跟随与章内文本定位 |
| 胶囊收起／展开 | 应用内胶囊、播放器展开动画、自动折叠、位置和样式配置 | 阅读器只能隐藏本页控制条，没有全局胶囊；原控制条入场只有淡入 |
| 背景 | 纯色、模糊、流光、透明选择 | 没有相应播放器背景选择；属于独立视觉扩展 |
| 朗读设置分类 | 通用、声音、配音三页；通用包含界面／后台／媒体，声音包含引擎／缓存／划分，配音包含角色和配乐 | “朗读设置”实际跳到引擎管理页，语速跟随在控制条、音调音量在听书页、部分媒体开关在“其他”；应先统一入口与真实功能分类 |
| 目录、转后台 | 保留朗读会话的控制入口 | 已有目录和“转后台”，不应移除 |
| 退出时继续朗读 | 有独立 `keepReadAloudOnExit`，默认 false | 阅读器销毁没有对应停止动作，也没有该策略开关，当前退出策略不能按上游默认直接认定一致 |
| 分钟定时 | 暂停期间不扣时，分钟与章节模式互斥 | Notifier 已实现，阅读器与听书页共享，不需要重建计时器 |
| 按章停止 | 可选章节配额 | 后端支持 1–99 章，听书页有入口；阅读器面板仅提供“读完本章后停止”，属于入口能力差异 |
| 分钟到点读完本章 | 有 `finishCurrentChapterAfterTimer`，到点绑定正在朗读的章节 | 没有该修饰选项；当前分钟到点直接停止 |
| 耳机、通知、锁屏 | 播放命令、媒体元数据及设置控制 | 基本媒体会话和按键已接通；不能把后台能力整体判为缺失 |
| 耳机键切段或切章 | 有 `mediaButtonPerNext` | 当前上一／下一媒体事件固定切章，缺少可选切段语义 |
| 退出后响应、耳机启动、忽略焦点 | 配置参与服务运行 | “其他”页已有三个开关，但本轮全源搜索仅找到键、界面读写，播放及原生桥未消费；应先补真实接线 |
| 来电暂停 | 有独立开关，尤其处理忽略焦点时的来电 | 当前有通用焦点中断处理，没有对应的独立来电配置；Android 与 iOS 接线必须分别评估 |
| 唤醒锁 | 朗读专用设置 | 已有 Android 媒体桥与听书页 `audioPlayWakeLock` 接线；朗读专用键仅见于恢复忽略列表，没有统一朗读设置入口 |
| 应用外悬浮胶囊 | Android overlay 权限、窗口、拖动位置与显隐处理 | 未实现；这是 Android 平台扩展，不能机械搬成 iOS 同能力 |
| Android 媒体兼容、流式朗读 | 有系统控制兼容开关与 HTTP 流式路径 | 未实现对应配置；已有音频书流媒体不等于 HTTP TTS 边合成边播放 |

本项目核对路径：`lib/src/widgets/reader/read_aloud_bar.dart`、`lib/src/screens/audio_screen.dart`、`lib/src/screens/other_settings_screen.dart`、`lib/src/services/audio_service.dart`、Android `MediaSessionBridge.kt` 与 iOS `MediaSessionBridge.swift`。

## 4. 引擎、音色与缓存

上游依据：[引擎与音色管理](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cloudtts/CloudTtsScreen.kt)、[引擎目录模型](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/TtsCatalogModels.kt)、[缓存管理](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cache/TtsCacheViewModel.kt)。

| 功能 | MD3 上游 | 本项目与差异 |
|---|---|---|
| 系统 TTS | 系统引擎、音色以及预设 | 已有 Android 引擎选择、Android／iOS 音色选择和持久化；未形成跨引擎音色预设目录 |
| 书级／全局引擎 | 本书覆盖、全局回退，可选应用范围 | 已实现优先级和两类写入；控制条的点选立即应用全局，与管理页先选再应用的交互不同，应统一明确语义 |
| HTTP 引擎编辑与保存 | 请求头、登录、并发、音色目录等参与完整源配置 | 编辑页有名称、URL、Content-Type、请求头，但 `addHttpTts`／`updateHttpTts` 只传名称和 URL，后两项不能据界面宣称已保存 |
| HTTP 模板执行 | `AnalyzeUrl` 支持请求选项及源上下文 | Rust 当前只有 GET URL 加文本／语速替换，未接 POST、脚本解析、源级 header、login、Cookie 写回开关与并发限制 |
| 兼容既有源 | 完整源配置和目录导入、在线导入、导出 | 当前默认种子已存在，但自动选源刻意排除 POST／脚本等不兼容模板；引擎管理页没有上游完整导入导出流程 |
| 音色试听 | 保存音色、试听、自定义试听文本、批量管理 | 当前系统设置可选音色，没有统一试听与预设管理 |
| HTTP 参数 | 各引擎能力决定参数和音色 | 现有 HTTP 正常合成不使用 `pitch`、`volume`、`voiceName`；这些参数只在失败后的探活 URL 中替换，探活并不产生可播放文件 |
| 合成缓存 | 合成音频复用、缓存目录和日志查看／清理 | Rust 已有按 URL／文本／语速生成摘要的文件缓存；缺少对应 TTS 管理页与可配置过期清理。音频书下载缓存是另一条能力 |
| 预合成 | 预下载章节数、预合成并发上限、失败重试 | 当前上一段停止后才合成下一段；存在段间等待，没有 TTS 预合成队列 |
| 缓存过期 | 有 `audioCacheCleanTime`，用于朗读缓存策略 | 当前未找到该朗读配置消费路径；新增前需明确缓存目录归属和播放中文件保护 |
| 原生云端 TTS | 上游有 OpenAI、Gemini、MiMo、Azure、阿里云、AWS Polly、火山引擎适配 | 未实现独立原生云端配置、音色目录与合成适配；用户自行填写 HTTP 模板并不等于这些适配已存在 |

请求头等缺口需要改 `HttpTts` 数据链及 FFI，必须先更新、冻结 [API 契约](API_CONTRACT.md)，不应靠在 UI 中加一次请求绕过 Rust。

## 5. 多角色、音效与配乐扩展

上游依据：[配音数据模型](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/ReadAloudSpeechModels.kt)、[配音规则](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cast/MultiRoleRuleScreen.kt)、[声音池](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cast/VoicePoolScreen.kt)、[配乐池](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cast/BgmPoolScreen.kt)。

| 上游能力 | 本项目对应情况 | 实施影响 |
|---|---|---|
| 统一声音池、旁白和角色音色绑定 | 未找到对应朗读模型与播放路由 | 新的数据模型、持久化与引擎能力标识 |
| 规则分析、规则结合 AI、AI 理解、推理级别 | 未找到朗读专用实现；既有 AI 页面不是朗读识别链路 | 独立网络能力、解析、失败回退及费用设置 |
| 正则配音规则、未知男女／主配角分类 | 未实现朗读分配规则 | 规则编辑、导入导出及正文范围映射 |
| 本书角色分配、手动对白胶囊、自动分配 | 未实现朗读角色绑定 | 阅读器、章节文本与朗读队列联动；不得污染精准选区原文 |
| 情绪、语音样式、角色表达指令 | 未实现按朗读片段的表达参数 | 各引擎能力不同，不能保证所有引擎都支持 |
| 变声器、音高／语速、混响等音效 | 只有系统语音的基本音调／语速参数 | 音频会话与系统直读路径能力不同，需单独适配 |
| 配乐池、场景表、场景识别与配乐胶囊 | 未实现对应播放层；布局模型有 `bgmScene` 类型也不能算功能接通 | 第二音轨、混音、音量与生命周期协调 |
| 配音胶囊样式、头像与预设导入导出 | 未实现对应管理界面 | 在角色能力稳定后再做视觉定制 |

这些是上游扩展能力，需要单独确认产品范围，不随“优化现有朗读”自动全部加入。尤其不能先放出一组没有播放实现的开关。

## 6. 建议实施顺序与范围选择

### 第一批：基础朗读与统一设置

建议优先处理日常最明显的问题：

1. 普通朗读从可见正文锚点开始；选区朗读保留段内 UTF-16 起点。沿用现有阅读布局和原文坐标，不改分页算法。
2. 保留系统服务已有分片、停止屏障及迟到事件防护，统一系统／HTTP 的失败状态；建议停止无声估时推进、提供明确重试。这与上游 HTTP 五次错误暂停并非完全同一策略，实施前由用户决定“严格复刻”还是“出错即暂停”。
3. 将语速跟随、手动语速及有效引擎归入播放配置，面板只展示和操作；避免打开面板本身重设速度。
4. 设置先分为“播放与控制”“引擎与声音”“缓存与预加载”；复用现有 SettingsGroup、SettingSwitchRow、SettingMenuRow 和调节行。
5. 清楚区分“收起面板”“停止”“退出继续朗读”。暂不改变用户目前退出后可继续朗读的默认行为，待默认值裁决后实施。
6. 让现有耳机与焦点开关真正参与播放，而不是增加更多仅保存偏好的设置。

以上不要求实现角色配音、云端厂商或应用外悬浮窗；是否扩展 FFI 由最终选定项决定。

### 第二批：HTTP 引擎完整性与连续播放

1. 先修好字段的保存、读取、请求消费，再完善请求头、登录、POST 和源模板兼容。
2. 增加有界预合成队列：下一段优先、后台有限并发，切书／切章／切引擎时取消旧任务。
3. 增加 TTS 缓存查看、删除和过期策略，保护正在播放及预合成中的文件。
4. 接入分段方式、段间停顿及“分钟到点读完本章”，所有定时仍使用现有 Notifier 单一计时源。

此批涉及 Rust 数据链和 FFI，需先冻结契约，再修改实现与生成物，最后重编 native。

### 第三批：播放界面与正文跟随

1. 基于统一朗读会话提供紧凑条／胶囊与独立播放器；避免把 AudioScreen 和 ReadAloudBar 各复制一份业务状态。
2. 系统 TTS 接入真实范围回调；HTTP 优先提供可靠单元级范围，不用估时伪造逐字精度。
3. 正文朗读高亮、跟随翻页和进度保存共用原文锚点；用户手动翻页时明确是否临时脱离跟随。
4. Android 应用外胶囊另行选择；iOS 继续评估媒体会话和后台控制，不照搬 Android overlay 窗口。

### 第四批：确认后再做扩展

云端厂商、声音池、多角色识别、角色分配、音效及配乐按独立功能批准和实施，不要求本轮全部完成。

## 7. 实施前需要选择的产品行为

| 选择点 | 推荐 | 另一个可选行为 |
|---|---|---|
| 第一批范围 | 基础播放、真实设置接线与现有控制条整理 | 先只做面板样式 |
| HTTP 错误 | 出错暂停，保留位置并重试 | 严格复刻上游：部分错误跳过、连续五次暂停 |
| 退出阅读器 | 保留当前继续朗读，并提供开关 | 使用上游默认：普通退出停止，显式转后台继续 |
| 暂停时切段／切章 | 移动位置后仍暂停，显式播放才出声 | 保留当前切章后立即播放 |
| 界面范围 | 先重整经典控制条，再加独立播放器／胶囊 | 同批实施完整播放器与应用内胶囊 |
| 新扩展 | 云端与多角色另批授权 | 完整搬入上游扩展体系 |

开发验证先选相关逻辑及现有回归，不新增纯布局测试、不运行全套 CI；仅在用户要求构建或到了需要设备验证的节点，增量编译并安装，设备端点实时探测。iOS 后台、来电与系统 TTS 的验收需要相应设备，不用 Android 模拟器结果代替。

## 8. 独立播放器的 Flutter 基础适配

结构参考固定版本的 [ReadAloudPlayerScreen](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/player/ReadAloudPlayerScreen.kt)：目录／封面／正文三页，默认封面页，前后段与前后章分开控制，语速和定时提供快捷入口。

Flutter 界面只消费 `AudioNotifier`，不复制播放状态或新建音频会话。封面复用 `BookCover`，定时选择抽为共用组件。当前只能取得可靠段落索引，进度显示为段落并接入段落定位，正文高亮当前段；没有接入字级范围或时间估算。暂停中定位保持暂停，切章仍沿用既有开始播放行为。自动正文跟随、应用内胶囊、背景特效与角色配音不属于基础界面范围；执行状态与验证仅记录于 Active 计划。

编写者：Codex｜2026-10-12
