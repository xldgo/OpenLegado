# 双轨协作开发规范（UI 轨与 Rust 轨）

**日期**: 2026-10-16
**版本**: v1.2
**维护人**: Legado 开发团队

> 本文只规定 Rust/Flutter 双轨边界、Mock 与 FFI/codegen/native 构建专项步骤。通用任务优先级、Agent 派发、当前分支策略、常规验证、证据和关闭流程统一见 [REFACTORING_WORKFLOW.md](REFACTORING_WORKFLOW.md)、根目录 [AGENTS.md](../AGENTS.md) 与[通用开发规范](DEVELOPMENT_CONVENTIONS.md)；视觉目标见 [SCREEN_1TO1_PARITY_SPEC_20260914.md](SCREEN_1TO1_PARITY_SPEC_20260914.md)。

---

## 1. 背景与目标

### 1.1 为什么分轨

Legado Flutter 重构采用 **Rust 核心引擎 + Flutter 跨平台 UI** 架构，两端通过 `flutter_rust_bridge`（FFI）连接。在实际开发中暴露出以下痛点：

- **UI 迭代被 Rust 交叉编译拖慢**：每次修改 Rust 代码都需重新编译 cdylib、执行 codegen、同步 DLL，一次完整循环耗时数分钟，严重拖慢 UI 调整节奏。
- **UI 对齐需要高频迭代**：Flutter 端按参考版截图核对用户可见布局和交互；纯 Dart UI 可先用 Mock 开发，再进入双轨集成验证。
- **任务级并行**：按轨划分文件边界后，UI 与 Rust 引擎的工作可由不同任务或代理并行推进；分工与并行上限以统一工作流为准。

### 1.2 目标

| 目标 | 说明 |
|------|------|
| 解耦迭代节奏 | UI 轨无需等待 Rust 编译即可全速开发 |
| 明确文件归属 | 消除双轨同时修改同一文件导致的冲突 |
| 契约驱动协作 | 通过领域 Repository/Service 接口与 Mock 实现解耦 |
| 规避已知坑 | codegen 产物一致性、DLL 前置重编译等铁律固化 |

---

## 2. 轨道划分与工作范围

### 2.1 目录级边界表

| 轨道 | 允许修改 | 禁止修改 |
|------|----------|----------|
| **UI 轨** | `flutter_legado/lib/src/{app,features,screens,widgets,providers,theme,utils,l10n}`、`flutter_legado/test/` | `rust/`、未经确认的领域契约变更、`bridge/`、`frb_generated*`、`pubspec.yaml` 原生依赖段 |
| **Rust 轨** | `rust/`、经确认的 `domain/contracts/` 契约和 `data/` 适配器、`bridge/`、codegen 产物（`frb_generated.dart` / `frb_generated.rs`） | `flutter_legado/lib/src/{screens,widgets,theme}`（UI 层） |

### 2.2 灰色地带约定

- **providers 属 UI 轨**，但调用的领域接口若需新增或变更，走第 4 节"契约变更流程"。
- **pubspec.yaml**：纯 Dart 依赖（如 UI 库）由 UI 轨自行添加；涉及原生插件或 `flutter_rust_bridge` 版本变更由 Rust 轨负责。
- **公共配置文件**（`Cargo.toml`、`settings.gradle`、`build.gradle`）：修改前必须通知对方，沿用既有协作规范。

---

## 3. FFI 边界铁律

> 本节规则为强制性，违反将导致运行时崩溃。

### 3.1 codegen 归属

- `flutter_rust_bridge_codegen generate` **只由 Rust 轨执行**。
- 产物 `frb_generated.dart` 与 `frb_generated.rs` **必须由同一次 codegen 生成并一次性提交**。
- 禁止手改 `frb_generated*` 任何内容（包括 content hash），codegen 会覆盖手改。

FRB Dart runtime、Rust runtime 与 codegen 当前精确配对为 2.13.0。
生成入口从 `pubspec.yaml` 读取版本并检查已安装 codegen；生成后以
`cargo build --locked -p legado-ffi --features quickjs` 重建原生库。
Flutter 为 3.47.7，包声明的 Dart 最低版本为 3.13；环境检查须核对实际版本，
不依赖开发者个人的 FVM 配置。

### 3.2 已知坑：content hash 不匹配

每次 codegen 会重新计算双侧 content hash。若 codegen 后未重编译 Rust DLL/.so，旧二进制中嵌入的 hash 与新生成的 Dart 侧 hash 不一致，启动即报：

```
Content hash on Dart side (X) is different from Rust side (Y),
indicating out-of-sync code
```

**构建配对检查（2026-10-11 更新）**：Android Gradle 调用同一 Python 只读校验器，
检查契约、源码与工具指纹、ABI/profile/features、元数据和实际库摘要：

| 入口 | 行为 |
|------|------|
| `flutter build apk` / Gradle variant `preBuild` | 对应 Debug/Release/Profile 的任务执行 Python 严格只读校验；失配则构建失败 |
| `python scripts/dev.py build ffi android ...` | 独立编译、复制并生成 v2 元数据；失败不降级或复用旧库 |
| `python scripts/dev.py build android ...` | 编译 FFI、严格校验、打包并检查 APK；安装启动需显式选择设备 |
| `scripts/emulator_smoke_test.ps1` | 保留设备 QA，构建调用 Python；Debug APK 与 Rust Debug 配对 |
| `python scripts/dev.py collect apk android ...` | 校验已有分 ABI APK 与 Cargo/jniLibs 来源，全部通过后收集；不重新编译或安装 |
| 本地纯 Dart UI 开发 | 仅 Debug，同时显式 `USE_MOCK=true` 和 `LEGADO_SKIP_RUST_BUILD=1` 才可跳过 |
| Release/Profile/CI | 禁止通过跳过变量绕过校验 |

