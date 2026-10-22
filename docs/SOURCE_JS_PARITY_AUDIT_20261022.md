# 书源 JS 与上游行为对齐审计

## 1. 结论与审计口径

**当前不能把“书源 JS 已接入 QuickJS、注册了 Java API”视为与上游完整对齐。** 声明式规则路径已有较多可用基础；单文件 `mainJs` 路径则存在参数、上下文、调用作用域、可选函数及返回值处理方面的实际差异。并发 API 和 jsLib 加载还存在跨路径语义分叉，应先修这些基础契约，再扩展批量正文等能力。

本轮是代码审计和定向行为取证，不修改业务实现。任务状态只维护在 [Active 计划](REFACTORING_ACTIVE_PLAN.md)；本文保存固定基线下的证据与建议，不另作进度台账。

第1–8节对应下表审计基线；后续测试复用与第一批修复证据分别追加在第9、10节，不能把历史复现结果当作修复后现状。

| 对象 | 本地路径 | 固定提交 |
| --- | --- | --- |
| OpenLegado | 仓库根目录，`dev` | `57d9c4fa2104cab998e36d33d4b7ed3c5fd989a4` |
| Android 原版 | `build/upstream/legado` | `363540972195d5d4dd9d4008196767a73a814b36` |
| HapeLee 参考版 | `build/upstream/legado-with-MD3` | `c4182eb9bcdd2e52eb6bb44d14c37856e592a99a` |

这些是本地快照，不声明为远端最新版本。本地 HapeLee 快照未包含 `BookSource.mainJs` 或 `model/jsSource/`；原版快照已包含完整单文件 JS 书源路径。因此，本文的 `mainJs` 对照以原版为依据，声明式规则与公共宿主能力同时检查参考版。不能把原版新能力直接说成两个上游共同具备。

证据分级：

- **运行确认**：在实际 Rust QuickJS 中运行场景，核实当前输出；上游期望来自固定 Kotlin 源码。本轮未运行上游 Gradle 测试，不称为双端实测。
- **静态确认**：追踪生产调用链与实现，指出明确差异；不推定所有真实书源都会触发。
- **未验证**：真实站点、设备平台交互、完整 API 重载覆盖和性能，不以注册数量或注释替代验收。

## 2. 当前调用链与能力概览

```text
书源原文 → core 统一 JSON 解析 → DB / FFI / 编辑与导入
                                    ↓
                            engine / fetcher 分派
                     ┌──────────────┴──────────────┐
                声明式规则                      mainJs 书源
          AnalyzeUrl / AnalyzeRule          build_js_orchestrator
             source_setup                    JsSourceEngine
            QuickJsExecutor              JsSourceBookOrchestrator
                     └──────────────┬──────────────┘
                            宿主 API / 请求 / 状态
                                    ↓
                            结果转换与业务模型
```

两条 JS 路径并没有完全复用同一套上下文装配和 jsLib 加载机制。最近完成的书源 JSON 统一解析解决了“导入时如何解释字段”，并未自动解决“运行脚本时传什么、怎样执行、怎样接收返回值”。

| 范围 | 当前判断 | 本轮证据边界 |
| --- | --- | --- |
| JSON 字段归一化、批量正文规则字段保留 | 已有统一解析入口；批量字段保留不等于批量执行 | 沿用既有解析交付记录，不重复运行其测试 |
| 声明式 `@js:`、动态请求与响应脚本 | 已有实际执行路径 | 两项网络/绑定恢复定向回归通过 |
| 声明式 source/sourceApi、Cookie、cache 装配 | 已有实现 | `source_setup.rs` 静态核查；不推广为所有方法完全等价 |
| mainJs 搜索、详情、目录、正文分派 | 已有入口，执行契约部分不符 | 参数、上下文、可选函数等运行确认 |
| mainJs 配置检查 | 已检查基础必需函数、登录和段评摘要/详情配对 | 新增批量正文/回复函数的配置与执行未完整覆盖 |
| jsLib 原始脚本 | 正常及失败传播路径已有覆盖 | 7 项既有定向回归通过 |
| jsLib URL 映射 | 声明式有加载器，mainJs 未走相同加载器 | 主路径差异、库顺序错误运行确认 |
| 并发宿主 API | 方法存在，回调和隔离语义不符 | 原版调用签名失败、跨源计数共享运行确认 |
| Jsoup、响应对象、加密、Java 类兼容层 | 已有相应实现，不是完整 JVM | 本轮只复验响应对象相关定向用例，其他未全量核验 |
| 平台动作与 WebView | 通过宿主桥请求，依赖订阅和真实平台执行 | 未做设备交互验收 |

