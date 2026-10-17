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