**Android 构建流程（仓库根目录 PowerShell）**：

```powershell
python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64
```

**正确做法（Rust 轨 codegen 后）**：先完成生成，再显式重编对应 native 库，成对验证后运行。
生成入口不隐式关闭应用或重编 DLL。Android 使用上述 Python 构建命令同步 jniLibs；
解释器、Mock 限制及迁移证据见 [Gradle 接线说明](PYTHON_GRADLE_FFI_20261011.md)。
Android 旧入口已删除；APK 与安装参数见 [Android 入口说明](PYTHON_ANDROID_CLEANUP_20261011.md)。

### 3.3 UI 轨禁区

- UI 轨**永远不手改** `bridge/` 目录下任何文件。
- UI 轨**不执行** codegen 命令。
- 若 UI 轨发现 FFI 调用报错，应报告 Rust 轨处理，而非自行修改。

### 3.4 DLL / .so 构建

- 构建由 Rust 轨负责。
- Windows 使用 `python scripts/dev.py build ffi windows --profile debug` 独立生成和校验 DLL；应用构建/开发会话分别使用 `build windows`、`run windows`。
- CMake 负责复制对应 profile 的 DLL；Python 传入当前 Cargo 输出目录并复核最终复制摘要，不跨模式回退。旧 Windows/生成脚本及 Makefile 已删除，详见 [Windows 工具说明](PYTHON_WINDOWS_TOOLING_20261011.md)。
- DLL 被运行进程锁定时提示用户手动关闭应用，生成器和构建入口均不强制终止进程。
- iOS 正式静态库由 `python scripts/dev.py build ffi ios --target device --profile release` 编译，模拟器使用 `--target simulator`；保留 CocoaPods `RustFFI` 的 `-force_load`。最终应用的 PDE 符号由同一 Python 入口检查；模拟器兼顾 `Runner.debug.dylib`。元数据与平台边界见 [iOS 工具说明](PYTHON_IOS_TOOLING_20261011.md)，历史 XCFramework 不接入本流程。

### 3.5 frb 构件配对纪律（评审 W2 登记，持久约束）

> 背景：`lib/src/bridge/ffi.dart` 顶部曾手写配对警示，被一次 codegen 直接抹除——
> 生成文件里的手写内容不可靠，故将纪律沉淀到本持久文档。

frb（flutter_rust_bridge）的调用桥按 **funcId 序号**把 Dart 调用分派到 Rust 函数，
两侧生成物（Dart 侧 `bridge/ffi/ffi.dart` 等 + Rust 侧 `frb_generated.rs` + 编译产物
`.dll`/`.so`）必须满足：

1. **原子重建**：任何 FFI 面变更后，「codegen 生成 → cargo 重编译 → 替换运行环境
   .dll/.so」必须作为一个原子操作整体完成（原 Makefile `gen` 目标已随 Makefile 归档废止，见 docs/过期文档/Makefile；Windows 环境无 make，以 codegen 脚本为准），
   不允许只重生成 Dart 不重编 Rust，或只替换二进制不更新生成物。
2. **禁止混配**：不同 codegen 批次产出的 Dart 生成物与 .dll/.so 严禁混搭运行
   （例如新 Dart 绑定配旧 .so）。混配时 funcId 序号错位，Dart 调用会被分派到
   **另一个 Rust 函数**——后果是参数类型错位的随机崩溃（native segfault/
   栈溢出）或静默数据错乱，且堆栈无 Dart 符号、极难定位（历史上已多次踩中）。
3. **content hash 双向抽查**：每次重配后用 `FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH`
   校验两侧一致——Dart 侧启动报错信息中的 hash 与 Rust 编译时嵌入的 hash
   必须相同；交付/验收 APK 前先抽查两侧 hash，发现不一致一律整套重建而非局部修补。
4. **生成文件零手改**：`bridge/` 目录及 `frb_generated.*` 均为 codegen 产物，
   任何手写注释/警示都会被下次 codegen 抹除；需要持久化的约束一律写入本文档。

---

## 4. 契约变更流程

项目通过 `domain/contracts/` 中的窄 Repository/Service 接口解耦 UI 与 Rust：

```
页面 / Notifier / 辅助服务
  → 领域 Provider 或显式构造参数
  → Repository / Service 契约
      ├── data/ 下的 Rust 实现 → FRB
      └── data/ 下的 Mock 实现 → 共享 Mock 数据
```

切换机制：`--dart-define=USE_MOCK=true` 启用 Mock，否则走真实 FFI。

`app/bootstrap/application_dependencies.dart` 注册领域能力；
`application_bootstrap.dart` 创建应用容器并显式初始化 `AppRuntime`。
启动和界面共用同一容器，`ApplicationScope` 在卸载时释放它。
`BookApi`、`RustApi` 和 `bookApiProvider` 已从生产链路移除；
`test/fixtures/` 的组合夹具只服务现有测试，应用代码不得引用。

### 4.1 新增 API

