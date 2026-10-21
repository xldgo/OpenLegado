# 双轨协作开发规范（UI 轨与 Rust 轨）

**日期**: 2026-10-19
**版本**: v1.4
**维护人**: Legado 开发团队

> 本文只规定 Rust/Flutter 双轨边界、Mock 与 FFI/codegen/native 构建专项步骤。通用任务优先级、Agent 派发、当前分支策略、常规验证、证据和关闭流程统一见 [REFACTORING_WORKFLOW.md](REFACTORING_WORKFLOW.md)、根目录 [AGENTS.md](../AGENTS.md) 与[通用开发规范](DEVELOPMENT_CONVENTIONS.md)；视觉目标见 [SCREEN_1TO1_PARITY_SPEC_20260914.md](SCREEN_1TO1_PARITY_SPEC_20260914.md)。

> **内容边界**：本文只写「怎么做」——边界、规则、流程、命令。
> 「为什么这样规定」见 [TWO_TRACK_DEV_RATIONALE.md](TWO_TRACK_DEV_RATIONALE.md)（章节号与本文对应）；
> Rust 服务边界的逐批变更记录见 [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md)。

测试清理、正常框架时序与特殊处理的判定，遵循
[通用开发规范](DEVELOPMENT_CONVENTIONS.md)「测试与生产职责分离与最小必要处理」；
双轨实现均不得仅为满足测试结束检查而改变生产业务规则或资源释放语义。

---

## 1. 适用范围

- 本文规定双轨的**文件边界、FFI/codegen 铁律、契约变更流程、Mock 工作流、分支与集成步骤**。
- 背景、动机与原理见 [TWO_TRACK_DEV_RATIONALE.md §1](TWO_TRACK_DEV_RATIONALE.md)；不在本文展开。

---

## 2. 轨道划分与工作范围

### 2.1 目录级边界表

#### (1) `flutter_legado/lib/src/` 全量归属表

| 目录 / 文件 | 规模 | bridge 引用 | 归属 | 说明 |
|---|---|---|---|---|
| `app/` | 13 | 0 | **UI 轨** | 应用装配与 bootstrap |
| `features/` | 295 | 27 | **UI 轨** | 页面在 `features/*/presentation/`，状态在 `features/*/application/` |
| `widgets/` | 121 | 0 | **UI 轨** | 共享控件 |
| `providers/` | 55 | 0 | **UI 轨** | Riverpod DI 装配（调用的领域接口变更走 §4 契约流程） |
| `theme/` | 8 | 0 | **UI 轨** | 主题 |
| `utils/` | 21 | 0 | **UI 轨** | 工具 |
| `l10n/` | 5 | 0 | **UI 轨** | 多语言资源 |
| `models/` | 40 | **0** | **共享，默认 UI 轨** | 纯 Dart 共享实体；若被 `domain/` 引用则需契约评审 |
| `platform/` | 9 | 0 | **UI 轨** | 平台能力适配，无 bridge 依赖 |
| `constants/` | 1 | 0 | **UI 轨** | `pref_keys.dart` |
| `services/` | 35 | **1** | **共享，按内容分** | 平台/媒体类 → UI 轨；含 bridge 引用或业务逻辑者需契约评审 |
| `routes.dart` | 1 | 0 | **UI 轨（全局，改前须知会）** | 被 46 个文件反向引用，改动需独占批次 |
| `domain/` | 175 | **0** | **Rust 轨** | 领域契约层 |
| `data/` | 201 | 有 | **Rust 轨** | `rust_*` / `mock_*` 适配器 |
| `bridge/` | 23 | — | **Rust 轨（UI 轨禁区）** | FRB 生成物，见 §3.3 |
| `rust/` | 1（空壳） | 0 | **Rust 轨** | 仅 `.gitkeep.dart` 占位，待清理 |

#### (2) 轨道权限