主要生产入口：[web_book.rs](../rust/legado-fetcher/src/web_book.rs)（`build_js_orchestrator`，4086 行）、[source_setup.rs](../rust/legado-fetcher/src/source_setup.rs)、[executor.rs](../rust/legado-js/src/executor.rs)、[source_engine.rs](../rust/legado-js/src/source_engine.rs)。

## 3. 已确认的执行契约差异

### JS-01 / P1：mainJs 的对象参数和书源上下文未正确装配

**运行确认。** 原版 `JsSourceEngine.buildScope` 每次绑定 `java/source/sourceApi/baseUrl/cookie/cache`，再注入调用参数。`JsSourceBook` 将书籍、章节对象交给脚本，脚本可以读取 `book.name`、`chapter.title`。

本项目 `JsSourceBookOrchestrator` 先 `serde_json::to_string(book/chapter)`，再以 `JsValue::String` 传入。`JsSourceEngine` 缓存构造未接入声明式书源的完整 setup，调用只补充 `baseUrl` 和参数。

实际运行：

```js
// 在 getContent(chapter, book, ...) 内检查
[typeof chapter, typeof book, chapter.title, book.name]
// 当前： ["string", "string", null, null]

[typeof source, typeof sourceApi, typeof cookie]
// 当前： ["undefined", "undefined", "undefined"]
```

因此，按原版方式写的主脚本可能取不到书名、章节标题、登录信息或书源方法。这不是所有书源的全局问题：声明式路径已有这些全局对象。

依据：本项目 [js_source_book.rs](../rust/legado-js/src/js_source/js_source_book.rs) 的 `get_book_info/get_chapter_list/get_content`（190、229、269 行附近），[source_engine.rs](../rust/legado-js/src/source_engine.rs) 的构造与 `call_function_inner`（151、304 行附近）；原版 [JsSourceEngine.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceEngine.kt)（104 行）和 [JsSourceBook.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceBook.kt)。

修复方向：在同一个主脚本执行边界装配真实 JS 对象和书源上下文；复用现有宿主资源，不在 Dart 再做一套转换，也不让每个业务方法自行拼字符串补救。

### JS-02 / P1：缓存完整 VM 改变了 mainJs 的普通调用作用域

**运行确认。** 原版缓存的是编译结果，每次 `buildScope` 仍建立调用作用域并执行主脚本。本项目 `main_js_loaded` 使已缓存 VM 不再重新执行主脚本，同资源下的新包装实例仍复用其顶层变量。

场景：`var calls=0; function probe(){return ++calls;}`，同一实例两次调用、同资源同配置新实例再调用，当前依次返回 **1、2、3**。原版所示普通顶层 `var` 会在每次主脚本求值时重新初始化。

影响包括计数器、临时 token、请求中间状态跨调用残留。这里不能扩大为“上游完全不共享任何 JS 状态”：原版也有共享原型与全局状态机制，需分别处理。

依据：[source_engine.rs](../rust/legado-js/src/source_engine.rs)（331、362 行及已有“仅执行一次”用例）、[engine_cache.rs](../rust/legado-js/src/engine_cache.rs)，原版 `JsSourceEngine.kt`（104–141 行）。

修复方向：分清编译缓存、可复用宿主资源、书源共享状态、单次调用状态。保留现有 `JsResources` 所有权及取消边界；不能简单删除缓存或恢复进程全局变量。现有 [API 契约](API_CONTRACT.md) 已描述资源内 VM 缓存，实施前需明确并更新调用作用域语义。

### JS-03 / P1：返回值被过早转成字符串，空值和异常混在一起

**运行确认。** 原版字符串原样返回，只有真正 `null/undefined` 才为空；对象序列化异常明确抛出。

| JS 返回 | 当前结果 | 原版边界语义 |
| --- | --- | --- |
| `'  保留空白  '` | `Some("保留空白")` | 保留字符串空白 |
| 字符串 `'null'` / `'undefined'` | `None` | 保留字符串 |
| 循环引用对象 | `Ok(None)` | 序列化错误上抛 |

根因有两层：QuickJS 对象 `json_stringify` 失败被转换成字符串 `"null"`；随后 `normalize_result` 对字符串 trim 并把几个字面量视为空。业务层因此可能把“解析失败”误当成“源返回空内容”。最终正文是否另有 trim 规则，应与引擎层字符串契约分开。

依据：[engine.rs](../rust/legado-js/src/engine.rs)（`js_value_from_rquickjs` 及 `result_to_string`，243、584 行）、[source_engine.rs](../rust/legado-js/src/source_engine.rs)（427 行）；原版 `JsSourceEngine.kt`（151 行及 `stringifyScriptable`）。

