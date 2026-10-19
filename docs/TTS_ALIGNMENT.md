# 朗读引擎上游对齐方法与后续批次

任务状态只维护于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)，本文保存实现边界、上游依据与验收方法。

## HTTP 引擎导入导出（2026-10-19）

本批固定参考上游 [`c4182eb9`](https://github.com/HapeLee/legado-with-MD3/tree/c4182eb9bcdd2e52eb6bb44d14c37856e592a99a)：
`CloudTtsViewModel.importHttpTtsSource/parseHttpTtsSource/saveImportedHttpTts` 与
`CloudTtsScreen`。按 ID 与 lastUpdateTime 比较新增、更新、已有，已有默认不勾选；
保持用户已确认的编辑 Sheet，不恢复已放弃的全屏编辑器。

- 引擎页更多菜单进入导入或勾选导出；单引擎行更多菜单预选当前引擎导出。
- 剪贴板、UTF-8 文件、HTTP(S)、data URI、legado/yuedu 的 `/httpTTS?src=`
  汇合至数据服务预览。`#requestWithoutUA` 沿用上游发送 `User-Agent: null` 的规则。
  递归链接限制八层并拒绝循环；取消后的迟到预览不能保存或跳转。
- HttpTtsTransferService 负责解析/比较/编排，平台适配器负责文件，Sheet 负责勾选和反馈。
  确认仅调用一次既有文档导入，Rust 在同一 SQLite 事务内写全部配置与目录，提交后刷新限流。
  非零 ID 覆盖、零 ID 新建；同批先保留显式 ID，避免自动编号覆盖。预览拒绝重复非零 ID。
- 完整导出从配置与当前可用 HTTP 目录重建 speakersJson/emotionsJson；保留排除音色的
  目录定义，不将设备排除标记作为分享配置。云端凭据、系统目录和登录会话不导出。
  目录归一化为当前持久化内容，不保证原始 JSON 分组/缩进；未曾入库的未知字段不保留。
- 上游上传为分享 URL 的操作不在此批；本批提供本地文件与剪贴板 JSON，未接入上传服务。
  无 schema、FRB 签名、代码生成或播放队列改动。

验证以真实服务调用、Widget 勾选/取消/重试以及 SQLite 触发器注入失败为依据；
固定第三方账号、平台文件选择器与真实设备交互另行验收，不用 Mock 结果宣称真机可用。

编写者：Codex + UI/Bridge｜2026-10-19。

## 系统媒体时间轴与控制（2026-10-15）

本批对照[上游BaseReadAloudService](https://github.com/HapeLee/legado-with-MD3/blob/4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5/app/src/main/java/io/legado/app/service/BaseReadAloudService.kt)及同版本AudioPlayService：
正文每秒4个UTF-16字符乘语速估算章节时长，单调时钟补齐稀疏进度，暂停冻结；音频书使用真实音轨时长与播放倍率。
正文估算不等于云端实际音频时长；显示和定位均按同一原文坐标换算，最终用现有字形簇安全定位修正。
主动定位、切段、换章和变速重置时间轴，旧书/旧章/旧会话事件不定位当前播放器。
系统拖动串行提交，连续拖动保留最新位置；暂停中定位保持暂停。未知音轨时长时不开放拖动。

前后按钮共用持久化mediaButtonPerNext：正文可以选择切章或切当前朗读划分单元，音频书始终切章。
Android原生会话公开实际已接通的操作，系统从会话时长、进度和能力生成媒体面板；不增加旧系统专用兼容布局。
通知PendingIntent使用当前启用的桌面入口，Dart导航等待欢迎页退出并复用已有播放页，不重新创建音频会话。
停止会话后的通知不得恢复旧播放。iOS接通NowPlaying时长及changePlaybackPositionCommand；
iOS系统媒体卡片的应用入口由系统处理，本批不把任意回前台事件冒充通知点击，不承诺强制跳转指定页面。

本地规则与路由由单元/Widget测试保护；integration_test/media_controls_test.dart仅供隔离Android设备，
宿主实际拖动系统进度条、点击前后按钮和两次通知卡片，核对原生dumpsys及导航去重。
运行前备份并显式--no-uninstall，测试期间需要按pump推进Flutter帧。真实iOS锁屏/中断仍需Apple平台验收。

编写者：Codex UI / Bridge｜2026-10-15

## 媒体通知封面与标题（2026-10-15）

本批依据用户明确授权调整通知和锁屏展示：书名为主标题、章节为次标题，去掉播放/朗读前缀，
定时通过独立辅助字段传输。沿用现有媒体会话，不新增播放器或后台服务。
封面由MediaArtworkLoader复用已有网络图片缓存及CoverDecodeLoader的解密/复合请求头路径，
兼容本地和自定义封面，生成最长边384px、最大1MiB的PNG，失败使用默认封面。
文字先发布，图片异步补入；书籍、封面或隐私遮蔽改变更新身份，切章与倒计时不重复加载图片。
停止与释放清空身份，Flutter与原生双方拒绝过期图片；隐私锁定时不向系统暴露真实标题或封面。
协议见API_CONTRACT.md的媒体通知本地通道。Android使用媒体ART/ALBUM_ART与通知largeIcon，
iOS使用MPMediaItemArtwork；Android定时放subText，iOS写独立comment，实际是否展示由系统决定。
隔离设备验证使用integration_test/media_notification_test.dart，显式--no-uninstall，事前备份，
阶段标记用于宿主核对dumpsys和截图；不能仅凭通道调用成功宣称原生展示通过。
iOS编译和实际锁屏需要macOS/Apple设备，Windows及Android结果不能代替。

编写者：Codex UI｜2026-10-15

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
| HTTP 播放 | 本地原生队列、实时倍速、原位续播、前台优先的有界预合成 | 移动设备后台/中断验证 |
| 系统语音 | 独立平台接口、进度、停止屏障和暂停恢复；统一音色目录与选择界面 | 移动设备后台/中断回归 |
| 云端引擎 | OpenAI/MiMo/百炼 Provider、独立元数据/设备凭据、配置试听和播放接线 | 其他四家 Provider、云端预合成及真实账号/平台验收 |

T2a 曾缺少完整源上下文；T2b 将其补入独立 `tts_source` 模块，宿主注入数据库源变量/登录存储，`tts_transport` 统一首发与登录刷新请求策略，`tts_response` 处理二进制响应。支持面以 API_CONTRACT §2.42 的方法和 fixture 为准，不宣称覆盖所有第三方 JS 宿主接口。

默认引擎和编辑页已接受 HTTP、POST 选项与 JS 请求入口；它仅判断请求规则形态，不能证明源账号、签名、服务或凭据可用。真实公开源仍需单独验证。

## 统一音色与引擎管理界面

参考固定上游 [CloudTtsScreen](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/readaloud/cloudtts/CloudTtsScreen.kt) 的双 Tab、EngineSectionTitle、类型选择 Sheet 和默认引擎范围选择：

- 既有 readAloudConfig 路由共用音色/引擎两页；引擎按云 TTS、HTTP 协议 TTS、系统 TTS 排列，分类标题使用12dp水平/垂直内边距。用户要求保留各引擎独立卡片；空分类保留标题，系统能力不可用时不生成可选择卡片。
- 引擎页 FAB 打开云/HTTP 类型 Sheet，编辑器通过AppBottomSheet入口、AppSettingsSheet外壳及AppSettingsForm表单共用安全区域、键盘避让、可滚动正文和固定保存栏。云端与音色旧页面逻辑提取为面板及页内动作，不再拥有独立入口。
- 点击引擎选择书/全局，沿用当前持久化；取消不更改设置。手动刷新按钮与朗读设置的重复系统语音入口已按用户要求删除，系统设置保留于系统 TTS 卡片；进入及增删改后的自动重读保留。
- 音色页返回时重读 HTTP/系统目录和当前云端元数据，源已删除或停用时拒绝对旧音色行保存；音色变更保留源指令和凭据引用。
- Widget 测试使用实际 AppTheme，覆盖窄屏/键盘、Tab 点击/滑动、卡片分类、缺少系统能力、范围持久化、凭据不回显和退出试听取消；真实账号与移动后台另行验收。

### 引擎与音色职责（2026-10-14 追加）

按照同一固定上游的 buildEngine/buildVoice 和 VoiceEnginePicker/VoicePresetEditor：
引擎只定义服务连接、凭据与模型；音色使用 engineType/engineId/speakerId 稳定身份，
同一引擎的多个原生音色分别保存，名称与合成参数属于音色记录。复用当前音色表和
Repository，不新建独立云端音色配置仓库，不修改引擎凭据来切换音色。

音色页 FAB 先选择引擎，再打开音色 Sheet；云端可从 Provider 目录选择或输入原生 ID，
HTTP 有目录时选择，也支持手动音色 ID；系统使用当前设备引擎的已安装音色作为候选，主列表仅显示用户手动保存的系统音色；切换显示排除项仍不显示未添加候选。
源级目录和系统发现继续可用，但再次发现不会覆盖 user 音色的自定义名称/参数。
普通源目录排除保留行，用户音色可以编辑、删除。音色页承担试听，引擎页不提供试听。
系统设置入口只选择设备引擎，不再重复选择语音。三个朗读编辑器通过公共AppSettingsSheet和AppSettingsForm组合标准Material输入框与控件；控件间距12dp、音色芯片换行间距8dp，保存/校验/试听仍由具体页面负责。

已保存云端音色试听与正文都传音色记录 ID，由 Rust 核对引擎归属及可选状态；
编辑中的草稿只传受限 voiceOptions，不写音色表或默认选择。实际请求参数进入已有
缓存身份，不同音色不串用缓存。系统临时 voiceKey 不改变持久化选择，下一次正文
起播重新使用用户保存的语音。试听有独立播放器/会话，先暂停正文，停止或离开后
取消在途请求并释放租约，迟到结果不能起播或推进正文。

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

1. `ReadAloudSynthesisQueue` 独立编排当前段与后台请求，共用有限并发槽。当前段优先，必要时取消一个后台请求腾出槽位；同合成输入的排队/在途后台任务可提升为前台，纯播放倍速不改变其身份。请求包含源配置/音色/正文快照；实际规则与音频缓存仍只在 Rust 执行。
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
5. FileReadAloudEngine 统一本地文件装载、暂停屏障、恢复换绑和释放租约。HTTP/云端共用正文播放器，协调层提供同一个停止 Future，两个引擎都等待停止后释放自己的租约。CloudReadAloudEngine 按不超过 4000 UTF-16 的字形簇边界分片，不拆代理对/组合字符；进度累加已完成分片偏移，只有整段全部完成才切段。全局倍速留给播放器，源级合成速度来自 DB 选项。HTTP/云端均接入共用预合成窗口；保持现有文件播放器，不宣称与ExoPlayer播放列表的无缝衔接等价。
6. 试听独立播放器与会话，先暂停正文，不占用正文的完成标签。页面退出、停止、失败或新试听取消旧合成，晚到音频不启动；编辑凭据不把密钥回显到输入框。云端选择器失败隔离于 HTTP/系统列表。缓存仍使用原有索引、活动租约与清理入口。

验收方法：内存/插件替身验证凭据操作与 UI，真实 Windows DLL + 本机 HTTP fixture 验证新表、配对 FRB、参数/缓存/租约、过期引用拒绝和禁用；再用原 HTTP fixture 与播放回归防止替换共用文件状态机导致退化。不调用真实云账号，不用 fixture WAV 代替平台解码器或后台连续播放测试。命令结果与状态仅记 Active。

### T4b-3：MiMo（用户调整优先顺序）

- 纯计算 `cloud_tts_mimo` 对照固定上游 [MimoCloudTtsProvider](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/playback/MimoCloudTtsProvider.kt)：默认模型 mimo-v2.5-tts，api.xiaomimimo.com/v1/chat/completions，api-key 鉴权。instructions 为可选 user 消息，风格以 `(style)` 前缀写入 assistant 正文；audio 指定 pcm16/voice，stream=true。支持完整端点，避免重复追加路径。
- 内置九项音色与八种风格按上游目录，输出为 24kHz/16-bit/单声道/小端 WAV。SSE 拼接 choices[0].delta.audio.data，分片 Base64 解码后组合 PCM。官方 [MiMo 语音合成说明](https://mimo.mi.com/docs/en-US/quick-start/usage-guide/audio/speech-synthesis-v2.5) 同样要求正文放 assistant，流格式 pcm16，并说明 24kHz PCM16LE；本任务不增加声音克隆、Voice Design 或唱歌模式。
- 上游对流中无效 JSON 会忽略，本实现采用严格失败；错误事件、无效 JSON/Base64、空数据、奇数 PCM、异常结束不缓存。完成需 [DONE] 或 finish_reason=stop，length 等截断拒绝。网络层仅在 Provider 声明 EventStream 时接受 text/event-stream，OpenAI 的直接音频路径继续拒绝 JSON/text，不放宽为所有文本响应。
- 使用同一个 Provider 分派函数覆盖元数据校验、静态音色发现与合成执行，未知类型不回退。保持 schema v112 与五个 FRB 签名，没有新 API 或配对生成要求；音色 JSON 新增 styles 和可选 sampleRate，旧 id/displayName 消费不变。新建时服务商切换重新加载目录并重置默认模型/音色/格式，清空旧服务地址和密钥；保存后 Provider 在 UI/DB 固定，换服务请新建。
- MiMo 不消费数值源 speed/pitch/volume，按照上游请求不发送，配置页隐藏无效的源速度，播放倍速仍走现有文件播放器。风格、指令、模型、音色与凭据参与实际请求缓存；改变播放倍速不导致重新合成。SSE 仍完整收齐后落盘再播放，不将 HTTP 流式传输称为边合成边播放。云端后台预合成后置。
- 协议/缓存/取消、元数据默认值和服务商身份、配置交互分别测试；真实 Windows DLL + 本机 SSE 复核 api-key（无 Bearer/Cookie）、消息 JSON、顺序 PCM/WAV、缓存命中和坏流不落盘。凭据仅为测试替身，不调用真实 MiMo 账号，不证明设备解码、音色效果或后台生命周期。

### T4b-4：阿里云百炼

- 对照固定上游 AlibabaCloudTtsProvider：`alibaba_cloud`、qwen3-tts-flash、Cherry、四音色、WAV；Bearer 与 X-DashScope-SSE，multimodal-generation/generation 端点，input 为 text/voice/language_type。style 与 instructions 以中文分号连接，只有 instruct 模型发送。数值源速度不发送，配置页依据 Provider 能力隐藏该控件，播放倍速保持独立。
- Provider 只准备请求并解析 SSE，fetcher 消费普通音频或后续下载动作。PCM 优先按到达顺序拼接，24kHz 单声道 WAV；仅有 URL 时下载完整 WAV，允许 OSS 签名查询，下载不携带 API Key/Cookie/SSE 请求头、不跟随重定向。取消与 120 秒超时覆盖下载，错误文本、截断 WAV 与不完整 SSE 不落盘。缓存身份来自实际合成请求；命中不重复 POST 或 GET。
- 官方接口输入上限为 600 字符。百炼正文和试听按 Provider 能力使用 600 UTF-16 字形簇安全分片，保守满足上限，不拆 emoji/组合音标；其他两家保留 4000。分片进度仍累计章内原文偏移，整段全部结束才触发切段。元数据查询完成后检查会话，停止期间的迟到配置不启动合成。
- 与上游更严格的内部判定：JSON/Base64 错误直接失败，要求 finish_reason=stop 或 [DONE]，异常结束不复用部分 PCM；下载 WAV 检查 RIFF 声明长度。不升级 schema/FRB 签名、不回填配置、不改变既有服务商的凭据归属。真实账号/移动音频解码及后台行为另行验收。

## 内容划分与共用云端预合成（2026-10-15）

参考上游固定dd97afe4f1184ac6b9840dc8faf821b40e162583的
[内容划分策略](https://github.com/HapeLee/legado-with-MD3/blob/dd97afe4f1184ac6b9840dc8faf821b40e162583/app/src/main/java/io/legado/app/domain/model/readaloud/ReadAloudContentSplit.kt)与
[合成播放流程](https://github.com/HapeLee/legado-with-MD3/blob/dd97afe4f1184ac6b9840dc8faf821b40e162583/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt)。

- 默认整段，用户可选符号/整页，设置归统一ReadAloudSettingsRepository；符号连续出现时保留在同一单元末尾。现有显示空白归一化保留，所有起点从原文取值。
- 页面范围来自ReaderPageView完整真实排版，跨页重排以当前原文锚点重建朗读单元；缺少或陈旧/不完整范围明确拒绝。页面模式预合成仅当前已有排版章节，未排版的后续章不凭字数猜页。
- 长度保护独立于用户单元：百炼600、其他已实现Provider4000 UTF-16；先句末及结束引号，再词边界，最后字形簇；不丢弃分片间空白，索引记录实际音频分片文本。
- 共用ReadAloudSynthesisQueue注入合成操作，read_aloud_synthesis_adapter负责HTTP/云参数映射；有界并发、前台优先、在途背景提升、后台500ms单次重试与取消/租约复用。云端窗口覆盖当前段剩余片、剩余单元及配置数量的后续章；关闭预下载停止后台请求。身份包含引擎和音色版本，纯播放器倍速不作废合成缓存。
- 云端首次/片间失败暂停并提示，失败起点保留，恢复重试不重播已完成片；HTTP既有失败处理未改。系统继续speak直接朗读。
- 播放继续由FileReadAloudEngine按顺序装载完整文件；没有增加native播放列表、下一文件控制器预初始化或实时PCM播放，不宣称零停顿。真实账号延迟、后台与两端解码仍需设备验收。

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
- [AlibabaCloudTtsProvider](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/help/readaloud/playback/AlibabaCloudTtsProvider.kt)：百炼请求、音色、PCM 与 URL 两条响应路径。
- [百炼官方 Qwen-TTS API](https://www.alibabacloud.com/help/en/model-studio/qwen-tts-api)：600 字符上限、SSE 头、语言与 output.audio/finish_reason。
- [CloudTtsModels](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/domain/model/readaloud/CloudTtsModels.kt)：云端 Provider 与配置模型。

编写者：Codex｜2026-10-14

## 播放器倍速和定时面板（2026-10-15）

参照固定上游dd97afe4的ReadAloudPlayerScreen与ReadAloudTimerSheet，保留Flutter平台实现，
使用AppBottomSheet统一外壳，界面直接操作已有共享设置和播放会话，不复制第二套计时器。

- 倍速滑块范围0.5–3.0，0.1一档；拖动只预览，松手或点预设才保存。手动选择使用
  setReadAloudSpeed(activateManual: true)，通过ReadAloudPreferences更新倍率和跟随开关；
  写入先倍率后开关，失败保留有效播放状态，重试继续完成剩余保存。
- 定时保持时间/章节两类，0为关闭，沿用当前项目180分钟/99章的范围。切换类别清空
  对方计时，打开面板不启动计时。共享入口同时供经典条、独立播放器和音频书使用。
- startSleepTimer(finishCurrentChapter: true)到点后进入等待自然章末状态，模式仍为duration；
  只有自然章末完成路径消费等待状态，普通段落、云端内部长度分片不会提前停止。
  setFinishCurrentChapterAfterTimer修改当前策略不重置剩余秒数；等待中关闭立即停止。
  取消定时继续播放，停止/重设/换模式清除等待状态，暂停时倒计时仍冻结。
- 定时配置不加入数据库或普通偏好，生命周期沿用当前播放会话。iOS后台长期计时和真实音频
  续播依赖实际运行能力，不能由Widget测试证明；本轮按用户要求跳过设备验收。

参考：[上游定时面板](https://github.com/HapeLee/legado-with-MD3/blob/dd97afe4f1184ac6b9840dc8faf821b40e162583/app/src/main/java/io/legado/app/ui/book/readaloud/ReadAloudTimerSheet.kt)。

编写者：Codex｜2026-10-15


## 段落与分片播放衔接（2026-10-15）

本批重新固定上游 main 为 `4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5`，
只对照 [HttpReadAloudService 的播放器队列](https://github.com/HapeLee/legado-with-MD3/blob/4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt)：
零段间隔时复用 ExoPlayer，首项 setMediaItem/prepare，后续 addMediaItem；原生换项驱动正文归属。
有段间隔时独立调度。此前各节固定的请求、缓存和管理界面基线不因此替换。

- Flutter 使用 [just_audio 0.10.6](https://pub.dev/packages/just_audio/versions/0.10.6) 的原生播放列表，
  Windows 配套 [just_audio_windows 0.2.3](https://pub.dev/packages/just_audio_windows/versions/0.2.3)。
  `ReadAloudAudioPlayer` 最初只接管正文 TTS 本地队列；后续按2026-10-15纯音频统一批次
  接管音频书URL与独立试听，视频仍保留原实现。
  关闭插件自行管理焦点、中断和音频会话，由既有 MediaSessionBridge 处理；不新增第二个后台服务。
- `AudioNotifier` 生成当前章的 cue：逻辑段落、UTF-16 原文起点和不可变合成请求。
  零停顿排当前章剩余正文，有停顿只排同段长度分片；不提前排下一章，章末定时和循环仍归协调层。
- `FileReadAloudPlaylist` 只管理本地文件入队与租约，最多当前项加两个后续项。
  合成仍走既有前台优先队列和 Rust 缓存；文件退出原生列表之后才释放租约。
  追加失败可能已有原生引用，文件保护持续到停止；取消后的迟到合成只释放，不加入新会话。
- 原生追加/裁去旧项期间，来源列表先更新、原生索引稍后更新，属于插件中间态；
  不将其当作真实换项。MuMu 初次对照曾出现 0/1/2/1/2 的重复段落通知，屏蔽编辑中间态后
  按 0..7 顺序通过，单元用例保留此时序，防止 Fake 的原子更新掩盖问题。
- Windows 的 WinRT 删除前项后不回传校正索引，适配层保留当前文件位置并显式同步；
  逐项 completed 不能当成队列结束，须检查末项、有效时长和实际片尾。
  验收还要求总耗时覆盖媒体时长，防止只有顺序回调正确却提前结束。
  Windows 插件单独使用 C++20 标准协程、UTF-8 编码及旧成员限定名兼容模式；
  不修改 Pub 缓存或其他插件编译设置。
- 暂停保留位置和已排文件，续播替换段落会话；暂停确认前已发生的换项在续播时补齐原文归属。
  修改段间停顿从当前原文锚点重新准备，不让已排下一段绕过新设置。
  队尾等待未完成音频不当作章末；后续合成失败到可播放文件结束后暂停并定位未读项，不自动跳过。
  首项 HTTP 合成失败仍保留既有可见提示及估算推进规则，未在本批扩大改动该策略。
- MuMu Debug 对照使用无网络 WAV 夹具（24kHz/16bit/mono，8×400ms，总媒体时长3200ms）：
  逐文件装载总耗时4052ms、创建8个播放器；原生队列3429ms、创建1个播放器。
  新方案开始回调时间为173/643/1040/1441/1837/2237/2640/3040ms。
  同一夹具的 Windows 原生队列耗时3326ms，创建1个播放器；原 video_player 无 Windows
  后端，此平台只验证新路径，不伪造前后对照。
  数据包含装载及 Dart 回调，只是单次调试模式对照，不是声学间隙测量或发布性能结论；
  不承诺消除服务端音频自带静音、网络等待或不同编码产生的间隙。

本节仅记录方法、依据和测量口径；验证状态与未测边界见 Active 的 TTS-PLAYLIST-20261015。

编写者：Codex｜2026-10-15


### 原生测试的设备数据保护

设备集成测试命令必须明确 `flutter test --no-uninstall ... -d <隔离测试设备号>`，
执行前备份，测试后覆盖安装正常入口应用。Flutter 3.47.7 默认在测试结束后卸载应用；
测试本身不调用数据库不代表宿主应用数据不会受影响。不得在用户验收实例直接运行此类测试。
本批 MuMu 数据事故及恢复状态记录于 Active，不能以重新安装成功代替数据恢复。


## 纯音频后端统一（2026-10-15）

用户收敛范围为正文TTS、音频书和音色试听统一just_audio，暂时保留所有视频功能。
`StreamAudioPlayer` 只定义音频调用与带tag的回调；`ReadAloudAudioPlayer` 实现网络URL、
本地文件、原位续播、实时倍速及原生队列，不再持有视频控制器或super旧后端回退。
正文与音频书共用实例，试听使用同实现的独立实例。异步解码错误由原会话处理，
过期错误不能修改新章或新试听，装载失败先清理原生引用再交由引擎释放音频租约。
主实例随Provider释放，试听继续随预览对象释放。

原生夹具现只验收当前统一后端，不继续依赖video_player运行“旧路径”，前批对照日志
保持历史测量。Windows夹具覆盖真实WAV队列和本机HTTP音频播放/暂停/定位/换绑/完成，
HTTP服务器提供HEAD与Range及查询串检查。此结果不代表真实移动后台、中断、锁屏或
所有第三方音频书源均已验证。视频依赖、代码、原生服务及Rust接口本批不删除。
具体边界见 [纯音频统一方案](AUDIO_PLAYER_UNIFICATION.md)，状态只见Active。

编写者：Codex｜2026-10-15