- Rust 轨可自由添加新方法，但必须**同步完成三件事**：
  1. 在对应领域契约新增方法，不创建全能根接口
  2. 数据层提供真实 FRB 适配实现并接入应用装配
  3. 对应 Mock 实现提供行为明确的假数据能力
- 更新 `API_CONTRACT.md` 登记新方法签名与返回结构。

### 4.2 修改 / 删除已有 API（破坏性变更）

- 必须**双轨评审确认**后才能修改。
- 同步修改：领域契约 → Rust 适配器 → Mock 实现 → 装配及全部调用点。
- 在 PR 描述中明确标注"破坏性变更"及影响范围。

### 4.3 UI 轨需要新数据时

流程如下：

1. **登记需求**：在 `API_CONTRACT.md` 的"需求区"登记（方法名 + 入参/返回 DTO 或真实 JSON 文档结构示例）。
2. **Mock 先行**：UI 轨在对应领域 Mock 实现中提供假数据能力，继续 UI 开发。
3. **Rust 交付**：Rust 轨按契约实现真实方法，并接入对应数据适配器。
4. **验证切换**：UI 轨去掉 `USE_MOCK=true`，验证真实数据流通。

---

## 5. Mock 开发工作流（UI 轨日常）

### 5.1 启动命令

```bash
flutter run -d windows --dart-define=USE_MOCK=true
```

- 无需 DLL、无需 Rust 编译环境。
- 秒级热重载，专注 UI 调整。

### 5.2 日常流程

1. 启动 Mock 模式。
2. 按 `SCREEN_1TO1_PARITY_SPEC_20260914.md` 和对应屏幕台账对照参考版截图；状态以 Active 计划为准。
3. 使用 `flutter analyze` 确保静态分析无错误。
4. 编写 / 更新 `flutter_legado/test/` 下对应 Widget 测试。
5. 按根目录 `AGENTS.md` 当前分支和提交策略交付，不沿用本文件旧分支示例。

### 5.3 实机验证

- 里程碑节点才构建 APK 上模拟器 / 实机对照。
- APK 构建通过当前统一构建脚本或 CI 执行；涉及 Rust 交叉编译时按 §3.2/§3.4 校验 hash。
- UI 轨不自行执行含 Rust 编译的构建流程。

---

## 6. Git 分支规范

### 6.1 分支与冲突

- 分支创建、命名、集成分支和提交历史纪律以根目录 `AGENTS.md` 为准；本文不再维护第二套分支方案或示例。
- 同一批跨轨修改必须先界定文件所有权与契约。遇到共享文件冲突、契约语义不一致或 codegen 产物不匹配时暂停合并，由任务负责人依据 `API_CONTRACT.md` 和当前任务卡协调；不得仅按“某轨优先”覆盖另一侧。

### 6.2 冲突处理

- FFI 边界文件（`bridge/`、`frb_generated*`、`rust_api.dart`）冲突时暂停集成，先核对已确认契约和本批文件边界，再由任务负责人安排解决。
- UI 层文件冲突时按任务卡确认的文件所有者处理，不用轨道标签覆盖未提交工作。
- 公共文件冲突时暂停相关提交并协调，保留双方尚未提交的改动。

### 6.3 集成顺序

- 集成分支与合流步骤遵循根目录 `AGENTS.md` 和当前任务卡，不把固定的“Rust 先合、UI 再 rebase”作为所有任务的通用规则。
- 对确实涉及 FFI 的批次，契约先行；随后在同一集成批次完成 Dart/Rust codegen、native 重建、hash 核对和端到端验证。未完成配对验证不得交付。

### 6.4 提交信息

提交格式、中文描述、版本和双日志同步均以 [DEVELOPMENT_CONVENTIONS.md](DEVELOPMENT_CONVENTIONS.md) 与根目录 `AGENTS.md` 为准；旧式 `[UI]` / `[Rust]` 样例仅作历史记录，不用于新提交。

---

## 7. 集成节奏

### 7.1 集成触发

- 集成以任务依赖、契约变更和阶段门为触发，不规定固定周频。
- FFI 契约或 codegen/native 产物变更后必须执行本节对应的配对验证。

### 7.2 集成验证步骤

1. 按根目录 `AGENTS.md` 当前分支策略集成，不改写已提交历史。
2. 以当前 CI 工作流验证 Flutter/Rust 常规门禁；不重复派角色跑 CI 覆盖项。
3. FFI 变更执行 §3 的双侧 codegen、native 构建及 hash 校验。
4. 仅对 CI 未覆盖的平台或 UI 行为按统一工作流执行设备/桌面验收。

**Flutter 排版测试的本地准备**：`test/helpers/native_reader_layout.dart` 复用正式
`NativeReaderLayoutTransport` 与 FRB Opaque 会话，每个测试worker初始化一次绑定，
用例结束清理尚未关闭的句柄；不启动应用或打开数据库。Windows在根目录使用
`python scripts/dev.py build ffi windows --profile debug`；Linux/macOS使用
`cargo build --locked --manifest-path rust/Cargo.toml -p legado-ffi --features quickjs`。
默认从当前工作树 `rust/target/debug/` 加载对应的 DLL/so/dylib；复用其他Cargo目录时，
将 `LEGADO_TEST_FFI_LIBRARY` 设置为实际原生库绝对路径。绑定与原生库必须来自同一契约。