修复方向：保留返回值类型直到边界归一化，区分空值、字符串和错误；不靠字符串内容猜类型。

### JS-04 / P1：可选函数缺失识别依赖错误文案，实际无法回退

**运行确认。** 原版先判断目标是否为函数，不存在则返回 `exists=false`，函数内部错误照常上抛。本项目先调用，再只识别包含中文“缺少函数”的错误。

真实 QuickJS 对缺失函数返回 `optionalAbsent is not defined`，当前直接报错。`getBookInfo` 等可选函数因此可能无法走沿用既有字段的回退路径。

依据：[source_engine.rs](../rust/legado-js/src/source_engine.rs)（388 行），原版 `JsSourceEngine.kt`（83 行）。

修复方向：在 JS 运行时准确检查目标是否可调用；不得通过吞掉所有 `ReferenceError` 修复，否则会隐藏函数内部的真实错误。

### JS-05 / P1：详情结果按完整新对象解析，缺少上游的字段合并语义

**运行确认主要缺陷，其他差异静态确认。** 原版允许 `getBookInfo` 只补充一部分字段，并合并到传入的已有书籍。本项目中间模型 `JsBookInfo.name` 为必填；返回 `{intro:'只补充简介'}` 即报 `missing field name`，即使传入书籍已有名称且不允许重命名。

此外，生产 fetcher 的详情路径以 URL、来源新建 `Book`，并未传入完整搜索结果；中间结果未透出 `variable/type`，后续映射也明确采用缺省/来源兜底。这会限制“搜索已有数据，详情只补充”的能力。

依据：[js_source_marshaller.rs](../rust/legado-js/src/js_source/js_source_marshaller.rs)（52 行）、[js_source_book.rs](../rust/legado-js/src/js_source/js_source_book.rs)（184 行）、[web_book.rs](../rust/legado-fetcher/src/web_book.rs)（4217 行附近）；原版 [JsSourceMarshaller.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceMarshaller.kt) 的 `mergeBookInfo`（62 行）。

修复方向：以既有书籍为基础，按返回字段是否存在、是否允许重命名等规则合并；不要要求脚本回传完整模型。涉及 DTO 或公共边界扩展时先冻结契约。

## 4. 宿主 API 与规则加载差异

### JS-06 / P1：singleFlight/lock 未实现原版回调协议，计数键未按源隔离

**运行确认。** 原版签名是 `singleFlight(name, action, timeoutMs)` 和 `lock(name, action, timeoutMs)`，含缺省超时重载；会执行函数，并以 `sourceUrl@name` 区分书源。

本项目绑定为 `singleFlight(key, waitMs, fJs)`、`lock(key, waitMs)`。内部 `single_flight` 只返回 `[flight:...]` 标识，不执行 JS 函数；`lock` 返回布尔值，没有原版回调执行语义。

以原版三参数方式分别调用，两者都因第二参数是函数而发生类型转换错误，回调执行次数为 **0**。两个不同 source URL、共用一个 `JsResources` 时，`java.tick('same-name')` 返回 **1、2**，未像原版按源独立计数。

依据：[quickjs_impl.rs](../rust/legado-js/src/host_api/quickjs_impl.rs)（3760 行）、[concurrency_api.rs](../rust/legado-js/src/host_api/concurrency_api.rs)（43 行）；原版 [JsExtensions.kt](../build/upstream/legado/app/src/main/java/io/legado/app/help/JsExtensions.kt)（1305–1355 行）。

修复方向：在真实 JS 函数回调边界实现重载、返回/异常、超时和释放；资源仍归当前引擎所有，在资源内再区分 source key。不能把“不同引擎已隔离”当成“同引擎各书源已隔离”。

### JS-07 / P1：jsLib 主路径分叉，URL 映射执行顺序错误

**主路径及顺序运行确认；失败策略静态确认。**

1. 声明式执行器识别 URL 映射后进入专用加载器；mainJs 缓存初始化直接 eval `jsLib` 原文。同样的 `{"library":"https://…/library.js"}` 在 mainJs 下成为 JS 语法错误，并未拉取库。
2. 加载器注释称保留插入序，实际当前 `serde_json::Value` 对象迭代产生键排序。依赖先后顺序被改变。
3. URL 映射下载失败时，本项目记录台账并跳过，原版抛出失败；本项目还把映射中的非 URL 值作为内联 JS 执行，原版当前循环只执行绝对 URL 项。