| 轨道 | 允许修改 | 禁止修改 |
|------|----------|----------|
| **UI 轨** | `flutter_legado/lib/src/{app,features,widgets,providers,theme,utils,l10n,models,platform,constants}`、`routes.dart`（改前知会）、`flutter_legado/test/` | `rust/`、`bridge/`、`domain/`、`data/`（未经 §4 契约流程确认的变更）、`frb_generated*`、`pubspec.yaml` 原生依赖段 |
| **Rust 轨** | `rust/`、经确认的 `domain/contracts/` 契约和 `data/` 适配器、`bridge/`、`lib/src/rust/`、codegen 产物（`frb_generated.dart` / `frb_generated.rs`） | `flutter_legado/lib/src/{features,widgets,theme,providers,l10n,platform}`（UI 层） |

#### (3) 共享目录的判定规则

`models/` 与 `services/` 属共享目录，按以下规则判定归属，不确定时**按 Rust 轨处理并走契约评审**：

1. 文件含 `bridge/ffi` 或 `frb` 引用 → **Rust 轨**
2. 文件被 `domain/contracts/` 引用，或定义了跨轨传递的数据结构 → **Rust 轨**，且须按 §4 登记
3. 其余纯 Dart、仅在 UI 层内流通 → **UI 轨**
4. `services/` 中属于平台/媒体/通知等原生能力适配者 → **UI 轨**，但不得直接引用 `bridge/`，
   须经 `domain/contracts/` 契约访问（当前 `lib/src/services/` 存在 1 处 bridge 引用，属历史遗留，改动前须评审）

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

FRB Dart runtime、Rust runtime 与 codegen 当前精确配对为 **2.13.0**
（已核对：`flutter_legado/pubspec.yaml` = `2.13.0`，`rust/legado-ffi/Cargo.toml` = `=2.13.0`）。
生成入口从 `pubspec.yaml` 读取版本并检查已安装 codegen。

> codegen 之后走 Python 构建入口（见 §3.4），它会完成编译、复制与严格校验。
> 等价底层命令仅供排障参考，不作为交付路径：
> `cargo build --locked --manifest-path rust/Cargo.toml -p legado-ffi --features quickjs`。
> 不以此命令交付的原因见 [rationale §3.1](TWO_TRACK_DEV_RATIONALE.md)。

Flutter 为 3.47.7，包声明的 Dart 最低版本为 3.13；环境检查须核对实际版本，
不依赖开发者个人的 FVM 配置。

### 3.2 构建配对检查

Android Gradle 调用 Python 只读校验器，检查契约、源码与工具指纹、ABI/profile/features、
元数据和实际库摘要；失配则构建失败。content hash 的原理与失配后果见
[rationale §3.2](TWO_TRACK_DEV_RATIONALE.md)。

| 入口 | 行为 |
|------|------|
| `flutter build apk` / Gradle variant `preBuild` | 对应 Debug/Release/Profile 的任务执行 Python 严格只读校验；失配则构建失败 |
| `python scripts/dev.py build ffi android ...` | 独立编译、复制并生成 v2 元数据；失败不降级或复用旧库 |
| `python scripts/dev.py build android ...` | 编译 FFI、严格校验、打包并检查 APK；安装启动需显式选择设备 |
| `scripts/emulator_smoke_test.ps1` | 保留设备 QA，构建调用 Python；Debug APK 与 Rust Debug 配对 |
| `python scripts/dev.py collect apk android ...` | 校验已有分 ABI APK 与 Cargo/jniLibs 来源，全部通过后收集；不重新编译或安装 |
| 本地纯 Dart UI 开发（**仅 Android**） | 仅 Debug，同时显式 `USE_MOCK=true` 和 `LEGADO_SKIP_RUST_BUILD=1` 才可跳过 |
| Release/Profile/CI | 禁止通过跳过变量绕过校验 |