需要真实分页的Widget测试使用 `pumpNativeReaderLayout` / `settleNativeReaderLayout`
交替等待真实I/O和推进测试帧；只调用 `pumpAndSettle` 不保证原生回调已经完成。
普通组件测试继续使用固定布局输入，不要求原生库。旧逐次启动进程、重放全部内容的
宿主及专用JSON测试链路已退役；测试辅助器只负责调度与清理，不另写分页算法。
上游算法样例在Rust完整比对；真实FRB仅抽取两种代表载荷验证映射与句柄。
分段、索引与设置传参单测不初始化原生库；需要测量、渲染和原文坐标配合的
跨层回归仍使用正式FRB。普通调试计时不作为默认测试或发布性能证据。

### 7.3 集成失败处理

| 失败类型 | 责任方 | 处理方式 |
|----------|--------|----------|
| FFI 调用崩溃 / hash 不匹配 | Rust 轨 | 回退 Rust 轨提交，重新 codegen + 编译 |
| UI 渲染异常（Mock 通过但真实数据异常） | 双方协同 | 检查契约是否一致，修正数据格式 |
| 编译错误（Dart 侧） | UI 轨 | 修复后重新提交 |
| 编译错误（Rust 侧） | Rust 轨 | 修复后重新提交 |

- 集成失败时，优先回退到上一个已知良好的集成点，再逐步排查。

---

## 8. 附则

### 8.1 与既有文档的关系

| 文档 | 关系 |
|------|------|
| [DEVELOPMENT_CONVENTIONS.md](DEVELOPMENT_CONVENTIONS.md) | 通用开发规范，本规范为其在双轨场景下的补充 |
| [REFACTORING_WORKFLOW.md](REFACTORING_WORKFLOW.md) | 通用任务实施、Agent 分工、验证证据与关闭流程 |
| [API_CONTRACT.md](API_CONTRACT.md) | 契约登记表，本规范第 4 节流程的操作载体 |
| [VERSION_CONTROL.md](VERSION_CONTROL.md) | 版本记录，集成里程碑在此登记 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | 开发者指南，含构建与运行说明 |

### 8.2 生效与修订

- **生效日期**：2026-08-01；流程边界修订：2026-09-27
- **修订流程**：规范文档修订遵循根目录 `AGENTS.md` 与统一工作流；若修订涉及 FFI 契约，另按契约的双轨确认要求执行。更新本文档版本与日期。
- 修订时同步更新文档头部版本与日期。

### 8.3 术语表

| 术语 | 含义 |
|------|------|
| UI 轨 | 负责 Flutter UI 层开发的轨道 |
| Rust 轨 | 负责 Rust 引擎 + FFI 边界的轨道 |
| codegen | `flutter_rust_bridge_codegen generate`，生成 FFI 桥接代码 |
| 契约 | 领域接口与 FFI 定义的方法签名及数据结构约定 |
| Mock 模式 | `--dart-define=USE_MOCK=true` 启用假数据实现 |

---

**最后更新**: 2026-10-16
**维护者**: Legado 开发团队

本次边界更新：Codex + Bridge｜2026-10-16

### Rust 引擎装配与宿主边界（2026-10-16）

`legado-engine` 汇集存储、网络、限流、JS 数据资源与任务作用域，FFI 和 Server 共享注入实例。
FFI 根边界保留首次成功初始化的契约；业务闭包捕获窄数据能力，不反向持有根引擎。
Web/MCP 监听状态及 Tokio runtime 由宿主拥有；停止端口和等待实际任务结束是两个独立事实。
任务组有界关闭超时须报告仍有工作，不能提前清空登记或宣称同步 JS 已被强杀。
本次内部重构不更改 FRB 方法、JSON、生成绑定、依赖与应用版本。
真实 Flutter 应用使用新 Rust 实现前仍需重建 native 产物；Rust 单测不替代设备验收。

— Codex，2026-10-16

测试分层更新：Codex｜2026-10-17

### 搜索与换源应用服务边界（2026-10-17）

`legado-engine/search_service`接管单源请求与解析、普通/精确/流式搜索、结果转换、
阅读记录标记及持久化，内部按model/records/source划分；SearchResources显式注入
存储、网络、SearchTasks、TaskGroup、宿主运行时Handle与FetcherDeps装配函数。
普通搜索替换旧会话，精确搜索独立登记；旧会话不能写库或向新会话发布结果。
服务不访问FFI当前实例、不持根EngineContext、不创建运行时；宿主保留JS绑定装配与协议转换。
FFI入口和DTO/生成绑定不变；动态文档格式仍在适配边界解析，不引入另一套传输协议。

`legado-engine/source_switch_service`接管换源过滤/评分、增强、预取、变量合并和事务提交；
内部按search/enrich/repository/apply分工。SwitchSearcher由宿主注入并直接调用Engine单源搜索，
候选转换共用result_to_candidate，不再调用FFI搜索执行器。运行时由宿主持有，服务只借Handle；
操作槽及TaskGroup保持实例归属，迟到结果仍受发布门控。
`source_batches`是普通搜索和换源共用的唯一调度实现，`source_catalog`共用启用源筛选；
保持32并发、普通搜索每源30秒及换源每源60秒超时，不因服务提取改变限流、暂停和错误策略。
评分同步先归还查询连接，再更新同一实例的config缓存，支持单连接内存实例。
本次不改数据库、外部依赖版本或应用行为；真实Flutter使用前仍需重建native产物。