顺序探针中，输入先 `zFirst → var dependency=42`，后 `aSecond → var derived=dependency+1`；实际先执行 `aSecond`，结果 `derived=NaN`（JSON 中显示 null），而不是 43。证明即使未报错，也可能得到错误计算值。

依据：[executor.rs](../rust/legado-js/src/executor.rs)、[engine_cache.rs](../rust/legado-js/src/engine_cache.rs)、[jslib_loader.rs](../rust/legado-js/src/host_api/jslib_loader.rs)（50、121 行）；原版 [SharedJsScope.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/SharedJsScope.kt)（231 行）。

修复方向：两条主路径共用加载规则，显式保留映射输入顺序。下载失败“记录后继续”在现有代码中被注明为有意差异，应先按项目对齐规则提交裁决，再变更；错误顺序与错误执行入口则已有直接缺陷依据。

### JS-08 / P2：getThemeMode 的返回协议与两侧上游不同

**运行确认。** 原版和当前 HapeLee 的 `getThemeMode()` 返回设置值 `"0"/"1"/"2"`。本项目将注入值转换成 `"auto"/"light"/"dark"`，已有测试也固定了此映射。

按 `java.getThemeMode() === '2'` 分支的原版脚本在当前实现不会命中暗色条件。此项是本项目已有的可见协议差异，不能仅因原测试通过而认为对齐；本轮只记录，不擅自改变既有行为。

依据：[config_api.rs](../rust/legado-js/src/host_api/config_api.rs)（74–85 行），原版 `JsExtensions.kt`（1372 行），参考版 [JsExtensions.kt](../build/upstream/legado-with-MD3/app/src/main/java/io/legado/app/help/JsExtensions.kt)（1203 行）。

## 5. 配置入口及原版新增能力

### JS-09 / P2：mainJs config 没有完全收敛到统一解析入口

**运行确认。** [js_source_config.rs](../rust/legado-js/src/js_source/js_source_config.rs)（182 行）仍直接 `serde_json::from_value::<BookSource>`，未调用统一 `parse_source_value`，且把字段错误替换为泛化的“config 配置对象字段类型不符”。

例如 `config.respondTime=null` 在该路径被拒绝，而本项目已冻结的 JSON 导入/解析契约明确整数 null 采用字段缺省值。这里比较的是本项目两个入口的一致性，不把此例误称为已运行 Kotlin 的结果。

修复方向：配置提取保留对 JS 函数及特有属性的检查，但普通书源字段解释复用 core 入口，保留字段路径；不要再创建一套容错转换。

### JS-10 / 能力缺口：批量正文与段评回复未形成上游完整执行链

**配置运行确认，执行链静态确认。** 原版 `JsSourceConfig` 校验 `maxBatchSize/getContentBatch` 配对以及 `getReviewReplies` 的函数类型和摘要/详情配对。当前探针中，下列输入都被接受：

- 有 `config.maxBatchSize=4`，没有 `getContentBatch`；
- 有 `getContentBatch`，没有 `config.maxBatchSize`；
- 仅有 `getReviewReplies`，没有段评摘要/详情函数。

本项目配置探测未包含这两个函数；并且没有原版 `getContentBatch → java.cacheContent` 的完整执行与回存协议。最近补齐的声明式 `contentBatch/maxBatchSize` 只是字段解析与保存，不能算成批量能力已落地，也不是本次发现的退化。

段评回复方面，当前 `ReviewService::js_review_get_replies` 仍调用 `orchestrator.get_review_detail`，没有按原版独立 `getReviewReplies` 协议传递回复上下文。

依据：[js_source_config.rs](../rust/legado-js/src/js_source/js_source_config.rs)（110 行）、[review_service/js.rs](../rust/legado-engine/src/review_service/js.rs)（38–58 行）；原版 [JsSourceConfig.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceConfig.kt)（154–217 行）、[JsSourceBook.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceBook.kt)（146 行）、[JsSourceReview.kt](../build/upstream/legado/app/src/main/java/io/legado/app/model/jsSource/JsSourceReview.kt)（102 行）。

修复方向：单独定义执行契约与授权范围，不以添加函数名检查冒充功能完成。两个上游快照能力不同，应先明确追齐哪个版本的产品范围。

### JS-11 / P2：卷标题占位正文返回 tag，与原版空正文不符

**后续复用上游用例时运行确认。** 原版 `JsSourceBookTest` 的 `volume placeholder skips js content and ignores its tag` 使用 `isVolume=true`、`url="Volume 1#0"`、`title="Volume 1"`、非空 tag，并让 `getContent` 主动抛错来验证不会执行脚本；预期正文为空。

