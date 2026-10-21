# 书源 JS 与上游行为对齐审计

## 1. 结论与审计口径

**当前不能把“书源 JS 已接入 QuickJS、注册了 Java API”视为与上游完整对齐。** 声明式规则路径已有较多可用基础；单文件 `mainJs` 路径则存在参数、上下文、调用作用域、可选函数及返回值处理方面的实际差异。并发 API 和 jsLib 加载还存在跨路径语义分叉，应先修这些基础契约，再扩展批量正文等能力。

本轮是代码审计和定向行为取证，不修改业务实现。任务状态只维护在 [Active 计划](REFACTORING_ACTIVE_PLAN.md)；本文保存固定基线下的证据与建议，不另作进度台账。

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

编写者：Codex + Rust / Bridge｜2026-10-22