编写者：Codex｜2026-10-17

### 发现与书源校验应用服务边界（2026-10-17）

`legado-engine/explore_service`接管分类/控件脚本、所属实例infoMap默认值与写回、
发现分页抓取的同步驱动；显式接收JsResources、SourceInfoMap、TaskGroup、宿主Handle
及source绑定装配函数，不回查FFI根实例、不另建运行时。平台动作仍使用既有收集队列。
`legado-fetcher/explore`负责发现HTTP/data URI、登录校验、规则解析和字段处理；
`explore_url`负责携带infoMap/page的URL求值，setup由捕获的FetcherDeps提供；
`explore_js`集中原jsLib降级加载，保留URL映射/完整脚本/sanitize/前缀/host声明的顺序。
FFI保留实体与文档适配、原路径重导出及宿主JS绑定装配；调试入口可继续传入自己的deps/任务。

`legado-engine/source_check_service`显式接收存储、网络、TaskGroup、OperationSlot与Handle，
保留单源独立任务和批量串行校验；选中禁用源仍校验，缺失URL保留占位与索引。
替换/取消/关闭回调受原操作发布门控保护，不新增数据库结果回写或更换底层SourceChecker。
本批不改FRB签名、DTO/生成绑定、外部依赖、数据库或可见行为；完整状态只记Active计划。

编写者：Codex｜2026-10-17

### 阅读应用服务边界（2026-10-17）

`legado-engine/reading_service`按toc/access/content/processing/pre_update划分目录事务、
读取编排、原文缓存与下载、内容设置/处理和刷新前钩子。ReadingResources显式接收存储、
抓取工厂、任务组、WebBookState、JS资源、搜索服务、宿主Handle及本地路径解析器；
不反向依赖FFI，不持根EngineContext或自建运行时。路径解析器由宿主捕获数据目录后注入。

目录刷新保持tocUrl/originBookUrl/bookUrl取址链、空目录保护、单事务重写和进度列排除；
原文读取和下载共用ChapterContent，缓存仍保存原文，规则/繁简/重复标题只作用于展示路径。
普通阅读尽力缓存与显式缓存保存的Result错误语义分别保留，不为合并代码而改变失败策略。
已取消任务的缓存及媒体副内容发布仍走原门控；不据此宣称同步解析被强杀或所有目录写入
新增了取消保证。preUpdateJs的reGetBook/refreshTocUrl直接复用所属Engine精搜与Fetcher详情，
不再从钩子回调FFI搜索/详情入口；稳定bookUrl与钩子更新字段保持原语义。

FFI保留宿主装配、旧入口和类型重导出；对外DTO/生成绑定、数据库和应用版本不变。
Engine仅新增对已有legado-book/legado-parser的workspace依赖边，外部锁定包版本不变。
正式应用使用前须重建native；实现状态与验证边界只记Active计划。

编写者：Codex｜2026-10-17


### 书源调试应用服务边界（2026-10-17）

`legado-engine/source_debug_service`负责关键字分流、搜索/发现/详情/目录/正文串联和日志。
SourceDebugResources显式接收可选存储、抓取工厂、infoMap、操作槽、宿主Handle及ExploreService；
只保存窄资源快照，不持根EngineContext，不新建运行时或在执行中回查FFI全局槽。
搜索/详情/目录/正文继续复用Fetcher，发现直接消费所属ExploreService与本次deps/infoMap/任务。
文档解析与日志展示规则原样保留，不借迁移更改调试协议或补全Server的独立调试端点。

操作槽按实例替换会话；回调失败仍在退出发布门控后取消，避免重入锁。
入口丢弃停止本次发布，实际阻塞worker仍持凭据直到工作结束；不宣称同步JS或HTTP被强杀。
FFI保留宿主JS绑定/目录能力装配、类型重导出和流事件适配；调试与校验操作槽仍相互独立。
原HTTP/JS和会话测试随服务迁移，媒体副内容的迟到落库门禁留在FFI层复验真实宿主注入。
本批不改FRB签名、DTO/生成绑定、数据库、版本或音频/TTS业务，状态与证据只记Active计划。

编写者：Codex｜2026-10-17


### 段评应用服务边界（2026-10-17）

`legado-engine/review_service`以model/rules/js分离请求与应用结果、HTTP规则和JS编排。
ReviewResources只接收所属NetworkContext、JsResources与宿主Handle，不保存根EngineContext，
不自建运行时或在请求/解析中重新发现FFI全局实例。规则解析复用Fetcher的JS分析器适配，
mainJs复用原编排器；两者保留原source作用域和JSON字符串形式的book/chapter脚本参数。

摘要缺失/禁用仍返回空，详情与回复缺规则仍报原错误；保留规则路径page下限、直连URL优先、
相对地址、请求头覆盖、CookieJar内部标记、回复分页和嵌套条目转换。原JS路径的页码处理保持。
本批未新增取消、限流、登录校验或关闭保证，也未调整段评UI、排版与Server的本地评论功能。

请求实体和应用结果不依赖FFI DTO；摘要复用Parser模型，页面保留has_reply_url应用信息。
FFI保留JSON文档解析与DTO转换；可空条目字段及nextPageUrl仍由原DTO序列化，避免直接使用
Parser的skip_serializing_if改变既有文档形状。签名、DTO字段、生成绑定与存储不变。