> **v1.3 澄清（`LEGADO_SKIP_RUST_BUILD`）**：该变量**只对 Android 构建生效**，且是**环境变量**
> 而非 `--dart-define`。读取点仅两处：`flutter_legado/android/ffi-verification.gradle.kts:57`
> 与 `scripts/tooling/android_app.py:204`（后者对真实 APK 编排直接拒绝该变量）。
> **Windows / iOS / macOS 的 Mock 开发不涉及此变量**，只需 `USE_MOCK=true`（见 §5.1）。
> 桌面端跳过 Rust 编译的方式是直接使用 Mock 模式运行，不存在对应的跳过开关。

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
- CMake 负责复制对应 profile 的 DLL；Python 传入当前 Cargo 输出目录并复核最终复制摘要，不跨模式回退（机制见 [rationale §3.6](TWO_TRACK_DEV_RATIONALE.md)）。旧 Windows/生成脚本及 Makefile 已删除，不再作为入口；详见 [Windows 工具说明](PYTHON_WINDOWS_TOOLING_20261011.md)。
- DLL 被运行进程锁定时提示用户手动关闭应用，生成器和构建入口均不强制终止进程。
- iOS 正式静态库由 `python scripts/dev.py build ffi ios --target device --profile release` 编译，模拟器使用 `--target simulator`；保留 CocoaPods `RustFFI` 的 `-force_load`。最终应用的 PDE 符号由同一 Python 入口检查；模拟器兼顾 `Runner.debug.dylib`。元数据与平台边界见 [iOS 工具说明](PYTHON_IOS_TOOLING_20261011.md)，历史 XCFramework 不接入本流程。

Android应用和插件使用AGP内置Kotlin（`android.builtInKotlin=true`），模块不再显式应用
`kotlin-android`。`settings.gradle.kts`保留2.4.21的`apply false`声明以固定编译器类路径，
不能直接删除，否则当前AGP默认解析的2.2.10低于Flutter下限；该声明本身不应用旧插件。
`android.newDsl=false`仍保留，内置Kotlin和新Android DSL分开迁移，Java/Kotlin目标仍为17。
`flutter_tts`使用nguyen703维护的4.2.5构建补丁，固定Git提交
`f6af434f7016c7b1f4709f4f8f421543abc08635`；官方发布迁移版后另批评估切回，
不修改Pub缓存中的插件代码。升级后用正式Android入口构建并检查原有KGP迁移告警是否消失。

编写者：Codex + Tool｜2026-10-20

### 3.5 frb 构件配对纪律（评审 W2 登记，持久约束）

两侧生成物（Dart 侧 `bridge/ffi/ffi.dart` 等 + Rust 侧 `frb_generated.rs` + 编译产物
`.dll`/`.so`）必须满足：

1. **原子重建**：任何 FFI 面变更后，「codegen 生成 → cargo 重编译 → 替换运行环境
   .dll/.so」必须作为一个原子操作整体完成（原 Makefile `gen` 目标已随 Makefile 归档废止，见 docs/过期文档/Makefile；Windows 环境无 make，以 codegen 脚本为准），
   不允许只重生成 Dart 不重编 Rust，或只替换二进制不更新生成物。
2. **禁止混配**：不同 codegen 批次产出的 Dart 生成物与 .dll/.so 严禁混搭运行
   （例如新 Dart 绑定配旧 .so）。混配会让 Dart 调用被分派到**另一个 Rust 函数**，
   后果是崩溃或静默数据错乱（原理见 [rationale §3.4](TWO_TRACK_DEV_RATIONALE.md)）。
3. **content hash 双向抽查**：每次重配后用 `FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH`
   校验两侧一致——Dart 侧启动报错信息中的 hash 与 Rust 编译时嵌入的 hash
   必须相同；交付/验收 APK 前先抽查两侧 hash，发现不一致一律整套重建而非局部修补。
4. **生成文件零手改**：`bridge/` 目录及 `frb_generated.*` 均为 codegen 产物，
   任何手写注释/警示都会被下次 codegen 抹除；需要持久化的约束一律写入本文档。

### 3.6 Rust 服务装配约束（通用）

> 逐批服务边界与保留行为见 [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md)；
> 本节只列仍有效的通用约束，取自历次批次反复出现的同一要求。

1. **显式接收所属资源**：服务只接收宿主在入口一次性捕获的 `StorageContext` /
   `NetworkContext` / `JsResources` / 宿主 Handle 等窄能力；不反向持有根 `EngineContext`，
   不自建或拥有 Tokio Runtime，不在执行中回查 FFI 全局槽或当前宿主实例。
2. **运行时与监听状态归宿主所有**：服务只借用 Handle；直接调用方须保证传入的 Runtime 存活，
   服务不承担调度器所有权。
