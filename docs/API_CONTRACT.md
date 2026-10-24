# API 契约文档

### READER-RESEGMENT-20261024：重新分段算法及书级接线（实施前冻结）

- 沿用 `ReadConfig.reSegment`（默认 false）及既有 Book DTO/保存入口；不新增 FRB 方法、不改数据库、偏好或应用版本。Flutter 只保存开关并重读，业务仅由 Rust 执行。
- `content_help::re_segment` 对齐本地原版 363540972 / HapeLee c4182eb9b 的 ContentHelp 完整流程：引号预处理、错误换行连接、重复引用词条识别、引号状态/断点推导、概率长段切分、对话后处理及末尾格式整理。内部位置按 UTF-16 处理以对应 Kotlin，输出保持有效 Unicode；不保留现有固定10/200/500字阈值的替代算法。空正文返回空串。上游概率切分保留随机分布，测试固定随机输入对照，不声称每次分段完全相同。
- 阅读器与后续朗读正文获取启用“调用方允许重新分段 AND 书级开关”；与是否启用替换规则独立，顺序维持去重复标题→重新分段→繁简转换→替换。导出明确关闭重新分段，既有 raw/正文搜索入口关闭重新分段，保持原有搜索请求与坐标语义；Web旧正文接口按书级开关处理，不扩展Web功能。
- 原始文件/缓存继续保存原文；切换成功后重载处理正文、失效相邻布局预览，沿用既有锚点恢复，不清缓存或自动重启音频。成功反馈在保存完成后发出，失败仅显示实际错误；不为开关复制UI测试或另建Dart算法。
- 复核上游完整函数生成固定随机输入的对照样例；Rust算法以同一批样例验证，另验证真实阅读/导出边界及缓存不变，不逐私有辅助函数机械测试。原版与参考版仅makeDict的Pattern/Regex写法不同，语义相同；上游未找到该算法专门单测。

编写者：Codex + Rust / UI｜2026-10-24

### REPLACE-DEFAULT-20261024：默认替换净化接线（实施前冻结）

- 全局设置 `replaceEnableDefault` 由现有 `configGet/configSet` 读写，Rust 配置键 `config:replaceEnableDefault`，序列化为 `true/false`，缺省 true。Flutter 使用共享设置服务的 RustConfig 投影，不读取旧 SharedPreferences 值、不双写、不迁移；外部配置恢复后通过现有恢复刷新器重读；本批不扩展备份格式。
- 唯一纯业务判定为 `Book::use_replace_rule(default_enabled)`：书级显式 bool 优先；否则图片媒体位或本地 EPUB 关闭；其余取全局默认。本地 EPUB 复用原版本地识别语义（type=0 按 origin，其余检查 LOCAL 位），按 originName 的 .epub 后缀识别；不根据 URL 猜测在线书类型。
- 新增1个只读 FFI `reader_resolve_replace_rule(book: BookDto, default_enabled: bool) -> bool`，经 `ReadingRepository.resolveReplaceRule(Book, bool)` 提供给菜单，不查库、不写书级设置。Mock 只提供普通文字书/显式覆盖夹具，不复制类型判定算法；真实策略在 Rust 验证。FRB 生成器产出绑定，不手改生成文件。
- Rust ContentProcessing 统一以“调用方允许替换 AND 书籍有效开关”门控规则，原始缓存继续保存原始正文。调用方的 raw 选择仍控制繁简转换等既有路径，不能把有效替换开关代入繁简转换或章级重复标题开关。
- 高级设置可保存，菜单使用只读有效值，点击写书级覆盖；加载/读取失败不按 true 伪造有效值。保存完成后的全局变化使阅读正文重载并清理相邻章布局预览，沿用会话代次隔离及锚点恢复，不清原文缓存、不主动重启正在播放的音频。
- 阅读、后续朗读正文请求及导出复用 Engine 处理；Web 旧接口复用同一 Core 判定并读取同一全局配置，避免继续固定默认 true。显式内容搜索开关保持其请求语义，并受书级开关门控。
- 不改 DB schema/Book DTO/应用版本，不新增恢复默认按钮或批量改写书级设置。参考证据为本地 LegadoTeam/legado 363540972 的 Book.kt:232、AppConfig.kt:774；与 HapeLee 判定一致。

编写者：Codex + Rust / UI / Bridge｜2026-10-24

### AUDIO-FOCUS-POLICY-20261024：共享音频焦点策略（实施前冻结）

- 仅Dart内部设置与平台会话行为变化，无Rust/FRB/DTO/方法数变化。ReadAloudSettings.ignoreAudioFocus对应既有preferences键ignoreAudioFocus，bool缺省false；同一设置快照供界面与平台策略使用，不增加旧键处理或双写。
- Android开启后不请求音频焦点，过滤焦点中断/恢复事件；耳机拔出及事件源错误仍终止相关播放。iOS开启仅增加AVAudioSession的mixWithOthers，保留playback/spokenAudio及系统中断处理，不承诺电话等系统中断期间继续播放。
- 所有语音/音频书/试听共用AppAudioSession的使用凭据和串行队列。关闭忽略后若焦点申请被拒绝，暂停并报告原因；设置/恢复策略不触发play/seek或重新创建播放列表，不自动恢复用户已暂停的声音。Android忽略模式仍保留凭据，Web静音保活不因本开关获得更高优先级。
- 设置保存失败不应用运行时策略；保存成功但平台应用失败，保留已保存选择并明确报告“设置已保存，音频策略应用失败”，下一次播放可重试。启动加载、开关变更及备份恢复复用同一策略应用入口；不加入自动重试或另一套播放状态机。

编写者：Codex + UI｜2026-10-24

### READER-EDGE-TIPS-20261023：正文与页眉页脚独立避让（实施前冻结）

- 用户授权新增屏幕偏好extendPageTips，键reader_extend_page_tips，bool缺省false；仅开启刘海避让时显示“扩展至屏幕边缘”。关闭刘海避让仅隐藏入口、不清除选择；关闭本开关时保持原布局。使用既有阅读仓储及备份分类，不增加旧键迁移。
- 正文继续使用原缺口/系统栏边距，页眉页脚的垂直边距允许取消缺口占位，显示中的系统栏仍预留；横向缺口及页脚圆角避让保持。页眉配置了居中提示时保留顶部缺口边距，避免将提示放入刘海中央；延伸的左右页眉复用已有圆角几何的镜像作保守横向内收，不宣称精确获取上角/刘海轮廓。
- 分页测量与绘制共用相同的页边扩展差值：正文同时避开安全区与提示实际占位，重叠处取最大值，不重复扣减。页眉页脚用户边距继续有效。单/双页、相邻章预览与翻页快照共用参数；滚动模式原无页眉页脚，正文仍保留完整安全边距。
- 仅Dart内部参数及偏好扩展，不修改Rust、FRB方法/DTO、原生采样或数据库；正文原文锚点和重排恢复保持。版本及依赖不变。

编写者：Codex + UI｜2026-10-23

### BOOK-MEDIA-POLICY-20261023：开读媒体识别归属收敛（实施前冻结）

- 新增只读FFI `book_resolve_reading_type(book_type: i32, source: Option<BookSourceDto>) → i32`，返回媒体位（4/8/32/64/128组合），不读写数据库、不抓取、不修改书源或书籍。无source时仅提取已有媒体位，不默认补文本位。
- Rust Core唯一拥有书源类型映射和开读识别。保留当前优先级：视频误标识别优先；显式1..4声明覆盖旧媒体位；普通源沿用已有媒体位（缺省文本），仅符合既有HTML抽图条件时提升为图片；已有音视频不提升。UTF-16长度上限及图片样式TEXT排除保持。
- 上游BookSourceExtensions.getBookType用于核对文本/音频/图片/文件映射；项目现有视频类型4、MacCMS纠偏和HTML图片转漫画属于现有适配，本批原样迁移，不声称这些扩展来自上游，也不新增启发式或改变打开方式。JS/Fetcher基础映射复用Core，不引入反向依赖。
- Dart通过BookSourceQueryService.resolveReadingType传递已有类型和可空书源，正式适配器直连FFI；BookDetailService保留书源匹配和开读编排，导航继续归BookOpenUtils。Dart仅保留媒体掩码及详情快照合并的简单位运算，不保留书源识别算法。Mock不调用FFI或复制启发式，仅返回既有书籍媒体位，定向用例显式注入预期识别结果。
- 现有写库流程、详情合并、路由和失败传播保持；不扩展为书籍状态写入或播放器重构。新增1方法、无新增DTO，FRB由固定生成器产出；应用版本、数据库和依赖保持。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

### RULE-TEXT-BOUNDARY-20261023：通用规则文本与元信息显示分离（实施前冻结）

- 内部行为契约修复，不修改FRB签名/DTO/方法数或数据库。通用AnalyzeRule不得按文本内容删除NaN/null/undefined字面量、模板符号或数组中的相应字符串；真正JS null/undefined在既有Function-eval返回点按类型转空串，字符串保持，其他值沿用原字符串化/数组展开行为。脚本副作用及异常仍各执行/传播一次，不通过再次eval判断返回类型。
- 对照本地原版363540972及参考版c4182eb9：RhinoScriptEngine.unwrapReturnValue将Undefined转null，AnalyzeRule.getString只将真正null转空串，未按NaN或模板符号清洗字符串。数值NaN不在通用层额外丢弃；不扩大数组/对象类型化或URL规则改造。
- 搜索/详情已有元信息显示规则保持：空字段、NaN拼接形、第三方占位文案及未展开模板不显示，仅作用于既有元信息位置；合并Dart重复判断，不移入通用解析器，不更改存量书籍或正文。这里是既有展示策略，不声称上游通用语义要求隐藏这些字符串。
- 取消此前泛用Rust字符串清洗帮助函数及其逐参数重复测试，以真实QuickJS→AnalyzeRule行为覆盖缺失值与合法文本；Dart只验证共享显示判断和既有调用方，不为同一规则维护多份算法。
- 本批不新增元信息全局清洗器、FFI查询或历史数据迁移；若以后需要持久化清洗，须先建立字段及来源语义，不能依据字符串内容推断运行类型。应用版本及依赖不变。

编写者：Codex + Rust / UI｜2026-10-23

### BOOKMARK-EXPORT-20261023：书签导出格式与平台保存分离（实施前冻结）

- 新增只读FFI `bookmark_export(book_name: String, book_author: String, bookmarks: Vec<BookmarkDto>, format: BookmarkExportFormatDto) → Result<BookmarkExportDocumentDto, BridgeError>`；format仅Json/Markdown。文档包含file_name、mime_type、content三个String字段，不访问数据库、不写文件、不改变书签顺序。
- Rust唯一生成JSON/Markdown及文件名/MIME。JSON保留time/bookName/bookAuthor/chapterIndex/chapterPos/chapterName/bookText/content八字段，排除本地主键id；Markdown保持既有标题、原文、摘要、空行与前置空格。文件名为bookmark-书名 作者.json/.md，沿用非法字符及控制字符替换为下划线、末尾空白清理；不修改原书名和正文。
- Dart BookmarkExportService仅适配类型化入参和返回文档；导出编排调用该接口后交平台保存，不再序列化书签或拼接模板/文件名。目录页仍按书名+作者读取书签，空列表提示、不保存，导出成功/失败提示及取消静默保持。
- Flutter平台保存保留现有SAF目录选择与UTF-8写入、异常时应用专属外部目录回退、其他平台file_picker目录选择及initialDirectory。选择器取消返回null，不进入回退；文件保存失败向调用方传播，不报告成功。
- Mock不调用FFI、不复制Rust算法；未提供真实格式能力时明确报不支持，不生成伪成功的空导出文件。格式语义由Rust测试验证，Dart只验证编排、取消和保存结果。
- 新增1个FFI方法、1个格式枚举及1个文档DTO；生成绑定，不手改生成物。无数据库、应用版本、依赖和UI样式变更，不扩大为通用文件管理或其他导出重构。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

### AUDIO-BOOK-POLICY-20261023：音频跳过与自动更新状态归属（实施前冻结）

- 新增`audio_resolve_skip_window(read_config: Option<ReadConfigDto>, duration_ms: i64, global_open_credits: i32, global_close_credits: i32) → Option<AudioSkipWindowDto>`；DTO包含`intro_end_ms/outro_start_ms: i64`。纯计算，只调用既有Rust audio_skip_policy，不读写数据库。无配置或明确使用全局时取全局值，其他情况取书级值；未知/过短时长返回None。
- Dart ReadConfig补齐既有`useGlobalAudioSkip`布尔字段，缺省false，与Rust既有默认一致；DTO及JSON双向保留，不再通过片头片尾非零推断作用域。不增加旧值迁移、数据库列或新设置入口。
- Flutter只在播放输入变化后调用窗口计算，同输入复用在途/完成结果（包括None），不在进度采样时反复调用FFI；seek、片尾检测及播放器生命周期仍归Flutter。
- 跳过设置sheet读写明确的useGlobalAudioSkip，全局模式保存不清零书级值；书级零值表示本书不跳过。保存经既有书级配置队列合并并更新播放器绑定，不再将旧路由Book绑回。音频配置从None首次物化时明确初始化为全局，避免保存播放模式/倍速反而关闭全局跳过；已有配置仍保留明确的作用域。没有新增设置项或第三个FFI方法。
- 新增`bookshelf_set_can_update(book_url: String, can_update: bool) → Result<BookDto, BridgeError>`；在Rust事务内读取最新记录，仅修改canUpdate，关闭时清除updateError位。返回最新完整记录；书籍不存在报错，不创建记录，不回写页面旧快照。
- BookshelfRepository新增`setCanUpdate`；已入架详情保存成功后才接受返回快照，失败保留原状态；未入架仍只修改临时展示对象的canUpdate，不落库、不清除错误位，与既有语义一致。
- 既有方法不变，新增2方法及1 DTO；FRB、Freezed/JSON生成物由生成器产出。Mock音频只提供无跳过的示例，不调用FFI或另立策略；测试通过端口返回明确窗口，Rust语义由Rust测试验收。应用版本不变；本批不涉及书签导出、文本清洗、TTS分片或漫画处理。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

### FEATURE-OWNERSHIP-20261022：阅读内部数据职责归位（实施前冻结）

- 仅调整Dart内部目录与依赖：ReaderSourceAnchor模型归domain，ReaderPositionStore偏好读写归data；原键reader_source_anchor_v2、version=2、coordinate=utf16、字段名及恢复/拒绝规则不变，不增加迁移或清洗。
- 后续布局传输接口、只读返回数据与串行会话归domain，原生句柄及FRB映射归data，InheritedWidget注入归reader，原生实现从应用装配提供。会话取消、顺序、失败释放、诊断及既有默认原生路径不变，不新增Dart算法回退。
- Dart内部ReaderLayoutSession构造器显式接收transport，不再由领域会话构造原生实现；ParagraphLayoutEngine维持“显式参数→InheritedWidget→应用默认工厂”的选择顺序。ReaderLayoutReply的原生DTO转换移入data，空begin结果由empty构造，解码及数据内容不变；正式调用方和既有测试同步，不留旧路径导出。
- readerLayoutBegin及opaque句柄push/finish/cancel的FRB签名、载荷与错误、数据库、生成绑定和方法计数全部不变；不运行codegen。只读数据仍使用同一缓冲和字形簇/UTF-16索引规则，不新增复制或序列化。

编写者：Codex + UI / Bridge｜2026-10-22

### SOURCE-JS-DETAIL-20261022：详情结果增量合并（第三批，实施前冻结）

- 对照原版363540972的JsSourceMarshaller.mergeBookInfo：返回对象仅覆盖允许的非null字段；缺省/null保留既有值。name仅在允许重命名时更新；author在允许重命名或原作者为空时更新。书籍身份、进度、自定义字段不从脚本返回对象覆盖。
- 复用已有Book建立详情结果，不要求脚本回传name等完整模型。variable接受对象或JSON对象字符串，合法时整表替换；非法variable/type/downloadUrls忽略该字段。下载地址仅接受全字符串数组，去空、拒绝javascript（不区分大小写）、绝对化并去重。有效type使用实际媒体位4/8/32/64/128，不接受旧错误掩码0x0F。
- 既有FFI webbook_info加可选existing_book: Option<BookDto>及can_re_name: Option<bool>（缺省true），方法数、返回DTO不变；不传时维持URL入口。Dart BookSourceQueryService.getBookInfo加可选existingBook/canReName，详情服务传完整对象，首屏补全不重命名、已有目录后的详情刷新允许更新，门控由Rust执行。页面取址点与稳定主键分开，返回与缓存不得把取址点写成稳定主键。
- mainJs详情使用本次对象与既有变量，合并后variable/type经既有WebBookInfo字段回传；不另设Dart宽容转换或重复合并。普通规则书源保留原抓取/格式化路径。
- mainJs先完成详情再取目录；目录/正文消费已接受的快照变量，不被旧DB读数覆盖。Flutter仅映射已合并的mainJs快照，保留显式空字符串，不再执行第二轮补空逻辑；普通规则书源的并行补全及非空覆盖策略保持。
- Rust及Dart绑定同次生成，测试只覆盖上游完整合并场景和必要边界编排，不在每层逐字段重复；不改数据库、应用版本、Web/MCP功能、搜索结果传输格式或新增文件下载流程。downloadUrls继续停留在既有JS详情模型，本批不扩其FFI返回字段。

编写者：Codex + Rust / Bridge｜2026-10-22

### SOURCE-JS-SCOPE-20261022：主脚本调用作用域与结果（第二批，实施前冻结）

- FFI/DTO/方法计数/数据库不变，内部调用返回明确的exists与Option<String>，不再按字符串内容判空。
- 对照原版JsSourceEngine.buildScope及modules/rhino/ScriptBindings：普通顶层var/let/const、声明函数和注入参数属于本次调用；每次建立独立词法作用域并执行mainJs。复用QuickJS Context、Runtime、宿主资源与jsLib共享层，使库的const/let导出仍可访问；不在构造阶段执行mainJs，不通过清空Cookie/变量来实现隔离。
- 显式globalThis/global与jsLib对象属于同书源缓存层，保留其跨调用状态；不把普通声明混入该层。调用期间将当前绑定借给共享库，返回、错误或取消后解除，不长期保留调用作用域。独立JsResources继续隔离，同资源的流程能力每次绑定。
- 真正的JS null/undefined返回None；字符串（包括空串、空白、"null"、"undefined"）原样Some，数字/布尔沿既有文本表示；对象/数组用当前调用环境执行JSON序列化。循环引用、自定义getter/toJSON错误及超时/取消必须上抛，不伪造"null"。不在本批改变声明式规则通用字符串接口或正文业务层已有trim策略。
- 可选判断、主脚本执行、函数调用与结果序列化使用同一调用作用域及一次执行预算；库缓存不保留首个流程。取消/异常后下一次调用使用新作用域，缓存资源和外部显式状态不被误清空。
- 移除只用于旧主脚本求值标记的内部API/测试，不增加兼容分支；现有公共Rust消费者同步调整。主脚本编译缓存如仍只保存源码，不能宣称已有字节码缓存或性能收益。
- 不扩展详情合并、并发API、jsLib下载策略或新平台能力，版本保持。
- 对象绑定复验确认既有JsValue::Int注入会先强转i32，时间戳等大整数截断；本批修正为JS Number，沿用JS安全整数精度范围，不新增BigInt协议。

编写者：Codex + Rust / Bridge｜2026-10-22

### SOURCE-JS-CALL-20261022：主脚本调用边界修复（第一批，实施前冻结）

- FFI签名、DTO、方法计数及数据库不变。本批修正Rust内部mainJs执行协议，参考原版363540972的JsSourceEngine/JsSourceBook。
- 主脚本首次求值前装配完整书源的source/sourceApi、baseUrl、cookie/cache与已有书源方法；声明式规则和mainJs复用同一份上下文脚本，不复制宿主方法实现。缓存身份必须包含影响上下文的配置，后续配置变更不能继续使用旧source快照。
- source表示可被主脚本声明覆盖的变量，sourceApi保留宿主书源身份及方法；不把主脚本自定义source反写数据库。Cookie、变量、登录及取消继续使用当前JsResources/流程能力。
- book/chapter等结构参数按递归JS对象传入，数字/布尔/null/数组保持类型，属性名沿用序列化模型的camelCase；nextChapterUrl缺省为JS null，不用JSON字符串冒充对象。
- 可选调用先检查目标是否可调用，缺失或非函数返回exists=false；存在时调用一次，函数内部ReferenceError等错误原样传播，禁止依赖异常文案猜测函数缺失。段评摘要同样走可选调用，不能把任意脚本错误降级为空摘要。上下文装配错误拒绝初始化，不在不完整环境中继续执行主脚本。
- isVolume且url以title开头的卷占位不调用脚本，返回空正文并忽略tag；其他卷章节可返回空正文，普通章节空正文仍报ContentEmpty。
- 本批保留现有VM缓存、主脚本求值次数与返回归一化策略，作用域/类型化返回和详情合并后续独立修复。不借机调整jsLib失败策略、并发API、批量正文或回复能力，不改应用版本。

编写者：Codex + Rust / Bridge｜2026-10-22

### SOURCE-PARSE-UNIFY-20261022：书源 JSON 解析与导入契约

书源字段由`legado-core::models::book_source::parse`统一解释。编辑回填、导入预览、
FFI导入、Room导入与服务器更新共用条目解析器，Dart不另写宽容转换规则。

| FFI接口 | 输入与输出 | 行为 |
|---|---|---|
| `source_parse(source_json: String)` | 对象或非空数组 → `Result<BookSourceDto, BridgeError>` | 数组只取首项；空数组或首项非对象报结构错误，后续项不参与回填。允许名称/地址尚未填写，不附warnings |
| `source_preview_fields(json_array: String)` | 对象或数组 → `Result<String, BridgeError>`，字符串内容为JSON数组 | 与输入同序；成功项包含`bookSourceUrl`、`bookSourceName`、`bookSourceComment`、`lastUpdateTime`，失败项为`{"error":"可读原因"}`。文档语法或顶层结构错误整体报错 |
| `source_import(json_array: String)` | 对象或数组 → `Result<i32, BridgeError>` | 严格校验全部条目后批量写入，任一条失败整体拒绝或回滚，成功返回数量 |

`source_parse`与`source_preview_fields`只读，不写数据库、不修改存量记录、不发布限速。
预览逐项保留有效候选，不因个别条目失败改变正式批量写入的原子性。

字段转换按目标类型确定：

| 目标类型 | 接受与空值规则 |
|---|---|
| 整数`i32/i64` | 接受整数及合法整数字符串，数字字符串为明确保留的兼容超集；超范围、非法字符串、布尔、数组、对象报错。缺省及显式`null`取字段默认值，`respondTime`为180000 |
| 布尔 | 接受JSON布尔、整数（0关，非0开）及字符串`"true"/"false"/"1"/"0"/""`，空串为false；其他报错。非可空字段缺省/显式`null`取默认值；`enabledCookieJar`缺省为`Some(true)`，显式`null`为`None`并按关闭处理 |
| 可空字符串`Option<String>` | `null`为`None`，字符串保留原文，数字/布尔转字面量，数组/对象转紧凑JSON字符串 |
| 非可空字符串`String` | 同上，但显式`null`为空串。名称/地址的必填校验由保存或导入阶段负责，解析层不拦截 |
| 六类规则对象 | 接受对象或内容为JSON对象的字符串；直接`null`/数组、空字符串及内容为`null`的字符串表示无规则。非空规则字符串的语法/字段错误必须上抛；规则内字符串按目标类型转换，例如`isVolume:false`为`"false"`、`chapterList:[1,2]`为`"[1,2]"` |

`ruleReview.enabled`同样使用上述布尔转换，缺省及显式`null`均为false；
规则对象和规则JSON字符串两种输入的行为一致，非法值仍报出字段路径。

`ruleContent.contentBatch`为可空字符串，复用上述字符串转换；
`ruleContent.maxBatchSize`为可空i32，缺省及显式`null`均为None，
非空值复用整数转换（接受合法整数字符串，非法类型及越界报字段错误）。
两个字段须经Rust模型、ContentRuleDto、Dart模型双向传递，并在编辑保存及导出中保留。
本批仅补齐解析和数据保留，不启用批量正文执行、不新增编辑控件；
FFI方法签名与方法数不变，DTO新增两字段，Rust/Dart绑定须同次重生成并配套重编原生库。
规则仍存于既有JSON列，不变更数据库schema，也不增加旧数据迁移。

语法错误包含行列，结构错误说明期望形态，字段错误包含字段路径；批量条目错误包含序号，
嵌套规则错误保留外层规则名与内部字段路径，不静默改成空值或0。

Dart的`BookSourceEditService.parseSource`由`RustBookSourceEditService`直连`sourceParse`，
粘贴与扫码共用回填流程，不进行Dart JSON语法预检。`SourceImportParser`的展示字段、
必填校验及确认导入的替换规则匹配均使用Rust归一化结果；原始Map保留用于展示原文、
应用导入选项，以及后续替换/写入。Dart确认导入仍按条目编排，单条失败继续后续条目。

Room导入直接持有归一化实体，经`BookSourceRepository`全列写入（包含`variable`和规则），
不再序列化后重新解析；URL、并发率与限速变更均来自同一实体，仅在事务成功提交后发布。
Mock装配使用无FFI的解析器，只覆盖常规类型化夹具，不声称复刻Rust宽容算法。
Rust测试负责转换语义，Dart测试负责编排、错误传递和路由。

未知字段无损往返及单引号`exploreUrl`嵌套规则解析不在本契约覆盖范围。

编写者：Codex + Rust / UI｜2026-10-22

### READER-BATTERY-20261021：阅读电量平台契约（实施前冻结）

- 使用battery_plus 7.1.2读取系统电量，不新增项目原生通道或手写平台实现。百分比仅接受0..100；插件不支持、读取失败或非法值返回未知，不伪装满电。
- Dart平台监视器由当前ReaderPageView持有并在页眉、页脚及预览间共享；首次和恢复前台读取，充放电状态事件触发补读。插件没有百分比变化流，因此仅阅读器前台每分钟补读；后台取消定时器，阅读器组件销毁时取消订阅与定时器。在途读取合并，释放后不回写。
- ReaderTipContext使用共享ValueListenable<int?>电量源，移除固定100默认；百分比未知显示“—”，图标未知显示外框与短横。固定28×12图形、比例填充及独立语义，配色跟随提示文字。时间+电池、纯图标与百分比共用来源。
- ReaderPageTipBar自行监听电量，只刷新提示子树；正文分页签名、缓存身份与业务状态不依赖电量，预览沿用同一监听源。不改变Rust/FRB、数据库、阅读位置或页眉页脚高度。

编写者：Codex + UI｜2026-10-21

### READER-FONT-METRICS-20261021：基础行盒按主字体度量（实施前冻结）

- FlutterTextShaper以相同字体、字重、斜体、Locale、文字缩放及kTextHeightNone测量空格模板。lineHeightPx取首行LineMetrics.ascent+descent，baselineOffsetPx取ascent，不使用取整后的TextPainter.height或preferredLineHeight，不以中文回退模板决定整章基础行盒。
- 行推进仍为基础H乘行距倍率，段落附加距仍为H乘段距刻度/10；正文、章节标题及其缩放分段共享度量入口，绘制使用布局提供的基线。不新增设置、持久化格式或布局版本标识。
- 保持原始字形簇塑形/宽度测量及选区原文映射；测量策略改变后新布局按现有原文锚点恢复。Rust配置载荷字段含义与FRB签名不变，不增加原生字体桥接。
- 当前Android样本leading均为0；本次不宣称完整复现任意异常字体leading过滤，iOS与非零leading字体需按平台测量，不硬编码Android数值。

编写者：Codex + UI｜2026-10-21

### READER-CUTOUT-AVOIDANCE-20261021：独立系统栏占位与刘海避让（实施前冻结）

- 删除ReaderScreenSettings.extendIntoCutout、ReaderSettingsRepository.updateScreen对应参数、reader_extend_into_cutout键/备份分类及UI入口；不迁移、清洗或兼容读取旧值。
- 保留avoidDisplayCutouts与reader_avoid_display_cutouts（缺省false），显示名称统一为“刘海避让”；不新增重复开关。显示状态栏保留系统顶部占位，隐藏则取消；导航栏同理。缺口开关仅选择四方向缺口边距，与系统占位重叠时取max，不相加。
- legado/system_bar新增getDisplayCutoutInsets，只读返回当前窗口物理像素{width,height,left,top,right,bottom}，不可读取时null；Android按DisplayCutout采样，iOS按公开UIWindow安全区作保守近似，不承诺识别真实硬件轮廓。Dart按DPR转换并核对窗口大小，迟到的旋转结果不回写。
- ReaderScreen稳定保存系统栏原始尺寸；缺口单独采样。内容区、页眉、页脚、滚动及翻页预览共用最终insets；菜单临时显示系统栏不改变阅读配置或分页几何。独立ReaderPageView无宿主参数时仍按隐藏设置处理顶部。
- 移除仅服务旧设置的readBodyToLh与未使用overlay辅助函数，保留菜单自身SafeArea。不改Rust/FRB、数据库、朗读或页脚圆角规则。

编写者：Codex + UI｜2026-10-21

### READER-TITLE-PARITY-20261021：章节标题样式与内容块（实施前冻结）

- 第一批：ReaderTitleSettings新增sizeRelative（缺省true）、fontWeight（500）与lineHeight（1.2），字号缺省4；相对模式取正文+size，绝对模式取size，最终字号至少1。没有旧模式推断或迁移。
- ReaderSettingsRepository.updateTitle按字段更新；新增普通偏好reader_title_size_relative、reader_title_font_weight、reader_title_line_height，既有字号与上下间距键含义保持。备份沿通用分类登记，不清洗旧值。
- 分页、滚动、预览共享标题最终样式与测量环境；字体空值跟随正文，字距按标题字号换算em，斜体跟随正文，颜色保持现有正文色。标题默认居左，上下附加距0。
- 第二批：标题测量为现有Rust布局Paragraph/InlineParagraph的isTitle内容块，采用已有标题间距和行推进参数；移除手工扣首页高度及独立标题绘制。标题不写入正文sourceText，不改变正文UTF-16坐标、复制和朗读文本。
- 第二批载荷细化：标题使用前置emphasized InlineParagraph，每段有独立自然行高、基线、字号缩放与titleSpacingScale；Dart按前置块数映射正文段号，标题标为ParagraphInfo.isTitle，不注册选区，不写正文锚点。既有firstPageHeight/rule占位入口删除，不留并行实现。
- 新普通偏好reader_title_segment_type/position/delimiter/subtitle_scale/segment_spacing，缺省0/4/空串/1/1.2；分段间距按基础标题自然H计算，副标题缩放只作用于该段，不改变原文。缓存身份包含标题文本、卷章、全部几何设置及字体版本；配色更新只重绘。
- 渲染按最终段落坐标定位，负分段距可使后段向上重叠，不以非负高度截断其推进量；容器占用取所有行的最大下沿，原文选择仍只注册正文。
- 标题分段复用上游关闭/按位置/标记/正则规则及副标题缩放；卷章、空章与分页规则按可用数据接线，不扩展完整HTML或单图书源路径。FRB签名与生成物不变；如既有载荷需要扩展，先修订本条再实现。

编写者：Codex + UI｜2026-10-21

### READER-SPACING-RATIO-20261021：正文段距改为自然行高比例

- ReaderTextLayoutSettings.paragraphSpacing、ReaderPageView.paragraphSpacing和ParagraphConfig.paragraphSpacing统一表示自然行高的十分之一刻度，基础值2=0.2H；有效范围0..20，UI显示0..2倍并以0.1倍步进。
- 普通偏好改名reader_paragraph_spacing_tenths。旧固定像素键及其读写、备份分类直接移除，不增加迁移、兼容或专用过滤；新键不存在时取2。
- FlutterTextShaper统一提供paragraphSpacingPx=自然行盒高度×刻度/10，普通段落/行内段评共享LayoutConfigDto.paragraphSpacingPx；FRB/Rust已有参数仍表示最终坐标距离，签名不变。
- ReaderTextLayoutSettings与仓储useZhLayout缺省改为true，显式保存的false仍可关闭；ParagraphConfig及ReaderPageView缺省保持true，实际入口同源。段首标点悬挂保持独立、默认false。
- 滚动模式不做页底对齐；拼接分页结果保留页内最终spacingBefore，页间补足自然行推进后的空白和真实段末附加距。绘制层只消费布局间隔，旧手工PageInfo的fallback参数仍为最终像素距离。
- 不修改业务数据、原文UTF-16位置、Rust/FRB签名、标题或预设语义。

编写者：Codex + UI｜2026-10-21

### READER-TIP-UNIFY-20261021：统一阅读状态信息

- 移除ReaderSettings.statusStrip、ReaderStatusStripSettings及ReaderSettingsRepository.updateStatusStrip，删除四个reader_status_show_*普通偏好的读写与备份分类。开发阶段直接按旧键不存在处理，不读取、迁移、双写或清理旧值，也不增加专用备份过滤。
- 信息统一使用ReaderSettings.pageLayout的header/footer左中右六个提示槽位。updatePageEdge选择非零提示类型时，在同一次局部更新中清除其他槽位的相同类型；多个显式槽位按左、中、右依次应用，后者优先。传0只清空目标；非提示字段不整理存量配置。
- 槽位选择前加载共享设置，按当前快照（含排队中的乐观更新）计算改动；失败继续遵守AppSettingsService逐字段持久化/失败回退语义，不宣称跨键事务。同行渲染相同类型仅显示首项，对齐上游绘制规则。
- 系统状态栏由screen.hideStatusBar独立控制。header.mode为0时系统状态栏隐藏则显示页眉，1恒显示、2恒隐藏；footer.mode为0显示、1隐藏；布局占位与可见内容沿用既有规则。
- 不修改Rust/FRB、数据库、原文位置、翻页或朗读接口。

编写者：Codex + UI｜2026-10-21

### READER-PAGE-HEIGHT-20261021：正文行盒与底部对齐接线

- Flutter正文lineHeight表示自然字体行盒的推进倍率；自然行盒与基线由同一Flutter字体环境测量，文字渲染不再把倍率写入TextStyle.height。倍率分别传入既有LayoutConfigDto和InlineParagraphDto.lineSpacingMultiplier。
- ReaderTextLayoutSettings/ReaderSettingsRepository.updateTextLayout新增textBottomJustify；普通Preferences键reader_text_bottom_justify，缺省true，存取/订阅/备份沿现有共享设置路径。该字段进入布局缓存身份，切换后按原文锚点重排；关闭时保留自然行距。
- ParagraphConfig.textBottomJustify传入既有LayoutConfigDto.textBottomJustify；Rust分页规则不变，底部对齐只分配剩余间隙，不增加可容纳行数；连续滚动不做底部对齐。
- 缺省行距倍率1.2，正文上下6、左右16，与参考版缺省及恢复入口一致；显式保存值保持。隐藏页脚及空提示页脚高度为零，不回退显示另一套页码。
- 不修改FFI签名、数据库、原文UTF-16坐标、段评占位或阅读进度格式。

编写者：Codex + UI｜2026-10-21


## 阅读页脚圆角避让（READER-FOOTER-CORNERS-20261021，实施前冻结）

Rust/FRB及设置键不变。Android legado/system_bar 新增只读 getDisplayCorners，
返回当前窗口物理像素的 width/height，以及 bottomLeft/bottomRight：null或{radius,x,y}。
Android 12以上读取WindowInsets.getRoundedCorner，缺少窗口信息返回null；
窗口已知但无圆角时保留null角，不虚构半径。Dart按当前DPR转逻辑尺寸，方向/尺寸变化重新读取。
iOS及不可用平台使用公开安全区与保守移动端近似，不使用私有API或机型表，桌面默认不补偿。
只对页脚信息行左右槽位取自动安全距离与用户边距的较大值；中间槽、分隔线、纵向高度、
正文分页和设置存储不变。双页中间不按屏幕边缘处理，旋转时按新窗口重新计算。

编写者：Codex + UI｜2026-10-21

## 音频中断后显式恢复（TTS-INTERRUPTION-20261021，实施前冻结）

本批仅调整 Dart 平台会话与播放端口，不修改 Rust/FRB、数据库或播放器队列。
AppAudioSession.acquire / AudioService.requestAudioFocus 传入 userInitiated，默认 false；
手动播放/继续、系统媒体播放按钮及试听显式传 true，自动恢复/换章/保活不继承手动授权。
显式请求允许在缺少中断结束事件时重新调用平台配置和激活；平台成功且中断代次未变才授予凭据。
保活始终受中断及真实音频占用限制。后台恢复不通过超时、前台切换或循环重试抢占。
中断结束但不建议自动恢复使用独立 interruptionEnded 事件，不与耳机拔出/停止混用；
显式恢复成功消费旧中断，迟到的旧结束事件不再影响新播放，新中断仍暂停并使旧申请失效。
激活失败保留原异常/暂停位置和再次手动重试能力；只记录申请来源与拒绝阶段，不记录凭据/正文。

编写者：Codex + UI｜2026-10-21

## 系统媒体服务迁移（TTS-AUDIO-SERVICE-20261020，实施前冻结）

Rust/FRB 方法不变。Dart AudioService 的现有协调接口保持，底层改为 audio_service 的
BaseAudioHandler；插件只发布状态并转发 play/pause/stop/skip/seek，不创建第二播放器或业务队列。
定位与通知导航继续携带 MediaPlaybackTarget 的书籍、会话和章节身份，未知时长不声明 seek；
元数据以书名为 title、章节为 artist，定时为 displayDescription，封面使用受身份检查的本地缩略图 URI。
正文继续使用现有估算章节时间轴，音频书使用真实时长；系统队列不暴露合成分片。
删除 legado/media_session 及两个原生媒体会话、旧音频前台服务，不保留回退。
独有的可选唤醒锁改为 Android 引擎级 legado/audio_wake_lock 的 update{enabled,playing}，
只消费两个布尔值，持有条件为两者均为 true，FlutterEngine 销毁时释放；不依附 Activity 生命周期。
AudioSession 的焦点/中断职责不变，插件平台未实现时仍可本地播放，不宣称提供 Windows SMTC。

编写者：Codex + UI｜2026-10-20

## 音频平台职责收敛（TTS-AUDIO-SESSION-20261020）

本批不改 Rust/FRB；legado/media_session 移除 requestAudioFocus、abandonAudioFocus 与
onAudioFocusChange 原生通道分派，由 Dart AppAudioSession/audio_session 统一激活、释放和事件映射。
原有通知、元数据、封面、进度、定位、媒体按钮与 Web 保活 setEnabled 协议保持；
Web 保活调用方先持有独立音频会话使用凭据，原生只启停近静音音轨，不再修改共享会话。
不保留双重焦点监听或旧通道回退，不改变应用数据契约；行为边界与平台差异见 TTS_ALIGNMENT。

编写者：Codex + UI｜2026-10-20

## 云 TTS 按 ID 查询（TTS-LOOKUP-20261020，实施前冻结）

新增 cloudTtsGet(id: String) -> CloudTtsMetadataDto?，Flutter CloudTtsRepository.get(id)
返回 CloudTtsEngine?；缺项为 null，查询/解码错误抛出，不把错误解释为缺项。
复用既有 DTO，不返回平台凭据，不修改 schema 或保存/删除语义。
Rust 仓库新增 find(id) 可选查询，既有 get(id) 保持缺项报错；两者最终均执行
参数化 WHERE id=?1，不调用全量 list；list 保持完整列举与任一坏行失败语义。
单项查询不解析其他记录，目标记录坏行仍失败；不新增历史迁移或数据修复。
Flutter 合成、音色发现、播放参数解析及已知 ID 的配置操作改用单项查询，
列表管理继续使用 list。每次请求仍读当前启用态及设备凭据；Rust 再核对凭据引用、
音色归属与可用性，不新增会话/全局凭据缓存，不改预下载、原生队列或流式播放。
真实 FFI 定向计数区分 list/get、安全存储接口读取、HTTP 次数；
不以调用计数或内存凭据替身推断设备 IPC 耗时、功耗或首段延迟改善。

编写者：Codex + Bridge｜2026-10-20

## 火山 V3／豆包 2.0（TTS-VOLCENGINE-V3-20261020，实施前冻结）

本批新增 provider=`volcengine_v3`，保留独立 V1 `volcengine`，不自动迁移或回退。
参考版当前仍为 V1，本增量依用户继续接入 V3 的授权，协议以官方文档为准。
V3 使用安全存储中的单 API Key，发 X-Api-Key；model 表示资源 ID，
本批固定支持 seed-tts-2.0，不支持声音克隆/旧控制台 App ID+Token 鉴权。
默认完整端点 https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse，
X-Api-Resource-Id 为稳定头；X-Api-Request-Id 发送前生成新 UUID，不参与缓存身份。
正文原样放 req_params.text；speaker 为音色 ID，提供 Vivi/小何/云舟/小天 2.0 四个官方候选，
不自动保存。style/instructions 合并到 additions JSON 字符串中的 context_texts，
post_process.pitch 也在 additions 内。无角色/语言/SSML/字幕/任意 JSON 设置。
统一领域参数 speed/volume 为倍率 0.5..=2，转换为整数 (倍率-1)*100；
pitch 为音高倍率 0.5..=2，转换为整数 12*log2(倍率)，四舍五入到官方半音范围。
前台/预合成均保留本地保守的 1024 UTF-8 字节分片上限，不把它宣称为 V3 官方上限。
格式 mp3/ogg_opus/pcm/wav；MP3/PCM 使用 24 kHz，Ogg 使用 48 kHz；
本地 WAV 请求上游 PCM，完整收齐后包装 24 kHz 单声道 16-bit LE WAV。
响应必须 text/event-stream，逐事件 JSON 核验；音频 Base64 逐片解码后按序拼接。
code=0 为数据，code=20000000 或正常 SessionFinished(152) 为完成；
SessionCanceled(151)/SessionFailed(153)/错误事件、非零错误码、坏 JSON/Base64、
缺完成/空音频/坏容器均失败，不缓存部分结果，不回显服务端私人载荷。
目录、配置保存、试听与正文使用同一 Provider 分派和默认值，沿用取消/缓存/租约。
仅 FFI Provider 枚举扩展，无数据库迁移、依赖升级或播放队列改动。

依据：[官方 V3 HTTP/SSE](https://docs.volcengine.com/docs/DoubaoVoice/HTTPChunkedSSEUnidirectionalStreaming-V3?lang=zh)、
[官方 2.0 参数](https://docs.volcengine.com/docs/DoubaoVoice/unidirectional-streaming-text-to-speech-http?lang=zh)。
编写者：Codex + Bridge｜2026-10-20

## Rust实践修复边界（2026-10-20，实施前冻结）

普通数据库列表查询任一行解码失败即返回错误，不再成功返回缺行集合；空表仍成功返回空集合。
书籍保存的读取、来源字段合并和更新在同一短写事务完成；读取失败不写入，进度仍由专用字段更新。
内部数据库错误保留分类和source，Busy/Locked才重试；传输仍保留既有错误码，不改FRB签名/DTO/schema。
Web /api/audio/speak的speed缺省1，须有限且大于0，先校验后请求；时长浮点运算后舍入，超范围拒绝。
直接URL TTS与按ID规则合成保持区分；直接URL路径复用所属引擎网络、任务取消、期限和有界响应，
HTTP失败不返回成功音频，文本地址须是有效HTTP(S)地址；单次响应32MiB、整体期限60秒，超额/超时明确失败；不新增JS源规则解释或播放器协议。
归档资源预算在Book层实施，本批默认CBZ页128MiB、导入条目512MiB、单次实际导入总量8GiB、容器条目100000；超额明确失败，不改变FRB字节返回类型。
ZIP按实际输出计量并以单条目暂存文件提交，已完成的前置条目保持；RAR仅头部预检和读完复核，未声称中途限制原生解压。
条目数在ZIP库解析中央目录之后检查，不宣称限制了第三方元数据解析的全部内存。
JS同步异步桥不支持的运行时环境返回可捕获错误，不因current_thread调用block_in_place而panic；Rust内部block_on显式返回环境错误，脚本按各网络入口原有失败形态传播。

编写者：Codex + Rust/Bridge｜2026-10-20

## 普通页面系统栏固定策略（2026-10-20，实施前冻结）

用户授权移除全局沉浸状态栏/导航栏开关，普通页面统一边到边布局；不处理旧偏好键。
本批仅调整Flutter与Android私有MethodChannel，不改Rust/FRB或数据库。

- SystemBarService.apply仅接受appBarColor/navigationBarColor，用于计算系统栏图标明暗。
- legado/system_bar的apply载荷仅包含lightStatusBarIcons/lightNavigationBarIcons两个布尔值，
  true表示浅色背景使用深色图标；Android同时更新两种图标明暗，固定透明系统栏、
  边到边布局并关闭对比度遮罩。
- reader与getDisplayCutoutBottomInset方法保持；阅读器显隐、菜单临时显示、路由归属和
  退出/前台恢复继续由SystemBarController管理，不将阅读器策略改成全局固定显隐。
- iOS普通页面恢复系统栏显示及主题图标明暗；本批不新增原生iOS接线。

编写者：Codex + UI｜2026-10-20

## 正文缓存清理与离线下载并发（2026-10-19，实施前冻结）

用户授权按当前基线修复清理范围，再接通离线下载并发。Rust/Flutter由同一Codex执行，
不新增FRB方法或更改已有DTO，版本不额外递增。

- clearCache仅清除cached_chapters及sameTitleRemoved:*章节附属标记；不再整表清空caches。
  config:*、下载断点/索引/序号、登录状态、音频进度及其他KV均保留；界面说明同步限定为正文缓存。
- cacheBookThreadCount通过现有ConfigRepository存入config:cacheBookThreadCount；有效范围1～8，
  缺失或非法值使用8（参考版CacheBook.maxDownloadConcurrency=8，配置默认16经上限收敛后为8）。
  每个下载任务创建/恢复时捕获并发快照，修改只影响后续任务；实例内显式任务按书籍FIFO，
  队首书内并发，不因多本书而倍增实际章节并发。取消可等待在途执行收尾，但取消后不接收迟到成功/继续派发。
- 下载断点记录连续已处理前沿及前沿之后乱序完成的章节；恢复时跳过已经完成的章节，
  未完成的在途章重新调度。completed/failed只按真正完成的执行计数；在途查询返回全部实际执行章，
  不将待调度章节伪装成下载中。保持同书运行任务复用、任务ID、状态与现有失败章继续策略。

来源：https://github.com/HapeLee/legado-with-MD3/blob/main/app/src/main/java/io/legado/app/model/CacheBook.kt

编写者：Codex + Bridge｜2026-10-19

## JS RSA与签名边界（2026-10-19，实施前冻结）

对照固定参考版15e1337a的AsymmetricCrypto/Sign与JCA；保留createAsymmetricCrypto/createSign的java及裸入口。
RSA transformation仅接受单段RSA或RSA/{ECB|NONE}/{PKCS1Padding|OAEPPadding|OAEPWithSHA-1AndMGF1Padding|OAEPWithSHA-256AndMGF1Padding}，
保留已支持的无连字符SHA写法；未知模式、额外字段及假OAEP名称拒绝，不新增NoPadding/SHA384/512-OAEP等算法。
OAEP沿用[Android普通Provider](https://developer.android.com/privacy-and-security/cryptography)的主摘要=MGF1摘要，SHA256/SHA256；JDK向量显式OAEPParameterSpec选择两者，
不使用桌面JDK默认SHA256/SHA1替换它，不声称支持Android Keystore句柄或全部Provider。
setPublicKey/setPrivateKey支持SPKI/PKCS8原始DER字节和既有PKCS1、PEM/Base64字符串扩展；
原始字节不经String/Base64中转，非法/空/失效输入抛异常，失败不覆盖上一个有效密钥，链式返回this。
RSA明文和签名正文支持UTF-8字符串、有效Uint8/Int8视图与Java byte数组；密文字符串先识别偶数Hex，否则Hutool Base64，
不通过重复尝试不同解码/解密猜格式。保留签名Hex/Base64字符串验签扩展，同一确定性解码规则。
方向参数缺省true、显式null按上游可空Boolean走私钥，其他显式值须Boolean；错误不得静默选公钥。
分块加解密继续按模长和padding预算，空明文也执行一次真实padding操作；畸形密文和不足8字节的type1 padding拒绝。
既有RSA对象懒生成随机密钥对保留，不改变随机密钥长度/生成时机；签名对象必须显式设置所需密钥，不再静默随机生成。
Sign保持6种已有RSA签名摘要及现有别名；缺密钥/无效参数抛异常，合法签名不匹配返回false，不宣称JCA全部算法或异常类型一致。
Packages PKCS8/X509 KeySpec复制构造输入，getEncoded/既有encode返回复制；KeyFactory在generate时校验DER并提供公/私钥对象，
Signature支持initSign/initVerify/update/sign/verify，初始化失败后不能继续使用旧会话；仅保留固定大小增量摘要状态，
不累计完整正文，成功sign/verify（包括不匹配的false）重置摘要并保留初始化密钥。
失效update/verify字节输入不得污染已有摘要；未初始化或模式不对必须拒绝；验证/签名计算复用同一Rust核心，不另设JSON或轮询协议。
保留已确认得间的无new KeySpec和JavaImporter路径；不将临时JDK研究工具变成运行时或永久测试依赖。
不升级RSA/crypto依赖、不改安全豁免、FRB/生成物、数据库或Flutter业务；不宣称修复整个RSA依赖的时序漏洞。

编写者：Codex + Bridge｜2026-10-19

## JS对称加密边界（2026-10-19，实施前冻结）

对照固定参考版15e1337a的JsEncodeUtils/SymmetricCryptoAndroid与[Java Cipher](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/javax/crypto/Cipher.html)；仅处理现有对称加密入口。
AES/DES/DESede支持CBC、ECB及PKCS5/PKCS7/NoPadding，保留既有NONE无填充别名；未知模式或padding明确拒绝。
RC4保持既有单算法路径和1～256字节非空密钥范围，不宣称其全部Provider行为等价，不接受IV。
createSymmetricCrypto的单段块算法按ECB/PKCS5Padding；保留既有16字节DESede双密钥兼容，
DES与DESede对象按参考版截断超长密钥；空密钥拒绝，显式null密钥生成随机密钥，不将空字符串当随机。
对象支持字符串和有效字节视图/Java byte数组；字符串按UTF-8，encrypt/encryptBase64可显式传字符集。
decrypt(String)先识别偶数Hex，否则复用既有Hutool Base64规则；decryptStr默认UTF-8替换无效字符。
setIv复制参数并返回当前对象，不捕获JS对象自引用；工厂忽略空IV，显式setIv空IV仍按非法参数处理。
对象CBC加密缺IV时由安全随机生成器产生本次IV，解密缺IV报错，不伪造零IV；不宣称可取回对象内部随机IV。
Packages Cipher提供ENCRYPT_MODE/DECRYPT_MODE，init验证操作模式、密钥算法/长度及IV，doFinal依模式调用同一Rust核心；
未初始化或失败init后的doFinal拒绝，成功doFinal保留初始化参数供下次独立调用；不新增update/多段流协议。
SecretKeySpec/IvParameterSpec及Cipher初始化复制字节，后续修改源数组不改变已初始化参数；getIV/getEncoded返回拷贝。
CBC加密init缺IV时生成并保留随机IV，getIV可读取；CBC解密init缺IV报错；ECB在对象工厂忽略IV，原生Cipher显式IV拒绝。
所有现有对称加密字符串入口失败抛可捕获异常，不返回[ERROR]正文；null非空String形参拒绝。
aesDecryptBytes复用自有ByteArray转换，失效/越界视图不得当空数据；不跨JS重入保留缓冲区借用。
现有aesEncrypt/desEncrypt/rc4Encrypt等本地便利扩展保留原编码和默认IV，不把它们宣称为参考版同名接口。
不改RSA/签名、依赖、FRB/生成物、数据库及Flutter业务；不新增尚未支持的算法或Provider。

编写者：Codex + Bridge｜2026-10-19

## Gemini 3.8 接入（TTS-GEMINI-20261020，实施前冻结）

用户已选择当前官方 Gemini 3.8 协议，而非参考版早期预览模型的文本指令拼接。
新增 provider=`gemini_tts`，沿用 §2.42 的配置、音色、合成与取消/租约接口，
不迁移数据库。默认 model=`gemini-3.8-flash-tts`，支持同协议的
`gemini-3.8-flash-lite-tts`；可带 `models/` 前缀，其他模型明确拒绝，避免误用协议。
默认基址 https://generativelanguage.googleapis.com/v1beta，自定义基址可去掉尾部 /openai；
固定 POST /models/{model}:generateContent，密钥仅放 x-goog-api-key 头，不放 URL。
正文逐字保留于 contents[0].parts[0].text；非空 style 与 instructions 按换行合并到
speech_metadata.style。voiceConfig.voice 使用真实音色 ID，单音色、非流式、请求 WAV。
不发送旧 DIRECTOR'S NOTES 提示词，不添加文本标签，不支持数值合成语速/音调/音量。
音色默认 Kore，提供官方 30 个内置候选（含参考版未列出的 Zephyr），仍只手动保存用户选择。
JsonAudio 仅接受 application/json 响应；第一候选必须 STOP，阻断/错误/空音频/
无效 Base64/未知 MIME 均失败，不回显服务端正文或凭据。WAV 验证容器后原样保存；
明确标记 audio/L16、codec=pcm、rate=24000 的单声道 16-bit LE 音频才包装 WAV，
同格式 PCM 多片按序拼接，多个 WAV 容器拒绝，禁止把未知二进制猜作 PCM。
缓存继续覆盖实际模型、正文、音色、风格/指令与凭据；取消和租约沿用既有执行层。
不改原生队列、全局播放倍速、分段策略或安全存储格式。

依据：[官方 GenerateContent TTS](https://ai.google.dev/gemini-api/docs/generate-content/speech-generation)。
编写者：Codex + Bridge｜2026-10-20

## 火山 V1 接入（TTS-VOLCENGINE-20261020，实施前冻结）

新增 provider=`volcengine`，对齐固定 c4182eb9 的 VolcengineCloudTtsProvider。
沿用云配置与凭据接口：appId 为必填非秘密应用标识，apiKey 参数/安全存储值为原始
Access Token；model 对此 Provider 表示业务集群，默认 volcano_tts，用户 uid 固定 legado。
不将 App ID 当作密钥，不新增数据库列，不新增 STS/V3 或音色管理 API。
默认端点 https://openspeech.bytedance.com/api/v1/tts，自定义地址为完整 HTTP(S) 端点。
Authorization 使用 Bearer;token，JSON app/token 同源；只有发送请求时生成唯一 UUID reqid，
稳定合成描述不包含 reqid。缓存必须覆盖集群、App ID、音色、正文和实际音频参数，
相同正文重试/并发不因请求编号变化而失去缓存去重。
合成响应类型新增 JsonAudio，与普通音频及 SSE 显式区分；仅在此类型接受 JSON，
要求整数 code=0 或 3000 及有效非空 Base64 data，错误不回显凭据或正文，不缓存部分数据。
四个候选音色 BV001/BV002/BV700/BV701_streaming；只手动保存用户选择，不自动添加。
音色参数支持 speed 0.2..=3、pitch/volume 0.1..=3、style（情感）；格式
mp3/ogg_opus/wav/pcm。PCM 按官方默认 24000 Hz 包装 WAV，Ogg 文件扩展名为 ogg。
前台及预合成共用新增 UTF-8 1024 字节分片约束，不拆字形簇，UTF-16 位置仍映射原文；
不改变段落划分、翻页或原生播放队列。单字形簇超限明确失败，不截断文字。
不提供 V3/豆包 2.0 支持，相关账号和设备听感另行验收。

编写者：Codex + Bridge｜2026-10-20

## AWS Polly 接入（TTS-POLLY-20261020，实施前冻结）

沿用 §2.42 的云引擎/音色/合成接口，新增 provider=`aws_polly`，默认 model=`neural`。
region 必填，支持自定义 HTTP(S) 服务地址；数据库仍只保存 credentialKey，不增加密钥列。
此 Provider 的安全存储值及调用时 apiKey 参数为严格 JSON 对象
`{"apiKey":"Access Key ID","secretKey":"Secret Access Key"}`，两者成组轮换；
Rust 在 Engine 边界按 Provider 解码，错误不回显载荷，其他 Provider 仍传原单密钥字符串。
表单空编辑保留原值，单独更新其中一项须与安全存储中的另一项组成完整凭据。
CloudTtsVoiceDescriptor 新增 supportedModels 字符串数组；只作为候选目录信息，
不写入音色 traitsJson。远端音色目录按 Engine 查询并消费 NextToken，去重 ID，
重复令牌报错，取消覆盖全部分页；配置仓库不隐式执行网络发现。
合成沿用纯文本 POST /v1/speech，语言可选，支持 mp3/ogg_vorbis/pcm/wav；
PCM/WAV 按用户裁决采用 AWS 官方 16 kHz 默认，显式仅允许 8/16 kHz。
SigV4 使用明确 UTC 时间的纯函数；请求认证头与稳定合成头分开，日期及签名不参与
缓存键，区域、模型、输出格式、实际采样率和成组凭据参与缓存身份。
不调整播放队列、不引入 STS、不做数据库迁移；真实账号音频及设备验收另行记录。

编写者：Codex + Bridge｜2026-10-20

## Flutter 封面开书过渡（2026-10-19，实施前冻结）

文字阅读器命名路由可接收BookCoverOrigin，只包含来源书籍标识、当前可见封面位置、
圆角与已显示图像的只读取值入口；未传参数仍可直接开读。来源只在当前路由子树查找，
不建立全局封面注册表或保存进入业务状态。自定义路由克隆图片句柄并负责释放，
正文始终按全屏约束布局；展开/收回只改变外层裁剪与透明度，加载不等待动画完成。
书架和详情仅在当前路由仍有效时导航，避免异步开书期间重复压栈；隐私未通过时不显示
封面快照。返回重新读取位置，无可用起点则淡出；尊重减少动态效果，不新增设置。
保留PrivacyAppGate/PrivacyBookGate、Reader退出保存及命名路由结果语义；
无Rust/FRB/数据库变更，不改变媒体路由。

编写者：Codex + UI｜2026-10-19
## JS摘要与HMAC接口（2026-10-19，实施前冻结）

参考固定15e1337a的JsEncodeUtils及CryptoUtils.digest/hmac；保留java与裸入口。
补HMacHex，与既有hmacHex同源；HMacBase64/hmacBase64、hmacMd5/hmacSha256保留。
摘要与HMAC在已有依赖内支持MD5、SHA-1/224/256/384/512，先计算字节再独立编码为小写Hex或标准带padding、不换行Base64。
摘要计算复用同一MessageDigest核心，Packages能力预校验与实际计算同步补SHA-224/384；
宿主算法名继续忽略大小写和连字符，并支持JCA摘要SHA别名；Packages原有更宽的规范化规则保留。
HMAC保留已确认阅文语料HMAC-SHA1及既有裸SHA1/MD5等别名，不以JDK Provider拼写约束删除兼容。
String形参null抛错，其他值保持Rhino ToString；undefined数据为字面字符串，未知算法抛异常；
空数据合法，空密钥按[SecretKeySpec规则](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/javax/crypto/spec/SecretKeySpec.html)拒绝，非空Unicode及超出摘要块长的密钥正常处理。
java.digestHex维持Java String方法对象，裸digestHex和其他既有接口维持原始字符串；
包装层不能提前String(null)绕过宿主校验，错误不得变为[ERROR]正文或被包装成有效摘要。
MessageDigest原生字节入口拒绝失效视图，不把复制失败当空字节；Packages增量面保持原输入数组转换与成功digest后复位，
null/失效视图的update/digest须失败且保留此前累计内容，不改为新资源句柄或流协议。
只统一本批已支持算法，不宣称实现JCA全部Provider/别名；不修改AES/RSA、FFI/生成物/schema/依赖或Flutter业务。

编写者：Codex + Bridge｜2026-10-19

## JS时间格式与负时间戳（2026-10-19，实施前冻结）

参考固定15e1337a的JsExtensions.timeFormat/timeFormatUTC与AppConst.dateFormat；
数字格式规则核对[Android SimpleDateFormat](https://developer.android.com/reference/java/text/SimpleDateFormat)与JDK25探针，不把Chrono格式串直接当Java格式。
timeFormatUTC(time,format,sh)的time/sh沿用Rhino非空long/int转换，sh单位为毫秒，允许非整分钟偏移；
format为非空String形参，null报错、undefined按字符串转换；空串输出空串，不替换成默认格式。
本批先以ASCII数字支持常用数值字段y/yy、M/L(1~2位)、d/D/F/u、H/k/K/h/m/s/S、Z、X(1~3位)，
数字按最小宽度补零，yy截两位，S为完整毫秒值补零而非小数截断；引号字面量、双单引号转义('')和非ASCII文字保留。
未知格式字母、未闭合单引号及不合法X长度抛可捕获异常，不返回[ERROR]或panic。
本批按数字范围实施；月份/星期名称、AM/PM、纪元、周历及文本时区依赖Locale，明确报不支持，
相关扩展等待用户选择，不擅自固定为英文或中文。
负毫秒时间戳使用正确的秒/毫秒分解；偏移通过checked时间运算应用，越界明确返回错误。
timeFormat(time)维持系统本地时区和yyyy/MM/dd HH:mm显示；只修正负毫秒与安全错误传播。
formatTime/parseTime为本地既有扩展，保留Chrono语法、空格式使用原默认、parseTime按UTC及失败返回-1；
formatTime保持原错误文本约定，但通过可失败写入处理坏格式，禁止Display转String导致panic。
不引入依赖、不改JS Date内建、FFI/生成物/schema/Flutter或平台配置；不承诺JVM全部Locale/本地化数字/历法/时间范围。

编写者：Codex + Bridge｜2026-10-19

## JS URL编码与全局内建函数（2026-10-19，实施前冻结）

参考固定15e1337a的JsExtensions.encodeURI、AnalyzeRule/AnalyzeUrl绑定及Rhino标准作用域。
java.encodeURI(str[,enc])是Java表单编码：ASCII字母数字及-_.和*保留；
空格变+，其余连续非安全字符按指定字符集编码后，全部字节用大写%HH表示。
省略字符集用UTF-8；复用现有UTF-8/GBK/UTF-16等转换能力，UTF-16每个非安全连续段独立带BOM。
非空String形参遵从既有TextArg/CharsetArg：null抛错，undefined转为字面字符串；
未知/非法字符集返回空串（上游显式catch），不回退UTF-8、不返回[ERROR]，不吞ToString本身异常。
全局encodeURI/encodeURIComponent/decodeURI/decodeURIComponent由QuickJS内建提供，
宿主注册不再覆盖；保留各自保留字符、ToString和畸形代理项URIError语义。
java.encodeURIComponent既有扩展复用原生函数，不再维护第二份百分号算法；不新增java.decodeURI等扩展。
urlencode/urldecode为既有本地扩展，不宣称上游同名API：沿用java/裸双入口和单参UTF-8，
按其声明的Java表单语义共用编解码；urldecode将+还原空格、%2B还原+，坏%HH抛可捕获异常。
无效UTF-8字节复用既有替换转换，不承诺JVM全部字符集别名、畸形字节替换分组或孤立代理项传入Rust的等价性。
不修改请求体/AnalyzeUrl、getAbsUrl内部宽松解码、加密算法、FFI/生成物/schema/依赖或Flutter。

编写者：Codex + Bridge｜2026-10-19

## JS Base64/Hex转换（2026-10-19，实施前冻结）

参考固定15e1337a的JsExtensions/CryptoUtils/EncoderUtils、Hutool 5.8.22及Android16 Base64。
沿用java/裸入口；base64Decoder、hexDecode等既有别名保留，无FFI/数据库/依赖变更。
base64Decode(str?)及(str?,charset)使用Hutool路径：支持缺padding、双字母表及跳过表内无效字节；
按固定版本对超出查表范围的ASCII报错，不复刻数组越界或Rust panic。null返回空串，undefined按字符串转换。
第二参数number走Android flags，其余按字符集字符串转换；null字符集抛错，未知编码抛错。
Android路径接受缺padding和非零尾位，跳过非所选字母表字节，但拒绝错误位置/数量的padding。
base64DecodeToByteArray(str?,flags?)默认0，null/空白返回null；非空返回Uint8Array。
base64Encode(str,flags?)及内部base64EncodeBytes默认2，支持NO_PADDING(1)/NO_WRAP(2)/CRLF(4)/URL_SAFE(8)。
换行按76字符分组，非空且启用换行时含结尾换行；其他位忽略。Android Packages的Base64转发flags及标准常量，Java util原无flags的包装保持不变。
flags显式值按现有RhinoInt语义转换，省略使用默认；错误抛可捕获异常，不返回[ERROR]正文。
Hex空字符串解码为长度0的Uint8Array，合法字节到文本使用UTF-8替换无效序列；不污染后续VM状态。
用户明确裁决移除非法Hex文本原样返回兼容；hexDecode/hexDecodeToString与字节接口统一抛错。
字体非网络字符串复用同一Hutool路径；不改变字体解析/缓存或AES/DES等加密算法。

编写者：Codex + Bridge｜2026-10-19

## JS字体输入、请求与缓存（2026-10-19，实施前冻结）

参考固定15e1337a的queryTTF/queryBase64TTF/replaceFont，沿用java与裸别名，无FFI或数据库变更。
queryTTF支持实际字符串及有效Uint8Array/Int8Array视图；字节输入在JS边界即复制，保留视图范围。
null/undefined及不支持的Any类型返回真实JS null；空字符串、损坏字体、非法Base64、失效视图和下载失败抛异常。
HTTP(S)字体规则复用当前VM的AnalyzeUrl与原始HTTP字节管线，支持POST、请求头、Cookie、路由、限流、取消；
不执行bodyJs/type文本转换/WebView，不增加专用网络实现；规则求值和网络等待不持字体缓存锁。
并发冷加载可重复请求，完整解析后只发布有效缓存；失败不污染已有解析结果。
保留既有本地路径扩展，但必须allow_file_access且通过文件沙箱检查，授权与路径检查先于缓存命中。
queryBase64TTF保留上游字符串重载，委托同一字体查询；不增加本地文件或数据URI的上游承诺。
成功返回当前QuickJS拥有的字体对象，直接持有Arc解析结果，不暴露JSON重载数据或全局ID。
replaceFont仅消费真实字体对象或null，无效/伪造对象抛异常，null字体返回原文；不再静默吞下载/解析错误。
资源缓存容量4，按SHA-256标识及LRU淘汰；useCache=false严格绕过读写，不保留字体磁盘缓存或无限句柄表。
JS仍持有的字体不因LRU淘汰失效；最后一个JS对象和缓存引用释放后释放解析结果，不二次下载或读取文件。
useCache/filter省略分别默认true/false，显式传参必须为Boolean；轮廓反查、过滤和空白处理算法不变。
不扩展QueryTTF的其余Java方法，不改TTF解析器、书源规则、Flutter或平台构建。

编写者：Codex + Bridge｜2026-10-19

## JS目录文本读取与清理（2026-10-19，实施前冻结）

沿用getTxtInFolder(path)的java/裸别名及allow_file_access门控，无FFI或数据库变更。
参考固定15e1337a的JsExtensions.kt:828-847：按目录直接子项的枚举顺序读取，不按扩展名过滤、不递归。
每个文件使用现有文本自动检测解码，以一个换行连接，不额外追加末尾换行；空文件仍保留其分隔位置。
空字符串直接返回空串且不操作沙箱；空目录返回空串并清理该目录，不复制上游空集合越界错误。
明确拒绝沙箱根目录及其别名、非目录、目录链接；每个子项须经沙箱校验且指向普通文件。
子目录、坏链接、越界链接、读取/枚举失败抛可捕获JS异常，不跳过文件、不返回[ERROR]或部分结果。
所有文件完整读取后才开始清理：只移除已读取的直接子项，再以非递归删除移除空目录。
读取失败或清理前观察到任务取消时不清理；新出现的未读取子项不递归删除，目录删除失败报错。
清理不是文件系统事务，清理阶段IO错误可能已移除部分已读项；不承诺外部并发换路径的原子防护。
不修改deleteFile、压缩解包、下载、缓存、字体或平台接线。

编写者：Codex + Bridge｜2026-10-19

## JS下载、文本缓存与脚本导入（2026-10-19，实施前冻结）

参考固定15e1337a的JsExtensions；沿用java/裸别名及allow_file_access门控，无FFI或数据库变更。
downloadFile(url)复用当前VM的AnalyzeUrl与原始HTTP字节管线，保留POST、来源头、Cookie、路由、限流和取消。
返回沙箱内相对路径，文件名取原规则字符串MD5中间16位，加type或合法URL后缀（无后缀为ext）。
downloadFile(contentHex,url)仅为上游废弃重载：用规则type，无type返回空串，不发网络请求。
删除仓库仅测试使用的自定义文件名重载；不再根据第二参数字符串猜测重载。
自动下载文件仍属于HttpResources私有目录，销毁资源时清理；扩展名不得用于路径逃逸。
cacheFile(url,saveTime?)返回自动检测编码后的文本，不返回路径；省略saveTime为0永久，单位秒。
缓存保存下载路径，文件缺失时重新下载；遵守用户确认的严格期限，两层均受截止时间约束，负值立即过期。
命中不续期，失败不发布缓存元数据；URL求值和网络等待不持文件锁，锁只协调发布。
并发未命中可能重复请求；发布前再次检查缓存，已有有效值时复用且不续期。
importScript(path)对http前缀使用文本缓存，其余按沙箱本地文本读取；空白内容、IO或网络失败抛异常。
三个接口失败抛可捕获JS异常，不返回[ERROR]正文；取消后不发布下载文件或新缓存路径。
不执行导入脚本、不新增全局服务，不改getTxtInFolder、字体下载、FFI或平台构建。

编写者：Codex + Bridge｜2026-10-19

## JS字节转换统一（2026-10-19，实施前冻结）

沿用strToBytes/bytesToStr的java与裸别名，无FFI变更。strToBytes返回Uint8Array，不再暴露JSON字符串。
bytesToStr接收Uint8Array/Int8Array的有效视图或普通数组，读取当前视图范围；分离/缩容越界缓冲抛异常。
普通数组按仓库Rhino实测的byte转换：数值向零截断后须在-128..127，允许可转数字字符串；
拒绝布尔、null/undefined、NaN/无限值及越界项，不将字符串解析为JSON数组。字节视图保留8位位模式。
UTF-8为默认；只有省略字符集才使用默认，显式null/undefined/未知编码抛异常，不返回[ERROR]正文。
strToBytes不接受null字符串；转换不进行文本编码自动检测。ISO-8859-1/ASCII按Java字符范围转换，
无法编码的字符替换为问号，不使用Web编码器的HTML数字实体。
UTF-16LE/BE分别按指定字节序编码/解码；非空UTF-16编码带BE BOM，空串编码为空字节，解码识别BOM、无BOM用BE。
原生Java字节数组以Rust脚本宿主现有Uint8Array表示，不复制Rhino的Java对象包装身份。
java.lang.String/getBytes、字节输入/输出流统一消费字节；移除内部JSON字节中转。
保持包装对象的字符串方法、输入流拷贝/偏移/mark/reset与现有错误生命周期；不改加密算法、网络、FFI或数据库。

编写者：Codex + Bridge｜2026-10-19

## JS文件与压缩包读取（2026-10-19，实施前冻结）

参考固定15e1337a的JsExtensions；沿用既有文件沙箱与资源所有者，不改FFI签名或数据库。
readFile返回Uint8Array或文件不存在时null；readTxtFile不存在时空串，省略编码自动检测，显式未知编码抛异常。
ZIP/7z的get*ByteArrayContent返回Uint8Array，条目不存在为null；get*StringContent对应空串。
损坏档案、无效十六进制、下载/读取失败及不支持的显式编码抛可捕获JS异常，不冒充缺失内容。
远程档案复用当前VM的AnalyzeUrl准备与HTTP二进制发送：保留来源头、Cookie、路由、期限、限流及取消；
不经过文本解码、type十六进制转换、bodyJs或WebView正文求值，与上游getByteArray路径一致。
保留已有本地档案路径扩展；allow_file_access=false时不读取本地档案，网络/十六进制读取仍可用。
本地普通文件仍经沙箱检查；拒绝词法逃逸及已存在链接指向沙箱外，不承诺抵御外部进程同时替换路径。
文本自动检测复用现有BOM/统计检测；不保证不同检测库对所有短/歧义文本的结果完全相同。
两个字节接口同时注册java命名空间与裸别名，RAR三类入口继续在任何IO之前明确拒绝。
本批不改downloadFile/cacheFile/importScript策略、目录拼接产品规则、文件夹批量读取或原生平台实现。

编写者：Codex + Bridge｜2026-10-19

## 普通JS缓存统一期限（2026-10-19，用户确认的上游差异，实施前冻结）

用户确认cache.put的期限应约束内存与磁盘，明确不保留参考版内存命中绕过磁盘期限的行为。
沿用cache.put(key,value,saveTime?)、get(key,onlyDisk?)、getFromMemory、putMemory与deleteMemory，无FFI变更。
put的两层共享写入时刻确定的截止毫秒，0永久、负值已过期；只有当前时间>截止时间才失效，与文件缓存一致。
成功写入同步保存内存值和期限；磁盘有效命中可回填内存，但保留原截止时间，不延长寿命。
getFromMemory同样检查put条目的期限；putMemory显式创建无期限内存值，不影响磁盘条目。
onlyDisk只读取/检查磁盘，不回填内存，也不删除同键显式putMemory的无期限值。
写盘失败仍返回false并日志限流，内存降级保留同一截止时间；不承诺失败的磁盘写入成功或重启后可用。
失败写入不保证清除原有有效磁盘条目；onlyDisk仍只反映实际持久化内容。
deleteMemory只清内存；delete清理内存/普通磁盘/独立文件缓存。目录、LRU容量和引擎归属不变。
普通磁盘复用值/可选截止时间的内部JSON结构，无法解析的旧条目按未命中处理，不做缓存迁移或协议版本标识。
本批限定JS缓存；不修改登录专用存储、数据库schema、业务缓存、FFI签名或平台接线。

编写者：Codex + Bridge｜2026-10-19

## JS文件缓存期限（2026-10-19，实施前冻结）

沿用cache.putFile(key,value,saveTime?)与cache.getFile(key)，没有新增FFI字段。
QuickJS可选期限沿用现有RhinoOptInt转换；省略/null/undefined为0。页内宿主省略/null为0，提供字符串需可解析为i32整数秒。
0永久，正值为写入时间加秒数，负值已过期；当前时间严格大于截止时间才失效，边界毫秒仍可读。
getFile过期返回null并移除该文件；重开相同目录保留截止时间，覆盖写入替换旧值和期限。
文件缓存与内存/普通cache.put层分离；delete同时移除对应各层，独立引擎目录不互相影响。
文件缓存采用内部JSON值/可选截止时间，不增加协议版本标识；无法按当前结构解析的条目作未命中，由规则重建，不实施旧格式迁移。
QuickJS保留现有写入bool，页内保留现有void/null；失败仍走原日志/false规则，无内存降级，不扩大为全缓存错误改造。
本批仅文件缓存期限行为对齐；普通cache.put的已有负值/失败降级规则不在范围内。

编写者：Codex + Bridge｜2026-10-19

## WebView嗅探匹配与结果语义（2026-10-19，实施前冻结）

沿用既有webViewGetSource/webViewGetOverrideUrl请求与WebViewResponse，不增加FFI字段。
sourceRegex/overrideUrlRegex按整个候选URL匹配，不将任意子串命中视为成功。
资源嗅探只接受实际加载的资源；Android使用onLoadResource，持续等待首个合法命中、取消或既有总期限。
未点击的a[href]、未加载的DOM属性不能作为资源结果；加载结束不代表后续动态资源不会出现。
跳转捕获仅来自实际导航回调，初始URL本身不作为已发生的导航直接返回。
结果result为命中URL，finalUrl为捕获时所属页面地址（缺失时使用输入URL）；不把资源URL冒充页面地址。
Flutter回退使用document.URL识别实际文档，避免HTML载入的历史条目about:blank误作Cookie或结果归属。
空资源规则保留既有空结果，不因本批事件化改为等待完整超时。
命中/失败/取消仍走既有单次完成与清理，Cookie同步与页内宿主顺序保持，不增加全局监听表。
Android清理先离开旧文档停止JS定时器，再延迟原生析构；不宣称已发出的网络请求可强制撤回。
Flutter回退因公开接口无资源事件，限时观察performance资源记录，只保证可观察子集，不宣称等价原生嗅探。
未完成或响应体未消费的fetch/流式资源可能没有performance记录；不能据此保证早期捕获媒体流。
正则方言仍分别受Kotlin/Dart实现约束，不声称全部Java正则语法跨平台一致；不实施新缓存/登录功能。

编写者：Codex + Bridge｜2026-10-19

## WebView加载阶段Cookie同步（2026-10-19，实施前冻结）

新增webview_sync_cookies(key, cookies: Map<String,String>) -> Result<bool,BridgeError>。
平台在加载完成、规则脚本执行前读取当前页面地址和Cookie并等待同步；不结束请求。
key决定所属请求/引擎，未知、结束、超时、取消key返回false且无副作用；数据或持久化失败上抛。
Android沿用CookieManager，Flutter回退仅document.cookie可见子集，不宣称读取HttpOnly。
不得在prompt暂停JS时再次调用页面JS读取Cookie。同步发生在门面、window.result与规则脚本之前。
每个请求保存已观察的平台Cookie基线，初始请求域取WebViewRequest.cookie；域规则沿用现状。
中间/最终回传只合并相对该基线新增或值改变的Cookie，避免未变化快照覆盖期间Rust的新值或清除。
缺失名称不当作删除（回退读取并非完整罐）；平台与Rust均更改同名值时，不承诺获得实际写入时间顺序。
基线仅活在请求生命周期中，页面结束清理；不添加全局会话表、不修改Cookie数据库schema。
完成仍等待已有操作，取消不等待IO锁；已开始的同步写入不承诺回滚，失败不会继续规则脚本。
本批不扩展登录/RSS界面、JS方法或Cookie存储模型，真实Android与iOS证据分别登记。

编写者：Codex + Bridge｜2026-10-19

## 后台WebView页内宿主能力（2026-10-19，实施前冻结）

新增webview_page_call(key, WebViewPageCallDto{target:source|cache|java,method,args:List<String?>})，
返回单个JSON值文本；动态页内调用经白名单/参数验证，不开放任意eval。请求key唯一确定来源和
所属引擎，不接受平台另报来源；仅仍有效且已具备HTML/规则接口的请求可调用。结束/过期/取消/
其他实例key均失败；串行同请求页内调用，完成回传等待已开始操作结束，取消可唤醒正在等待的网络。
开始后的同步副作用不承诺回滚；取消后不再开始新的写入或发布成功，不写全局当前来源。
source.get/put、getVariable/putVariable、登录信息/Header复用Rust现有来源键和登录服务；cache
复用所属JsHostResources.cache，保留内存/磁盘/TTL区别，不建平台镜像，不在完整结果返回时回填快照。
java.get/put按上游RssJsExtensions委托source；同步ajax/connect/get/head/post和getString/List
复用Rust网络/解析器，独立执行视图避免重入正在等待WebView的父VM。source.login复用已配置的
源登录脚本，不打开登录UI。缓存putFile的期限现已按本文“JS文件缓存期限”扩展，统一委托所属CacheStore。
后台无Activity：java.request异步分派不执行（与参考版后台一致），不补RSS导航/界面回调。
Android通过原生prompt回调及现有MethodChannel转发，主线程只异步处理；Flutter回退使用
公开prompt回调保持页内同步返回。两路消费相同Dart参数校验/错误信封与Rust执行，不把失败转空串。
同步ajax按上游返回错误文本，connect返回上游WebJsExtensions的响应概要字符串；协议取真实响应，
JS内部响应增加raw_summary供概要读取（不替换正文/字段），没有元数据不伪造真实协议。
HTTP/1说明取库的标准描述（不保证非标准自定义reason短语），HTTP/2、3无reason；失败使用
既有合成200概要，不将其当真实HTTP成功。get/head/post及解析失败明确抛出。
需要配置的调用找不到书源/未提供页内宿主、未知方法和坏参数均显式失败，不伪装成功。真实DOM/平台Cookie/
原生释放仍需设备验证。本批不改数据库schema、依赖、登录UI或RSS页面。

编写者：Codex + Bridge｜2026-10-19

## URL规则WebView执行（2026-10-19，实施前冻结）

本节取代下方历史批次中“URL规则WebView仍拒绝/未接入”的限制，其余DNS/代理边界不变。
ajax/connect/ajaxAll/ajaxTestAll共用URL规则分派。type字节模式优先；否则webView为真时，
POST先执行既有HTTP管线，再将HTML和最终URL交平台，其他方法直接平台加载；bodyJs仅用于
普通HTTP。源限流只获取一次，批量保序/错误/取消保持。平台加载不声称支持Rust DNS/代理
覆盖，POST前置HTTP仍消费这些配置；无本宿主订阅明确失败，不改发普通HTTP。
WebViewRequestDto增加headers字符串映射；action=cancel为Rust取消/超时/放弃发出的控制
事件，只含key。平台取消清除排队或停止并释放在途页面；取消后不重试或回传成功。
新增WebViewResponseDto{result,finalUrl,error?,cookies}及webview_complete(key,response)。
正常空结果有效；error非空表示失败。内部保留finalUrl，HTTP适配生成合成200和空响应头，
不虚构真实HTTP状态。既有文本提交入口委托同一完成判定；迟到/重复/未知key无Cookie副作用，
合法认领后先持久化Cookie再唤醒，已开始的提交不强制回滚；finalUrl缺省为请求URL。
Core提供通知驱动的异步等待，批量不阻塞Tokio worker。HTTP callTimeout只约束前置HTTP，
WebView独立60秒，规则级WebJS仍10秒。取消释放等待句柄及平台执行。
最小Dart/平台适配及绑定生成随同交付，不做UI布局或登录重构。Android按key销毁独立实例；
Flutter回退停止页面、解绑回调并释放控制器引用，不宣称公开API之外的立即原生析构。
真实DOM、平台Cookie及原生释放需要设备验证，不以模拟回传代替。

编写者：Codex + Bridge｜2026-10-19

## WebJS规则上下文传递（2026-10-19，实施前冻结）

沿用现有WebViewRequest和FRB签名；Parser不依赖JS实现。宿主适配器为规则请求填入
实际source_tag；QuickJS档从所属HttpResources按本次页面URL读取Cookie，禁止按书源
URL代替页面域或缓存首个Cookie值。无QuickJS档传递source_tag，沿用无Cookie读者的边界。
适配闭包只捕获管理器、取消能力及HTTP数据资源，不捕获根Engine、VM缓存或整个JsResources。
解析器派生子规则时共享已注入的WebView执行能力，显式回调不能被重新推导覆盖。
WebJS result的JSON保留现有结构化元素语义：普通内容为字符串，标记为元素的合法对象/
数组保留类型，非法JSON或标量仍为字符串；正常与无头路径使用同一值序列化逻辑。
保留当前拆链、HTML输入、取消、期限、Cookie回流和无订阅回退；不新增请求头/登录事件、
WebView URL选项或平台DOM实现。仅Rust行为测试验证，不构建DLL/应用/模拟器。

编写者：Codex + Bridge｜2026-10-19

## WebView 请求生命周期与结果回传（2026-10-19，实施前冻结）

本批不改FRB签名、DTO、数据库schema、Flutter界面或WebView执行器；只收口Rust通道。
每个Engine沿用所属JsHostResources中的WebView管理器，JS、解析/正文钩子和FFI订阅/
回传使用同一实例；无根Engine回指或进程共享请求表。独立无订阅JS保持既有载荷回退。
已有任务取消能力时，请求绑定本次取消快照；无任务的独立宿主仍受显式取消和超时约束。
取消/超时/句柄丢弃/最后订阅退出均清理待处理请求并唤醒等待；正常空字符串仍成功，
取消明确为错误，桥接层不转换为正文或触发无头重试。既有平台载荷中的`[ERROR]`
前缀表示执行失败，Rust等待适配层将其转为错误；不修改结果传输格式。
回传必须先原子认领仍有效且未取消/超时的本实例请求，方可写入本实例Cookie并发布结果。
重复、未知、迟到及其他实例的key返回false且没有Cookie副作用。认领与取消/超时互斥，
认领后的提交完成后才唤醒等待方；已开始的Cookie提交不承诺强制中断或回滚。
请求key跨实例唯一，订阅退出显式注销；数据资源由Arc正常释放，不使用泄漏的静态管理器。
沿用既有Cookie合并和错误日志策略，不新增登录回调、请求WebView选项、DOM/资源嗅探实现。
仅采用Rust通道、真实QuickJS和数据库行为回归；真实WebView/平台Cookie验证留后续批次。

编写者：Codex + Bridge｜2026-10-19

## 漫画手动离线缓存（MANGA-OFFLINE-20261024，实施前冻结）

- 复用`CacheDownloadService`及现有任务/失败章/取消/重试接口，签名、DTO、FRB方法数和数据库不变。
  漫画菜单提供范围下载和下载队列入口，本地CBZ不提供下载入口；自动离线开关留待后批。
- 在线漫画章节任务先取得原始章节正文，再按正文图片顺序复用ImageService的请求头、Cookie及
  imageDecode，将有效图片写入既有书级ImageCacheService目录；已有有效图片跳过，不引入第二套目录。
  仅当正文缓存和全部图片均已落盘才计章节成功；网络、解码及写盘失败计失败章，重试复用已完成图片。
- 普通阅读仍可缓存正文，即使图片未齐；已缓存章节列表对漫画额外核验图片完整性，不能仅凭正文行
  报告可离线。卷标记不下载图片。文本、音视频及本地书的既有缓存判定不变。
- 下载沿用现有任务并发、FIFO和生命周期；图片在章内顺序执行，不叠加独立后台队列。
  取消停止后续图片并禁止取消后发布结果/写盘，允许已完成缓存保留；不承诺回滚缓存或中断同步JS执行。
- Flutter只负责范围表单、启动反馈和队列导航；Rust负责解析图片、请求、落盘和完整性判断。
  无新增依赖、应用版本或自动下载行为。验证使用定向Rust回环HTTP/临时缓存及既有表单回归。

编写者：Codex + Rust / UI｜2026-10-24

## 漫画预加载配置（MANGA-PRELOAD-20261024，实施前冻结）

- `MangaSettings`增加`preloadImages`（默认true），由现有漫画仓储统一读写Rust配置键
  `mangaPreDownloadNum`（关闭0、开启10；正数解释为启用，对照参考版当前章图片预载开关）。
- 图片启用后预载当前章，可见区域及其近邻优先，等待项随视口重排；最多两个后台图片任务。
  关闭时不另发后台图片请求，正常可见图片的加载与缓存保持。图片状态、源Header、imageDecode
  仍经既有领域接口；预载只准备原有磁盘缓存，不把当前章图片全部填入内存。
  本地CBZ已有原件，仅保留正常可见图片的读取/缓存，不执行整章后台预下载。
  不增加下载通道或应用依赖；该设置纳入既有备份配置白名单。
- 章节正文预取直接消费DownloadSettings的`preDownloadNum/preDownloadNumPrev`（默认10/0、0关闭方向），
  不另设漫画章节数量键；下一章优先，按方向和章节边界顺序访问既有`getChapterContentFull`。
  这是正文预取，不承诺下载未来章全部图片，不在本批接自动离线缓存或整书下载。
- 切章、换书、配置变化和退出后停止旧队列继续取下一项；现有FFI不支持取消已经发出的单次
  请求，允许它结束，但旧图片结果不继续发布或启动后续写入；不伪称已经中断网络或回滚完成的缓存。
- 页面读取共享变更流，不维护第二份章节设置；未完成有效设置读取前不启动预取。保存失败保留
  原预载设置并提示；预载失败不阻塞阅读，同窗口不循环重试，正式图片加载保留原重试路径。
- 无FRB签名、DTO、数据库或应用版本变化；不更改图片归属、清理规则及已完成的漫画位置/缩放行为。

编写者：Codex + UI / Bridge｜2026-10-24

## Flutter 开书导航（2026-10-19，实施前冻结）

漫画浏览设置（MANGA-VIEWER-20261024，实施前冻结）：GeneralSettings及其仓储增加
showMangaUi，复用Preferences原键showMangaUi，缺省true；高级页与开书入口消费同一快照，
不维护页面副本。在线图片书开启时进专用漫画阅读器，关闭时进普通阅读器的图片展示路径。
书架、详情、公共开书与启动恢复使用同一导航判定，音视频优先级、封面动效和书籍类型不变。
设置只影响后续开书，不切换正在运行的阅读会话；读取或保存失败不伪装成功。
本地漫画（含CBZ和WebDAV本地格式）保留专用漫画阅读器，不受在线开关影响；
参考版书架/详情入口排除本地书，但本项目普通阅读器尚不能读取CBZ条目，保留既有能力。
不新增FRB方法、DTO、数据库或依赖。
编写者：Codex + UI｜2026-10-24。

书架与公共 BookOpenUtils.openBook 不再按零阅读进度转入详情，统一按书籍类型
进入阅读器或播放器，文本继续由 ReaderNotifier.openBook 加载目录与章节。
删除 unreadOpensBookInfo、BookInfoArgs、BookInfoScreen.openReaderImmediately
及其自动导航状态；详情路由继续接收 Book 或 bookUrl，显式点击阅读按钮才开读。
长按进入详情、隐私门禁、媒体参数、开读后的进度刷新及欢迎页全局导航保持。
本次仅调整 Flutter 导航参数与交互，不改 Rust/FRB/数据库或原文定位契约。

编写者：Codex + UI｜2026-10-19

## 通用网络任务并发设置（2026-10-18，实施前冻结）

threadCount经领域设置仓储→共享AppSettingsService→ConfigRepository保存到Rust
config:threadCount；不再从SharedPreferences读写或维护镜像，不迁移尚未接线的旧值。
按参考版DownloadCacheSettings默认16、设置界面范围1..256；缺失/非法存储值回落16，
数据库读取失败保留错误，不以默认值掩盖故障。新写入超范围值拒绝。
Engine统一解释配置，JS批量、搜索/换源、目录并行页与书源校验消费同一来源。
每个并发调度阶段固定一次快照，新设置作用于后续阶段，不热改在途队列；这是每批
任务并发上限，不是系统线程池大小或Engine所有任务合计上限。换源增强保留现有8上限。
Fetcher只接收宿主注入的非零快照，不访问数据库；最小宿主默认16。目录保序、错误
与取消门禁不变；书源校验并行执行且按输入顺序发布，保留原index/最后项语义。
Server批量更新省略max_concurrent时读本实例配置；显式值沿用现有max(1)规则优先，
返回实际采用值。Server独立批量书源校验省略concurrency时读本实例配置，保留20上限；
显式参数沿用1..20夹取并优先。Flutter书架逐书串行更新本批不改，单书目录分页使用该配置。
离线下载cacheBookThreadCount、TTS并发及其专用限制独立，不合并。
设置页使用现有数字对话框，保存/读取失败可见且不显示伪成功，不新增FRB方法、生成物、
数据库schema或依赖；验证采用Rust/Flutter行为测试，不构建应用/DLL或模拟器。

编写者：Codex + Bridge｜2026-10-18

## SOCKS4请求代理（2026-10-18，实施前冻结）

允许socks4://host:port复用现有reqwest SOCKS通道，不新增依赖或协议实现。
严格解析与宽容配置构造均识别独立Socks4类型；请求级DNS、Cookie、限流、
期限与取消沿用现有管线。SOCKS4使用IPv4目标与本地DNS；代理拒绝必须返回错误，
不得直连或改用SOCKS5。参考版HttpHelper统一交Java SOCKS入口，本批不把该入口
当作完整SOCKS4互操作证明，以真实v4握手和源站收包验证。
当前reqwest v4路径不传递USERID/密码；标准或遗留凭据配置均在构建前明确拒绝，
不宣称SOCKS5式认证能力，不静默丢弃凭据。SOCKS4a不在本批范围。
不改FRB/生成物、数据库、UI或依赖；验证仅限本地Rust/QuickJS网络测试。

编写者：Codex + Bridge｜2026-10-18

## JS请求级DNS与代理（2026-10-18，实施前冻结）

ajax/connect和批量请求复用同一AnalyzeUrl发送管线，消费dnsIp与proxy（含来源header中的
proxy控制项），控制项不作为HTTP头发送。WebView仍明确拒绝，不以普通HTTP代替。
dnsIp按参考版15e1337a的parseIpsFromString处理逗号列表：逐项接受IP或解析主机名，
忽略失败项；全空/全失败回落原DNS。有效列表仅覆盖本请求派生客户端的DNS查找，
包含重定向和代理主机的本地解析，保留URL域名、Host和TLS SNI；字面量IP不强制改写。
不修改Engine全局hosts，也不将请求级映射写入数据库。DNS准备与网络等待均可取消。
代理复用既有Net校验与认证能力，支持HTTP/HTTPS/SOCKS5及既有标准/遗留凭据格式；
SOCKS4的补充范围见上方“SOCKS4请求代理”。非法代理在发送前返回错误，
不得降级直连；显式代理优先于回环直连策略，不把代理凭据加入诊断日志或缓存Debug输出。
派生池按实际代理/DNS地址列表、直连和期限策略区分，在所属HttpResources内有界复用，
reset同步失效。所有变体共享原Cookie罐与持久化后端，既有源限流、超时、重试、
重定向及取消错误形态不变；流/批次失败直接释放等待，不创建脱离任务。
不改变FRB签名/生成物、schema、Flutter设置或依赖版本；仅用Rust真实QuickJS与有界
本地HTTP/代理验证，未执行平台构建，不声称HTTP代理或SOCKS远端DNS可由本地dnsIp覆盖。

编写者：Codex + Bridge｜2026-10-18

## JS任务主动取消（2026-10-18，实施前冻结）

复用宿主已登记的TaskHandle，通过JS层定义的窄取消能力按次绑定执行，不反向引用Engine。
QuickJS指令执行、源限流等待、HTTP发送/正文读取及批量队列均响应所属任务取消；
取消与JS期限/网络故障分开诊断，不转换为ajax错误正文、connect错误响应或探活失败项后继续。
缓存VM不长期持有首个任务；初始化、fresh、mainJs及compiled路径使用当次能力，
嵌套执行保存恢复上下文，结束/异常后释放绑定。未绑定任务的独立VM保持现有行为。
停止任务不发布后续结果或新发请求；保持已有提交门禁，不承诺回滚取消前已完成的副作用，
也不强杀任意原生函数。外层入口被丢弃后，阻塞worker仍登记至实际退出。
普通HTTP错误、显式零期限及书源接口返回形态不变，不新增FRB入口或全仓错误载荷改造。
验证限于Rust/真实QuickJS/有界回环HTTP，不新增外部宿主、DLL或模拟器验收。

编写者：Codex + Bridge｜2026-10-18

## JS请求限流与批量并发（2026-10-18，实施前冻结）

ajax/connect及get/head/post复用所属EngineContext的RateLimiterRegistry，按当前源键
消费concurrentRate，与抓取主链共用窗口；书源、订阅源和httpTts:<id>均从所属存储读取。
HTTP TTS沿用ttsSourceState中的concurrentRate覆盖。源配置缺失/空值/0沿用现有限流器语义。
限流等待发生在HTTP发送前，释放数据库连接与策略锁后再等待；网络期限与callTime不包含等待。
ajaxAll/ajaxTestAll的skipRateLimit缺省为false，true仅跳过源限流，不跳过并发上限。
正式引擎从通用Rust配置config:threadCount读取正整数并发，缺失/非法值使用上游默认16；独立无存储VM
保持4。每批次固定来源、策略与并发快照，后续调用重新读取配置；源头不从异步TLS重取。
批次失败直接丢弃在途请求及限流等待，不生成脱离任务或预先占用未来窗口。
JS仅定义可注入窄策略，不反向依赖Fetcher、不持有根Engine/JsResources，保留可释放资源图。
不修改UI、FRB签名/生成物、数据库schema、网络重试及外部主动停止能力。
该批交付时Flutter线程数条目仍是读取SharedPreferences的只读占位，与Rust配置尚未统一；
本轮已统一权威来源并开放控件，见上方“通用网络任务并发设置”；Rust不读取平台私有偏好文件。

编写者：Codex + Bridge｜2026-10-18

## JS响应桥注入生命周期（2026-10-18，实施前冻结）

保留宿主注册与setup之后的响应桥注入时机；同一VM重复注入且函数/依赖未变时，
必须复用已安装包装，不重复解析响应或叠加变量查询/webView垫片。
setup替换底层函数或connectNR依赖后须重新适配最新函数，保留旧包装委托的行为，
不能用“整个桥已初始化”直接跳过。单参get继续查询变量，多参仍为网络请求。
connect/批量返回StrResponse，get/head/post返回既有Response；超时、错误、Cookie、
头与正文规则不改。只有本VM桥实际创建的同类响应对象可以在setup委托后原样返回；
损坏JSON或任意伪响应对象仍须拒绝，不能用宽松对象识别掩盖格式错误。
安装记录只在当前VM保存，不进入数据库/全局Engine，不新增进程级状态或根资源引用。
FRB签名、生成物、数据库、网络发送实现和依赖不变。

编写者：Codex + Bridge｜2026-10-18


## JS批量网络请求（2026-10-18，实施前冻结）

ajaxAll(urls, skipRateLimit?)、ajaxTestAll(urls, timeout?, skipRateLimit?)在JS端返回
StrResponse数组，保留输入顺序、重复项与空列表的既有宽松入参；不再返回JSON字符串数组
或statusCode/success探活对象。每项提供body()/code()/raw()/callTime()等同源响应能力。
内部Rust边界仍以JSON传输，JS包装负责恢复对象方法；不保留第二种旧返回协议。
两接口复用单项AnalyzeUrl规则、源头快照、Cookie、编码和重试；不以HEAD探活替代正文。
ajaxAll失败抛异常，立即释放整个批次的在途future及未启动队列，不分离tokio任务。
ajaxTestAll逐项保留失败：合成状态200、错误正文与负callTime；调用方用callTime<0
判断失败。Timeout按现有结构记-1，其他不可细分错误记-7，不按字符串猜Java错误类别。
成功callTime为请求和响应处理的实际毫秒数；超时参数覆盖URL预算，零关闭调用总期限。
默认/null/undefined继续使用默认，负数在任何请求前拒绝；数值转换沿用原始Int契约。
动态JS借用当前VM，在同步准备或响应求值后立刻恢复外层result/baseUrl/page、URL和头，
不跨异步等待保留这些临时绑定。源限流、全局threadCount与skipRateLimit的后续接线
见上方“JS请求限流与批量并发”；本节不新增外部网络停止接口。
FRB签名、生成绑定、数据库及UI不变；DNS/代理后续接线见上方“JS请求级DNS与代理”，WebView仍不支持。

编写者：Codex + Bridge｜2026-10-18


## JS规则请求统一（2026-10-18，实施前冻结）

ajax/connect复用AnalyzeUrl规则解析；同一URL选项的method/body/headers/charset、动态
@js/<js>/{{}}与选项js/bodyJs在当前QuickJS上下文执行，不另建VM或重复获取引擎锁。
来源头→connect显式头→URL规则头按不区分大小写覆盖；Cookie沿请求域合并且保留写入门控。
初始Content-Type参与正文编码判定；脚本明确覆盖Content-Type后不沿用自动表单编码。
缺省或显式零超时沿用前批约定；显式调用超时优先于规则timeout/既有timeout_ms扩展。
保留ajax标准JSON扩展的响应JSON形态与增强方法参数；普通规则ajax只返回正文，connect
保留StrResponse包装。原生请求和JS错误转换分离，get/head/post不进入AnalyzeUrl。
嵌套规则保存/恢复外层URL、待发头及result，失败也恢复；已有解析器对选项JS的降级策略
本批不统一重写。编码复用原抓取链四级解码，重定向/状态码重试复用下层通用发送算法。
DNS/代理接线见上方“JS请求级DNS与代理”；webView仍明确返回不支持，不发送普通HTTP替代请求。
FRB/schema/生成物不变，不新增对Fetcher的反向依赖，不改变批量请求。

编写者：Codex + Bridge｜2026-10-18



## JS请求失败与超时分层（2026-10-18，实施前冻结）

按参考版15e1337a：ajax失败返回含原因的错误文本；connect失败返回StrResponse，
body承载错误，raw使用上游合成状态200及请求URL，不能将其当作真实HTTP成功。
get/head/post的网络失败抛出JS异常，不再返回状态0/空正文；真实HTTP响应行为不因本批改变。
包装收到损坏的内部响应时明确抛错，不伪造空响应。单参java.get仍查询变量。
缺省/null/undefined沿用默认；合法正数保留逐次期限，负数/越界在发送前拒绝。
显式0须保留：ajax/connect不设总调用期限，同时保留连接与读取空闲超时；
get/head/post的0不设请求/连接/读取超时。0覆盖规则内timeout_ms，不得退化为缺省。
网络层新增明确的客户端超时策略，默认策略保持原行为；派生无重定向客户端继承策略。
JS按直连/代理、重定向和超时策略惰性复用池，所有池共享同一Cookie与持久化后端。
FRB函数、生成物、数据库和书源存储不变；本批不统一AnalyzeUrl或批量请求。

编写者：Codex + Bridge｜2026-10-18



## JS网络逐请求超时与回环分派（2026-10-18，实施前冻结）

参考版15e1337a的JsExtensions.get/head(url,headers,timeout: Int?)及
post(url,body,headers,timeout: Int?)在最后一参接收毫秒超时。补齐JS包装到
不跟随重定向请求的参数传递；缺省/null/undefined保持默认，正数按请求生效，
负数及超出Int范围在发送前拒绝。保留原有请求正文、请求头、302拦截、Cookie门控
及单参java.get变量查询。timeout=0语义以上方“JS请求失败与超时分层”的新约定为准。
JS回环池按URL解析后的HTTP(S)主机选择，涵盖IPv4回环与IPv6 ::1；用户名、路径、
相似域名不得被误认而绕过代理。其他域名继续使用原代理池，不改变沙箱网络权限。
FRB签名/生成绑定、书源存储、数据库及公开Rust旧请求入口不变。

编写者：Codex + Bridge｜2026-10-18

## 胶囊底栏文字边界（2026-10-18，用户确认）

AppFloatingBottomBar增加showLabels可选布尔参数，默认true；主页从已有
UiSettings.labelVisibilityMode映射：auto和labeled均为true，unlabeled为false。
不新增偏好、不改保存值；标准底栏仍保留原三档。Glass页签传入label/null并始终保留
semanticLabel，普通胶囊同步显示图标与文字；不实现只选中显示或自定义文字显隐动画。
前景颜色显式使用应用主题，文字仅一行，基准胶囊高度64dp；大字体按所需行高增加
占用，AppBottomBarInset继续消费实际尺寸。文字设置页提示胶囊下auto映射全部常显。
不改Rust/FRB或数据库，版本仍为2.0.380+381；完成后本地提交，不自动推送或安装。

编写者：Codex + UI｜2026-10-18

## 阅读器 Glass 界面边界（2026-10-18，用户确认）

阅读器统一使用 Glass 设计，不提供旧版/胶囊/液态菜单切换，不新增任何偏好键。
前一轮未提交的 useLiquidGlass 配置、仓储参数、编解码和文案均撤销；原菜单配色、
亮度设置和业务行为保留。Rust/FRB、数据库与阅读位置契约不变。

第一批：顶栏独立返回按钮及共用背景动作组，章节信息保留网页/书源入口；
底部进度与五键操作分成两个悬浮圆角表面，左右12dp、间隔10dp、底部12dp加系统
安全区、四角28dp。使用真实GlassButton/GlassSlider，通过阅读器专用组件传递普通
数值与回调，SDK Cupertino主题从material_ui局部阅读主题显式适配。
按钮组内使用透明交互，不重复绘制玻璃。资源未就绪时表面降级、控件使用minimal，
不恢复旧布局。保留原菜单控制器及外部点击/滑动关闭语义；弹出菜单内容、设置Sheet、
选区工具条和朗读浮层在后续批次迁移。原220/180ms动画及减少动态效果规则保持。
版本保持2.0.380+381，不自动推送或安装；iOS GPU效果和性能验收后置。

编写者：Codex + UI｜2026-10-18

## 顶栏液态按钮适配边界（2026-10-18，实施前冻结）

沿用TopBarButtonStyle.liquidGlass、TopBarActionStyler与TopBarButton现有输入，
不新增偏好键，不修改Rust/FRB或数据库。仅在AppGlassScope预热成功时启用玻璃背景，
未就绪保留原半透明实色。独立按钮与合并胶囊视觉均为36dp、点击48dp；合并只作用于
右侧动作，返回按钮独立；Plain不合并。胶囊背景与点击层分开，单动作自然退化为圆形，
保留分隔线，图标、文字和自定义菜单入口不重建为第三方交互控件。
按钮材质沿用原色alpha乘0.5，光学模糊固定8逻辑像素，不复用栏背景浓度或全局模糊开关。
GlassContainer仅绘制背景，不参与手势或语义；点击、长按、键盘、菜单与禁用态由原控件
负责，不新增自定义缩放。用户要求后续批次不提升版本号，本批保持2.0.380+381。

编写者：Codex + UI｜2026-10-18

## 悬浮底栏液态玻璃设置边界（2026-10-18，实施前冻结）

UiSettings / UiSettingsRepository.update新增useFloatingBottomBarLiquidGlass布尔字段，
偏好键同名，默认false；不复用enableBlur，不读取旧别名，不改Rust/FRB或数据库。
开关仅作用于悬浮底栏，保留普通底栏、皮肤、页签和书架双击行为；预热未就绪时使用
普通材质。液态模式独立消费既有bottomBarBlurSigma和bottomBarBlurTintOpacity，
不要求启用普通毛玻璃，也不将底色alpha二次相乘；普通模式保持原有材质定义。
第三方导航模型只存在于组件适配内部，应用仍传AppNavSpec和逻辑页签回调。

编写者：Codex + UI｜2026-10-18


## 隐私凭据Argon2依赖迁移（2026-10-18，实施前冻结）

升级argon2 0.5.3至0.6，外部密码接口、数据库表和PHC存储格式不变。
保留Argon2id v19、m=19456/t=2/p=1及32字节输出，使用系统随机数生成16字节盐；
新API显式传入原始盐，不再经SaltString编码后传入。升级前PHC哈希必须继续校验，
错误旧密码不改写或清除凭据；损坏PHC仍返回“隐私凭据损坏”。不批量重哈希或迁库。

编写者：Codex + Bridge｜2026-10-18


## PDF导出后端替换边界（2026-10-18，实施前冻结）

保留既有导出方法、格式、配置及返回字节，不变更FRB或数据库。以printpdf替换genpdf，
A4文本/图片导出保留标题、作者、简介、可选目录、章节另起页和长文续页；混合章节同时
保留正文与图片。允许行断点、具体页数和留白变化，不复刻旧版坐标或阅读器高级排版。
图片保持比例、不放大并适配内容区；字体缺字、字体不可用、下载/解码或PDF保存失败应
明确报错，不能静默丢字。测试使用受控字体，生产继续使用字体候选及LEGADO_PDF_FONT。
外部PDF导入继续使用已锁定lopdf 0.45，不为消重降级；仅在旧漏洞依赖确实退出后删豁免。

编写者：Codex + Bridge｜2026-10-18


## JS RAR安全停用边界（2026-10-18，实施前冻结）

移除legado-js中rar 0.4解压与临时文件读取实现，避免条目越界写入/截断和越界读取。
保留已注册unrarFile/getRarStringContent名称，调用立即抛出“JS RAR 功能暂不支持”异常，
不访问文件、不发请求、不创建目录；这两项不再计为已实现能力。
unArchiveFile及unzipFile别名遇RAR魔数同样抛出明确异常，不绕过停用边界；ZIP/7z保持。
getRarByteArrayContent当前未注册，本批不新增；桌面legado-book的unrar导入不改。
Android arm64/x86_64、Windows与iOS QuickJS均执行同一边界，不将停用误报为RAR兼容完成。
FRB函数签名/生成物、书源存储与数据库schema不变。

编写者：Codex + Bridge｜2026-10-18

## UI 材质参数边界（2026-10-18，实施前冻结）

本批仅调整 Flutter 普通界面设置窄接口，用户批准不处理旧编码兼容。
UiSettings / UiSettingsRepository / Notifier 的上下栏背景不透明度和模糊底色不透明度
统一为 0–1 double，采用明确的新字段和新偏好键；旧键不读取、迁移或双写。
模糊参数命名为 BlurSigma，使用 0–48 double；卡片圆角仍为 4–28 逻辑像素整数。
读取与保存共用有限值/范围规范，非法非有限值回退对应默认值；比例默认 1/1/0.73/0.40。
材质解析按模糊开关选取普通背景或模糊底色，组件不转换百分比或字节单位。
不透明度只影响背景，原色 alpha 作为颜色输入保留并乘以选定比例；显式透明色不强制着色。
普通背景比例为零不得关闭已启用的模糊，模糊 sigma 为零无需创建过滤器。
设置页只展示当前模式的参数，百分比仅为显示格式。按钮半透明材质定义集中，继续使用
现有玻璃实色回退；液态玻璃光学效果后置，不新增光学滤镜或更改悬浮底栏缩放。
Rust/FRB/数据库/备份内容与生成物不变，不需要 codegen。

编写者：Codex + UI｜2026-10-18

## Flutter错误边界（2026-10-18，实施前冻结）

领域层使用不引用FRB的AppException承载可见消息、操作上下文、原始cause及sourceStackTrace；
数据层将BridgeError转换为该类型，同步/Future/Stream入口共用转换规则并保留堆栈。
未知异常原样传播，不按消息文本猜测网络/取消分类，不重写现有取消令牌、结果类型和
订阅释放行为。既有RustApiException并入领域类型，不保留同义转发或第二套错误体系。
UI的errorMessage只读取领域错误，空白消息使用既有“未知错误”，普通异常沿用toString；
原有操作前缀仍由原调用点提供，不在转换器中重复添加。清理各feature的BridgeError判断
及dynamic.message探测；错误以外的生成类型不得以隐藏导出继续泄漏至UI。
Rust签名、FRB生成绑定、数据库、依赖和版本不变，不需要codegen。

编写者：Codex + Bridge/UI｜2026-10-18

## 非音频固定结果类型化（2026-10-18，实施前冻结）

本批原位替换三项正式FRB返回类型，不新增JSON兼容入口；同批生成两端绑定并重建原生库。

| 入口 | Rust DTO / Dart领域结果 | 字段与保持行为 |
|---|---|---|
| parseRule(content, rule, ruleType) | RuleParseResultDto / RuleParseResult | results: List<String>、count: u64→int；顺序/重复/Unicode保留，count为结果条数，规则前缀判定与失败异常保持 |
| importOldData(dir) | OldDataImportResultDto / OldDataImportResult | books/bookSources/replaceRules: u64→int、messages: List<String>；保留逐文件部分成功及消息顺序，不新增事务；目录预检查与失败异常保持 |
| webdavFullSync(connection, localBooks, localSources) | WebDavSyncResultDto / WebDavSyncResult | books/sources: String，仍是实际文档原文，不在边界反复编码外层JSON；上传/下载顺序、认证与错误保持 |

Dart窄接口、正式/Mock实现与消费层同步使用领域结果，不暴露生成DTO给UI；旧备份导入的
消息优先/计数提示不变。规则Mock仍不实现解析器，以原输入作为单条占位结果；WebDAV Mock
返回输入的两份文档而非虚构synced标志，不宣称发生远端同步。WebDAV配置/书架/书源文档、
脚本与正文继续使用字符串；不变更增量同步、音频/TTS、错误码、schema、依赖或版本。

编写者：Codex + Bridge｜2026-10-18

## 朗读收口边界（2026-10-18，实施前冻结）

移除临时诊断通道、关于页入口及A/B实验，保留正式播放、默认延迟准备和位置250ms节流。
移除仅供对照使用的startPlaylist.initialFollowing参数；初始装载单项，后续使用既有
appendPlaylist批量追加。保留正式控制器使用的合成任务whenIdle等待，不扩大资源释放改动。
追加前记录旧队尾身份，追加返回后重新核验会话、播放意图、已确认项目和
相邻后继；仅仍停在该旧队尾末尾时恢复，原生已换项不得重置。恢复提交新项后先通知旧项
完成、再通知新项起播，暂停/停止/换会话作废迟到恢复。
位置基点按转换的前后事件核验：新项已有更新的时间或位置基点时不额外等待播放事件；
新索引沿用旧基点时继续隔离，定时采样不能单独证明基点更新。
后台合成仅在未完成时可提升为前台；发布成功结果前转移租约所有权，后台已完成结果
不得作为前台有效租约交付。前台重新通过合成/缓存入口获取租约，不直接复用失效句柄。
Rust/FRB签名、存储格式及预合成设置不变。

编写者：Codex + UI｜2026-10-18

## 朗读播放转换确认边界（2026-10-17，实施前冻结）

currentPlaylistTag只表示本会话已确认项目。列表快照、追加
返回和位置采样不单独产生起播或完成；自然转换保留前后索引、稳定项目身份、事件时间与
会话/控制归属，核对合法相邻后继后才进入有序候选队列。追加期间保留真实连续转换，
暂态回退、恢复到已确认项及不一致事件不得写入完成集合。提交内部项目及完成去重状态后，
统一先通知旧项完成、再通知新项开始；每次外部回调后核对会话及控制有效性，停止/换会话
不得继续旧通知。主动定位仅凭应用定位操作或新会话接受目标，不把离开项视为自然完成。
队尾完成须由归属于已确认项目的有效completed事件确认；当前已入队音频耗尽不等于
整章结束，正式朗读仍以完整计划判定章末。暂停保留候选，恢复时
重新核对；停止清空候选与调度。位置250ms展示节流不承担转换判定。
正式队列补充合并异步唤醒，在执行时读取已确认项目和已准备/已提交范围；
起播回调不直接递归启动合成或追加。保留前方两项策略、预合成配置、缓存租约、默认延迟
准备及迟到追加后的身份复核。just_audio固定到用户指定的iOS尾部追加修复提交；
不修改Pub缓存源码或Rust/FRB。临时诊断和A/B对照已退役，历史证据保留在归档文档。

编写者：Codex + UI｜2026-10-17

## 朗读文件队列Dart边界（2026-10-17，实施前冻结）

`AudioPlaylistPlayer`只接收本地音频路径和稳定标签；`appendPlaylist`接收非空项目列表，
一次调用对应一次原生批量追加。空列表无操作。章节播放期间不删除历史来源，停止并清空
原生列表后才释放本章缓存租约；移除`discardPlayedItems`，不再保留播放中裁剪入口。
`FileReadAloudPlaylist`独立记录当前、已准备和已提交位置，只为当前项之后准备至多两项；
历史来源不占待播额度。已经就绪的项目在下一次事件循环批量提交，不等待未完成合成。
自然换项、主动定位、队列结束与位置采样分别处理，完成回调按会话和稳定标签去重；
位置事件不得推动队列。新项先发布段首归属，等待新位置基点再发布段内进度，避免混入旧项位置。
保留队尾迟到追加的二次状态检查，不依据追加前快照重播新项。暂停不清空队列，停止取消
待提交任务；追加失败的文件仍可能被原生引用，须停止确认后释放。Rust/FRB、预合成设置、
系统TTS、媒体会话和播放器准备参数不变。本边界不承诺iOS无缝或消除所有原生重播。

编写者：Codex + UI｜2026-10-17

## 引擎选择与书级偏好Dart边界（2026-10-17，实施前冻结）

ReadAloudSelectionService负责默认引擎、书级优先/全局回退、HTTP稳定ID与音色选择保存；
AudioBookPreferencesService负责书级配置读取、模式合并与倍速防抖，提供同一readConfig
串行修改入口供引擎/模式/倍速使用，不覆盖未修改字段。服务不持有Ref或AudioNotifier，
不保存第二份书籍/播放配置；经明确宿主端口读取唯一Book/AudioState、发布配置或调用
现有重启入口。播放参数生效和重新起播规则仍由AudioNotifier的现有公开方法执行。
保存使用发起书籍身份；切书后旧结果不替换当前书籍，销毁取消尚未执行的防抖任务。
现有ReadAloudSelectionRepository仅负责选择存取，BookshelfRepository及AudioBookService
保留数据访问/模式合并。默认种子、存储键、Rust/FRB、数据库、原生平台与版本不变。

编写者：Codex + UI｜2026-10-17

## 音频书播放Dart边界（2026-10-16，实施前冻结）

AudioBookController拥有音频书取址/可播章查找、进度恢复、片头片尾、流媒体回调、
自然完成/循环衔接及进度保存；依赖现有AudioBookService、播放设置仓储与共享播放器。
通过明确宿主端口读取唯一AudioState及全局播放标识，发布状态并请求章导航/定时边界、
系统朗读停止和媒体激活；不持有Riverpod Ref或AudioNotifier，不增加独立播放状态。
AudioNotifier保留模式分流、章导航、定时停止和现有公开API，书级偏好委托
AudioBookPreferencesService，引擎选择委托ReadAloudSelectionService，
MediaSessionCoordinator继续管理系统媒体展示，ReadAloudController继续管理朗读。
暂停/切章/停止写入调用时所属书章；销毁仅使用宿主提供的最终快照尽力保存一次，
不在销毁后读取Ref或状态。共享播放器由既有宿主/引擎清理路径停止及释放，不重复销毁。
保留回调书章归属、写库/显示节流、恢复和跳过规则；Rust/FRB、原生协议、存储及版本不变。

编写者：Codex + UI｜2026-10-16

## 系统媒体会话Dart边界（2026-10-16，实施前冻结）

MediaSessionCoordinator拥有媒体订阅、焦点恢复意图、系统展示时钟/节流、元数据签名、
封面身份及串行系统定位；通过明确宿主端口读取同一AudioState并执行播放/定位操作，
不持有Riverpod Ref或AudioNotifier，不复制书章和播放事实，不另建播放器或原生会话。
AudioNotifier保留全局播放标识、定时停止及原公开API，媒体操作委托同一协调器；
ReadAloudController继续拥有朗读单元和原文位置，系统进度从该位置派生。
AudioService保留原平台通信，复用MediaArtworkLoader、StreamAudioPlayer及单调时钟。
隐私变化、定时文字、暂停/恢复/停止与释放使用同一媒体协调路径，保留原按钮粒度、
串行定位与过期过滤。Rust/FRB、原生通道协议、数据库、设置、依赖及版本不变。

编写者：Codex + UI｜2026-10-16

## 朗读会话Dart边界（2026-10-16，实施前冻结）

ReadAloudController拥有段落单元、UTF-16原文偏移、分段/定位、段落完成和暂停恢复、
系统/HTTP/云端引擎及预合成衔接；仅通过明确的播放宿主端口读取当前AudioState、
共用播放标识，并发布播放状态和媒体/章级动作，不持有Riverpod Ref或AudioNotifier。
AudioNotifier保留书籍、模式、定时停止及现有对外API，音频书播放委托AudioBookController，
系统媒体会话委托MediaSessionCoordinator；展示值从朗读控制器派生，不镜像其段落索引、位置或引擎
运行状态。原ReadAloudSession继续作为
单次请求回调归属，控制器不重建引擎、队列或额外的全局会话计数。
复用ChapterContentService、原仓储/设置、原错误与降级策略；Rust/FRB与存储格式不变。

编写者：Codex + UI｜2026-10-16

## 纯正文加载Dart边界（2026-10-16，实施前冻结）

ChapterContentService仅依赖ReadingRepository与ChapterCacheRepository，read(bookUrl,
chapterIndex)返回阅读/朗读正文：按Rust当前扩展名白名单，本地书使用getChapterContent，
在线书使用getChapterContentFull；保留原路径还原、缓存、净化和平台拦截链路。
refresh显式接收bookUrl、chapterIndex、chapterUrl和sourceUrl，先清当前章缓存再抓取，
错误原样传播；是否允许刷新、空正文处理、页面旧正文及加载/播放状态由现有会话管理。
ReaderNotifier、阅读器预取/边界预览/反转和AudioNotifier正文读取/HTTP及云端预取共用
注入服务；会话去重、内存正文与预合成队列继续由原所有者管理，不建立第二份持久缓存。
漫画、音频书、视频、原始正文及书内搜索保留各自协议；Rust/FRB和存储格式不变。

编写者：Codex + Bridge｜2026-10-16

## 详情与目录加载Dart边界（2026-10-16，实施前冻结）

BookDetailService仅通过BookshelfRepository、ReadingRepository、BookSourceRepository和
BookSourceQueryService编排数据；页面不再组合本地/网络结果或决定查询写回路径。
BookDetailData保存当前书籍、目录、书源和在架事实；BookDetailNotifier负责加载/刷新状态，
同一页面展示和菜单读取同一份状态。BookMetadataPolicy及BookTypePolicy为不依赖Flutter的
纯规则，保留原BookOpenUtils中的取址、字段合并、类型判断；BookOpenUtils仅保留导航职责。
本地首屏与网络补全分开，已有目录地址允许并行；未入架在线查询不落库，已入架按原条件写回。
单项网络失败保留另一项成功结果与既有数据；刷新、离页后的过期结果不回写当前详情状态。
Rust/FRB函数、数据格式、存储、版本及现有界面保持不变，不引入旧数据迁移。

编写者：Codex + Bridge｜2026-10-16

## 应用依赖装配边界（2026-10-16，实施前冻结）

正式与Mock实现通过Bootstrap中的Riverpod装配注册，每个消费者获取实际需要的窄能力。
BookApi、RustApi及bookApiProvider在生产链路移除，不增加等价全能服务集合或运行时定位器。
共享Mock数据由专用内存数据对象拥有，领域实现仍复用现有契约；初始化继续由同一
RustBootstrap/AppRuntime执行，设置与主题刷新复用同一配置同步对象。封面、媒体、导入、
登录等辅助服务通过明确参数接入领域契约，不再接收根API。FFI函数、数据格式、存储位置、
应用版本及原业务行为不变。组合测试夹具仅用于显式装配和替身，不进入生产依赖链。

编写者：Codex + Bridge｜2026-10-16

## 配置与运行时Dart边界（2026-10-16，实施前冻结）

ConfigRepository承接getConfig/setConfig/deleteConfig/getAllConfigs；正式实现继续使用configGet/
configSet/configGetAll，空字符串读为null，删除仍写空字符串，枚举保留当前字段字符串化语义。
JSON只在数据层解释，异常向上传递；configSet返回false视为写入失败，不能发布保存成功。

Web服务设置（2026-10-21）：ServiceSettings.webAutoStart通过既有配置接口保存为
webServiceAutoStart字符串true/false，默认false；只表示下次冷启动是否自动启动服务。
运行开关仅取LocalServerService.getServerStatus的真实状态，不持久化；旧webService键
不读不写、不迁移。自动启动由应用作用域执行一次，失败保留配置并展示错误，前台恢复只刷新状态。
本次不改变Rust/FRB签名、服务协议或数据库结构。— Codex + UI
Mock复用原配置Map，其他Mock服务继续共享同一存储。
ConfigSettingsStorage改为依赖该仓储；普通设置只经AppSettingsService投影的类型化领域仓储
访问，不由页面直接拼键。朗读引擎与音色选择、TXT目录规则、源变量、视频进度分别归属领域，
复用原键、格式和TTL；令牌/凭据独立访问。存储介质不变，不引入历史兼容或数据库迁移。
运行时边界负责原初始化委托与引擎版本查询，复用现有RustBootstrap/RustRuntime及完整启动
顺序、失败策略和Mock资产预热。根BookApi移除六项方法及空配置part，只保留装配引用。
不修改Rust/FRB签名、生成物、数据库、依赖、原生平台、应用版本或UI布局。

编写者：Codex + Bridge｜2026-10-16

## 阅读处理与书源动作Dart边界（2026-10-16，实施前冻结）

ReadingContentService承接繁简转换读写及章级重复标题切换/读取/试算五项，直接复用当前FRB。
繁简转换保留Rust现有配置键与运行时生效方式，不添加Preferences副本；设置成功后按原路径
重新读取正文。重复标题开关仍按稳定bookUrl与章节索引持久化，试算及默认开启语义不变。
SourceActionService承接章节购买及书源回调两项。购买返回ChapterPurchaseResult，kind只允许
url/success/none，保留value，非法协议上抛，不伪造无需购买；购买成功仍由Rust失效缓存，UI重读。
回调返回SourceCallbackResult，保留invoked/jsTrue/raw/actions及handled=invoked&&jsTrue；
数据适配器注入既有dispatchActions，在返回之前回放一次平台动作，UI不重复回放。依照原有
FFI契约，只有未接管才执行默认分享/复制/清缓存/搜索；修正旧复制和清缓存忽略接管结果的路径，
并补齐分享/复制/清缓存遗漏的动作回放。注入的回放器异常上抛；既有平台回放器逐动作捕获错误
并继续队列的行为保留，各消费者保留原错误提示/回退策略。
正式/Mock共用应用装配和独立Provider；Mock繁简设置与根配置共享同一Map，章级状态隔离，
不在Mock执行真实转换/缓存失效/付费或JS动作。根七项移除，13→6；两个空discovery_cache
part删除，reader_data仅保留配置CRUD。不修改Rust、生成物、数据库、依赖、平台原生代码、
排版/翻页算法或应用版本。真实native/书源购买与平台动作验证后置。

编写者：Codex + Bridge｜2026-10-16

## 书源编辑与交互通道Dart边界（2026-10-16，实施前冻结）

BookSourceEditService承接cURL识别/双向转换、JS书源提取与语法检查五项；提取返回BookSource，
语法检查返回SourceSyntaxResult，传输JSON仅在数据层处理。无生产调用的时间戳写回Dart壳删除，
底层Rust/FRB保留。清除Cookie并入NetworkService，保留原域名归一和共享Cookie存储语义。
SourceLoginV2Service承接V2判定、动态表单和动作；已有SourceLoginService继续负责手动凭据会话。
输入使用BookSource与状态/表单对象，返回
LoginUiDescription/LoginActionResult。平台interceptResult在解码之前调用；保留close/login、
error、state的处理优先级。LoginV2Dialog仅依赖LoginV2Session；HTTP TTS既有SourceLoginSession
经适配器复用同一控件，不改其Rust操作、凭据存储或经典登录行为。
VerificationService接管验证码流/提交/取消三项，WebViewBridgeService接管WebView流/普通提交/
Cookie回流提交/取消四项。请求使用类型化模型；保留请求key、源身份、Cookie、执行参数与时间。
监听器固定订阅时服务实例，取消和回传都使用该实例；验证码按key去重/FIFO，WebView保留五个
并行槽位/FIFO。平台WebView执行通过独立执行器注入，字段映射在平台适配器，错误仍回传ERROR。
卸载后释放订阅并取消尚未处理请求，不再启动队列后续执行；不新增Rust句柄或重连协议。
验证码监听在应用builder外层使用显式Navigator挂载点并在首帧后弹窗；提交异常允许重试，
提交false不当作成功。JS提取/语法坏响应及缺少请求key的事件作为错误传播，不伪造成功结果。
正式/Mock通过独立Provider装配；Mock空流/未命中/无真实引擎的既有语义保持。
根十六活动方法及一项无调用壳移除，30→13；删除两个空sources part，不改Rust、生成物、
数据库、依赖、原生平台代码或应用版本。真实WebView/Cookie/验证码及网络验证后置。

编写者：Codex + Bridge｜2026-10-16

## 网络、规则执行与本地服务Dart边界（2026-10-16，实施前冻结）

NetworkService承接文本GET/POST、二进制GET与自定义hosts应用；请求继续使用Rust共享客户端，
返回HttpTextResponse/HttpBytesResponse，状态码、正文与最终URL由数据层解码。二进制请求头
由适配器编码，保留调用方显式超时、非2xx状态与错误传播；hosts仍接收现有编辑配置文本。
LocalServerService承接Web启动/停止/状态/端口保存及MCP端口应用，状态返回LocalServerStatus，
不把坏响应当作服务已停止。普通设置仍负责原配置读取与开关持久化，保留Web保活的原调用顺序。
RuleExecutionService承接规则解析、JS执行与引擎版本；正式JS执行注入原平台拦截器，版本探测
失败仍返回unknown。Mock不执行真实网络、规则或服务，仅保留既有内存语义；hosts、服务端口
和运行标记与根配置共享同一Map。三类能力均可经独立Provider替换。
导入与漫画下载直接消费类型化服务，删除旧bridge_http包装与数据层响应模型；书单URL导入
使用HTTP正文并检查状态码，不再将整个传输JSON误当书单。根十二方法与两个空media_format
part移除，42→30；不修改Rust、FRB生成物、数据库、依赖、平台接线或应用版本。
端口配置写入返回false时上抛失败，不提示引擎同步成功。书单输入对话框自身管理控制器，
避免提交后退出动画仍引用已释放对象；保留原布局、本地文件入口和取消行为。

编写者：Codex + Bridge｜2026-10-16

## 换源与封面搜索Dart边界（2026-10-16，实施前冻结）

SourceSwitchService负责七项换源能力；候选搜索返回List<SourceMatch>，流返回SourceSwitchBatch，
其matches为Rust排序后的完整快照，保留源名、错误、完成数、总数和终批标记。普通/预拉换源
分别调用原FRB并返回Book，bookUrl必须与请求的稳定主键一致，新源详情地址由originBookUrl承载。
取消调用发起换源的服务实例；评分/删除写入成功后更新展示。JSON仅在正式数据适配器处理，
坏结构不冒充空结果，换源失败不回退候选URL作为成功结果。Rust事务、预拉与取消协议保持。
CoverSearchService返回既有CoverCandidate，并保留按封面规则搜索URL列表的能力；
CoverRuleRepository接管外观设置中以方法引用传入的读取/保存/删除，使用CoverRule类型，保留
enabledCookieJar未展示字段。四项均有生产调用，随本批迁移，不删除底层或功能入口。
正式/Mock各自共享应用装配，保留空列表与错误语义；
Mock换源更新同一书架记录并保留进度，不宣称执行真实规则/目录事务或验证预拉缓存。
根十二项活动方法移除，54→42；Rust/FRB能力不删除。

编写者：Codex + Bridge｜2026-10-16

## 发现与书源执行Dart边界（2026-10-16，实施前冻结）

ExploreService负责分类、分页书籍、动作与UI脚本；返回现有ExploreCategory/SearchBook及
ExploreActionResult。ExploreStateRepository负责infoMap写入、默认值和Map<String,String>快照。
BookSourceQueryService按BookSource与实际pageUrl读取详情/目录，返回Book/List<BookChapter>；
目录另传稳定bookUrl作为归属主键，保留tocUrl/bookName提示，不因查询而落库。
BookSourceDebugService返回BookSourceDebugEvent流并取消既有全局调试；Dart仅管理订阅和当前实例。
应用装配与四个Provider共享正式/Mock实例。响应JSON和字段归一化在数据层，正式实现注入既有
平台interceptResult，不能移除WebView拦截。经典登录继续保留既有Session协议，只迁移动作求值入口。
根十一项活动方法和无消费者的webbookSearch/webbookContent旧壳移除，67→54；不改Rust/FRB、
数据库、发现分页、当前书源取址及书籍合并语义。

编写者：Codex + Bridge｜2026-10-16

## 自动任务Dart边界（2026-10-16，实施前冻结）

AutoTaskRepository负责规则列表、创建、更新、删除和按ID查询，输入/输出使用已有AutoTaskRule，
保留脚本、登录设置、排序及运行字段。AutoTaskService负责构建书籍任务、批量cron、导入准备、
执行、脚本规范化、刷新许可、书籍任务匹配和下次时间；执行接受协议对象和可选taskId，
适配原有两项FRB方法并返回AutoTaskExecutionResult，JSON编码/解码在数据层完成。
页面与调度器使用同一装配和窄Provider，调度器只接规则仓储、任务服务和开关读取回调。
根十四方法及空part移除，81→67。导入/启停/修改须保留完整规则；写入失败不计入导入成功。
保留当前调度和执行协议行为，既有协议/实际动作缺口单独登记；不改Rust/FRB/数据库或后台机制。

编写者：Codex + Bridge｜2026-10-16

## 媒体能力Dart边界（2026-10-16，实施前冻结）

BookImageRepository接管saveImageCache/getImageCache/fetchImageWithDecode，网络解码返回Uint8List，
保留缓存写失败false、读取失败null和在线回退；传输base64由数据层处理。
AudioCacheRepository接管四项缓存查询/清理，AudioCacheDownloadService接管下载/取消，
下载返回AudioCacheDownloadResult（installed/alreadyCached、path/sizeBytes/extension），
只接受现有installed/already_cached协议；取消含义及读面降级、写面上抛不变。
AudioBookService接管getAudioChapterMedia/getAudioProgress/saveAudioProgress/audioWithPlayMode，
取址返回AudioChapterMedia，进度返回毫秒整数（无记录0），播放模式传入/返回ReadConfig，
由适配器与现有Rust JSON协议转换。VideoDanmakuService复用VideoDanmakuItem及既有查询/解析降级。
正式/Mock共用应用装配，音频Mock下载与读面共享单一状态；不在Mock复制XML解析或真实播放器。
根十五项活动方法与无生产调用的audioResolvePlayBook旧包装移除，97→81，不保留转发壳。
不改Rust/FRB/数据库/取消机制和TTS生命周期；JSON坏响应不能变成写入成功，辅助增强仍按原契约降级。

编写者：Codex + Bridge｜2026-10-16

## 书籍内容Dart边界（2026-10-16，实施前冻结）

LocalBookService接管importLocalBook与cbzReadPage，导入仍返回Book，CBZ返回Uint8List，
base64及长度校验归数据层。BookArchiveService接管七项压缩包/编码能力：解包返回文件路径列表，
失败抛异常；编码检测返回EncodingDetection，转换返回输出路径。BookExportService接管
bookExportWithOptions与bookExportInfo，分别返回BookExportData和BookExportInfo，选项以
BookExportOptions传入，由适配器编码；已有ExportService只组合导出与WebDavService窄依赖。
ReviewService接管reviewGetSummary/reviewGetDetail/reviewGetReplies，返回ReviewSummary和
ReviewPage，ReviewDetailItem从Widget迁至共享模型；请求上下文由数据层编码，分页及字段不变。
应用装配注入共享正式/Mock实例，各领域Provider可独立替换；根十四项旧方法移除、不保留转发。

无生产消费者的scanLocalBooks/detectFormat/parseMetadata/parseTxt/parseEpub/exportBook、
txtSearch/txtSearchRegex/txtSearchInChapter/txtSearchCount及无选项bookExport十一项Dart旧壳
同时删除，底层Rust/FRB能力保留。合计根接口122→97；不重写TXT断章、EPUB解析或导出算法，
不新增FFI、生成绑定、数据库变更或历史兼容。Mock压缩包改为返回同一契约的解出路径，
导入后立即可从同一Mock书架读取；真实文件和网络行为须另行验证。

编写者：Codex + Bridge｜2026-10-16

## 同步 JS 的 UI 动作归属（2026-10-16，Rust 内部边界）

- 发现页、书源回调和 HTTP TTS 的动作只在本次同步 JS 求值作用域收集；
  嵌套作用域恢复外层，异常和 panic 均清理当前状态，不使用进程队列或全局刷新标志。
- 保留 actions 的 JSON、refreshExplore 布尔值、错误传播和调用协议；不新增 UI 动作或改 Flutter。
  书源回调/发现页动作登记实际工作，根关闭拒绝迟到返回及发现配置回写。

## 自定义 DNS 的实例归属（2026-10-16，Rust 内部边界）

- 正式 FFI/Web/JS/订阅/WebDAV 客户端接收所属 NetworkContext 的同一 hosts 能力，
  更新不修改其他引擎或独立工具的默认映射；保留原 JSON 解析、空值清除、持久化及恢复容忍。
- root/JS 客户端重建保留原 Cookie 罐；旧请求继续使用捕获的客户端和所属 resolver。
  外部工具的低层默认入口仍委托一个默认映射，不参与正式引擎装配，只有一份解析/查表算法。

## JS 缓存与并发原语的剩余实例边界（2026-10-16，Rust 内部边界）

- cache 的内存 LRU、磁盘目录与 singleFlight/lock/tick 注册表属于显式 JS 数据资源，
  同一引擎的 flow/VM/mainJs 共享，独立资源不能因 key 相同而读到对方缓存或计数。
- 保留原缓存 TTL、内存/磁盘分层、JSON/空值、写盘失败降级、锁等待及 tick 返回语义；
  不新增 JS 功能。显式注入目录仍持久保留；私有自动目录由实际数据所有者回收。
- 主题、阅读配置、模式与设备标识由同一宿主数据能力注入，保留未注入默认、空值不覆盖和现有字段。
- VM 回调只持数据资源，不持 VM 缓存、EngineContext 或任务凭据；缓存命中检查资源身份。
  FFI 的缓存目录 setter 仅委托所属宿主资源，公开 FRB 签名和生成绑定不变。

## 服务与朗读任务的实例生命周期（2026-10-16，Rust 内部边界）

- Web/MCP 的监听槽、启停锁及状态归属 FFI 宿主实例；Tokio runtime 仍由宿主提供，不进入 EngineContext。
  保留同步 bind 失败、全接口地址、鉴权、端口范围、配置持久化和既有 FRB/JSON/错误语义。
- 每次服务启动使用独立子任务组；停止先关闭该组，再等待监听任务释放端口。
  尚未退出的请求及阻塞工作继续登记，超时只记录未完成，不伪称已经全部停止；旧服务结束不能清除新服务状态。
- 请求、数据库及抓取阻塞任务持有原作用域凭据；不得把任务凭据存入 VM 缓存等长期资源。
  Web 和 MCP 的关闭互不取消，重启创建新子组，不重新打开数据库或网络实例。
- TTS 配置、来源变量、登录能力、缓存目录及限流在入口固定；来源回写使用原存储，根关闭后禁止迟到提交。
  取消不表示同步 JS 被强杀，实际任务退出前不能释放其登记；保持音频缓存格式和公开协议。

## 换源完整流程的实例与提交门控（2026-10-16，Rust 内部边界）

- 保留既有 FFI/JSON、来源过滤/排序、并发/超时、预拉详情与目录的部分命中、30000 总章数上限、
  稳定 bookUrl、变量合并、进度列保护与事务回滚；不新增 UI 功能或更改数据库格式。
- 搜索、增强、预拉缓存与 apply 使用同一宿主实例的数据能力；新搜索取代旧搜索并清空本实例缓存。
  旧会话不能写入新会话缓存、候选表或事件流；sink 关闭/入口丢弃后停止后置增强与发布。
- apply 拥有独立槽位；取消和事务提交共用短发布门控，取消返回后不能新进入旧事务。
  TOC 取消作用于原 WebBookState，提交后的下一章登记使用同一实例；不持 SQL 连接跨网络。
- 增强超时仍返回原候选，不让已超时工作迟到写入缓存。真实阻塞工作保留凭据至退出，
  子操作取消不影响兄弟候选/独立引擎；不强杀网络/JS，不用清空任务表冒充结束。

## 独立单源与精确搜索的任务凭据（2026-10-16，R5e1 内部边界）

- 保持既有 FFI/JSON、名称作者匹配、书源顺序、命中即停和错误文案；精搜不新增 searchBooks 落库。
  单源/精搜不占用或取消 UI 多源搜索槽位，拥有根任务组中的独立凭据。
- 精搜在入口加载固定存储的启用书源列表，各源沿用同一数据能力与任务凭据；异步步骤不重查根槽。
  单源常规错误仍按原规则处理，根取消须终止精搜，不伪装为继续查下一个来源或正常未命中。
- 取消/入口被丢弃后拒绝迟到结果；URL、登录校验、正文解析和 mainJs 阻塞闭包持有凭据直到真实退出。
  RAII 析构只请求取消，不同步等待阻塞工作；有界关闭如实反映在途寿命，不强杀 JS/CPU。
- 本子批不把独立单源监督等同于整个换源流程收口；预拉缓存、换源增强与原子提交仍需另组迁移。

## 书源校验与调试会话（2026-10-16，R5d 内部边界）

- FRB 签名、校验配置/顺序/逐步超时、调试分流、日志 JSON/状态码及时间戳保持不变。
  校验批次与调试各有独立实例槽位；新操作只替换同槽旧操作，不重置其他实例的取消状态。
- 入口固定原存储、网络、JS、登录、infoMap 与目录能力；调试各步不重新访问宿主根槽位。
  单次校验也登记任务；批量仍串行，不借机新增校验落库或改变校验算法。
- 日志回调属于原会话，终结只清理自身；取消后禁止迟到结果/日志/媒体副内容发布。
  sink 关闭在发布门控外取消；门控闭包不得重入取消或启动替代会话。
- 丢弃异步入口时取消自身；已经开始的阻塞调试保留凭据直到真实退出，关闭超时保留在途登记。
  不宣称能强杀阻塞网络/JS，不持根 EngineContext 跨请求；开库前原降级/错误流保持。
- 调试内部构造的直达章节补齐既有 WebChapter 必填 is_vip=false，避免正文抓取前反序列化失败；
  不放宽公共章节模型、不改外部 JSON。JS java.log 原本仅写 stderr，本组不新增日志注册或功能。

## 章节缓存下载实例与关闭（2026-10-16，R5c 内部边界）

- FRB 方法、缓存下载 JSON/持久快照字段、0-based 闭区间、失败章查询、重启续传语义不变。
  NEXT_TASK_ID/TASKS/RESTORED 改为宿主实例服务；同书创建与恢复串行装配，恢复读取失败可重试，不能静默占用恢复标志。
- 操作只持原 StorageContext、网络/JS/登录/infoMap/限流能力及任务凭据，不强持 EngineContext。
  状态表弱持执行凭据，终态查询不让任务永远登记在途；线程启动失败清理运行态并返回原错误类别。
- 抓取阶段不持 SQL/发布门控；在线与本地正文、字数回填及媒体副内容只在短提交门控内写入原库/原目录。
  取消先关提交入口并排空已进入的提交，再记录 cancelled 及原断点，不推进尚未提交的章节。
- 终态/断点快照是关闭收尾控制面，允许已登记 worker 在取消后完成该快照；凭据须覆盖到收尾真正退出。
  shutdown 返回成功后不再有该组 worker 的正文/快照写入，超时保留真实在途登记；不强杀网络/CPU 工作。
- 保存任务索引与 nextId 使用同一次短事务，不能并发丢索引；正文缓存仍存原文，在线缓存失败保持告警，
  本地写入错误仍计失败；净化只在读正文返回时执行，不改变下载内容。
- 文件库沿用相邻 ruleData，内存库数据目录按 StorageContext 独占且克隆共享寿命；只清理自己创建的临时目录，
  不删除文件库或显式覆盖目录。覆盖配置在装配时固定；前台网络正文同样登记根任务，复用原文算法并保留净化。
- 开库前进度/列表/取消继续返回既有 notFound/空/false，不提前标记已经恢复；新建仍要求数据库可用。
  已开库恢复 I/O 错误明确返回失败并允许下次重试，不伪装为没有任务。旧队列管理与真实缓存 worker 分别迁移。

## 搜索会话与任务归属（2026-10-16，R5b 内部边界）

- 保持搜索 FRB 方法、JSON/错误事件、单源超时、并发上限、软暂停和新搜索取代旧搜索的行为。
- 当前搜索槽位和会话编号由宿主实例持有；会话捕获所属控制器与根任务组能力，异步回调不重新发现当前会话/引擎。
  新会话在短锁内替换槽位，再在锁外取消旧会话；旧会话清理不能清除新会话。
- 搜索入口固定数据库、JS、登录/来源配置及限流能力；结果只落入原数据库。
  结果提交和事件发送进入任务发布门控，sink 关闭在门控外取消，避免重入锁。
- 派发的异步任务与 URL/正文/mainJs 阻塞工作保留任务凭据直到真正退出；取消收集不表示阻塞计算被强杀。
  根关闭拒绝新搜索并禁止迟到发布；保留尚未退出工作的登记，超时不能报告关闭成功。
- FFI 共享测试数据库改为每次进程运行独占创建，避免 Windows 进程号复用读到旧测试数据；
  只改测试路径分配，不改生产数据库、书签语义或测试串行锁。
- 无数据库时原有可降级读取/落库仍降级；失败不发布空的新引擎或偷偷切换来源。
  本批只迁移三类多源搜索会话，精搜/换源控制、下载、调试、服务等继续单独接线，不宣称整个 R5 已完成。

## 引擎任务作用域基础（2026-10-16，R5a 内部边界）

- 先建立实例任务组与登记能力，不在此子批改变任何 FRB/REST 签名、事件、取消/暂停协议、
  runtime 所有者、并发上限或线程优先级；正式搜索/下载/调试等接线在后续成组迁移。
- 引擎持有根任务组，宿主/操作创建子组；取消某组只影响自身与后代，独立引擎互不影响。
  关闭组后拒绝新登记；每个任务有独立取消位，子任务/阻塞工作持有的克隆凭据共同登记在途寿命。
- 发布回调和取消之间有同步门控；取消先置位，再等待已进入的发布段退出，返回后不允许新的发布。
  门控内只执行同步提交/事件步骤，不跨 await，不允许重入同一任务的取消/发布。
- shutdown 先取消并等待匹配的在途凭据释放；超时返回失败，不清空未结束任务伪造完成。
  不强杀 CPU 工作，取消不能替代等待。异步等待不阻塞 Tokio worker，不创建/销毁外部 runtime。
- 回调和任务仅持任务/数据能力，不捕获 EngineContext/VM 缓存根；引擎析构做取消兜底，
  可等待的关闭必须显式调用。开库前后任务资源保持同一身份；本批不宣称既有生产任务已受监督。

## Cookie 权威罐与写协调器收口（2026-10-16，R4c4 内部边界）

- 不改变 FRB/REST 导出、JSON、schema 或 Cookie 的域归属/按键合并协议。
  移除旧 JS GLOBAL_COOKIES、CookieSink、开库注册/回填及清除镜像钩子；
  VM、发现直发、音频缓存、正文和 WebView 只读同一次资源的权威 jar。
- CookieAccess 是不依赖 QuickJS 的窄数据能力；正式两档均由 NetworkContext 实现。
  JS 方法仍由原绑定校验入参；持久化失败保留 JS 已生效的内存值，原生带 Result 的入口保持原错误协议。
- 写协调器归属 CookieStore，由同罐的 HTTP 客户端、JS、预载与删除方共享，独立罐不共享保护域。
  获取协调器时释放 jar 读锁，再取得域/全量门控；不得持 jar 锁跨 SQL 或重入协调器。
  全清只清内容，不替换写协调器。只保留一个同步闭包算法，不新增全局注册槽或 TLS 引擎查找。
- 旧全局状态测试由实例真实 VM/HTTP/DB 回归及纯转换测试接替；仅删除不再需要的全局锁，
  仍操作 FFI 根数据库的测试继续串行，不把测试替身当作生产接线证据。
- 本子批完成不等于监督关闭已完成；R5/R6 的任务资源捕获和关闭协议继续单独推进。

## 间接下载与字体缓存实例归属（2026-10-16，R4c3 内部边界）

> 本节保留R4c3当时的接线记录。当前脚本下载、缓存、目录与字体行为按顶部2026-10-19契约执行；
> 旧错误降级、JSON字体句柄/磁盘字体及同URL网络串行规则已被覆盖，资源实例归属原则继续有效。

- 文件下载、cacheFile/importScript、字体与压缩包的网络读取使用所属 HttpResources，
  维持现有方法、超时、代理、重定向、返回结构与错误降级；不隐式加入新的来源 Header 或 CookieJar 开关。
- 真实 ZIP 回归暴露旧 get_bytes 的 UTF-8 有损中转；间接二进制下载改用现有 get_raw，
  保留原始字节，状态码和错误返回规则不变，不修改 legado-net 的公共接口。
- 字体句柄表、容量 4 的解析 LRU 和 URL 磁盘缓存归属同一资源；fontId 及 JS 参数不变。
  自动下载缓存使用资源私有临时目录，跨引擎不共享同 URL 的字节，资源释放时清理；
  不复用旧进程级临时缓存，显式文件读写和调用方指定的文件名仍遵循原沙箱路径语义。
- cacheFile/importScript 的自动缓存同样按资源隔离；正文 WebView 和请求头 Cookie 合并
  读取本次抓取依赖的权威 jar，不回退旧 JS 镜像。缺少 QuickJS 时仍使用注入客户端的 jar。
- 同 URL 的自动文件/字体并发加载在所属实例内串行；完整写入临时文件后发布缓存，
  失败移除临时文件，不把半份目标当成命中，不跨引擎共享锁。
- 删除已无生产消费者的进程四池、CookieStore/持久化/来源开关 first-wins 注册槽及开库注册步骤；
  协议测试改用逐用例实例。WebView Cookie 回流直接更新共享 jar，不再拆除连接池。
- 回调仅捕获网络和数据能力，不持有 EngineContext/VM 缓存；可通过真实网络和释放检查验证。
  旧 Cookie 镜像/sink、发现直发/音频缓存读取、全局写协调器及生命周期仍待成组迁移。

## JS 网络请求实例能力（2026-10-16，R4c2 内部接线）

- JsResources 持有实例 HttpResources，四组 JS 客户端、来源请求头和 Cookie 操作能力由 VM 显式捕获；
  正式宿主注入 NetworkContext 的同一 CookieStore/持久化能力，不再给这些 VM 注册 first-wins 全局钩子。
- 每次 JS 网络调用在同步入口固定来源标识、enabledCookieJar 和来源请求头；异步请求/批量子任务只使用
  此次不可变快照，不在 await 后查询当前来源。URL 归一、超时、代理、重定向和返回格式保持。
- VM 的 Cookie API 直接读写共享 jar，不维护第二份 JS Cookie 镜像；域名归属、按键合并及持久化失败
  不阻断 JS 的行为保持。默认独立 VM 自建内存能力，不能隐式读取正式宿主或其他独立 VM。
- 缓存身份包含 HttpResources 身份；开库前后接续同一能力。回调不得捕获 VM、缓存或 EngineContext，
  必须验证实际网络与资源释放。间接下载/字体/jsLib 等调用方及旧工具 API 的删除逐项闭环后再宣布整体完成。
- URL 映射 jsLib 的网络读取和 64 项内存缓存一并归属 HttpResources，保留 md5(URL) 键、无 TTL、
  大小/超时限制和失败台账语义；同 URL 不跨独立引擎复用内容，不引入磁盘迁移。
- WebView 桥接载荷的 Cookie 由本 VM 的共享罐提供，载荷字段、来源键与回调协议不变；
  空 URL 仍不携带 Cookie，不再读取旧 JS 镜像。

## Cookie 写通道实例能力（2026-10-16，R4c 内部边界）

- 新写通道由所属 Cookie 资源持有；逐域、多域和全量操作使用同步闭包，不能返回伪造的
  `'static` 锁守卫，也不把引擎选择放在线程局部状态。临界区不得重入此能力或跨异步等待。
- 同一实例的同域写入、删除和回填串行；不同域可并发；全清屏障同时覆盖已存在和新注册的域。
  域锁只保留弱索引，最后一个操作结束后可释放；独立实例不共享保护域。
- 基础能力先旁路验证，随后 JS/HTTP/FFI/Web 写方成组切换；在完成成组切换之前保留原生产锁，
  不让旧 JS 写方和新 HTTP 写方分别使用两套锁而失去互斥。对外 Cookie 语义与格式不变。
- 切换分两步：先由所有既有写方成组使用闭包 API，保护域仍由原宿主共同持有；
  再与 JS Cookie/HTTP 资源的实例注入一起迁移协调器所有权。第一步不等于已经完成实例隔离。
- 同步原语在 legado-core 维护唯一算法，legado-net 提供 Cookie 命名适配；
  未启用 QuickJS 的 JS 档不因此引入网络或 QuickJS 依赖。

## 发现 infoMap 实例服务（2026-10-16，R4b2i 内部边界）

- FFI/REST 签名、发现控件和 `infoMap_<sourceUrl>` JSON 持久化格式不变。
- EngineContext 持有 SourceInfoMap，FFI 与同进程 Web 的 setup 快照消费同一服务；
  开库前写入沿用同一实例，按键覆盖数据库旧值，未修改的键从本次数据库补齐。
- snapshot、put、ensure_default 的回填及读改写由服务串行协调，状态锁不跨 SQL；
  持久化失败仍以本实例内存值为准。独立引擎不共享表，回调只捕获数据能力。
- 本批保留现有 JS infoMap 代理和事后逐键写回语义，不宣称已完成代理原生化或 Cookie/任务迁移。



## 主书源显式变量流程（2026-10-16，R4b2h）

- FRB/REST、JSON、schema 及生成绑定不变。正式宿主不再使用进程级当前 flow；JS 资源默认拥有实例变量能力，调用入口显式建立来源/用途/查询或来源/书籍的结构化流程身份。
- 搜索、发现、登录/回调及一般规则入口使用来源能力；同来源同查询分页可延续流程，不同查询或来源不得串临时变量。详情、目录和正文使用来源＋真实书籍锚点，稳定主键与实际取址点维持现有职责，不把目录地址猜作书籍地址。
- 请求头、URL、loginCheck、内容规则、分页、mainJs、book 绑定构造及写回使用同次资源。普通变量与持久 cache 留在实例存储，临时值在显式流程；没有旧全局值兜底。
- book overlay 按来源/书籍读取同一能力；详情→目录→正文可连续读写，不因切到另一本书清除仍在途句柄。深链缺少书籍映射时使用来源＋章节的独立流程，不读取上次书籍，也不伪造 bookUrl。
- 删除 begin_book_flow、全局变量表/flow 槽及旧变量适配模块；独立 QuickJsEngine/原生API注册也创建自己的变量能力，不再隐式共享进程表。变量绑定模块只负责VM按次能力守卫，不保留旧模式。旧全局算法测试由实例/流程及真实链路回归接替，不把测试替身作为正式链路验收。
- 完整链路、交错来源/书籍、URL相同、原生/Web共享及default/quickjs两档分别验证；未验证设备/native/性能不据此宣称完成。

编写者：Codex｜2026-10-16

## JS 登录键直连实例服务（2026-10-16，R4b2g 内部边界）

- FRB/REST、JSON、schema 与缓存键不变。JS 层定义仅含数据操作的 SourceLoginStore 能力，由 engine 的 SourceLoginCache 实现；VM/缓存仅捕获此能力，不捕获 EngineContext。
- 注入能力的 VM 对 loginHeader_<sourceUrl>、userInfo_<sourceUrl> 的裸键读取、写入与删除直接访问该服务，缺失不回退旧全局表。缓存 VM、fresh/词法回退、mainJs 与 FFI 登录/发现入口必须一致接线；普通变量及书籍 flow 本批不切换。
- setup 的历史登录快照不得写回已注入服务，认证预置读取执行时服务值。移除 FFI 事后从旧 JS 表复制登录值的步骤，避免覆盖较新的原生命令值或复活已删除登录态；JS 脚本错误前已经完成的登录写入仍保留。
- clearVariables 仅清理变量能力；实例登录服务属于持久缓存，删除登录态使用原有 removeLoginHeader/removeLoginInfo，不能因变量清理而删用户凭据。未注入宿主能力的独立 JS 构造保留已有变量语义，不作为正式应用路径的兜底。
- 缓存身份须包含登录服务身份；同一缓存不得复用其他服务的 VM。开库前后沿用同一服务，独立实例不串读，回调释放不得保活根实例。

编写者：Codex｜2026-10-16

## 来源登录缓存的实例归属（2026-10-16，R4b2f 原生宿主边界）

- FRB/REST、JSON、缓存键及 schema 保持不变。登录头 `loginHeader_<sourceUrl>` 与用户信息 `userInfo_<sourceUrl>` 由引擎拥有的 SourceLoginCache 统一读写，FFI 与同引擎 Web 抓取共用同一实例；独立引擎不共享内存或持久化后端。
- 开库前可读写本实例内存；首次成功建库接续同一对象，早期写入及删除按原键写回绑定数据库，已有内存值优先。后端只绑定一次，旧服务不得重定向到其他实例数据库。
- 缓存回填、写入、删除和绑定按本服务操作门控协调；内存命中不等 SQL，数据锁不跨数据库 I/O。删除失败仍保留当前实例的删除记录，避免再次读库复活旧值；数据库写入失败继续沿用仅内存降级，不更改调用方错误协议。数据库未命中的值不负缓存，之后写入的缓存行仍可发现。
- FFI 抓取的登录头与 setup 回调捕获本次 SourceLoginCache，后续执行不重新发现全局登录服务。
- Web 的 source setup 先释放 infoMap 查询借用，再通过同一登录服务取登录值，不能持有数据库连接嵌套调用此服务。服务只持有数据与 StorageContext，不持有 VM、宿主或 EngineContext。
- 本批不切换 JS 的旧变量写入/同步来源；仍使用旧 JS 表的入口统一写回此服务。正式主书源变量、登录脚本与 JS 删除同步需要后续成组迁移，不能据此声称完整 JS 登录隔离或引擎热重启已完成。

编写者：Codex｜2026-10-16

## 主书源元信息的来源键（2026-10-16，R4b2e 接线前置边界）

- 不改 FRB/REST、JSON、数据库与生成绑定。共享 fetcher 的详情元信息写入和读取必须显式携带来源 URL，以结构化的（来源 URL，书籍 URL）为缓存键，不允许回退查询其他来源。
- 详情→目录→章节反查→正文绑定，以及换源 overlay 锚点解析均使用同一来源。稳定书籍主键和实际目录取址点的现有语义不变，不将 tocUrl 当成 bookUrl。
- 缓存仍在同一 EngineContext 内跨宿主共享；保留原有容量、非空字段合并、variable 的 DB 优先及缺失降级规则。本批不迁移页面响应缓存的请求身份，也不声称正式书源变量/登录链已成组切换。

编写者：Codex｜2026-10-16

## 书籍流程身份与变量锚点分离（2026-10-16，R4b2d 能力边界）

- 不改变 FRB/REST、数据库字段、持久化书籍 URL 或生成绑定。本子批先完善显式书籍能力；未完成全部消费者接线前不切换正式书源链，也不声称已隔离。
- 普通 flow 名仅定位会话，不隐式充当 bookUrl。显式书籍 flow 以来源 URL＋书籍 URL 为身份，独立携带真实 bookUrl 锚点；来源和书籍以结构化键保存，不能靠分隔符拼接猜测。
- 同一引擎内，书籍变量覆盖按来源＋bookUrl 保存并跨流程保留；type/reverseToc 只属于该书籍的流程，进入另一本书不清除在途句柄。显式书籍能力不回退读取旧全局或裸 bookVar 键。规则读取顺序仍为本地→flow→引擎裸键→该来源该书籍的变量覆盖。
- 无 QuickJS 的规则、上下文和目录适配器也消费显式变量读者；目录共享上下文保留读者而非空占位，仍不创建 VM。未绑定显式视图的消费者保持原读者。
- JS 的 book 读写桥、构造期覆盖快照与解析器读者必须消费同一显式能力。缓存 VM 的已保存回调跟随每次执行绑定；主书源、登录缓存及直接规则入口要在后续成组迁移，不能只替换读取侧。
- clearVariables 清除此引擎的持久裸键及书籍变量，并只清理本次 flow 的临时值/type/reverseToc；不删除其他在途 flow 的会话覆盖或其他引擎数据。原有删除书籍变量无 tombstone 的行为不在此批更改。

编写者：Codex｜2026-10-16

## 缓存 VM 的每次执行流程绑定（2026-10-16，R4b2c 边界）

- FRB/REST 导出、JSON 与数据库不变。VariableScope 可随执行器/mainJs 的每次调用显式传入，VM 内宿主回调读取该 VM 的变量能力，不永久捕获首次请求。
- 绑定与 JS 求值在同一 QuickJS 上下文锁内执行；普通、compiled 和字节求值的执行预算在取得上下文锁后开始，排队调用不能重置在途预算；成功、脚本错误与 panic 都恢复原能力。不使用线程局部值跨 await，也不把整个 VM/JsResources 捕获进回调。
- VM 初始化脚本、缓存命中执行、词法回退及带参数 mainJs 调用使用同次能力；脚本保存的原生函数引用在后续调用仍读取本次 flow。
- 保留已有默认构造的旧入口至其消费者成组迁移。新缓存条目校验变量存储身份，同一缓存不能把不同存储的 VM 误作同一条目。
- 本子批完善缓存执行与显式资源视图，并先接入字典 URL/showRule 的真实缓存路径；规则标签与查询词共同定位 flow，原有网络请求、解析结果及无 JS 降级保持。未切换的书源绑定覆盖层/登录缓存不得据此记为已实例隔离；两宿主真实书籍变量链由后续接线验证。

编写者：Codex｜2026-10-16

## JS 变量与显式流程归属（2026-10-16，R4b2b 能力及分批接线）

- 不修改 FRB/REST 签名、JSON、数据库或生成物。提供独立 VariableStore 与显式流程能力；JsResources 已持有新数据存储，FFI HTTP TTS 由其注入，内存宿主则各自拥有。当前只接入 HTTP TTS 路径，主书源仍待切换，不宣称已隔离。
- 新能力的流程由不可变的显式句柄携带，不通过“当前 flow”单槽发现；注册式同书键可跨调用复用，启动另一流程不清理在途句柄。TTS 每次合成使用 fresh_flow，响应校验、重试及 URL 重算继续持有原句柄。
- flow 注册表保留最近 32 条强引用并用 Weak 查找仍在途的流程；逐出不撤销句柄，同键在途重入不分叉。持久裸键/cache 属于宿主存储并跨调用保留，flow 值只属于各自会话；此 32 条规模是本批新流程保留上限，后续书源切换仍须核对生命周期。
- 保留规则本地→flow→持久裸键→本书 bookVar 的读取顺序；未绑定 flow 的直接执行只读写自身引擎裸键。不同书籍 flow 不共用会话值。
- 后续缓存 VM 切换的要求：初始化和每次执行均使用本次变量句柄；native 回调不持有 JsResources/EngineContext，不把第一次请求永久绑定到缓存 VM。
- Cookie、网络 first-wins 钩子和任务关闭仍按后续批次迁移；不能以变量隔离代替这些能力的验证。
- 分批接线：先让独立构造的 HTTP TTS 执行器实际使用新变量能力，保留旧书源入口至缓存 VM 和书籍绑定可同时迁移；新旧路径均使用同一存取实现。未迁移消费者不得记为已隔离。

编写者：Codex｜2026-10-16

## 规则解析器变量读取归属（2026-10-16，R4b2a 边界）

- 不修改 FRB/REST 参数、JSON、错误或事件。解析器移除进程级读取器注册函数与槽位。
- AnalyzeRule 使用实例 VariableReader，或委托当前 JsExecutor 的变量读取能力；没有注入能力的独立解析器不读取其他调用的全局兜底。子解析器继承同一读取器，原本地变量/绑定优先级保持。
- 现有书源、字典、目录、调试、封面与段评规则入口显式接入当前变量链；段评使用已配置解析器并向各条目传递读者，条目本地变量仍独立；无 QuickJS 档保留原有直接变量读取能力，JS 执行能力仍关闭。
- JS 变量表和 flow 仍由后续子批迁移；本批只解除解析器与进程级注册槽位的耦合，不宣称整个 JS 已实例隔离。

编写者：Codex｜2026-10-16

## Rust JS VM 缓存归属（2026-10-16，R4b1 边界）

- FFI/REST 签名、JSON、错误和事件不变，不重新生成 FRB 绑定。
- QuickJS 非词法脚本及 mainJs 的 VM 缓存由 JsResources 持有，EngineContext 经 FetcherDeps 注入；同引擎连续调用共享，独立引擎及独立构造的执行器不隐式共享。
- 保留缓存容量、LRU、脚本/配置变化失效、词法重声明回退、沙箱与错误传播规则。重声明识别记录同样属于本实例，其他实例的错误不能强制本实例走新 VM。无 quickjs 档不创建 VM，保持现有能力降级。
- 初始化状态改用具名 CachedEngine 返回；jsLib 失败原因随本实例结果返回，不从进程台账回读另一实例的同名记录。诊断台账暂仍为进程级，不作为异常数据来源。
- FFI 开库前持有的 JS 缓存沿用至开库后。预校验与实际规则执行使用同一资源；原本明确新建 VM 的执行入口仍新建，不扩大缓存使用范围。
- 本批仅迁移 VM 缓存所有权，不宣称 JS 变量、Cookie、flow、下载库缓存或所有宿主回调已隔离；这些状态在后续子批继续处理。

编写者：Codex｜2026-10-16

## Rust 引擎抓取缓存归属（2026-10-16，R4a 边界）

- FFI/REST 导出、JSON、错误和事件不变，不修改 FRB 生成物。
- 详情/目录 HTML、BookMeta、章节所属书和下一章映射及目录刷新代数由 EngineContext 持有，经 FetcherDeps 显式传入；同引擎两宿主共享，独立引擎不共享。
- 保留原有缓存 TTL、容量、复合键、回退、合并及淘汰规则；未打开数据库的 FFI 抓取沿用根持有者的同一缓存实例，开库不丢失早期状态。
- 本批只迁移缓存与代数的所有权，不改变同引擎目录刷新取消规则；JS 全局表、flow 和 VM 注入继续由 R4 后续子批处理，不据此宣称多引擎 JS 已隔离。

编写者：Codex｜2026-10-16


## Rust 引擎网络与 Cookie 收敛（2026-10-16，R3 边界）

- 不改变 FFI/REST/MCP 的签名、JSON、错误与事件协议；客户端配置、CookieJar 开关和域名归一规则保持。
- 同一 EngineContext 的 FFI/Web 抓取复用网络客户端、内存 CookieStore 和绑定本实例数据库的持久化后端；旧请求不动态查找其他实例的库。
- 数据库打开前仍可发起网络请求；打开成功后沿用早期网络实例及内存 Cookie，既有客户端也能写入已绑定数据库。
- Cookie 合并、删除、全清与客户端重建回填共用协调规则，数据库等待不持有 jar/客户端槽位锁；配置重建失败保留可用客户端，旧构造不得覆盖更新的配置。
- MCP 清除 Cookie 同时清除当前引擎共享 jar，防止下次请求继续发送已清 Cookie。JS first-wins 钩子本批绑定当前网络实例，多引擎 JS 隔离仍属 R4。
- 内部 CookiePersistence 增加可协调的回填方法，原有后端沿用默认实现；不改 FRB 生成输入。
- reqwest 不再另建隐藏 jar：重定向链和最终响应共用引擎 jar；整个请求作用域遵守 CookieJar 写入许可，修复清除后仍发送旧 Cookie 及关闭写入时被隐藏 jar 绕过的问题。
- 本节记录 R3 过渡接线；R4c4 已删除 CookieSink 与第二份 JS 镜像，正式 JS 直接更新实例权威 jar，仅将本次变更键交给持久化合并，避免旧快照覆盖 HTTP 新值。JS 对外 setCookie 签名不变。

编写者：Codex｜2026-10-16


## Rust 引擎 Server/限流收敛（2026-10-16，R2 边界）

- Web、MCP 与 FFI 的导出签名、路径、请求/响应字段、错误码和事件协议不变。
- 内嵌 Web/MCP 直接接收 FFI 当前的 EngineContext；独立服务自行构造实例，不再长期借出池连接。
- 同一引擎的 FFI/REST 抓取共用书源 concurrentRate 窗口，源保存/导入成功后刷新同一注册表；失败不刷新，不改变空/0/非法值规则。
- FFI 在数据库初始化前可取得原有的限流能力，成功打开数据库后继续使用该实例，不丢已有窗口。
- SQLite 异步调用在受限的阻塞任务中取连接并完成操作；事务不跨连接或网络等待。同步抓取回调直接使用同一实例的 storage，不再因异步单连接互斥锁竞争而返回无值。
- 网络客户端、Cookie 合并/删除与 JS 全局钩子的统一仍由 R3/R4 处理；本批不声称这些状态已隔离。

编写者：Codex｜2026-10-16


## Rust 引擎数据库上下文收敛（2026-10-16，R1 边界）

- `dbOpen(path)` 的导出签名、返回错误类型和调用方接线不变，不重新生成 FRB 绑定。
- 第一次成功打开的数据库保持生效；后续重复调用仍成功返回，不切库、不重跑迁移或初始化钩子。
- 文件身份与连接池在成功建库后一起发布；打开失败时不登记无效路径，之后可重试。
- 路径取自已打开的 SQLite 主连接，内存库没有文件路径；相对本地书路径继续相对实际库的父目录解析。
- 内部改由 `legado-engine::EngineContext` 持有数据库能力；本批不改 Cookie、网络、任务、Server 路由或数据库结构，不提供热切库/关闭新 API。
- 初始化后既有 Cookie 注册、customHosts/MCP 配置恢复顺序保持。并发重复初始化由宿主门控串行化，配置钩子只运行一次。

编写者：Codex｜2026-10-16


## 媒体进度与通知导航增量（2026-10-15，实施前冻结）

用户授权正文/音频书系统进度、锁屏拖动、通知返回播放页面和前后按钮切段/切章；不增加旧系统通知兼容分支，不改变Rust/FRB或数据库。

- 现有`legado/media_session`增加`updateProgress{mediaId,sessionToken,chapterIndex,state,position,duration,speed,canSeek,hasPrevious,hasNext,isStream}`。时间单位为毫秒；音频书使用真实位置、时长与播放倍率，正文使用上游4字/秒乘语速的章节时间轴，向系统发布的正文时间轴播放倍率为1。无有效时长不声明seek；原生只接受当前元数据身份，文字/封面更新不得丢失时间轴。
- 原生`onSeekTo{mediaId,sessionToken,chapterIndex,position}`经强类型事件交由当前AudioNotifier处理；拒绝旧书/旧章/旧会话，暂停定位保持暂停，正文复用原文UTF-16/字形簇安全定位，音频书复用现有播放器seek。停止/释放撤销身份与能力。
- `onOpenPlayback{mediaId,sessionToken,chapterIndex}`及`takePendingOpen`交由应用导航层处理；原生通知使用当前启用图标对应Activity的PendingIntent，热启动走onNewIntent，启动期间保留待取事件。导航等待欢迎页退出，当前会话校验后复用已有播放页，不启动第二份播放。失效通知只打开应用，不恢复已结束朗读。
- `ReadAloudSettings.mediaButtonPerNext`（持久化键同名）默认true保持现有切章；false时正文媒体前后按钮切换当前划分单元，音频书始终切章。普通设置沿用唯一Repository，保存失败不发布新值。
- 本批不增加通知定时/独立停止按钮或媒体兼容模式设置；iOS接通真实时间轴与changePlaybackPositionCommand，实际锁屏验证仍需要Apple平台。

编写者：Codex + Bridge｜2026-10-15

## 媒体通知本地通道（2026-10-15，实施前冻结）

用户授权通知封面及标题调整，沿用 `legado/media_session`，不改变 Rust/FRB 方法或计数。

- `updateMetadata{mediaId: String, sessionToken: int, title: String, artist: String, album: String, timerText: String}`：title 为书名，artist 为章节名，album 为书名；不含“正在朗读/播放”前缀。timerText 为独立定时剩余说明，不拼入书名/章节。Android 通知主副标题及系统媒体标题语义一致，定时放 subText；iOS 定时保留独立 comment，是否显示由系统决定。
- `updateArtwork{mediaId: String, sessionToken: int, artworkBytes: Uint8List?}`：PNG 缩略图最长边384px、大小不超过1MiB；null 明确清除。同媒体标识与token的文字更新保留封面，身份变化先清除旧图。只有与当前元数据身份完全一致才接受图片；停止/释放清空身份，拒绝迟到图片，不创建通知或恢复播放。
- Flutter 先推文字，后台加载封面；使用已有封面缓存/复合URL与书源解密，不由原生重新请求。切书、停播、销毁和隐私遮蔽使旧加载失效；无图/失败使用默认封面。文字和图片分别去重，切章及倒计时不重复发送图片。
- mediaId仅用于现有通道内部归属检查，不将书籍URL额外发布为系统媒体标识。

编写者：Codex + Bridge｜2026-10-15

## 隐私访问增量契约（2026-10-14，实施前冻结）

平台增量：`legado/privacy` 提供 `capabilities`（biometric: available/notEnrolled/noHardware/unavailable，enrolled: bool）、`enrollBiometric`、`authenticateBiometric`、`clearBiometric`、`permissions`、`openNotificationSettings`、Android 专属 `openBatterySettings`。Android 使用认证绑定的 Keystore Cipher，iOS 使用 biometryCurrentSet Keychain 项；成功须完成实际加密/解密或受保护项读取。取消返回 false，不授予权限。改密/清密撤销快捷凭据；平台不支持如实返回，不允许设备 PIN 替代应用密码。隐私设置增加 `biometricEnabled`，开关只在系统认证及保存均成功后开启。

- 用户授权继续隐私功能，Firebase 后置。Book 与 BookGroup JSON 增加 `isPrivate: bool`，默认 false；书籍单独标记或所属私密分组均视为私密。既有读写须保留标记，分组增改桥接增加可空 `isPrivate` 参数，空值保留既有值。
- 新增 `privacyHasPassword()`、`privacyVerifyPassword(password)`、`privacySetPassword(currentPassword, password)`；修改/清除已有凭据必须验证旧密码，失败不写入。凭据由 Rust 独立本地表保存随机盐 Argon2id 摘要，不返回明文/摘要，不复用既有 Web/备份密码。
- 两个 `isPrivate` 列及凭据表由初始化 DDL 与既有幂等补列入口创建；本批不占用其他 worktree 正在开发的版本迁移编号。当前数据库打开后即获得加法式结构，应用版本不变。
- Flutter 内部统一隐私设置、会话授权、后台宽限与书籍判定；设置验证只允许访问设置，启动验证与目标授权分开。默认关闭，关掉保留标记及凭据；进程授权不落盘。密码清除时同步关闭隐私设置。
- 本轮先验收密码闭环；平台生物识别、通知/电池权限通过独立平台能力接线后验收，不展示无实际效果的开关。沿用原版功能及用户已确认的三组界面设计。

编写者：Codex + Bridge｜2026-10-14

**日期**: 2026-08-01
**版本**: v1.0
**维护人**: Legado 开发团队

**更新记录**：

| 日期 | 内容 |
|------|------|
| 2026-10-16 | **自动任务Dart边界冻结**：五项CRUD迁入AutoTaskRepository，九项计算/执行迁入AutoTaskService（执行合并为可选taskId），复用完整AutoTaskRule，结果类型化、编解码归数据层。管理页、调试和调度器使用窄依赖；编辑保留ID及完整字段，导入失败不计成功。根十四项及空part移除，81→67；Rust/FRB及实际执行协议不变，业务缺口单列Active。 |
| 2026-10-16 | **媒体Dart边界冻结**：图片三项迁入BookImageRepository，音频缓存四项及下载/取消两项分别迁入AudioCacheRepository和AudioCacheDownloadService；音频取址/进度/模式四项迁入AudioBookService，弹幕两项迁入VideoDanmakuService。图片返回字节，音频返回类型化结果/毫秒整数/ReadConfig，数据层处理JSON；根旧十五项及无消费者的audioResolvePlayBook包装移除，97→81。Rust/FRB、数据库及播放生命周期不变。 |
| 2026-10-16 | **全局缓存与数据库维护Dart边界冻结**：CacheRepository接管五项全局统计与清理，DatabaseMaintenanceService接管VACUUM，CacheService返回CacheStats；设置页使用窄Provider，统计失败可重试、清理拒绝不报成功，根BookApi 128→122。Rust/FRB和实际缓存清理范围不变，见§2.16。 |
| 2026-10-16 | **应用日志Dart边界冻结**：appLog五项迁入AppLogRepository，列表返回共享AppLogEntry，JSON解码归数据层；正式/Mock实现共用应用装配实例，搜索与换源写入失败不阻断业务。根旧五项移除，BookApi 133→128；Rust/FRB及崩溃采集备份不变，见§2.38。 |
| 2026-10-16 | **词典Dart边界冻结**：dictLookup迁入DictionaryService，返回DictEntry；七项规则访问迁入DictRuleRepository，列表返回补齐id的DictRule，排序接受ID列表。查询、管理和关联导入统一使用现有dictRules表，删除config:dict_rules第二份权威及版本标记，不迁移旧配置。BookApi 141→133，Rust/FRB/数据库不变，见§2.45与§3词典说明。 |
| 2026-10-16 | **正文标注与高亮规则Dart边界冻结**：标注七项与规则四项分别迁入HighlightRepository和HighlightRuleRepository，列表返回共享模型、保存传实体，JSON由数据层处理；规则保留sortOrder/timeoutMillisecond。根旧十一项移除，BookApi 152→141；Rust/FRB签名及数据库不变，见§2.36。 |
| 2026-10-16 | **规则订阅Dart边界冻结**：五项配置访问迁入RuleSubRepository，两项检查/应用迁入RuleSubService；列表使用已有RuleSub，保存与响应JSON解码归数据层，更新返回类型化结果。根旧七项移除，BookApi 159→152；现有Rust/FRB签名、数据库及更新能力不变，见§2.39。 |
| 2026-10-16 | **替换规则Dart边界冻结**：六项配置访问迁入ReplaceRuleRepository，两项预览/书源作用域替换迁入ReplaceRuleService；正式实现直接复用既有FRB，根旧八项移除，BookApi 167→159。保留现有字段映射、错误及排序行为；现有FRB更新缺少scope/sortOrder，排序与范围更新能力缺口独立后续处理，本批不修改Rust导出、生成绑定或数据库，见§2.8。 |
| 2026-10-16 | **RSS Dart边界冻结**：源八项、文章两项、已读七项、收藏四项分别迁入RssSourceRepository、RssArticleRepository、RssReadRecordRepository、RssStarRepository；已读列表返回已有RssReadRecordRow，JSON解码集中于数据层。RSS启停使用rssUpdateSource更新原RSS实体的enabled，不再调用书源启停接口；现有Rust/FRB签名、存储与默认源策略不变。根BookApi移除21项，188→167（纠正上一版文档少计一项），见§2.5、§2.13、§2.35。 |
| 2026-10-15 | **章节缓存与下载边界冻结**：五项章节缓存迁入ChapterCacheRepository，六项真实批量下载迁入CacheDownloadService；列表/进度返回共享CacheDownloadTask，严格解码失败不得伪装空任务。仅删除无生产消费者的旧download管理器七项Dart包装，Rust公开签名保留；BookApi 205→187，见§2.43的Dart接线。 |
| 2026-10-15 | **阅读访问边界冻结**：目录、正文、抓取、正文保存及进度八项迁入ReadingRepository，正式实现直接调用既有FRB；平台载荷处理从应用装配注入，Mock复用同一书架/目录/正文数据。旧根接口移除八项，BookApi 213→205；目录错误响应明确报错，不按空目录处理。Rust签名、生成绑定、原文锚点及音视频进度语义不变，详见§2.9。 |
| 2026-10-15 | **WebDAV恢复调用方向冻结**：恢复通过既有webdavDownload读取bookshelf.json和sources.json，两份载荷结构校验完成后，经现有BookshelfRepository.importBooks和BookSourceRepository.importBookSources回写；恢复禁止调用上传或webdavFullSync。空列表不清空本地，下载/解码失败不以空列表代替；导入失败如实报告已完成阶段，不更新完整成功时间。备份仍保留现有目录准备与上传路径，Rust导出、FRB签名和方法数量不变。 |
| 2026-10-13 | **阅读记录上游三视图/会话契约冻结**：新增真实会话查询、每日单书删除和原始会话集合删除三项；累计写入带副本URL及章节序号。新增时段与累计/每日数据原子提交，重复快照不计时，删除按作者/设备隔离并同步四表，跨午夜每日删除裁剪原会话。不补造旧会话。领域方法7→10，附录296→299。 |
| 2026-10-13 | **阅读记录明细契约冻结（加法式，+2 方法；契约先行）**：补齐阅读记录单书每日明细（readRecordDetail）数据链与写入跨午夜原子事务语义。书籍身份由 `(bookName, author)` 标识，阅读器保存时透传真实 author；`putReadRecord` 写入事务计算有效增量 `delta = 新 readTime − 旧 readTime`，`delta <= 0` 幂等忽略；以 `[startTime, endTime]` 判断是否跨本地午夜，跨午夜时原子拆分毫秒至对应日期，单事务原子更新 `readRecord`、`readRecordDetail` 及 `readRecordDaily`，失败全量回滚；`deleteReadRecord` 级联删除指定书籍在 `readRecordDetail` 的所有明细；`clearReadRecords` 同时清空三表。新增 `getReadRecordDetails(int year)` 与 `getAllReadRecordDetails()`（均返回毫秒单位 `List<ReadRecordDetail>`）。§2.12 方法数 5→**7**，附录合计 294→**296**，ReadRecordRepository 口径 5→**7**（契约先行，实现批封装后程序化计数转齐）。 |
| 2026-10-14 | **搜索聚合与功能目录冻结**：SearchResultAggregator 独立纯 Dart，复用原增量桶、原始 name/author/origin 预去重与清洗后桶内双键、来源/已读合并、首条元数据及稳定排序；applyPrecisionSearch 使用同一实现，空关键词保留原返回。搜索页/书内搜索页、State/Freezed、Notifier、访问 Provider 与筛选面板集中到 features/search，外部经 search.dart；共享搜索栏保持原路径，旧入口不保留转发。会话/暂停取消/节流、Rust/FRB、方法计数、DB/版本/依赖不变。 |
| 2026-10-14 | **搜索会话生命周期冻结**：Dart SearchSession 持有发起时 SearchService、逐页订阅与控制队列；新请求在首个 await 前取得代数，旧取消/控制/订阅清理完成后才启动最新请求。停止、清空、重开及销毁立即隔离旧回调，取消使用原实例且先原生后解绑，暂停恢复串行并只回写当前会话；流异常关闭、自然结束保留同查询续页绑定。Rust 仍为全局搜索调度，Dart 会话不是新的原生请求句柄；七项协议、方法计数、聚合/节流和分页规则不变。 |
| 2026-10-14 | **搜索访问边界冻结**：SearchService 接管原七项普通/精确/多源/流式搜索及取消、暂停、恢复；SearchHistoryRepository 接管五项历史操作。正式直接 FRB，Mock 保留原返回与延迟、唯一历史存储；流式 SearchBatch 在数据层解码，保留 hasReadRecord、缺省字段与可空 hasMore，UI 不解析批次 Map。根分享引用、旧十二项方法移除；书内搜索和书架精确搜索同步迁移。会话生命周期与增量聚合后置；Rust/FRB 协议、数据库、版本与依赖不变。 |
| 2026-10-14 | **书源登录凭据边界冻结**：SourceLoginRepository 承担既有信息/登录头四项原始 JSON 读写，正式直接 FRB、Mock 保留唯一存储；转换与旧配置回退/顺序保存提取到独立模块，根仅分享引用、移除旧四项方法。手动编辑状态按书源 URL 隔离并过滤过期加载，空凭据清空，保存固定快照、重复调用共用在途结果；经典表单和 WebView 改用凭据接口，经典 JS 求值单独注入。保留 JSON、键、Header→Info 两次写入及部分成功/失败语义；动态登录、Rust/FRB、数据库、版本和依赖保持。 |
| 2026-10-13 | **HTTP TTS 批次 T1 全字段持久化与原地更新契约冻结**：保留 `HttpTtsRepository` 七项方法签名及方法计数不变；FRB `http_tts_add(http_tts_json: String) → Result<i64, BridgeError>` 与 `http_tts_update(http_tts_json: String) → Result<bool, BridgeError>` 升级为完整 `HttpTts` JSON 载荷，`http_tts_list()` 返回统一 camelCase JSON 数组。数据库 `httpTTS` 升级至 v110（新库建表 + `Migration109To110` + `repair_legacy_columns` 补齐 `speed` 可空整型与 `synthesisThreadCount` 默认 1）；完整读写 `id`、`name`、`url`、`contentType`、`pauseDuration`（Rust 扩展保留，默认 0）、`concurrentRate`、`loginUrl`、`loginUi`（导入兼容 JSON 数组自动序列化为字符串）、`header`、`jsLib`、`enabledCookieJar`、`loginCheckJs`、`speed`、`synthesisThreadCount`（1..8 clamp，默认 1）、`lastUpdateTime`、`isEnabled`（Rust 扩展保留，默认 true）。`updateHttpTts` 按 `id` 原地 UPDATE 全部字段并刷新 `lastUpdateTime`；目标 `id` 不存在（返回 `false`）、JSON 非法或写库失败均抛错，不删除或覆盖既有记录。配置页编辑改为 `copyWith` 原地更新，保留未展示高级字段与原 ID。 |
| 2026-10-13 | **书源校验边界冻结**：Dart 内部 SourceChecker 接收既有单源校验、批量进度流与取消三项能力；正式直接调用原 FRB 并复用 JSON 守卫，Mock 与书源 Repository 共用唯一存储，根仅提供共享引用、删除旧三项方法。Notifier 捕获发起校验的实例，以会话代数过滤迟到事件；准备期间重复启动被拒绝，取消完成前不启动下一轮，清除/销毁解除旧订阅。保留配置键、默认值、事件 JSON、结果文案和正常完成的失效分组回写；Rust 进程级取消与 Mock 原取消空操作保持，不变更 Rust/FRB 或数据库。 |
| 2026-10-13 | **书源导入职责冻结**：ImportResult/SourcePreview 独立为纯数据模型，SourceImportParser 统一预览和必填校验；导入服务只接收 BookSourceRepository、文本 GET、文件读取及书源替换规则回调，应用装配绑定同一根实例。保留宽松原始 JSON、逐条替换再入库、成功计数及失败边界；文件缺失与读取失败、HTTP 状态及原实际超时提示保持，不增加 BookApi 或 Rust/FRB 方法、不改变数据库或批量事务。 |
| 2026-10-13 | **书源功能目录冻结**：四个管理/编辑/导入页面及 part、状态和专用组件归入 `features/book_sources/`，外部经 `book_sources.dart` 使用；共用编辑器/选择栏保留，导入状态颜色抽到 theme。只改路径与共享辅助类位置，Provider/Controller 生命周期、方法体、源配置、导入语义及契约计数不变。 |
| 2026-10-13 | **书源数据访问冻结**：BookSourceRepository 承担既有列表/启用列表、增改删、启停、导入导出、排序偏好与源变量十一项操作；正式实现直连现有 FRB，写入成功后通过应用装配的回调保持封面注册表失效时序。Mock 与校验、默认种子共用唯一源列表，排序配置共用原存储；根只提供共享引用，删除旧十一项方法。登录、校验、JS 解析、搜索及替换规则保持既有入口，不改变 Rust/FRB、数据库或书源语义。 |
| 2026-10-13 | **书架功能目录冻结**：三个页面、书架/管理状态及注入入口集中至 `features/bookshelf/`，外部经 `bookshelf.dart` 引用。书架专用网格/列表项及分组名称辅助函数归入其 widgets，共享封面保留；只改路径和 import/export，领域接口、根实例、Provider 生命周期、状态及 Rust/FRB 契约不变。 |
| 2026-10-13 | **书架与分组直接适配冻结**：十项书架及五项分组操作由独立正式/Mock Repository 承担，根 BookApi 提供共享引用，删除旧十五项方法与临时适配器。正式调用沿用现有 FRB，Mock 书籍存储与加载守卫供进度、章节和本地导入共用；分组种子与 ID 分配保持。迁移阅读器、详情、朗读、记录、备份、同步等剩余消费者；书籍 JSON、排序、异常、进度写入及分组能力差异不变，Rust/FRB 和数据库不变。 |
| 2026-10-13 | **书架与分组窄接口第一批冻结**：新增 Dart 内部 BookshelfRepository（§2.2 十项）与 BookGroupRepository（§2.14 四项及既有 bookGroupSetShow）。本批单向适配现有 BookApi，迁移书架、管理和分组消费者；保留参数、返回值、异常、排序和分组显隐能力差异。旧方法供阅读器、详情、朗读、备份与同步继续使用，不重复计入契约总数；不修改 Rust/FRB、JSON、数据库或进度规则。 |
| 2026-10-13 | **朗读边界第三批冻结**：新增 Dart 内部 `ReadAloudEngine` 播放协议与段落 `ReadAloudSession`。HTTP 本地播放和系统朗读统一起播、完成、进度与控制入口，会话沿用播放 token / 合成代数判定过期，完成只消费一次；系统暂停续读与 HTTP 暂停重播、合成失败策略保持。控制异常按发起会话过滤，当前 HTTP 暂停/停止异常显示提示并保持暂停/空闲，不再逃逸为未处理异步错误。音频书和媒体会话不重构，不增加 BookApi 或 Rust/FRB 方法，签名、JSON、缓存和数据库不变。 |
| 2026-10-13 | **朗读边界第二批冻结（当时行为，后被本日 T2a/T2b 契约取代）**：HTTP 合成迁入 `HttpTtsSynthesizer.synthesize`，结果区分本地音频（路径、缓存命中、MIME）与无音频（空产物、探活成功或 Mock）。保留 Rust 合成失败后的 GET 探活、30 秒超时及播放器估算推进；探活不等同合成成功。移除 BookApi 的 `audioSpeak`、无应用调用方的 `ttsSpeak` / `ttsSetCacheDir` 包装；原生两项导出保留，缓存目录仍由 NativeRustRuntime 初始化。系统 TTS 提取平台接口和独立注入，插件实现、设置键、进度与停止屏障保持；不修改 Rust/FRB、数据库或播放协议。 |
| 2026-10-12 | **RUST-EDITION-20261012 工具链与旧 C ABI 清理范围**：工作区自有 crate 迁移 Rust 2024，沿用 stable，更新兼容依赖；FRB runtime/codegen 保持 2.13.0 配对。移除无项目内调用方的旧 `bridge.rs` C ABI 模块及其 182 个函数定义（181 个独立导出符号），不保留旧符号兼容层。现用 `crate::ffi`、FRB/PDE 入口、业务签名与 JSON、数据库结构保持不变（本日新增书签更新入口除外）；生成绑定由固定生成器重新产生。 |
| 2026-10-12 | **API-LIFECYCLE-20261012 书签更新契约冻结**：保留 `BookApi.updateBookmark(Bookmark)` 签名，新增 FRB `bookmark_update(bookmark_json: String) → Result<(), BridgeError>`，Dart 绑定为 `bookmarkUpdate(bookmarkJson:)`。按现有 Bookmark JSON 字段传入，以 id 定位并用单条 UPDATE 修改书籍、章节、正文和备注；id 与数据库原有 time 不变，输入 time 不参与更新。JSON 非法、目标不存在或数据库写入失败均抛错，失败不删除或新增记录。Mock 同步此语义；数据库结构与 BookApi 方法计数不变。初始化后将同一 BookApi 实例注入 Provider，不增加业务接口。 |
| 2026-10-10 | **FRB-UPGRADE-20261010 工具链升级范围冻结**：用户已同意 Dart 下限提高至 3.13、FRB Dart/Rust runtime 与 codegen 同步至 2.13.0。重新生成双方绑定并重建原生库；现有 BookApi/FFI 方法签名、JSON 字段、错误与事件流语义、数据库格式保持不变。版本、生成器内部实现和 content hash 可由同次生成更新，禁止手改生成物；生成前后核对导出方法并执行真实 FFI 回归。本条不增加业务 API，方法表与计数不变。 |
| 2026-10-05 | **P2-29c 后续：失败章查询契约冻结（加法式，零破坏，+1 方法，契约先行本批不改代码）**：§2.43 新增 `cacheDownloadFailedChapters(bookUrl) → Future<String>`（§2.43.8）：单次只读查询返回该书批量下载**已失败**章节 index 的 JSON 整型数组（升序、0-based；无失败为空数组）；数据链=任务表 `TaskInner` 与持久化快照新增失败章索引集合（对齐参考版 `CacheDownloadStateStore.kt:35-57` 的 `markFailed`（加入）/`markSuccess`（移除）语义，任务启动清空、恢复回读一并恢复、`persist_snapshot` 含集合）；目录页 ERROR 态（红色重试图标可重试，P2-29c 已落 UI、数据源恒空待接）由此接通。§2.43 方法数 10→**11**，附录合计 293→**294**，BookApi 口径 290→**291**（契约先行，实现批封装后程序化计数转齐） |
| 2026-10-03 | **B2 音频预下载写入面契约冻结（加法式，+2 写面方法；契约先于代码，本批不改任何代码）**：§2.48 新增（补齐 §2.47 只读/清理面所缺写入面，对齐原版 `AudioCacheService` 服务编排 + `AudioCacheManager.cacheChapter` 写入本体）：`audioCacheDownload({bookUrl, chapterIndex, chapterUrl, chapterTitle, playUrl}) → Future<String>`（Rust `ffi::audio_cache_download`，async + spawn_blocking 非阻塞）——单章下载安装，**幂等**（已提交缓存直接返回 `already_cached` 不重下，对齐原版服务循环 `AudioCacheService.kt:216` 跳过语义）；playUrl 由 Dart 经既有 `audioGetChapterMedia`（§2.26 播放取址链）的 `mediaUrl` 解析传入——**修订说明（2026-10-04，主代理据实现批反馈修正）**：初稿写 `getChapterContentFull`，但该链会应用替换规则与简繁转换（`reader.rs:1034,1111`）**可能污染 URL**；原版 `cacheChapterLocked:139-144` 实为播放链 `WebBook.getContentAwait` 输出，与我方 `getAudioChapterMedia` 同源，实现取后者更贴原版；Rust 自 DB 载入 Book/BookSource/BookChapter 后以 `legado-parser::AnalyzeUrl` 等价语义发起下载（headers/cookie/JS/重试全在 Rust；**字节不穿 FFI**——音频可达数十 MB，禁止 base64，系 §2.46 base64 惯例的反例登记，先例 `tts_speak`/`webdavDownloadFile`）；流程逐条对齐 `AudioCacheManager.kt:132-199`：五段式命名（`AudioCachePolicy.kt:67-98`）→ 陈旧未提交清理（1 小时阈值 `:302-314`）→ 流式写 `tmp_*.part`（块级取消检查）→ size 校验 → rename 安装（失败退复制）→ 写 `.complete` 并回读校验 → 同 key 旧版本清理；失败 **Err 上抛不降级**（有意区别于 §2.47 读面降级风格：写入是显式用户动作，错误须驱动 Dart 循环 failCount）。`audioCacheCancel() → Future<bool>`——取消在途下载（进程级取消代数单槽，对齐原版服务单 worker + stop 语义；中止流式拷贝并删部分文件）。**不设**批量队列/进度查询方法（Dart 循环逐章自持进度，原版服务编排不上 FFI）；**不设**容量上限/自动清理（原版无此功能，重构红线禁新增）；**不设**导入/导出（用户已裁决）；原版前台服务保活语义不复制（进程死即停、已装文件保留，登记为已知边界）。决策策略（键计算/文件名/扩展名探测/.complete 安装/已缓存跳过）全部落 Rust，UI 层零业务逻辑。§2.48 方法数 **2**，方法模块 44→**45**，附录合计 291→**293**，BookApi 口径 288→**290**（契约先行，代码未实现，`api_contract_test.dart` BookApi 总数项按预期红、实现批封装后转绿） |
| 2026-10-03 | **cbz 本地漫画批 B：FFI 契约冻结 + bookType 位域 + is_local_book 白名单（E9 参考版扩展，用户已授权；加法式，+1 纯 FFI 方法）**：**契约先于代码**——本条目及同批文档改动先于 Rust 代码落盘（工作树顺序：契约先行，代码随后；若同批提交则契约条目提交在前，见提交记录）。**新增 FFI 方法**（§2.34 压缩包导入 7→**8**，附录合计 286→**287**，BookApi 口径 283 不变——纯 FFI，待 UI 轨后续封装）：`cbzReadPage(path, entry) → Future<String>`（Rust `ffi::cbz_read_page`，实现 `legado-ffi/src/api/cbz_api.rs`；仅走 frb 主链路）——CBZ 本地漫画按条目读取图片字节，返回 JSON `{base64, len}`（与 §2.20 `fetchImageWithDecode` / §2.46 图片缓存的 `{base64,len}` 惯例对齐，§1.3 复杂类型 JSON 约定）；`entry` 兼容带/不带 `cbz://` 前缀（剥前缀后按 ZIP 条目名精确匹配，中文/空格条目名原样，不 URL 编解码）；`path` 为本地书 `bookUrl` 形态（绝对路径原样；相对可迁移标识经 `resolve_local_book_path` 同语义解析，与 §2.9 本地书链路一致）；错误语义：文件不存在 / ZIP 解析失败 / 条目不存在 / 包内无图片条目 → 抛 BridgeError。**bookType 语义补记**：`importLocalBook` 导入 `.cbz` 时 `bookType = LOCAL(0x1000) \| IMAGE_BIT(64)`（位域，对齐 Kotlin `BookType` 位语义）；其余本地格式（txt/epub/mobi/azw/azw3/pdf/umd）保持 `LOCAL` 无媒体位；`origin=loc_book` / `book_url` 相对标识语义不变。**命名域警告（必读）**：新增常量 `legado_core::models::book::book_type::IMAGE_BIT = 64` 属 `Book.bookType` **位域**；既有 `book_type::IMAGE = 2` 属 **BookSourceType 数值域**（书源类型「图片源」），两域禁止混用。**is_local_book 白名单**：新增 `.cbz`（`reader::is_local_book` 后缀判定，与 `.epub/.txt/.text/.mobi/.azw/.azw3/.pdf` 同列）；`.zip` **不加入**（保持压缩容器行为，`archiveImportZip` 路径不变）。**链路衔接**：`.cbz` 加入白名单后，`getChapters` 懒加载经 `LocalBook` → `CbzFile`（批 A `1e7dd3abb3`）解析并入库，`getChapterContent` 返回 `cbz://<条目名>` 行列表，Dart 侧逐行调 `cbzReadPage` 取图渲染 |
| 2026-10-02 | **P5 尾项 server 注入面接入关闭（setup 生成器平移 + `server_deps` 三闭包全量接入；零 FFI 签名变更、零 REST schema 变化、不新增端点；方法表与方法计数全部不变）**：提交 `aa49874137`。**调研翻盘（前批边界登记已被补齐）**：P5 关闭时登记「`login_header`/`book_variable`/`source_context` server 侧注入 None（server 无 DB/登录端点/setup 构造器，行为无损起点，接真实现即生效）」（见本表 2026-10-01 条目⑤及 REFACTORING_ACTIVE_PLAN P5 关闭记录尾项）——本批全部接入真实现，server 注入面不再有 None 占位。**setup 脚本生成器平移**：`legado-fetcher` 新增共享 `source_setup.rs`（宿主数据参数化），ffi `source_js_bindings.rs` 改薄壳 re-export——与 HEAD 逐字一致、diff 为空（code-reviewer 证实）；non-quickjs 档行为保持（返回空串）。**server 三闭包全量接入（`server_deps(state: &Arc<AppState>)`）**：① `login_header`——caches 表 `loginHeader_<source_url>`（与 ffi `source_login_cache::get_login_header` 同键）；② `book_variable`——`find_by_url` → `find_by_origin_book_url` 反查 `books.variable`（与 ffi `db_book_variable` 同语义）；③ `source_context`——`infoMap_<url>`/`loginHeader_<url>`/`userInfo_<url>` 三键 + 共享生成器（与 ffi `explore_info_map`/登录缓存同键）。**`with_state_db` 三级锁**：try_lock 快路径 → 多线程 runtime `block_in_place`（源码级证实慢路径无死锁风险）→ current_thread 测试档 None 降级（=批前行为等价）；code-reviewer 建议的两条禁令已注释（持 guard 任务不得进 fetcher 链、`Runtime::block_on` 根 future 不得直调 webbook 链）。**行为变化范围（接线）**：`build_engine(state)` 签名改动，reader/audio/toc_update 全端点接线；REST `/api/webbook/{search,info,chapters,content}`、`/api/books/:id/chapters/:index/content`、audio、toc_update 对需登录/带变量/需 setup 的书源从「能力关闭（None）」变为「可用」（登录头合并、`books.variable` 变量链、setup 脚本注入 JS 上下文）；不新增端点、不改 schema。**边界登记（未改）**：server 无 login/webView 写入面，登录头/变量生效依赖 server DB 已有行（App/桌面端写同库或外部写库）；`PUT /api/books/{id}` 以 `..Book::default()` 重建行会清空 variable（存量边界）。**测试与门禁**：server 5 新（deps 装配/login_header 种库/book_variable 反查/source_context 内容/REST 端到端 login_header 种→1 条未种→0 条）+ fetcher source_setup 2；回归 server 179、fetcher 84、ffi 403、ffi quickjs 467、server quickjs 180 全绿；clippy 三 crate `--all-targets -D warnings` 通过。**独立审查（code-reviewer）**：pass（无阻塞；P2-1 锁禁令已注释、P3 `leave_native`）。零 FFI 签名/REST schema/方法表变化，§2 方法表与方法计数全部不变 |
| 2026-10-02 | **HTTP P2-19 阻塞项关闭——`enabledCookieJar` 写侧门控（用户裁决方案 A「标记头机制」；零 FFI 签名变更、零 REST schema 变化、零 codegen，方法表与方法计数全部不变）**：提交 `62b04d9998`。**调研翻盘（推翻 2026-09-22 登记前提）**：原登记「打通需 FFI 签名/契约变更 + parser 变更，触碰契约先行红线」不成立——P5 fetcher 下沉后主链路调用点全部持 `BookSource`（共享 `legado-fetcher`），实现零 FFI 导出变更、零 codegen、零方法表变更。**上游真实语义（实读）**：请求**读侧**（携带 DB cookie）在主链路**无条件**（`AnalyzeUrl.kt:126/735-757`）；门控只在**写侧**（`Set-Cookie` 落 DB）——`enabledCookieJar==true` 才由 `AnalyzeUrl.kt` 放置 `CookieJar:1` 标记头，`HttpHelper.kt:84-100` 拦截器按标记头门控 `CookieManager.saveResponse` 写回，`null→false` 判定在 `AnalyzeUrl.kt:126`，Jsoup `get`/`post`/`head` 仅开关开启时补标记（`JsExtensions.kt:532-534/559-561/586-588`）。我方真实缺口仅为**写侧无条件落库**，读侧现状已对齐、逐行未动。**批1（Rust 写侧门控）**：serde 三态 `default_true_opt`（缺键→`Some(true)`、显式 `false`→`Some(false)`、显式 `null`/DB NULL→`None`→按关）；`legado-net` 写侧门控（`COOKIE_JAR_HEADER` 常量 + 6 个发送方法透传 `save_cookies` + `collect_*` 按标记门控 + 唯一建请求点剥离标记头；读侧 `apply_headers_and_cookies` 逐行未动）；`legado-fetcher` `parse_source_headers` 一处覆盖全部主链路调用点（`apply_cookie_jar_marker` 只补不覆盖）+ `search_single_source` 接线。**批2（JS 桥与直发点）**：first-wins 注入钩子 `SourceCookieJarLookup`（tag→`Option<bool>`），ffi `db_open` 与 cookie persistence 同点注册（基于 `BookSourceRepository::find_by_url`）；10 个 JS 网络发送入口按当前书源开关补标记（`http_get`/`http_post`/`http_head`/`ajax`/`ajax_request_body`/`ajax_all`/`connect_full`/`connect_no_redirect`/`head_full`/`post_full`）；读侧 `merge_js_cookies`/`cookies_for_url` 逐行未动；`review`×3/`explore`/`image`/`rss`/`source_checker` 直发点接线；无 source 语境的通用下载路径（`ffi_http_get/post`、`http_get_bytes`、TTS、font、`file_utils`、`jslib_loader`、dict、net rss/cover）保持无标记=不写回（对齐上游），已登记。**审查收尾（code-reviewer 初判 needs changes、无 P0 → 3 项全部闭环转 pass）**：P1 RoomImporter 解析统一（`as_bool().or_else(as_i64.map(n!=0)).unwrap_or(true)`，缺键→1、布尔 `true`→1，消除 server `source_update` 与 FFI `import_sources` 口径分叉及布尔 true 丢失）；P2-1 `RssSource` 同款 `default_true_opt`（core 的 `default_true_opt` 提升 `pub(crate)` 复用）——新导入/保存的 RSS 缺键现在按开（行为变化），库中既有 NULL 行仍按关（不迁移）；P2-2 残差仅登记（`tts_speak_api.rs:64` 与 dict/cover 恒不写，列入下一批接线清单）。**行为变化（均已登记）**：JS 桥每请求一次 `find_by_url` DB 查询（单行索引、不持锁进网络路径，保证运行中开关切换即时生效）；导出再导入 NULL→`Some(true)` 语义翻转（`default_true` 副作用）；同名 `CookieJar` 键自带 header 会被判开（上游同风险，只补不覆盖）；`httpGet`/`httpPost`/`httpHead` 纳入门控为上游超集（方向安全）。**测试（红→绿已做）**：core 4（`BookSource` 缺键/false/null、`RssSource` 同款）+ net 5（标记写回/无标记跳过/raw 两态/大小写/剥离）+ fetcher 2（parse 注入、e2e 缺键导入落库）+ search e2e 2 态 + JS 桥 3（gate 三态 + 2 原失败用例恢复）+ db 5 例三态（缺键/true/false/0/1→1/1/0/0/1 SELECT 断言）。**门禁（实现者+审查+主代理三方）**：db 322 / core 830 / net 257 / fetcher 81 / ffi 401+21 ignored / ffi quickjs 465+42 ignored / legado-js quickjs 657+2 ignored（连续 5 次）全绿；workspace 与 quickjs 档 clippy `--all-targets -D warnings` 通过。**P3 `leave_native`（登记不修）**：关源+规则同名 `CookieJar` 头 fail-open 半边、重定向后续跳无剥离断言、JS 桥其余 9 入口表驱动用例可补、`find_by_url` 每请求开销。**P2-19 至此全部关闭（backlog 五项 + 阻塞项 `enabledCookieJar`）**。零 FFI 签名/REST schema/方法表变化，§2 方法表与方法计数全部不变 |
| 2026-10-02 | **HTTP P2-19 尾项 charset 第四级统计探测（chardetng，零 FFI 签名变更、零 REST schema 变化；方法表与方法计数全部不变）**：提交 `f83b891ed6`。**依赖批准记录**：用户已批准引入 `chardetng` 1.0（纯 Rust、Apache-2.0 OR MIT、依赖仅 `encoding_rs`/`memchr`/`cfg-if`），`legado-fetcher` 的 `Cargo.toml` 带批准注释（2026-10-01 批准）；`encoding_rs` 0.8 由 dev-dependency 升为正式依赖。**四级解码语义表**：`decode_web_response`（`rust/legado-fetcher/src/web_book.rs`，改 pub，抓取链+搜索链唯一入口）按序为 ① 显式 charset（最高优先，不被探测覆盖；对抗用例双证：fetcher 单测 + 搜索级）→ ② `Content-Type` 头 → ③ HTML meta → ④ `chardetng` 统计探测；均未命中走 lossy UTF-8 兜底。对齐上游 `OkHttpUtils.kt:80-96` → `EncodingDetect.kt:18-44`（ICU4J `CharsetDetector`，无阈值）。**第四级细节**：BOM 优先（`Encoding::for_bom`，UTF-8/UTF-16 均支持，上游仅剥 UTF-8 BOM、属合理超集）；`guess(None, Utf8Detection::Allow)`（Allow 必须，Deny 会把无标识中文 UTF-8 误判 windows-1252，审查代理 scratch 实测）；`Iso2022JpDetection::Deny`（Web 内容指引）；探测猜非 UTF-8 走无损解码，失败或猜 UTF-8 回 lossy UTF-8。**搜索链收敛**：`search_single_source` 两分支（needs_charset_decode raw 分支 + 文本分支）统一为 `send_raw` + `decode_web_response`——补齐 meta 级与探测级（改前文本分支 reqwest `.text()` 只认 header）；retry/followRedirects 语义不变（共用 `send_with_options`）。**行为变化（已登记）**：3xx 日志拆两条（4xx/5xx「非 2xx/3xx」+ 未跟随 3xx 单独留痕，合取等价改前 raw 分支完整语义）；重定向后 `final_url` 作为相对链接解析基（改善，302→GBK 目标页用例钉住）。**parser 侧**：`decode_response_bytes` 保持声明解码原语 + lossy 兜底，不加探测（评估注释：避免共享原语语义扩散，探测只在 fetcher 一处）。**已知边界（注释登记）**：猜中 GBK/GB18030 族时无损解码对混合非法字节几乎总成功，个别乱码正文会有损解码进入规则解析（对齐上游无阈值）；JSON 纯 ASCII 不受影响。**测试 8 例**：fetcher 3（四级探测单测含对抗/UTF-8 回归、BOM 处理含 UTF-16LE、fetch_page 无标识 GBK 端到端）+ ffi 5（meta-only GBK、无标识 GBK+负向锚、显式 charset 对抗、UTF-8 回归、302→final_url）；红→绿已做。**门禁（实现者+审查+主代理三方）**：fetcher 79 / ffi 400+21 ignored / parser 314，0 failed；三 crate clippy `--all-targets -D warnings` 通过。**独立审查（code-reviewer）**：初判 needs changes（无阻塞，核心实现经 scratch 实测确认），4 项收尾全部闭环（P1-1 3xx 日志双条、P2-1 final_url 用例、P2-2 误判边界注释、P2-3 负向锚）→ 转 **pass**；P3 `leave_native`（显式 charset=utf-8 + BOM 极端角落保留 U+FEFF）。零 FFI 签名/REST schema 变化，§2 方法表与方法计数全部不变 |
| 2026-10-02 | **HTTP P2-19 批3 `urlOption` `followRedirects`/`retry` 消费接线（零 FFI 签名变更、零 REST schema 变化；方法表与方法计数全部不变）**：提交 `70b7c65e83`。新增汇聚模块 `rust/legado-fetcher/src/analyze_request.rs`（552 行，`send_raw` / `send_text` / `send_with_options`）统一消费 `AnalyzeUrl` 的 urlOption。**followRedirects 语义**：`Some(false)` → 改用 `LegadoClient::no_redirect_variant()`（`rust/legado-net/src/client.rs`，`Arc<OnceLock<LegadoClient>>` 实例级缓存的第二客户端池；clone 共享同池，FFI `shared_client` 场景即进程级）不跟随重定向发送；`true`/缺省 → 沿用现有共享客户端 `Policy::limited(20)`（批1 语义不变）。第二池复用同一 CookieStore（`Arc::ptr_eq` 验证）与持久化后端；首建 `load_all` 为一次性成本（已注释）。**retry 语义（重试边界）**：`retry > 0` 时响应**非 2xx 且非 3xx** 立即原样重发、无退避，总尝试次数 = `retry + 1`；2xx/3xx 为终态（含 `followRedirects=false` 下原样返回的 3xx，不触发重试），传输错误 `Err` 上抛不重试；**不复用 `legado_net::retry::RetryExecutor`**（其指数退避/面向 I/O 错误语义与 urlOption 的响应码级即时重发不等价）。**接线范围**：`fetch_page` 两分支（`web_book.rs`）、`search_single_source` 两分支（`search.rs`）、dict `fetch_body`（`dict_api.rs`，封面规则复用）。**行为变化（上游证实）**：hex（`type != null`）+ POST 书源从「实际 GET」恢复为「按 method POST」派发（上游 `AnalyzeUrl.kt:443` + `getResponseAwait:577-597` 按 method 派发），并补端到端用例 `test_fetch_page_hex_post_dispatches_post` 锁定。**未接线 deferred（各自原因）**：`review_api` 三处（发送 URL 为规则相对路径经 `get_absolute_url` 改写后的 `final_url`，可≠`analyze_url.url()`，需 helper 增 URL override 参数）；`explore_books_async`（现状强制 GET，接线会顺带改 method 语义）；`web_book.rs` 裸 URL 直发点（不持 `AnalyzeUrl`，天然不在汇聚点范围）。**curl 键不补**：`curl_converter` 不加 `retry` 键——上游 `CurlAnalyzeUrlConverter.analyzeOptionKeys` 无 `retry`，逐字一致。**测试**：`analyze_request` 10 例（followRedirects 302 原样/缺省 true 回归、retry 耗尽/成功即停/缺省 0/3xx 不重试、组合 false+retry 重试链不跟随/true+retry 跟随、POST 方法保持、`send_text` 共用循环）+ net 1 例（变体缓存 + CookieStore 共享 + 原客户端 20 跳对照）+ ffi 1 例（searchUrl retry=2 全链路 3 次请求）+ fetcher hex+POST 1 例；红→绿已做（桩 unimplemented 10 红→绿）。**门禁**（实现者 + 审查代理 + 主代理三方复跑）：fetcher 76 / net 252 / parser 314 / ffi 395+21 ignored / server 175，0 failed；四 crate clippy `--all-targets -- -D warnings` 通过；fmt 仅既有漂移（`web_book.rs` `include_str!` 换行，HEAD 记 `:5883` 位移）。**独立审查（code-reviewer）**：初判 needs changes（无 P0/P1），两项 P2 已闭环——P2-1 hex+POST 经上游源码证实维持现实现 + 用例锁定 + 行为登记；P2-2 汇聚点声明修正为准确覆盖范围 + deferred 登记；P3 `leave_native`（persistence `load_all` 权衡已注释）；闭环后满足 `convert_to_check` 转 **pass**。本批零 FFI 签名/REST schema 变化，§2 方法表与方法计数全部不变 |
| 2026-10-02 | **P2-19 `concurrentRate` REST 三态接线（REST schema 加法式；FFI 签名零变化、Dart `BookApi` 面零变化，方法表与方法计数全部不变）**：承接同日「保存刷新接线」批，按用户裁决方案 A 关闭 REST 面残余。**REST schema 加法**：`CreateSourceRequest`（`POST /api/sources`）新增可选 `concurrent_rate`（snake_case；缺键/null → `None`；空串/纯空白 → 按 `None`，对齐原版「空=不限流」）；新增独立 `UpdateSourceRequest`（`PUT /api/sources/:id`），`concurrent_rate` 为三态 `Option<Option<String>>` + 自定义 serde `deserialize_present_option_string`（键存在时再包一层 `Some`，缺键归外层 `None`）。**`concurrent_rate` 三态语义表（`UpdateSourceRequest`）**：① 缺键 = 保留数据库原值且**不刷新**限速注册表；② 显式 `null` 或空串/纯空白 = **清除**（DB 置 `None` + registry `remove`）；③ 合法值 = 入库并**刷新**。create 侧：带合法值 → 入库并刷新；缺键/null/空串/纯空白 → `None`，并清除该 URL 既有 limiter（`INSERT OR REPLACE` 既有行语义）。**update handler**：改为 `find_by_url` 完整实体字段级 mutate（不再 `BookSource::default()` 全列构造），DTO 未暴露字段（`jsLib`/`header`/`variable`/`comment`/`ruleSearch`/`ruleContent` 等）保留；path 不存在维持 `INSERT OR REPLACE`（不加 404）；path/body URL 冲突保持「按 path 查找、写 body URL」现状。**registry 新增原语**（`rust/legado-fetcher/src/rate_limit.rs`）：`remove(source_url)`（map 锁内移除，在途 `Arc` 自然跑完，未注册 no-op）+ `refresh(url, rate)` 统一保存入口（空 / `"0"` / 纯空白 → `remove`，对齐上游 Kotlin `ConcurrentRateLimiter`「空即不限流」；其余 → `update`：合法原位刷新保留窗口、非法不改、未注册不预建）；ffi/server 两处 `refresh_source_rate_limit` 薄壳均改走 `refresh`。**行为变化**：FFI `import_sources` / server `execute_update` 批量路径保存空值从「不改动」变为「移除 limiter」，修复 DB 与 registry 分叉（审查确认合理无回归）。**测试**：fetcher 4 新例（remove 重建/在途 Arc/未注册 no-op/refresh 分发）+ server 7 例（create 带值/缺省清除、update 缺键保留全字段且不刷新、显式 null 清除、空串清除、合法值原位刷新可区分清除重建、path 不存在 upsert）+ ffi 1 例（清除路径）。**门禁**（实现者跑 + code-reviewer 独立复跑）：fetcher 65 / net 251 / db 321 / ffi 394+21 ignored / server 175，0 failed；五 crate clippy `--all-targets -- -D warnings` 通过；fmt 仅两处 HEAD 既有漂移（`legado-fetcher/src/web_book.rs:5883`、`legado-server/src/handlers/web_book.rs:698`，未触碰）。**独立审查（code-reviewer）pass 无阻塞；登记项**：P1-1 path/body URL 冲突时清除/改率只刷新 body URL，path URL 旧 limiter 残留（裁决保留旧行为衍生，leave_native 后续批）；P2-2 create 对已存在 URL 全列 upsert 清空未暴露字段（既有 create 语义，与 FFI `add_source` 一致，不处理）；P3 响应无可观测性区分 / 合法值不 trim 入库（与 create 口径一致，上游同形）。**已知残余延续**：未注册 key 保存合法值后首个旧快照 `acquire` 仍按旧率惰性建（上游以 `update` 预建 record 关闭，我方按「未注册不预创建」约束保留待裁决）。本批为 REST schema 加法，FFI 签名、Dart 面与 codegen 零变化，§2 方法表与方法计数全部不变 |
| 2026-10-02 | **P2-19 `concurrentRate` 保存刷新接线（既有行为修复，零 FFI 签名变更、零 REST schema 变化，方法表与方法计数全部不变）**：修复「书源编辑保存后 `concurrentRate` 不生效」（P2-19 未修 backlog 项）。`RateLimiterRegistry`（`rust/legado-fetcher/src/rate_limit.rs`，自 ffi 下沉的共享实现）：`acquire` 只读配置、仅 key 缺失时按当前快照惰性创建 limiter；新增唯一配置写入者 `update(source_url, concurrent_rate)`（对齐上游 `ConcurrentRateLimiter.updateConcurrentRate`）——已有 limiter 原位更新 `accessLimit/interval` 并保留当前窗口 `time/frequency`（不重置已用次数），空 / `"0"` / 非法 rate 不改动既有记录，未注册 key 不预创建 limiter（「保存后首个 acquire 仍来自旧快照」作为残余登记）。**入口覆盖**：FFI `add_source` / `update_source` / `import_sources`（`legado-ffi/src/api/source.rs`）写库成功后刷新本次书源；server `source_update::execute_update` 经 `RoomImporter::import_book_sources` 成功后刷新本次实际导入 sources。**批量事务语义**：FFI `import_sources` 改走 `BookSourceRepository::insert_batch`（`legado-db::connection::in_transaction` 单事务），server `RoomImporter` 同用该共享事务边界——整批提交成功后才刷新，任一条失败整批回滚、不刷新（消除「前 k-1 条已入库但整体报错」的 DB 与 limiter 分叉态；嵌套事务场景复用外层事务）。**双宿主边界**：ffi 与 server 可同进程并存但各持独立 static registry，各自保存入口刷新各自实例；REST/FFI 同源并发窗口仍分叉，单例收敛另立项。**REST 面**：create/update DTO 不携带 `concurrentRate`，本批未扩展 REST schema、未改其原有字段语义，仅批量 source_update 接线；REST 编辑支持 `concurrentRate` 与其 update 全行 replace 可能把旧 rate 置空，登记为待用户裁决。本批为 Rust 内部行为修复，Dart `BookApi` 表面与 codegen 零变化 |
| 2026-10-01 | **漫画设置作用域书级字段（加法式，零 FFI 签名变更，方法数不变）**：按用户裁决对齐参考版「本书覆盖 + 全局回退」——`Book.readConfig` JSON 加法式新增可选 `mangaScrollMode`（书级翻页模式）与 `webtoonSidePaddingDp`（书级条漫侧边留白），均为 null/缺失 = 未覆盖、跟随全局 `MangaConfigKeys.scrollMode` / `MangaConfigKeys.sidePadding`。**单位口径（必读）**：`webtoonSidePaddingDp` 键名沿用以保持参考版作用域对齐，但**单位不是 dp**，值为 Flutter 现行百分比口径 0..45（每侧留白 = 视口宽 × p/100），不引入 dp/百分比换算。Rust `ReadConfig`（`legado-core/src/models/book.rs`）加法式类型化接收（`skip_serializing_if = "Option::is_none"`），修复此前 `updateBook` 全行回写链因类型化结构体不含该键而静默丢弃的问题；旧 JSON/旧数据库缺键 → `None`，空 readConfig JSON 形态与既有行为不变；进度/其他 readConfig 字段保留（进度列结构性排除不回滚）。Dart 端复用既有 `BookApi.updateBook`/`Book.copyWith(readConfig:)`（无新 FFI 方法、无签名变更、无 codegen 变化）；Flutter 阅读器有效值 = 书级 `readConfig` ?? 全局键 ?? 默认，「跟随全局」= 删键回退。回归测试：`legado-core` 三例（round-trip/旧 JSON 缺失/单项独立）、`legado-db` 两例（update 回写保留书级字段与进度、旧库 JSON 回写不新增键）。§2.2 方法数 10 不变、附录合计不变 |
| 2026-10-01 | **P5-1/P5-2 双实现下沉共享 crate 行为补记（内部重构，零 FFI 导出变化）**：server（REST `/api/webbook/*`）的 `RealBookSourceFetcher` 与 `login_check.rs` 本是 ffi 同类型的能力阉割分叉副本（P5-1/P5-2 缺陷登记，原版佐证 BookController.kt 直调共享 WebBook 单例）。三个提交完成合一：`bef38c3f25`（loginCheckJs 内核+QuickJsExecutor 下沉 legado-js）+ `f5ecbc0961`（新建 legado-fetcher 共享 crate，ffi fetcher 本体迁移）+ `2bdad331dc`（server 切共享实现+REST 改接自由入口）。**FFI 导出零变化**（ffi.rs:1280-1336 四个 `webbook_*` 签名与 FRB 绑定不动，codegen 未重跑）；REST 路由与响应 JSON 结构不变。**行为补记（server 侧能力增强，均属缺陷修复本身）**：① loginCheckJs 沙箱档统一为 ffi 原版（`allow_script_run=true`+64MB+RESPONSE/JSOUP 桥）——server 原裸档（eval 禁用/16MB）下依赖 eval 的 loginCheckJs 由误判 LoginRequired 变为可正确执行；② REST 端点获得源级 `concurrentRate` 限速门控（旧版零限速）、charset 三级解码（GBK 站点不再乱码）、data:URI/hex/final_url/cookie 按域合并/分页与变量字段；③ REST 改接 fetcher 自由入口后 mainJs **JS 书源分派经 REST 可用**（旧版 JS 源经 REST 恒失败）、begin_book_flow 流程生命周期接入、章节 index 语义与 App 对齐（不再叠加 0..n 重排）；④ 空 searchUrl 校验 500→400 Parser（引擎前置校验，对齐 App 自由入口）；⑤ `login_header`/`book_variable`/`source_context` server 侧注入 None（server 无 DB/登录端点/setup 构造器，行为无损起点，接真实现即生效）；⑥ flow scope 进程级单槽竞态为原版同构已知接受项。独立审查（code-reviewer）结论 pass（3 项 P2 登记：fetcher 测试夹具跨 crate 引用、双宿主限速表注释互认、REST 序列化往返开销）。§2.17 方法表与计数全部不变 |
| 2026-09-29 | **P4-1 C4 正文链空正文规则语义事实补记（纯补记+测试固化，零行为变更）**：§2.17 新增 ℹ️ 补记——正文规则 `ruleContent.content` 为空时，**非 JS 书源**的 `webbookContent` / 阅读正文链**不请求章节页**、直接返回**章节 URL 字符串**（Rust 短路位于 `WebBookEngine::get_content` 包装层 `legado-core/src/web_book.rs`，对齐原版 Kotlin `WebBook.kt:429-433`「正文规则为空,使用章节链接」——两侧语义一致，**无差异**）；JS 书源（`mainJs` 非空）豁免该短路，进入 fetcher 正文链（空规则 → 章节页 body 直用，是 `parse_content_page_with_bindings`「body 直用」分支的唯一可达路径，非 JS 源经引擎路径不可达）。P4-1 调查稿 §6 C4 原表述「空正文时 Rust 返回 body HTML、原版返回章节 URL 字符串」**与实测行为不符**（包装层先于 body 直用分支短路），本补记以实测行为为准并勘误。固化测试 `rust/legado-ffi/tests/comic_content_fixture.rs::test_empty_content_rule_returns_chapter_url_like_original`（离线回环：章节页路由注册但断言零命中 + 正文 == 章节 URL）。无签名/行为变更 |
| 2026-09-29 | **P2-29 目录章节行状态机对齐参考版五态：新增只读查询 listDownloadingChapters（加法式，零破坏，+1 方法）**：用户验收反馈「下载中缺少过渡动画」——P2-28b/c 目录轮询只翻转缓存态，批量离线缓存下载中章节行无 DOWNLOADING 态动画，且我方当前章 check_circle 与参考版 SUCCESS 态撞形。§2.43 加法式新增 `cacheDownloadRunningChapters(bookUrl) → Future<String>`（§2.43.7）：单次只读查询（纯任务表读 + 恢复回读，**零写入**）返回该书当前在途下载章节 index 集合，JSON 整型数组 `[2,3,...]`（0-based 升序；无活跃任务返回空数组）；Rust `cache_download_api::cache_download_running_chapters`（进程内任务表纯读 + `ensure_restored` 落库恢复回读：每 `running` 任务在途章 = `next_index`（worker 顺序下载，`[start,end]` 闭区间内方收录））；FFI `ffi::cache_download_running_chapters`（frb 主链）+ FRB codegen；Dart `BookApi/RustApi/MockBookApi.listDownloadingChapters`（RustApi 解析 JSON 数组为 `List<int>`）；目录页 1s 轮询（P2-28b/c）同周期拉取下载中集合驱动五态行（isDur location_on / DOWNLOADING 16px 转圈 / ERROR 红色重试 / NONE ⬇ / 已缓存无图标）。ERROR 态数据链：任务表仅 failed 计数、无逐章失败记录（记录需任务表写路径改动，超出本批授权）→ 目录页 ERROR 分支先落、数据源恒空（恒不显示，不伪造），待数据链补齐后接。§2.43 方法数 9→**10**，§1.7 等价对 13→**14**，附录合计 283→**284**，BookApi 口径 280→**281** |
| 2026-09-28 | **P2-28c 目录页实时字数刷新数据链：新增只读查询 listCachedChapters（加法式，零破坏，+1 方法）**：2.0.319 真机点验发现 P2-28b 轮询只 diff URL 集合（翻转 ⬇ 图标），字数胶囊渲染数据（章节 wordCount）不在轮询刷新路径内——批量缓存下载中胶囊要重开目录才出现。§2.43 加法式新增 `cacheListCachedChapters(bookUrl) → Future<String>`（§2.43.6）：单次只读查询返回该书已缓存章节的 (chapter_url, wordCount) 集合，JSON 对象数组 `[{"url":"...","wordCount":"..."}]`（按 chapter_index 升序、空 url 过滤；wordCount 取 `chapters` 表当前值（P2-28b 回填链同源），未回填为空串；有目录书过滤已退出当前目录的陈旧缓存行，与 §2.43.5 同步）；Rust `cache_api::list_cached_chapters`（纯 SELECT，复用 `CacheBookRepository::get_by_book` + `BookChapterRepository::find_by_book_url` 零额外查询）；FFI `ffi::cache_list_cached_chapters`（frb 主链）；Dart `BookApi/RustApi/MockBookApi.listCachedChapters`（RustApi 将 JSON 解析为 `Map<String, String>` url→wordCount，空 wordCount 不收录）；目录页 1s 轮询（P2-28b）升级为新方法：一次调用同时 diff URL 集合（翻转 ⬇）与刷新字数映射（新缓存章字数胶囊同帧出现，对齐参考版 ChapterListFragment 订阅 SAVE_CONTENT 同帧刷行语义）；查询失败保留旧态，dispose/停轮询语义不变。§2.43 方法数 8→**9**，§1.7 等价对 12→**13**，附录合计 282→**283**，BookApi 口径 279→**280** |
| 2026-09-28 | **STAGE3-C2B 刷新正文对齐上游原版强制联网重取（用户已裁决，加法式新增 1 方法）**：§2.16 加法式新增 `clearChapterCache(bookUrl, chapterIndex) → Future<int>`——删除指定书籍单章的正文缓存行（对齐上游原版 `BookHelp.delContent` 章级语义：仅删该章缓存行、**不触碰** `sameTitleRemoved` 等章级开关键、行不存在为 no-op 成功、空 bookUrl 返回参数错误、**不触发整书清理**）；FFI `ffi::cache_clear_chapter`（Rust `cache_api::clear_chapter_cache` → `CacheBookRepository::delete_by_book_and_index`）。Dart 阅读器 `refreshChapterContent` 编排改为「先失效当前章 → 再抓取」（对齐上游 `ReadBookViewModel.refreshContentDur` = `BookHelp.delContent` → `ReadBook.loadContent`），移除 C2 期自创的「抓取成功后才失效 + 成功后整书 `clearBookCache`」——已缓存章节点刷新必发网络请求，失败仅丢当前章缓存（同书他章缓存保留，UI 保留旧正文并显示失败原因）。§2.16 方法数 8→**9**，附录合计 281→**282**，BookApi 口径 278→**279** |
| 2026-09-24 | **换源感知等待（搜索期预拉缓存 + 可取消 apply，加法式，零破坏）**：对齐上游 Android `ChangeBookSourceViewModel` 三步——① 搜索期 enrich 对候选做内存预拉缓存写入（有界并发 8、单候选 60s 超时、失败/超时隔离直通；缓存 key `source_url\u0000book_url` 对齐上游 `primaryStr()`、目录上限 30000 章）；② §2.4 加法式新增 `switchSourcePrefetch(bookUrl, newSourceUrl, newBookUrl) → Future<String>`——命中预拉缓存直接提交缓存详情+目录（**零网络、选中即落地**），部分命中仅补抓目录，未命中现场抓取（执行链同 `switchSource`，既有方法冻结不变）；③ §2.4 加法式新增 `cancelSwitchSourceApply() → Future<void>`（对齐上游 `cancelChangeSource` L715-721）——apply 代数 +1 并 bump 目录刷新代数，在途 apply 提交前三点代数比对即中止（DB 零变更），在途目录分页链下一页边界中止；④ Flutter 换源页：apply 在途展示可取消加载态（spinner + 取消钮），进度串对齐上游 zh「结果 N，进度 M/K：源名」（values-zh/strings.xml:1457 + ChangeBookSourceDialog.kt L286-298）。§2.4 方法数 17→**19**，附录合计 278→**280**，BookApi 口径 275→**277** |
| 2026-09-22 | **队列⑩a P2-20 搜索跨源聚合三路径语义收敛（加法式，零破坏，方法数不变）**：P2-20 裁决落地——三条路径（Dart 纯函数 `applyPrecisionSearch` / `SearchNotifier` 增量桶 / Rust `aggregate_search_books` 单一真源）**在同一输入列表内**统一到同一语义：入桶前跨桶预去重（seen 键为**原始** `name|author|origin` 三段，与运行时 `_seenKeys` 逐字一致），同一 `(name, author, origin)` 仅**首次到达**入桶（落桶由首次到达决定，四桶优先级 equal→tags→contains→other 不变），后续同键到达丢弃（origin 由首条代表，跨源计数由桶内 `origins` 集合承载）。实现：纯函数（`search_state.dart`）与 Rust 入口（`legado-core::search_aggregate`）各补 `seen` 门控；`search_notifier.dart` 运行时路径仅补注释、行为不动（语义基准）。两端各新增 2 条单测（同键 kind 分桶 → 仅首条 1 条，含 assert_ne 回归保护；不同 origin 各保留、origins 累加）+ 跨端夹具 `cross_source_merge.json` `keep_other` expected 8→7 条（若回退为无 seen 的四桶独立实现，该 case 由 7 变 8 条、夹具变红——回归保护）。**范围限定（必读）**：该统一仅在**单次调用的输入列表**内成立——运行时 `_seenKeys` 为**会话级跨页**（跨页 APPEND 不清空，直至新关键词/清空），纯函数 / Rust 入口为**单次调用**语义、不携带会话状态；未来若把运行时聚合切到 Rust 入口，须传**会话累积列表**（会话内全部 books）而非单批 `SearchSourceBatch.books[]`，否则跨页同键书会重复计数（跨页重复回归）。§2.4 方法数 17 不变、附录合计不变 |
| 2026-09-22 | **队列⑩a P1-1 项2 搜索跨源聚合单一真源（加法式，零破坏，方法数不变）**：① **Rust 单一聚合入口**——`legado-core` 新增 `search_aggregate` 模块（`aggregate_search_books(books, key, keep_other)` 纯函数：归一化清洗 / 聚合键 `name\u0000author`（清洗后值）/ 四独立桶 equal→tags→contains→(keep_other) other / 桶内 originsCount 降序 + 首次到达索引平局 / 归并时 origins 并集累加（首次出现序，origin 去重不重复计数）+ `hasReadRecord` 跨源 OR + 首条到达元数据保留 / 空 key 原样返回），与 Dart 现行**纯函数** `applyPrecisionSearch`（`search_state.dart` L144-207）**逐条对齐（对齐范围严格限定为纯函数，不覆盖 `SearchNotifier` 增量桶路径——该路径入桶前多一层 `_seenKeys` 预去重（`search_notifier.dart` L307-310，`_seenKeys` 声明 L64），同名同作者同 origin 且 kind 分落不同桶时（如「都市情缘+乙」同源两条）纯函数/本入口产出 2 条、增量路径仅 1 条；差异登记 `REFACTORING_ACTIVE_PLAN.md` P2-20 待裁决，故本模块不得与增量路径称「完全一致」）**；FFI 层 `legado-ffi/src/api/search.rs::aggregate_search_books_json(books_json, key, keep_other) → Result<String>` 作为跨端校验入口（**FFI crate 内 pub 函数，本轮不做 FRB 暴露**——避免 codegen + `BookApi`/`MockBookApi` 同步面，Dart 运行时聚合切换留待后续批次，届时直接包装本函数）。② **`CoreSearchBook`（`SearchSourceBatch.books[]` 元素）加法式新增可选字段 `origins`（string 数组，serde default + 空时省略序列化）**——由聚合入口产出（同名同作者跨源合并后累加的 origins，首次出现序）；既有流式批次 / 解析 / DB 读路径不填充（空 → 序列化省略 → 批次 JSON 形态零变化），旧消费方零破坏。③ **Dart 侧加法式消费**——`SearchBook.origins`（`@Default([])`）+ `SearchResult.fromSearchBook` 非空时优先作为有效 origins（对齐 Rust `effective_origins` 规则：origins 非空→用它；否则 origin 非空→`{origin}`；全空→空集合，计数下限 1）；**Dart 运行时聚合路径（`SearchNotifier` 增量桶 + 150ms 节流）本轮不切换**——切换为每次 flush 跨 FFI 全量聚合将引入 O(n) 性能回归与会话态映射复杂度，非最小改动，故本轮交付 Rust 参考实现 + 加法式字段 + 跨端夹具锁定两端等价。④ **跨端夹具校验**——`rust/legado-ffi/tests/fixtures/search_aggregate/cross_source_merge.json`（books + expected，含跨源同名合并 / 作者「作者：」前缀与书名「 作者」后缀归一化 / 同源重复去重 / 四桶分落（同一键因 kind 差异落不同桶）/ 预填 origins 字段 / hasReadRecord OR / keep_other 两态），Rust 集成测试 `tests/search_aggregate_fixture.rs` 与 Dart 单测 `test/unit/search_aggregate_fixture_test.dart` 各跑同一夹具与 expected 比对（origins 按序比对（首次出现序为契约）、其余字段顺序敏感，不依赖真网络），已验证 Rust 聚合结果 ≡ Dart 现行纯函数 `applyPrecisionSearch` 期望。**双轨确认记录（一句）**：本变更 Rust/Flutter 双轨均归我方——Rust 侧仅 `search_aggregate` 新模块 + `CoreSearchBook.origins` 加法式字段 + FFI 内 pub JSON 入口（无 FRB 签名变更），Flutter 侧仅 `SearchBook.origins` 加法式消费（增量桶聚合路径不变、UI 零改动），既有搜索批次 JSON 形态与行为零变化。§2.4 方法数 17 不变、附录合计不变 |
| 2026-09-22 | **队列④ P1-B 单源搜索失败 UI 落地（纯 Flutter，无新 FFI，方法数不变）**：§2.4 `searchMultiStream` 批次事件 `error` / `source_name` 字段原在 Flutter 侧仅 `AppLog` 留痕（单源失败 UI 不可见）。本次落地最小可见呈现：`SearchNotifier` 批次监听将单源失败累积进 `SearchState.failedSources`（按源名去重、最新错误优先；新关键词搜索 / 清空结果 / 页面重开三处会话重置，同关键词续页会话内累积），搜索结果页顶部（列表头位置）以非阻断横幅呈现——文案取批次 `error`（含书源能力受限提示），点击展开可见逐源明细（`source_name` + `error`）。整体搜索交互不变（失败源不阻断搜索，对齐原版 `SearchModel` 静默语义，仅把「仅 AppLog 留痕」升级为「留痕 + 可见呈现」）；FFI 契约零变更，§2.4 方法数 17 不变、附录合计不变 |
| 2026-09-19 | **搜索批次逐源错误八分类（任务书 B P2 项1，加法式，零破坏）**：§2.4 `searchMultiStream` 批次事件 `SearchSourceBatch` JSON 新增可选字段 `error_class`（字符串枚举，八类：`ok` / `empty` / `http_error` / `timeout` / `login_required` / `js_error` / `parser_error` / `cancelled`）；分类在 Rust 侧批次组装单点完成（`search.rs` `run_multi_stream` 批次闭包对 `LegadoError` 变体做映射，不可归类的落到最近类别并在报告说明）；现有 `error?` 字段及其语义保持不变（冻结约束），不读该字段的旧调用方零破坏；§2.4 方法数 17 不变、附录合计不变。**双轨确认记录（一句）**：本变更 Rust/Flutter 双轨均归我方——Rust 仅批次 JSON 加法式扩展；Flutter 侧 `ffi.dart` 批次事件解析加法式同步，UI 展示已落地（队列④ P1-B，2026-09-22：单源失败累积 `SearchState.failedSources` 并在搜索结果页顶部以非阻断横幅呈现，既有批次消费路径不变） |
| 2026-09-13 | **替换规则预览 `@js:` 补齐（跨轨批次）**：§2.8 加法式新增方法 `previewReplaceRule(ruleJson, sampleContent) → Future<String>`（替换规则编辑器预览：对单条规则在示例文本上执行真实替换管线——正则（regex 优先 / fancy-regex 回退）/ 字面量 / `@js:` QuickJS 执行 + 逐规则超时；成功=返回替换后文本；规则级错误（非法正则 / `@js:` JS 异常 / 执行超时）=返回 `⚠️ ` 前缀错误文本（可直接展示于预览区，不上抛异常）；非法输入（JSON 解析失败）MAY Err）；§2.8 方法数 7→**8**，附录合计 277→**278**，BookApi 口径 274→**275** |
| 2026-09-13 | **替换规则书源作用域（scopeSource）全链路加法式（跨轨批次，对齐原版 `ReplaceRule.scopeSource`）**：① 契约——FFI `replaceRuleAdd` / `replaceRuleUpdate`（§2.8）各新增末尾可选参 `scopeSource: Option<bool>`（add 缺省=false 对齐原版；update 未提供=保留既有值）；`replaceRuleList` / `replaceRuleEnabled` 返回 JSON 项自动新增 `scopeSource`（缺省 false，旧调用方零破坏）；§2.8 **新增方法** `applyReplaceRulesToSource(sourceJson, sourceName, sourceUrl) → Future<String>`（书源导入时替换：仅取 isEnabled && scopeSource && pattern 非空规则，scope/excludeScope 按「源名称或 URL」contains 忽略大小写匹配——与标题/正文上下文的「书名/书籍来源」匹配是两套独立上下文，不复用 ScopeContext；正则带超时、`@js:` 复用正文管线、非正则按字面量替换；未命中=原样返回，规则级错误不上抛 FFI、保留原文不阻断导入）；§2.8 方法数 6→**7**，附录合计 276→**277**，BookApi 口径 273→**274**；② DB——`replace_rules` 表新增 `scopeSource INTEGER NOT NULL DEFAULT 0` 列，DB v108 迁移预告（SCHEMA_VERSION 107→**108**，幂等：user_version 门禁 + table_info 缺列检测，down 不可回滚），并纳入 `repair_legacy_columns` 防「版本已到 108 但缺列」历史坑 |
| 2026-09-11 | **替换规则写接口加法式扩参（A3 存量阻塞项，跨轨批次）**：FFI `replaceRuleAdd` / `replaceRuleUpdate`（§2.8 替换规则操作）新增 5 个可选参 `group: Option<String>` / `scopeTitle: Option<bool>` / `scopeContent: Option<bool>` / `excludeScope: Option<String>` / `timeoutMillisecond: Option<i64>`。缺省语义：add 未提供=旧行为（group=null / scopeTitle=false / scopeContent=true / excludeScope=null / timeout=3000ms）；update 未提供=保留既有值，提供空串=清除该字段。存储与读链路（replace_rules 表 upsert + `content_processor` 按 scope/scopeTitle/scopeContent/excludeScope 应用）早已存在，本次补齐写侧使 分组/作用范围/排除范围/超时 真正落库；BookApi 签名不变（仍传 ReplaceRule 对象，UI 层零改动），§2.8 方法数 6 不变、附录合计不变。**A3 阻塞项状态：①「FFI 写接口窄」已解除（写链路已补齐）；② scopeSource、③ @js: 预览仍受阻** |
| 2026-09-11 | **readRecordDaily 单位归一（修复，非签名变更）**：2026-08-29 上线的写路径把毫秒增量写进契约声明为秒的 `durationSeconds` 列，当日聚合值放大 1000 倍（热力图时长配色全天饱和、首页今日目标表盘恒满、按天视图显示「75天」级时长）。写路径改按整秒差值入账（`read_time/1000 − old_read_time/1000`，不因频繁小增量截断丢秒）；新增 DB v107 迁移把存量行整除 1000 归一（`Migration106To107`，user_version 门禁保证仅执行一次，SCHEMA_VERSION 106→**107**）。FFI 签名与 §2.12 方法数不变 |
| 2026-09-03 | **换源搜索流式化 FFI 冻结**（换源修复任务书批次 3 / T6，加法式）：`searchSourceStream`（§2.4 换源搜索流：Rust 侧 `ffi::source_switch_search_stream(book_name, author, source_urls_json, options_json, sink: StreamSink<String>)`，逐源完成即推一批次——进度 `finished_count`/`total_count` + 当前已过滤评分排序候选全量快照 `matches[]`；DB 复用路径单批推送；enrich 流内后置不阻塞首批到达）。旧 `searchSource` 保留兼容。§2.4 方法数 16→**17**，附录合计 268→**269**，BookApi 口径 265→**266** |
| 2026-09-03 | **换源执行链与变量链对齐**（换源修复任务书 T2/T3/T4/T5，加法式）：`searchSource` 返回 `matches[]` 项新增可选 `variable`（搜索期级联变量，对齐 SearchBook.toBook 复制语义）；`webbookInfo` 返回 JSON 新增可选 `variable`（bookInfo 规则求值 `@put`/`putVariable` 级联导出，无专用规则字段）；搜索结果项与 `searchBooks` 持久化启用 `variable` 透传（元素级导出）；`switchSource` 签名不变、行为对齐原版 getToc（详情解析→真实 tocUrl 取目录→失败即失败保留旧源；book.variable=候选与详情页变量合并、详情页优先；章节落库保留 variable/isVolume）。§2.4/§2.17 方法数不变 |
| 2026-08-29 | **热力图每日时长聚合契约**（U 侧 UI_MD3_PLAN 登记）：加法式——`readRecordDailyList(int year)`（§2.12 阅读记录组，返回 `[{date, seconds}]` 日期升序）；`putReadRecord` 写路径增量累加当日 readRecordDaily（新 readRecordDaily 表：date TEXT PK + durationSeconds，增量 > 0 入账，本地时区）。§2.12 方法数 5→**6**，附录合计 267→**268**，BookApi 口径 264→**265** |
| 2026-08-25 | **P3-5 换源页 parity**：加法式——`updateSearchBookScore` / `deleteSearchBook`（§2.4 搜索组，对标原版 SourceConfig 书维度评分与换源长按删除）；`searchSource` 返回 `matches[]` 项新增 `book_score`（-1/0/1）。§2.4 方法数 14→**16**，附录合计 265→**267**，BookApi 口径 262→**264** |
| 2026-08-24 | **搜索 parity 批次B FFI 冻结**：breaking——`searchMultiStream` Rust 签名 `ffi::search_multi_stream` 新增 `page: i32` 入参（页码透传，双轨评审记录：两轨均归我方 + 用户已批准批次B范围）；加法式——`pauseSearch()` / `resumeSearch()`（软暂停门控，SEARCH_PAUSED，仅拦未派发书源）+ 批次事件 `has_more` 字段（累积非空判定）。§2.4 方法数 12→14，附录合计 263→**265**，BookApi 口径 260→**262** |
| 2026-08-22 | **P1-3 契约自动校验**：新增 `test/unit/api_contract_test.dart` 程序化交叉校验（BookApi⊆RustApi/MockBookApi、§2.x 各节声明数、附录镜像、计数口径）；§1.7 补登录四方法命名等价对（`getLoginHeader` / `getLoginInfo` / `putLoginHeader` / `putLoginInfo`）；修正 6 处章节标题计数（2.3/2.5/2.9/2.18/2.41/2.43）+ 6 行附录计数；附录合计 251→**263**，BookApi 口径 252→**260** |
| 2026-09-15 | **N5 目录字数胶囊（无新 FFI 方法，JSON 加法式字段）**：`WebChapter`/`BookChapter` 章节 JSON 新增可选字段 `wordCount`（规则源由 `ruleToc.updateTime` 规则 info 经 `AppPattern.wordCountRegex` 等价正则 `(?:^|字数[：:、]?\s*|\s+)([0-9万千百.]{1,6}字)` 提取；JS 书源读章节 `wordCount` 键；`refreshToc` 落库透传）。Dart 侧 `BookChapter.wordCount` 已有（`@JsonKey(name: 'wordCount')`），目录页字数胶囊按「有值才渲染」，方法表不变 |
| 2026-08-01 | 契约初版冻结（v1.0） |
| 2026-08-10 | 第二批后置项 FFI 冻结：三个加法式新增——`shrinkDatabase`（§2.16 缓存管理）/ `webdavUploadFile`（§2.28 WebDAV 云同步）/ `toggleSameTitleRemoved`（§2.9 阅读器操作），契约合计方法数 174→177（Task #50） |
| 2026-08-10 | 第三批后置项 FFI 冻结：两个加法式新增——`setSourceVariable`（§2.3 书源操作）/ `getBookmarksByBook`（§2.7 书签操作，书签作者维度查询）+ `book_sources` 表补 `variable` 列 schema 迁移预告（SCHEMA_VERSION 102→103，幂等迁移），契约合计方法数 225→227（Task #63） |
| 2026-08-10 | 第四批后置项 FFI 冻结（Task #72）：三个加法式新增——`setCustomHosts`（§2.20 网络组，对齐原版 hosts 映射 JSON 对象）/ `setMcpPort`（§2.22 服务器组，**决策：对齐原版独立端口方案**，不复用 `setServerPort`，默认 1236，≤0=停止独立 MCP 服务）/ `searchCoverRules`（§2.4 搜索组，coverRules 表规则搜封面），附录合计 236→239，BookApi 口径 227→230 |
| 2026-08-12 | 远程书库（P1-5）加法式新增——`webdavDownloadFile`（§2.28 WebDAV 云同步，镜像 `webdavUploadFile`，二进制落盘）；远程服务器列表沿用 Flutter `SettingsService` 持久化（对齐原版 `servers` 表语义，不新增 Server CRUD FFI）。附录合计 239→240，BookApi 口径 230→231 |
| 2026-08-12 | P1-2 加法式新增——`clearCookie`（§2.3 书源操作，对齐原版 `CookieStore.removeCookie`）：按 URL 二级域名清除持久层 + 共享 HTTP 内存 CookieStore + JS 宿主 Cookie；附录合计 240→241，BookApi 口径 231→232 |
| 2026-08-13 | P2-4 部分：恢复忽略项 UI + `localBook` 在调用 `restore` 前由 Flutter 过滤备份 JSON（无新 FFI）；「导入旧版」仍隐藏待确认 |
| 2026-08-13 | P2-4 续：恢复忽略项其余键——备份 JSON 注入 `appPrefs`，恢复时按 BackupConfig.keyIsNotIgnore 过滤（readConfig/themeMode/themeConfig/coverConfig/bookshelfLayout/showRss/threadCount）；无新 FFI |
| 2026-08-13 | P2-1：底栏皮肤最小可用——纯 Flutter（`archive` zip 导入 + PrefKeys.bottomBarSkin）；**无新 FFI** |
| 2026-08-12 | P1-14 加法式新增——`looksLikeCurl` / `curlToAnalyzeUrl` / `analyzeUrlToCurl`（§2.3 书源操作）：对齐原版 `CurlAnalyzeUrlConverter`；Rust 复用 `legado-parser::curl_converter`。附录合计 241→244，BookApi 口径 232→235 |
| 2026-08-14 | **发现页控件 action**：加法式 `exploreEvalAction` / `exploreEvalUiJs`（§2.18）；`java.refreshExplore` 经 ui_action_queue 回传 `refreshExplore` 标志 |
| 2026-08-14 | **F3-17**：加法式 `rssListReadRecordsByOrigin`（§2.35）；**F3-10** 契约全面同步至 BookApi **247** 方法、附录 **251** |
| 2026-08-14 | **F3-14**：加法式新增 `httpGetBytes`（§2.20）；UI 层 8 处裸 `http.get` 收敛至 Bridge；附录 244→245，BookApi 233→234 |
| 2026-08-14 | **F3-5**：§1.6 登记 9 个 FFI 非 Result 导出豁免（只读/哨兵语义，不改签名） |
| 2026-08-13 | P2-8：检查更新对接 GitHub Release API（`AppUpdateService` + `UpdateDialog`）；纯 Flutter HTTP，**无新 FFI** |
| 2026-08-13 | P2-7：AutoTaskDebug 流式调试——UI 逐行回调 + `TaskResult.details` 对齐 LogFormatter；复用 `autoTaskExecuteWithId`，**无新 StreamSink FFI** |
| 2026-08-13 | `getSameTitleRemoved` / `canRemoveSameTitle` 权威查询与试算 FFI（§2.9）；UI 勾选态改读 caches KV；复刻「未找到可移除的重复标题」提示 |
| 2026-08-13 | **DB schema 结构对齐专项落地**（台账称「schema v102」，代码版本号 **103→104**，因 102/103 已分别用于 cached_chapters 复合索引与 book_sources.variable）：rssArticles/rssStars/readRecord 主键重建；rssReadRecords/httpTTS（原 http_tts）/search_keywords 结构对齐 Room v95；rssSources 去掉 enableCookieJar 冗余列；coverRules 纳入建表清单。无新 FFI；Repository 列名随表结构适配。残留：rule_subs/dict_rules/keyboard_assists 表名仍为 snake_case（见台账 §4.2.1） |
| 2026-08-13 | **D1**：SCHEMA 104→105，`ruleSubs`/`dictRules`/`keyboardAssists` 对齐 Room 表名列名（Migration104To105） |
| 2026-08-13 | **F4**：封面规则 CRUD 加法式新增——`getCoverRule` / `saveCoverRule` / `deleteCoverRule`（§2.4，对齐原版 `BookCover` + `CoverRuleConfigDialog`） |
| 2026-08-13 | **F5**：`setMcpPort` 对齐原版 LAN（`0.0.0.0`）+ `jsSourceApiToken` 启动前置 + `X-Legado-Token` 鉴权（§2.22） |
| 2026-08-13 | **SOURCE_DIFF P0-1**：`@put:`/`@get:`/`setLocal` 变量系统落地——`AnalyzeRule` 会话变量 + 章节 `WebChapter.variable` / `BookChapter.variable` 透传；**无新 FFI 方法**（既有 webbook/reader JSON 加法式字段） |
| 2026-08-14 | **F3-13（D4=B）**：`video_play_utils.dart` 视频 URL/MPD 解析保留 Flutter 层（对齐原版 VideoPlay 复合 URL 语义）；**登记豁免**，不新增 video FFI |
| 2026-08-14 | **F3-4（D3=A）**：沙箱文档口径——书源主路径 `EnginePool` 启用 eval/Function（Rhino 对齐）；`js_eval` 仍用严格 `SandboxConfig::default()` |
| 2026-08-13 | **SOURCE_DIFF P1 DOM WebView**：加法式新增 `webviewRequestStream` / `webviewSubmit` / `webviewCancel` / `webviewPending`（§2.3）：对齐 `BackstageWebView` 挂起-唤醒；Flutter 订阅后 `@webjs`/正文 webJs/`java.webView*` 走真实 DOM。附录合计随 codegen +4 |
| 2026-08-13 | **SOURCE_DIFF 纯工程收口（无新 FFI）**：Android 原生 `backstageEval` 落地页内 `java`/`source`/`cache` JavascriptInterface + `cacheFirst`→`LOAD_CACHE_ELSE_NETWORK`；Rust `ownText`/`string_rule_cache`。契约语义边界更新，方法表不变 |
| 2026-08-18 | **书源搜索 parity（无新 FFI）**：QuickJS 宿主补齐 `org.jsoup.Jsoup` 模拟（`java.jsoupAttr/jsoupText/jsoupHtml`）+ 引擎创建时注入 `java.get/post/head` Response 桥（`connectNR`/`followRedirects(false)`，对齐 JsExtensions）；`@js`/`<js>` searchUrl 求值失败禁止字面回退；`AnalyzeUrl`/`ajax` 纠正书源 `#tag` 后缀把 path/query 拼进 fragment 的假 URL。方法表不变 |
| 2026-08-18 | **G8 `$n` 跨步分组（无新 FFI）**：allInOne 正则 `getElements`（`:` 前缀）在有捕获组时把 `[全文,$1,$2,…]` 编成 JSON 数组元素；`getString("$2")` / `$1##…` 对齐原版 `SourceRule.makeUpRule` 用前序捕获组回填。覆盖书书小说/笔下文学/若夏等目录规则。方法表不变 |
| 2026-08-19 | **搜索 baseUrl=重定向最终 URL（无新 FFI）**：`webbookSearch` 对齐 `WebBook.search` 的 `baseUrl = res.url`；搜索 302 到详情页时按空列表回退解析 `ruleBookInfo`。方法表不变 |
| 2026-08-24 | **webbook* FFI 非阻塞化（无签名变更）**：Rust 侧 `ffi::webbook_search/info/chapters/content` 改为 `async fn` + tokio 阻塞线程池执行（`spawn_blocking`），对齐原版 `WebBook.kt` Dispatchers.IO 语义——网络 + quickjs JS 解析不再阻塞 Dart 主 isolate（此前 wire 函数同步执行，加载目录卡 UI 数秒）；Dart 侧 API 表面不变（仍 `Future<String>`），codegen 双侧重生成 |
| 2026-09-26 | **项 B/B1 WebView cookie 回流 + sourceKey（加法式）**：新增 `webviewSubmitResultWithCookies`（§2.3，WebView 执行结果 + 域 cookie 回流，Rust 侧按 ETLD+1 归一域键 merged upsert 落 `cookies` 表并同步 JS 桥共享客户端内存 CookieStore，先持久化后唤醒）；`WebViewRequest` 事件加法式字段 `source_key`（JS 执行线程当前书源 key，缺省空串）/ `cookie`（B4 起按请求域预填，缺省空串）——`serde(default)` 空串缺省，旧端忽略未知字段不破坏反序列化。Android 原生 `backstageEval` 加法式返回 cookie 回流信封（无 cookie 时纯结果串，旧版语义不变）；注入接口口径由 `isRule` 扩为「`isRule` 或 `sourceKey` 非空」。旧 `webviewSubmit` 冻结不动。§2.3 方法数 32→**33**，附录合计 280→**281**，BookApi 口径 277→**278** |

---

## 1. 契约总则

### 1.1 定位

本文档是 **UI 轨**与 **Rust 轨**的唯一接口契约基准。跨轨数据流通以 `BookApi` 和逐域拆出的窄接口为准；书签由 `BookmarkRepository`、阅读记录由 `ReadRecordRepository`、HTTP 引擎配置由 `HttpTtsRepository`、合成由 `HttpTtsSynthesizer` 承担，书源配置与校验分别由 BookSourceRepository、SourceChecker 承担，本文档为其权威文字说明。

### 1.2 变更规则

| 变更类型 | 规则 |
|----------|------|
| **新增 API** | Rust 轨可自由添加，但须同步：① 更新本文档 ② 补 `MockBookApi` 假实现 ③ 对应的 `BookApi` 或领域窄接口新增抽象方法 |
| **修改/删除已有签名** | 破坏性变更，必须双轨评审确认后执行，PR 标注"破坏性变更"及影响范围 |

详细流程参见 [TWO_TRACK_DEV_SPEC.md § 4 契约变更流程](TWO_TRACK_DEV_SPEC.md)。

### 1.3 数据传递约定

- 稳定实体和结果按逐域冻结的 FRB Struct/Enum/集合传输，Dart data 适配器转换为原领域模型。
- 原始文件/图片字节使用 Vec<u8>/Option<Vec<u8>>；当前继续使用 SSE，不能据此宣称零拷贝。
- 真正的脚本、配置、登录、导入导出文件和网络协议保持各自 JSON 文档语义，不为消除 String 改写产品格式。
- 已迁移接口以本文件末尾 FFI-TRANSPORT-20261017 各域冻结和生成签名为准，覆盖正文历史 JSON 说明；
  尚未冻结迁移的接口仍使用原协议，不能把“当前仍返回 JSON”理解为必须保留 JSON 的设计要求。
- JSON 仅在真实文档/尚未迁移边界使用 toJson/fromJson；已迁移稳定 DTO 不得先序列化再反解析。

### 1.3.1 阅读布局纯计算服务（2026-10-12 冻结）

用户批准以独立 `legado-layout` 替换旧估算排版；平台文字测量留在 Flutter。
该服务独立于书籍业务 `BookApi`，不修改其方法计数、数据库和书源协议。
布局输入、输出及会话生命周期以 [阅读布局契约](READER_LAYOUT_CONTRACT_20261012.md) 为准。

| Rust 导出 / Dart 名称 | 参数 | 返回 | 语义 |
|---|---|---|---|
| `reader_layout_begin` / `readerLayoutBegin` | `config: LayoutConfigDto` | `Result<LayoutSession, BridgeError>` | 校验配置和载荷预算，创建独立 opaque 句柄 |
| `LayoutSession.push` | `blocks: Vec<LayoutBlockDto>` | `Result<LayoutReplyDto, BridgeError>` | 批量推送已测量块，返回已完成页 |
| `LayoutSession.finish` | 无 | `Result<LayoutReplyDto, BridgeError>` | 输出余页并释放会话核心，重复调用报错 |
| `LayoutSession.cancel` | 无 | 同步 void | 幂等取消；Dart 最终显式 dispose 释放句柄引用 |

数值列为 Vec<u8> 小端二进制，不再经 Base64；共享文字/样式和字形编号继续保留。
删除 session_id 注册表和旧全局 push/finish/cancel 导出，不保留双协议兼容或格式标签。
预算、并发会话、单批块数/行内项数和取消语义保持，GC 不是及时取消机制。
文本位置采用章节 UTF-16 偏移；虚拟缩进、段评与背景音乐胶囊没有原文长度。
无效配置、非有限几何、簇/宽度不匹配及已结束会话报错，不回退旧算法；分页/断行仍按固定上游
`070ca1a9b2e491654f70c105bca9939968023940` 的 Kotlin 执行结果校验。

### 1.4 已知双兼容点（重要警告）

> 2026-10-17 强类型补充：本节 JSON 裸数组约束仅适用于尚未迁移的 JSON 接口；已冻结的 DTO 列表直接传输，不先转换 JSON。书签与每日阅读明细见 §2.7。

下表记录历史结构事故；当前对应 ChapterListDto/SourceSwitchResponseDto 在 data 层明确映射，不再解码包装 JSON：

| 方法 | Rust 返回结构 | 提取字段 | 历史事故 |
|------|---------------|----------|----------|
| `getChapters` | `ChapterListResponse { total, chapters[] }` | `chapters` | Task #29 崩溃修复 |
| `refreshToc` | `ChapterListResponse { total, chapters[] }` | `chapters` | Task #42 崩溃修复 |
| `searchSource` | `SourceSwitchResponse { book_name, author, matches[] }` | `matches` | Task #42 崩溃修复 |

> 列表和带分页/总数的响应须冻结各自类型，禁止无预警改变容器。仅真正 JSON 文档及未迁移接口沿用原裸数组约定，不把 DTO 包回 JSON。

### 1.5 实现类

| 类 | 文件 | 用途 |
|----|------|------|
| `RustApi` | `rust_api.dart` | 真实 FFI 实现（需 Rust DLL） |
| `MockBookApi` | `mock_book_api.dart` | 纯 Dart Mock（`--dart-define=USE_MOCK=true`） |

### 1.6 FFI 非 Result 导出豁免（F3-5，2026-08-14）

以下 9 个 `ffi.rs` 导出**刻意**不包 `Result<_, BridgeError>`，BookApi/Dart 侧保持既有签名；语义为只读查询或哨兵返回值，失败不抛 bridge 异常：

| FFI 函数 | 返回类型 | 豁免理由 |
|----------|----------|----------|
| `version` | `String` | 编译期常量版本号，永真 |
| `backup_list` | `String` | 目录列表 JSON；IO 失败返回 `[]` 空数组字符串 |
| `server_stop` | `String` | 状态消息字符串（对齐 stopServer 吞错语义） |
| `server_status` | `String` | 状态 JSON；未启动时返回 `{running:false}` |
| `archive_is_archive` | `bool` | 纯路径扩展名判定，无 IO |
| `auto_task_normalize_script` | `String` | 纯字符串变换，输入必返字符串 |
| `auto_task_can_refresh_toc` | `bool` | 纯布尔逻辑组合 |
| `auto_task_next_due_at` | `i64` | cron 无法解析时返回 **-1** 哨兵（非异常） |
| `audio_with_play_mode` | `String` | readConfig JSON 变换；非法 JSON 回落 `{}` |

> 其余新增 FFI 仍遵循 `Result<_, BridgeError>` 铁律；本表仅销记历史非 Result 面，**不扩范围**。

### 1.6.1 进程注入型 FFI（void，不经 BookApi，MD3 对齐 2026-09-04）

阅读器底栏文字偏好（2026-10-21）：ReaderSettings.showMenuLabels默认false，
ReaderSettingsRepository.update新增同名可选字段，经既有SharedPreferences通道
保存为reader_menu_show_labels布尔值，归入阅读偏好备份；仅控制底栏五个按钮的可见文字，
图标、提示及无障碍名称保留。不改变Rust/FRB或数据库，不增加旧键兼容。— Codex + UI

> **第二十步设置试点冻结（2026-10-14）**：仅新增 Dart 内部设置快照/读写协调与搜索设置窄接口，
> 复用既有 configGet/configSet 及 SharedPreferences，不改变 FRB 签名、JSON 或数据库。
> BookApi 配置四项本批保留供未迁移域与兼容存储适配器共享；方法总数不变。
> 搜索四个 config 键、showSearchReadRecord 偏好键和值编码保持；不把所有 config 载荷归入普通设置。

> **第二十八步主题偏好与未接线选项冻结（2026-10-14）**：八项日夜颜色、两项背景路径
> 通过纯 ThemeColorsSettings、ThemeColorsSettingsRepository 与共享 AppSettingsService
> 读写；颜色以类型化槽位传递，null 清除覆盖，空背景路径删除原键。保留原键及类型，
> 多键保存沿用逐项成功语义；失败向页面传播，不继续提示应用/导入成功。恢复后显式重读。
> 导航栏阴影、壁纸自动更新、四项默认封面及日夜透明导航栏尚无实际消费端，设置行
> 禁用并保留原说明、追加“待实现”，既有值不删除。主题预设列表格式、平台图标操作及 Rust/FRB
> 接口不变。本条只冻结 Dart 内部访问边界，由用户本轮授权确认，不新增 FFI 方法。
>
> **第二十七步常用偏好集中迁移冻结（2026-10-14）**：书架五项、阅读记录三项、
> 语言一项、护眼六项、欢迎页及启动默认开读九项，共二十四项复用 Dart 共享设置
> 服务和各领域 Repository。保留原键、类型、默认值、编码和实际运行行为；
> 设置页与实际消费者同步切换，删除对应独立写队列。阅读记录实体、阅读进度、
> 路由、原生接口、Rust/FRB、数据库与存储位置不变，组合保存不承诺事务。
>
> **第二十六步界面偏好集中迁移冻结（2026-10-14）**：按用户加速迁移指令，
> 原十项布局与 UiSettingsNotifier 剩余十七项合并为 Dart UiSettingsRepository，
> 沿用 SharedPreferences 原键、类型、默认值和现有保存限值。移除旧存储访问、
> 独立写队列及加载合并；保留页面入口，圆角/模糊对话框等待保存并提示错误。
> 不改变 Rust/FRB、阅读器行为、平台能力、数据格式或存储位置。
>
> **第二十五步系统栏偏好接线冻结（2026-10-14）**：transparentStatusBar、
> immNavigationBar、transparentNavBar、transparentNavBarNight 四项偏好复用
> Dart 共享设置服务，保留原布尔键与默认值；原生系统栏控制和阅读器显隐保持。
> 不新增透明导航栏平台接线，不修改 Rust/FRB、数据库、备份格式或存储位置。
>
> **第二十四步界面布局偏好接线冻结（2026-10-14）**：顶栏/底栏/侧栏十项
> 普通偏好迁入 Dart 共享设置访问层，保留原键、类型、默认值与透明度限值。
> 不修改 Rust/FRB、数据库、存储位置或备份格式；其余界面偏好保持原访问路径。
>
> **第二十三步主界面偏好接线冻结（2026-10-14）**：仅拆分 Dart 内部三项主界面偏好
> 访问，保留 showDiscovery/showRss/defaultHomePage 键、布尔/字符串编码与原默认值。
> 导航协调属于界面层，共享设置服务负责持久化与失败回退；不修改 Rust/FRB、数据库、
> 备份格式或存储位置。
>
> **第二十二步外观设置接线冻结（2026-10-14）**：三项既有 SharedPreferences 外观
> 偏好接入共享设置服务与纯模型；启动和运行时使用同一来源。Dart 内部主题同步能力
> 区分保存失败与原生同步失败，沿用现有主题 JSON 和模式 0/1/2，不改变 Rust/FRB、
> 数据库、备份格式或存储位置。
>
> **第二十一步朗读设置接线冻结（2026-10-14）**：沿用第二十步 Dart 设置访问层，
> 迁移既有七项朗读普通偏好及旧跟随开关迁移，不修改任何 Rust/FRB 接口、载荷或数据库。
> 引擎选择、书级语速、音色实体、凭据和平台音频桥保持；现有 config 键与编码不变。

> **FLUTTER-DATA-BOUNDARIES-20261012 接线冻结**：仅调整 Dart 内部职责，不新增或修改
> FFI 签名、JSON 字段、BookApi 计数及数据库结构。应用 Bootstrap 依次调用原生运行时、
> 数据库、目录与设备注入、主题配置及模式、阅读配置；设置层产生只含数据的快照，
> Bridge 负责序列化及写入。阅读设置刷新经 `ReadingConfigSync` 接口委托同一实现，
> 不通过具体 RustApi 类型识别；Mock 无注入动作。RustApi 生命周期由应用工厂注入，
> `initialize()` 仍等待就绪后供根 ProviderScope 共享。非关键注入失败继续保留原回退。

以下 6 个 `ffi.rs` 导出为 Flutter→Rust 单向进程级注入（返回 void，经 `bridge.*` 直调，不进 `BookApi` 抽象层与方法计数）：

| FFI 函数 | 入参 | 说明 |
|----------|------|------|
| `set_device_id` | device_id（Android ID / iOS IDFV） | 历史既有（本书山正文 X-Device-Id 校验），本次补登记 |
| `set_theme_config` | theme_json（`get_theme_config` 同形 JSON） | Batch 0 R1：启动/切换调色板时注入当前 palette 亮色 role，JS `getThemeConfig()` 优先返回注入值，未注入回退 wh 默认 |
| `set_theme_mode` | mode（"0"=跟随系统/"1"=亮/"2"=暗，对齐 Kotlin themeMode） | Batch 0 R2 + R 批 R3：`setThemeMode` 时注入，JS `getThemeMode()` 映射为 auto/light/dark（"0"→auto；未注入回退 light） |
| `set_read_book_config` | read_json（`get_read_book_config` 同形 JSON） | R 批 R4：阅读配置变更时注入当前阅读配置，JS `getReadBookConfig()` 优先返回注入值，未注入回退硬编码默认 |

阅读配色增量（READER-COLOR-STYLES-20261014）：Dart 阅读样式分别保存日夜背景和文字色，
配置注入从同一仓储解析当前样式，读取与正文共享的阅读会话明暗覆盖及应用明暗。
手动覆盖不持久化，退出阅读页清除；样式配色与选择继续保存。既有 JSON 键和类型保持，
`name` 为当前样式名，`bgStr`、`textColor`、`_bgColorHex` 为当前生效颜色；纯色背景
的 `bgType` 为 0，不再使用旧预设数组下标表示背景类型。颜色切换后刷新现有注入
入口；字号与其他既有快照参数保持，Rust/FRB 方法签名和数据库不变。

字号行距访问迁移（READER-TYPOGRAPHY-SETTINGS-20261014）：`textSize` 改为读取共享
ReaderSettingsRepository 的字号并按原规则四舍五入为整数。字号默认20，行距默认1.7，
继续保存为原 Preferences double 键。行距同步到正文；既有 JS `lineSpacingExtra: 8`
及其他配置字段、类型和初始化顺序保持，不新增或修改 Rust/FRB 方法。

字体访问迁移（READER-FONT-SETTINGS-20261015）：正文字体沿用`reader_font_family`，
默认删除键；标题字体统一为`reader_title_font_family`，空串表示跟随正文。两者进入共享阅读设置，
开发阶段直接使用新键，不读取或迁移旧titleFont；高级配置不再写回标题字体。自定义列表保留StringList及`family|path`格式，字体文件
仍在Documents/fonts，通过统一平台加载入口注册。既有JS配置的`font`字段及其他
注入字段保持，Rust/FRB契约、生成物和数据库不变。

目录与章节链接设置（READER-CHAPTER-SETTINGS-20261015）：ReaderSettingsRepository
管理`reader_toc_load_word_count`（默认true）和`reader_chapter_in_system_browser`（默认false）。
目录显示、章节点击及长按保存使用同源快照；开发阶段直接使用规范键，不读取或迁移旧键。
保存失败回退并反馈，章节长按仍执行本次所选的打开方式。备份恢复重读这两项，
阅读配置忽略集合覆盖它们；既有JS快照、Rust/FRB方法和数据库保持。

正文排版设置分组（READER-TEXT-LAYOUT-SETTINGS-20261015）：ReaderTextLayoutSettings
归ReaderSettingsRepository，八项标量使用reader_前缀规范键，按字段保存并同步正文和控件。
高级配置不再包含或写回这些字段；不读取或迁移它们的旧键，实际默认与单位保持。
原JS配置中的段距、字距、字重等既有字段和值保持，本轮不改变Rust/FRB签名或生成物。

页面布局设置分组（READER-PAGE-LAYOUT-SETTINGS-20261015）：正文边距、横向双页、
章节标题及页眉页脚27项归ReaderPageLayoutSettings，使用reader_前缀规范键，逐字段保存。
高级配置不再读写这些字段，不迁移旧键或旧日夜分桶；控件与ReaderPageChrome共用快照。
既有首次缺省、恢复默认入口、提示编号及显示规则保持；Rust/FRB、JS快照与数据库不变。

屏幕设置（READER-SCREEN-STATUS-SETTINGS-20261015，20261021按READER-TIP-UNIFY更新）：
ReaderSettings.screen管理系统栏、方向与安全区普通偏好，使用reader_规范键和同一仓储逐字段更新，
不迁移旧值。状态信息统一配置在pageLayout页眉/页脚，不再有独立状态条。
系统栏临时覆盖、原方向编码、Rust/FRB、JS快照与数据库保持。

剩余阅读设置（READER-SETTINGS-CLEANUP-20261015）：ReaderSettings.autoChangeSource默认true、
showTitleAddition默认true，update按字段保存；screen.keepScreenOnSeconds默认0，
updateScreen接受-1/0/60/300/600秒，分别为常亮/系统/1分钟/5分钟/10分钟。
三项仅使用reader_auto_change_source、reader_show_title_addition、reader_keep_screen_on_seconds。
showTitleAddition保留读取与存储定义，界面继续禁用。
保持亮屏（READER-KEEP-AWAKE-20261021）：沿用现有键与枚举，使用wakelock_plus执行屏幕防休眠。
0不阻止系统熄屏，-1在阅读器前台可见时常亮；正数从进入/返回阅读器或最近一次阅读触摸开始计时，
到期仅解除防休眠，由系统决定实际熄屏时间，不调用强制关屏，也不减去系统自动锁屏时长。
更改时长立即重新计时；其他设置变化、重建、朗读进度与自动翻页不重置计时。
独立页面覆盖、应用非resumed或阅读器退出时解除；弹出阅读设置等浮层仍属于阅读会话。
平台调用串行化并按页面所有者汇总，过期请求不能恢复已退出页面的亮屏；平台失败记录并可在后续交互重试。
该能力不改变朗读的PARTIAL_WAKE_LOCK、媒体后台保活、Rust/FRB签名或数据库。
ReaderAdvancedConfig、readerAdvConfigProvider、loadAdvanced/saveAdvanced及独立高级队列删除，
设置界面不再接收或回传整份高级快照；自动换源读取共享当前值，原执行策略保持。
备份忽略及reload覆盖三项，不迁移旧值。Rust/FRB、JS快照、数据库保持不变。

菜单配色与亮度控件（READER-MENU-SETTINGS-20261015）：ReaderSettings新增menuTheme与
brightnessControl两个不可变分组，分别由updateMenuTheme和updateBrightnessControl逐字段更新。
菜单来源0跟随应用/1阅读背景/2自定义，生成方式0种子/1手动；日夜ARGB颜色零值沿用现有回退。
亮度控件0关闭/1横向/2纵向，onLeft默认false；关闭或横向时保留侧栏位置，不修改实际亮度。
13项直接使用reader_规范键，不读旧值、不补写默认；菜单主题、标题颜色及侧栏均消费共享快照。
日夜编辑选择不持久化；旧高级快照不得覆盖已迁字段。通用UiSettings中无消费者的旧亮度
竖条开关和位置字段同时移除，不迁入无效值。Rust/FRB签名、JS快照和数据库不变。

翻页与操作分组（READER-INTERACTION-SETTINGS-20261015）：ReaderSettings新增autoPageTurn
与interaction，十二项偏好经同一仓储逐字段保存；九宫格StringList使用动作枚举名称。
不读取旧索引列表或三列键，不回写兼容副本；点击命中与平台动作仍由Flutter层处理。
原默认、范围、定时器方向与间隔语义保持，Rust/FRB、JS配置快照及数据库不变。
StringList进入共享快照前转为SettingsStringList不可变配置值，Preferences仍用
setStringList落盘；不扩展共享快照承载实体列表、凭据或可变集合。

| `set_image_cache_dir` | dir（应用缓存目录下 `image_cache` 子目录，P4-2a） | 与 `set_cache_dir` 同型的进程注入（`set_cache_dir` 服务 JS 缓存）：`saveImageCache`/`getImageCache`（§2.46）图片磁盘缓存落应用私有缓存目录；未注入时回落 `<temp_dir>/legado-image-cache`（一次性告警）。Dart Bootstrap 经平台环境获取路径，再调用 Bridge 注入 |
| `set_audio_cache_dir` | dir（应用缓存目录下 `audio_cache` 子目录，B1） | 与 `set_image_cache_dir` 同型：`audioCacheQuery`/`audioCacheList`/`audioCacheClearChapter`/`audioCacheClearBook`（§2.47）音频章节文件缓存读取与 `audioCacheDownload`/`audioCacheCancel`（§2.48，B2）写入**共用此根目录**（写读同根同键）；未注入时回落 `<temp_dir>/legado-audio-cache`（一次性告警）。Dart Bootstrap 经平台环境获取路径，再调用 Bridge 注入 |

> 注入键集合约定（R 批 R5 登记）：`set_theme_config` JSON 必需键 `themeName/isNightTheme/primaryColor/accentColor/backgroundColor/bottomBackground/statusBarColor/navigationBarColor`；可选透传键 `paletteId/背景图路径/blur/圆角覆写` 等（Rust 不解释，原样透传 JS）；注入为进程内存级（RwLock），重启需 Flutter Bootstrap 重注，注入前 JS 调用拿到 wh 默认。
>
> `themeConfigList` 纯 Flutter 持久化（SharedPreferences），Rust 仅见合成后的单主题 JSON，不做调色板解析。
>
> `deleteConfig` 契约登记但 `ffi.rs` 暂无 `config_delete` 导出，布局开关恢复默认约定为 `setConfig(key,"")` 空串语义。

### 1.7 BookApi / FFI 命名等价表（F3-10，2026-08-14）

以下 15 对 Dart `BookApi` 方法名与契约/FFI 登记名不一致，语义等价，计数时勿重复：

| BookApi（Dart） | 契约 §2.x / FFI 登记名 |
|-----------------|------------------------|
| `extractJsSource` | `jsSourceExtract`（§2.37） |
| `checkJsSourceSyntax` | `jsSourceSyntaxCheck`（§2.37） |
| `stampJsSourceLastUpdateTime` | `jsSourceStampLastUpdateTime`（§2.37） |
| `isLoginUiV2` | `sourceIsLoginUiV2`（§2.3） |
| `loginUiV2` | `sourceLoginUiV2`（§2.3） |
| `loginActionV2` | `sourceLoginActionV2`（§2.3） |
| `listCachedChapterUrls` | `cacheListCachedChapterUrls`（§2.43.5） |
| `listCachedChapters` | `cacheListCachedChapters`（§2.43.6） |
| `listDownloadingChapters` | `cacheDownloadRunningChapters`（§2.43.7） |
| `listFailedChapters` | `cacheDownloadFailedChapters`（§2.43.8，2026-10-05 实现批补登记） |
| `getCachedChapter` | `cacheGetChapter`（§2.16 / §2.41） |
| `getLoginHeader` | `sourceGetLoginHeader`（§2.3） |
| `getLoginInfo` | `sourceGetLoginInfo`（§2.3） |
| `putLoginHeader` | `sourcePutLoginHeader`（§2.3） |
| `putLoginInfo` | `sourcePutLoginInfo`（§2.3） |

---

## 2. 方法清单

> 共 **47 个方法模块**（§2.1–§2.50，编号跳过 2.24/2.27）+ §2.44 数据层实现备注；计数由 `tool/check_api_contract.dart` 自动校验。
> BookApi 接口当前共 **97 个方法**（按当前Dart接口声明计数；2026-10-04 B1 将音频缓存 4 方法封装进 BookApi：284→288；2026-10-03 B2 冻结音频预下载写入面 2 方法，契约先行、待实现批封装进 BookApi：288→290；2026-10-05 P2-29c 后续批冻结失败章查询 1 方法，契约先行、待实现批封装进 BookApi：290→291；2026-10-05 V-B1 冻结视频弹幕查询 1 方法，契约先行、待实现批封装进 BookApi：291→292；2026-10-05 V-B2 冻结弹幕解析 1 方法，契约先行、待实现批封装进 BookApi：292→293；2026-10-13 书签七项旧方法迁走：293→286；阅读记录六项旧方法迁走：286→280；HTTP 引擎配置八项旧方法迁走：280→272；HTTP 合成及无调用方包装三项迁走：272→269；书架与分组十五项迁走：269→254；书源十一项迁走：254→243；书源校验三项迁走：243→240；登录凭据四项迁走：240→236；备份四项与WebDAV七项迁走：224→213；阅读目录、正文及进度八项迁走：213→205；章节缓存与批量下载十一项迁走、无消费者旧下载包装七项移除：205→187；RSS批次前语法树复核为188（上一版文档少计一项），RSS源/文章/已读/收藏二十一项迁走：188→167；替换规则配置六项与执行两项迁走：167→159；规则订阅配置五项与更新两项迁走：159→152；正文标注七项与高亮规则四项迁走：152→141；词典查询一项与规则七项迁走：141→133；应用日志五项迁走：133→128；全局缓存五项与数据库维护一项迁走：128→122；书籍内容十四项迁走、无生产消费者包装十一项移除：122→97）。
> 附录按模块登记行合计 **307**（书签导出本批新增一项）。这是文档登记行数，不等于FRB导出方法总数；Dart实际归属以各窄接口为准，旧BookApi拆分过程仅作历史记录。

### 2.1 初始化/版本（2 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `initialize()` | 无 | `Future<void>` | 初始化 Rust 运行时和数据库连接 |
| `getVersion()` | 无 | `Future<String>` | 获取引擎版本号 |

### 2.2 书架操作（11 个方法）

> 以下方法由 BookshelfRepository 承担，根只提供共享引用；正式实现直接 FRB，Mock 与进度、章节和本地导入共用唯一存储。旧 BookApi 方法及临时转发已删除。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getBooks()` | 无 | `Future<List<Book>>` | 获取书架上所有书籍 |
| `addBook(Book book)` | book: Book 对象 | `Future<Book>` | 添加书籍到书架 |
| `setCanUpdate(String bookUrl, bool canUpdate)` | 稳定书籍标识、目标状态 | `Future<Book>` | Rust事务读取最新记录，仅修改自动更新策略及关闭时的更新失败位，返回最新快照；不存在报错 |
| `updateBook(Book book)` | book: Book 对象 | `Future<void>` | 更新书籍信息。Book JSON 的 `readConfig` 承载加法式书级字段：可选 `mangaScrollMode`（书级翻页模式）与 `webtoonSidePaddingDp`（书级条漫侧边留白）——缺失/null = 未覆盖、跟随全局；后者键名沿用参考版（legado-with-MD3）但**单位不是 dp**，值为 Flutter 现行百分比口径 0..45（每侧留白 = 视口宽 × p/100，不做 dp/百分比换算）。Rust `ReadConfig` 类型化接收后全行回写不丢该两字段（旧 JSON 缺键 → None，空值序列化省略）；进度列按既有「不回滚」语义仍由 `update_progress` 单列写入 |
| `deleteBook(String bookUrl)` | bookUrl | `Future<void>` | 从书架删除书籍 |
| `getBook(String bookUrl)` | bookUrl | `Future<Book?>` | 按 bookUrl 获取书籍详情 |
| `topBook(String bookUrl)` | bookUrl | `Future<void>` | 置顶书籍 |
| `unTopBook(String bookUrl)` | bookUrl | `Future<void>` | 取消置顶 |
| `setBookGroup(String bookUrl, int groupId)` | bookUrl, groupId | `Future<void>` | 设置书籍分组 |
| `importBooks(String jsonArray)` | jsonArray: JSON 数组字符串 | `Future<int>` | 批量导入书籍，返回成功导入的数量 |
| `reorderBooks(List<Map<String, dynamic>> orders)` | orders: `[{bookUrl, order}, ...]` | `Future<void>` | 批量持久化拖拽排序（对齐原版 BookAdapter.swap 后 updateBook） |

### 2.3 书源操作（33 个方法）

> 其中列表、启用列表、增改删、启停、导入导出、排序偏好与源变量十一项由 BookSourceRepository 承担；正式/Mock 保持既有存储语义，其他能力仍使用原入口。旧根方法已删除。登录信息/登录头四项由 SourceLoginRepository 承担，动态脚本仍用原入口。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getBookSources()` | 无 | `Future<List<BookSource>>` | 获取所有书源 |
| `getEnabledBookSources()` | 无 | `Future<List<BookSource>>` | 获取所有启用的书源 |
| `addBookSource(BookSource source)` | source: BookSource 对象 | `Future<BookSource>` | 添加书源 |
| `updateBookSource(BookSource source)` | source: BookSource 对象 | `Future<void>` | 更新书源 |
| `deleteBookSource(String sourceUrl)` | sourceUrl | `Future<void>` | 删除书源 |
| `enableBookSource(String sourceUrl)` | sourceUrl | `Future<void>` | 启用书源 |
| `disableBookSource(String sourceUrl)` | sourceUrl | `Future<void>` | 禁用书源 |
| `importBookSources(String jsonArray)` | jsonArray: JSON 数组字符串 | `Future<int>` | 批量导入书源，返回成功数量 |
| `exportBookSources()` | 无 | `Future<String>` | 导出所有书源为 JSON 数组 |
| `sortBookSources(int sortKey, bool ascending)` | sortKey, ascending | `Future<void>` | 书源排序 |
| `sourceIsLoginUiV2(String sourceJson)` | sourceJson: BookSource JSON | `Future<bool>` | 判定登录 UI 是否为 V2 动态状态协议（#402/#488，加法式新增） |
| `sourceLoginUiV2(String sourceJson, String stateJson)` | sourceJson, stateJson（首次传 `"{}"`） | `Future<String>` | 执行 loginUi v2 脚本，返回动态 UI 描述 JSON `{"rows":[RowUi...]}`（#402，加法式新增） |
| `sourceLoginActionV2(String sourceJson, String userInputJson)` | sourceJson, userInputJson | `Future<String>` | 执行 loginAction v2 动作，返回命令 JSON（state/error/login/close）（#402，加法式新增） |
| `sourcePutLoginInfo(String sourceUrl, String infoJson)` | sourceUrl, infoJson: 用户信息 JSON | `Future<void>` | 保存书源登录用户信息（对齐原版 `BaseSource.putLoginInfo` → `userInfo_<key>`；V2 login 命令自动落库 + 手动登录共用）。加法式新增（2026-08-14 发现页修复 R1） |
| `sourcePutLoginHeader(String sourceUrl, String headerJson)` | sourceUrl, headerJson: header map JSON（如 `{"Cookie":"..."}`） | `Future<void>` | 保存书源登录头（对齐原版 `BaseSource.putLoginHeader` → `loginHeader_<key>`；请求路径自动合并）。加法式新增（2026-08-14 发现页修复 R1） |
| `sourceGetLoginInfo(String sourceUrl)` | sourceUrl | `Future<String>` | 读取书源登录用户信息（`userInfo_<key>`），无则空串。加法式新增（2026-08-14 发现页修复 R1） |
| `sourceGetLoginHeader(String sourceUrl)` | sourceUrl | `Future<String>` | 读取书源登录头（`loginHeader_<key>`），无则空串。加法式新增（2026-08-14 发现页修复 R1） |
| `checkSource(String sourceJson, {String? configJson})` | sourceJson: BookSource JSON；configJson(可选): 校验配置 JSON | `Future<Map<String, dynamic>>` | 校验单个书源（搜索→详情→目录→正文四步 + 验证码/重定向检测），返回 CheckResult JSON（Task #87，加法式新增） |
| `checkSourcesStream(List<String> sourceUrls, {String? configJson})` | sourceUrls: 待校验书源 URL 列表（空列表=全部书源）；configJson(可选) | `Stream<Map<String, dynamic>>` | 批量校验书源（串行逐个回推进度，对齐 Kotlin CheckSourceService），每条为 CheckProgress JSON（Task #87，加法式新增） |
| `cancelCheckSources()` | 无 | `Future<void>` | 取消正在进行的批量书源校验（Task #87，加法式新增） |
| `verificationRequestStream()` | 无 | `Stream<Map<String, dynamic>>` | 验证码请求事件流（长期存活，订阅时先回放进行中请求），事件字段：`key` / `source_url` / `source_name` / `image_url` / `title` / `use_browser`（恒 false，已降级）/ `created_at_ms`（Task #90，加法式新增） |
| `submitVerificationResult(String key, String code)` | key: resultKey；code: 用户输入的验证码 | `Future<bool>` | 提交验证码结果唤醒 JS 等待方（对齐 Kotlin `setResult`：空值也唤醒，空值判定在等待侧），返回是否命中进行中请求（Task #90，加法式新增） |
| `cancelVerificationRequest(String key)` | key: resultKey | `Future<bool>` | 取消验证码请求（对齐 Kotlin `checkResult`：以空结果唤醒等待方），返回是否命中（Task #90，加法式新增） |
| `webviewRequestStream()` | 无 | `Stream<Map<String, dynamic>>` | BackstageWebView DOM 执行请求流（长期存活，订阅时回放进行中请求）。事件字段：`key` / `action` / `html` / `url` / `js` / `source_regex` / `override_url_regex` / `cache_first` / `delay_time` / `is_rule` / `result` / `created_at_ms` / `source_key` / `cookie`（SOURCE_DIFF P1 加法式新增；`source_key` / `cookie` 为项 B 加法式字段（B1 sourceKey 补全 / B4 请求域预填），`serde(default)` 空串缺省，旧端忽略未知字段） |
| `submitWebviewResult(String key, String result)` | key: resultKey；result: WebView 执行结果（可空） | `Future<bool>` | 提交 DOM 执行结果唤醒 Rust 等待方，返回是否命中（SOURCE_DIFF P1，加法式新增；项 B/B1 起 cookie 回流场景改调 `submitWebviewResultWithCookies`，本方法冻结不动） |
| `submitWebviewResultWithCookies(String key, String result, String cookiesJson)` | key: resultKey；result: WebView 执行结果；cookiesJson: cookie 回流 JSON 对象（`{"<url 或域键>": "k1=v1; k2=v2"}`，空串 / `{}` = 无回流） | `Future<bool>` | 提交 DOM 执行结果并回流域 cookie（项 B/B1，加法式新增）：Rust 侧对每个域键按 ETLD+1 归一（`cookie_store::normalized_cookie_key`）merged upsert 落 `cookies` 表，并同步 JS 桥共享客户端内存 CookieStore（quickjs 构建重置共享池；复用 http_state 落库/锁序口径），**先持久化后唤醒**等待方；不相关域键不落行（P2-19 口径）。双轨均归我方、加法式，旧端忽略未知字段；Android 原生 `backstageEval` 加法式返回 `{"result","cookies"}` 信封（无 cookie 时纯结果串，旧版语义不变），非 Android 回退路径经 `document.cookie` 尽力读取（仅非 HttpOnly，仅 webView 主路径） |
| `cancelWebviewRequest(String key)` | key: resultKey | `Future<bool>` | 取消 WebView 请求（空结果唤醒），返回是否命中（SOURCE_DIFF P1，加法式新增） |
| `setSourceVariable(String sourceUrl, String variable)` | sourceUrl: 书源 URL；variable: 自定义变量内容（空串=清除） | `Future<void>` | 设置书源自定义变量（对齐原版 `source.setVariable`），单列 UPDATE 语义仅更新 `variable` 单列，规避 `updateBookSource` 全行更新风险；variable 为空串表示清除该变量。错误码：Internal（书源不存在）/ Db（写入失败）。**DB schema 变更预告**：`book_sources` 表补 `variable` 列（幂等迁移，SCHEMA_VERSION 102→103）（台账 §5.11-3，第三批后置项，Task #63，加法式新增） |
| `clearCookie(String url)` | url: 书源/订阅源 URL（或任意含域名的地址） | `Future<void>` | 清除该 URL 所属二级域名的 Cookie（对齐原版 `CookieStore.removeCookie` / 编辑页 `menu_clear_cookie`）。清除范围：① cookies 表持久层；② 共享 HTTP 客户端内存 CookieStore；③ JS 宿主 `java.clearCookies`（内存表 + 其**落库行**——2026-09-23 起 JS 写入的 cookie 亦落 `cookies` 表，按 ETLD+1 域键持久化并在进程启动时回填；该域的持久行随本入口一并清除）。差距说明：原版另清 WebView Cookie / 会话 CacheManager，本实现无独立 WebView Cookie 层（与 MCP `clear_cookies` 一致）。url 为空 → Internal。加法式新增（2026-08-12 P1-2） |
| `looksLikeCurl(String text)` | text: 待判定文本 | `Future<bool>` | 判断是否形似 cURL 命令（对齐 `CurlAnalyzeUrlConverter.looksLikeCurl`）。加法式新增（2026-08-12 P1-14） |
| `curlToAnalyzeUrl(String text)` | text: cURL 命令 | `Future<String>` | cURL → AnalyzeUrl 模板（`url` 或 `url,{options}`）。错误消息含 `[CURL_*]` 前缀。加法式新增（2026-08-12 P1-14） |
| `analyzeUrlToCurl(String text)` | text: AnalyzeUrl 模板 | `Future<String>` | AnalyzeUrl → cURL 命令。错误消息含 `[CURL_*]` 前缀。加法式新增（2026-08-12 P1-14） |
| `sourceCallBackBtn({required String event, required String bookUrl, int? chapterIndex, String? result, int bookType = 0})` | event, bookUrl, chapterIndex(可选), result(可选), bookType | `Future<Map<String, dynamic>>` | 书源 callBackBtn JS（对齐 SourceCallBack）；返回 `invoked` / `jsTrue` / `raw` / `actions`（F3-10 补登记） |

> ℹ️ **登录 UI V2 动态状态协议（#402/#488）**：Rust 侧 `ffi::source_is_login_ui_v2 / source_login_ui_v2 / source_login_action_v2`（核心实现 `legado-core/src/login_ui_v2.rs`，对齐 Kotlin `LoginUiV2.kt` + `BaseSource.evalLoginUiV2/evalLoginActionV2`）。`loginUi` 为 `{"version":2}` 标记时启用；登录脚本取自 `mainJs`（JS 单文件书源）或 `loginUrl`，须实现 `loginUi(state)` / `loginAction(action, state, form)`。`userInputJson` 契约：`{"action":"...","stateJson":"...","formJson":{...}}`（stateJson/formJson 支持字符串或对象）。JS 返回 null/undefined 时返回空字符串；需 quickjs 特性构建。RowUi V2 扩展字段：key/hint/value/options/countdown。冻结契约保持不变，本组方法为加法式新增。
>
> ℹ️ **书源校验（Task #87）**：Dart 三项能力由 SourceChecker 承担，正式/Mock 共用根装配引用，旧 BookApi 方法删除；Notifier 的开始与取消绑定同一实例，迟到进度不影响新会话。Rust 侧 `ffi::source_check / source_check_stream / source_check_cancel`（核心实现 `legado-ffi/src/api/source_check_api.rs`，包装 `legado-net::source_checker::SourceChecker`，与 legado-server `/sources/check` 同源）。`checkSource` 返回 CheckResult JSON：`source_url` / `search_ok` / `toc_ok` / `content_ok` / `search_error` / `toc_error` / `content_error` / `total_time_ms` / `captcha`（detected/captcha_type/matched_keyword）/ `redirect`（redirected/original_url/final_url/is_login_redirect）。`checkSourcesStream` 每完成一个书源推送一条 CheckProgress JSON：`index` / `total` / `is_last` / `source_name` / `result`（CheckResult）；**串行**校验（对齐 Kotlin `CheckSourceService` flow 顺序执行，避免对书源站并发压力），不存在的书源推送失败结果而非跳过（序号连续）。`configJson` 契约：`{"keyword":String,"step_timeout_ms":int,"check_search":bool,"check_toc":bool,"check_content":bool,"detect_captcha":bool,"detect_redirect":bool}`，全部字段可选，缺省回落 CheckerConfig 默认值（keyword="我的"、step_timeout_ms=180000、其余全开）。冻结契约保持不变，本组方法为加法式新增。
>
> ℹ️ **验证码交互通道（Task #90）**：Rust 侧 `ffi::verification_request_stream / verification_submit / verification_cancel / verification_pending`（核心实现 `legado-core/src/verification_channel.rs`，对齐 Kotlin `SourceVerificationHelp` + `JsExtensions.getVerificationCode/startBrowserAwait`）。JS 书源经宿主 API 钩子挂起等待（std condvar 阻塞 JS 工作线程，不占用 tokio runtime，默认超时 5 分钟对齐 Kotlin）；同书源并发请求经航班去重共享结果（空 source_url 匿名请求不去重）；`use_browser` 一律降级为图片验证码（桌面端无 WebView）。`verificationSubmit` 无论 code 是否为空都唤醒等待方（对齐 Kotlin `setResult`），空值由等待侧报「验证结果为空」；`verificationCancel` 等价 Kotlin `checkResult`（空结果唤醒）；超时返回「source verification timed out」。订阅事件流时先回放当前进行中的请求。冻结契约保持不变，本组方法为加法式新增。
>
> ℹ️ **BackstageWebView DOM 通道（SOURCE_DIFF P1）**：Rust 侧 `ffi::webview_request_stream / webview_submit / webview_cancel / webview_pending`（核心 `legado-core/src/webview_channel.rs`）。Flutter `WebViewBridgeListener` 订阅后，`@webjs` / 正文 `contentRule.webJs` / `java.webView*` 经真实 WebView 执行并回传；无订阅者时回退无头 QuickJS 或历史桥接载荷（`interceptResult`）。默认超时 60s，规则级 Mode.WebJs 10s。**Android**：`PlatformBridgeService`→原生 `legado/webview.backstageEval`：`cacheFirst`→`WebSettings.LOAD_CACHE_ELSE_NETWORK`；`isRule`+html 时注入 `java`/`source`/`cache` JavascriptInterface（变量读写与精简同步 API；ajax 等网络类仍建议无头宿主）。非 Android 回退 `webview_flutter`（无 cacheMode）。加法式新增。
>
> ℹ️ **项 B/B1 WebView cookie 回流 + sourceKey 补全（2026-09-26，加法式，零破坏）**：Rust 侧新增 `ffi::webview_submit_result_with_cookies`（Dart `submitWebviewResultWithCookies`）——WebView 执行结果 + 域 cookie 回流：cookiesJson 每个域键按 ETLD+1 归一（`cookie_store::normalized_cookie_key`，不相关域不落行，P2-19 口径）merged upsert 落 `cookies` 表 + 同步 JS 桥共享客户端内存 CookieStore（quickjs 构建重置共享池，复用 http_state 落库/锁序口径），先持久化后唤醒等待方；`WebViewRequest` 事件加法式字段 `source_key`（JS 执行线程当前书源 key，缺省空串）/ `cookie`（B4 起按请求域预填，缺省空串），`serde(default)` 空串缺省、旧端忽略未知字段不破坏反序列化。Android 原生 `backstageEval`：注入接口口径由 `isRule` 扩为「`isRule` 或 `sourceKey` 非空」（对齐上游 tag 语义）；结果确定时（onPageFinished 首次命中 + 最终 eval 前）`CookieManager.getCookie(finalUrl)` 读取并随结果回传，返回值加法式改为 `{"result","cookies"}` 信封（cookie 为空时仍返回纯结果串，旧版 loadUrl/evaluateJs 通道语义不变）；非 Android 回退路径 `document.cookie` 尽力读取（仅非 HttpOnly，仅 webView 主路径，嗅探动作空串）。旧 `webviewSubmit`（`submitWebviewResult`）冻结不动。

### 2.4 搜索操作（19 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `searchBooks(String keyword, {List<String>? sourceUrls})` | keyword, sourceUrls(可选) | `Future<List<SearchResult>>` | 搜索书籍 |
| `preciseSearch(String name, String author, {List<String>? sourceUrls})` | name, author, sourceUrls(可选) | `Future<SearchBook>` | 精确搜索（对齐 `WebBook.preciseSearchAwait`）：启用源中搜书名，返回首个 name+author 完全匹配的 SearchBook JSON；未命中抛错（SOURCE_DIFF P0-2） |
| `searchMulti(String query, {List<String>? sourceUrls})` | query, sourceUrls(可选) | `Future<List<Map<String, dynamic>>>` | 多源并行搜索 |
| `searchMultiStream(String query, {List<String>? sourceUrls, int page = 1})` | query, sourceUrls(可选), page(默认 1) | `Stream<Map<String, dynamic>>` | 多源渐进式（流式）搜索：每完成一个书源即推送一个批次，无需等待最慢书源；批次事件含 `has_more` 字段（累积值）。**批次B breaking**：新增 `page` 入参透传（同关键词翻页 searchPage++，新关键词重置为 1，对齐原版 SearchModel.kt L73-75）；批次事件另加 `error_class?` 逐源错误八分类字段（2026-09-19 加法式，`error?` 语义冻结不变） |
| `cancelSearch()` | 无 | `Future<void>` | 取消搜索（硬取消，批次A） |
| `pauseSearch()` | 无 | `Future<void>` | 暂停流式搜索（软挂起：未派发书源挂起、已派发任务继续完成；状态/进度保留，可 resume。G-B-04，对齐原版 workingState 门控语义 SearchModel.kt L45/L98/L227-233） |
| `resumeSearch()` | 无 | `Future<void>` | 恢复已暂停的流式搜索（G-B-04） |
| `searchSource(String bookName, String author, {List<String>? sourceUrls, bool loadInfo = false, bool loadToc = false, bool loadWordCount = false, bool forceRefresh = false})` | bookName, author, sourceUrls(可选), loadInfo, loadToc, loadWordCount, forceRefresh | `Future<List<Map<String, dynamic>>>` | 搜索可替换的书源 ⚠️ 双兼容点（留项#12/Task #131：`sourceUrls` 为加法式新增可选参数，null/空=搜全部启用源；`forceRefresh` 默认 false 优先复用 searchBooks） |
| `searchSourceStream(String bookName, String author, {List<String>? sourceUrls, bool loadInfo = false, bool loadToc = false, bool loadWordCount = false, bool forceRefresh = false})` | bookName, author, sourceUrls(可选), loadInfo, loadToc, loadWordCount, forceRefresh | `Stream<Map<String, dynamic>>` | 换源搜索流式（Task #156 / T6）：逐源完成即推一批次事件，首批候选 <5s 到达（500+ 源规模验收线）；批次事件含 `source_index` / `source_url` / `source_name` / `error?` / `finished_count` / `total_count` / `is_last` / `matches[]`（`matches` = 当前已过滤评分排序候选**全量快照**，Rust 侧维持过滤/排序、UI 仅替换展示）；DB 复用路径（forceRefresh=false 且库有数据）推单批即结束；enrich 开启时搜索阶段结束后再推一批 enriched+重排快照（不阻塞首批到达）。旧 `searchSource` 保留兼容 |
| `searchCover(String bookName)` | bookName | `Future<List<Map<String, dynamic>>>` | 搜索书籍封面候选列表：复用多书源搜索提取封面 URL，每项字段 `url` / `width` / `height`（未知尺寸填 0），无候选返回空列表 |
| `switchSource(String bookUrl, String newSourceUrl, String newBookUrl)` | bookUrl, newSourceUrl, newBookUrl | `Future<String>` | 切换书源 |
| `switchSourcePrefetch(String bookUrl, String newSourceUrl, String newBookUrl)` | bookUrl, newSourceUrl, newBookUrl | `Future<String>` | 切换书源（预拉缓存版，2026-09-24 换源感知等待，加法式新增）：命中搜索期预拉缓存（`SwitchPrefetchCache`，key = `newSourceUrl\u0000newBookUrl`，对齐上游 `primaryStr()`）→ 缓存详情+目录**零网络**直接提交（选中即落地）；部分命中（有 info 无 chapters）→ 仅补抓目录；未命中 → 现场抓取详情+目录（执行链同 `switchSource`，且提交前可经 `cancelSwitchSourceApply` 取消，取消后 DB 零变更）；返回新 bookUrl JSON |
| `cancelSwitchSourceApply()` | 无 | `Future<void>` | 取消进行中的「换源（预拉缓存版）」apply（对齐上游 `cancelChangeSource`，ChangeBookSourceViewModel.kt L715-721）：换源 apply 代数 +1 并 bump 目录刷新代数——未提交 apply 在提交前代数比对即中止（DB 零变更），在途目录分页链在下一页边界中止 |
| `updateSearchBookScore(String bookUrl, int score)` | bookUrl, score（-1/0/1） | `Future<void>` | 更新换源列表项用户评分（对标原版 `SourceConfig.setBookScore`，持久化 `searchBooks.bookScore` 并同步书源聚合分） |
| `deleteSearchBook(String bookUrl)` | bookUrl | `Future<void>` | 删除换源列表项（对标换源页长按「删除」，按 bookUrl 移除 `searchBooks` 行） |
| `searchCoverRules(String name)` | name: 书名（作为规则搜索关键词，对齐原版 `BookCover.searchCover(book)` 传 `book.name` 语义） | `Future<String>` | 按书名执行 coverRules 表中全部启用规则搜封面（JS 搜索规则语义对齐原版 `BookCover.searchCover` 链路），返回候选封面 URL **裸 JSON Array**（遵守 §1.4 铁律）；无启用规则/无候选返回空数组（非异常）；单规则失败隔离（记日志跳过，不阻断其余规则）。错误码：Internal（coverRules 规则数据读取失败）（台账 §5.13-10，第四批后置项，Task #72，加法式新增） |
| `getCoverRule()` | 无 | `Future<String>` | 读取封面规则配置（对齐原版 `BookCover.getCoverRule`）：返回裸 JSON 对象 `{enable, searchUrl, coverRule}`；表空时回退 `DefaultData.coverRule`（assets 同源）。错误码：Internal |
| `saveCoverRule(String ruleJson)` | ruleJson: `{enable, searchUrl, coverRule}` | `Future<bool>` | 保存封面规则（对齐原版 `BookCover.saveCoverRule`）：写入 coverRules 表（单配置语义，REPLACE 主配置行）；searchUrl/coverRule 为空 → Internal。F4 |
| `deleteCoverRule()` | 无 | `Future<bool>` | 删除用户封面规则配置（对齐原版 `BookCover.delCoverRule`）：清空 coverRules；随后 `getCoverRule` 回退默认。F4 |

> ⚠️ `searchSource`：Rust 返回 `SourceSwitchResponse { book_name, author, matches[] }`，Dart 侧提取 `matches` 字段。
>
> ℹ️ **换源变量链与执行链对齐（2026-09-03，换源修复任务书 T2/T3/T4/T5，均为加法式）**：
> ① `searchSource` 返回的 `matches[]` 项新增可选字段 `variable`（string，JSON 对象文本；搜索期 `@put`/`putVariable` 级联变量，对齐原版 `SearchBook.toBook()` 复制 variable 语义）；`loadInfo` 开启时 enrich 阶段将详情页导出变量合并入候选 `variable`（详情页后写入者优先）。
> ② `webbookInfo` 返回 JSON 新增可选字段 `variable`（bookInfo 规则求值期间 `@put`/JS `putVariable` 级联导出，与目录解析同一机制；原版无专用 variable 规则字段）。
> ③ `search_books`/`searchSingleSource`/`searchMulti*` 的结果项与 `searchBooks` 表持久化新增/启用 `variable` 透传（元素级解析导出，additive）。
> ④ `switchSource` 签名不变，行为对齐原版 `ChangeBookSourceViewModel.getToc`：先经新源详情解析（canReName=false 保留既有书名/作者，cover/intro/kind/lastChapter/wordCount 按非空更新），以解析出的**真实 tocUrl**（ruleBookInfo.tocUrl，可与详情页不同）取目录；详情或目录任一步失败 → 换源整体失败并保留旧源（单事务回滚，禁止拿 new_book_url 硬闯目录）；`book.variable` = 候选搜索期变量（searchBooks 行）与详情页导出变量合并（详情页后写入者优先，对齐原版覆盖语义）；章节落库保留解析值（`variable`/`isVolume`）。
>
> ℹ️ `searchSource` 分组/书源范围过滤（留项#12，Task #131 闭合）：Rust 侧 `ffi::source_switch_search(book_name, author, source_urls_json)` 新增第三个参数 `source_urls_json`（JSON 字符串数组；空串/空数组/缺省=搜全部启用源，语义与 `search_books` 的 `source_urls_json` 完全一致，复用 `search::load_search_sources` 过滤逻辑）。C ABI `ffi_source_switch_search` 同步加参。Dart 侧 `searchSource` 新增可选命名参数 `sourceUrls`，由 `rust_api` 编码为 `sourceUrlsJson` 传入；换源页按 `AppConfig.searchGroup` 内存过滤出该分组源 URL 列表后传入。冻结契约返回结构不变，本变更为加法式新增。
>
> ℹ️ `searchSource` 分组 config 原生过滤（留项#12 增强，Task #145，**零签名变更**）：Rust 侧 `source_switch::resolve_switch_sources` 内部读取 config `searchGroup`（键名对齐原版 `AppConfig.searchGroup`，UI setConfig 已通），非空时对齐原版 `getEnabledPartByGroup` 的 `SOURCE_GROUP_MEMBERSHIP_FILTER` SQL 语义过滤：分组字段按 `,`/`;`/`，`/`；` 规范化拆分、逐组名 trim 后与目标分组精确相等匹配（非子串）；空分组=全部启用源。过滤后零结果由 UI 弹「xx分组搜索结果为空，是否切换到全部分组」对话框（对标 ChangeChapterSourceDialog L90-97，确认后清空 searchGroup 重搜）。
>
> ℹ️ `searchSource` 换源高级选项（审计 F2-2，**加法式新增**）：Rust 侧 `ffi::source_switch_search` 第四参 `options_json` 为 JSON 对象 `{loadInfo,loadToc,loadWordCount}`；Dart `searchSource` 三命名参数编码传入。空串/缺省时 Rust 回退读取 config `changeSourceLoadInfo`/`changeSourceLoadToc`/`changeSourceLoadWordCount`（键名对齐原版 AppConfig）。`loadInfo` 触发详情页补全；`loadToc`/`loadWordCount` 触发目录抓取；`loadWordCount` 另试读末章正文计字数并按原版 `wordCountComparator` 排序。返回 `matches[]` 项新增可选字段 `chapter_word_count_text` / `chapter_word_count` / `respond_time` / `origin_order` / `book_score`（snake_case，用户评分 -1/0/1，对标原版 SearchBook.bookScore）。

> ℹ️ `searchSource` 复用搜索缓存（**加法式**，`forceRefresh`）：对齐原版 `ChangeBookSourceViewModel` 先 `getDbSearchBooks` 再条件 `startSearch`。搜索流式/一次性结果写入 `searchBooks` 表；换源默认读库复用（`forceRefresh=false`），「刷新列表」等传 `forceRefresh=true` 才强制全量网络重搜。Dart `searchSource` / 换源页进入默认不二次搜索。
>
> ℹ️ **换源搜索流式化（Task #156 / T6，加法式）**：Rust 侧 `ffi::source_switch_search_stream(book_name, author, source_urls_json, options_json, sink: StreamSink<String>)`（frb 生成 Dart `Stream<String>`），驱动复用 `search::drive_source_batches`（并发 32、单源超时 60s、逐源隔离，与主搜索同构）。每完成一个书源推送一个 `ChangeSourceBatch` JSON：`source_index` / `source_url` / `source_name` / `error?` / `finished_count` / `total_count` / `is_last` / `matches[]`——**`matches` 为当前累积候选经同名过滤（+可选作者校验）与评分排序后的全量快照**（逐源增量过滤 ≡ 批量过滤，元素级判定），Rust 侧维持过滤/排序职责、UI 仅按批替换展示。单源错误以 `error` 字段随该批次推送（不中断流）；全部完成后：① `options.needs_enrichment()` 时**流内后置 enrich**——对累积候选补详情/目录后推最后一批 enriched+重排快照（首批到达不受阻塞，对齐任务书「enrich 改流内后置或仅对展示项懒加载」）；② `persist_switch_matches` 落库最终排序结果。DB 复用路径（forceRefresh=false 且 searchBooks 有数据）：读库评分排序后推**单批**（`finished_count=total_count=1`、`is_last=true`）即结束，不发起网络搜索；forceRefresh=true 先清库再全量重搜。旧 `searchSource`（一次性）保留兼容，两 API 共享同一执行链与落库语义。
>
> ℹ️ `searchMultiStream`：Rust 侧 `ffi::search_multi_stream(query, source_urls_json, page, sink: StreamSink<String>)`（frb 生成 Dart `Stream<String>`），每完成一个书源推送一个 `SearchSourceBatch` JSON：`source_index` / `source_url` / `source_name` / `books[]` / `error?` / `error_class?` / `finished_count` / `total_count` / `is_last` / `has_more`（累积值：任一已推送批次非空即 true，对齐原版 SearchModel `hasMore = hasMore || items.isNotEmpty()` 语义）。**批次B breaking 变更**（双轨评审记录：本重构 Rust/Flutter 两轨均归我方所有 + 用户已批准批次B范围）：签名新增 `page: i32` 入参——页码透传至 `build_search_url_with_setup` 第三参及 JS 书源 `orch.search`（原硬编码 page=1），Dart 侧同关键词翻页传 `searchPage++`、新关键词重置为 1。加法式新增：`pauseSearch()` / `resumeSearch()`——Rust 侧 `SEARCH_PAUSED` 门控位于单源派发前（信号量 permit 后、search_one 前；已派发任务继续完成、未派发书源挂起，状态/进度全部保留），新搜索开始时自动解除暂停。冻结契约 `searchMulti` / `cancelSearch` 保持不变。**逐源错误八分类（任务书 B P2 项1，2026-09-19，加法式，零破坏）**：批次 JSON 新增可选字段 `error_class`（字符串枚举，八类：`ok` / `empty` / `http_error` / `timeout` / `login_required` / `js_error` / `parser_error` / `cancelled`），Rust 侧分类在批次组装单点完成（`run_multi_stream` 批次闭包对 `LegadoError` 变体映射，不可归类的落到最近类别并在报告说明）；现有 `error?` 字段及其语义保持不变（冻结约束），不读该字段的旧调用方零破坏；`#[serde(default)]` 兼容历史批次反序列化（历史批次无此字段时回退空串，Rust 侧发出的批次恒为八类之一）。**双轨确认记录（一句）**：本变更 Rust/Flutter 双轨均归我方——Rust 仅批次 JSON 加法式扩展；Flutter 侧 `ffi.dart` 批次事件解析加法式同步，UI 展示已落地（队列④ P1-B，2026-09-22：单源失败累积 `SearchState.failedSources` 并在搜索结果页顶部以非阻断横幅呈现，既有批次消费路径不变）。
>
> ℹ️ **跨源聚合单一真源（队列⑩a P1-1 项2，2026-09-22，加法式，零破坏）**：`SearchSourceBatch.books[]` 元素（`CoreSearchBook`）新增可选字段 `origins`（string 数组，`#[serde(default, skip_serializing_if = "Vec::is_empty")]`——空时序列化省略，**既有批次 JSON 形态零变化**）。填充路径：Rust 跨源聚合入口 `legado_ffi::api::search::aggregate_search_books_json(books_json, key, keep_other)`（FFI crate 内 pub 函数，非 FRB 暴露；`legado-core::search_aggregate::aggregate_search_books` 纯函数为单一真源，语义与 Dart **纯函数** `applyPrecisionSearch`（`search_state.dart` L144-207）逐条对齐——同名同作者跨源合并、origins 并集累加（首次出现序，同源不重复计数）、`hasReadRecord` 跨源 OR、桶序 equal→tags→contains→(keep_other) other、桶内 originsCount 降序 + 首次到达索引平局、空 key 原样返回；**P2-20 裁决后（2026-09-22 收敛）三条路径（纯函数 / `SearchNotifier` 增量桶 / Rust 单一真源）已统一到同一语义——限定在**同一输入列表内**：入桶前跨桶预去重（seen 键为**原始** `(name, author, origin)` 三段，与 `_seenKeys` 逐字一致），同一三元组仅**首次到达**入桶、**落桶由首次到达决定**，后续同键到达丢弃（其 origin 已由首条代表，跨源计数由桶内 `origins` 集合承载）；纯函数与 Rust 入口已补 `seen` 门控，夹具 `keep_other` expected 8→7 条（若回退为无 seen 的四桶独立实现，该 case 由 7 变 8 条、夹具变红——回归保护）。**范围限定（必读）**：该统一仅对**单次调用的输入列表**成立——运行时 `_seenKeys` 为**会话级跨页**去重（跨页 APPEND 不清空，直至新关键词/清空），纯函数 / Rust 入口是**单次调用**语义、不携带会话状态；未来若把运行时聚合切到 Rust 入口，须传**会话累积列表**（会话内全部 books）而非单批 `SearchSourceBatch.books[]`，否则跨页同键书会重复计数（跨页重复回归）。既有 `searchMultiStream` / `searchMulti` 流式批次与解析路径**不填充**该字段（恒为空 → 省略序列化），旧消费方零破坏。Dart 侧 `SearchBook.origins`（`@Default([])`）加法式消费：`SearchResult.fromSearchBook` 非空时优先作为有效 origins（对齐 Rust `effective_origins`：origins 非空→用它；否则 origin 非空→`{origin}`；全空→空集合，计数下限 1）；Dart 运行时增量桶聚合路径不变（切换评估见更新记录 2026-09-22 行③）。跨端夹具：`rust/legado-ffi/tests/fixtures/search_aggregate/cross_source_merge.json`（Rust 集成测试 + Dart 单测双端比对，锁定两端聚合等价，不依赖真网络）。
>
> ℹ️ **封面规则搜索（台账 §5.13-10，Task #72）**：原版实现为单条封面规则配置——Kotlin `BookCover.searchCover(book)` 读取 `CoverRule(enable, searchUrl, coverRule)`（用户配置存 CacheManager，缺省回退 `DefaultData.coverRule`，UI 入口 `CoverRuleConfigDialog`），以 `AnalyzeUrl(searchUrl, book.name)` 发起搜索请求，再经 `AnalyzeRule.getString(coverRule, isUrl=true)` 提取封面 URL。本轨差异与对齐方案：规则载体为 `legado-db` 既有 `coverRules` 表（`id` / `name` / `rule` / `enable`，默认数据注入已就位），执行全部 `enable=1` 规则；规则执行复用既有书源搜索/JS 执行基础设施（`legado-net` HTTP 抓取 + `legado-parser`/quickjs 规则解析链路，与 `dictLookup` 字典规则执行同模式），`rule` 文本承载 searchUrl 与提取规则（具体内联格式由 Rust 轨实施时按表内既有数据确定）；单规则失败隔离不阻断其余；与既有 `searchCover`（多书源搜索提取封面）互补并存、互不影响。冻结契约保持不变，本方法为加法式新增。
>
> ℹ️ **换源预拉缓存与感知等待（2026-09-24，加法式，零破坏）**：对齐上游 Android `ChangeBookSourceViewModel`「换源感知等待」方案三步——① **搜索期并行预拉**：`searchSourceStream` / `searchSource` 的 enrich 阶段对候选做内存预拉缓存写入（`SwitchPrefetchCache`，`source_switch.rs`）——有界并发 `ENRICH_CONCURRENCY = 8`（上游 threadCount=32 覆盖「搜索+enrich」全链，本轨搜索期已是 32 宽，enrich 为重目录突发，收敛到 8 防连接池饱和），单候选超时复用 `search::SWITCH_SOURCE_TIMEOUT`（60s），单候选失败/超时回退原候选直通、不阻断整批（对齐上游 per-source `try/catch + ensureActive`）；缓存条目 `{info: Option<WebBookInfo>, chapters: Vec<WebChapter>}`，key = `new_source_url\u0000new_book_url`（对齐上游 `primaryStr()` = origin+bookUrl 拼接，`\u0000` 分隔防拼接边界歧义），总目录数上限 `PREFETCH_CACHE_MAX_CHAPTERS = 30000`（超限条目跳过、不计入配额）；② **选中命中零网络**：`switchSourcePrefetch`（§2.4 加法式新增）——完整命中（chapters 非空）→ 缓存详情+目录直接提交，**零网络、选中即落地**；部分命中（info 有、chapters 空）→ 仅补抓目录（2a 跳过）；未命中 → 现场抓取详情（2a）+目录（2b），执行链与 `switchSource` 同构（`switchSource` 本体签名与行为冻结不变）；③ **可取消加载态**：`cancelSwitchSourceApply`（§2.4 加法式新增，对齐上游 `cancelChangeSource` L715-721）——`SWITCH_APPLY_EPOCH` 代数 +1 并同步 bump 目录刷新代数（`bump_toc_fetch_epoch`）：在途 apply 在详情前/目录前/提交前三点代数比对即中止（`Err("换源已取消")`，DB 零变更），在途目录分页链在下一页边界中止；Flutter 换源页 apply 在途展示可取消加载态（spinner + 取消钮）。**双轨确认记录（一句）**：本变更 Rust/Flutter 双轨均归我方——Rust 仅 `source_switch.rs` 增 `SwitchPrefetchCache`/`SWITCH_APPLY_EPOCH`/`cancel_switch_apply` + FFI `source_switch_apply_prefetch`/`source_switch_apply_cancel` 两个新导出；Flutter 侧 `BookApi.switchSourcePrefetch`/`cancelSwitchSourceApply` + RustApi/MockBookApi 实现 + 换源页进度串对齐上游 zh「结果 %1$d, 当前进度 %2$d / %3$d: %4$s」（values-zh/strings.xml:1457 + ChangeBookSourceDialog.kt L286-298）与可取消加载态；`reloadAfterSourceChange` 链、进度保持、本地书隐藏入口、`switchSource` 既有行为均不变。§2.4 方法数 17→**19**，附录合计 278→**280**，BookApi 口径 275→**277** |

### 2.5 RSS 源操作（11 个方法）

**Dart访问边界（2026-10-16）**：源增删改、启停与导入导出八项由`RssSourceRepository`提供；文章获取与清缓存两项由`RssArticleRepository`提供。启停读取原RSS实体并调用既有`rssUpdateSource`仅修改enabled，源不存在报错，不再调用书源表接口。列表和实体在数据层解码，坏响应不作为空结果；默认源导入、逐项导入与导出字段保持不变。Rust签名和底层存储不变。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getRssSources()` | 无 | `Future<List<RssSource>>` | 获取所有 RSS 源 |
| `addRssSource(RssSource source)` | source: RssSource 对象 | `Future<RssSource>` | 添加 RSS 源 |
| `updateRssSource(RssSource source)` | source: RssSource 对象 | `Future<void>` | 更新 RSS 源（Rust 侧 `ffi::rss_update_source`：按 `sourceUrl` 主键单条 UPDATE 原子更新，替代「删旧+加新」workaround，规避级联串表风险；Task #108，加法式新增 FFI）。✅ UI 封装接通：`RustRssSourceRepository.updateRssSource` 已由误接 `sourceUpdate` 改接 `rssUpdateSource` 真实管线（本次评审修复提交），Mock 同步对齐「源不存在时报错」语义 |
| `rssUpdateSource(String sourceJson)` | sourceJson: RssSource JSON | `Future<String>` | 原子更新 RSS 源（按 `sourceUrl` 主键单条 UPDATE 全字段），源不存在时报错，返回更新后的 RssSource JSON（Task #108，加法式新增） |
| `deleteRssSource(String sourceUrl)` | sourceUrl | `Future<void>` | 删除 RSS 源 |
| `enableRssSource(String sourceUrl)` | sourceUrl | `Future<void>` | 启用 RSS 源 |
| `disableRssSource(String sourceUrl)` | sourceUrl | `Future<void>` | 禁用 RSS 源 |
| `importRssSources(String jsonArray)` | jsonArray: JSON 数组字符串 | `Future<int>` | 导入 RSS 源，返回成功数量。✅ **2026-08-12 纠偏**：Flutter `RustRssSourceRepository.importRssSources` 曾误接 `sourceImport`（写入书源表）；现改为逐条 `rssAddSource` 落 `rssSources`。Rust `add_rss_source` 已改走 `RssSourceRepository::insert` 全字段；`import_rss_sources` 已在 `api/rss.rs` 备好，待 FRB 生成后可改批量 FFI |
| `exportRssSources()` | 无 | `Future<String>` | 导出 RSS 源。✅ **2026-08-12 纠偏**：勿走 `sourceExport`；现导出 `getRssSources()` JSON |
| `getRssArticles(String sourceUrl)` | sourceUrl | `Future<List<RssFeedArticle>>` | 获取 RSS 文章列表 |
| `rssClearArticles(String sourceUrl)` | sourceUrl | `Future<void>` | 清空指定 RSS 源本地文章缓存（对齐原版 clearArticles，F3-10 补登记） |

> ℹ️ **RSS 源原子更新（Task #108 缺口④）**：Rust 侧 `ffi::rss_update_source(source_json)`（核心实现 `legado-ffi/src/api/rss.rs::update_rss_source`，DB 层 `legado-db::RssSourceRepository::update_fields`）。对 `rssSources` 表按 `sourceUrl` 主键执行**单条 UPDATE 语句**全字段原子更新（不走 DELETE+INSERT，不触发外键级联）；目标源不存在时返回错误（不静默插入）。Flutter 侧 RSS 源编辑保存应改走本接口，替代原「删旧+加新」workaround。冻结契约保持不变，本方法为加法式新增。

### 2.6 本地书籍操作（4 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `importLocalBook(String filePath)` | filePath | `Future<Book>` | 导入本地书籍。**`.cbz` 本地漫画（2026-10-03 批 B 补记）**：`bookType = LOCAL(0x1000) \| IMAGE_BIT(64)`（位域，对齐 Kotlin `BookType` 位语义；`IMAGE_BIT` 常量见 `legado-core` `book_type`，**勿与 BookSourceType 数值域的 `IMAGE=2` 混淆**）；其余本地格式（txt/epub/mobi/azw/azw3/pdf/umd）仍为 `LOCAL` 无媒体位；`origin=loc_book`、`book_url` 存传入标识（相对标识语义不变） |
| `scanLocalBooks(String dirPath)` | dirPath | `Future<List<Map<String, dynamic>>>` | 扫描本地书籍，返回 `{path, name, size, lastModified}` |
| `detectFormat(String filePath)` | filePath | `Future<String>` | 检测书籍文件格式 |
| `parseMetadata(String filePath)` | filePath | `Future<String>` | 解析书籍元数据（返回 JSON） |

> ℹ️ **本地书白名单与 CBZ 懒加载链路（2026-10-03 批 B）**：`reader::is_local_book` 后缀白名单 = `.epub / .txt / .text / .mobi / .azw / .azw3 / .pdf / .cbz`（本次新增 `.cbz`）；`.zip` **不在**白名单（保持压缩容器语义，走 §2.34 导入路径，行为不变）。`.cbz` 命中白名单后：`getChapters` 首次调用懒解析（`LocalBook` → `CbzFile`，整包 1 章、章节 `url` 置空）并入库（含 B-13b 派生字段同步）；`getChapterContent` 返回 `cbz://<条目名>` 行列表（自然排序、仅图片条目）；图片字节经 §2.34 `cbzReadPage` 按条目读取。

> **FFI-TRANSPORT-20261017 / P2 冻结**（覆盖后文四个图片接口的历史 base64 约定）：`cbz_read_page(path, entry)` 与
> `fetch_image_with_decode(url, source_json)` 改为 `Result<Vec<u8>, BridgeError>`，
> `get_image_cache(book_url, url)` 改为 `Result<Option<Vec<u8>>, BridgeError>`，
> `save_image_cache(book_url, url, bytes: Vec<u8>)` 保留 bool 结果。Dart 参数/结果为 Uint8List；
> 删除上述传输的 base64/len JSON，不修改图片解密、CBZ 路径/条目、缓存键与 I/O 降级。
> 空缓存仍视为未命中，在线/CBZ 错误抛出；音频继续落盘，封面规则与字体不扩参。
> 沿用 SSE codec，只声明二进制直传，不宣称零拷贝；未增加新的图片格式或大小策略。
>
> 编写者：Codex + Bridge｜2026-10-17

### 2.7 书签操作（8 个方法）

> **FFI-TRANSPORT-20261017 / P1 冻结（2026-10-17）**：本批以强类型 FRB 替换书签和每日阅读明细的内部 JSON 载荷。
> Flutter 领域 Repository、DB schema、导入/导出及 REST JSON 不变。以下新约定覆盖本节历史 JSON 传输说明。
>
> - `BookmarkDto`：`id: i64`、`time: i64`、`bookName: String`、`bookAuthor: String`、
>   `chapterIndex: i32`、`chapterPos: i32`、`chapterName: String`、`bookText: String`、`content: String`。
>   字符串均不可空，允许空串；ID 和时间在 native Dart 使用精确 64 位 int，时间单位毫秒。
>   chapterPos 保持已有章内 UTF-16 偏移语义，不增加转换、裁剪或默认值。
> - `bookmark_get_all(book_name)`、`get_bookmarks_by_book(book_name, book_author)`、
>   `bookmark_list()`、`bookmark_search(keyword)` 返回 `Result<Vec<BookmarkDto>, BridgeError>`，
>   Dart 为 `Future<List<BookmarkDto>>`。空查询返回空列表，顺序、过滤和错误沿用原实现。
> - `bookmark_update(bookmark: BookmarkDto)` 返回 `Result<(), BridgeError>`；
>   原地更新并保留数据库原 id/time，缺失目标或写入错误抛出，失败不改记录。
>   移除 bookmark_json 参数及对应 JSON 解析，新增/删除仍使用现有标量参数及 i64 ID。
> - `ReadRecordDetailDto`：`bookName: String`、`author: String`、`date: String`、
>   `readTime: i64`、`lastRead: i64`；时间单位毫秒，date 沿用本地日期 YYYY-MM-DD。
>   `read_record_detail_list(year: i32)`、`read_record_all_detail_list()` 返回
>   `Result<Vec<ReadRecordDetailDto>, BridgeError>`，Dart 为 `Future<List<ReadRecordDetailDto>>`。
>   维持原有跨设备汇总、年份过滤和日期顺序，不暴露 deviceId 或推造历史明细。
> - DTO 位于 legado-ffi 的传输模块，Rust 与既有实体直接转换；Dart data 层映射到既有领域模型，
>   页面不导入生成 DTO。更新未修改的其他阅读记录接口继续沿用现有 JSON。
> - Rust/Dart 绑定同次生成并重建 native，旧 DLL 不兼容新绑定；本批不保留 JSON 双接口。
>   同步验证大 i64、Unicode/空串、更新保留时间、错误传播与真实跨桥接调用。
>
> 编写者：Codex + Bridge｜2026-10-17

> **书签直接适配接线冻结（2026-10-13）**：`BookmarkRepository` 暴露全部查询、
> 书名与作者双键查询、新增、原子更新、删除及搜索六项操作。`RustBookmarkRepository`
> 直接调用既有 FRB；MockBookmarkRepository 独立拥有会话内书签，沿用原 ID 分配、
> 查询、延迟与更新语义。BookApi 仅暴露 `bookmarkRepository` 装配引用，七项旧书签
> 方法删除；根实例中的同一个 Repository 由 Provider 共享，替换根实例时一起替换。
> 不初始化或重新打开运行时与数据库，不新增缓存。临时 BookApiBookmarkRepository
> 删除，不存在双向转发。仅按书名的旧查询不进入新接口；Rust 原 `bookmarkGetAll`
> 导出保留。Rust FFI、FRB 生成物、错误传播、JSON 及数据库均不变；BookApi 方法
> 计数由 293 减至 286，书签六项改由领域接口承担。

> **备注编辑接线（2026-10-13）**：新增选区书签时 `bookText` 为选区原文，`content`
> 为用户填写的备注（默认空串），`chapterPos` 保留选区 UTF-16 起始偏移。已有书签
> 编辑只改变 `content`，其余字段不变；Notifier 在原子更新成功后刷新当前列表的
> 对应记录，失败不更新列表。共用输入组件等待持久化成功才关闭，取消不写入。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `buildDocument({required String bookName, required String bookAuthor, required List<Bookmark> bookmarks, required BookmarkExportFormat format})` | 书籍名称/作者、有序书签快照、JSON或Markdown | `Future<BookmarkExportDocument>` | BookmarkExportService直连只读bookmarkExport；返回文件名/MIME/内容，不读库、不写文件 |
| `bookmarkGetAll({required String bookName})`（仅 FRB） | bookName | `Future<List<BookmarkDto>>` | 仅按书名返回强类型列表；Rust/FRB 导出保留，旧 BookApi.getBookmarks 已删除，应用使用领域接口的双键查询。 |
| `getBookmarksByBook(String bookName, String bookAuthor)` | bookName, bookAuthor | `Future<List<Bookmark>>` | 按书名+作者获取某本书的所有书签（对齐原版 `bookmarkDao.getByBook(name, author)`，规避同名书混入）；返回书签领域列表（FRB 传输改为 List<BookmarkDto>，不经过 JSON）；Dart 调用迁至 BookmarkRepository（历史来源：台账 §5.14-2，Task #63） |
| `getAllBookmarks()` | 无 | `Future<List<Bookmark>>` | 获取所有书签 |
| `addBookmark(Bookmark bookmark)` | bookmark: Bookmark 对象 | `Future<Bookmark>` | 添加书签 |
| `updateBookmark(Bookmark bookmark)` | bookmark: Bookmark 对象 | `Future<void>` | 通过 FRB `bookmark_update(bookmark: BookmarkDto)` 原子更新已有书签；保留 id 与原有创建时间 time。目标不存在或写入失败抛错，失败保留原记录，不执行删除后新增。 |
| `deleteBookmark(int id)` | id | `Future<void>` | 删除书签 |
| `searchBookmarks(String keyword)` | keyword | `Future<List<Bookmark>>` | 搜索书签 |

### 2.8 替换规则操作（8 个方法）

**Dart访问边界（2026-10-16）**：前六项由`ReplaceRuleRepository`访问，后两项由`ReplaceRuleService`执行；两种正式实现均直接复用既有FRB，根BookApi不保留旧方法。源导入装配、直导入口、编辑器和阅读菜单复用同一装配实例；合法空列表成功，坏列表结构或字段明确报错，不当作空规则。Mock保留原有规则内存与固定预览结果，不建立第二套执行引擎。

**已确认的既有写入缺口**：FRB `replaceRuleUpdate`不接受scope/sortOrder，Rust `update_replace_rule`保留原scope/order，因此本批不宣称修复编辑范围或排序持久化。拖拽仍为现有内存排序；批量置顶/置底虽调用更新也不能落库顺序。补齐需后续独立扩参、codegen与原生库配对，本批不改Rust/FRB签名、生成绑定和存储格式。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getReplaceRules()` | 无 | `Future<List<ReplaceRule>>` | 获取所有替换规则 |
| `getEnabledReplaceRules()` | 无 | `Future<List<ReplaceRule>>` | 获取启用的替换规则 |
| `addReplaceRule(ReplaceRule rule)` | rule: ReplaceRule 对象 | `Future<ReplaceRule>` | 添加替换规则。**2026-09-11 加法式扩参（A3 写链路补齐）**：FFI `replaceRuleAdd` 新增可选参 `group` / `scopeTitle` / `scopeContent` / `excludeScope` / `timeoutMillisecond`（缺省=旧行为：group=null、scopeTitle=false、scopeContent=true、excludeScope=null、timeoutMillisecond=3000）；**2026-09-13 再新增末尾可选参 `scopeSource: Option<bool>`（add 缺省=false 对齐原版独立列默认值）**；BookApi 签名不变（仍传 ReplaceRule 对象，UI 层零改动） |
| `updateReplaceRule(ReplaceRule rule)` | rule: ReplaceRule 对象 | `Future<void>` | 更新替换规则。**2026-09-11 加法式扩参（A3 写链路补齐）**：FFI `replaceRuleUpdate` 新增可选参 `group` / `scopeTitle` / `scopeContent` / `excludeScope` / `timeoutMillisecond`（未提供=保留既有值；提供空串=清除该字段）；`isEnabled` 维持既有参。**2026-09-13 再新增末尾可选参 `scopeSource: Option<bool>`（未提供=保留既有值）**。BookApi 签名不变 |
| `deleteReplaceRule(int id)` | id | `Future<void>` | 删除替换规则 |
| `setReplaceRuleEnabled(int id, bool enabled)` | id, enabled | `Future<void>` | 启用/禁用替换规则 |
| `applyReplaceRulesToSource(String sourceJson, String sourceName, String sourceUrl)` | sourceJson: 单个书源对象 JSON 字符串；sourceName / sourceUrl: 该源 `bookSourceName` / `bookSourceUrl`（scope 匹配依据） | `Future<String>` | **2026-09-13 加法式新增（书源导入时替换，对齐原版 `ReplaceRuleDao.findEnabledBySourceScope` + `BookSourceImport` 逐源判定）**：仅取 `isEnabled && scopeSource && pattern 非空` 的启用规则，`scope`/`excludeScope` 按「源名称或 URL」contains（忽略大小写）匹配——独立源上下文（**不复用标题/正文的 ScopeContext，语义红线：source 上下文的 scope 匹配对象是源名/源 URL，不是书名/书籍来源**）；正则带逐规则超时、`@js:` 复用正文管线、非正则按字面量替换；**未命中=原样返回原文，任何规则级错误（编译失败/超时/@js: 异常/DB 未就绪）不上抛 FFI、保留原文不阻断导入**。Dart 侧由 `SourceImportService.importFromJson` 统一入口对数组逐项调用（逐项而非整数组，因 scope 匹配按单源） |
| `previewReplaceRule(String ruleJson, String sampleContent)` | ruleJson: 单条 `ReplaceRule` 模型 JSON（camelCase 字段，Dart 侧 `ReplaceRule.toJson()` 产物）；sampleContent: 预览输入文本 | `Future<String>` | **2026-09-13 加法式新增（替换规则编辑器预览，`@js:` 补齐）**：对单条规则在示例文本上执行真实替换管线（正则编译 regex 优先 / fancy-regex 回退、`@js:` 走 QuickJS 执行器、逐规则超时保护）；成功=返回替换后文本；规则级错误（非法正则 / `@js:` JS 异常 / 执行超时）=返回 `⚠️ ` 前缀错误文本（可直接展示于预览区，不上抛异常）；非法输入（JSON 解析失败）MAY Err。编辑器预览改由本方法单一语义源承接（原 Dart 侧纯 Dart 近似分支删除，`@js:` 不再降级为「不可用」提示） |

### 2.9 阅读器操作（12 个方法）

**Dart访问边界（2026-10-15冻结）**：本节目录、正文、抓取及进度七项，与§2.43.1的
`saveChapterContent`共八项迁入`ReadingRepository`，由`RustReadingRepository`直接使用既有FRB，
Mock实现复用原书架、章节和正文数据。根BookApi只共享仓储实例，不保留旧八项方法；
阅读器、朗读、目录、详情、搜索及媒体调用迁移到同一仓储。
目录返回继续接受`ChapterListResponse.chapters`或列表，合法空列表成功；缺少chapters、
非数组及坏条目报格式错误，不按空目录处理。正文与刷新保留平台桥接载荷拦截。
进度参数沿用既有语义，正文原文锚点、页面状态与音视频毫秒不在本次合并；
Rust签名、数据库格式和生成绑定不变，缓存清理及下载任务仍属原能力边界。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getChapters(String bookUrl)` | bookUrl | `Future<List<BookChapter>>` | 获取章节列表 ⚠️ 双兼容点 |
| `getChapterContent(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<String>` | 获取章节正文内容 |
| `getChapterContentRaw(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<String>` | 获取章节正文（不应用替换规则，用于内容搜索，与 Android replaceEnabled=false 对齐） |
| `getChapterContentFull(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<String>` | 一次调用获取章节正文（合并 getChapterContent + fetchChapterContent，在线书籍自动网络抓取，始终返回纯正文） |
| `fetchChapterContent(String bookUrl, String chapterUrl, String sourceUrl)` | bookUrl, chapterUrl, sourceUrl | `Future<String>` | 从网络获取章节正文 |
| `updateReadingProgress({required String bookUrl, required int chapterIndex, required int chapterPos})` | bookUrl, chapterIndex, chapterPos | `Future<void>` | 更新阅读进度 |
| `refreshToc(String bookUrl, String sourceUrl)` | bookUrl, sourceUrl | `Future<List<BookChapter>>` | 从网络刷新书籍目录 ⚠️ 双兼容点 |
| `setChineseConvertType(int type)` | type | `Future<void>` | 设置阅读器繁简转换类型并持久化（0=不转换 / 1=繁转简 t2s / 2=简转繁 s2t，对齐 Android `AppConfig.chineseConverterType`，非法值归一为 0） |
| `getChineseConvertType()` | 无 | `Future<int>` | 获取当前繁简转换类型（0/1/2） |
| `toggleSameTitleRemoved(String bookUrl, int chapterIndex, bool enable)` | bookUrl: 书籍 URL；chapterIndex: 章节序号（0 起）；enable: true=去除重复标题 / false=保留原始标题 | `Future<void>` | 章级「删除重复标题」开关，覆盖全局默认（全局默认仍为去除）；状态须持久化（建议 DB，重启后保持）；接线后正文读取按章应用该开关。错误码：Db（章节不存在）/ Internal（书籍不存在）。语义对齐原版章级 opt-out 方向（台账 §5.11-7 删除重复标题正文链路，Task #50，加法式新增） |
| `getSameTitleRemoved(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<bool>` | 权威查询章级开关（caches KV `sameTitleRemoved:{bookUrl}:{chapterIndex}`）；true=去除（默认），false=opt-out。UI 菜单勾选态须以此为准，避免仅 SP 镜像分叉（2026-08-13 加法式新增） |
| `canRemoveSameTitle(String chapterTitle, String rawContent)` | chapterTitle, rawContent | `Future<bool>` | 试算正文 trim 后是否以标题开头（对齐原版「未找到可移除的重复标题」提示条件；2026-08-13 加法式新增） |

> ⚠️ `getChapters` / `refreshToc`：Rust 返回 `ChapterListResponse { total, chapters[] }`，Dart 侧提取 `chapters` 字段。
>
> 繁简转换（Task #100）：配置键 `chineseConverterType`（caches 表 `config:` 前缀，与 Kotlin PreferKey 同名）。正文在净化管线按配置做 t2s/s2t；章节标题在 getChapters/refreshToc 返回前做显示层转换（对齐 Kotlin `BookChapter.getDisplayTitle`，不回写 DB）；内容搜索 raw 路径保持原文。

### 2.10 配置操作（4 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getConfig(String key)` | key | `Future<String?>` | 获取配置值 |
| `setConfig(String key, String value)` | key, value | `Future<void>` | 设置配置值 |
| `deleteConfig(String key)` | key | `Future<void>` | 删除配置 |
| `getAllConfigs()` | 无 | `Future<Map<String, String>>` | 获取所有配置 |

### 2.11 备份操作（BACKUP-RESTORE-20261024，当前契约）

领域入口由BackupRepository拥有，BackupService编排平台偏好/资源/凭据及WebDAV传输。
不保留开发阶段JSON版本1或双JSON云端备份兼容分支，旧阶段约定由Git历史追溯。

- `backup_create(path, preferences_json, files_json, sensitive_json, password?) → String`：
  产物为版本化ZIP，包含manifest、24个明确业务集合、普通Rust配置及用户选定资源。
  files是原引用→本地文件路径；不包含可重建缓存、任意config或平台私有凭据。
  内部业务格式为openlegado/version2，未知集合/列、类型错误、重复主键及缺集合均拒绝。
  书籍经BookRepository更新，其余按原主键upsert，不用REPLACE删除关联记录。
- `backup_restore(path,password?,ignore_json) → BackupRestoreResultDto`：
  stats保留六主统计及additional集合计数，preferences_json/sensitive_json返回平台载荷，
  warnings报告上游未映射项。只接受localBook/threadCount/coverConfig/readConfig业务忽略项。
  包、资源、实体完整校验后单事务恢复，解析/写入/提交失败不留部分业务数据；限速在提交后发布。
  资源只能写入所属实例的资源目录，失败删除本次新建文件，已有文件不删除。
  Dart在业务提交后按忽略规则应用偏好与凭据，失败独立报告真实已提交统计；不承诺跨存储原子。
- 有密码时使用PBKDF2-HMAC-SHA256/600000次、随机32字节盐、AES-256-GCM及随机12字节nonce
  包装ZIP；固定magic/version标识参数。密码不进入包或日志，缺密码/错误密码/认证失败均在写入前拒绝。
  未加密包不能携带敏感载荷；备份密码由BackupPasswordStore使用平台安全存储持有。
- 先完成临时文件再发布产物；限制包/成员大小，拒绝路径逃逸、重复或缺失ZIP成员。
- 原版/HapeLee ZIP只按显式文件/字段映射导入，不能无损恢复项报告warnings；不声称全量兼容。
- 本地与WebDAV上传同一ZIP，云端选择文件后下载走同一本地恢复入口，恢复不得上传。
  `webdav_mkdir(config_json,path)`及领域webdavMkdir逐级准备远程目录，成功/已存在才继续，
  认证及服务器失败必须上抛（本批新增FRB方法1个）。

| 领域方法 | 返回 | 说明 |
|---|---|---|
| `backup(dirPath,{preferences,files,sensitive,password})` | `Future<String>` | 返回完整包路径 |
| `restore(path,{password,ignore})` | `Future<BackupRestoreResult>` | 已提交统计、平台数据及未支持项 |
| `backupList(dirPath)` | `Future<List<String>>` | 现有文件描述文本，不改其他消费者 |
| `importOldData(String dirPath)` | `Future<OldDataImportResult>` | **P2-4（2026-08-13）**：对齐原版 `ImportOldData.importUri`。读取目录下 `myBookShelf.json` / `myBookSource.json` / `myBookReplaceRule.json`（缺文件不致命，计入 `messages`）；书架字段映射（`noteUrl`→`bookUrl`、`bookInfoBean.*` 等）；书源经 `toNewRule`/`toNewUrl`/`toNewUrls`/`uaToHeader` 迁到 3.x 规则结构；替换规则兼容新格式或旧字段（`regex`/`replaceSummary`/`useTo`/`enable`/`serialNumber`）。已存在 `bookUrl` 的书跳过。返回结构化统计：books / bookSources / replaceRules / messages |

B4（实施前冻结）：本地密码只经BackupPasswordStore安全存储读写，空值删除；备份页提供
两次输入确认及独立的云TTS凭据导出选项（普通策略键backup_include_cloud_credentials，默认false）。
未设密码不导出WebDAV密码及远程服务器配置（含账号/密码），两者仅进入加密敏感区。
远程服务器经既有RemoteServerRepository恢复ID/连接/选中项，普通偏好排除remote_servers及remote_server_id。
显式选择云凭据且无密码则拒绝创建。密码不参与普通偏好备份。
上游config.xml只映射WebDAV地址/账号/目录/加密密码，其余Android设置报告未恢复。
上游AES格式没有认证完整性保证；本项目新包不使用该算法。上游AES-ECB/PKCS7密钥为本地密码小写MD5十六进制前16个ASCII字节，仅用于导入；
无法解密报错，不把密文误存为密码。其他上游敏感文件保持明确未支持，不增加明文回退。
既有FRB签名、DTO和数据库schema不变。

B5（实施前冻结）：BackupSettings统一保存onlyLatestBackup、autoCheckNewBackup、autoBackup、
autoBackupIntervalDays（1..365）、autoBackupWebDav及既有凭据导出开关；自动备份默认关闭。
BackupMetadataRepository单独保存安装身份、上次备份完成时间及已查看远程包，不参加备份恢复。
BackupRepository.backup增加可选fileName（Dart参数，FRB仍接path），正式及Mock成套调整。
Mock不创建或恢复真实包，明确报不支持，避免伪成功触发本机旧包清理。
应用生成含安全设备名、安装身份和时间戳的唯一文件名；仅清理同安装身份、同目录的本项目旧包，
成功写出/上传新包后才清理相应旧包，禁止删除上游包、无关ZIP及其他设备备份。
共享BackupService排斥并发备份/恢复；同一创建流程本地成功而云端失败时保留本地文件、报告部分结果，
不更新时间。自动化仅在启动/恢复前台检查到期间隔，调用真实创建及传输流程；失败保留旧时间，
不承诺后台定时唤醒。新备份检查显示可恢复项，未经用户选择不得自动恢复；按连接隔离已查看标记。
不连接尚未实装的AutoTask Backup执行占位，既有独立待办保持。

设备名称自动取值（2026-10-24）：自定义设备名优先，空值由Flutter平台层通过现有
device_info_plus读取系统设备名，直接使用插件返回的名称，包括iOS的通用iPhone/iPad名称，
不替换为具体型号，也不新增iOS设备名称entitlement。
页面与备份创建共用同一自动名称来源；自动名称不写入自定义偏好，清空即恢复自动。
读取不可用时回退平台名称，不阻断备份；安装身份及备份清理归属不变。
不新增依赖、权限、FRB方法、DTO、数据库或偏好键。编写者：Codex + UI。

### 2.12 阅读记录（15 个方法）

**记录列表下沉（RUST-BOUNDARY B7d，2026-10-23，实施前冻结）**：新增只读FRB
`read_record_views(query: String) → Result<ReadRecordListDto, BridgeError>`，领域接口
`getReadRecordList(String query) → Future<ReadRecordListData>`。结果含aggregate/latest两份
列表及totalTimeMs，UI按视图选择，摘要复用latest；不另取全量明细或再做业务归并。
条目字段为bookName/author/date（latest为null）/durationMs/lastRead；按书名+作者+日期
归并每日正数且日期合法的明细，latest按书名+作者跨日相加。最后阅读取非负最大值，
日期降序后按最后阅读降序，平局保持首次出现顺序。搜索trim后忽略大小写包含匹配
书名或作者。totalTimeMs始终是未过滤累计表合计，不随搜索改变。
沿用当前列表口径：只有原始明细中完全没有同名书时，latest才从累计记录补展示项，
按原作者字符串归并；不拆作者集合，也不因此补造每日记录。存在无效或零时长明细
的同名书仍抑制此回退，本批只迁移职责，不改变这条既有接受范围。
Rust直接读取数据库，既有累计/每日/删除事务不变；时间线继续走B7a查询。Flutter保留
日期卡片组织、文案、封面查找、选中键与导航；偏好Notifier只管偏好/搜索状态，删除
零生产消费者的旧列表/总时长计算与写入包装，不改存储偏好键。
查询按搜索参数缓存，成功变更和仓储替换触发失效；手动刷新及明细/首页重试须刷新
实际查询。Mock明确不支持新列表能力，测试用结果夹具，不复制Rust聚合算法。
本批无DB、依赖或应用版本变更，不移除原始数据Repository/FRB接口。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**日内小时分布下沉（RUST-BOUNDARY B7c，2026-10-23，实施前冻结）**：新增只读FRB
`read_record_hourly(boundaries: Vec<i64>) → Result<Vec<i64>, BridgeError>`，领域接口
`getReadRecordHourly(List<int> boundaries) → Future<List<int>>`；边界及会话单位为Unix毫秒，
返回24个小时槽的整秒数。Flutter按当前平台本地日历构造当天0..24点共25个边界，
不以起点加固定24小时替代；调用方保证25项非递减边界且首尾严格递增，允许夏令时
跳时产生的零宽槽。当前唯一Flutter入口固定生成，Rust运行时形状检查按用户要求
注释保留，不再承诺非法形状返回错误；不排序或修复输入，不在Rust另推系统时区。
Rust仅查询与首尾半开区间相交的有效原始会话，再与每个小时槽求交集，各槽先汇总
毫秒后取整秒；不归并设备副本、不补造历史、不从日累计推算，不改既有统计口径。
Flutter只拼接日期坐标与返回秒数，不再读取全量会话计算。日期参数化Provider订阅
已有成功变更通知，支持刷新与仓储替换；日周期外不订阅小时查询。
Mock明确不支持新查询，测试注入结果；原始会话接口仍保留，无DB或版本变更。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**周期统计下沉（RUST-BOUNDARY B7b，2026-10-23，实施前冻结）**：新增只读FRB
`read_record_overview(period: ReadRecordPeriodDto, reference_date: String)`及
`read_record_books_for_day(date: String)`，领域同名getReadRecordOverview/getReadRecordBooksForDay。
Rust直接读取每日明细、累计记录和正式书架（排除notShelf）；不接收Flutter全量历史。
period为day/week/month/year/all，日期严格YYYY-MM-DD；周一至周日、自然月/年按日历
运算，不用固定24小时。跨设备同日同书同作者相加，非正明细及非法明细日期不参与。
周期毫秒、天数、本数和排行由有效明细计算；all时长仅取累计表，不能用其补造日历。
在读数按累计表作者集合与周期书籍身份交集；读完数按同身份正式书架章节末尾且
durChapterPos非零判定。封面仍取书架coverUrl，同日并列最长优先最后阅读较新的书。
overview返回totalTimeMs/readingDays/totalBooks/readingBooks/finishedBooks、前十topBooks、
日期列表days（seconds/bookCount/topBook）及周/月日点或年内月点chart；均类型化DTO。
Dart仅将days映射为allDailyTimes/allDailyCounts/dailyTopBook，日/all的chart为空。
当天明细返回全部同名同作者归并项，按时长降序、名称/作者排序，不限前十。
界面保留周期选择/日期步进/图表坐标与格式化；本批日内小时柱状图继续由现有真实
会话求交集，不借每日总量伪造小时数据。原始记录查询及写入/删除事务不变，无迁移。
统计Provider使用查询参数和现有成功变更通知失效；书架状态变化也重新查询封面与
完成状态，首页固定all查询且独立于总览导航。异步归属由Riverpod管理，不另加锁。
Mock默认明确不支持新查询，测试注入结果夹具，不在Dart保留统计算法或调用FFI。
本批新增2个FRB方法，生成绑定；保持应用版本、其他视图及UI样式。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**时间线归并下沉（RUST-BOUNDARY B7a，2026-10-23，实施前冻结）**：新增只读FRB
`read_record_timeline(query: String) -> Result<Vec<ReadRecordTimelineDto>, BridgeError>`，
领域入口`ReadRecordRepository.getReadRecordTimeline(String query)`返回归并后的时间线。
Rust从现有数据库读取原始会话，不从Flutter回传全量历史；不修改记录或累计统计。
过滤无效时段，书名/作者按trim后关键词忽略大小写包含匹配，空关键词不过滤；
按startTime/id升序处理，按系统本地时区的开始日期归组，不用固定24小时推导日期。
同日期、同书名和作者的相邻会话，间隔不超过20分钟时合并，重叠区间取最大终点；
保留最早项的bookUrl/chapterIndex和startTime，最终按归并项开始时间倒序输出。
重复身份为bookName/author/bookUrl/startTime/endTime/chapterIndex（与现有Dart一致，
不含deviceId），重复仅折叠展示，所有原始id仍保留，保证删除整项不会遗漏重复副本。
DTO字段：bookName、author、date、本项bookUrl、startTime、endTime、chapterIndex、
sessionIds（i64列表）；展示跨度=endTime-startTime，含间隔，不用于累计/每日时长。
既有原始会话查询和删除接口保留；删除消费归并项全部sessionIds，仍由原事务扣减。
Flutter保留日期分组、格式化、章节名查询、选择和导航；时间线Provider订阅已存在的
成功写入通知并跟随仓储替换，错误上抛，异步结果归属由Riverpod管理，不另设快照锁。
Mock不联网、不调用FFI或重写归并算法：默认明确不支持，测试通过时间线夹具覆写能力。
本批新增1个FRB方法，生成绑定；无DB迁移、写入语义、周期统计或UI样式变更。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

> **实施补充（2026-10-13）**：保留现有按书名累计的 `readRecord` 入口；明细严格按
> `(deviceId, bookName, bookAuthor, date)` 保存。ReadRecord 新增真实 `author` 及仅用于写入的
> `startTime`，`lastRead` 是本次有效阅读时段终点；读接口返回作者或既有作者集合编码。
> 重复累计值不计时，负数拒绝；时段缺失时以终点向前回推有效增量，显式时段必须覆盖增量。
> 每日秒数从当日明细毫秒总和统一取整，不按每次增量截断；明细 lastRead 为该日有效时段终点。删除按书名级联全部作者明细，
> 在同一事务更新受影响日期的总秒数；清空累计、每日明细、日总数与会话四表。正式与 Mock 写入成功后发布变更通知，
> 统计数据 Provider 订阅通知并跟随 Repository 替换；搜索过滤不作为统计数据源。
> `putReadRecord` 对接 `readRecordRecordTime(bookName, author, readTimeMs, startTimeMs, endTimeMs, bookUrl, chapterIndex)`；
> 两个明细查询对接 `readRecordDetailList(year)` / `readRecordAllDetailList()`；2026-10-17 P1 改为强类型列表，字段与映射见 §2.7 冻结说明。
> 不补造历史每日明细；没有明细的累计值只参与“总”时长，不推算日历或排行。


> **阅读记录领域契约与明细扩展（2026-10-13 适配接线，2026-10-13 明细契约冻结）**：
> `ReadRecordRepository` 承担下列十项操作，正式实现直接调用底层 FRB/Rust 存储，
> 沿用同一运行时与数据库，不自行初始化、缓存或重写聚合。BookApi 只提供 `readRecordRepository`
> 装配引用，Provider 共享根实例中的同一对象并跟随根实例替换。页面、首页及阅读器计时改读窄接口。
>
> ℹ️ **书籍身份、写入事务与明细语义（2026-10-13 冻结）**：
> 1. **书籍身份标识**：书籍身份由 `(bookName, author)` 标识。阅读器保存时透传真实 author，避免同名不同作者书籍阅读记录混淆。
> 2. **写入事务与累加语义**：
>    - 计算本次有效增量：`delta = 新 readTime − 旧 readTime`。
>    - 若 `delta <= 0` 则幂等忽略，不产生任何副作用。
>    - 以 `[startTime, endTime]` 判断是否跨本地午夜；若跨午夜，则原子拆分毫秒至对应日期。
>    - 在同一个数据库事务中原子更新总表 `readRecord`、单书每日明细表 `readRecordDetail` 以及日总聚合表 `readRecordDaily`；失败全量回滚。
> 3. **删除与清空语义**：
>    - `deleteReadRecord`：删除指定书籍的 `readRecord`，并级联删除指定书籍在 `readRecordDetail` 的所有明细记录。
>    - `clearReadRecords`：同时清空 `readRecord`、`readRecordDetail` 、`readRecordDaily` 与 `readRecordSession` 四张表全部数据。
> 4. **数据模型 `ReadRecordDetail`**：包含 `bookName`（书名）、`author`（作者）、`date`（日期，本地时区 `YYYY-MM-DD`）、`readTime`（单日单书累计时长，毫秒单位）及 `lastRead`（最后阅读时间戳）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getReadRecords()` | 无 | `Future<List<ReadRecord>>` | 获取所有阅读记录 |
| `putReadRecord(ReadRecord record, {String bookUrl = '', int chapterIndex = 0})` | record: ReadRecord 对象 | `Future<void>` | 更新阅读记录；**（热力图每日时长契约，2026-08-29；单位口径 2026-09-11 修复；事务原子拆分 2026-10-13）**写路径同步原子累加当日/跨午夜日期明细 `readRecordDetail` 与日聚合 `readRecordDaily`（按整秒差值入账日聚合表，毫秒入明细表，失败全量回滚） |
| `deleteReadRecord(String bookName, {String? author})` | bookName | `Future<void>` | 删除阅读记录，级联删除 `readRecordDetail` 中该书所有明细 |
| `clearReadRecords()` | 无 | `Future<void>` | 清空阅读记录，同时清空 `readRecord`、`readRecordDetail`、`readRecordDaily` 与 `readRecordSession` |
| `readRecordDailyList(int year)` | year：年份 | `Future<List<Map<String, dynamic>>>`（`[{date, seconds}]`，日期升序） | **新增（热力图每日时长契约，2026-08-29，U 侧 UI_MD3_PLAN 登记；单位归一 2026-09-11）**：按年查询每日阅读秒数（readRecordDaily 表：`date TEXT PK` + `durationSeconds INTEGER`）；由 `putReadRecord` 写路径自动累加，UI 轨热力图「每日时长」配色模式数据源。存量毫秒值经 DB v107 迁移归一为秒（见更新记录） |
| `getReadRecordDetails(int year)` | year：年份 | `Future<List<ReadRecordDetail>>` | **新增（UI-HOME-OVERVIEW-A1，2026-10-13 冻结）**：返回特定年份按日期升序的每日单书明细列表（毫秒单位） |
| `getAllReadRecordDetails()` | 无 | `Future<List<ReadRecordDetail>>` | **新增（UI-HOME-OVERVIEW-A1，2026-10-13 冻结）**：返回全量历史每日单书明细列表（毫秒单位） |

> **阅读记录三视图/会话契约冻结（2026-10-13，用户授权上游对齐）**：
> `putReadRecord(record, {bookUrl = '', chapterIndex = 0})` 新增副本URL/章节序号写入上下文。
> 有效累计增量的真实区间 `[endTime-delta, endTime]` 与累计/每日明细在同一事务写入
> `readRecordSession`；重复累计不新增会话。原有记录不补造会话。
> 会话字段：id、deviceId、bookName、author、bookUrl、startTime、endTime、chapterIndex；
> 时间戳为本地展示用的UTC毫秒，章节序号从0开始，时长=endTime-startTime。
> 原始会话查询仍保留；B7a后时间线归并由Rust查询负责，UI消费结果，不改变存储与统计时长。
> `deleteReadRecord` 带author时只删除该作者的累计/每日/会话，省略时保留按书名全部删除语义。
> 删除每日明细同步裁剪对应会话的当日区间；删除指定会话同步扣减每日与累计，清空覆盖四表。
> 修改成功后广播既有变更通知，查询/删除错误直接返回，不作静默降级。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getReadRecordSessions()` | 无 | `Future<List<ReadRecordSession>>` | 查询原始真实会话，按startTime/id升序，保留设备副本供统计 |
| `getReadRecordTimeline(String query)` | 搜索词 | `Future<List<ReadRecordTimelineEntry>>` | Rust只读时间线投影，保留全部原始ID及本地日期，详见B7a冻结 |
| `getReadRecordOverview(ReadPeriod period, DateTime date)` | 周期、本地日期 | `Future<ReadRecordStatistics>` | Rust周期统计、排行与全量日历投影；小时分布仍由真实会话计算 |
| `getReadRecordBooksForDay(DateTime date)` | 本地日期 | `Future<List<ReadBookRanking>>` | 该日全部单书归并明细，不截取前十 |
| `getReadRecordHourly(List<int> boundaries)` | 本地0..24点共25个Unix毫秒边界 | `Future<List<int>>` | 相交真实会话汇总为24槽秒数，详见B7c冻结 |
| `getReadRecordList(String query)` | 搜索词 | `Future<ReadRecordListData>` | 按日汇总/最后阅读及未过滤累计时长，同一只读投影 |
| `deleteReadRecordDetail(String bookName, String author, String date)` | 名称、作者、本地YYYY-MM-DD | `Future<void>` | 删除该日单书明细，联动累计/日总数/会话区间 |
| `deleteReadRecordSessions(List<int> ids)` | 原始会话ID列表 | `Future<void>` | 原子删除选定会话，重复/不存在ID不扣减；同步每日与累计 |

### 2.13 RSS 收藏操作（4 个方法）

**Dart访问边界（2026-10-16）**：列表、添加、删除和收藏状态四项由`RssStarRepository`提供；保留已有按link操作与添加返回实体的语义，不增加二次存储。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getRssStars()` | 无 | `Future<List<RssStar>>` | 获取所有 RSS 收藏 |
| `addRssStar(RssStar star)` | star: RssStar 对象 | `Future<RssStar>` | 添加 RSS 收藏 |
| `deleteRssStar(String link)` | link | `Future<void>` | 删除 RSS 收藏 |
| `isStarred(String link)` | link | `Future<bool>` | 判断是否已收藏 |

### 2.14 书籍分组（4 个方法）

> 以下四项及 §2.41 的 bookGroupSetShow 共五项归 BookGroupRepository。正式更新仍只传名称/封面/顺序，Mock 更新完整对象；本批不改变显隐和 enableRefresh 的既有差异。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getBookGroups()` | 无 | `Future<List<BookGroup>>` | 获取所有书籍分组 |
| `addBookGroup(BookGroup group)` | group: BookGroup 对象 | `Future<BookGroup>` | 添加书籍分组 |
| `updateBookGroup(BookGroup group)` | group: BookGroup 对象 | `Future<void>` | 更新书籍分组 |
| `deleteBookGroup(int groupId)` | groupId | `Future<void>` | 删除书籍分组 |

### 2.15 搜索历史（5 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getSearchHistory({int limit = 50})` | limit(默认50) | `Future<List<SearchKeyword>>` | 获取搜索历史 |
| `searchHistoryByPrefix(String prefix, {int limit = 20})` | prefix, limit(默认20) | `Future<List<String>>` | 按前缀搜索历史关键词（搜索联想） |
| `addSearchKeyword(String keyword, String bookName)` | keyword, bookName | `Future<void>` | 添加搜索关键词 |
| `deleteSearchKeyword(String keyword)` | keyword | `Future<void>` | 删除搜索关键词 |
| `clearSearchHistory()` | 无 | `Future<void>` | 清空搜索历史 |

### 2.16 缓存管理（9 个方法）

**全局缓存与维护Dart边界冻结（2026-10-16，实施前）**：CacheRepository接管
getCacheSize/getCacheBookCount/getCacheChapterCount/clearCache/clearCacheBefore五项，
DatabaseMaintenanceService接管shrinkDatabase。应用装配共享实例并提供可独立替换的Provider；
根BookApi六项旧方法及part实现移除，不保留转发。CacheService仅依赖CacheRepository，
统计返回不可变CacheStats（totalSize/bookCount/chapterCount），不再返回动态Map。
Rust/FRB签名、数据库及生成绑定不变；清理false视为失败，异常原样传播，不伪造成功。
统计仍来自cached_chapters；全部清理按2026-10-19修订仅清正文及章节标记，保留其他KV，按时间清理
仍使用毫秒截止时间并复位受影响书籍的sameTitleRemoved键，不新增文件或媒体缓存清理。
VACUUM的0继续表示无需压缩或Rust降级，Dart不将其重新解释为确定成功。
Mock保留旧固定50MB/3书/30章、清理空操作和压缩固定10MB的展示样例，不作为真实清理证据。
自动过期仍仅有配置、执行入口待实现；不在本批新增调度或迁移设置存储。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getCacheSize()` | 无 | `Future<int>` | 获取缓存大小（字节） |
| `clearCache()` | 无 | `Future<void>` | 清除全部正文缓存及章节标记，保留配置和其他持久KV |
| `clearBookCache(String bookUrl)` | bookUrl | `Future<int>` | 清除指定书籍章节缓存，返回删除行数（对齐 BookHelp.clearCache(book)） |
| `clearChapterCache(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<int>` | 清除指定书籍**单章**的章节缓存，返回删除行数（行不存在为 no-op 成功；对齐上游原版 `BookHelp.delContent` 章级语义——仅删本章缓存行，**不触碰** `sameTitleRemoved` 等章级开关键，不触发整书清理；空 bookUrl 返回参数错误）（STAGE3-C2B：刷新正文对齐上游强制联网重取） |
| `getCacheBookCount()` | 无 | `Future<int>` | 获取缓存书籍数量 |
| `getCacheChapterCount()` | 无 | `Future<int>` | 获取缓存章节数量 |
| `clearCacheBefore(int beforeTimestampMs)` | beforeTimestampMs: 毫秒时间戳 | `Future<void>` | 清除指定时间之前的缓存 |
| `shrinkDatabase()` | 无 | `Future<int>` | 执行 SQLite VACUUM 压缩数据库文件，返回释放的字节数；Rust 侧应在后台线程执行避免阻塞。错误语义：VACUUM 失败（数据库锁/文件损坏）或数据库未初始化 → 返回 0 降级为无操作（不抛异常阻断业务）（台账 §5.13-9，第二批后置项，Task #50，加法式新增） |
| `getCachedChapter(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<String>` | 读取已缓存章节正文（FFI `cacheGetChapter`，F3-10 补登记 §1.7 命名等价） |

### 2.17 WebBook 操作（6 个方法）

**分类与字数格式（2026-10-12，用户确认）**：搜索、发现及详情的新解析结果统一分类与
字数口径。`kind` 按换行（含 CRLF）、英文逗号、中文逗号拆项并去除空项，输出英文逗号
分隔文本；`categories` 使用同一分类序列，保留标签内空格和日期内容。纯数字字数沿用现有
格式化规则（如 `3128968` → `312.9万字`），已有单位文本保持原样；空、非正数字及 NaN
视为缺失。详情刷新继续按既有逻辑写回在架书籍；不调整数据库读取，不批量修复旧数据。
字段、FFI 签名及生成绑定不变。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `webbookSearch(String sourceJson, String query, int page)` | sourceJson, query, page | `Future<String>` | 搜索书籍（书源规则驱动），返回 JSON |
| `webbookInfo(String sourceJson, String bookUrl)` | sourceJson, bookUrl | `Future<String>` | 获取书籍详情 JSON |
| `webbookChapters(String sourceJson, String bookUrl)` | sourceJson, bookUrl | `Future<String>` | 获取章节列表 JSON |
| `webbookContent(String sourceJson, String chapterJson)` | sourceJson, chapterJson | `Future<String>` | 获取章节正文（含 nextContentUrl 分页抓取，见下） |
| `debugBookSourceStream(String sourceUrl, String key)` | sourceUrl（已入库书源 URL）, key（调试关键字） | `Stream<Map<String, dynamic>>` | 流式书源调试（对齐 Kotlin `Debug.startDebug` + `Callback.printLog`）。每条 JSON：`state`（int）/ `msg`（String，含 `[mm:ss.SSS]` 时间戳）；`state=-1` 失败终止、`1000` 成功完成；关键字分流：绝对 URL→详情、`分类名::url`→发现、`++tocUrl`→目录、`--chapterUrl`→正文、否则搜索→详情→目录→正文。流在完成/取消/sink 关闭后结束 |
| `cancelDebugBookSource()` | 无 | `Future<void>` | 取消正在进行的书源调试（对齐 `Debug.cancelDebug`） |

> ℹ️ **nextContentUrl 分页抓取行为（Task #108 缺口①）**：`webbookContent` 签名不变，行为完善——消费 `contentRule.nextContentUrl` 规则（对标 Kotlin `BookContent.analyzeContent` 分页循环）：解析当前页正文后解析下一页 URL 规则，非空且未重复则继续抓取并按页拼接（`\n` 连接，同 Kotlin `contentList.joinToString("\n")`）；每页正文独立走 HtmlFormatter 净化（按该页 URL 绝对化 img）。防死循环保护：已访问 URL 去重（含首章 URL）+ 最大页数上限 99（原版无显式上限，Rust 轨加法式加固）；nextContentUrl 命中下一章 URL 的截断判定因无状态签名不可得 nextChapterUrl，由 URL 去重与页数上限兜底。音视频源不参与分页净化（同单页行为）。

> ℹ️ **空正文规则语义（P4-1 C4，2026-09-29，行为事实补记，零行为变更）**：正文规则 `ruleContent.content` 为空时，**非 JS 书源**两侧语义**一致**——`webbookContent` / 阅读正文链**不请求章节页**、直接返回**章节 URL 字符串**。Rust 侧短路位于 `WebBookEngine::get_content` 包装层（`legado-core/src/web_book.rs`，注释「正文规则为空时回退章节链接（听书/直链源关键路径）」），对齐原版 Kotlin `WebBook.kt:429-433`（`contentRule.content.isNullOrEmpty()` → `return bookChapter.url`，日志「正文规则为空,使用章节链接」）。JS 书源（`mainJs` 非空）豁免该短路：原版走 `JsSourceBook.getContentAwait` 独立分支（Kotlin `WebBook.kt:408-424`）；Rust 进入 fetcher 正文链（空规则 → 章节页 body 经 `format_keep_img` 直用）——这是 `parse_content_page_with_bindings`「body 直用」分支（空规则 → `analyzer.content()`）的**唯一可达路径**，非 JS 源经引擎路径不可达（包装层先短路，章节页不请求）。P4-1 调查稿 §6 C4 原表述「空正文时 Rust 返回 body HTML、原版返回章节 URL 字符串」**与实测行为不符**（实测 Rust 与原版同为「回退章节 URL」），本补记以实测行为为准并勘误。影响：漫画书源（bookSourceType=2）若 `content` 规则为空，上层（阅读器/Dart）收到的是章节 URL 字符串而非正文 HTML，漫画屏渲染前须按「URL 字符串」语义处理（图片 URL 行解析等兜底路径见 `comic_image_utils`）。固化测试：`rust/legado-ffi/tests/comic_content_fixture.rs::test_empty_content_rule_returns_chapter_url_like_original`（离线回环，章节页路由注册但断言零命中 + 正文 == 章节 URL）。本补记为纯契约记录 + 测试固化，无实现/签名变更。

> ℹ️ **流式 Debug.Callback（2026-08-13）**：Rust 侧 `ffi::debug_book_source_stream / debug_book_source_cancel`（实现 `legado-ffi/src/api/source_debug_api.rs`），复用既有 `webbook*` / `exploreFetchBooks` 链路推送逐步日志与字段摘要（`JsSourceDebugFormatter` 风格）。冻结 `webbook*` 契约不变，本组为加法式新增。

> ℹ️ **webbook* 非阻塞执行（2026-08-24）**：`webbookSearch/webbookInfo/webbookChapters/webbookContent` 四方法在 Rust 阻塞线程池（tokio `spawn_blocking`）执行，对齐原版 `WebBook.kt` Dispatchers.IO 语义；FFI 入口立即返回，网络 + quickjs JS 解析不阻塞 Dart 主 isolate。签名与返回值不变。

### 2.18 发现页操作（7 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `exploreParseUrl({required String exploreUrl, BookSourceDto? source})` | exploreUrl；`@js:` 须传 source | `Future<List<ExploreCategoryDto>>` | 解析 exploreUrl 为分类列表（含 type/action/chars/style） |
| `exploreFetchBooks({required BookSourceDto source, required String url, required int page})` | source, url, page | `Future<List<WebSearchResultDto>>` | 抓取发现分类的书籍列表，数据适配器转为 SearchBook |
| `exploreInfoMapPut(String sourceUrl, String key, String value)` | sourceUrl, key, value | `Future<void>` | toggle/select/text 写入 infoMap |
| `exploreInfoMapEnsureDefault(String sourceUrl, String key, String defaultValue)` | sourceUrl, key, defaultValue | `Future<void>` | infoMap 键不存在时写入默认值 |
| `exploreInfoMapSnapshot(String sourceUrl)` | sourceUrl | `Future<String>` | 读取 infoMap 快照（JSON 对象；UI 回显 toggle/select/text 已存值，对齐原版 InfoMap 持久化）。加法式新增（2026-08-14 发现页修复 B①） |
| `exploreEvalAction({required BookSourceDto source, required String actionJs})` | source, actionJs | `Future<ExploreActionDto>` | 固定字段 raw/refreshExplore 类型化，动态动作保留 actionsJson，数据适配器转为 ExploreActionResult |
| `exploreEvalUiJs({required BookSourceDto source, required String jsStr})` | source, jsStr | `Future<String>` | 执行 viewName 动态标题 JS（对标 evalUiJs） |

### 2.19 规则解析（1 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `parseRule(String content, String rule, String ruleType)` | content, rule, ruleType（css/xpath/json/regex 等，rule 无 `@` 前缀时拼为 `@type:rule`） | `Future<RuleParseResult>` | 使用规则解析内容，返回结构化 results/count，保留结果顺序 |

### 2.20 网络操作（5 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `NetworkService.httpGet(String url, {timeout})` | url、超时 | `Future<HttpTextResponse>` | 原生HttpTextResponseDto逐字段映射status/body/url；不经JSON |
| `NetworkService.httpPost(String url, String body, {timeout})` | url、body、超时 | `Future<HttpTextResponse>` | 与GET共用文本响应模型和共享客户端 |
| `NetworkService.httpGetBytes(String url, {headers, timeout})` | URL、可空Map<String,String>请求头、超时 | `Future<HttpBytesResponse>` | 原生HttpBytesResponseDto直接传status/bytes/url，字节不经Base64 |
| `fetchImageWithDecode(String url, String sourceJson)` | url、真正书源配置文档 | `Future<Uint8List>` | 图片下载及imageDecode脚本解密，原始字节直传，不包装base64/len |
| `setCustomHosts(String hostsJson)` | hostsJson: 域名→IP 映射 JSON 对象字符串（对齐原版存储格式） | `Future<void>` | 设置自定义 hosts 映射，配置后网络层 DNS 解析优先使用该映射（命中域名直连映射 IP，未命中回落系统 DNS）。存储格式对齐原版 `AppConfig.customHosts`：JSON **对象** `{"域名":"IP", "域名":["IP1","IP2"]}`（值支持单 IP 字符串或 IP 数组，实读原版 `AppConfig.hostMap/addressCache` 确认）；空串/空对象=清除映射、恢复系统 DNS。配置需持久化（复用既有配置存储语义，caches 表 `config:` 前缀键 `customHosts`，与既有 `setConfig` 同语义）并即时生效（后续请求使用新映射）。Rust 实现要点：legado-net 经 reqwest `ClientBuilder::resolve` 域名覆盖或自定义 DNS resolver 挂钩（现状无 custom_hosts 钩子，实施时补）。错误码：Internal（hostsJson 非合法 JSON 对象）。差异注明：原版非法输入即清除；本契约改为拒绝保存（更防误操作，Task #76 Med2）。既有 `httpGet` / `httpPost` 签名保持不变，本方法为加法式新增（台账 §5.13-1，第四批后置项，Task #72） |

### 2.21 JS 引擎（2 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `evalJs(String script)` | script | `Future<String>` | 执行 JS 脚本 |
| `getJsEngineVersion()` | 无 | `Future<String>` | 获取 JS 引擎版本 |

### 2.22 服务器管理（5 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `startServer({int port = 1122})` | port(默认1122) | `Future<void>` | 启动服务器 |
| `stopServer()` | 无 | `Future<void>` | 停止服务器 |
| `getServerStatus()` | 无 | `Future<String>` | 获取服务器状态 |
| `setServerPort(int port)` | port | `Future<void>` | 设置服务器端口 |
| `setMcpPort(int port)` | port: 独立 MCP 服务端口（合法区间 1024–65530，对齐原版 NumberPicker 取值；缺省语义默认 1236，对齐原版 `AppConfig.mcpPort` 默认值，未配置时 UI 对话框预填 1236 落实该缺省语义）；port ≤ 0 = 停止独立 MCP 服务 | `Future<void>` | 启动/停止独立 MCP 服务端口（**对齐原版独立端口方案**，见下方决策说明）。独立端口启动后提供与既有 Web 端口挂载的 `/mcp/tools`（GET）/ `/mcp/call`（POST）等价能力（同一套 MCP 工具与调用入口，零新增工具）；**并存策略**：独立端口开启时保持 Web 端口 `/mcp/*` 挂载不变（兼容既有消费方），二者共用同一 AppState/工具实现。端口配置需持久化（caches 表 `config:` 前缀键 `mcpPort`，与既有配置语义一致）。**F5（2026-08-13）**：监听 `0.0.0.0`（LAN 可达，对齐原版）；启动前置要求 `config:jsSourceApiToken` 非空（否则 Internal）；独立端口 `/mcp/*` 请求须带请求头 `X-Legado-Token`（大小写不敏感）与配置 token 字节级相等，否则 401。错误码：Internal（端口绑定失败 / 越界 / token 未设置）。既有 `startServer` / `stopServer` / `getServerStatus` / `setServerPort` 签名保持不变，本方法为加法式新增（台账 §5.13-6，第四批后置项，Task #72） |

> ℹ️ **mcpPort 决策说明（台账 §5.13-6，Task #72；F5 补齐）**：调研原版 `McpService.kt`——其为**独立前台服务**，ktor CIO embeddedServer 绑定 **0.0.0.0** 独立端口（`AppConfig.mcpPort` 默认 1236，合法区间 1024..65530），与 Web 服务完全分离；启动前置条件为 `jsSourceApiToken` 非空；请求经 `X-Legado-Token` 鉴权 + Host/Origin 白名单。本轨：`setMcpPort` 独立端口 + REST `/mcp/tools`/`/mcp/call`；**F5 已对齐** LAN 绑定、`jsSourceApiToken` 启动前置与 `X-Legado-Token` 校验。差异：原版另有 Host/Origin 白名单（本轨暂以 token 为访问控制主防线）；原版越界回落 1236，本契约改为报错（UI 内联区间校验前置拦截）。

### 2.23 书籍格式解析（3 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `parseTxt(String filePath)` | filePath | `Future<List<BookChapter>>` | 解析 TXT 文件 |
| `parseEpub(String filePath)` | filePath | `Future<List<BookChapter>>` | 解析 EPUB 文件 |
| `exportBook(String bookUrl, String format, String outDir)` | bookUrl, format, outDir | `Future<String>` | 导出书籍（将章节内容写入文件） |

### 2.25 HTTP TTS（6 个方法）

> **2026-10-19 导入导出闭环**：保留现有 FRB 签名。`httpTtsImport(document)` 接收
> JSON 数组，整批解析并在同一事务保存配置与源内音色目录；解析、写入或目录同步失败
> 均整批回滚，限流配置仅在提交成功后刷新。显式非零 ID 原地覆盖；零 ID 分配新 ID，
> 先保存显式 ID，避免同批自动编号覆盖显式记录。空名称/地址条目仍按既有规则跳过。
> 管理页预览接受单对象/数组、HTTP(S) URL、data URI 和 legado 导入链接，按稳定 ID
> 比较：不存在为新增、时间更新为更新、其余为已有；已有项默认不勾选，确认前不写入。
> 重复非零 ID 在预览阶段报错。`exportHttpTts()` 仍返回 JSON 数组，附带当前可用 HTTP
> 音色的 `speakersJson` / `emotionsJson`，不包含云端凭据、系统语音或登录会话数据。
> 单条/勾选导出从该完整文档筛选，不经 `HttpTts.toJson()` 丢弃目录。此批不修改 schema。

> **2026-10-13 批次 T1 全字段持久化与原地更新冻结**：本节六项及 §2.41 的
> `httpTtsSetEnabled` 由 `HttpTtsRepository` 承担；根 BookApi 只提供共享
> `httpTtsRepository` 引用。`httpTTS` 表升级至 Schema v110（补齐 `speed`、
> `synthesisThreadCount`），FRB `httpTtsAdd(httpTtsJson:)` 与
> `httpTtsUpdate(httpTtsJson:)` 接收完整 `HttpTts` JSON，`httpTtsList()`
> 输出统一 camelCase 字段：`id`、`name`、`url`、`contentType`、
> `pauseDuration`（默认 0）、`concurrentRate`（默认 `"0"`）、`loginUrl`、
> `loginUi`（兼容上游 JSON 数组导入并序列化为字符串）、`header`、`jsLib`、
> `enabledCookieJar`（默认 `false`）、`loginCheckJs`、`speed`（可空整型）、
> `synthesisThreadCount`（1..8 clamp，默认 1）、`lastUpdateTime`、
> `isEnabled`（默认 `true`）。`updateHttpTts` 按 `id` 原地更新，目标不存在
> 或写入失败均抛错（正式与 Mock 一致）；配置编辑使用 `copyWith` 保留未展示字段。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getHttpTts()` | 无 | `Future<List<HttpTts>>` | 获取所有 HTTP TTS 配置（完整 camelCase 字段） |
| `addHttpTts(HttpTts tts)` | tts: HttpTts 对象 | `Future<HttpTts>` | 添加或保存完整 HTTP TTS 配置（`id != 0` 保留输入 ID，否则分配新 ID） |
| `updateHttpTts(HttpTts tts)` | tts: HttpTts 对象 | `Future<void>` | 按 `id` 原地更新完整 HTTP TTS 配置；目标不存在或失败抛错 |
| `deleteHttpTts(int id)` | id | `Future<void>` | 删除 HTTP TTS 配置 |
| `importHttpTts(String json)` | json: JSON 字符串 | `Future<int>` | 导入完整 HTTP TTS 配置（兼容数组 `loginUi`），返回成功数量 |
| `exportHttpTts()` | 无 | `Future<String>` | 导出完整 HTTP TTS 配置 JSON 数组 |

### 2.26 音频播放（5 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `synthesize({required int engineId, required String text, String? engineUrl, double speed = 1.0, double pitch = 1.0, double volume = 1.0, String? voiceName, String? toneId, String? speakerName, String? emotionTag, HttpTtsCancellation? cancellation})` | 稳定 ID、正文、播放参数、音色上下文、取消状态 | `Future<HttpTtsSynthesisResult>` | `HttpTtsSynthesizer` 执行 HTTP 合成；`HttpTtsAudio` 提供路径、缓存命中及 MIME。`HttpTtsNoAudio` 区分 emptyResult/synthesisFailed/mock；真实失败保留原始错误，没有 GET 探活。`HttpTtsCancelled` 不起播、不进入失败估算。播放参数由播放器消费，源级语速从数据库读取。系统 TTS 不走此接口。 |
| `getAudioChapterMedia(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<Map<String, dynamic>>` | **音频书章节取址**（对齐原版 `AudioPlay` → `WebBook.getContent`）。Rust FFI：`audioGetChapterMedia` → JSON。返回字段（camelCase）：`chapterIndex` / `title` / **`mediaUrl`**（可播地址，即 getContent 正文 trim）/ `url`（章节页 URL，兼容旧字段）/ `resourceUrl` / `isVolume`（卷章无媒体，调用方应跳过）/ `fromCache` / `lyric` / `sourceUrl`。流程：查章 → 卷章短路 → DB 章节内容缓存命中则直接作 `mediaUrl` → 否则按 `book.origin` 书源 `getContent`（**正文规则为空时回退章节 URL**，对齐 Kotlin）→ 写入缓存。空 `mediaUrl` 且非卷章表示取址失败。错误码：章节/书籍不存在 → Database；书源网络/解析失败向上抛。与 HTTP TTS 合成分流：仅 `BookType.audio` 走本接口流媒体 |
| `resolveSkipWindow({ReadConfig? readConfig, required int durationMs, required int globalOpenCredits, required int globalCloseCredits})` | 配置、毫秒时长、全局秒数 | `Future<AudioSkipWindow?>` | AudioBookService薄适配Rust audioResolveSkipWindow；未启用窗口返回null，播放器保留定位与切章职责 |
| `getAudioProgress(String bookUrl, int chapterIndex)` | bookUrl, chapterIndex | `Future<Map<String, dynamic>?>` | 获取音频播放进度 |
| `saveAudioProgress(String bookUrl, int chapterIndex, int positionMs)` | bookUrl, chapterIndex, positionMs | `Future<void>` | 保存音频播放进度 |

### 2.28 WebDAV 云同步（9 个方法）

**连接测试下沉（RUST-BOUNDARY B5，2026-10-23，实施前冻结）**：新增只读FRB
`webdav_probe(config_json: String) -> Result<WebDavProbeResultDto, BridgeError>`，
Dart窄接口为`webdavProbe(WebDavConnection) -> Future<WebDavProbeResult>`。
复用Rust WebDavClient及应用CustomHosts，对草稿服务器地址本身发起一次PROPFIND，
Depth为0，不拼接remote_dir；账号或密码非空才携带Basic Auth。5秒预算覆盖请求至
响应头，不读取响应体，不解析目录XML，不重试、不建目录、不写配置或同步数据。
结果包含status（success/authenticationFailed/httpFailed/timedOut/networkFailed/invalidUrl）
和可空statusCode：200/207成功，401/403认证失败，其余HTTP状态为httpFailed；
无HTTP响应的结果无statusCode，地址须为含主机的HTTP(S) URL。
网络/超时以分类结果返回，不向UI暴露含凭据的请求地址或响应正文；配置编码错误等
调用错误仍使用BridgeError。Flutter仅处理必填提示、加载状态与结果展示，Mock不联网。
本批只新增1个FRB方法，不修改配置持久化、备份/同步流程或其余方法签名。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**Dart数据边界拆分（2026-10-15，实施前冻结）**：七项远程操作由`WebDavService`
及其直接FRB/Mock实现承担，配置参数改为`WebDavConnection`，JSON仅在FRB适配层编码。
本地备份四项由`BackupRepository`及直接FRB/Mock实现承担。根`BookApi`只装配共享实例，
迁移消费者后删除原十一项方法及其part实现；Rust导出、FRB签名和总方法表不变。
本地备份编排统一为`BackupService`，偏好写入失败向上传递；恢复先完成业务数据，
再应用偏好，部分完成不得误报整体成功。恢复后的设置刷新由应用层集中执行，
不因个别失败或页面卸载跳过其余刷新；原有顺序和配置同步能力保留。

**应用恢复调用方向（2026-10-24）**：备份统一采用§2.11完整ZIP。
SyncNotifier.restoreFromWebDav选择/下载远程包并调用同一本地恢复入口；恢复不上传、删除或
调用webdavFullSync，失败不把载荷改为空数组。业务提交后独立应用平台设置，反馈统计及部分失败。
备份创建与上传共用BackupService，只有请求的目标均完成才记录备份时间。
目录MKCOL仅接受成功或405（目录已存在）；DELETE只接受成功状态，认证/服务器错误须上抛，
不能让旧包清理失败冒充成功。旧双JSON应用路径移除，webdavFullSync不再用于完整备份/恢复。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `webdavListDir(WebDavConnection connection, String path)` | connection, path | `Future<List<Map<String, dynamic>>>` | WebDAV 列出远程目录；FRB返回JSON，数据层解码为对象列表，字段：`name` / `path` / `size` / `last_modified` / `etag` / `is_dir` |
| `webdavProbe(WebDavConnection connection)` | 草稿连接配置 | `Future<WebDavProbeResult>` | 只读连接测试，分类及HTTP状态由Rust返回，不落库 |
| `webdavUpload(WebDavConnection connection, String path, String data)` | connection, path, data | `Future<void>` | WebDAV 上传文件 |
| `webdavDownload(WebDavConnection connection, String path)` | connection, path | `Future<String>` | WebDAV 下载文件（**仅 UTF-8 文本**；二进制请用 `webdavDownloadFile`） |
| `webdavMkdir(WebDavConnection connection, String path)` | connection, path | `Future<void>` | 准备配置的子目录，MKCOL失败上抛 |
| `webdavDelete(WebDavConnection connection, String path)` | connection, path | `Future<void>` | WebDAV 删除远程文件 |
| `webdavFullSync(WebDavConnection connection, String localBooks, String localSources)` | connection, localBooks, localSources | `Future<WebDavSyncResult>` | WebDAV 全量同步 |
| `webdavUploadFile(WebDavConnection connection, String path, String localFilePath)` | connection（适配层编码为原WebDavConfig JSON）；path: 远程目标路径；localFilePath: 本地文件绝对路径 | `Future<void>` | WebDAV 从本地文件路径读取并上传（大文件场景，如书籍上传至远程），区别于既有 `webdavUpload` 的 String data 直传；既有 `webdavUpload` 签名保持不变。错误码：Io（文件不存在/读取失败）/ Net（上传失败）/ Internal（配置解析失败）（台账 §5.11-1 上传至远程，Task #50，加法式新增） |
| `webdavDownloadFile(WebDavConnection connection, String path, String localFilePath)` | connection（适配层编码为WebDavConfig JSON，字段 `url`/`username`/`password`/`remote_dir`）；path: 相对 `remote_dir` 的远程路径；localFilePath: 本地落盘绝对路径 | `Future<void>` | WebDAV 下载**二进制**到本地文件（对齐远程书库 `RemoteBookActivity` 导入；镜像 `webdavUploadFile`）。父目录不存在时创建；错误码：Io（写盘失败）/ Net（下载失败）/ Internal（配置解析失败）。既有 `webdavDownload` 签名保持不变（加法式新增，2026-08-12 P1-5） |

> **远程书库服务器列表（非 FFI）**：对齐原版 `servers` 表 + `AppConfig.remoteServerId`。Flutter 侧以 `RemoteServerRepository` 持久化 `remote_servers`（JSON 数组：`id`/`name`/`url`/`username`/`password`）与 `remote_server_id`（`-1` = 默认 WebDAV，即同步设置中的账号，根目录相对 path 为 `books/`）。目录浏览复用 `webdavListDir`；导入 = `webdavDownloadFile` → `importLocalBook`。

### 2.29 下载管理器（7 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `downloadAddTask({required String bookUrl, required String chapterUrl, required String chapterTitle, required int chapterIndex, int priority = 0})` | bookUrl, chapterUrl, chapterTitle, chapterIndex, priority | `Future<String>` | 添加下载任务，返回任务 ID（**字符串**，opaque 标识符，非数字序号） |
| `downloadGetStats()` | 无 | `Future<String>` | 获取下载统计信息 JSON |
| `downloadListByBook(String bookUrl)` | bookUrl | `Future<String>` | 获取指定书籍的下载任务 JSON |
| `downloadPauseAll()` | 无 | `Future<void>` | 暂停所有下载 |
| `downloadResumeAll()` | 无 | `Future<void>` | 恢复所有下载 |
| `downloadRemoveTask(String taskId)` | taskId（字符串 opaque ID） | `Future<void>` | 移除下载任务 |
| `downloadUpdateProgress(String taskId, double progress)` | taskId（字符串 opaque ID）, progress | `Future<void>` | 更新下载进度 |

### 2.30 段评（3 个方法，书源 ruleReview）

> **口径**：`reviewGetSummary` / `reviewGetDetail` / `reviewGetReplies` 为书源 `ruleReview` 路径（对齐原版 ReadBook / ReviewDetailDialog / ReviewController）。  
> **已移除**（F3-15）：本地库 CRUD（`reviewGetByChapter` / `reviewAdd` / `reviewDelete` / `reviewLike`）——原版 Android 无本地段评表/CRUD，属重构偏离创意，已从 FFI 与 BookApi 删除。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `reviewGetSummary(String sourceJson, String requestJson)` | sourceJson, requestJson | `Future<String>` | 段评摘要（对标 `ReadBookActivity.loadReviewSummary*` + `ReviewRuleParser.parseSummary` / JS `getReviewSummary`）。返回 `{"counts":{"1":5},"keys":{"1":"paraData"}}`（键为段落索引字符串；仅 count>0 的段）。requestJson：`chapterUrl`；可选 `book`/`chapter` JSON。规则缺失/未启用返回空 maps（非异常） |
| `reviewGetDetail(String sourceJson, String requestJson, int page)` | sourceJson, requestJson, page | `Future<String>` | 段评详情分页（对标 `ReviewDetailDialog.loadDetailPage` + `parseDetailPage` / JS `getReviewDetail`）。返回 `{"items":[DetailItem...],"nextPageUrl":String?,"hasReplyUrl":bool}`。requestJson：`paraIndex`/`paraData`/`chapterUrl`；可选 `detailUrl`（翻页直连）、`book`/`chapter`。条目字段同 `reviewGetReplies`，另含 likeCount/replyCount/replies |
| `reviewGetReplies(String sourceJson, String requestJson, int page)` | sourceJson, requestJson, page | `Future<String>` | 按需加载段评回复（上游 #519），返回 `{"items": [...], "nextPageUrl": String?}` 对象包装（含分页 URL，非裸数组）；requestJson 支持 reviewId/paraIndex/paraData/chapterUrl/replyUrl 字段；回复条目字段：id/avatar/name/badges/content/imageUrl/audioUrl/time |

### 2.31 书籍导出（2 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `bookExport({required String bookUrl, required String format, required bool includeToc})` | bookUrl, format, includeToc | `Future<Map<String, dynamic>>` | 导出书籍，返回 ExportResult JSON |
| `bookExportInfo({required String bookUrl, required String format})` | bookUrl, format | `Future<Map<String, dynamic>>` | 获取导出预览信息 |

### 2.32 自动任务（auto_task FFI）（14 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `autoTaskBuildBookUpdateTask({required String bookUrl, required String bookName, required String bookAuthor, required String name})` | bookUrl, bookName, bookAuthor, name | `Future<Map<String, dynamic>>` | 构建书籍更新定时任务 |
| `autoTaskUpdateCronBatch({required String rulesJson, required String idsJson, required String cron})` | rulesJson, idsJson, cron | `Future<List<Map<String, dynamic>>>` | 批量更新 cron 表达式 |
| `autoTaskPrepareImported({required String localTasksJson, required String importedJson})` | localTasksJson, importedJson | `Future<List<Map<String, dynamic>>>` | 准备导入任务 |
| `autoTaskExecute({required String protocolJson})` | protocolJson | `Future<Map<String, dynamic>>` | 执行任务协议 |
| `autoTaskExecuteWithId({required String protocolJson, required String taskId})` | protocolJson, taskId（自动任务规则 ID，字符串 UUID/主键，非下载 taskId） | `Future<Map<String, dynamic>>` | 带任务 ID 执行任务协议 |
| `autoTaskNormalizeScript({required String script})` | script | `Future<String>` | 规范化脚本 |
| `autoTaskCanRefreshBookToc({required bool canUpdate, required bool respectCanUpdate})` | canUpdate, respectCanUpdate | `Future<bool>` | 判断书籍是否允许刷新目录 |
| `autoTaskFindBookUpdateTask({required String tasksJson, required String bookUrl, required String bookName, required String bookAuthor})` | tasksJson, bookUrl, bookName, bookAuthor | `Future<Map<String, dynamic>?>` | 查找书籍更新任务 |
| `autoTaskNextDueAt({required String cron, required int fromMs})` | cron, fromMs | `Future<int>` | 解析 cron 表达式计算下次执行时间 |
| `autoTaskListRules()` | 无 | `Future<List<Map<String, dynamic>>>` | 列出所有自动任务规则（数据库 CRUD） |
| `autoTaskCreateRule({required String ruleJson})` | ruleJson | `Future<String>` | 创建自动任务规则（数据库 CRUD） |
| `autoTaskUpdateRule({required String ruleJson})` | ruleJson | `Future<void>` | 更新自动任务规则（数据库 CRUD） |
| `autoTaskDeleteRule({required String id})` | id | `Future<void>` | 删除自动任务规则（数据库 CRUD） |
| `autoTaskFindRuleById({required String id})` | id | `Future<Map<String, dynamic>?>` | 根据 ID 查询自动任务规则（数据库 CRUD） |

### 2.33 音频播放模式（audio FFI）（2 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `audioWithPlayMode({String? readConfig, required int playMode})` | readConfig(可选), playMode | `Future<String>` | 将播放模式写入 readConfig JSON |
| `audioResolvePlayBook({String? requestedBookUrl, String? cachedBookJson})` | requestedBookUrl(可选), cachedBookJson(可选) | `Future<Map<String, dynamic>?>` | 解析听书书籍 |

### 2.34 压缩包导入（8 个方法）

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `archiveImportZip({required String zipPath, required String outputDir})` | zipPath, outputDir | `Future<Map<String, dynamic>>` | 导入 ZIP 压缩包中的书籍文件 |
| `archiveImportRar({required String rarPath, required String outputDir, String? password})` | rarPath, outputDir, password(可选) | `Future<Map<String, dynamic>>` | 导入 RAR 压缩包中的书籍文件 |
| `archiveListZipFiles({required String zipPath})` | zipPath | `Future<List<String>>` | 列出 ZIP 压缩包中的书籍文件名 |
| `archiveListRarFiles({required String rarPath, String? password})` | rarPath, password(可选) | `Future<List<String>>` | 列出 RAR 压缩包中的书籍文件名 |
| `archiveDetectEncoding({required String filePath})` | filePath | `Future<Map<String, dynamic>>` | 检测 TXT 文件编码 |
| `archiveConvertEncoding({required String filePath, required String fromEncoding, required String toEncoding})` | filePath, fromEncoding, toEncoding | `Future<Map<String, dynamic>>` | 转换 TXT 文件编码 |
| `archiveIsArchive({required String filePath})` | filePath | `Future<bool>` | 判断文件是否为压缩包格式 |
| `cbzReadPage({required String path, required String entry})` | path: 本地 CBZ 书 `bookUrl`（绝对路径，或相对可迁移标识——经 `resolve_local_book_path` 同语义解析）；entry: ZIP 条目名（兼容带/不带 `cbz://` 前缀，中文/空格原样） | `Future<String>` | **2026-10-03 批 B 加法式新增（E9 参考版扩展，用户已授权；纯 FFI，尚未封装进 BookApi）**：读取 CBZ 漫画单页图片字节，返回 JSON `{base64, len}`（与 `fetchImageWithDecode`/图片缓存同惯例）。配合 §2.6 链路：`getChapterContent` 返回 `cbz://<条目名>` 行列表，Dart 侧逐行调用本方法取图。错误语义：文件不存在 / ZIP 解析失败 / 条目不存在 / 包内无图片条目 → 抛 BridgeError |

### 2.35 RSS 已读记录（7 个方法）

**Dart访问边界（2026-10-16）**：七项由`RssReadRecordRepository`提供，列表在数据层解码为已有`RssReadRecordRow`，保留snake_case read_time、nullable link、Rust返回顺序和limit语义；页面不再解析Map。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `rssMarkRead(String origin, String title, {String? link})` | origin, title, link(可选) | `Future<void>` | 标记 RSS 文章为已读 |
| `rssIsRead(String link)` | link | `Future<bool>` | 判断文章是否已读（按 link 匹配） |
| `rssIsReadByTitle(String origin, String title)` | origin, title | `Future<bool>` | 判断文章是否已读（按 origin+title 匹配） |
| `rssClearReadRecords()` | 无 | `Future<void>` | 清空所有已读记录 |
| `rssReadRecordCount()` | 无 | `Future<int>` | 获取已读记录总数 |
| `rssListReadRecords({int? limit})` | limit(可选，默认100) | `Future<List<RssReadRecordRow>>` | 获取已读记录列表（按 readTime 降序） |
| `rssListReadRecordsByOrigin(String origin, {int? limit})` | origin, limit(可选，默认100) | `Future<List<RssReadRecordRow>>` | 按 RSS 源 origin 获取已读记录（对齐原版 `getRecordsByOrigin`，F3-17） |

### 2.36 正文高亮（highlight FFI）（16 个方法）

**HIGHLIGHT-RULES-20261024（已实现，用户已确认范围）**：

- 数字`id`继续作为本地主键，新增`uuid`稳定标识；数据库v112→v113为已有规则补UUID并建唯一索引，保留数字ID、规则和标注数据。预设使用固定UUID，同一预设重复导入合并，普通新规则分配UUID。
- `style`继续为完整样式JSON，覆盖MD3的示例文本、标题/正文/全部范围、字色/背景色、7种线条、宽度/偏移/SVG路径、背景图及适配/缩放/九宫格、字体/字重/斜体/字号偏移、命中前后间距与行上下间距、背景左右长度偏移及配置绑定。Rust统一解析、校验和规范化；Flutter只编辑、测量和绘制。
- 增加只读预设/导入预览、原子批量导入和导出能力，预览不落库；导入按UUID更新并保留本地主键，新规则不采信外部数字ID。支持本项目JSON及MD3对象/数组/含rules备份载荷，MD3字符串ID映射稳定UUID；不默认覆盖用户修改的预设。
- 增加只读章节规则匹配，Rust执行正则、作用范围及优先级解析，返回原文UTF-16半开区间与完整样式；标题和正文分别标记，不改原文，不污染选区和朗读文本。预设正则对照MD3样例；使用现有正则安全入口。
- 排版TextStyle/DTO新增`inheritColor: bool`（默认false）；正文基础样式与未指定字色的高亮使用true，绘制继承当前正文色，避免纯配色变化重新分页。线条扩展载荷亦支持inheritColor。
- Flutter按最终样式测量，Rust现有通用行内模型负责断行/分页/间距，Flutter按同一布局产物绘制。规则变更使布局缓存失效并按原文锚点恢复，不另建Dart正则执行分支。
- 本地字体/背景由文件选择器复制到应用持久目录；完整应用备份收集规则引用资源并在恢复时重写路径；规则恢复按UUID合并，数字主键空闲时保留、冲突时重分配，整批事务不变。规则JSON导出保留资源引用，不内嵌二进制资源，跨设备分享文件型样式需另行提供资源。
- 领域仓储、正式/Mock适配及FRB生成物成套更新；精确方法签名随本批出口补入下表，生成物由工具产出。应用版本保持。

编写者：Codex + Rust / UI｜2026-10-24

> **当前Dart边界（2026-10-24）**：下表为当前FRB传输签名，十六项不属于根BookApi。
> HighlightRepository保留标注七项方法名，highlightAdd(BookHighlight highlight)在仓储映射DTO，返回实际time；
> 四项列表/搜索返回Future<List<BookHighlight>>，删除保留原bool/数量返回。
> HighlightRuleRepository包含规则配置、预设、预览、导入导出和匹配九项，highlightRuleSave(HighlightRule rule)返回ID，
> 列表与适用规则查询返回Future<List<HighlightRule>>；模型移出Provider状态文件并保留既有排序和超时字段。
> 两份仓储直接调用现有FRB；Mock通过同一装配实例共享状态，规则ID复用原分配器。
> 空列表合法，底层错误原样上抛；保存无有效主键时失败，删除保留原false/数量。
> 消费者通过独立Provider注入，不在目录页或规则Notifier解析传输载荷；匹配返回样式区间，不改写原文。
>
> **Flutter 选区调用口径（2026-10-11，UI-READER-SELECTION-20261011）**：新增选区记录的 `chapterPos` / `chapterPosEnd` 为收到的章节正文中的 UTF-16 起止偏移（左闭右开），与 Dart 选区一致；`bookText` 从同一原文区间取得，排版生成的缩进不计入原文。阅读器现有页索引与字符偏移分别管理。Rust 沿用现有整数存储，不新增字段、方法或数据库迁移，也不重写历史高亮记录。

> 对齐上游 `BookHighlight` / `HighlightRule` 实体与 DAO（DB v96-v99）。
> JSON 字段名对齐 Room 列名（camelCase）：BookHighlight 含 `time` / `bookUrl` / `chapterUrl` / `bookName` / `bookAuthor` / `chapterIndex` / `chapterPos` / `chapterPosEnd` / `layoutTitleLength` / `chapterName` / `bookText` / `style` / `note`；HighlightRule 含 `id` / `uuid` / `name` / `pattern` / `isRegex` / `scope` / `isEnabled` / `style` / `sortOrder` / `timeoutMillisecond` / `applyToTitle`。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `highlightAdd({required BookHighlightDto highlight})` | 完整标注快照（time=0 时自动分配） | `Future<int>` | 新增/更新高亮记录，返回 time 主键 |
| `highlightDelete({required int time})` | time | `Future<bool>` | 按主键删除高亮记录，返回是否实际删除 |
| `highlightDeleteByBook({required String bookUrl})` | bookUrl | `Future<int>` | 按书籍删除全部高亮，返回删除数量 |
| `highlightListByBook({required String bookUrl})` | bookUrl | `Future<List<BookHighlightDto>>` | 按书籍获取高亮列表 |
| `highlightListByChapter({required String bookUrl, required int chapterIndex})` | bookUrl, chapterIndex | `Future<List<BookHighlightDto>>` | 按书籍+章节获取高亮列表 |
| `highlightSearch({required String keyword})` | keyword | `Future<List<BookHighlightDto>>` | 全局关键词搜索高亮（bookText/note） |
| `highlightListAll()` | 无 | `Future<List<BookHighlightDto>>` | 获取所有高亮记录 |
| `highlightRuleList()` | 无 | `Future<List<HighlightRuleDto>>` | 获取所有高亮规则，按 sortOrder 升序 |
| `highlightRuleSave({required HighlightRuleDto rule})` | 规则快照（id=0 时自增新增） | `Future<int>` | 保存高亮规则，返回规则 ID |
| `highlightRuleDelete({required int id})` | id | `Future<bool>` | 按 ID 删除高亮规则，返回是否实际删除 |
| `highlightRuleFindEnabled({required String bookName, required String origin})` | bookName, origin | `Future<List<HighlightRuleDto>>` | 按书籍查找启用的高亮规则，scope 匹配书名或 origin |

| `highlightRulePresets()` | 无 | `Future<List<HighlightRuleDto>>` | 只读MD3预设，稳定UUID |
| `highlightRulePreview({required String content})` | 原始JSON | `Future<List<HighlightRuleDto>>` | 统一解析且不落库，外部数字ID清零 |
| `highlightRuleImport({required List<HighlightRuleDto> rules})` | 已预览并选中的规则 | `Future<int>` | 单事务按UUID合并，返回条数 |
| `highlightRuleExport()` | 无 | `Future<String>` | 全部规则JSON，保留UUID及完整样式 |
| `highlightRuleMatch({required List<HighlightRuleDto> rules, required String text, required bool isTitle, String? configName})` | 已按书籍筛选的规则及原文 | `Future<List<HighlightMatchDto>>` | 只读纯匹配，UTF-16半开区间和style JSON；升序排序，后规则覆盖；空匹配忽略，正则失败报错 |


### 2.37 JS 单文件书源配置（JsSourceConfig 对齐）（3 个方法）

> 对齐 Kotlin `JsSourceConfig.kt`：extract 配置提取 / stampLastUpdateTime 时间写回（#208/#515）/ 语法检查（#479）。
> extract 需 QuickJS 构建（`--features quickjs`），非 quickjs 构建返回错误；语法检查非 quickjs 构建降级为括号平衡基础检查。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `jsSourceExtract({required String content})` | content（完整 JS 书源脚本） | `Future<String>` | 执行脚本提取顶层 config/source 配置（BookSource JSON，mainJs 回填完整脚本）；缺必备函数/配对校验失败报错 |
| `jsSourceSyntaxCheck({required String content})` | content（待检查 JS 脚本） | `Future<String>` | 语法检查（SyntaxCheckResult JSON：`valid` / `message` / `line`）；quickjs 下只编译不执行 |
| `jsSourceStampLastUpdateTime({required String content, required int stamp})` | content（JS 书源脚本）, stamp（新时间戳毫秒） | `Future<String>` | 写回顶层 config/source 对象的 lastUpdateTime（仅替换数字字面量或 Date.now()）；无可替换位置返回空字符串 |

### 2.38 应用日志（app_log FFI，Task #79）（5 个方法）

> **Dart边界（2026-10-16）**：下表保留FRB传输签名，根BookApi不再提供五项日志方法。
> AppLogRepository保留五个方法名与既有参数，appLogList返回Future<List<AppLogEntry>>；
> JSON解码在正式仓储完成，坏结构/条目/字段类型明确报错，合法空数组正常返回空列表。
> AppLogEntry从Provider状态文件移至共享模型，时间显示语义不变；正式实现直接调用原FRB，
> Mock共享同一装配内存缓冲。搜索/换源日志写入失败不阻断结果，清空失败不报告成功。
> 不改变日志采集/备份、级别、正式导出格式与截断规则，不改Rust或生成绑定。
>
> 对齐 Kotlin `AppLog.kt` / `AppLogDialog.kt`（旧欠账 + 上游 #512/#524/#543）。
> Rust 侧进程级环形缓冲（每级上限 500 条，最新在前），三级独立：`message` / `crash` / `http`（大小写不敏感）。
> 日志条目 JSON 字段：`timestamp`（毫秒）/ `level` / `message`（对齐 Kotlin `Triple<Long, String, Throwable?>`）。
> 导出文本格式 `yyyy-MM-dd HH:mm:ss.SSS [LEVEL] message`，时间升序，超 64_000 字符按字符边界截断（对齐 #543 `MAX_SHARE_TEXT`）。
> 纯内存缓冲、无 DB 依赖，任意时机可调用；日志页面 UI 由 UI 轨后续接入（与 Flutter 现有 `CrashLogService` 文件型崩溃日志互补，不重复）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `appLogPush({required String level, required String message})` | level（message/crash/http）, message | `Future<void>` | 写入一条日志；非法级别抛 BridgeError，空消息忽略（对齐 Kotlin `put` 的 null 短路） |
| `appLogList({required String level})` | level | `Future<String>` | 获取指定级别日志列表（裸 JSON Array，最新在前，对齐 §1.4 铁律） |
| `appLogClear({required String level})` | level | `Future<void>` | 清空指定级别日志 |
| `appLogClearAll()` | 无 | `Future<void>` | 清空全部级别日志（对齐 #543 清空确认后的 AppLog.clear + HttpLogStore.clear） |
| `appLogExport()` | 无 | `Future<String>` | 导出全部日志为格式化文本（时间升序，64_000 字符截断，对齐 #543） |

### 2.39 规则订阅（rule_sub FFI，Task #89）（7 个方法）

> **Dart边界（2026-10-16）**：以下表格仍为原有FRB传输签名，不再属于根BookApi。
> RuleSubRepository接管配置五项：ruleSubList返回Future<List<RuleSub>>，
> ruleSubSave(RuleSub sub)在仓储内编码JSON，删除/启停保留命名参数，
> ruleSubUpdateOrder({required List<int> ids})在仓储内编码ID数组；写入保留bool返回，false不得误报成功。
> RuleSubService接管ruleSubCheckUpdate与ruleSubApplyUpdate，分别返回RuleSubCheckResult与RuleSubApplyResult；
> 结果必需字段按实际JSON类型检查，错误不转换为空列表、已是最新或更新成功。
> 两个Provider可分别替换，正式实现直接复用本节FRB；Mock更新服务读取同一Mock仓储，不再复制配置集合。
> 本批不修改Rust签名/生成绑定/数据库。既有应用更新未将merged_json写入各类实体表，
> 以及Flutter RuleSub未覆盖js/showRule/sourceUrl的往返缺口，登记于Active的RULE-SUB-UPDATE-GAPS-20261016。
>
> 对齐 Kotlin `RuleSub.kt` 实体与 `RuleSubActivity.kt`（列表 CRUD / 拖拽排序 / 自动更新 / 静默更新 / 更新间隔）。
> DB v100（Rust 轨自有扩展）：rule_subs 表补全 Kotlin RuleSub 字段 `customOrder` / `autoUpdate` / `updateInterval` /
> `silentUpdate` / `js` / `showRule` / `sourceUrl`（Migration99To100，幂等补列，不动 v95-v99 高亮体系迁移）。
> RuleSub JSON 字段：`id` / `url` / `name` / `sub_type`（bookSource/replaceRule/rssSource）/ `last_update` / `version` /
> `is_enabled` / `created_at` / `customOrder` / `autoUpdate` / `updateInterval` / `silentUpdate` / `js` / `showRule` / `sourceUrl`（新增 7 字段对齐 Kotlin 驼峰命名）。
> 检查/应用更新委托 `legado-net` rule_update_client（should_update / fetch_subscription / merge_subscription）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `ruleSubList()` | 无 | `Future<String>` | 获取订阅列表（RuleSub 数组 JSON，按 customOrder 排序） |
| `ruleSubSave({required String subJson})` | RuleSub JSON | `Future<bool>` | 新增/更新订阅（id>0 且存在则更新，否则新增） |
| `ruleSubDelete({required int id})` | id | `Future<bool>` | 删除订阅，返回是否实际删除 |
| `ruleSubSetEnabled({required int id, required bool enabled})` | id, enabled | `Future<bool>` | 切换启用状态，返回记录是否存在 |
| `ruleSubUpdateOrder({required String idsJson})` | idsJson（新顺序 ID 数组 JSON） | `Future<bool>` | 拖拽排序：按索引重写 customOrder（0 起） |
| `ruleSubCheckUpdate({required int id})` | id | `Future<String>` | 检查更新（检查结果 JSON：`id` / `url` / `name` / `dueForUpdate`（should_update 间隔判定）/ `hasUpdate`（远程版本对比）/ `remoteVersion` / `error`） |
| `ruleSubApplyUpdate({required int id})` | id | `Future<String>` | 应用更新（应用结果 JSON：`id` / `url` / `success` / `itemsAdded` / `itemsUpdated` / `itemsRemoved` / `totalItems` / `error`；合并后回写版本号与最后更新时间） |

### 2.40 本地 TXT 全文搜索（历史4项FRB导出，2026-10-17已退役）

> 下表只记录历史接口，当前没有对应FRB导出或Flutter消费者。底层 `legado-book::txt_search`
> 的纯文本、正则、章节内搜索和计数能力仍保留；阅读器现有搜索路径不受影响。
> 返回裸 JSON Array（遵守 §1.4 铁律），每项字段（snake_case）：`chapter_index` / `chapter_title` / `char_offset` /
> `matched_text` / `context` / `context_match_start` / `context_match_end`（TxtSearchResult 序列化）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `txtSearch(String path, String query, {bool caseSensitive = false, int maxResults = 500})` | path: TXT 文件路径，query: 关键词 | `Future<List<Map<String, dynamic>>>` | 纯文本全文搜索（章节感知 + 上下文摘要） |
| `txtSearchRegex(String path, String pattern, {bool caseSensitive = false, int maxResults = 500})` | path, pattern: 正则表达式 | `Future<List<Map<String, dynamic>>>` | 正则全文搜索，返回格式同上 |
| `txtSearchInChapter(String path, String query, int chapterIndex, {bool caseSensitive = false, int maxResults = 50})` | path, query, chapterIndex（0 起） | `Future<List<Map<String, dynamic>>>` | 指定章节内搜索，返回格式同上 |
| `txtSearchCount(String path, String query, {bool caseSensitive = false})` | path, query | `Future<int>` | 匹配总数计数（不返回完整结果，供 UI 显示） |

### 2.41 契约外已实现 FFI 补登记（2026-08-06 审计，5 个方法）

> 以下函数已在 `rust/legado-ffi/src/ffi.rs` 实现并生成 Dart 绑定（`ffi.dart`），但此前未登记本契约（违反 §1.2「新增 API 须同步更新文档」），本节为补登记（承接 REMAINING_PLAN §4.2.2 P1-3）。其中多数尚未封装进 `BookApi` 抽象层，UI 封装计划见 §3「待 UI 封装清单」。
>
> **注（2026-08-07，Task #139）**：原 QUIC 系列 8 个函数（quicCreateClient / quicGet / quicPost / quicPerformanceTest / quicIsInitialized / quicCleanup / netSetQuicEnabled / netIsQuicEnabled）属原版不存在的新增能力，按「项目目标是纯重构」的用户决策已整体移除，不再作为契约项。

**其他（5 个）**

| 函数 | 所属模块 | 说明 |
|------|----------|------|
| `backupList` | 备份操作（§2.11 扩展） | 列出备份文件——✅ 已封装 `BookApi.backupList`（F3-20） |
| `cacheGetChapter` | 缓存管理（§2.16 扩展） | 获取已缓存章节内容（离线缓存 UI 批次依赖）——✅ 已封装接通（本次评审修复提交，`RustApi.getCachedChapter` 封装，书架菜单缓存导出） |
| `bookGroupSetShow` | 书籍分组（§2.14 扩展） | 设置分组显示状态——✅ 已封装 `BookApi.bookGroupSetShow`（F3-20） |
| `httpTtsSetEnabled` | HTTP TTS（§2.25 扩展） | 启用/禁用 HTTP TTS 配置——✅ 已封装 `BookApi.httpTtsSetEnabled`（F3-20） |
| `dictLookup` | 词典（§3 需求 4） | 词典释义查询——已迁入 `DictionaryService.dictLookup`，返回DictEntry（2026-10-16，见§2.45） |

### 2.42 TTS 合成、请求取消与登录管线（4 个方法）

> 对齐 Kotlin 原版 `HttpReadAloudService.getSpeakStream` + `AnalyzeUrl(speakText/speakSpeed)` 模型：
> url 模板占位符替换 → HTTP 请求获取音频二进制 → Content-Type 校验（`application/json` / `text/*` 视为服务器报错）→
> 以结构化请求配置、正文、源级语速、音色上下文和运行态登录/源变量的 MD5 命名缓存到本地（命中直接返回路径，避免重复请求）。
> 全局播放倍速不参与网络合成与缓存键，由播放端独立应用。
> Flutter 由 `HttpTtsSynthesizer.synthesize`（§2.26）调用此真实管线。服务器返回 json/text 时携带响应体文本；MIME 不匹配或配置无效时携带对应校验原因抛出 BridgeError。MIME 先去除参数，再按 contentType 正则完整匹配。
>
> **2026-10-13 审查修复约定**：HTTP 书级选择在 `readConfig.ttsEngine` 保存非零有符号 ID 字符串，系统保留 `system://default`；有效 ID 被删除或读取失败时不按 URL 改选其他引擎。缓存输入以结构化 JSON 序列化，覆盖完整请求配置（包括 jsLib）、正文、源级语速与音色上下文；全局播放倍速继续排除。JS 属性表达式和复杂表达式使用同一份安全变量绑定。合成错误保留原始原因，不作为成功探活或空产物吞掉。
>
> **T2b 请求与登录契约（2026-10-13 冻结）**：Rust 以数据库 HTTP TTS ID 构造 BaseSource，来源键 `httpTts:<id>`，不得保存为书源。`source`/`java` 可访问 getKey/getTag、源变量、登录 Header/信息及 login；源变量由宿主注入的存储落库。Header 优先级为源规则 → 登录 Header → URL 选项（大小写不敏感覆盖）；无效 Header 抛错。Cookie 延续域名共享和写侧 enabledCookieJar 门控，不隔离同域 Cookie。loginCheckJs 接收二进制响应对象（code/header/headers/body/request/newBuilder），返回修改后的响应；字符串/布尔完成值拒绝，正文不经过有损 UTF-8 转换。
>
> `ttsRequestNew()` 同步创建独立原生请求句柄，句柄 `cancel()` 同步置位；`ttsSpeak` 接收该句柄，等待同输入门禁、限流、网络和重试均可取消，取消不落盘、不进入失败估算。原生句柄释放随 FRB 生命周期，不建立全局请求 ID 表。源规则 JS 为同步沙箱执行，不能强制中断已进入的 JS 宿主调用；完成阶段再次检查取消。
>
> `httpTtsLogin({engineId, operation, payload})` 以 ID 读取当前配置；operation 为 ui（经典/V2 UI JSON）、action（V2 命令）、eval（经典按钮脚本，返回 result/actions）、headers（源规则与登录 Header 合并后的请求头）、info/header（读回）、putInfo/putHeader（写入）。未知操作和不存在 ID 抛错。现有登录控件通过回调适配复用，不改变书源登录接口。登录 UI 不把凭据写入 HTTP TTS 普通配置。
>
> **TTS 规则上下文约定**：
> - `speakText` / `text`：朗读文本
> - `speakSpeed` / `speed`：源级语速刻度 `(httpTts.speed ?? 5) + 5`
> - `currentToneID`：音色 ID（可选，默认空串）
> - `currentSpeakerName`：发音人名称（可选，默认空串）
> - `currentEmotionTag`：情感标签（可选，默认空串）
> - `currentEmotionName`：从本次捕获的源目录映射的情感名称，无匹配时为空串。
> - 支持 URL 模板、`@Header`、`@Body`、POST/GET 方法及 `@js:` / `{{js}}` 规则求值。
> **缓存目录**：默认为系统临时目录下 `legado_tts_cache`，由 Bootstrap 经 NativeRustRuntime 的 `setTtsCacheDirectory` 调用 `ttsSetCacheDir` 注入应用缓存目录。合成接口不初始化运行时、不改变目录或另存缓存。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `ttsSpeak({required int engineId, required String text, required TtsRequest request, String? toneId, String? speakerName, String? emotionTag})` | engineId: 引擎 ID，text: 朗读文本，toneId: 音色 ID（可选），speakerName: 发音人（可选），emotionTag: 情感标签（可选） | `Future<String>` | 原生 TTS 真实合成的 JSON 导出；根据 engineId 读取数据库 HttpTts 配置，经 `legado-fetcher` 的 TTS 变量上下文与 AnalyzeUrl 执行网络合成与校验；T2b 已接入 Source 常用 API、动态 Header、登录响应脚本、源限流与取消；同步 JS 宿主调用不能强制中断。返回字段（camelCase）：`audioPath: String`（本地音频文件绝对路径）/ `fromCache: bool`（是否缓存命中）/ `contentType: String`（音频 MIME 类型）。服务器返回 json/text 时携带响应体；其他校验失败携带对应原因抛出 BridgeError |
| `ttsRequestNew()` / `TtsRequest.cancel()` | 无 / 当前原生句柄 | 同步 `TtsRequest` / `void` | 创建和取消单次请求；不得复用已取消句柄。取消/失败在 finally 释放；成功交给音频租约，播放停止或预合成索引登记后释放。 |
| `httpTtsLogin({required int engineId, required String operation, required String payload})` | ID、上述操作名与载荷字符串 | `Future<String>` | 当前配置按 ID 查库；经典/V2 登录描述、动作、源规则 Header 及独立登录信息。未知操作、无效载荷及无对应引擎抛错。 |
| `ttsSetCacheDir({required String path})` | path: 缓存目录绝对路径 | `Future<bool>` | 设置 TTS 音频缓存目录（全局生效） |

### 朗读扩展：缓存、音色目录与云端（§2.42 补充）

**CONTENT-SEARCH-EXECUTION-20261023（B10b，实施前冻结）**：正文搜索执行迁入ReadingService，B10a Core匹配/UTF-16/摘要规则复用，Flutter不再逐章请求正文。
- 新增`contentSearch(options: ContentSearchOptionsDto, request: StreamRequest) → Stream<ContentSearchBatchDto>`，复用既有独立StreamRequest及managedRustStream；取消本订阅只取消捕获的TaskHandle，不查宿主新槽或取消其他任务。
- options含bookUrl/query/useRegex/useReplace/scope/currentChapterIndex；scope为current/cached/network：当前章；当前章加缓存URL匹配章；全部目录。当前章可正常取内容，其余缓存范围仅使用实际有效缓存，缓存清理或空缓存不触发联网补抓。目录顺序保持，每章最多50项、总200项。每个批次仅本章新增结果，含chapterIndex（初始进度为null）/chapterTitle/hits/scanned/total/error/limitReached；流自然结束表示完成，不重复传累计结果。
- 目录及原文/净化/本地路径复用ReadingService正式能力；在线实际读取ChapterContent，不再将readerGetContent的need_fetch描述JSON当作小说正文。净化开关只控制替换规则，保持既有繁简/去同标题等流程。历史、设置、标题搜索策略和命中跳转不扩展。
- 单章失败发error批次并继续；目录/宿主错误作为流错误；非法正则不读取正文并正常结束。进度沿用目录总量和已扫描目录位置，不以已选章节计数重定义。Rust统一返回limitReached，UI不维护另一份截断阈值。
- 执行登记在捕获引擎TaskGroup；阻塞章节IO不能强杀线程，网络等待select取消并向JS注入本任务凭据/执行租约，停止后拒绝正文缓存/副内容和结果提交；文件读取/同步净化等已运行步骤结束后退出，不声称瞬间中断所有CPU工作。进程/引擎关闭也能取消任务。
- B10a临时匹配句柄工厂/search从FFI移除（无外部兼容承诺），保留Core匹配器及结果DTO；Dart ContentSearchService改为流接口，取消/新查询/清空/销毁取消各自订阅，原generation仍隔离迟到事件。正式Mock不复制算法，测试使用固定批次验证编排。
- 不改数据库结构、依赖、应用版本、Web/MCP、播放或阅读器取内容既有入口；只定向测试，独立本地提交，不推送/安装。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**CONTENT-SEARCH-MATCH-20261023（B10a，FFI形态已由B10b取代，下述保留迁移依据）**：正文匹配和摘要坐标归Core，章节调度本批保留Flutter；不改DB/历史、搜索范围与开读导航。
- 新增`contentSearchBegin(query: String, useRegex: bool) → Future<ContentSearchMatcher?>`；空关键词、非法或被既有安全编译器拒绝的正则返回null，不请求正文。查询对象只持编译模式，无全局会话表、数据库或网络副作用。
- 句柄`search(content: String) → Future<List<ContentSearchHitDto>>`，每章最多50项，返回原文sourceStart/sourceEnd、snippet与snippet中的highlightStart/highlightEnd；所有位置为UTF-16半开区间。摘要保留本项目两侧30单位、换行为空格和省略号，边界向外对齐Unicode标量，避免切开代理对。
- 正则默认区分大小写、按整个正文查找，复用Core安全编译的regex/fancy-regex，核验前后查找、反向引用、原子组、零宽与UTF-16样例；不宣称Rust引擎覆盖全部Java Pattern。编译无效按上游返回空能力；执行错误上抛，不当作正常无命中。
- 普通搜索保留项目现有忽略大小写与非重叠语义，大小写转换后映射回原文坐标；这是与上游字面量区分大小写的已有差异，本批不更改产品选项。三档范围、每次200项上限不变。
- Flutter经ContentSearchService/Matcher窄接口取得结果；不预编译Dart RegExp、不二次匹配摘要。每个结果仅高亮自身命中，即使原正则包含摘要外上下文，也消费已计算位置。句柄由一次search的try/finally在任务结束后dispose；停止/新搜索沿用原generation拒绝迟到结果，章节IO的实际取消留B10b。
- Mock明确不支持未配置能力；测试注入固定类型化结果，Rust承担算法语义，Dart验证桥接、等待期间取消/替换与结果绘制，不复制算法。无新依赖/应用版本变更。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**SEARCH-INCREMENTAL-AGGREGATION-20261023（B9，实施前冻结）**：跨源聚合改由每次查询独立的原生句柄持有。新增`searchAggregationBegin(keyword: String) → Future<SearchAggregation>`，句柄异步add/snapshot/close，无全局字符串注册表或数据库副作用。
- 句柄方法：`add(books: List<SearchAggregateInputDto>) → Future<List<SearchAggregateRetainedDto>>`、`snapshot(keepOther: bool) → Future<List<SearchAggregateResultDto>>`、`close() → Future<void>`；一项工厂加三项句柄方法，类型化传输、不经JSON字符串。
- add只传每条原始name/author/origin/kind/origins/hasReadRecord；预去重仍是原始三元组，清洗、四桶、来源顺序/计数、阅读OR、首到平局沿用Core现有实现，不更改清洗规则。返回新建组的批内inputIndex与会话representativeId；后续归并不重复返回首条元数据。
- snapshot(keepOther)只返回representativeId、归一化name/author、origins与hasReadRecord；other始终保留在会话，精准开关仅控制快照，跨页继续追加。Flutter只为新建组保存首条完整SearchResult，按ID合并上述投影；不经SearchBookDto往返截掉Book字段，也不在两端保存全量输入历史。
- Dart经SearchAggregationService/Session窄接口串行append→snapshot→close；150ms仍为界面快照节流，不每条输入全量物化。自然onDone等待最后快照再结束loading；错误/停止先结束loading并隔离流回调，再取已接收批次最终快照，新查询/清空/销毁后的旧结果不回写。
- 自然完成保留句柄供续页；新关键词、清空、页面重置和Provider销毁释放，失败也可释放，不自动重试。已有SearchSession继续拥有网络取消/暂停，不把聚合close当网络cancel。Mock只提供明确夹具，不保留Dart算法副本。
- 无DB/版本/依赖变更，无正文搜索或书名作者清洗规则重做；原一次性Core入口复用新增量状态，外部空关键词一次性原样返回语义保持。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**TTS-RUST-PARTITION-20261023（B8d，实施前冻结）**：统一迁移整段/符号/页面切分与云请求长度分片至Core纯计算模块。新增两个异步只读FRB方法，无数据库、网络或全局会话：
- `readAloudPlan(content: String, mode: ReadAloudSplitModeDto, symbols: String, pages: List<ReadAloudRangeDto>) → List<ReadAloudUnitDto>`；范围为原文UTF-16半开区间，unit含start/end/sourceParagraphIndex/isParagraphEnd，不重复返回文本。整段/符号忽略pages；页面仅消费既有真实完整分页范围，保留既有范围错误，先段落再页切片，不合并同页多段。
- `cloudTtsPartition(provider: CloudTtsProviderDto, texts: List<String>) → List<SpeechPartitionDto>`；结果与输入同序，每项含ranges（输入文本内UTF-16半开范围），不重复传inputIndex。Provider在Rust内决定上限，沿用现有句末/词界/字形簇断点、UTF-16/UTF-8限制和错误，不新增引号吸收等算法优化。
- Dart经ReadAloudPlanner窄端口，正式实现仅DTO映射及substring，不保留算法；Flutter提供原文、设置和真实页界，保留播放器/后台窗口/媒体/定位编排。页界登记仍为同步快照更新，生成计划时Rust核验，不在界面登记时重复调用FFI。
- 新增await后复用既有token/generation与预合成窗口身份检查，拒绝迟到结果启动旧会话。暂停恢复对剩余文本分片，保留原文基点、播放单元与原段落编号、缓存身份和停顿粒度。
- 无持久章节句柄，不查询布局finish后的已释放状态，不在分页时绑定Provider。Mock仅显式夹具/不支持错误，不复制算法；迁移前行为快照作为Rust组合用例，Dart只验证传参与调度。
- Core复用锁文件已有unicode-segmentation 1.13.3，仅增加Core直接依赖关系，不升级包。版本保持2.0.439+440，无DB/设置迁移，Server旧朗读模块与符号引号暂缓保持。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**TTS-PAGE-PARAGRAPH-20261023（实施前冻结，Dart内部模型）**：按本地上游
ReaderReadAloudChapter对齐页面模式：先生成原文段落，再以真实页起点切开段落；
同页多个段落不合并。继续使用现有完整分页范围及既有一致性验证，不猜测分页。
ReadAloudUnit保留start/text/sourceParagraphIndex/isParagraphEnd，end由start+文本UTF-16
长度派生；同一原文段落在页面/符号切分后共享sourceParagraphIndex，仅最后片继承
真实段末。云请求的长度片段是另一种范围，不冒充逻辑段落；构建播放cue时以原单元
切片传递语义，仅最后一片继承isParagraphEnd。cue的unitIndex继续指播放单元，
与sourceParagraphIndex分开；段落切换、选择及缓存索引仍用播放单元索引。
当前段间停顿按播放单元执行，沿用上游服务和既有行为，不改成仅真实段末停顿。
不调整原有换行/首尾空白归一、符号断点（引号问题暂缓）、长度断点/阈值、旧Rust
朗读模块、数据库、设置键、FRB方法或生成物；只更新Dart内部契约及直接消费者。

编写者：Codex + UI｜2026-10-23

**RUST-BOUNDARY-B8B-20261023（实施前冻结）**：新增只读
`cloudTtsCapabilities() → Future<List<CloudTtsCapabilitiesDto>>`，一次返回八家已支持Provider
的类型化能力：provider、defaultModel/defaultVoice、formats/styles、表单能力开关
（支持语速/语言/韵律/角色/风格/指令/采样率、需要区域/AppID/SecretKey、使用模型、
远端目录/静态完整目录）、sourceSpeedRange/prosodyRange（min/max）、
sampleRates/pcmSampleRates（Polly沿用现有按格式区分的采样率列表，其他为空）。
查询不访问数据库/凭据/网络；默认值及格式来自Core同一描述，DB默认请求、Provider
格式/适用范围校验及Flutter表单共享。数值范围表示既有表单支持的编辑范围，Azure等
Provider已有更宽的协议接受范围保持，不借收敛缩小既有载荷口径；动态音色/模型约束
继续由实际Provider校验，不以静态能力假装全部有效。
CloudTtsRepository新增providerCapabilities()，正式实现只映射DTO，Mock提供离线夹具。
Flutter保留本地化名称/标签/提示和显示顺序，删除生产静态业务配置表；表单打开前
获取能力快照，失败走现有错误面，不回退旧表。新建使用默认值，编辑保留已存值及
未展示参数，不自动迁移/重写配置。FRB加法式新增1方法，现有方法及DB结构不变。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

**RUST-BOUNDARY-B8A-20261023（实施前冻结）**：新增只读
`cloudTtsSpeechLimits(provider: CloudTtsProviderDto) → Future<CloudTtsSpeechLimitsDto>`，
返回 `maxUtf16Units: u32` 和 `maxUtf8Bytes: Option<u32>`，不访问数据库、网络或凭据。
这是应用请求分片的保守阈值，不把服务端字符计数误称为UTF-16：通用4000 UTF-16，
百炼600、Polly3000；火山V1/V3另限1024 UTF-8字节。保留现有分片结果。
Rust统一保存阈值及Provider已有硬限制常量；Flutter CloudTtsRepository新增
`speechLimits(provider)`，正式播放、队列构建与预合成消费同一查询快照，
删除Dart配置表的长度/字节限制。Mock使用明确的无FFI夹具，不复制远端校验算法。
请求等待期间沿用现有会话代次校验；查询失败上抛，不回退另一份限制表。
不修改分片算法、界面参数、数据库、缓存身份、凭据或播放队列策略，FRB加法式新增1方法。

编写者：Codex + Rust / UI / Bridge｜2026-10-23

按 ID 元数据入口 cloudTtsGet 的可空 DTO 与错误语义见顶部 TTS-LOOKUP-20261020。

Gemini 3.8 与火山 V1/V3 增量见本文顶部 TTS-GEMINI-20261020、TTS-VOLCENGINE-20261020、TTS-VOLCENGINE-V3-20261020；方法签名和元数据表不变。

Polly 增量契约见本文顶部 TTS-POLLY-20261020；新增 aws_polly、成组调用凭据及 supportedModels，既有方法签名不变。

**TTS-AZURE-20261019（实施前冻结）**：新增 azure_speech，沿用云端元数据表、凭据引用、
音色表与播放会话。region 或自定义 baseUrl 决定端点；SSML 合成使用 Subscription-Key，
支持 mp3/wav/ogg/opus、语言、风格、角色、语速、音调、音量，XML 必须转义。
Core 仅构造/解析协议，Fetcher 执行网络，Engine 核对数据库与凭据引用并隔离取消生命周期。
请求体以 JSON/SSML 枚举表达；缓存身份包含实际请求体、输出格式及必要请求头。
新增 cloudTtsEngineVoices(engineId,apiKey,credentialKey,request:TtsRequest) 返回完整音色 DTO，
包含 id/displayName/locale/gender/styles/roles/sampleRate；按当前保存的引擎配置发现，
不从 Flutter 传地址绕过校验。静态 cloudTtsVoices 保留三家已有目录，Azure 必须走引擎发现。
Flutter 通过独立 CloudTtsVoiceCatalog 窄服务查询，不让配置仓库承担凭据或网络编排；
音色编辑器进入时获取远端目录，关闭取消，失败可重试或手动输入 ID，不写入整份目录。
引擎 Sheet 增加区域，音色 Sheet 按能力展示参数；切换原生音色更新目录的语言/风格/角色。
无数据库迁移、依赖升级、历史回填、播放队列改造；真实账号和移动后台另行验收。

**T3b 朗读缓存与预合成（2026-10-13，实施前冻结）**：不更改 ttsSpeak 入参及三个 JSON 字段。单次 TtsRequest 在成功合成后持有返回文件的缓存租约；RustHttpTtsSynthesizer 将句柄所有权交给 HttpTtsAudio.lease，停止播放器后释放；预合成登记索引后立即释放，取消/失败在 finally 释放。请求期间保护缓存读取与发布，避免清理竞争；此保护是进程内文件生命周期，不是另一份播放状态或数据库事实。

| 原生方法 | 返回 | 约束 |
|---|---|---|
| `ttsCacheRecord(audioPath, contextJson)` | `Future<void>` | context 为 bookUrl/bookName/chapterIndex/chapterTitle/paragraphIndex/text，章段索引非负；仅接受当前缓存目录中的正规音频文件。一个文件可关联多个书/章/段，索引用独立 JSON 原子发布，不改数据库 schema。 |
| `ttsCacheList()` | `Future<String>` | JSON 数组：name/sizeBytes/modifiedAtMs/protected/contexts。只列已发布的非空音频，不将 .part/索引文件当成音频；没有索引的缓存可列为 contexts=[]，不回填历史数据。 |
| `ttsCacheClear({String? name, BigInt? beforeTimestampMs, String? keepBookUrl, int? keepChapterIndex})` | `Future<String>` | 不传 name 清理全部或过期项；传 name 删除单文件。返回 removedFiles/removedBytes/skippedFiles；保护请求中与租约持有的文件，不删活动临时文件。拒绝目录穿越和不合法文件名，不读取或删除音频符号链接，索引符号链接报错；删除失败抛 BridgeError，不伪装成功。 |

TtsCacheRepository 是独立窄接口，UI 不直接枚举/删除目录。Repository 对时间戳使用 int，Rust u64 经 FRB 生成为 BigInt，由正式适配器转换；keepBookUrl/keepChapterIndex 成对用于保留当前章。缓存保留 `audioCacheCleanTime` 单位分钟，默认 10，0 为即听即焚：停止并释放活动租约后清理；保留模式保护当前章，清理其他过期项。预下载 `audioPreDownloadNum` 默认 3 章；预合成 `ttsPreSynthesisConcurrency` 默认 3，与源 synthesisThreadCount 取小（1..8）。全局播放倍速不改变合成身份。调度只改变请求顺序，不改 Rust 规则求值、缓存键或音频格式；同输入优先复用排队/在途任务，取消不转失败估算。预合成失败不改变当前播放器状态。

**T4a 音色目录（2026-10-13，实施前冻结）**：新增独立 `read_aloud_voices` 表（schema v111，仅建表，不回填历史目录），HTTP 16 字段及表列保持不变。导入 HTTP 源的原始 JSON 中 speakersJson/emotionsJson 在 Rust 解析并同步；按上游仅接受字符串内嵌 JSON，支持平铺/分组与字段别名，平铺优先、同 ID 首项保留。没有有效 speaker 时不清空目录；正常编辑不丢既有音色；删除引擎清理其目录。源与目录保存处于同一事务，不能只保存其中一半。

**2026-10-19 HTTP 音色参数贯通（实施前冻结）**：不改 FRB 签名/schema。源目录 traitsJson
数组继续表示标签；用户 HTTP 预设保存为对象，保留 `tags` 与可选默认 `emotionTag`，
不丢未知参数。选择中的 emotionTag 为 null 时使用预设默认值，空字符串表示用户明确选择
引擎默认情感，非空值为显式覆盖。目录内不存在的情感提示并回落默认；没有情感目录的源
允许直接传标签，由其规则自行解释。编辑当前选中预设后重置情感覆盖，让正文使用新预设；
列表试听使用与正文相同的选择解析，编辑草稿试听只消费草稿、不写默认选择。
Rust 从操作捕获的源目录映射情感名称/标签：精确匹配、上游同义词、目录默认项，未知值不
猜测私有标签；无目录保留输入标签。规则收到 currentEmotionName/currentEmotionTag，二者
进入实际音频缓存身份。前台预合成身份继续按有效 toneId/speakerName/emotionTag 区分。
本批不增加自动情绪识别或云端参数，不更改播放队列。

目录行字段：id/engineType/engineId/speakerId/displayName/traitsJson/emotionCatalogJson/managedBy/enabled/available/excluded/revision/createdAt/updatedAt。稳定 ID 对齐 SpeechIdentity：`voice:` + SHA256(`engineType + NUL + engineId + NUL + speakerId`) 前 32 小写十六进制字符。HTTP 的 engineId 是数据库整数的字符串，speakerId 是 toneID；系统 engineId 为 `system:<设备引擎>`，speakerId 优先设备 identifier，否则 name。系统发现由现有 SystemTts 平台接口负责，Rust 不访问 TTS 插件。

| 新增原生接口 | 返回/约束 |
|---|---|
| `readAloudVoiceList()` | Future<String>，全量目录 JSON 数组，包括排除项；可选候选必须 enabled && available && !excluded。 |
| `readAloudVoiceSyncSystem(engineId, entriesJson)` | Future<void>，仅同步给定系统引擎；输入 speakerId/displayName/traitsJson。保留已存在行的 enabled/excluded/createdAt，缺失系统项标为不可用，不删除用户偏好。 |
| `readAloudVoiceSetFlags(id, enabled, excluded)` | Future<bool>，只改用户标记；ID 不存在返回 false，不伪造新目录行。 |

`ReadAloudVoiceRepository` 窄接口提供查询、系统同步和标记修改，HTTP 导入同步不经过 UI 算法。源级目录情感列表挂到该源每个音色，传入 toneId/speakerName/emotionTag 三项均进入已有 ReadAloudRequest 与 Rust 合成上下文/缓存键。选择按引擎持久化；换引擎不沿用上一源 toneID，选中不可用/排除音色不静默替换，保持默认参数并给出提示。系统选择复用 saveSettings；目录发现不依赖所选音色能成功播放，起播/非原生暂停恢复时校验当前设备目录和用户标记。显式系统音色消失、禁用或排除时保留选择并报错，不自动换声；默认选择避开不可选项。暂不实现系统音频文件合成或新原生桥。

**2026-10-15 播放编排对齐（用户授权）**：不新增或修改FRB方法。内容单元保留原文UTF-16范围，请求分片不改变原文坐标；云端失败暂停并保留当前单元，不按估算推进。HTTP/云端复用有界调度、取消和现有音频租约；云端缓存索引记录实际分片文本。内容划分设置经ReadAloudSettingsRepository维护，页面模式消费真实排版范围；无分页结果时明确报告不可用，不凭字数猜测。

**2026-10-14 音色/引擎职责拆分（用户授权，实施前冻结）**：复用 schema v112 的 read_aloud_voices，不新增表。按固定上游使用 engineType/engineId/speakerId 的稳定身份；同引擎的不同原生音色分别保存，重复添加同一音色编辑原行。用户配置 managedBy=user，目录同步保留用户名称/参数；引擎删除清理关联音色。云端 engineType=cloud_tts、traitsJson 为 CloudVoiceOptions 对象，speakerId 为原生音色 ID；HTTP/系统继续复用现有选择协议。

| 新增接口 | 语义 |
|---|---|
| readAloudVoiceSave(voiceJson) | Future<void>；保存完整 ReadAloudVoice 用户配置，验证稳定 ID、引擎存在、参数对象，不允许把一个已有 ID 改绑其他引擎/音色；时间戳与 revision 由 Rust 管理。 |
| readAloudVoiceDelete(id) | Future<bool>；删除用户音色；自动同步目录通过排除标记保留，不允许删除后重建。 |

CloudTtsSynthesizer.synthesize 增加可选 voiceId（保存的音色记录 ID）、voiceOptions（仅试听草稿）；cloudTtsSpeak 的 requestJson 扩展相同二选一字段。Rust 从音色表读取配置并核对所属引擎/可选标记；草稿只接受受限 CloudVoiceOptions 字段，不能传地址/凭据。选择按 cloudTtsVoice:<engineId> 保存音色记录 ID，不修改引擎 optionsJson 或凭据。实际合成参数覆盖音色、风格、指令、语速和格式，进入现有请求缓存身份。原有省略音色的调用仍使用引擎默认参数；未增加历史回填。

引擎页只管理服务/凭据/请求配置，音色页添加/编辑/删除/试听音色。试听使用独立会话和播放器，先暂停正文，不写默认选择、不改变引擎、不触发正文切段；退出页/换 Tab/停止使过期回调失效并释放租约。系统试听可传临时 voiceKey，不能写入持久化系统选项。

**T4b-1 原生云端合成基础（2026-10-13，实施前冻结）**：本批仅新增 Rust 内部 CloudTtsProvider/OpenAI Speech 与可注入网络传输，不新增 FRB 方法、数据库表或用户入口。参考上游固定 070ca1a 的 OpenAiCloudTtsProvider；模型、音色、请求和格式语义以 TTS_ALIGNMENT 的明确清单为准。凭据仅作为调用输入，在内存准备 Authorization；Debug 和可导出 JSON 不含凭据。缓存身份包含引擎、目标、实际请求与凭据摘要，不将明文凭据落盘。缓存命中仍须先验证引擎启用、必填参数和凭据。取消覆盖锁等待和网络；结果使用既有 TtsCache 活动门禁/音频租约和 SpeakCache 原子发布。此内部接口不是已开放给 Flutter 的云端功能；后续安全存储、CloudTtsRepository、FRB 和 CloudReadAloudEngine 需分别冻结契约。

**T4b-2 云端配置与播放（2026-10-14，实施前冻结）**：schema v112 新增 cloud_tts_engines 元数据表，仅建表、不回填。字段 id/name/provider/baseUrl/model/optionsJson/region/appId/enabled/createdAt/updatedAt/credentialKey；不保存 apiKey 或 secretKey。T4b-2 首批 provider 为 openai_speech，T4b-3 增加 mimo，T4b-4 增加 alibaba_cloud，未知类型拒绝。ID 为 1..128 ASCII 字母/数字/下划线/连字符；credentialKey 为独立平台安全存储引用。正常保存保留 createdAt、更新 updatedAt；optionsJson 必须是合法对象，不接受私有凭据字段。

| 新增方法 | 返回与约束 |
|---|---|
| cloudTtsList() | Future<String>，元数据 JSON 数组，无明文凭据。 |
| cloudTtsSave(engineJson) | Future<void>，按 ID 原地保存元数据；拒绝载荷中 apiKey/secretKey，完整字段 camelCase。 |
| cloudTtsDelete(id) | Future<bool>，只删指定元数据，不读取平台凭据。 |
| cloudTtsVoices(provider) | Future<String>，当前 Provider 静态音色数组 id/displayName/styles/sampleRate（可选）；未知 Provider 抛错。 |
| cloudTtsSpeak(engineId,apiKey,requestJson,request:TtsRequest) | Future<String>，从 DB 读取当前配置并检查启用；apiKey 仅作为临时输入。requestJson 含 text/credentialKey 及可选 voiceId 或 voiceOptions；合成参数从所属音色记录或试听草稿读取，省略时使用当前 DB optionsJson，credentialKey 必须仍匹配 DB，拒绝读取期间已替换的凭据；结果 audioPath/fromCache/contentType，成功租约交给同一个 TtsRequest，沿用取消与释放机制。 |

CloudTtsRepository 窄接口仅管理元数据；CloudTtsCredentialStore 独立管理设备凭据；CloudTtsSettings 协调版本化引用写入：新凭据保存成功后再写 DB，DB 失败删除新引用、保留旧配置；DB 成功后清理旧凭据。删除先删元数据，再删凭据；后者失败明确提示已删配置而凭据清理失败，不伪装回滚或跨存储事务。不会读取历史凭据，不做明文存储回退。

选择使用 cloud://<ID>，复用当前书级/全局引擎设置，云端选择清空旧 HTTP 数值 ID；不保存为 httpTTS。CloudReadAloudEngine 实现现有 ReadAloudEngine 协议，复用共享文件播放器、媒体会话、缓存索引/租约和定时；停止/换源使旧回调失效。长段按 UTF-16/字形簇安全分片，段内完成只推进分片，整段全部播放完成才调用现有切段逻辑。云端合成参数源于 optionsJson，播放倍速仍独立。试听使用独立播放器和取消会话，不接管正文的完成回调；进入试听先暂停已有朗读。设备凭据、后台行为及真实云账号另行验收。


**T4b-3 MiMo（2026-10-14，实施前冻结）**：用户指定下一家优先 MiMo。provider 新增 `mimo`，schema v112 和五个 FRB 方法签名保持；未知 Provider 仍拒绝。默认模型 mimo-v2.5-tts、默认音色 mimo_default、输出仅 wav，音色目录对照固定上游九项；目录可附 styles/sampleRate，既有 id/displayName 保留。配置页按 Provider 提供默认模型/音色与格式，新建时可选择 Provider，并清空前一服务的地址和密钥；已保存的 Provider 在 UI/DB 均保持不变，需要更换时新建引擎，防止空密钥编辑把上一服务的凭据发送到另一服务。

MiMo 源选项保留 voiceId/style/instructions/format，format 为 wav；源 speed 不改变请求（上游未消费），配置页不显示该无效控制，播放倍速仍由播放器处理。Rust 准备 POST /chat/completions（兼容显式完整端点），使用 api-key 头，不添加 Bearer。instructions 作为可选 user 消息，style 非空时以 `(style)` 前缀进入 assistant 正文，audio 为 pcm16/voice，stream=true。网络传输只遵从 Provider 明确的鉴权头与响应类型，不让页面实现 SSE 或 Base64。

Provider 解码 text/event-stream 的 choices[0].delta.audio.data，按到达顺序拼接 Base64 PCM，使用 24kHz/16-bit/单声道/小端 WAV 适配。错误事件、坏 JSON/Base64、空音频或未完成流不能落盘；完成以 [DONE] 或 finish_reason=stop 为证，拒绝 length 等截断原因。保留 120 秒超时、完整响应后播放、取消、缓存去重/原子提交及租约，不新增边合成边播放或云端后台预合成。OpenAI 仍使用 Bearer 与直接音频响应，其原有 JSON/text 错误拒绝不能因 SSE 支持而放宽。不调用真实云账号。

**2026-10-19 云端音色参数保留（实施前冻结）**：不新增 FRB 方法、不改数据库 schema 或 Provider 协议。
CloudVoiceOptions 与 CloudVoiceOptionsDto 同步补齐可选 locale/role/pitch/volume/sampleRate，
同步生成绑定并重编原生库，不混用旧二进制；生成器 hash 一致不能替代字段兼容验证。
保存音色、引擎默认配置与试听草稿均映射至
已有 CloudTtsSynthesisRequest；缺省字符串为空、pitch/volume 为 1、sampleRate 为 null。
草稿与配置继续拒绝未知字段/地址/凭据，数字必须有限，sampleRate 为非负 u32；具体支持由
Provider 决定，不给百炼添加其接口不支持的数值调音能力。
云端音色编辑/试听以原 traitsJson 对象为底，仅覆盖表单实际编辑字段；保留未展示的
locale、role、pitch、volume、sampleRate 等参数。百炼增加语言编辑，保存去除首尾空白的
locale；空值沿用 Rust 的 Auto 默认语义，试听与保存使用同一草稿。不支持源级语速的
Provider 不新增 speed，但编辑不能删除已有字段；是否参与请求仍由 Rust Provider 决定。
参考固定 c4182eb9 的 CloudTtsViewModel.buildVoice/buildRequest 及 AlibabaCloudTtsProvider。

**T4b-4 阿里云百炼（2026-10-14，实施前冻结）**：新增 provider `alibaba_cloud`，保持 schema v112、五个 FRB 签名和设备凭据引用。对照固定上游 070ca1a AlibabaCloudTtsProvider：默认 qwen3-tts-flash、Cherry，四个内置音色 Cherry/Serena/Ethan/Chelsie，格式仅 WAV。POST multimodal-generation/generation，Bearer 鉴权及 X-DashScope-SSE: enable；input 为 text/voice/language_type（默认 Auto），仅 instruct 模型发送 style 与 instructions 以中文分号连接后的 instructions。源级数值速度不发送，播放倍速仍独立。

百炼会话采用不超过 600 UTF-16 的字形簇安全分片（保守满足官方 600 字符限制），原文进度累计与段落完成语义不变。SSE output.audio.data 按序拼接 PCM 并封装 24kHz 单声道 WAV；无 PCM 时使用 output.audio.url 下载完整 WAV。仅在 finish_reason=stop 或 [DONE] 后接受完整结果，错误、坏 JSON/Base64、截断、空音频不缓存。音频下载接受无用户凭据/片段的 HTTP(S) 地址（允许 OSS 签名查询），不携带合成请求凭据、不跟随重定向，沿用取消、120 秒超时及文本报错拒绝。UI/Mock/DB 共用新增服务商的默认值、格式和只读 Provider 规则。不调用真实云账号，不新增云端预合成或边合成边播放。

### 2.43 缓存写/购买/批量下载/导出扩展（Task #136 R5+R6+R7+R8，11 个方法）

> **Dart接线冻结（CHAPTER-CACHE-DOWNLOAD-20261015）**：ChapterCacheRepository提供clearBookCache、clearChapterCache、getCachedChapter、listCachedChapterUrls、listCachedChapters五项，参数和返回类型沿用原接口；空字数不收录，坏结构与非字符串条目抛FormatException。CacheDownloadService提供cacheDownloadStart、cacheDownloadCancel、cacheDownloadList、cacheDownloadProgress、listDownloadingChapters、listFailedChapters六项；仅列表/进度由JSON字符串提升为List<CacheDownloadTask>/CacheDownloadTask，其余签名不变。CacheDownloadTask包含taskId、bookUrl、status、total、completed、failed，字段必需且按Rust类型解码；未知状态字符串原样保留，notFound允许空bookUrl。正式实现直接调用既有FRB，不创建第二份任务状态；Mock保留原占位语义。旧downloadAddTask/downloadGetStats/downloadListByBook/downloadPauseAll/downloadResumeAll/downloadRemoveTask/downloadUpdateProgress仅移除Dart包装，本文对应Rust契约仍有效。全局缓存、媒体缓存及数据库结构不变。

> Task #136 合并批次，均为**加法式**新增（不改既有签名/行为）。仅走 frb 主链路（`ffi.rs`），
> 旧式 C ABI（`bridge.rs`）已在 RUST-EDITION-20261012 移除；本节能力统一通过 FRB 入口提供。

#### 2.43.1 R5 缓存写（1 个方法）

> 缓存系 FFI 此前仅读侧（§2.16 + §2.41 `cacheGetChapter`），写侧补齐：
> 复用 `legado-db` `CacheBookRepository.insert`（INSERT OR REPLACE），供阅读器「编辑内容/反转」闭环回写章节缓存。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `saveChapterContent({required String bookUrl, required int chapterIndex, required String title, required String content, String chapterUrl = ''})` | bookUrl, chapterIndex（0 起）, title（空串=从 DB 章节表回填）, content（正文原文，不做净化）, chapterUrl（空串=从 DB 章节表回填） | `Future<bool>` | 写入/覆盖单章缓存（cached_chapters 表），cached_at=当前毫秒、size_bytes=content 字节数；写入后可经 `cacheGetChapter` 读回一致 |

#### 2.43.2 R6 章节购买（1 个方法）

> 对齐 Kotlin `ReadBookActivity.payAction`：取书源 `ruleContent.payAction`（js 或含 `{{js}}` 的 url，空则报错 "no pay action"）→
> 复用登录 V2 JS 执行基础设施（书源 URL 分桶引擎池 + `eval_with_bindings`）执行，注入绑定 `baseUrl`=章节 url、
> `title`=章节标题、`book`/`chapter`=实体 JSON 对象、`source`=书源对象（Kotlin 另注入 java/result/src，Rust `java` 命名空间已全局注册，result/src 原版即为 null）。
> **结果语义（对照 Kotlin onSuccess）**：返回绝对 URL → UI 打开支付页 WebView；返回 "true" → 购买成功（Kotlin 随后清当前章缓存并刷新目录，UI 轨自行对应）；其他 → 原样回传。
> **R6 留项（F4-8，2026-08-14）**：含 `{{js}}` 的 URL 模板形态依赖 Android WebView 注入执行，Rust 侧**仅实现纯 JS 脚本**路径；URL 模板形态登记为后续留项（见 `pay_action_api.rs` 模块注释），不影响当前纯 JS payAction 书源。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `chapterPayAction({required String bookUrl, required int chapterIndex})` | bookUrl（本地书短路返回 kind=none，对齐 Kotlin isLocal 短路）, chapterIndex | `Future<String>` | 结果 JSON（camelCase）：`{"kind": "url"/"success"/"none", "value": "<JS 返回原文>"}`；kind=success 时 Rust 侧已清当前章正文缓存；需 quickjs 构建，否则返回 JsEngine 错误 |

#### 2.43.3 R7 缓存批量下载（4 个方法）

> 对标 Kotlin `CacheActivity` + `CacheBook` 批量缓存下载。运行态为进程内内存表（独立 worker 线程 + `AtomicBool` 取消令牌，
> worker 不用 tokio spawn 因正文抓取链路含 `block_on` 不可嵌套；取消对齐 §2.3 `cancelCheckSources` 的书源校验流机制）；
> **进度快照落库**至 `caches` 表（键前缀 `cacheDownloadTask:` / 索引 `cacheDownloadTaskIndex`，重启后恢复进行中任务并续跑；
> 终态任务亦可经 `cacheDownloadProgress`/`List` 回读）。逐章复用正文抓取链路 `get_chapter_content_full`
> （缓存命中免网络 → 网络抓取 → 缓存写入；本地书走解析器 + R5 写缓存），失败章计入 failed 并继续。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `cacheDownloadStart({required String bookUrl, required int startChapter, required int endChapter})` | bookUrl, startChapter/endChapter（章节 index，闭区间；越界自动收敛） | `Future<String>` | 创建并后台启动批量下载任务，返回任务 ID（字符串）；同一本书已有进行中任务时复用返回既有 ID |
| `cacheDownloadProgress(String taskId)` | taskId | `Future<String>` | 进度 JSON（camelCase）：`taskId`/`bookUrl`/`status`（running/completed/cancelled/failed/notFound）/`total`/`completed`/`failed` |
| `cacheDownloadCancel(String taskId)` | taskId | `Future<bool>` | 取消进行中任务（当前章完成后停止），返回任务是否存在 |
| `cacheDownloadList()` | 无 | `Future<String>` | 全部任务进度 JSON 数组（字段同上） |

#### 2.43.4 R8 书籍导出参数扩展（1 个方法）

> 加法式扩展：既有 `bookExport`（§2.31）签名与行为不变（缺省=现行为）。新方法以 `optionsJson` 透传参数，
> 对照 Kotlin `ExportBookService`（`AppConfig.exportCharset` 编码 / 章节范围 / `getExportFileName` 文件名规则）：
> - `encoding`：UTF-8（缺省）/ GB2312 / GBK / GB18030 / UTF-16 / UTF-16LE / ASCII（对齐 Kotlin `AppConst.charsets`），仅作用于 TXT；不可映射字符以 `?` 替代
> - `startChapter` / `endChapter`：章节 index 闭区间，缺省/`-1` = 不限
> - `fileNameTemplate`：`{name}` / `{author}` 占位符模板，缺省 = 现行为 `{书名}.{扩展名}`

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `bookExportWithOptions({required String bookUrl, required String format, required bool includeToc, String optionsJson = ''})` | bookUrl, format（txt/epub/html/pdf）, includeToc, optionsJson（`{"encoding":"GBK","startChapter":0,"endChapter":9,"fileNameTemplate":"{name} 作者：{author}"}`，空串=全缺省） | `Future<String>` | ExportResult JSON（同 §2.31 `bookExport` 返回结构） |

#### 2.43.5 目录页缓存态查询（Task #22，1 个方法）

> [UI-fix v2.0.6 | 2026-08-08] 加法式新增（不改既有签名/行为），仅走 frb 主链路（`ffi.rs`）。
> 目录页云图标缓存态数据源：复用 `legado-db` `CacheBookRepository.get_by_book`（按
> `book_url` 复合键查询，不串本），仅提取 `chapter_url`。对齐 Kotlin
> `item_chapter_list` 的 `iv_toc_cache`（已缓存实心云 / 未缓存空心云）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `cacheListCachedChapterUrls({required String bookUrl})` | bookUrl | `Future<String>` | 已缓存 `chapter_url` 的 JSON 字符串数组（`["url1","url2",...]`，按 chapter_index 升序、空 url 过滤）；Dart 侧 `RustApi.listCachedChapterUrls` 解析为 `List<String>` 供目录页渲染云图标 |

#### 2.43.6 目录页实时字数刷新查询（P2-28c，1 个方法）

> [P2-28c | 2026-09-28] 加法式新增（不改既有签名/行为），仅走 frb 主链路（`ffi.rs`）。
> 目录页实时刷新数据链：§2.43.5 的升级形态——单次只读查询（纯 SELECT）返回该书已缓存章节的
> (chapter_url, wordCount) 集合，使目录页 1 秒轮询（P2-28b）一次调用同时完成 URL 集合 diff
> （翻转「未缓存」⬇ 图标）与字数映射刷新（新缓存章的字数胶囊**同帧出现**，对齐参考版
> `ChapterListFragment` 订阅 `SAVE_CONTENT` 同帧刷行语义）。
> wordCount 取 `chapters` 表当前值（与 P2-28b 回填链同源，避免 `cached_chapters` 表内旧快照），
> 未回填为空串。过滤语义与 §2.43.5 一致：按 chapter_index 升序（repository 已排序）、空
> `chapter_url` 过滤；有目录的书同步过滤已退出当前目录的陈旧缓存行（[B-5] 同源）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `cacheListCachedChapters({required String bookUrl})` | bookUrl | `Future<String>` | 该书已缓存章节 url+wordCount 的 JSON 对象数组（`[{"url":"...","wordCount":"..."},...]`，按 chapter_index 升序、空 url 过滤；wordCount 取 `chapters` 表当前值，未回填为空串）；Dart 侧 `RustApi.listCachedChapters` 解析为 `Map<String, String>`（url → wordCount，空 wordCount 不收录）供目录页实时字数胶囊渲染 |

#### 2.43.7 目录页下载中态查询（P2-29，1 个方法）

> [P2-29 | 2026-09-29] 加法式新增（不改既有签名/行为），仅走 frb 主链路（`ffi.rs`）。
> 目录页五态行 DOWNLOADING 态动画的数据链（对齐参考版 `TocViewModel` 的 `runningIndices`
> —— 源自 `CacheBook.downloadStateFlow` 全局状态流）：单次只读查询（进程内任务表纯读 +
> `ensure_restored` 落库恢复回读，**零写入**）返回该书当前在途下载章节的 index 集合，
> 目录页 1s 轮询（P2-28b/c）与 §2.43.6 同周期拉取，驱动下载中行渲染 16px 加载指示
> （对齐参考版 `AppContainedLoadingIndicator` 16dp 形态，用户可见行为对齐）。
> 在途章语义：§2.43.3 的 worker 顺序逐章下载（`next_index` 恒为「当前正在抓取的章」
> 或「刚完成一章后待抓的下一章」），故每 `running` 任务至多一个在途章 = `next_index`
> （越出 `[start_chapter, end_chapter]` 闭区间不收录，任务终态后不收录）；
> 无活跃任务的书籍返回空数组。
> **ERROR 态留项**：Rust 任务表仅有 failed 计数、无逐章失败记录（补齐需任务表
> 写路径改动，超出本批授权）→ 目录页 ERROR 分支先落（红色重试图标 + 单章重下点击），
> 数据源恒空（恒不显示，不伪造），待失败记录数据链补齐后接入。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `cacheDownloadRunningChapters({required String bookUrl})` | bookUrl | `Future<String>` | 该书批量下载（§2.43.3）当前在途章节 index 的 JSON 整型数组（升序、0-based；无活跃任务为空数组 `[]`）；Dart 侧 `RustApi.listDownloadingChapters` 解析为 `List<int>` 供目录页 DOWNLOADING 态动画 |
| `cacheDownloadFailedChapters({required String bookUrl})` | bookUrl | `Future<String>` | 该书批量下载**已失败**章节 index 的 JSON 整型数组（升序、0-based；无失败为空数组 `[]`）；Dart 侧 `RustApi.listFailedChapters` 解析为 `List<int>` 供目录页 ERROR 态（红色重试图标，可点击重试）。**数据链（P2-29c 后续，2026-10-05 用户裁决）**：`TaskInner` 与持久化快照（`cacheDownloadTask:` kv）新增**失败章索引集合**（对齐参考版 `CacheDownloadStateStore.markFailed/markSuccess` 语义：失败加入、成功/重试移除、任务启动清空）；`run_download` 失败分支从仅递增 `failed` 计数改为同时记入集合，成功分支从集合移除；恢复回读（`ensure_restored`）一并恢复失败集合；`persist_snapshot` 序列化含集合。查询为**纯任务表读 + 恢复回读**，零额外写入 |

---

### 2.45 字典规则操作（dict_rule FFI，7 个方法）

> **Dart边界（2026-10-16）**：下表为既有FRB传输签名，根BookApi不再提供这些方法。
> DictRuleRepository接管七项：dictRuleList返回Future<List<DictRule>>，DictRule补齐id；
> dictRuleReorder(List<int> ids)在仓储内编码JSON，其他入参/返回不变。
> DictionaryService.dictLookup(String word)复用既有dictLookup FRB，返回Future<DictEntry>；
> 响应结构与字段类型错误明确失败，合法空definitions仍为未命中，不在Dart重新实现规则查询。
> 查询页、选词面板、规则管理及关联导入统一使用现有dictRules表，config:dict_rules和词典专用
> SharedPreferences版本标记不再读写，不迁移旧配置、不双写；空表seed沿用Rust，显式默认导入按名称覆盖并保留自定义项。
> 查询入口只展示启用项，管理页返回时重新读取共享仓储；保存无有效ID、写入false或排序计数不完整不得提示成功。
> 正式实现直接委托既有FRB，Mock保持原默认五源与无网络查询示例；Rust、绑定、数据库与默认资源未修改。
>
> [C2 批1 | 2026-09-13] 加法式新增（不改既有签名/行为）：字典规则 CRUD / 重排 / 导入经 frb 主链路（`ffi.rs` → `dict_api.rs`）暴露。
> 数据源 `dictRules` 表（`name` UNIQUE，按 `sortNumber` 排序）；`dictRuleList` 空表先注入原版默认 5 源（与 `dictLookup` 同 seed 语义）。
> 词典稳定实体使用DTO，真实导入文档保留JSON（§1.3）；`dictRuleReorder` / `dictRuleImport` 返回处理条数；解析/抓取失败返回**明确错误**（导入为显式动作，非静默跳过）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `dictRuleList()` | 无 | `Future<List<Map<String, dynamic>>>` | 列出全部字典规则（`ORDER BY sortNumber, id`）；空表先 seed 原版默认 5 源；每行 `{id, name, urlRule, showRule, enabled, sortNumber}` |
| `dictRuleAdd({required String name, required String urlRule, required String showRule})` | name / urlRule / showRule | `Future<int>` | 新增规则（enabled=1, sortNumber=0），返回新 ID；name 重复返回错误（UNIQUE 约束） |
| `dictRuleUpdate({required int id, required String name, required String urlRule, required String showRule})` | id / name / urlRule / showRule | `Future<bool>` | 按 id 更新规则（name/urlRule/showRule），返回是否实际更新 |
| `dictRuleDelete(int id)` | id | `Future<bool>` | 按 id 删除规则，返回是否实际删除 |
| `dictRuleSetEnabled({required int id, required bool enabled})` | id / enabled | `Future<bool>` | 按 id 启用/禁用规则，返回是否实际更新 |
| `dictRuleReorder(String idsJson)` | idsJson（JSON 数组 `[3,1,2]`） | `Future<int>` | 按给定 ID 顺序重编号 sortNumber=0..n（对标原版 upSortNumber），返回重排条数 |
| `dictRuleImport({required String jsonOrUrl, required String kind})` | jsonOrUrl / kind（text \| url） | `Future<int>` | 导入 GSON 数组/单对象规则（REPLACE by name：同名覆盖保留 id，异名插入）；kind=text 为 JSON 文本，kind=url 先经既有抓取链路取 body 再解析；返回导入条数 |

---

### 2.46 图片磁盘缓存（image_cache FFI，2 个方法）

> [P4-2a | 2026-09-29] 加法式新增（不改既有签名/行为）：漫画/图片书源图片的**磁盘缓存存取**，对齐原版 `BookHelp.saveImage`（L347+：`isImageExist` 命中即跳过 → 下载 → `writeImage` 写盘，写失败仅记日志**不抛异常**）与 `BookHelp.getImage`（L392+：返回缓存文件路径）+ `MangaVH.mangaImagePath`（L31-34：**本地优先**——缓存文件存在则取本地、否则走网络）语义。
> 目录结构对齐原版 `downloadDir/book_cache/{bookFolderName}/images/{md5_16(url)}.{suffix}`：缓存根目录经 `set_image_cache_dir` 进程注入（§1.6.1，Dart 启动时传应用私有缓存目录下 `image_cache` 子目录，与 `set_cache_dir` 同型；未注入回落 `<temp_dir>/legado-image-cache`）→ 书目录 = `sanitize(bookUrl)`（非法文件名字符替换 `_` 截断 64 字符 + `_{md5_8(bookUrl)}` 防截断碰撞，原版以 `book.getFolderName()` 为键、本书以 `bookUrl` 为键的加法式简化）→ `images/` → 文件名 = MD5(url) 小写 hex 中段 16 字符（原版 `MD5Utils.md5Encode16` = `hex[8..24]`）+ `.{suffix}`（原版 `UrlUtil.getSuffix(src, "jpg")`：URL 末段 `.` 后后缀，须匹配 `[A-Za-z0-9]{1,5}` 否则缺省 `jpg`）。
> 字节跨 FFI 走 base64 String（对齐 `fetchImageWithDecode` 的 `{base64, len}` JSON 惯例，§1.3 复杂类型 JSON 约定）：`saveImageCache` 入参 bytes 由 Dart 侧 base64 编码、`getImageCache` 返回 base64 由 Dart 侧解码。**写失败/读失败均降级**（save 返回 false、get 返回 null 并记一次性日志），不抛 FFI 异常——缓存是加速器不是数据源，失败必须不影响在线加载（对齐原版 saveImage catch 仅记 AppLog）。
> 书目录以 `bookUrl` 隔离（不同书互不串缓存）；图片文件按 URL 命名与 bookUrl 无关（同 URL 同书内幂等覆盖）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `saveImageCache({required String bookUrl, required String url, required List<int> bytes})` | bookUrl / url / bytes | `Future<bool>` | 图片缓存目录、命名和IO降级规则不变。FRB入参为Vec<u8>，不再接收或解码Base64；IO失败返回false，不影响在线显示 |
| `getImageCache({required String bookUrl, required String url})` | bookUrl / url | `Future<List<int>?>` | 读取磁盘缓存（对齐原版 `getImage`/`isImageExist` 的本地优先语义）：命中返回图片字节；未命中 / 读失败返回 `null`（降级走网络加载）。Rust FFI 面为 `get_image_cache(bookUrl, url) -> Result<Option<String>, BridgeError>`（base64 或 null；文件不存在与读失败均降级 `Ok(None)`） |

---

### 2.47 音频章节文件缓存（audio_cache FFI，4 个方法）

> [B1 | 2026-10-04] 加法式新增（不改既有签名/行为）：**音频章节音频文件的磁盘缓存只读面与清理面**，对齐原版 `AudioCacheManager` / `AudioPlay` 语义。
> **缓存键规则（严格对齐原版 `app/.../model/AudioCacheKey.kt:20-23`）**：`AudioCacheKey(MD5Utils.md5Encode16(chapterUrl.ifBlank { chapterTitle }))` —— 取**章节 URL**（为空才退回章节标题）的 MD5 小写 hex 中段 16 字符；**不含** `url + "|" + title` 拼接、**不含** bookUrl。`md5Encode16` 口径 = hutool MD5、小写 hex、`hex[8..24)`、UTF-8 字节、**不 trim、大小写敏感**（`MD5Utils.kt:29-33`；Rust 侧逐字节对齐先例见 `image_cache_api.rs:148` / `encoding.rs:36`）。
> **书级目录**：`{缓存根}/book_{md5Encode16(bookUrl)}`（原版 `AudioCacheManager.kt:210,228`，**即时计算、原版无映射表亦无 DB 记录**）→ 故 bookUrl 必须逐字符一致才能归位，跨应用不可直读原版目录（沙箱不继承 SAF 授权）。
> **命中判定（简化自原版 `AudioCacheManager.kt:201-203,358-373`）**：命中 = `key16` 匹配 **且** `.complete` 标记文件存在 **且** 音频文件 `size > 0`；同名多条取 `lastModified` 最新者。文件名五段式中的 title / playUrlHash / rev 三段**不参与命中判定**，仅过正则（`AudioCachePolicy.kt:11-13`）。**`.complete` 必须随行校验**：缺标记者原版眼中即不存在，导入/读取一律跳过。
> **只读面 + 清理面（不设写入面）**：按用户裁决（2026-10-04）「按原版做法」——原版写入只发生于预下载服务 `AudioCacheService`（`AudioCacheService.kt:217` 为全仓唯一 `cacheChapter` 调用方），**播放链从不写**（`AudioPlay.kt:388-413` 播放第一步查缓存、命中完全跳网络）。故本节**不登记任何写入方法**；写入面已于 2026-10-03 B2 批冻结至 **§2.48**（`audioCacheDownload` / `audioCacheCancel`，与本节写读同根同键）。
> **不纳入应用内备份**：原版官方备份产物为单一 zip（`help/storage/Backup.kt:122-131,416`，备份项见 `:52-98`），**不含音频缓存**（`help/storage` 包与备份 UI 中 `AudioCache*`/`LegadoAudioCache` 零命中；prefs 快照仅携带 `audioCacheTreeUri` 目录 URI 字符串，`BackupConfig.kt:101-116`）。按用户裁决（2026-10-04）**我方备份同样不含音频缓存**，故本节**不登记导入/导出方法**。
> 旧键 `${bookUrl.hashCode}_$i.audio`（重构版自创，`audio_screen.dart:996` 唯一引用、**无读取方**）按用户裁决**默认不读、不迁移**（按下标命名，目录重排后必错位且 `hashCode` 碰撞无从校验）。
> 失败一律降级（查询/列举返回空、清理返回实际删除数），**不抛 FFI 异常**——缓存是加速器不是数据源（同 §2.46 口径）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `audioCacheQuery({required String bookUrl, required int chapterIndex, required String chapterUrl, required String chapterTitle})` | bookUrl / chapterIndex / chapterUrl / chapterTitle | `Future<bool>` | 查询某章是否已缓存（**只读、幂等**）：按原版键规则计算 `key16` → 在 `{缓存根}/book_{md5_16(bookUrl)}` 下判定 `key16` 匹配 + `.complete` 存在 + size>0。`chapterUrl` 为空时用 `chapterTitle`（原版 `ifBlank` 语义）。目录不存在/无权限/解析异常一律返回 `false`（不抛异常）。Rust FFI 面为 `audio_cache_query(bookUrl, chapterIndex, chapterUrl, chapterTitle) -> Result<bool, BridgeError>` |
| `audioCacheList({required String bookUrl})` | bookUrl | `Future<List<int>>` | 列出该书**已缓存章节的章节下标数组**（**只读、幂等**）：扫描书目录内文件名，按原版五段式正则解析出章节序号与 `key16`（过不了正则的文件跳过并计数），仅返回通过 `.complete` + size>0 校验的条目，按章节下标升序。无缓存返回空数组 |
| `audioCacheClearChapter({required String bookUrl, required int chapterIndex, required String chapterUrl, required String chapterTitle})` | 同 `audioCacheQuery` | `Future<int>` | 清理某章缓存，返回**实际删除的文件数**（**仅统计数据文件，不计 `.complete` 标记**——对齐原版 `AudioCacheManager.kt:338-356`；**幂等**：不存在或已删返回 `0`，不抛异常）。只删该 `key16` 下的音频文件与标记（标记照删、只是不计入返回值），不触碰同目录其他章节 |
| `audioCacheClearBook({required String bookUrl})` | bookUrl | `Future<int>` | 清理该书**全部**缓存，返回实际删除的文件数（**同样仅统计数据文件，不计 `.complete` 标记**，对齐原版同上口径；**幂等**）；书目录一并尝试移除。**不跨书**（目录按 `md5_16(bookUrl)` 隔离，不同书互不影响） |

---

### 2.48 音频章节预下载（audio_cache 写入面 FFI，2 个方法）

> [B2 | 2026-10-03] 加法式新增（不改既有签名/行为；**契约先于代码**，本批不改任何代码）：**音频章节预下载写入面**，补齐 §2.47 只读/清理面所缺的下载安装能力，对齐原版 `AudioCacheService`（服务编排）+ `AudioCacheManager.cacheChapter`（写入本体）。
> **方法取舍（仅 2 方法）**：原版服务编排（任务队列 ArrayDeque、前台通知、START_NOT_STICKY 生命周期）**不上 FFI**——属 UI/应用层职责，Dart 循环逐章调用即可自持进度（done/total/fail 与原版通知计数 `AudioCacheService.kt:275-301` 等价）；唯一必须下放 Rust 的是「在途下载取消」（Dart 无法取消已发出的 Future）。决策策略（键计算、五段式文件名生成、扩展名探测、`.complete` 安装语义、已缓存跳过）**全部落 Rust**，UI 层零业务逻辑。
> **下载由 Rust 做（字节不穿 FFI）**：音频文件可达数十 MB，禁止 base64 穿边界（系 §2.46 图片缓存 base64 惯例的**反例登记**）。playUrl 由 Dart 经 **`audioGetChapterMedia`（§2.26 播放取址链）的 `mediaUrl`** 解析后传入——**修订说明（2026-10-04，主代理据实现批反馈修正契约初稿）**：初稿写「由 `getChapterContentFull` 解析」，但该链会应用替换规则与简繁转换（`reader.rs:1034,1111`）**可能污染 URL**；原版 `cacheChapterLocked:139-144` 实为**播放链** `WebBook.getContentAwait` 的输出，与我方 `getAudioChapterMedia` 同源，故实现取后者，**更贴原版**。取址同源保证 `.complete` 标记内 playUrl 与播放器将用的地址一致（可为含 `,{options}` 的 AnalyzeUrl 模板原串）；Rust 按 bookUrl 自 DB 载入 Book/BookSource/BookChapter，以 `legado-parser::AnalyzeUrl`（`analyze_url.rs:196`）+ `legado-fetcher` 等价语义发起下载（headers/cookie/JS/重试/限速全在 Rust，对齐原版 `AudioCacheManager.kt:148-154` 用 AnalyzeUrl 下载）；既有先例：`tts_speak`（`ffi.rs:2080`，Rust 下载+落盘+返回路径）、`webdavDownloadFile`（§2.28，字节零穿越）。
> **目录与命名（写读同根同键，严格对齐原版）**：写入根 = §1.6.1 `set_audio_cache_dir` 注入根（与 §2.47 读面共用）；书目录 = `{根}/book_{md5_16(bookUrl)}`（即时计算，`AudioCacheManager.kt:205-212/223-230`）；文件名五段式 `%05d_{key16}_{safeTitle}_{playUrlHash16}_{rev8}.{ext}`（`AudioCachePolicy.buildFileName:67-98`，正则 `:11-13`）——`key16` = `md5_16(chapterUrl.ifBlank{chapterTitle})`（与 §2.47 同源）；`safeTitle` = 标题经非法文件名字符替换 `_`（对齐 `normalizeFileName`）→ 去 ISO 控制符 → trim → 去首尾 `_` → 空则 `"chapter"` → 截 40 字符 → 去尾部 `.`/空格 → 空则 `"chapter"`（`AudioCachePolicy.kt:79-87`）；`playUrlHash16` = `md5_16(playUrl)`（不参与命中判定，仅区分同章换地址的历史版本）；`rev8` = 随机 8 位小写 hex（UUID 去连字符前 8 位，防并发同名）；`ext` 由 Content-Type 映射（mpeg/m4a/aac/ogg/opus/wav/flac/webm/amr/3gpp）→ 最终 URL 后缀 → playUrl 后缀 → 缺省 `"audio"`（`detectExtension:35-65`），须 ∈ 12 扩展白名单（mp3/m4a/m4b/aac/ogg/oga/opus/wav/flac/webm/amr/3gp）∪ `{"audio"}`（`:15-18`）。
> **下载安装流程（逐条对齐 `AudioCacheManager.kt:132-199`）**：① 前置校验（见方法行）；② 清理本 key 下陈旧未提交文件（`tmp_*.part` 与无 `.complete` 的五段式文件，lastModified 早于 1 小时者，`cleanupUncommittedFiles:302-314`，阈值 `STALE_PARTIAL_AGE_MILLIS:43`）；③ 流式下载写 `tmp_{key16}_{rev8}_{uuid}.part`（块级取消检查，对齐 `copyCancellable:397-412`；实现须 reqwest 字节流直写盘，禁整文件入内存后落盘）；④ size 校验（Content-Length>0 时最终大小必须相等且 size>0，`isCompleteFile:112-114`）；⑤ 安装（优先 rename 至五段式终名，SAF rename 失败退整文件复制后复验 size，`installStagedFile:232-264`）；⑥ 写 `.complete` 标记（内容 `1\n{md5_16(playUrl)}\n{playUrl}` UTF-8 三行元数据，写后**回读校验** decode==playUrl，不一致删标记报错，`createCompleteMarker:266-281` + `AudioCacheMetadata:137-153`）；⑦ 清理同 key 其他文件与标记（保留新安装文件，`removeCacheFiles:188/338-356`）；⑧ 任一步失败删除已安装文件+标记+tmp（`:190-197`）。
> **决策条件（原版事实，均落 Rust）**：原版**无用户开关**——AppConfig 仅 `audioCacheTreeUri` 目录键（`AppConfig.kt:728-735`），无 `readConfig.setCache` 类配置、无单章大小上限、无总容量上限/自动清理、无网络类型限制（仅 WiFi 与否不校验）、无超时。唯一决策门 = ① 分卷章节拒缓存（`cacheChapterLocked:115`）；② playUrl 校验——空 / JSON 数组多段 / HLS（`.m3u8`/`.m3u`，截 `?`/`#` 后大小写不敏感，`requireCacheablePlayUrl:25-33` + `isHlsUrl:116-119`，下载响应 Content-Type 含 mpegurl 或最终 URL 为 HLS 同拒 `:45-47`）；③ 已缓存跳过（服务循环 `AudioCacheService.kt:216`）。范围规范化（`normalizeRange:20-23`）与目录有效性预检（`isCacheDirAvailable:47-49`）属 UI/编排层，由 Dart 侧组合既有方法完成。**本批不新增**原版不存在的容量上限/自动清理（重构红线：禁止新增原版不存在的功能）。
> **已知边界（登记，不实现）**：原版为 Android 前台服务（通知+保活+AudioPlayActivity 内容 Intent），我方 FFI 下载仅在进程存活期间进行——App 被杀即停（已装文件保留，重入幂等=已缓存跳过）；无逐章失败明细持久化（对齐原版：计数仅在通知内存态）。
> **失败语义（有意区别于 §2.47 读面降级风格）**：写入是显式用户动作，失败**上抛 BridgeError 不降级**（原版 `cacheChapter` 返回 `Result`，服务计 `failCount` 后通知展示——Dart 循环等价承接）；错误文案对齐原版：「分卷章节不支持缓存」「播放链接为空」「暂不支持缓存多段音频」「暂不支持缓存 HLS 音频」「网络请求失败(code)」「音频文件为空」「音频文件不完整」「音频缓存完成标记校验失败」。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `audioCacheDownload({required String bookUrl, required int chapterIndex, required String chapterUrl, required String chapterTitle, required String playUrl})` | bookUrl / chapterIndex / chapterUrl / chapterTitle（章节四元标识，同 `audioCacheQuery`）/ playUrl（内容链解析所得播放地址原串，可为含 `,{options}` 的 AnalyzeUrl 模板） | `Future<String>` | 单章下载安装（**幂等**）：Rust 全权执行上文流程 ①–⑧；已提交缓存（命中判定同 §2.47：key16 匹配 + `.complete` 存在 + size>0）直接返回不重下（对齐原版服务 `AudioCacheService.kt:216` 跳过语义）；返回 JSON `{"status":"installed" / "already_cached","path":<本地文件绝对路径>,"sizeBytes":N,"extension":"mp3"}`。Rust FFI 面为 `pub async fn audio_cache_download(book_url: String, chapter_index: i32, chapter_url: String, chapter_title: String, play_url: String) -> Result<String, BridgeError>`（async + spawn_blocking 非阻塞，对齐 §2.17 webbook* 先例；实现落 `legado-ffi/src/api/audio_cache_api.rs` 扩展，复用其 `cache_key16`/`book_dir`/`parse_cache_file_name`）。前置校验：bookUrl 空白 / book 不在 DB / chapterIndex 无对应章（章不在 DB）/ playUrl 空 → Err；`isVolume` → Err「分卷章节不支持缓存」；playUrl 为 JSON 数组形态 → Err「暂不支持缓存多段音频」；HLS → Err「暂不支持缓存 HLS 音频」；书源不在 DB → Err（**差异登记**：原版为任务级静默中止整段范围 `AudioCacheService.kt:192`，我方逐章报错、由 Dart 循环决定后续，粒度更精细）。取消中断返回 Err「音频缓存下载已取消」 |
| `audioCacheCancel()` | 无 | `Future<bool>` | 取消当前在途下载（**对齐原版服务 stop 语义的单槽化**：原版单 worker 逐章处理 `AudioCacheService.kt:145-185`，全局同时至多一个在途下载）：进程级取消代数 +1，在途下载在每个流式块边界检查代数（对齐 `copyCancellable` 的 ensureActive），不匹配即中止拷贝并删除部分文件（对齐原版 CancellationException 清理路径 `AudioCacheManager.kt:190-197`）；返回 `true` = 置位时快照到在途下载（尽力提示，不作同步保证），`false` = 当前无在途；Dart 循环侧取消 = 调用本方法 + 停止发起后续章节调用。Rust FFI 面为 `pub fn audio_cache_cancel() -> Result<bool, BridgeError>`（同步立即返回）。**不设**进度/状态查询方法（Dart 循环自持进度，原版通知计数由 Dart 等价维护）；**不设**批量队列方法（原版 ArrayDeque 队列属服务编排，不上 FFI） |

---

### 2.49 视频弹幕数据链（video_danmaku FFI，1 个方法）

> [V-B1 | 2026-10-05] 加法式新增（不改既有签名/行为；**契约先于代码**，本批不改任何代码）：**视频弹幕数据链**——把书源内容规则副内容（`contentRule.subContent`）从「抓到即丢」接通到「捕获→落库→查询」，对齐原版 `BookContent` 弹幕链（`app/.../help/bookContent/BookContent.kt:156` `putDanmaku` → 章节变量 `danmaku`，`<10000` 字符进 variable 列、`≥10000` 走 `RuleBigDataHelp` 文件，`RuleDataInterface.kt:16`）与读取侧（`app/.../model/VideoPlay.kt:279` 读出 → `BiliDanmukuParser` 解析 B 站 XML）。
> **现状缺口（调研 `docs/VIDEO_TRACK_SURVEY_20261005.md` 实测）**：`rust/legado-fetcher/src/web_book.rs:3777-3783` `merge_sub_content_into_body` 在 `is_media`（视频/音频书）时**直接丢弃 subContent**——但提取链（含「http 开头则二次请求」语义，`:3731-3771` + 4 单测）**已完整实现**，缺的只是媒体分支的捕获与落库。**休眠资产激活**：`rust/legado-core/src/video_state.rs`（774 行，含 `DanmakuSource` 的 `Inline/File/None` 三态状态机 + 测试）当前零引用，本批激活为弹幕源归一入口。
> **方法取舍（仅 1 方法）**：查询面 `getVideoDanmaku`；**写入面不上 FFI**——捕获落库发生在 Rust 抓取链内部（fetcher 提取 subContent → 写章节 variable），与既有 `getChapterContentFull` 落库缓存同型，属数据链内部行为而非用户显式动作（对比 §2.48 音频缓存写入是用户显式动作故上抛 FFI）。**弹幕 XML 解析不在本节**：`BiliDanmukuParser` 的解析与渲染属 B2 渲染批（解析器归属另裁）。
> **字段模板**：对齐 §2.26 `getAudioChapterMedia` 的 `lyric` 字段先例（`audio_api.rs:44` `Option<String>` + `skip_serializing_if`）。
> **失败降级**：无弹幕返回 `null`（书源无 subContent / 未抓到 / 解析为空均同面）；查询异常降级为 `null` 不抛（弹幕是增强层不是数据源，对齐 §2.46 口径）。**幂等**：重复查询读同一落库值。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `getVideoDanmaku({required String bookUrl, required int chapterIndex})` | bookUrl / chapterIndex | `Future<String?>` | 查询某章弹幕数据（**只读、幂等**）：读章节 variable 列 `danmaku` 键（对齐原版 `putDanmaku` 落点）；`<10000` 字符直返原文（B 站 XML 或内联文本）；**≥10000 字符走文件存储**（对齐 `RuleBigDataHelp`，落点与文件名规则对齐原版实现，调研报告 §3.1）；无记录/书或章不在 DB/读失败 → `null`（降级不抛）。Rust FFI 面为 `pub fn get_video_danmaku(book_url: String, chapter_index: i32) -> Result<Option<String>, BridgeError>`。**数据链写入侧（本批一并实现，不上 FFI）**：fetcher 媒体分支从「丢弃 subContent」改为「捕获 → 按 `<10000`/`≥10000` 分流落库（variable 列 / 大数据文件）」；写失败降级仅记日志不阻断正文返回（对齐原版 putDanmaku 的非致命语义） |

---

### 2.50 视频弹幕解析（danmaku_parse FFI，1 个方法）

> [V-B2 | 2026-10-05] 加法式新增（不改既有签名/行为）：**B 站弹幕 XML 语义解析**，对齐原版 `help/gsyVideo/BiliDanmukuParser.kt`（SAX 解析，`:34-51`）。**归属依据（用户裁决 2026-10-05「同步原版逻辑」）**：解析属业务规则（p 属性语义、颜色/字号换算、类型过滤），落 Rust 服务侧，Dart 仅做渲染——原版解析亦在播放器服务链（非 UI 层）。
> **暴露面说明（B2 实现代理核查定案）**：`getVideoDanmaku`（§2.49）返回**原文**；解析结果必须经独立 FFI 到达 Dart（既有 284 导出无承接面；改 §2.49 返回结构=契约修订，不取）。**非 XML 容错对齐原版**：原版 SAX 解析失败 → null（**无容错、不包裹 `<i>`**，javap 实测 DanmakuFlameMaster 0.9.25 `load(InputStream)` 直连 `AndroidFileSource`）→ 我方解析失败/非 XML → `null`（静默无弹幕，对齐原版）。
> **解析语义（逐条对齐原版字节码与源码，B2 代理实测）**：
> - `<d p="时间秒,类型,字号,颜色,时间戳,池,hash,id">文本</d>`（`:80-89`）；`time = p0*1000` 毫秒（`:94-108`）；`color = (0xFF000000|p3)&0xFFFFFFFF`；仅解码 `&amp;&quot;&gt;&lt;` 四实体（`:257-272`）。
> - **类型映射**（DanmakuFlameMaster 0.9.25 `DanmakuFactory` 字节码）：1=右→左、4=底、5=顶、6=左→右、7=special（高级弹幕 JSON）；**2/3/8 返回 null 静默丢弃**（对齐原版）。
> - type7 高级弹幕：解析 JSON 属性（`:136-253`）但 **V-B2 渲染范围=1/4/5/6 四类**，type7 数据字段保留、渲染作**已登记边界**（用户裁决范围外不实现渲染）。
> - 描边色：`color<=BLACK?白:黑`（有符号比较 → 仅纯黑白描边，`:94-108`）；字号原值透传，`(density-0.6)` 平台换算由 Dart 渲染层做（**平台适配不属 XML 语义**，Rust 不做 density）。
> - **原版渲染配置（Dart 渲染层对齐，不属契约）**：滚动最多 5 行、SCROLL_RL/TOP 禁重叠、STROKEN 3f、不合并重复、scaleTextSize 1.0f（`VideoPlayer.kt:286-301`）；暂停/恢复（`:156-174`）、seek 同步（`:199-209`）、倍速联动 `danmakuSpeed-(speed-1)/6`（`:135-141`）；开关 UI 仅控制器条一个 TextView 文案「关弹幕/开弹幕」（`video_layout_controller.xml:72-81`），无弹幕时 GONE（`VideoPlayer.kt:266-272`）。

| 方法 | 入参 | 返回 | 说明 |
|------|------|------|------|
| `parseVideoDanmaku({required String raw})` | raw（弹幕原文：B 站 XML） | `Future<String?>` | 解析 B 站弹幕 XML 为 JSON 数组（**纯函数、无 IO、无 DB**）：每项 `{"timeMs":int,"type":int(1/4/5/6/7),"textSizeRaw":double,"color":int,"text":String}`，按 timeMs 升序（对齐原版加载序）；type 2/3/8 静默丢弃；type7 仅保留 JSON 属性字段（渲染边界见上）；解析失败/非 XML/空 → `null`（对齐原版 SAX 失败→null 静默无弹幕）。Rust FFI 面为 `pub fn parse_video_danmaku(raw: String) -> Result<Option<String>, BridgeError>`。Dart 侧 `RustApi.parseVideoDanmaku` 解析 JSON 为弹幕项列表供自绘渲染层（CustomPainter，不引第三方插件——原版 DanmakuFlameMaster 为 Android 专用库无 Flutter 等价，插件属新依赖须用户裁决） |

---

### 2.44 数据层实现备注（不涉契约签名）

> 本节登记数据层内部实现变更预告，均不改变任何契约签名，仅供 Rust 轨实施与双轨知会。
> 本节不含方法，不计入方法模块数与附录统计（方法模块为 47 个，§2.1–§2.50，编号跳过 2.24/2.27）。
>
> ℹ️ **BookRepository::insert 级联删除隐患（第三批后置项，Task #63）**：`BookRepository::insert` 当前走
> INSERT OR REPLACE，存在外键级联删除隐患；将在本批改为 upsert 链路（内部实现变更，不涉契约签名，不改任何 FFI 行为）。
>
> ℹ️ **瞬态 HTML/下载字段（F3-8，2026-08-14）**：`books` 表 `infoHtml` / `tocHtml` / `downloadUrls` 对齐原版 Room 列，存书源详情/目录页原始 HTML 与下载地址缓存，**非用户持久配置**；换源/清缓存时可被覆盖或清空，UI 不应当作权威书元数据。

---

## 3. UI 轨需求登记区

> UI 轨需要新数据时，在此登记需求，Rust 轨按契约实现。流程见 [TWO_TRACK_DEV_SPEC.md § 4.3](TWO_TRACK_DEV_SPEC.md)。

| 方法名 | 入参 | 期望返回 | 登记日期 | 状态 |
|--------|------|----------|----------|------|
| `getSearchHistory`（字段修复） | 不变 | `List<SearchKeyword>` 序列化字段对齐 Dart 模型：`word` / `usage` / `lastUseTime` | 2026-08-01 | ✅ 已完成 |
| `searchHistoryByPrefix`（新增） | `String prefix, {int limit = 20}` | `Future<List<String>>`（前缀匹配的历史关键词，对标 Android `searchKeywordDao.flowSearch`） | 2026-08-01 | ✅ 已完成 |
| `importBooks`（新增） | `String jsonArray` | `Future<int>`（批量导入书籍，返回成功导入数量，用于 WebDAV 书架批量回写） | 2026-08-02 | ✅ 已完成 |
| `searchMultiStream`（新增） | `String query, {List<String>? sourceUrls}` | `Stream<Map<String, dynamic>>`（多源渐进式搜索，逐书源推送批次，用于 Phase 3.3 渐进搜索） | 2026-08-02 | ✅ 已完成 |
| `searchCover`（新增） | `String bookName` | `Future<List<Map<String, dynamic>>>`（网络封面候选列表，字段建议 `url` / `width` / `height`，用于 Phase 6 P1 `change_cover_screen` 封面搜索） | 2026-08-01 | ✅ 已完成 |
| `dictLookup`（新增） | `String word` | `Future<Map<String, dynamic>>`（词典释义，字段对齐 Dart `DictEntry`：`word` / `phonetic` / `definitions[]`，用于 `dict_screen` 真实词典查询；Task #137 起数据源由静态占位表改为 dict_rules 字典规则引擎，见需求 4 补记） | 2026-08-01 | ✅ 已完成 |
| `highlight*` / `highlightRule*`（新增） | 见 §2.36 方法清单 | 高亮记录 CRUD + 高亮规则 CRUD（对齐上游 DB v96-v99，用于阅读器正文高亮一期） | 2026-08-04 | ✅ 已完成 |
| `reviewGetReplies`（新增） | `String sourceJson, String requestJson, int page` | `Future<String>`（段评回复按需加载，对标 Android `ReviewDetailDialog.loadReplies` + `ReviewRuleParser.parseReplyPage`，上游 #519；返回 `{items, nextPageUrl}` 对象包装，Flutter 段评弹窗回复 UI 由 UI 轨后续接入） | 2026-08-04 | ✅ 已完成 |
| `reviewGetSummary`（新增，P2-9） | `String sourceJson, String requestJson` | `Future<String>`（段评摘要，对标 `loadReviewSummary`+`parseSummary`；返回 `{counts, keys}`） | 2026-08-13 | ✅ 已冻结 |
| `reviewGetDetail`（新增，P2-9） | `String sourceJson, String requestJson, int page` | `Future<String>`（段评详情分页，对标 `ReviewDetailDialog`+`parseDetailPage`；返回 `{items, nextPageUrl, hasReplyUrl}`） | 2026-08-13 | ✅ 已冻结 |
| `appLog*`（新增，Task #79） | 见 §2.38 方法清单 | 应用日志体系：Rust 侧三级环形缓冲（message/crash/http）+ 写入/查询/清空/导出 FFI（对齐 Kotlin AppLog 旧欠账 + 上游 #543 导出 64K 截断），日志页面 UI 由 UI 轨接入 | 2026-08-05 | ✅ 已完成 |
| `checkSource` / `checkSourcesStream` / `cancelCheckSources`（新增，Task #87） | 见 §2.3 方法清单 | 书源校验 FFI 暴露：单本四步校验（CheckResult JSON）+ 批量串行 Stream 进度回推（CheckProgress JSON）+ 取消（包装 legado-net SourceChecker，对齐 Kotlin CheckSource 与 server /sources/check），校验页面 UI 由 UI 轨接入 | 2026-08-05 | ✅ 已完成 |
| `ruleSub*`（新增，Task #89） | 见 §2.39 方法清单 | 规则订阅 FFI 暴露：列表/保存/删除/启用切换/拖拽排序 + 检查更新/应用更新（DB v100 补全 Kotlin RuleSub 7 字段，委托 legado-net rule_update_client），订阅管理 UI 由 UI 轨接入 | 2026-08-05 | ✅ 已完成 |
| `verificationRequestStream` / `submitVerificationResult` / `cancelVerificationRequest`（新增，Task #90） | 见 §2.3 方法清单 | 验证码交互通道：JS 钩子（getVerificationCode/startBrowserAwait，对齐 Kotlin JsExtensions）经请求管理器挂起等待 → FFI 事件流推送请求（含航班去重/回放/5 分钟超时）→ UI 提交/取消唤醒；useBrowser 降级为图片验证码（桌面无 WebView），验证码弹窗 UI 由 UI 轨接入 | 2026-08-05 | ✅ 已完成 |
| `txtSearch` / `txtSearchRegex` / `txtSearchInChapter` / `txtSearchCount`（新增，Task #98 缺口#4） | 见 §2.40 方法清单 | 本地 TXT 全文搜索接入 frb 主链路：四项 TXT 搜索能力的 FRB 入口（包装 legado-book TxtSearch 引擎，纯文本/正则/章节内搜索 + 匹配计数，返回裸 JSON Array），供搜索页内“搜本地书正文”场景调用，UI 由 UI 轨后续接入 | 2026-08-05 | ✅ 已完成 |
| `setChineseConvertType` / `getChineseConvertType`（新增，Task #100） | 见 §2.9 方法清单 | 繁简转换 FFI 透传：reader.rs 硬编码 `chinese_convert: None` 改为读取持久化配置（键 `chineseConverterType`，0/1/2 → None/t2s/s2t），新增 set/get 接口；章节标题在展示路径补齐 t2s/s2t（对齐 Kotlin getDisplayTitle）；阅读器样式面板控件由 UI 轨接入 | 2026-08-05 | ✅ 已完成 |
| `ttsSpeak` / `ttsSetCacheDir`（新增，Task #113 缺口②） | 见 §2.42 方法清单 | TTS 真实合成管线：url 模板替换（speakText/speakSpeed）→ HTTP 拉取音频二进制（legado-net 新增 get_raw）→ Content-Type 校验 → MD5 命名本地缓存（命中免请求）；请 UI 轨将 `audioSpeak`（§2.26）的 `http.get` 探活 fallback 改接 `ttsSpeak`，音频播放器播放返回的 `audioPath` | 2026-08-06 | ✅ 已完成 |
| `readRecordDailyList`（新增，热力图「每日时长」） | `int year` | `Future<List<Map<String, dynamic>>>`（`[{date, seconds}]` 日期升序；写路径 `putReadRecord` 自动累加当日增量，见 §2.12） | 2026-08-29 | ✅ 已完成（单位归一 2026-09-11：存量毫秒经 v107 迁移归一为秒） |

#### 待 UI 封装清单（2026-08-06 审计：7 个 bridge 绑定已实现未被 UI 层封装）

> 以下 bridge 绑定（ffi.dart）已实现但未被 BookApi/rust_api.dart 封装或未被 UI 调用，登记于此供 UI 轨排期封装；封装后逐项销记。

| # | 绑定 | 所属组 | 备注 |
|---|------|--------|------|
| 1 | `sourceIsLoginUiV2` | 登录 UI V2 整组（§2.3） | ✅ 已封装接通（522e1c1be，`RustApi.isLoginUiV2`，书详/阅读器登录链路接入） |
| 2 | `sourceLoginUiV2` | 登录 UI V2 整组（§2.3） | ✅ 已封装接通（522e1c1be，`RustApi.loginUiV2`） |
| 3 | `sourceLoginActionV2` | 登录 UI V2 整组（§2.3） | ✅ 已封装接通（522e1c1be，`RustApi.loginActionV2`） |
| 4 | `backupList` | 其他（§2.41） | ✅ 已封装 `BookApi.backupList`（F3-20） |
| 5 | `cacheGetChapter` | 其他（§2.41） | ✅ 已封装接通（本次评审修复提交，`RustApi.getCachedChapter`，书架缓存导出） |
| 6 | `bookGroupSetShow` | 其他（§2.41） | ✅ 已封装 `BookApi.bookGroupSetShow`（F3-20） |
| 7 | `httpTtsSetEnabled` | 其他（§2.41） | ✅ 已封装 `BookApi.httpTtsSetEnabled`（F3-20） |
| 8 | `ttsSpeak` | TTS 真实合成管线（§2.42） | ✅ 原生导出保留，HTTP 合成由 `HttpTtsSynthesizer` 调用（2026-10-13 接口拆分） |
| 9 | `ttsSetCacheDir` | TTS 真实合成管线（§2.42） | ✅ 原生导出保留，Bootstrap 经 `NativeRustRuntime.setTtsCacheDirectory` 注入缓存目录（2026-10-13） |

> **销记更新（F3-20，2026-08-14）**：§3 待 UI 封装清单 **9 项全部销记**——登录 UI V2 三件套 + `cacheGetChapter` + `ttsSpeak`/`ttsSetCacheDir`（先前批次）+ `backupList`/`bookGroupSetShow`/`httpTtsSetEnabled`（本批补入 BookApi 抽象与 RustApi/MockBookApi 双实现）。**剩余待封装：0 项。**
>
> **移除记录（2026-08-07，Task #139）**：原表中 QUIC 客户端六件套（quicCreateClient/quicGet/quicPost/quicPerformanceTest/quicIsInitialized/quicCleanup）连同 netSetQuicEnabled/netIsQuicEnabled 总开关共 8 项 FFI，属原版不存在的新增能力，按纯重构决策已从 Rust/FFI/Dart 全链路移除，从本清单销记。

> **需求 1：getSearchHistory 字段修复（Bug）**
> 当前 Rust `search_history_api::get_search_history` 返回 DTO 字段为 `keyword` / `book_name` / `time`，
> 而 Dart `SearchKeyword` 模型（对齐 Android 原版实体）解析 `word` / `usage` / `lastUseTime`。
> 字段名不匹配导致 `SearchKeyword.fromJson` 解析后 `word` 恒为空字符串，
> 影响全局搜索历史与书内搜索历史（`search_content_screen.dart`）的真实 FFI 显示。
> 请 Rust 轨将 `SearchHistoryItem` 序列化字段对齐 Dart 模型（`word` / `usage` / `lastUseTime`）。
>
> **需求 2：searchHistoryByPrefix 前缀联想**
> Rust 仓储层已有 `SearchKeywordRepository::find_by_prefix`（LIKE 前缀匹配），但未暴露至 FFI bridge。
> 请暴露为 `searchHistoryByPrefix(prefix, {limit})` FFI 方法，供搜索页联想使用。
> UI 轨当前以客户端前缀过滤临时实现（行为等价），待本方法交付后切换为 DB 查询。
>
> **需求 3：searchCover 网络封面搜索（Phase 6 P1）**
> `change_cover_screen` 网络封面搜索原为 UI 内联占位假数据（`Future.delayed` + picsum 随机图）。
> Android 原版通过配置的封面源（图片搜索）按书名检索候选封面。请 Rust 轨提供 `searchCover(bookName)`。
> **响应契约**（snake_case，UI 侧已建 `CoverCandidate` freezed 模型对齐）：返回 `List<Map<String, dynamic>>`，
> 每项字段 `url: String`（封面图片地址，必需）/ `width: int`（像素，未知填 0）/ `height: int`（像素，未知填 0）。
> **错误语义**：无候选返回空列表（非异常）；网络/源异常抛出经 bridge 统一映射为 `BridgeError`。
> **UI 侧现状（Mock 先行）**：`ChangeCoverNotifier.searchCovers` 已就位并以 Mock 数据驱动 `CoverCandidate` 数据流，
> `change_cover_screen` 已重构为 `ConsumerStatefulWidget`（UI 层不再制造假数据）。Rust 交付后仅需将 Notifier 内
> `_mockSearch` 替换为 `ref.read(bookApiProvider).searchCover(keyword)` 并 `CoverCandidate.fromJson` 解析返回。
> 本地选图路径（FilePicker）不依赖本契约。因 UI 轨禁改 `rust_api.dart`，未单边添加 BookApi 抽象方法。
>
> **需求 4：dictLookup 词典查询（Phase 6 P2 延伸）**
> `dict_screen` 本地内置词典为静态占位数据，仅覆盖少量示例词。请 Rust 轨提供 `dictLookup(word)`。
> **响应契约**（snake_case，UI 侧已建 `DictEntry` freezed 模型对齐）：返回 `Map<String, dynamic>`，
> 字段 `word: String`（归一化后的单词）/ `phonetic: String`（音标，可空字符串）/ `definitions: List<String>`（释义条目）。
> **错误语义**：未收录词返回 `definitions` 空列表（非异常）；查询异常抛出经 bridge 统一映射为 `BridgeError`。
> **UI 侧现状（Mock 先行）**：`DictNotifier.lookup` 已封装查询职责，当前以本地内置词典 `_localDict` 为占位数据；
> 在线词典规则跳转经 `getConfig/setConfig` 持久化，不依赖本契约。Rust 交付后将 `_localDict[key]` 替换为
> `await api.dictLookup(key)`（届时 `lookup` 转异步）即可，模型字段即契约。
>
> **Task #137 补记（2026-08-07，数据源对齐原版字典规则，签名不变）**：
> Rust 侧 `dictLookup` 数据源由 18 词静态占位表改为对齐 Android 原版字典规则（dict_rules）体系：
> ① 查询 `dict_rules` 表全部启用规则（按 sortNumber 排序），逐条执行原版 `DictRule.search(word)`
> 等价链路（AnalyzeUrl urlRule 模板/`{{key}}`/data: URI → HTTP → AnalyzeRule showRule，`@js:` 经
> quickjs 特性执行）；② 表为空时注入原版默认 5 个字典源（海词中文/海词英文/有道/哔哩/百度汉语，
> 数据与 `assets/defaultData/dictRules.json` 逐字节同源）；③ 每条成功规则结果为一个 `definitions`
> 条目（前缀 `【规则名】`，原版为每规则独立页签），HTML 释义做轻量纯文本化；`phonetic` 恒为空；
> ④ 无启用规则/DB 未初始化返回空列表（非异常），单规则失败记日志跳过；
> ⑤ 入参仅 trim 不再小写（中文词兼容，原版原样传词）；⑥ 原版部分规则依赖 Rhino 专属能力
> （JavaImporter/org.jsoup/cache.putMemory）在 QuickJS 下不可等价复现，规则数据不改写、失败即跳过。

---

### 2.51 隐私凭据（3 个方法）

| 方法 | 参数 | 返回值 | 说明 |
|---|---|---|---|
| `privacyHasPassword()` | 无 | `Future<bool>` | 检查是否存在隐私密码；不返回摘要 |
| `privacyVerifyPassword(password)` | password | `Future<bool>` | 只校验身份，不授予内容访问权限 |
| `privacySetPassword(currentPassword, password)` | currentPassword、password | `Future<bool>` | 更改或清除已有密码须验证旧密码；空新密码清除凭据 |

Dart 窄接口 PrivacyCredentialRepository 的 hasPassword、verify、change 分别映射上述方法；不回填 BookApi。
完整平台与会话规则见本页隐私访问增量契约。

## 附录：模块方法数统计

| # | 模块 | 方法数 |
|---|------|--------|
| 1 | 初始化/版本 | 2 |
| 2 | 书架操作 | 11 |
| 3 | 书源操作 | 33 |
| 4 | 搜索操作 | 19 |
| 5 | RSS 源操作 | 11 |
| 6 | 本地书籍操作 | 4 |
| 7 | 书签操作 | 8 |
| 8 | 替换规则操作 | 8 |
| 9 | 阅读器操作 | 12 |
| 10 | 配置操作 | 4 |
| 11 | 备份操作 | 3 |
| 12 | 阅读记录 | 15 |
| 13 | RSS 收藏操作 | 4 |
| 14 | 书籍分组 | 4 |
| 15 | 搜索历史 | 5 |
| 16 | 缓存管理 | 9 |
| 17 | WebBook 操作 | 6 |
| 18 | 发现页操作 | 7 |
| 19 | 规则解析 | 1 |
| 20 | 网络操作 | 5 |
| 21 | JS 引擎 | 2 |
| 22 | 服务器管理 | 5 |
| 23 | 书籍格式解析 | 3 |
| 24 | HTTP TTS | 6 |
| 25 | 音频播放 | 5 |
| 26 | WebDAV 云同步 | 7 |
| 29 | 下载管理器 | 7 |
| 30 | 段评（ruleReview） | 3 |
| 31 | 书籍导出 | 2 |
| 32 | 自动任务 | 14 |
| 33 | 音频播放模式 | 2 |
| 34 | 压缩包导入 | 8 |
| 35 | RSS 已读记录 | 7 |
| 36 | 正文高亮 | 11 |
| 37 | JS 单文件书源配置 | 3 |
| 38 | 应用日志 | 5 |
| 39 | 规则订阅 | 7 |
| 40 | 本地 TXT 全文搜索 | 4 |
| 41 | 契约外已实现 FFI 补登记（§2.41，待 BookApi 封装） | 5 |
| 42 | TTS 合成、请求取消与登录管线 | 4 |
| 43 | 缓存写/购买/批量下载/导出扩展（§2.43，Task #136） | 11 |
| 44 | 字典规则操作 | 7 |
| 45 | 图片磁盘缓存 | 2 |
| 46 | 音频章节文件缓存 | 4 |
| 47 | 音频章节预下载 | 2 |
| 49 | 视频弹幕数据链 | 1 |
| 50 | 视频弹幕解析 | 1 |
| 51 | 隐私凭据 | 3 |
| | **合计（§2.x 附录行合计）** | **312** |

2026-10-23校准：阅读记录补计B7a时间线1项、B7b统计/当天明细2项、B7c小时分布1项和B7d列表1项，10→15。
此处为领域方法行合计，不是FRB导出总数。

> 口径说明（2026-08-15 程序化计数校准，2026-09-13 C2 批1 增 §2.45 字典规则 7 方法、书源作用域批次增 §2.8 替换规则 1 方法 `applyReplaceRulesToSource`、替换规则预览批次再增 §2.8 1 方法 `previewReplaceRule`、2026-09-24 换源预拉缓存批次增 §2.4 2 方法、2026-09-26 项 B/B1 增 §2.3 1 方法 `submitWebviewResultWithCookies`、2026-09-28 STAGE3-C2B 增 §2.16 单章缓存失效 1 方法 `clearChapterCache`、2026-09-28 P2-28c 增 §2.43 目录实时刷新 1 方法 `listCachedChapters`、2026-09-29 P2-29 增 §2.43 目录下载中态查询 1 方法 `listDownloadingChapters`、2026-09-29 P4-2a 增 §2.46 图片磁盘缓存 2 方法 `saveImageCache`/`getImageCache`、2026-10-03 cbz 批 B 增 §2.34 本地漫画页读取 1 方法 `cbzReadPage`、2026-10-04 B1 增 §2.47 音频章节文件缓存 4 方法、2026-10-03 B2 增 §2.48 音频章节预下载写入 2 方法 `audioCacheDownload`/`audioCacheCancel`、2026-10-13 UI-HOME-OVERVIEW-A1 增 §2.12 阅读记录单书每日明细 2 方法 `getReadRecordDetails`/`getAllReadRecordDetails`，取代人工统计）：

> - 附录行合计 **304** = §2.x 实际方法行总数；删除无调用方的阅读记录和 HTTP 列表别名，其余迁移只改变 Dart 接口归属。
> - BookApi 代码计数 **236**；书签六项、阅读记录十项（原五项 + 每日单书明细两项 + 会话/删除三项）、HTTP 配置七项、合成一项、书架十项、分组五项、书源十一项及书源校验三项由独立接口承担；
>   六个纯 FFI 为 `bookmarkGetAll` / `chapterPayAction` / `rssUpdateSource` / `ttsSpeak` / `ttsRequestNew` / `httpTtsLogin`，另有 Runtime 缓存设置一项；
>   `getCachedChapter` / `cacheGetChapter` 在 §2.16 / §2.41 登记同一能力，增加一行登记。
> - 闭合关系为 **304 = 224 + 7 + 5 + 6 + 10 + 7 + 1 + 10 + 5 + 11 + 3 + 4 + 6 + 1 + 1 + 3**：BookApi、书签、记录（含每日明细）、引擎配置、合成、书架、分组、书源、纯 FFI、Runtime 缓存设置及重复缓存登记；测试核对领域接口与旧方法移除；书源登录四项从根移入独立接口，TTS 请求创建/登录两项为纯 FFI。
> - 2026-08-15 之前的人工校准（F3-10 等）已由程序化计数取代，历史演进见 git 历史。

## 2026-10-14 朗读合并接线补充（实施前确认）

主目录 SourceLoginRepository 的四项原始凭据读写保留，BookApi 不恢复旧方法。
ClassicLoginDialog 默认入口继续注入凭据 Repository 和动作求值回调；新增
session 构造接受 TTS SourceLoginSession，两个来源共用既有表单逻辑。
WebView 同时接受书源 Repository 与可选 TTS 会话，TTS 读写通过会话，
普通书源仍走原 Repository；不把 HTTP TTS 伪装为书源。阅读记录三视图
与朗读新增的 FFI 方法全部保留，配对绑定从合并源码重新生成。
schema v112 保留阅读记录明细与两个朗读目录/元数据表，不覆盖任一建表。

编写者：Codex｜2026-10-14


### FFI-TRANSPORT-20261017 / P3 核心实体冻结

本次内部 DTO 同步替换书架 CRUD、书源 CRUD/列表与已有目录查询载荷；领域接口、JSON 导入导出、REST、数据库与页面行为保持。
DTO 字段如下（Rust snake_case，生成 Dart camelCase；所有 Option 保持 null 与空值区别，i64 保持 native 精确整型）：

> - `ReadConfigDto`：`reverse_toc: bool`, `page_anim: Option<i32>`, `re_segment: bool`, `image_style: Option<String>`, `use_replace_rule: Option<bool>`, `del_tag: i64`, `tts_engine: Option<String>`, `split_long_chapter: bool`, `read_simulating: bool`, `start_date: Option<String>`, `start_chapter: Option<i32>`, `daily_chapters: i32`, `open_credits: i32`, `close_credits: i32`, `play_mode: i32`, `play_speed: f32`, `use_global_audio_skip: bool`, `manga_scroll_mode: Option<i32>`, `webtoon_side_padding_dp: Option<i32>`。
> - `BookDto`：`book_url: String`, `toc_url: String`, `origin_book_url: String`, `is_private: bool`, `origin: String`, `origin_name: String`, `name: String`, `author: String`, `kind: Option<String>`, `custom_tag: Option<String>`, `cover_url: Option<String>`, `custom_cover_url: Option<String>`, `intro: Option<String>`, `custom_intro: Option<String>`, `charset: Option<String>`, `book_type: i32`, `group: i64`, `latest_chapter_title: Option<String>`, `latest_chapter_time: i64`, `last_check_time: i64`, `last_check_count: i32`, `total_chapter_num: i32`, `dur_chapter_title: Option<String>`, `dur_chapter_index: i32`, `dur_volume_index: i32`, `chapter_in_volume_index: i32`, `dur_chapter_pos: i32`, `dur_chapter_time: i64`, `word_count: Option<String>`, `can_update: bool`, `order: i32`, `origin_order: i32`, `variable: Option<String>`, `read_config: Option<ReadConfigDto>`, `sync_time: i64`, `info_html: Option<String>`, `toc_html: Option<String>`, `download_urls: Option<String>`, `cover_origin: Option<String>`。
> - `ChapterDto`：`url: String`, `title: String`, `is_volume: bool`, `base_url: String`, `book_url: String`, `index: i32`, `is_vip: bool`, `is_pay: bool`, `resource_url: Option<String>`, `tag: Option<String>`, `word_count: Option<String>`, `start: Option<i64>`, `end: Option<i64>`, `start_fragment_id: Option<String>`, `end_fragment_id: Option<String>`, `variable: Option<String>`, `img_url: Option<String>`。
> - `BookSourceDto`：`book_source_url: String`, `book_source_name: String`, `book_source_group: Option<String>`, `book_source_type: i32`, `book_url_pattern: Option<String>`, `custom_order: i32`, `enabled: bool`, `enabled_explore: bool`, `js_lib: Option<String>`, `enabled_cookie_jar: Option<bool>`, `concurrent_rate: Option<String>`, `header: Option<String>`, `login_url: Option<String>`, `login_ui: Option<String>`, `login_check_js: Option<String>`, `cover_decode_js: Option<String>`, `book_source_comment: Option<String>`, `variable_comment: Option<String>`, `variable: String`, `last_update_time: i64`, `respond_time: i64`, `weight: i32`, `explore_url: Option<String>`, `explore_screen: Option<String>`, `rule_explore: Option<ExploreRuleDto>`, `search_url: Option<String>`, `rule_search: Option<SearchRuleDto>`, `rule_book_info: Option<BookInfoRuleDto>`, `rule_toc: Option<TocRuleDto>`, `rule_content: Option<ContentRuleDto>`, `rule_review: Option<ReviewRuleDto>`, `main_js: Option<String>`, `event_listener: bool`, `custom_button: bool`。
> - `ExploreRuleDto`：`book_list: Option<String>`, `name: Option<String>`, `author: Option<String>`, `intro: Option<String>`, `kind: Option<String>`, `last_chapter: Option<String>`, `update_time: Option<String>`, `book_url: Option<String>`, `cover_url: Option<String>`, `word_count: Option<String>`。
> - `SearchRuleDto`：`check_key_word: Option<String>`, `book_list: Option<String>`, `name: Option<String>`, `author: Option<String>`, `intro: Option<String>`, `kind: Option<String>`, `last_chapter: Option<String>`, `update_time: Option<String>`, `book_url: Option<String>`, `cover_url: Option<String>`, `word_count: Option<String>`。
> - `BookInfoRuleDto`：`init: Option<String>`, `name: Option<String>`, `author: Option<String>`, `intro: Option<String>`, `kind: Option<String>`, `last_chapter: Option<String>`, `update_time: Option<String>`, `cover_url: Option<String>`, `toc_url: Option<String>`, `word_count: Option<String>`, `can_re_name: Option<String>`, `download_urls: Option<String>`。
> - `TocRuleDto`：`pre_update_js: Option<String>`, `chapter_list: Option<String>`, `chapter_name: Option<String>`, `chapter_url: Option<String>`, `format_js: Option<String>`, `is_volume: Option<String>`, `is_vip: Option<String>`, `is_pay: Option<String>`, `update_time: Option<String>`, `next_toc_url: Option<String>`。
> - `ContentRuleDto`：`content: Option<String>`, `sub_content: Option<String>`, `title: Option<String>`, `next_content_url: Option<String>`, `web_js: Option<String>`, `source_regex: Option<String>`, `replace_regex: Option<String>`, `image_style: Option<String>`, `image_decode: Option<String>`, `pay_action: Option<String>`, `call_back_js: Option<String>`。
> - `ReviewRuleDto`：`review_url: Option<String>`, `avatar_rule: Option<String>`, `content_rule: Option<String>`, `post_time_rule: Option<String>`, `review_quote_url: Option<String>`, `vote_up_url: Option<String>`, `vote_down_url: Option<String>`, `post_review_url: Option<String>`, `post_quote_url: Option<String>`, `delete_url: Option<String>`, `enabled: bool`, `review_summary_url: Option<String>`, `summary_list_rule: Option<String>`, `summary_paragraph_index_rule: Option<String>`, `summary_paragraph_data_rule: Option<String>`, `summary_count_rule: Option<String>`, `review_detail_url: Option<String>`, `review_detail_next_page_url: Option<String>`, `detail_list_rule: Option<String>`, `detail_id_rule: Option<String>`, `detail_avatar_rule: Option<String>`, `detail_name_rule: Option<String>`, `detail_badge_rule: Option<String>`, `detail_content_rule: Option<String>`, `reply_list_rule: Option<String>`, `reply_id_rule: Option<String>`, `reply_avatar_rule: Option<String>`, `reply_name_rule: Option<String>`, `reply_badge_rule: Option<String>`, `reply_content_rule: Option<String>`。

- `bookshelf_list() -> Vec<BookDto>`；`bookshelf_get(book_url) -> Option<BookDto>`；
  `bookshelf_add(book: BookDto) -> BookDto`；`bookshelf_update(book: BookDto) -> ()`。
- `source_list/source_list_enabled -> Vec<BookSourceDto>`；`source_add(source: BookSourceDto) -> BookSourceDto`；
  `source_update(source: BookSourceDto) -> ()`。沿用写库后刷新同一限速器的顺序。
- `reader_get_chapters(book_url) -> ChapterListDto { total:i32, chapters:Vec<ChapterDto> }`。
  网络刷新/平台动作响应仍有拦截协议，不在纯目录读取时混为一个无错误分支的列表。
- JSON 解析入口为 Server/导入保留，并转发到同一实体实现；FRB 路径直接转换，不借 JSON 中转。
  书籍更新继续调用既有 source 字段防回退合并，DTO 本身不增加业务默认值或静默修复。
- Dart data 层只映射现有领域字段，不以生成类型替换 UI 模型；Rust 内部完整实体字段保留可表达能力。

编写者：Codex + Bridge｜2026-10-17

### FFI-TRANSPORT-20261017 / 后续第1批网络与书源查询冻结

- httpGet/httpPost 返回 HttpTextResponseDto(status/body/url)；httpGetBytes 接收可空字符串请求头映射，
  返回 HttpBytesResponseDto(status/bytes/url)，移除 bodyBase64；共用客户端、重定向、错误与超时行为不变。
- webbookSearch/Info/Chapters/Content 接收 BookSourceDto，分别返回 WebSearchResultDto 列表、
  WebBookInfoDto、WebChapterDto 列表和 TextResponseDto；正文接收 WebChapterDto。
  这些是抓取结果字段，不把部分详情伪装成已持久化的完整 BookDto；原平台回传语义保持。
- exploreParseUrl 接收可空 BookSourceDto，返回含全部控件及 Flex 样式的 ExploreCategoryDto；
  exploreFetchBooks 接收实体并返回 WebSearchResultDto 列表。动态脚本的配置文档仍在原解析边界读取。
- 段评请求为 ReviewRequestDto(chapterUrl/paraIndex/paraData/detailUrl/replyUrl/reviewId/book/chapter)，
  book/chapter 为可空实体，规则变量保持原字符串语义；响应为 ReviewSummaryDto(counts/keys) 与
  ReviewPageDto(items/nextPageUrl/hasReplyUrl)，条目递归保留全部图片、音频、计数与回复字段。
  现有段评服务和发现控件提供的书源配置文档保留 JSON 输入解析一次，不由 Dart 复制 Rust 导入规则。
- 共享核心的 HTTP/Server JSON 适配只在边界序列化，正式 FFI 使用实体执行链；不改数据库、UI和JS协议。

编写者：Codex + Bridge｜2026-10-17

### FFI-TRANSPORT-20261017 / 后续第2批朗读媒体冻结

- HTTP TTS 列表/普通新增/更新采用十六字段 HttpTtsConfigDto；JSON 导入独立为
  httpTtsImport(document)→条数，保留数组 loginUi、源内 speakersJson/emotionsJson；
  2026-10-19 起按 §2.25 整批事务写入，任一条失败回滚配置与目录。
  导出继续生成原 JSON 文档，限流器刷新、并发归一、音色目录同步与原事务共用实现。
- ttsSpeak/cloudTtsSpeak 返回 TtsSpeakDto(audioPath/fromCache/contentType)，不传音频字节；
  TtsRequest 的取消、活动保护及文件租约归属不变。
- 云端元数据、音色描述与试听参数分别为 CloudTtsMetadataDto、CloudVoiceDescriptorDto、
  CloudSpeechInputDto/CloudVoiceOptionsDto；当批仅映射已有三种供应商，2026-10-20 按
  TTS-AZURE-20261019 追加 azure_speech、完整目录字段和引擎目录发现接口。
  明文 API Key 仍只作为调用参数，不进入元数据或持久化；凭据版本与音色归属检查不变。
- 音色目录和设备同步使用 ReadAloudVoiceDto/SystemVoiceEntryDto；traitsJson 与
  emotionCatalogJson 为原有配置文档，不在传输层重新解释。
- TTS 缓存上下文/列表/清理使用 TtsCacheContextDto/TtsCacheEntryDto/TtsCacheClearResultDto，
  时间、大小、索引的有符号/无符号范围与原协议相同；活动请求与播放租约保护保留。
- 音频章节媒体采用 AudioChapterMediaDto；预下载返回 AudioCacheDownloadDto，状态为
  installed/already_cached 枚举。仍由 Rust 下载落盘，保留取消、失败清理和缓存命中规则。
- 页面、仓储领域接口、数据库、缓存文件和配置文档格式不改。无效整型范围与非有限浮点
  在直接编码前拒绝，不能用类型化掩盖原 JSON 路径会拒绝的值。

编写者：Codex + Bridge｜2026-10-17

### FFI-TRANSPORT-20261017 / 后续第3批任务与交互事件冻结

本批只替换内部传输和观察机制，不改变下载执行器、持久化格式、请求键或既有界面布局。

- `cache_download_start` 返回 u64 任务标识；progress/list 返回 `CacheDownloadTaskDto`/列表，字段为
  taskId:u64、bookUrl:String、status:CacheDownloadStatusDto、total/completed/failed:i32。
  状态穷举 running/completed/cancelled/failed/notFound；未知任务沿用 notFound，章节集合直接返回 Vec<i32>。
- 新增 `cache_download_stream(request:&StreamRequest,sink:StreamSink<Vec<CacheDownloadTaskDto>>)`：
  先订阅变化再读取初始快照，之后由实例下载服务的变更通知推送最新完整快照，允许合并快速中间进度，终态必可观察。
  无变化时不轮询；订阅在显式取消、宿主任务组关闭或 sink 失败时结束。取消观察不取消下载，下载取消仍调用原任务接口。
  Flutter下载服务增加watchTasks，缓存队列及离线缓存页用订阅替代2秒任务轮询；离开页面仅取消订阅。
- 队列元数据 `download_get_stats/list_by_book` 返回 DownloadStatsDto/Vec<DownloadTaskDto>，保持原公开字段；
  DownloadStatusDto穷举pending/downloading/completed/failed/paused，error仍为独立可空字段。
  该旧队列不是实际章节下载执行器，不新增伪执行流。
- 调试流 `DebugLogDto(state:i32,msg:String)`；验证码 `VerificationRequestDto` 保留原七字段；
  WebView `WebViewRequestDto` 保留原十四字段及DOM/JS/result/cookie文本，pending返回相同DTO列表。
  三条流均接收独立StreamRequest，由Dart订阅取消同步通知Rust；调试取消只终止原调试操作，
  验证码/WebView退订不提交或取消用户请求。WebView Cookie回流改为Map<String,String>，仍先合并落库后唤醒。
- 索引/状态映射由适配器完成，未知JSON状态等不再作为运行时协议；大小使用u64→BigInt，
  不把业务任务ID改成临时资源句柄。仍使用SSE，不宣称零拷贝。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 后续第4批稳定业务载荷冻结

本批以专用DTO贯通RSS源44字段、文章5字段、收藏10字段、已读4字段，搜索历史3字段、
替换规则既有字段、词典条目/规则、规则订阅15字段及检查/应用结果、应用日志3字段、
备份恢复统计6字段和备份文件摘要4字段。标量写入接口不因DTO而改变业务更新规则。

- RSS新增/更新改收RssSourceDto，返回RssSourceDto；原生实体写入和真正文档导入共用执行链。
  自定义Header、脚本、规则、样式字段保留字符串。Dart既有文档导入/导出仍解析或生成真实JSON。
  收藏starTime/pubDate按真实原生字段映射，避免原snake_case与UI别名不一致吞掉时间。
- 搜索联想、缓存章节URL、缓存索引直接传Vec<String>/Vec<i32>，配置快照与发现infoMap为Map<String,String>；
  书架排序、词典及规则订阅排序为类型化序列。书架实体规则/原子更新语义不变。
- 规则订阅仍接受未知subType字符串，由既有数据库映射决定；Flutter现有模型未暴露的js/showRule/sourceUrl
  保持普通保存时原先的空值行为，不以本次传输任务扩展编辑功能。检查/应用结果不经过JSON解码。
- 日志级别使用LogLevelDto穷举message/crash/http，导出仍是原格式化文本；日志列表保留时间、排序与环形缓冲。
- backup_create仍返回实际文件路径；backup_restore返回RestoreStatsDto；backup_list返回BackupFileDto列表。
  备份文件内容和旧版导入文档本身不改。旧版导入汇总、JS执行协议、登录协议、书籍导出选项及样式等
  真正文档不按“消除String”指标盲目替换。
- 专用DTO逐字段映射原生实体，不经serde_json中转；Dart在直传前保留i32范围校验。
  只删除经调用搜索确认无消费者的传输JSON适配器；REST/CLI/真实导入导出边界继续保留。

编写者：Codex｜2026-10-17

### BACKUP-RSS-BOOL-20261017 / RSS 备份完整性

备份文件仍为版本1，不改变FFI签名、数据库结构或恢复统计字段。RSS导出和恢复统一复用
RssSourceRepository完整44字段；布尔字段输出JSON布尔值，enabledCookieJar为空时显式写null，
避免反序列化缺省值覆盖空值。导出遇到行解析错误必须失败，不得静默生成缺记录的备份；
恢复遇到无效RSS条目沿用逐条跳过策略，但记录错误，不补历史整数布尔兼容层。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 自动任务稳定载荷冻结

AutoTaskRuleDto完整保留18字段：id/name/enable/cron/loginUrl/loginUi/loginCheckJs/comment/script/
header/jsLib/concurrentRate/enabledCookieJar/customOrder/lastRunAt/lastResult/lastError/lastLog。
CRUD、构建书籍任务、批量cron、书籍任务查找和导入准备的本地列表与返回值统一使用该DTO；
未命中为Option，ID列表为Vec<String>，创建仍返回原业务ID。不再跨边界传实体JSON。
纯计算仍调用原核心算法，完整实体专属的登录/Header等字段不得被核心10字段结构覆盖或丢弃。
TaskResultDto包含taskId/success/message/durationMs/details，时长u64直接传递并在Dart领域映射为int。
脚本、任务执行协议与用户导入文档保持原JSON字符串；只在真实文档边界解析，导入合并保留本地排序/
运行记录与重复ID后者覆盖策略。接口不改数据库、任务调度、QuickJS执行或版本；继续SSE。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 文件与服务稳定载荷冻结

本地格式检测返回format/path DTO；元数据返回title/author/description/format，不额外传送旧接口
未暴露的封面。格式枚举保持现有集合，导入结果使用success/BookDto?/error?，不改变落库规则。
导出结果含success/data:Option<Vec<u8>>/fileName?/mimeType?/chapterCount?/error?；文件数据不再
经Base64，预览章节数独立为usize，不再塞进error文本。选项JSON仍保留，生成文件内容不变。
ZIP/RAR导入结果含success/extractedFiles/error，条目直接Vec<String>；编码检测和转换结果
分别为encoding/hasBom/confidence和success/outputPath/error。错误不转换为空成功。
WebDAV目录返回name/path/size:u64/lastModified?/etag?/isDir DTO列表；配置与同步文档保持JSON，
领域旧Map暂由适配层逐字段构造，不经字符串解析。服务状态直接返回running/port:u16，
启动/停止状态机与消息不变。继续SSE，不声称字节零拷贝；不升级应用、数据库或依赖。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 书源工具与动作固定载荷冻结

封面搜索返回CoverCandidateDto(url,width,height)列表，封面规则搜索返回Vec<String>，
配置读写传CoverRuleDto(enable,searchUrl,coverRule,enabledCookieJar:Option<bool>)；
表达式原文、默认资源、主配置覆盖与Cookie空值语义不变，数据库rule仍为原JSON文档。
JS书源提取返回BookSourceDto，Dart继续将原脚本写入mainJs；语法检查返回
SourceSyntaxDto(valid,message,line:Option<u32>)，不强制执行脚本或更改行号含义。
购买返回ChapterPurchaseDto(kind:ChapterPurchaseKindDto,value)，kind穷举url/success/none，
原JS执行、成功清缓存和调用方刷新规则不变。按钮回调返回SourceCallbackDto(invoked,jsTrue,raw,
actionsJson)，动态动作数组单独保留JSON；顺序、未知字段及平台回放一次后才返回的语义不变。
完整稳定结果不得先JSON序列化再反解；固定结构与真正动态动作文档分开，不扩展用户功能。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 闲置导出清理冻结

全仓调用核对后，移除txt_search/txt_search_regex/txt_search_in_chapter/txt_search_count及
audio_resolve_play_book五个FRB导出和对应生成绑定；移除仅为这些入口存在的FFI适配模块/函数。
这些接口没有Flutter手写消费者，也未被脚本、CI或Server调用，不新增替代接口或界面接线。
legado-book::txt_search及legado-core::audio的通用算法和行为测试继续保留；实际阅读器搜索、
音频章节取址/进度/readConfig合并等现有入口不变。历史接口表仅作追溯，以本冻结为准。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 发现脚本实体收尾

explore_eval_action和explore_eval_ui_js的source入参统一为BookSourceDto，直接转换完整BookSource；
ExploreService对应两方法接收BookSource，发现控件及经典登录复用入口不再编码书源JSON。
infoMap身份仍由sourceUrl关联，不改变分类布局、平台动作顺序、刷新发现、标题空值或异常语义。
脚本文本、经典登录表单result和动态动作数组继续保留真实文档；Rust原JSON测试/文档包装
仅在其边界解析，FRB实体调用不得经字符串反解；结果模型沿用ExploreActionDto/原标题字符串。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / 动态协议边界冻结

source_is_login_ui_v2/source_login_ui_v2/source_login_action_v2的source入参改为既有BookSourceDto，
直接转换完整BookSource，移除实体的Dart编码/Rust反解。执行仍使用同一源码快照，
state_json/user_input_json及动态UI/命令结果保留原JSON协议：stateJson字符串/对象、formJson、
未知字段、null/空结果和平台拦截先于解码的顺序不变；login命令仍先写入同一登录缓存再返回。
Rust内部三项执行入口直接接收BookSource引用，旧JSON仅允许在真实测试fixture边界解析，
不保留生产环境双版本实体入口。
JS通用返回、登录V1/凭据文档、替换规则预览、WebDAV书架/书源文件与配置保持各自协议。
固定诊断/同步外壳与动态文档不等同；本批不将其余尚未迁移接口声称为已类型化。

编写者：Codex｜2026-10-17

### FFI-TRANSPORT-20261017 / P3 流冻结

搜索、书源校验和换源的已有 StreamSink<String> 分别改为 StreamSink<SearchSourceBatchDto>、
StreamSink<CheckProgressDto>、StreamSink<ChangeSourceBatchDto>；结果字段逐项对应既有批次，
嵌套 SearchBookDto、SourceMatchDto、CheckResultDto、CaptchaInfoDto 和 RedirectInfoDto 直接传输。
搜索保留按源结果批次/hasMore/已读信息，换源仍为累积排序快照；单源错误和终批语义不变。
三个流显式接受独立 opaque StreamRequest；Dart 取消订阅先取消该句柄，再解除订阅并 dispose。
句柄取消能打断没有产出事件的等待；发送失败依旧取消原执行会话。保留旧业务取消/暂停接口，
不使用它们处理旧订阅取消，避免误杀新任务。底层已有 TaskGroup/阻塞凭据继续跟踪真实寿命。
Rust 内部仍需 JSON 的测试/HTTP 适配器仅在边界序列化，与 FRB 类型化驱动共用唯一实现。
不承诺 StreamSink 自动背压或强杀同步 JS，不将所有短查询改为流。

编写者：Codex + Bridge｜2026-10-17

### FFI-TRANSPORT-20261017 / P4 排版会话冻结

`reader_layout_begin(config: LayoutConfigDto) -> LayoutSession`；移除基于 session_id 的
reader_layout_push/finish/cancel 导出；改为 opaque LayoutSession 的 push(blocks:Vec<LayoutBlockDto>)、
finish() 与同步 cancel()。push/finish 返回 LayoutReplyDto，不持有全局字符串会话表。
配置、段落、行内项、块和样式以字段/枚举快照表达；上游既有可扩展装饰元数据使用受限的
LayoutValue 类型树，不编码 JSON 字符串。低频装饰仍映射现有领域 Map，不重写排版算法。
输出保留共享样式与字形列：geometry/positions 改为 Vec<u8>，不退回逐字对象或 base64。
会话上限仍为8、单批32块/250000行内项；以16MiB估算内存预算替代JSON字符预算。
finish/失败释放会话容量；取消幂等并及时设置独立标志，竞争中的计算完成前不提前释放容量。
Dart finally显式取消/释放，GC仅兜底；已关闭对象不能push/finish。原阅读位置、分页与布局规则不变。

编写者：Codex + Bridge｜2026-10-17

#### P3/P4 数值与诊断补充

- 桥接沿用底层 f32/f64 类型；f32 传到 Dart double 时会呈现二进制精度（如 1.7 约为
  1.7000000477），不承诺十进制字符串格式的逐位一致，测试按 f32 误差验证。
- 排版诊断的 callMicroseconds 包含 Dart DTO 字段映射、FRB 往返和返回列适配；Rust 计时单列保留。
  已移除 JSON 编解码，旧 encoding/decoding 计时为零；不能将新旧 call 指标当作同一阶段直接比较。

### FFI-TRANSPORT-20261017 / 剩余主链路冻结

本轮继续在同一worktree完成既定现代化主链路，上一轮的P1～P4局部完成不作为整阶段关闭。
- 搜索/精搜/非流式多源查询与三个流均接收 Vec<String> 源列表；校验配置为 SourceCheckConfigDto
  的七个可空字段（keyword/stepTimeoutMs/checkSearch/checkToc/checkContent/detectCaptcha/detectRedirect）。
  单源校验接收 BookSourceDto，返回 CheckResultDto；流配置默认和顺序保持。
- 换源选项为 SwitchSearchOptionsDto 的四个布尔字段（loadInfo/loadToc/loadWordCount/forceRefresh）；
  非流查询返回 SourceSwitchResponseDto，apply/applyPrefetch 返回 BookDto，复用原事务和取消。
- 普通搜索返回 Vec<SearchBookDto>（沿用原FFI输出的SearchBook字段）；多源查询返回 AnnotatedCandidateDto
  （原候选/阅读标识/评分全部字段）；精搜返回 SearchBookDto。Server/HTTP适配自行序列化，执行链不重复。
- readerRefreshToc 返回 ChapterListDto。正文网络入口返回 TextResponseDto：普通正文或明确的
  PlatformActionDto；正文 String 保持原文，不把任意以花括号开头的小说文本误判成动作。
  平台动作转换集中在 Rust 边界，Dart 直接分发已有动作处理器；需要WebView结果时保留当前回传语义。
  UI、数据库、导入导出与JS脚本内容不改。

编写者：Codex + Bridge｜2026-10-17

PlatformActionDto 固定十二类动作，与既有 supportedActions 对齐；参数字段为 url/html/js/title/mimeType/text/message/result/cookie/sourceRegex/overrideUrlRegex/sourceKey/tag 的可空字符串、isFloat/isRule/cacheFirst布尔值及归一后的delayTimeMs整数；未知动作保持普通文本。

本轮“剩余主链路冻结”替代此前P3流输入字符串及目录刷新平台拦截的描述。三个流的配置和源列表
现在均为类型化入参；refreshToc仅返回ChapterListDto，平台动作只在确实可返回动作的正文入口分派。
HTTP/Server所需JSON格式仍由其入口适配，FRB执行链不借JSON序列化返回实体。

单源校验领域接口同步收口为 checkSource(BookSource source, {String? configJson})，不再把已有实体
序列化后交给Dart重新解析。这避免复制Rust导入的宽松反序列化规则及缺键/null语义；用户书源JSON
仍由既有导入路径解析。Mock与所有调用方同步；配置JSON是现有设置文档格式，仅在数据适配器
解析一次后转换SourceCheckConfigDto。批量校验的源列表接口不改。

### FFI-TRANSPORT-20261017 / 阅读域补齐契约

本批冻结下列强类型接口；领域仓储和页面行为、数据库与导入导出不变，继续使用 SSE。

| 导出 | 入参或结果 |
| --- | --- |
| readRecordList | Vec<ReadRecordDto>：bookName/author/deviceId/readTime/lastRead；时间均为 i64 毫秒，不新增 startTime |
| readRecordSessionList | Vec<ReadRecordSessionDto>：id/deviceId/bookName/author/bookUrl/startTime/endTime/chapterIndex；时间为毫秒 |
| readRecordDailyList(year) | Vec<ReadRecordDailyDto>：date/seconds；日期升序，seconds 为 i64 整秒，年份与空结果语义不变 |
| bookGroupList | Vec<BookGroupDto>：groupId/groupName/cover/order/show/isPrivate；cover 可空，其余领域默认值保持原样 |
| highlightAdd | BookHighlightDto → i64；time=0 分配主键并避免同毫秒冲突，显式主键仍覆盖 |
| highlightListByBook / highlightListByChapter / highlightSearch / highlightListAll | Vec<BookHighlightDto>；原过滤、排序与错误语义保持 |
| highlightRuleSave | HighlightRuleDto → i64；id=0 新增，正数覆盖；Dart 未保存的非正 id 仍归一为 0 |
| highlightRuleList / highlightRuleFindEnabled | Vec<HighlightRuleDto>；原排序、范围与启用判定保持 |

BookHighlightDto 十三个字段为 time/bookUrl/chapterUrl/bookName/bookAuthor/chapterIndex/chapterPos/
chapterPosEnd/layoutTitleLength/chapterName/bookText/style/note；位置仍为既有 UTF-16 坐标，
layoutTitleLength=-1 表示未知，时间为 i64。HighlightRuleDto 十个字段为 id/name/pattern/isRegex/
scope/isEnabled/style/sortOrder/timeoutMillisecond/applyToTitle；scope 可空，超时为 i64 毫秒。
style 为既有样式文档字符串，保留内容，不在传输层重新解释。

高亮保存直接把 DTO 转为现有实体；已确认没有生产调用方的旧 JSON 保存入口移除，测试直接调用实体入口。
阅读记录与分组复用现有同名 DTO，序列化字段保持给 Server 使用；不为迁移补充旧接口从未返回的字段。
Dart 每日统计仍向原领域接口提供 date/seconds Map，通过字段映射构造，不做 JSON 往返。
全部列表不吞掉底层错误；Dart 保存高亮/规则的无效返回主键校验保留。
高亮的四个 i32 位置/章节字段和规则 sortOrder 在 Dart 编码前检查有符号范围；
超出范围以 RangeError 拒绝，不让直接编码截断。有效负值（如未知标题长度 -1）不改。

编写者：Codex + Bridge｜2026-10-17