测试复用同crate的本地HTTP夹具；共同辅助仅在cfg(test)编译，POST按Content-Length完整读取，
不增加外部宿主或独立RPC协议。实现状态与验证限制只记Active计划。

编写者：Codex｜2026-10-17


### 词典与封面规则应用服务边界（2026-10-17）

`legado-engine/dictionary_service`负责词典查询、规则CRUD/排序/导入、JS作用域与释义处理；
`cover_service`负责封面配置和串行规则搜索；两者共享`rule_text`取体实现，不互调FFI业务入口。
各服务显式接收可选StorageContext、NetworkContext、JsResources和宿主Handle，
只捕获所属实例能力，不持根EngineContext、不创建运行时或在请求期间回查当前宿主。
默认封面JSON由宿主注入，服务仅在需要回退时解析，不依赖FFI的assets目录。

词典保持空表种子、trim保留大小写、排序和按名称导入保留ID；导入明确报错，查询单规则失败跳过。
封面保持单配置保存、缺配置回退、禁用源不执行与相对URL补全。共享取体沿用data URI、
AnalyzeUrl方法/请求头/body、followRedirects/retry和15秒外层超时，不另造网络请求策略。
词典及导入不主动补CookieJar，封面按配置只补不覆盖，内部标记仍由Net剥离后发送。
不新增任务取消/限流、事务、HTML渲染、字典分标签或其他用户可见行为。

FFI保留宿主能力装配、规则DTO和JSON文档转换；DictEntry与CoverRuleConfig在原路径重导出，
传输字段、序列化空值和持久化文档不变。Engine的regex直接依赖使用工作区已有锁定版本，
不升级外部包。测试复用本地HTTP夹具，仅增加可配置响应头以检查真实Set-Cookie门控。
完整进度与验证边界只记Active计划；音频/TTS业务继续暂缓。

编写者：Codex｜2026-10-17

### 本地书籍导入与导出应用服务边界（2026-10-17）

`legado-engine/book_import_service`负责格式检测、元数据解析及书架入库；
`book_export_service`负责导出正文组装、选项应用和预览。导入显式接收所属存储和路径解析器，
导出显式接收所属存储及图片获取器，不持有根引擎、不回查当前宿主或重新装配阅读/搜索服务。
图片获取器由 FFI 捕获所属 NetworkContext 和宿主运行时 Handle；TXT 等非 PDF 导出不调用它。

`reading_service::ContentProcessing`仅持有存储，承接原有正文处理配置和实现，供阅读与导出共用。
替换规则、简繁转换、章级重复标题开关和原始缓存的处理顺序不变，不为导出另写一套净化算法。
普通阅读继续通过 ReadingService 委托，导出直接使用同一存储构造的 ContentProcessing。

导入保留原传入标识作为 bookUrl，仅读取文件时解析相对路径；格式检测/元数据入口仍直接消费传入路径。
导出保留原本地解析器与在线原始缓存来源，不借本批修改相对导出路径、缺缓存回退或图片请求策略。
FFI保留宿主装配、选项 JSON 解析及原类型路径重导出；签名、DTO、生成绑定、数据库和版本不变。
测试中的两个内存数据库用于验证独立实例，不表示应用新增数据库或双库模式。
状态与本地验证证据只记 Active 计划；音频/TTS、压缩和编码薄入口不在本批范围内。

编写者：Codex｜2026-10-17

### 备份与WebDAV应用服务边界（2026-10-17）

`legado-engine/backup_service`管理已有六组数据的备份文件、逐项恢复、目录扫描和旧版导入。
服务只持所属StorageContext，目录条目与旧版导入统计使用Engine自身模型；FFI保留原DTO映射、
旧版导入结果JSON及恢复统计JSON的外壳，备份文件本身继续在服务内按已有文档格式读写。
不为本批引入新的数据库、事务、历史格式回退或备份集合；恢复成功计数与失败跳过策略保持。
阅读记录恢复使用与创建相同的DB实体，保持磁盘book_name/read_time字段不变，避免误用Core实体
将其读成空书名和零时长；仍按已有upsert策略写入，不借机改变其他记录字段的恢复策略。

`webdav_service`只接收所属CustomHosts和宿主运行时Handle，配置参数为Net的WebDavConfig，
执行中不查询FFI全局、不保存根EngineContext或自建Runtime。HTTP认证、路径、目录协议、
全量/增量同步算法继续复用Net的WebDavClient和BookSyncManager。
服务承接本地文件读写及同步调用，FFI保留配置文档解析和既有同步结果JSON包装。
未将整文件传输改为流式上传，也未更换客户端策略或补充取消/重试/冲突解决行为。

Runtime选择仍在FFI：优先当前Handle，否则使用持久兜底Runtime，避免返回临时Runtime的失效Handle。
直接Engine调用者须保证传入Runtime存活，服务不承担调度器所有权。
测试复用现有crate内HTTP夹具，验证真实方法、路径、认证、请求体和文件落盘，不新增宿主协议。
FFI签名/DTO/生成绑定、UI、schema和版本不变；当前状态与发现的缺陷统一记录在Active计划。

编写者：Codex｜2026-10-17

### RSS应用服务边界（2026-10-17）

