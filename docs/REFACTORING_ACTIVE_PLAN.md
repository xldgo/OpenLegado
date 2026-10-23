# 当前任务与待验收清单

更新日期：2026-10-24。整理基线：`dev / 5400d4d53`。

本文只保留下一步仍有动作的事项；实现完成、待设备验收、待核验和明确暂缓分别记录。
专题文档保存方法与证据，Git保存提交和已完成过程；不在本文追加命令流水、逐轮测试数字或合并日志。
未列入当前实现范围的候选不视为已授权开工，也不因缺少设备记录就重复实现。

## 一、当前基线

| 领域 | 已交付范围与证据入口 | 不能据此宣称 |
|---|---|---|
| Rust资源与FFI | EngineContext、领域服务边界、类型化传输及配套生成已完成约定批次；见[双轨规范](TWO_TRACK_DEV_SPEC.md)、[EngineContext证据](RUST_ENGINE_CONTEXT_PLAN_20261016.md)、[传输改造证据](FFI_TRANSPORT_MODERNIZATION_20261017.md) | 全部领域JSON已退役、所有平台已验收 |
| Flutter模块与入口 | Feature归属五步、页面拆分、路由迁移及四批编辑/导入入口整理已交付；见[归属迁移](FEATURE_OWNERSHIP_MIGRATION_20261022.md)、[页面拆分](FEATURE_FIRST_PAGE_DECOMPOSITION_20261017.md)、[路由方案](ROUTING_MIGRATION_PLAN_20261019.md) | 全仓无需后续整理、所有页面提示已统一 |
| 业务下沉 | 阅读统计、朗读切分/限制、搜索增量聚合与正文搜索执行已交付并合入dev；`610a9d47b`有3项真实FFI边界验收，见[边界审计及各批证据](RUST_DEDUP_FLUTTER_BOUNDARY_AUDIT_20261023.md) | Android/iOS运行和性能已通过 |
| 依赖与工具 | Rust依赖安全更新、workspace声明收口及Python正式构建入口已交付；SQLite仍使用bundled，Windows系统链接对照只是实验；见[CI编排](CI_ORCHESTRATION_20261010.md)、[SQLite实验](SQLITE_BUNDLED_SIZE_EXPERIMENT_20261024.md) | 移动平台体积或性能收益已确认、需要再做一次相同迁移 |
| 测试与规范 | `e8e7ef46e`、`6ef35d322`、`4658194ac`已清理本轮机械/重复测试与夹具问题；`825d03d48`已取消像素级复刻，现行UI依据为[设计系统](design_system.md) | 最新全量CI已通过、全仓测试价值已全面审查 |

## 二、后续实现与待核验

以下保留原任务编号，合并其重复登记；接续前先核对代码和用户当前优先级。

### AUTO-TASK-EXECUTION-GAPS-20261016：自动任务实际执行（P1，已确认，后续单独实施）

- 手动运行、调度及生成脚本的协议仍需统一；Core内RefreshToc/CacheChapters/UpdateSources/Backup目前可只返回成功消息，不能证明真实业务完成。Custom已走JS，不回退它。
- 定位：`rust/legado-core/src/auto_task.rs`、`rust/legado-engine/src/auto_task_service/`，以及Flutter的任务调度/运行入口。
- 下一步：先冻结统一执行契约，再接实际目录/缓存/书源/备份服务和运行状态；用真实数据库、文件及固定HTTP验证副作用，失败不报告成功。自动任务服务已拆分，不重复做接口迁移。

### RULE-SUB-UPDATE-GAPS-20261016：规则订阅落库及字段保留（P1，已确认，后续单独实施）

- `rule_subscription_service::prepare_update`仍以空本地集合合并，返回统计和版本元数据，未证明书源/RSS源/替换规则已写入各自表。Flutter RuleSub仍缺`js/showRule/sourceUrl`。
- 下一步：按订阅类型连接真实导入事务，补齐实体往返；成功提交后再更新时间与数量。保留手动打开导入确认页的现有入口，不以Mock计数或类型化迁移关闭此项。
- 定位：`rust/legado-engine/src/rule_subscription_service/`、`rust/legado-ffi/src/api/rule_sub_api.rs`、`flutter_legado/lib/src/models/rule_sub.dart`。