相同场景在当前 `JsSourceBookOrchestrator::get_content` 返回 tag `"2026-08-10"`。虽然同样跳过脚本，但可能把占位章节的附带数据当正文显示。依据是 [js_source_book.rs](../rust/legado-js/src/js_source/js_source_book.rs) 的卷章早退与原版 `JsSourceBook.kt::getContentAwait`。本轮不修改业务逻辑，保留上游预期为明确标记的待修用例。

## 6. 已有基础与平台边界

以下内容应保留，不能因上述问题推导出“全部宿主 API 都是假实现”或需要更换 JS 引擎：

- 声明式上下文已经有完整 source、sourceApi、Cookie、cache 装配，以及书籍变量、登录信息和 Header 处理入口；本轮问题是 mainJs 没有采用相同装配路径。
- `JsResources`、流程变量及执行租约已经区分宿主/流程资源归属。修复应沿用隔离和取消机制，不退回全局单例。
- 响应对象、动态规则及跨 await 的绑定恢复有实际行为回归，本轮选中的两项通过；jsLib 原始脚本失败传播的 7 项回归也通过。
- Java/Packages 是 QuickJS 上的兼容层，不是 JVM。未知类已有错误与能力台账机制，不能把有限白名单等同于 Rhino 全部 Java 类可用。
- RAR 当前明确报“不支持”；文件接口受 `allow_file_access` 控制。此类限制应单独列为平台/安全边界，不能为对齐而盲目放开。
- WebView 等操作走平台桥，是否有活动订阅与实际 Flutter 宿主决定执行方式。无设备验证时，不能以生成动作载荷证明网页交互完整可用。
- `SandboxConfig` 中有些配置是声明/提示而非完整强制闸门（如网络许可与栈深限制）；本轮未验证敌对脚本隔离，不能把它称为安全沙箱已完整验收。

参考实现：[host_api/quickjs_impl.rs](../rust/legado-js/src/host_api/quickjs_impl.rs)、[host_api/platform.rs](../rust/legado-js/src/host_api/platform.rs)、[sandbox.rs](../rust/legado-js/src/sandbox.rs)、[archive_utils.rs](../rust/legado-js/src/host_api/archive_utils.rs)。

## 7. 建议后续批次

以下是实施建议，不表示本轮已获修复授权或已经实施。

| 顺序 | 范围 | 交付目标 |
| --- | --- | --- |
| A：执行契约正确性 | JS-01～05 | 正确对象参数与书源上下文、单次调用状态、可选函数、类型化返回/异常、详情增量合并；不夹带新功能 |
| B：公共宿主语义 | JS-06～09 | 真实并发回调与源隔离、统一 jsLib 加载及输入顺序、统一 config 字段解释；先裁决已有失败降级与主题模式协议差异 |
| C：新增能力 | JS-10 | 经授权后实现批量正文回存和独立段评回复；明确原版与参考版版本差异，不仅补字段 |

模块边界建议：core 保持唯一书源字段解释；JS 层负责运行环境、值传递、调用及异常；fetcher/engine 负责对象合并、请求与业务提交；Flutter 只呈现结果和平台交互。问题集中在这些边界的重复装配，不需要先把引擎换成 Rhino，或扩大为全仓 FFI 重构。

测试沿用用户要求，采用少量完整行为场景：

1. 一个完整主脚本贯通搜索→详情补充→目录→正文，同时验证真实对象和 source API；不逐字段重复测试。
2. 一个调用生命周期场景验证重复调用、不同源与取消后重用，区分共享库状态与单次调用状态。
3. 返回值/异常场景借鉴原版 `JsSourceEngineTest` 的字符串、对象及自定义 toJSON、可选函数行为，覆盖已确认错误，不复制纯源码检索用例。
4. 一个依赖顺序明确的 jsLib 场景覆盖 URL 加载、缓存和失败；并发场景验证函数实际执行、共享结果、异常释放与源隔离。
5. 必要调用方只验证编排和资源归属，不在 DTO、DB、FFI、Dart 每层重复同一组字段断言；新增 native 往返仅在边界本身有变更时安排。

上游行为用例见 [JsSourceEngineTest.kt](../build/upstream/legado/app/src/test/java/io/legado/app/model/jsSource/JsSourceEngineTest.kt) 和 [JsSourceBookTest.kt](../build/upstream/legado/app/src/test/java/io/legado/app/model/jsSource/JsSourceBookTest.kt)。不能因为上游目录也包含源码字符串测试，就复制本项目明确禁止的形式主义测试。

## 8. 本轮验证证据与限制

