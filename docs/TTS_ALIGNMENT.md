# 朗读引擎上游对齐方法与后续批次

任务状态只维护于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)，本文保存实现边界、上游依据与验收方法。

## 基线与边界

- 工作目录：`reimplement_tts_t2a_task`，沿用同名分支。
- 用户授权 rebase 到主目录 `feature/ui-reader-selection` 的 `45392da979973ed2d1da155ad38d2765fbeaf9e8`；重放三个 T1 提交后的 HEAD 为 `3613d12fb7f5c4c086499c45b799ebfeb5f4a7d1`。
- 上游固定为 `HapeLee/legado-with-MD3` main 的 `070ca1a9b2e491654f70c105bca9939968023940`，不将随时变化的 main 当成验收基线。
- 保留 `HttpTtsRepository → HttpTtsSynthesizer → ReadAloudEngine/ReadAloudSession → AudioNotifier` 边界；Rust 负责源规则、请求、缓存，Flutter 负责播放与正文队列，系统 TTS 仍由平台适配器承担。
- 本轮保留现有 material_ui、系统 TTS、音频书、定时、媒体会话与焦点处理。开发阶段不增加历史迁移、旧配置回填或旧 C ABI。
- 不自动提交、推送、触发 CI；应用版本保持 `2.0.373+374`。Android/iOS 设备验证单独安排。

## 当前实现与剩余差距

| 模块 | 当前实现 | 尚需对齐 |
|---|---|---|
| 配置与选择 | T1 全字段持久化；书级优先、稳定 ID；登录入口与源级高级字段编辑 | 选择流程中的 URL 解析与旧调用形式可后续整理 |
| HTTP 请求 | 按 ID 查库；源变量/登录、动态 Header、GET/POST/JS、响应脚本与重发、限流、取消、连接/超时重试 | 实际第三方源与移动设备验证，尚未支持的 JS 宿主能力按具体用例补齐 |
| 缓存 | 结构化缓存键、同输入去重、原子音频/索引；书章关联、大小、过期清理和活动租约 | 移动设备实际播放与清理联动验收 |
| HTTP 播放 | 本地文件、实时倍速、原位续播、前台优先的有界预合成 | 移动设备后台/中断验证 |
| 系统语音 | 独立平台接口、进度、停止屏障和暂停恢复；统一音色目录与选择界面 | 移动设备后台/中断回归 |
| 云端引擎 | OpenAI/MiMo Provider、独立元数据/设备凭据、配置试听和播放接线 | 其他五家 Provider、云端预合成及真实账号/平台验收 |

T2a 曾缺少完整源上下文；T2b 将其补入独立 `tts_source` 模块，宿主注入数据库源变量/登录存储，`tts_transport` 统一首发与登录刷新请求策略，`tts_response` 处理二进制响应。支持面以 API_CONTRACT §2.42 的方法和 fixture 为准，不宣称覆盖所有第三方 JS 宿主接口。

默认引擎和编辑页已接受 HTTP、POST 选项与 JS 请求入口；它仅判断请求规则形态，不能证明源账号、签名、服务或凭据可用。真实公开源仍需单独验证。

## T2b：源规则与登录请求闭环

实施方法与验收如下；实际执行结果只记录于 Active 计划。

1. 先更新 API_CONTRACT §2.42：冻结可用源字段、JS Source 接口、Header 优先级、登录响应对象与取消语义。配置仍按 ID 从 Rust 数据库读取，不从 UI 复制第二套权威配置。
2. 在 fetcher 组装 `source.getKey() == httpTts:<id>`、`source.getTag()`、变量读写及登录状态上下文。复用已有 JS 宿主与 Cookie/登录存储，避免把 TTS 伪装成书源实体。
3. Header 支持上游源规则及登录 Header 合并，再叠加 URL 选项；不得吞掉解析失败变成空 Header。按启用标记控制 Cookie 读取和响应回写，并验证不同源会话隔离。
4. `loginCheckJs` 对响应对象求值，并接收脚本返回的响应；不能只按 bool 判定成功。HTTP TTS 登录 UI 复用现有登录设施，但以 TTS 来源键区分书源登录。
5. 接入共享 RateLimiterRegistry，按源 `concurrentRate` 限制；取消应覆盖等待、网络和落盘。停止与换引擎不只丢弃结果，还要停止旧请求的资源消耗。
6. 对照上游连接/超时错误重试范围设计有界重试，取消不重试。保持错误可见，不把失败 GET 探活或空音频当成成功合成。取消沿用同一请求句柄；同步 jsLib 下载、java.ajax 等宿主调用尚不能强制中断，退出时再次检查取消。
7. 更新默认引擎规则及完整编辑页，逐项验证 POST、@js、jsLib、登录源。预合成前先实现相同合成输入的请求去重和临时文件原子提交，拒绝空/未完成缓存。