### REPLACE-RULE-WRITE-GAPS-20261016：范围与排序持久化（P1，已确认，用户要求后置）

- 现有更新保留旧scope/order，新增默认enabled=true/order=0；UI拖拽与批量置顶/置底尚需按规则ID持久化排序，筛选列表的局部索引操作需一并核对。
- 下一步：先更新契约，再接完整写入和事务排序，重读后验证范围、启停及顺序；不在Dart保存第二份数据。已完成的卡片样式、删除失败提示和导入界面整理不重复实施。
- 定位：`rust/legado-engine/src/replace_rule_service/`及替换净化页面/Notifier。

### SOURCE-JS-PARITY-AUDIT-20261022：剩余公共宿主与规则能力（P1/P2，待分项核验/裁决）

- JS-01～05及JS-11对应的对象上下文、调用作用域、返回值、可选函数、详情增量合并和卷占位修复已交付；不再沿用初次审计的失败结论或3项ignore数量。
- 后续核对JS-06～09：singleFlight/lock回调与计数源隔离、两条jsLib加载路径及URL映射顺序、mainJs config统一解析。库下载失败后的继续策略、getThemeMode协议差异先提交用户裁决，不自行改行为。
- JS-10的批量正文执行与独立段评回复不等同字段已可解析；需单独确认实现范围。搜索结果未携带的变量、文件源完整下载、单引号exploreUrl及未知字段无损往返也不属于此前解析/详情修复的完成声明。
- 证据：[JS审计](SOURCE_JS_PARITY_AUDIT_20261022.md)及其后续修复章节；原版`363540972`、参考版`c4182eb9b`是固定快照，不代表远端最新。mainJs对照不能冒称参考版已有同等实现。

### RUST-BOUNDARY-AUDIT-20261023：剩余边界候选（P2，待新证据，不自动扩范围）

- B1～B10及集成边界验证已交付，不再重跑整条下沉计划。后续只有发现实际重复/职责问题才逐项立项。
- Feature归属五步之外的audio/read_aloud整域重组、其他私有工具/Provider迁移及大页面拆分尚未授权为新批次；页面提示、文案、确认框继续按实际改动收敛，不能全仓机械替换。
- FRB过期绑定已清理，生成工具对未来旧输出残留的识别仍是候选改进，未因一次清理而自动实现。
- 未使用孤儿组件维持“仅整理、暂不删除”的用户约定，CustomProgress已删除；不把旧审计的行数、组件数当作当前盘点。

## 三、已实现但尚需验收

这是尚未取得的验证范围，不是重新开发清单，也不默认触发全量测试、逐页截图或设备安装。
同一领域合并验收；若用户已确认某项，直接更新本节，不保留重复批次条目。