在 `rust/` 执行：

```powershell
cargo test --locked -p legado-js --features quickjs --test source_js_parity_audit_probe -- --nocapture
cargo test --locked -p legado-js --features quickjs --test jslib_failure_visible
cargo test --locked -p legado-js --features quickjs --test network_parity response_bridge_setup_delegation_preserves_headers_bodies_and_timeouts -- --exact
cargo test --locked -p legado-js --features quickjs --test network_parity batch_dynamic_rules_and_response_scripts_restore_bindings_between_awaits -- --exact
```

| 验证 | 结果 | 本地证据 |
| --- | --- | --- |
| 临时审计探针 | 4 个场景确认当前差异，退出 0；不是“与上游对齐通过” | `build/source-js-parity-audit-probe.log` |
| 宿主场景补充输出 | 增补顺序计算结果与主题模式，不增加独立场景计数 | `build/source-js-parity-audit-host.log` |
| 参数场景补充输出 | 增补部分详情结果，不增加独立场景计数 | `build/source-js-parity-audit-result.log` |
| jsLib 既有回归 | 7 项通过 | `build/source-js-parity-jslib-regression.log` |
| 响应对象/请求参数 | 1 项通过 | `build/source-js-parity-network-response.log` |
| 动态规则/绑定恢复 | 1 项通过 | `build/source-js-parity-network-batch.log` |

合计 **9 项既有定向回归通过，4 个诊断场景确认差异**。临时入口已移除，最终探针源码留在忽略目录 `build/source-js-parity-audit-probe.rs`；如需重跑须临时放回对应 tests 目录。证据文件只在本机保存，不作为提交中的永久测试套件。

本轮没有运行全量 Rust/Flutter 测试、上游 Gradle、真实 FFI 集成、模拟器、iOS、真实站点书源集合或性能测试；没有推送或触发 CI。未统计“兼容率”，没有证明未检查的宿主重载、Java 类、验证码和登录站点均可用。上述优先级基于可达生产调用链与行为证据，不能据此断定所有现有阅读故障都由同一原因造成。

## 9. 上游用例复用与本地去重对应

用户授权复用上游行为测试后，新增 [upstream_js_source.rs](../rust/legado-js/tests/upstream_js_source.rs)，记录上游固定提交、测试类及原用例名。JUnit/Rhino 接线改为实际 Rust QuickJS 与公开转换接口，不依赖本机上游目录，不读取生产源码进行断言。

| 上游行为 | Rust 适配 | 删除/保留边界 |
| --- | --- | --- |
| 完整引擎调用、const/for-in、自定义 toJSON/getter、正文与 undefined | `execution` 场景 | 移除旧的纯字符串归一化用例，特别是不再把 trim 当成对齐预期；取消和资源作用域回归仍保留 |
| 配置元信息与完整脚本、旧 source 配置、发现/登录配置、配对约束、时间戳写回 | `configuration` 场景 | 移除13个本地重叠用例；嵌套对象、字符串/注释、多声明和 compile-only 等独立词法回归保留 |
| 缺必填字段的搜索过滤、卷章与相对目录 URL | `marshalling` 场景 | 移除6个重叠的正常/过滤/URL及章节 camelCase 用例；在同一条行为链中消费实际类型化模型 |
| source/sourceApi、缺失可选函数、卷占位 tag | 3个明确关联JS-01、JS-04、JS-11的待修场景 | 保留原预期并标记ignore，单独执行确认失败；不反转断言让已知缺陷通过 |

最终按diff核对共删除 **20** 项本地测试（config 13、marshaller 6、engine 1），移植后组织为 **15** 个场景（12通过、3待修），并非删除整个JS测试套件。本项目特有的Cookie、资源/流程隔离、初始化失败恢复、类型化详情与网络专项覆盖继续保留。上游完整章节身份注入、详情增量合并等当前接口尚不能完整表达的场景没有冒充已迁移；原版测试还需随对应功能修复继续补齐，不将本批称为上游测试全量移植。

验证记录：

- `cargo test --locked -p legado-js --features quickjs --test upstream_js_source -- --nocapture`：12通过、3明确忽略；日志 `build/source-js-upstream-adapt.log`。
- 最终补齐空脚本与覆盖旧mainJs的场景输入后，仅复验`configuration::`的6项通过，日志`build/source-js-upstream-config-final.log`；与前次取并集，不重复计数。
- 同命令改为 `-- --ignored --nocapture`：3项均复现预期的实现缺口，退出101；日志 `build/source-js-upstream-known-gaps.log`，不记作通过。
- `--lib js_source::js_source_config::tests`、`--lib js_source::js_source_marshaller::tests`、`--lib source_engine::tests`：保留的9、11、7项分别通过；日志 `build/source-js-upstream-{config,marshaller,engine}.log`。
- 合计39项通过，3项已知未对齐场景单独复现失败。这里是测试重组后的结果，不与上一节历史审计的9项重复累加；没有更改业务实现、契约、依赖或应用版本，没有执行全量测试、设备验证或CI。