验收：本机 HTTP fixture 覆盖动态 Header、source API、Cookie 隔离、响应脚本转换、限流、取消、重试及重复请求去重；再使用真实 Windows DLL 验证 Dart→FRB→数据库配置→请求→缓存。公开源只作补充验证，不依赖真实凭据建立回归基线。

## T3a：HTTP 原位暂停恢复

上游 [HttpReadAloudService.kt 的 pauseReadAloud/resumeReadAloud](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt#L1717) 保留 ExoPlayer 的已加载音频和位置；阅读位置变更时重新 play，否则从播放器原位恢复。Flutter 保留现有 video_player，并按该行为接线：

1. 已成功加载的段落暂停只调用播放器 pause，不清空本地音频、播放位置或原请求文字长度。等待当前暂停操作完成后才恢复，合成/加载未完成时暂停则取消请求并停止，后续重新起播。
2. 恢复创建新的 ReadAloudSession，通过 `resumeWithTag(previousTag:, tag:)` 核对共享播放器归属并替换监听闭包。旧会话不接受完成/进度，新会话只消费一次完成；音频书继续使用不换绑的 resume。
3. 停止、换段、切章、切引擎同时失效旧播放和暂停屏障。平台控制的迟到失败只归属于发起时的播放 token，不能阻塞或改写新会话。
4. 恢复沿用原请求文本的 UTF-16 起点，不能把暂停时的高亮位置再加一次。HTTP 的全局倍速只修改播放器；引擎、音色或合成参数变化重新装载。
5. 初始化后和设置速度后核对控制器仍为当前装载；停止或替换期间迟到完成不得开播。自然完成依据播放器完成事件/实际到达末尾，不以“离段尾不足 200ms 且不在播放”判定，避免暂停时跳段。

验收：暂停不再次请求或重播段落；控制器与位置保留；恢复新会话能够继续上报进度且完成只消费一次；段内起点映射正确；暂停期间切段、切章、切引擎、停止与过期回调不续播；临时焦点恢复和用户手动暂停区分；音频书、系统 TTS、定时与持久化路径不变。插件平台替身证明 Dart→video_player 协议，不代替 Android/iOS 后台和锁屏实测。

## T3b：有界预合成与缓存管理

上游 `audioPreDownloadNum` 是预下载**章节数**，默认 10；全局 `ttsPreSynthesisConcurrency` 默认 3，实际并发受源 `synthesisThreadCount`（1..8）限制。此前讨论的“默认预合成五段”不是当前上游设置，应避免照此新增另一套配置。

1. `HttpTtsSynthesisQueue` 独立编排当前段与后台请求，共用有限并发槽。当前段优先，必要时取消一个后台请求腾出槽位；同合成输入的排队/在途后台任务可提升为前台，纯播放倍速不改变其身份。请求包含源配置/音色/正文快照；实际规则与音频缓存仍只在 Rust 执行。
2. 起播后窗口覆盖当前章剩余段落及设定数量的后续章节，每次只加载一个后续章，每批最多并发上限个任务。自然换段沿用当前窗口；暂停、手动换段、切章、换书、换源或正文定位取消旧窗口。异步正文返回后再检查窗口，不把旧结果扩展成新请求；章节抓取沿用既有接口，已在途的正文网络抓取尚不能通过本批 TTS 句柄强制取消。
3. 后台失败按上游等待 500ms 重试一次，多数段落失败记作该章失败，连续三章失败停止窗口；日志最多保留 100 条。失败不改变播放器状态，不创建伪音频或无声占位缓存；前台仍保持已有提示/估算推进。
4. 独立 `TtsCacheRepository` 提供书/章/段索引、大小、删除与过期清理。Rust 每音频一份 JSON 索引，保留多个使用位置，以唯一临时文件完整写入后原子发布；损坏索引不能回退成空成功。页面不操作目录，展示缓存、分片正文、文件时间、大小和本会话预合成日志。
5. `TtsRequest` 成功后持有原生音频租约，合成适配器移交给 `HttpTtsAudio`；前台在播放器停止后释放，后台登记索引后释放，取消/失败释放。清理和合成共享同一目录门禁，合成期间保守保护目录内所有音频，播放期间保护被租约持有的音频；临时文件和符号链接不作为可清理音频。租约不是另一份章节或播放状态。
6. `audioCacheCleanTime` 单位分钟，默认 10；保留模式清理其他过期章，保护当前章及活动文件。0 为即听即焚：新朗读会话起手清扫残留，停止/退出取消并等待请求结束、停止播放器并释放租约后清理。不批量回填旧索引，不改变数据库 schema。退出使用已捕获配置，不能读取已销毁 Ref。
7. 原生新增 record/list/clear 三个薄接口，FRB 2.13.0 成对生成，hash 为 `1993971577`。正式和 Mock 窄接口分别返回真实文件和空文件目录，Mock 不伪造本地音频。

验收：当前段不被预取饿死，并发峰值受限，同输入提升不重复合成；窗口只加载约定后续章；停止/换书后旧请求取消、不继续抓后续章；缓存命中不触网，倍速不失效；真实 FRB 下活动音频清理跳过，释放后删除，书章索引可读写；系统 TTS、音频书、原位续播、焦点、定时及持久化回归。代码与本地测试范围以 Active 记录为准，不代替 Android/iOS 锁屏和后台实测。

## T4a：音色目录

1. `legado-core::tts_catalog` 对照 HttpTtsCatalogParser，解析源原始 JSON 的字符串内嵌 speakersJson/emotionsJson；它们不是 HttpTTS 普通列。平铺优先分组、支持上游别名、同 toneID/tag 首项保留，无有效 speaker 不清空目录。
2. 独立 `read_aloud_voices` 表和 Repository 承担持久化；schema v111 只建表，不回填。HTTP 导入、完整 JSON 编辑及默认数据入口在同一事务保存源与目录；删除只清自己的目录。系统目录按单个设备引擎同步，消失只标 unavailable、重现保留用户 flags 和创建时间，元数据变化提升修订号。
3. 稳定身份使用上游 SpeechIdentity 的 `voice:` + SHA256(kind/NUL/engine/NUL/speaker) 前 32 个十六进制字符。HTTP engine 为整数 ID 字符串，speaker 为 toneID；系统 engine 为 system:<当前引擎配置>，speaker 优先 identifier、否则 name。未指定设备引擎使用空后缀，表示系统默认，不伪造云端身份。
4. Dart 窄接口提供查询、系统同步和用户标记；目录 Provider 不拥有播放器。系统插件只发现设备音色，Rust 不调用平台插件。发现与起播校验分离；已失效选择不能阻止重新打开目录，新装语音重新读取。显式失效/排除的系统选择起播报错，自动选择避开不可选音色。
5. HTTP 发音人/情感选择以 ttsVoice:<id> 落既有设置，独立于书级/全局引擎选择；不存在的音色或情感不作为合法选择保存。当前段和预合成都消费同一解析结果；toneId/speakerName/emotionTag 进入既有合成上下文及缓存，不改原文坐标。已选 HTTP 音色消失/禁用时提示并采用源默认参数，不改选另一目录音色。
6. 目录 UI 支持发音人、情感、引擎默认、禁用、排除/恢复及选中显示；正反选择用控件回归验证。系统设置沿用原插件，暂不新增文件合成、原生桥或云端 Provider。crypto/sha2 直接依赖用于同一稳定 ID，版本沿用已有 lockfile。

验收：重复导入不复制目录、不改变 flags；空目录不清空，删源不误删别的源；无回填建表不改变已有 HTTP 配置；失效系统选择仍可发现目录，但不能偷偷换声；当前段与预合成同音色/情感；真实 FRB 验证目录同步、标记及缓存身份。测试数量、运行日志和未测边界只在 Active 记录。

## T4b：云端引擎

通过 CloudTtsRepository 和 CloudReadAloudEngine 接入相同会话和缓存播放协议。按上游 OpenAI、阿里云百炼、Azure、AWS Polly、火山豆包、Gemini、小米 MiMo 逐个实现并验收，不在一批同时引入七套认证与音频格式处理。

每个 Provider 验收独立覆盖认证/签名、SSML 或 JSON 请求、错误响应、取消、PCM/WAV 等格式与缓存；凭据不得作为普通导出配置或日志暴露。多角色分析、BGM、音效不混入上述基础引擎批次。

### T4b-1：OpenAI Speech 原生 Provider

- `legado-core/cloud_tts` 保存纯模型、Provider 窄接口和 PCM→WAV；`cloud_tts_openai` 负责请求准备、参数校验、内置音色及格式适配，不访问数据库、Flutter 或网络。
- 对照固定上游 OpenAiCloudTtsProvider：默认模型 gpt-4o-mini-tts、默认地址 https://api.openai.com/v1；基址自动补 /audio/speech，完整端点不重复补。13 个内置音色及 voice_ 自定义对象，speed 0.25..4.0，六种格式；style/instructions 用空格组合，tts-1 系列不发送 instructions。locale/role/pitch/volume/sampleRate 沿用通用请求字段，但 OpenAI 不将它们加入 API 请求，也不将未使用字段加入音频缓存身份。
- `legado-fetcher/cloud_tts` 承担异步编排和可替换 CloudTtsTransport。默认独立网络客户端、120 秒超时，不共享书源登录/Cookie；正常校验证书，不自动跟随携带凭据的请求重定向。来源 key、实际地址/正文/模型/音色/合成速度及凭据参与 SHA-256 缓存身份，API Key 不进入调试或配置导出 JSON。
- 使用现有 TtsCancellation/synthesis_lock/SpeakCache/TtsCache。相同输入同时请求只发一次，等待锁与网络均可取消；开始前已取消不创建目录，不发请求。完整音频原子发布，结果携带原生租约，清理跳过活动音频，释放后可删。缓存命中前也验证启用态和凭据，不让禁用引擎或缺凭据请求续用旧音频。
- 缓存适配为现有播放器可接受的格式：Opus 使用 Ogg 文件，OpenAI PCM 按官方 24kHz/16-bit/单声道/小端规范补 WAV 头，不重采样。原始样本保留；空/奇数样本拒绝。错误状态、JSON/text 响应及明显误标音频的 JSON/HTML 不落盘；错误消息不回显响应体中的凭据。
- 与上游不同的内部适配：增加本地 4096 Unicode 字符前置失败，避免无效远程请求；PCM 落盘为 WAV，Opus 采用现有缓存接受的 Ogg 后缀；无效 Provider 类型明确拒绝，不默认转成尚未实现的 MiMo。更严格的错误响应/TLS/重定向行为不改旧书源或 HTTP TTS 客户端。

T4b-1 只交付 Rust 可测试基础；数据库、FRB、设备安全存储及产品接线的职责在下节 T4b-2 单独说明。API Key 不得作为普通 config/httpTTS 列或 JSON 导出内容保存；不以当前模型的内存字段替代设备密钥库。不调用真实账号，不将 fixture 成功解释为云账号、播放器解码或设备后台验收。任务状态和命令结果只在 Active 维护。

### T4b-2：元数据、设备凭据与产品接线

对应上游独立 CloudTtsEngineEntity/CloudTtsEngineRepository 和 CloudTtsCredentialCipher 的职责：

1. Rust DB/FFI 管理云端元数据，设备凭据引用单独存为 credentialKey，明文凭据只在合成调用中临时传入。optionsJson 严格限制为音色、风格、指令、源级速度与格式；不允许借选项夹带 apiKey/secretKey。FRB 原生调用重新读当前配置并核对凭据引用，拒绝读取过程中已替换的密钥。
2. Flutter 平台适配使用 [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)；Android 使用独立 legado_cloud_tts 命名空间，关闭失败后自动重置与算法迁移，备份规则只排除该命名空间的加密数据/密钥偏好。iOS Keychain 为 first_unlock_this_device，三个 Runner 构建配置引用同一 entitlement；macOS 沿用系统 Keychain，不强制新增应用分组。真实插件/设备验收另做，不把测试替身称为平台密钥库证明。
3. CloudTtsSettings 串行协调写入，凭据每次变更使用新引用。安全存储成功后更新 DB，DB 失败清理新引用；DB 成功后清理旧引用。删除先删 DB、再删安全存储，后者失败明确提示。跨存储不是原子事务，进程崩溃或清理失败可能遗留孤立引用；不伪造回滚，不新增历史读取/修复或明文回退。
4. 元数据通过 CloudTtsRepository，合成通过 CloudTtsSynthesizer；UI 只展示/编辑与委托窄接口。CloudReadAloudEngine 使用 cloud://<ID> 接入原有选择、书级/全局持久化和正文协调，不把云端保存为 HTTP 源。为复用现有文件租约，返回 DTO 与取消类型暂沿用 HttpTtsSynthesisResult/HttpTtsCancellation；复用的是协议类型，不是 HTTP 源表、登录或网络客户端。
5. FileReadAloudEngine 统一本地文件装载、暂停屏障、恢复换绑和释放租约。HTTP/云端共用正文播放器，协调层提供同一个停止 Future，两个引擎都等待停止后释放自己的租约。CloudReadAloudEngine 按不超过 4000 UTF-16 的字形簇边界分片，不拆代理对/组合字符；进度累加已完成分片偏移，只有整段全部完成才切段。全局倍速留给播放器，源级合成速度来自 DB 选项。HTTP 现有预合成窗口保留，云端窗口后续接入，不假称已与上游全部对齐。
6. 试听独立播放器与会话，先暂停正文，不占用正文的完成标签。页面退出、停止、失败或新试听取消旧合成，晚到音频不启动；编辑凭据不把密钥回显到输入框。云端选择器失败隔离于 HTTP/系统列表。缓存仍使用原有索引、活动租约与清理入口。

验收方法：内存/插件替身验证凭据操作与 UI，真实 Windows DLL + 本机 HTTP fixture 验证新表、配对 FRB、参数/缓存/租约、过期引用拒绝和禁用；再用原 HTTP fixture 与播放回归防止替换共用文件状态机导致退化。不调用真实云账号，不用 fixture WAV 代替平台解码器或后台连续播放测试。命令结果与状态仅记 Active。

### T4b-3：MiMo（用户调整优先顺序）

- 纯计算 `cloud_tts_mimo` 对照固定上游 [MimoCloudTtsProvider](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/playback/MimoCloudTtsProvider.kt)：默认模型 mimo-v2.5-tts，api.xiaomimimo.com/v1/chat/completions，api-key 鉴权。instructions 为可选 user 消息，风格以 `(style)` 前缀写入 assistant 正文；audio 指定 pcm16/voice，stream=true。支持完整端点，避免重复追加路径。
- 内置九项音色与八种风格按上游目录，输出为 24kHz/16-bit/单声道/小端 WAV。SSE 拼接 choices[0].delta.audio.data，分片 Base64 解码后组合 PCM。官方 [MiMo 语音合成说明](https://mimo.mi.com/docs/en-US/quick-start/usage-guide/audio/speech-synthesis-v2.5) 同样要求正文放 assistant，流格式 pcm16，并说明 24kHz PCM16LE；本任务不增加声音克隆、Voice Design 或唱歌模式。
- 上游对流中无效 JSON 会忽略，本实现采用严格失败；错误事件、无效 JSON/Base64、空数据、奇数 PCM、异常结束不缓存。完成需 [DONE] 或 finish_reason=stop，length 等截断拒绝。网络层仅在 Provider 声明 EventStream 时接受 text/event-stream，OpenAI 的直接音频路径继续拒绝 JSON/text，不放宽为所有文本响应。
- 使用同一个 Provider 分派函数覆盖元数据校验、静态音色发现与合成执行，未知类型不回退。保持 schema v112 与五个 FRB 签名，没有新 API 或配对生成要求；音色 JSON 新增 styles 和可选 sampleRate，旧 id/displayName 消费不变。新建时服务商切换重新加载目录并重置默认模型/音色/格式，清空旧服务地址和密钥；保存后 Provider 在 UI/DB 固定，换服务请新建。
- MiMo 不消费数值源 speed/pitch/volume，按照上游请求不发送，配置页隐藏无效的源速度，播放倍速仍走现有文件播放器。风格、指令、模型、音色与凭据参与实际请求缓存；改变播放倍速不导致重新合成。SSE 仍完整收齐后落盘再播放，不将 HTTP 流式传输称为边合成边播放。云端后台预合成后置。
- 协议/缓存/取消、元数据默认值和服务商身份、配置交互分别测试；真实 Windows DLL + 本机 SSE 复核 api-key（无 Bearer/Cookie）、消息 JSON、顺序 PCM/WAV、缓存命中和坏流不落盘。凭据仅为测试替身，不调用真实 MiMo 账号，不证明设备解码、音色效果或后台生命周期。

## 移动端验收与后续限制

Windows DLL、Rust 本机 HTTP fixture 和控件测试只证明本地链路；Android/iOS 的 WebView 登录、公开云账号、锁屏/后台与音频中断必须另行验收，不用 Windows 结果代替。

HTTP 失败时原有提示与估算推进保留，不自动切换系统引擎。已装载的 HTTP 音频暂停后原位续播；加载前暂停取消请求，恢复重新起播。源级语速与全局播放器倍速独立，暂停续播不使缓存失效。

## 上游依据

- [BaseSource 登录及 Header 语义](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/data/entities/BaseSource.kt)：来源键、动态 Header、登录信息与源变量。
- [HttpTTS 实体与来源键](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/data/entities/HttpTTS.kt)：getKey、源级语速与并发限制。
- [HttpReadAloudService](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt)：请求、登录响应处理、MIME 完整匹配、预合成与播放行为。
- [ReadAloudSettings](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/settings/ReadAloudSettings.kt)：预下载章节数与全局并发默认值。
- [HttpTtsCatalogParser](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/speech/HttpTtsCatalogParser.kt)：外部源的发音人与情感目录。
- [SyncHttpTtsCatalogUseCase](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/usecase/SyncHttpTtsCatalogUseCase.kt)：源级目录同步，不以空草稿清空已有目录。
- [SyncReadAloudVoicesUseCase](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/usecase/SyncReadAloudVoicesUseCase.kt)：系统音色不可用标记、重现和用户状态保留。
- [SpeechIdentity](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/SpeechIdentity.kt)：稳定目录身份。
- [OpenAiCloudTtsProvider](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/playback/OpenAiCloudTtsProvider.kt)：OpenAI 请求准备、音色和格式规则。
- [CloudTtsProvider](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/playback/CloudTtsProvider.kt)：Provider 边界、120 秒读取超时和 PCM/WAV 头。
- [CloudTtsCredentialCipher](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/data/security/CloudTtsCredentialCipher.kt)：后续凭据存储的设备密钥库语义。
- [OpenAI 官方 Speech API](https://developers.openai.com/api/reference/resources/audio/subresources/speech/methods/create)：实际请求参数、自定义音色、instructions、速度和文本上限。
- [OpenAI 官方 TTS 格式说明](https://developers.openai.com/api/docs/guides/text-to-speech)：PCM 采样及输出格式。
- [CloudTtsModels](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/CloudTtsModels.kt)：云端 Provider 与配置模型。

编写者：Codex｜2026-10-14