`legado-engine/rss_service`按sources/articles/records拆分源管理、文章加载缓存和收藏/已读。
RssService仅持所属StorageContext；文章加载方法额外接收所属NetworkContext和宿主Handle，
不持根EngineContext、不自行创建Runtime或在执行中查找FFI全局资源。
普通源管理、收藏与已读的宿主装配不启动网络或运行时；FFI保留源文档解析/导出和DTO映射。
RssArticle在Engine定义并从原FFI路径重导出，收藏返回DB记录后由FFI映射原RssStarDto。

RSS源44字段映射统一在DB仓储，find_all保持坏行报错供备份使用，find_all_skip_invalid
供页面列表保留原逐行跳过策略；共用相同查询和字段映射，不借去重改变错误处理。
列表排序、原子更新、默认分组删除、导入逐项写入及错误文本沿用原路径。

文章保持cacheFirst和最多500条缓存读取、RSS/Atom解析、非标准内容200字符摘要回退，
保持按源Cookie开关添加内部标记和尽力写入文章缓存，不引入额外JS、规则、事务或取消策略。
清理文章缓存不改变收藏/已读身份；收藏时间与已读操作继续复用原DB仓储及默认字段。
本批不改FRB签名、DTO、生成绑定、schema、版本或音频/TTS。状态与证据仅在Active计划维护。

编写者：Codex｜2026-10-17


### 图片获取与缓存服务边界（2026-10-17）

`legado-engine/image_service`负责复合URL、书源/内嵌请求头优先级、默认UA/Referer、
Cookie写回标记、图片下载状态与imageDecode。ImageService只持所属JsResources，
下载另外接收NetworkContext与宿主Handle，不保存根EngineContext或查找FFI全局。
FFI继续解析书源JSON文档、装配既有资源与持久运行时，FRB签名和字节返回不变。

解密每图创建独立VM，保留source上下文和完整复合URL的src绑定，避免const/let重复声明。
可选jsLib加载失败仍尝试内联规则；规则失败/空结果回退原字节，下载入口对配置了解密规则
却仍无可识别图片签名的结果报原错误。签名检查不是完整图片格式解码验证。

`image_cache_service`只持调用时注入的根目录，负责书级目录/MD5中段文件名、后缀和文件IO。
目录选择留在宿主，保持非空LEGADO_IMAGE_CACHE_DIR > MediaState注入目录 > 临时目录；
每次FFI操作重新装配目录快照，后续注入影响下一次操作，不改变进行中的操作归属。
MediaState现有音频/TTS字段不改。MD5直接复用仓库已有0.8.1，只有Engine依赖关系增加。

读失败/不存在返回None，写失败返回false；成功读取空文件仍返回Some(empty)，
Dart仓储对空字节的既有处理不变。同类失败保持进程级一次告警，不作为目录或内容状态。
缓存键/目录命名与已有文件兼容；下载和缓存仍为独立操作，不新增自动缓存、清理、重试、
取消或格式检查。已薄化CBZ接口不变；当前字节仍使用SSE，不宣称零拷贝。
状态和验证结果仅维护于Active计划。

编写者：Codex｜2026-10-17


### 规则订阅服务与双宿主边界（2026-10-17）

`legado-engine/rule_subscription_service`集中订阅存储操作与更新准备。
RuleSubscriptionService在宿主数据库闭包内借用连接，不持根EngineContext或自行获取第二条连接；
FFI沿用with_database，Web沿用AppState.with_database的阻塞调度和任务取消保护。
同步操作完成后仅把RuleSubRecord快照带到异步网络阶段，不持连接或服务跨await。

公共异步check_update只做远程版本比较，FFI专用check_update_with_interval额外执行原间隔判定，
保留尚未到期仍然实际拉取的行为；Web不新增该计算或返回字段。
网络继续显式消费所属CustomHosts并复用Net原客户端、超时、TLS和UA后缀策略，不切换共享Cookie客户端。
服务不保存Runtime或用block_on嵌套进入Web运行时，FFI同步等待由宿主负责。

PreparedUpdate区分FetchFailed、MergeFailed与Ready，Ready保存原合并结果和待回写版本元数据。
FFI严格传播版本写入错误，Web保持内部写入错误忽略、外层调度错误记录日志；该差异由宿主决定。
FFI检查/应用结果类型从原模块重导出，现有DTO映射不变；Web继续保留snake_case字段、
缺订阅形状及网络失败仅success/error的响应，不因共享业务结果而暴露额外字段。

prepare_update仍对空本地数组执行原合并算法，只生成统计并回写订阅版本/时间，未导入目标实体表。
该已知功能缺口继续归属Active中的RULE-SUB-UPDATE-GAPS-20261016，不以本批架构收口销账。
不新增订阅能力、自动任务、导入/事务/取消策略，不改FFI签名/DTO/生成绑定、UI、schema或依赖版本。
状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-17


### 书源管理与提交后限速发布（2026-10-18）

`legado-engine/book_source_service`在宿主数据库闭包内借用连接，集中完整实体CRUD、启停、变量
单列更新、类型化批量导入和编辑字段更新；不持根EngineContext、不重新获取池连接。
source_catalog保留原选择/排序语义，只复用服务的启用查询。

SourceWrite仅持成功写入的返回值与限速变更，不持数据库、注册表或根引擎；宿主在原提交位置
调用publish并显式指定所属RateLimiterRegistry。FFI在with_database成功返回后发布，Web创建/
编辑仍在阻塞闭包内提交后发布，在线Room更新仍在异步数据库操作成功返回后发布。
任何写入/提交失败均不返回可发布结果；若新调用者另开外层事务，须等待最外层提交后发布。
不在Drop中隐式刷新，也不改变请求取消或数据库任务的原生命周期。