## 10. 第一批主脚本调用修复证据

实施前按`SOURCE-JS-CALL-20261022`冻结Rust内部协议，FFI签名、DTO、方法计数和数据库不变。本批对应JS-01的对象/上下文接线、JS-04的可选调用和JS-11的卷占位语义，不包含作用域、返回归一化、详情合并和公共宿主后续批次。

- 原fetcher的书源上下文生成函数及host提取函数迁至`legado-js::source_setup`；旧公开路径转发到同一实现。生产函数体与迁移前一致，没有复制另一份宿主API。已有声明式调用不改参数或生成内容。
- `JsSourceConfig::from_source`接收完整实体；初始化在mainJs前加载source/sourceApi、Cookie/cache及既有方法。完整setup参与既有缓存比较，书源配置变化重建条目；装配失败拒绝发布半初始化VM。
- Book/BookChapter先按既有camelCase模型序列化，再递归转为JsValue对象；不再把JSON文本传给脚本。nextChapterUrl缺省为null，嵌套对象/数组及标量类型在真实QuickJS场景验证。
- 可选函数在持有当前VM锁和流程绑定时检查是否可调用，缺失/非函数返回not_found；目标调用一次，内部错误上抛。段评摘要使用同一入口，不再吞掉任意引擎错误；详情/目录/正文与段评均验证真实对象参数。
- 卷占位跳过脚本并忽略tag；其他卷章允许空正文，普通章节空正文继续报错。恢复原3个ignore，并移植上游“blank content is allowed only for volume chapters”，当前上游文件16项常规测试通过。

| 定向范围 | 最终结果 | 日志（build/下） |
| --- | --- | --- |
| upstream_js_source | 16通过，无ignore | source-js-call-upstream.log；递归数组绑定补充后仅复验受影响1项，source-js-call-encoding.log，不叠加计数 |
| source_engine::tests | 7通过，含Cookie、流程变量和初始化重试 | source-js-call-engine.log |
| js_source_book::tests | 14通过 | source-js-call-book.log |
| source_setup::tests | 迁移的2项通过 | source-js-call-setup.log |
| main_js_context（fetcher真实编排） | 2通过；含配置失效、资源隔离、对象属性、可选摘要错误 | source-js-call-context-final.log |
| engine_cache::tests | 5通过；后补装配失败不替换有效VM，受影响1项复验通过 | source-js-call-cache.log、source-js-call-cache-final.log，不叠加计数 |
| jslib_failure_visible | 7通过，既有加载策略不变 | source-js-call-jslib.log |
| engine source_login_js | 6通过 | source-js-call-login.log |
| engine review_service单一JS资源隔离场景 | 1通过 | source-js-call-review.log |

合计60项定向用例通过。调用方段评夹具原来主动JSON.parse来适配错误的字符串参数，本批删除该补偿，原资源隔离断言保留。生产编排新夹具初次编译将Value和Vec误当类型化对象/Map，已修正测试断言并通过；不把夹具编译失败解释成业务缺陷。

`cargo clippy --locked -p legado-js -p legado-fetcher --features quickjs --lib -- -D warnings`通过，日志`source-js-call-clippy.log`；同两crate的`cargo check --no-default-features --lib`检查默认编译路径，日志`source-js-call-default-check.log`。改动文件rustfmt和diff检查通过。

当前版本保持2.0.439+440，只补用户可见更新日志；没有运行全量测试、应用/native产物重建、真实站点、设备或CI。未使用子代理，只做单代理复核，不宣称独立审查。mainJs完整VM缓存/调用作用域、字符串返回与序列化错误、详情字段合并、jsLib URL映射及并发API仍按前文后续建议处理，不以本批通过宣称完整对齐。

编写者：Codex + Rust / Bridge｜2026-10-22

## 11. 第二批调用作用域与类型化返回证据

基线`dev / f2e22f071`，先冻结`SOURCE-JS-SCOPE-20261022`内部契约。本批修复选定mainJs路径的JS-02/JS-03，不修改FFI、DTO、数据库、依赖或应用版本。对照原版`JsSourceEngine.buildScope`、`modules/rhino/ScriptBindings`及`JsEngineCapabilitiesTest.sharedLibraryFunctionUsesCallerBindingsAsDefaultThis`，不把重复求值次数当作行为验收。