3. **数据库在宿主闭包内借还连接**：不跨 `await` 持有连接，不自行获取第二条连接，
   不在 `Drop` 中隐式刷新。
4. **未改契约的批次也要重建 native**：未改 FRB 签名 / DTO / 生成绑定 / schema / 依赖版本的批次，
   真实 Flutter 应用使用前仍须重建对应 native 产物；Rust 单测不替代设备验收。
5. **收口不扩权**：迁移或收口批次不得顺带新增取消、限流、事务、重试、登录回调或用户可见行为；
   确有需要另立批次并在 Active 计划登记。

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
不新增全能根接口，能力一律按领域契约注册；`test/fixtures/` 的组合夹具只服务现有测试，
应用代码不得引用（全能根接口的移除背景见 [rationale §4](TWO_TRACK_DEV_RATIONALE.md)）。

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

**Flutter 排版测试的本地准备**：先按 §3.4 构建对应平台的 native 库（Windows 用
`python scripts/dev.py build ffi windows --profile debug`；Linux/macOS 用
`cargo build --locked --manifest-path rust/Cargo.toml -p legado-ffi --features quickjs`），
再运行测试。默认从当前工作树 `rust/target/debug/` 加载 DLL/so/dylib；复用其他 Cargo
目录时，将 `LEGADO_TEST_FFI_LIBRARY` 设为实际原生库绝对路径。绑定与原生库必须来自同一契约。

需要真实分页的 Widget 测试使用 `pumpNativeReaderLayout` / `settleNativeReaderLayout`
交替等待真实 I/O 和推进测试帧，不要只用 `pumpAndSettle`；普通组件测试继续使用固定布局输入，
不要求原生库。机制、注意事项与旧链路退役原因见 [rationale §5](TWO_TRACK_DEV_RATIONALE.md)。

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
| [TWO_TRACK_DEV_RATIONALE.md](TWO_TRACK_DEV_RATIONALE.md) | 本文的背景与原理说明（为什么这样规定），章节号与本文对应 |
| [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md) | Rust 服务边界逐批变更记录（记录性，不构成新约束） |
| [VERSION_CONTROL.md](VERSION_CONTROL.md) | 版本记录，集成里程碑在此登记 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | 开发者指南，含构建与运行说明 |

### 8.2 生效与修订

- **生效日期**：2026-08-01；流程边界修订：2026-09-27
- **版本沿革**：v1.2（2026-10-16）→ v1.3（2026-10-18，边界口径订正）→ v1.4（2026-10-19，
  按"本文只写怎么做"原则剥离背景原理与逐批批次记录，**边界与流程口径未变**）
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

**最后更新**: 2026-10-19
**维护者**: Legado 开发团队

### 文档结构调整（v1.4，2026-10-19）

**依据**：用户要求"规范只写怎么做，为什么这么做移到专门的说明文档"。
本次只做结构性拆分，**边界、规则与流程口径与 v1.3 完全一致**。

| 动作 | 内容 |
|---|---|
| 移出 | §1 背景与目标、§3.2 content hash 原理、§3.5 生成文件手改史、§4 全能根接口移除史、§7.2 排版测试机制说明 → [TWO_TRACK_DEV_RATIONALE.md](TWO_TRACK_DEV_RATIONALE.md) |
| 移出 | 文末 17 条「应用服务边界」批次记录（原第 353–776 行，约 424 行）→ [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md)，原文与署名不变 |
| 新增 | §3.6「Rust 服务装配约束（通用）」：从上述批次记录中提炼的 5 条仍有效约束，避免纪律随记录迁出而丢失 |
| 保留 | §2 边界表与判定规则、§3.1–§3.5 铁律、§4 契约流程（含外部引用的 §4.3）、§5、§6、§7.2 编号与标题（外部锚点引用）、§8 附则 |

章节编号保持 §1–§8 不变：`API_CONTRACT.md` 对 §4 / §4.3 的引用，
以及 `READER_LAYOUT_REFERENCE_20261012.md` 对 §7.2 的锚点引用，均不受影响。

— 主代理，2026-10-19