| 合并范围及原编号 | 现有证据 | 剩余验收与完成条件 |
|---|---|---|
| 源编辑框行数：SOURCE-EDITOR-LINES-20261024 | 已接通共享仓储、设置Sheet及书源/RSS多行字段；52项定向回归、改动分析与架构检查通过，`build/source-editor-lines-*.log`；语义见[设置架构](SETTINGS_ARCHITECTURE.md#源编辑框行数2026-10-24) | 主应用检查“不限”及至少10行的显示/内滚动、保存重开后生效、单行字段与完整文本保持；未安装或进行设备验收，不为通用控件新增页面测试 |
| 音频焦点/中断/媒体会话：AUDIO-FOCUS-POLICY-20261024、TTS-INTERRUPTION-20261021、TTS-AUDIO-SESSION / AUDIO-SERVICE-20261020 | `1843f5141`及`build/audio-focus-{core-final,wiring-final,analysis-final,architecture}.log`；既有媒体服务和焦点定向验证 | Android混播、拒绝焦点、耳机拔出；iOS混音、来电/Siri后手动恢复、后台/蓝牙及锁屏媒体操作。不开启忽略时原行为保持，用户暂停不自动续播 |
| 云TTS、HTTP音色和导入导出：TTS-*20261019/20、TTS-TRANSFER-20261019 | [朗读对齐说明](TTS_ALIGNMENT.md)，各Provider已有固定HTTP/native与表单回归 | 真实账号下的鉴权、音色/情感、输出解码及连续后台听感；火山V1/V3保持独立入口，无授权不互相替代。HTTP源登录/POST/JS及实际系统语音按可用素材复验 |
| Rust下沉后的主链路：RUST-BOUNDARY-IMPLEMENT-20261023、BOOK-MEDIA-POLICY-20261023 | `610a9d47b`，`build/boundary-integration/{build,native}.log`；统计/分片/聚合/正文搜索的既有定向用例 | 新应用产物中的搜索/停止再搜、正文命中导航、朗读分片和三类书籍分流；本机3项FFI通过不替代移动端运行结论 |
| 书源解析/主脚本：SOURCE-PARSE-*、SOURCE-JS-CALL / SCOPE / DETAIL-20261022 | [API契约](API_CONTRACT.md)及JS审计后续修复证据，统一Rust解析和实际QuickJS用例 | 主应用粘贴/扫码/预览/严格导入、详情保名和变量传给目录正文；用真实书源确认，不因旧模型测试通过宣称全兼容 |
| 阅读几何与选区：READER-EDGE-TIPS-20261023；FONT-METRICS / SELECTION-BOUNDS / TITLE / SPACING / PAGE-HEIGHT / TIP-UNIFY / FOOTER-CORNERS-20261021 | [设计系统](design_system.md)、[排版契约](READER_LAYOUT_CONTRACT_20261012.md)，既有布局/选区/分页定向回归 | 实际设备中正文安全区、页眉页脚延伸、字形高度与选区颜色、标题/段距及单双页连续翻页；只处理可读性和操作缺陷，不对照上游像素 |
| 重新分段：READER-RESEGMENT-20261024 | 已对齐Core上游分段流程并接通书级开关；23组上游输出对照及阅读/导出/Web/菜单定向回归通过，样例位于 `rust/legado-core/tests/fixtures/content_resegment.json`，语义见[API契约](API_CONTRACT.md) | 主应用开关后的正文与相邻预览、暂停中的朗读及移动设备阅读位置；不重启现有音频，不重复实现已接通功能 |
| 默认替换净化：REPLACE-DEFAULT-20261024 | `1cf0b9787`，全局 Rust 配置、Core 唯一判定及书级覆盖；定向处理/菜单/锚点回归和真实宿主 FFI 调用通过，见 [API契约](API_CONTRACT.md) | 主应用切换全局及书级开关后的正文、目录菜单与阅读位置；未进行移动设备验证，不重新开发已接通功能 |
| 阅读器系统与菜单：READER-KEEP-AWAKE / KEYBOARD-VIEWPORT / ICON-LABELS / BOTTOM-PLACEMENT / DOWNLOAD-STYLE / QUICK-THEME / BATTERY-20261021 | 对应设置与布局行为回归；[设计系统](design_system.md)记录现有约定 | 亮屏到期解除防休眠、输入法不触发正文重排、菜单显示/下载表单、真实电量与系统栏；iOS刘海和底部手势区效果由实际设备确认 |
| 开书动画：READER-OPEN-MOTION-20261022及各旧COVER/TRANSITION批次 | 已使用A轨迹及速度设置；现有转场/归位回归 | 封面进入与返回、中途返回、无可用封面时默认转场的实际连贯性。旧A/B试验或高度缓动独立条目被现实现覆盖，不再分别重做 |
| 公共界面：APP-LARGE-TOP-BAR / HEADER-SPACING / SCROLL-VIEW / TOPBAR-PAINT-BOUNDARY / EXPLORE-SCROLL-POSITION-20261021；REPLACE-RULE-*、SEARCH-SCOPE-MULTI-20261022 | 独立诊断包/定向交互证据和已提交修复；[设计系统](design_system.md) | 主应用顶栏滚动、发现列表无多位置异常，规则卡片点击/拖拽/多选及搜索多源选择；独立诊断包通过不冒称正式包已验收 |
| 缓存与服务：COVER-HTTP-CACHE / CACHE-DOWNLOAD-CONCURRENCY / UI-DOWNLOAD-CACHE-20261019、WEB-SERVICE-LIFECYCLE-20261021 | 真实SQLite/HTTP/文件及配置/队列定向回归，封面专属CacheManager已接线 | 清理范围不伤配置/进度、下载并发与预取新任务生效、封面统计清理；Web运行状态与自动启动偏好分离，重启显示真实状态 |
| 平台WebView与登录：WEBVIEW-* / WEBJS-CONTEXT-20261019 | 已完成Rust通道、请求归属、取消与错误回传定向验证 | Android/iOS实际DOM、Cookie顺序、JS回传、登录/验证码与离场释放；不借本项重做用户后置的Web/MCP服务 |
| 启动、主题与平台效果：STARTUP-NAVIGATION / IOS-LAUNCH-BACKGROUND / APPEARANCE-FONT / THEME-DYNAMIC-PALETTE / SYSTEM-BARS-EDGE-TO-EDGE-20261020、GLASS-BOTTOM-* | 已实现和定向验证；部分MuMu观感记录不等同iPhone | 实际冷启动、外链与崩溃提示恢复、字体/取色、系统栏及玻璃底栏位置。iOS退出入口隐藏已实现，不重新补一个退出功能 |
| 远程构建：FLUTTER-TEST-BEHAVIOR-20261023、CI-REGRESSION / APKSIGNER-FORMAT-20261020、RUST-DEPS-20261023 | 本地测试清理及签名36/37真实APK验签；libc/backtrace苹果目标最小probe编译通过 | 用户要求下一次推送/构建时检查实际Flutter/Rust CI、Release签名收集及iOS正式包；本轮没有查询远端结果，不把历史失败或本地通过当作最新CI状态 |

## 四、明确暂缓与低优候选

| 原编号或范围 | 当前边界 |
|---|---|
| TTS-SYMBOL-QUOTE-20261023 | 已确认符号分段会把结束引号留在下一单元，如`他说：“你好！”然后离开。`；原文未丢失，本地上游也有同样规则。用户明确只记录不修，不混入云请求分片优化；证据见[边界审计§16](RUST_DEDUP_FLUTTER_BOUNDARY_AUDIT_20261023.md) |
| UI-LIQUID-GLASS / UI-MOTION-20261018 | 用户暂缓真机profile；悬浮底栏双层缩放留给玻璃优化，扩大玻璃范围不是自动待办。无测量不宣称性能收益或启动渲染重写 |
| SCH-M及Core拆分 | 选定构建测量、依赖传播和异常/生命周期核查已完成，结论暂不拆Core；不重开全仓错误枚举、运行时或任务框架改造。新缺陷另立范围，参见[排期方法](REFACTORING_SCHEDULE_20261018.md) |
| 开发环境与平台扩展 | doctor后置；移动端RAR替代、跨平台完整运行矩阵、Release体积/性能调优按新需求再安排。JS RAR现有停用不等同移动端能力已补齐；SQLite系统链接实验不改变bundled策略 |
| Characters / RelatedBooks / AI摘要与首页模块解禁 | 历史授权/后置约定仍在，不代表已冻结数据契约或已排期；仅用户重启任务后实施。已废止的像素补页与固定截图阈值不保留为候选 |
| 早期P2-9 / P2-11 / P2-15能力尾项、P2-3样本 | 新EngineContext、网络与JS修复已覆盖部分旧描述，禁止按旧路径/行号直接开工。若遇到Rhino/Java类、`@put`嵌套或语料问题，先用当前入口复现再立具体项；书架脱敏样本仍可按需补充，不为旧“全真实Mock”口号补无用途数据 |
| A*外部场景、P2-23与P3-8 | WebDAV、段评、验证码、皮肤及漫画/视频/音频真实源按需取可用素材；iOS后台任务、硬件媒体键和平台生命周期需要相应设备。旧“无Apple设备”及“仅MuMu可验收”不是当前事实，执行前实时确认能力，不照抄2026-09设备状态 |

## 五、维护与追溯

- 任务状态及精简维护规则见[工作流§3](REFACTORING_WORKFLOW.md#3-状态定义和任务记录)；测试、Git及UI规则分别读取[开发规范](DEVELOPMENT_CONVENTIONS.md)与[设计系统](design_system.md)，不在本文件复制。
- 本次删除的是已完成流水、被后续实现覆盖的旧计划和失效视觉要求，没有另存同体积归档。整理前的410个三级标题及原始日志路径可从已提交快照追溯：

```powershell
git show 5400d4d53:docs/REFACTORING_ACTIVE_PLAN.md
```

本次仅做文档与状态归并，未重新运行业务测试、设备验证或远程CI；不改变应用版本、依赖及功能实现。

编写者：Codex｜2026-10-24