完整实体保存不改字段；编辑字段输入与完整BookSource模型区分，未暴露字段从库内保留。
concurrentRate缺键保持且不刷新，null/空串清除，有值更新；未知path仍按默认实体补齐，
保持按path查询、按body URL写入的既有行为。删除/启停/变量修改不额外刷新限速。

类型化导入继续复用BookSourceRepository.insert_batch，保留规则对象和variable；RoomSourceImport
从同一组选中值生成原JSON文档及限速变更，再复用RoomImporter原列映射与事务，不混合两种格式。
Room在线更新的网络、筛选和计数仍由既有路径负责；失败整批回滚，成功提交后才发布。
FFI只解析文档和装配资源；Web保留请求DTO/三态反序列化、任务保护与响应。已无消费者的私有
refresh_source_rate_limit包装移除，许可获取和同一注册表的宿主装配保留。
本批不改变FFI签名/生成绑定、UI、schema、版本或依赖；状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 替换规则管理与执行服务（2026-10-18）

`legado-engine/replace_rule_service`借用宿主已取得的数据库连接，集中规则CRUD、启停、
新增默认值和编辑可选字段合并；ReplaceRuleFields只代表现有编辑入口允许写入的字段。
新增仍默认启用、order=0，更新仍保留scope/order，None保留、空串清除语义不变。
FFI继续提供原参数和JSON文档解析，不新增公共DTO或改写生成绑定。

书源导入沿用core的书源作用域规则和顺序执行，不注入JS执行器；查询失败由FFI原位置
返回输入文档，单条规则失败由core保留当前文本。正文/导出的规则处理不改，未扩入MCP。

预览接收已解析规则及宿主入口捕获的JsResources，不在超时工作线程查询宿主全局槽位。
每次匹配仍创建独立QuickJS VM，保留source/replace-rule-preview来源、64MB沙箱及result绑定；
来源变量与登录能力属于同一注入实例，不持根EngineContext或自建Runtime。
复用core既有逐规则超时及替换实现，执行失败仍返回原警告字符串，非法文档仍为FFI输入错误。
未启用QuickJS时维持原不可用提示，不额外引入取消或后台任务关闭协议。

本批不解决scope/order写入与Flutter排序持久化缺口；该后置项仍由Active计划单独登记。
FFI契约、UI、数据库、应用/依赖版本不变；状态和验证证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 书源登录与章节购买动作（2026-10-18）

`legado-engine/source_action_service`分别承接V1登录、V2渲染/动作及章节购买编排。
宿主入口一次捕获StorageContext、JsResources、SourceLoginCache与setup回调；回调仅持
登录和infoMap能力，不持根EngineContext。未开库的登录仍可使用同一内存服务，购买仍报原错误。
数据库查询分别借还连接，脚本执行不持数据库连接，也不新建或拥有Tokio Runtime。

V1保持getLoginJs去壳、动作名处理、sanitize jsLib与共享解析器setup；setup错误和脚本
执行错误仍按原路径忽略，最后返回登录头或空值，不借本批改变既有错误策略。
V2仍用core协议处理空状态/表单及命令，每次调用创建独立VM并注入原baseUrl/source绑定；
命令的login数据在脚本执行完成后写入同一登录服务，覆盖脚本中的中间值。
购买沿用本地书短路及书/章节/源检查顺序，原book/chapter/title/baseUrl/result/src绑定保持；
成功只按书籍URL与章节URL清理数据库正文缓存，URL/none结果不清理。

V2和购买只共用原本一致的独立VM构造及JSON到JS值转换，64MB沙箱、来源tag、
实例Cookie/来源请求头和无QuickJS行为保持。V1解析器、V2协议和购买绑定仍各自独立。
FFI保留文档解析与原签名，LoginActionV2Request及PayActionResult从原模块路径重导出；
原core算法、FFI DTO和生成绑定不变。未补购买模板能力，不涉及音频/TTS、schema、版本或依赖。
状态与证据仅维护于Active计划。

编写者：Codex｜2026-10-18


### 书源事件回调（2026-10-18）

`SourceActionService`的callback模块承接书籍/书源/可选章节查询、JS执行、动作收集及返回门控。
调用时显式借用所属TaskGroup，沿用先登记任务、再查询数据的顺序；JS执行不持数据库连接。
缺源、监听关闭和空脚本仍按原路径返回invoked=false，不额外改变提前返回的取消语义。

回调复用书源动作已有的独立VM构造及JSON到JS值转换，保持event/book/chapter/result绑定，
章节缺失绑定null，空字符串result与null区分；原来源tag、实例网络能力和动作顺序不变。
仅原JS成功后的with_active门控负责拒绝迟到返回，脚本错误仍上抛，工作真正结束才释放凭据。
取消不会中止同步HTTP，也不能撤销已执行的网络或登录副作用；UI动作仅随有效结果回放。

FFI仅装配宿主服务及任务组，保留原签名和暂未分流的book_type参数，SourceCallBackBtnResult
从原API路径重导出，DTO映射和FRB绑定不变。不为登录/购买新增任务或取消策略，
不涉及音频/TTS播放逻辑、数据库、UI、版本或依赖。状态与验证证据仅维护于Active计划。

编写者：Codex｜2026-10-18