### 最终实现

- mainJs每次在独立函数词法作用域执行，构造阶段只装配宿主与共享库。保留同一QuickJS Context/Runtime和jsLib词法环境，不重建整个VM，不清空Cookie/变量来制造隔离。普通var/let/const与函数声明按次初始化，显式globalThis/global及库状态保留在来源缓存层，普通变量与共享变量即使同名也不混用。
- 每次装配source/sourceApi、java、cache等及对象参数；预置属性作为调用参数，避免函数var提升破坏“先读取宿主source、再声明脚本source”。库函数调用期间借用当前绑定，正常返回、异常和取消都恢复父层属性描述，不把旧流程和任务能力留在库缓存。共享库const导出、函数身份和显式`.call(customThis)`一并验证。
- 真正null/undefined返回None；空串、空白以及字符串`"null"`/`"undefined"`原样保留。对象在有效调用环境内序列化，循环引用、getter/toJSON异常原样上抛，执行及序列化共用一次超时/取消预算。业务层原有正文空值校验保持，声明式通用字符串接口不借机改写。
- 递归对象绑定复验发现既有i64先转i32使时间戳1792486038190变为1484675758，已修为JS Number；不承诺超过JS安全整数范围的精度，不增加BigInt协议。
- 移除mainJs_loaded、只存源码的旧脚本缓存及3项机械计数测试，以真实重复调用、来源共享状态、当前Cookie和当前参数验证替代。现有泛用编译接口仍只是源码容器，不能声称有字节码缓存收益。

### 实现边界复核

初版独立Context方案暴露共享库const不可见，已由同一上下文内的独立词法环境替代；函数代理缓存方案在32次调用后仍累积对象，最终实现删除该缓存。共享状态视图使用普通对象访问器，不在全局原型链放置Proxy，避免未定义标识符变成undefined、吞掉ReferenceError。以上为实施过程中已纠正的问题，不作为最终实现仍需回避的限制。

保留一个实际回收用例：预热后记录QuickJS对象/函数数，重复32次带库函数和对象参数的调用，GC后两项计数与基线一致。它验证选定路径的临时对象回收，不代表测过进程RSS、耗时或所有逃逸对象。取消用例另外验证任务弱引用可释放，并确认下一次调用既不读旧参数，也不误清显式共享状态。

### 定向验证

在`rust/`运行现有Cargo入口，`--lib`按模块过滤，集成测试按测试文件或单一用例过滤：

| 范围 | 结果 | 日志（build/下） |
| --- | --- | --- |
| upstream_js_source | 20通过，无ignore；字符串类型、同名共享变量、库上下文、序列化错误/超时与原上游流程 | source-js-scope-upstream.log |
| 临时作用域回收 | 1通过，32次调用后对象/函数数恢复 | source-js-scope-lifetime.log |
| source_engine::tests | 4通过，当前Cookie/参数及流程能力 | source-js-scope-engine.log |
| js_source_book::tests | 14通过，Mock显式返回类型化结果，只验证业务编排 | source-js-scope-book.log |
| jslib_failure_visible | 7通过，不改变现有加载失败策略 | source-js-scope-jslib.log |
| fetcher main_js_context | 2通过，包含source覆盖与配置变化、正式对象调用 | source-js-scope-context.log |
| engine source_login_js / review_service | 6 / 4通过，登录与段评调用方 | source-js-scope-login.log、source-js-scope-review.log |
| 序列化取消 / 实际搜索取消 | 各1通过，覆盖取消后的任务释放及下一次调用 | source-js-scope-cancel.log、source-js-scope-cancel-search.log |

合计60个独立定向用例通过，不把实施中复跑次数重复计入。带QuickJS的`cargo clippy --locked -p legado-js -p legado-fetcher --features quickjs --lib -- -D warnings`及两crate无QuickJS的默认库编译通过，日志`source-js-scope-clippy.log`、`source-js-scope-default-check.log`；改动文件rustfmt/diff检查通过。

版本保持2.0.439+440，仅更新双日志；没有运行全量测试、真实站点、FFI/native打包、模拟器、iOS、性能测试或CI，也未推送。单代理复核，不宣称独立审查。旧MCP文本归一化入口按用户暂缓范围保留；详情字段增量合并、宿主并发与库加载策略仍待后续批次，本批不承诺完整复刻Rhino的动态eval/默认this语言扩展或所有书源兼容。

编写者：Codex + Rust / Bridge｜2026-10-22
