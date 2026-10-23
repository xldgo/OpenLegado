# AGENTS.md

本文件为编码 agent 提供进入 Legado 代码库的统一入口：模块地图、验证命令与规范路由。
项目概览详见 [README.md](README.md)。

## 项目概览

Legado：Rust + Flutter 跨平台阅读器，参考上游(HapeLee/legado-with-MD3)实现的阅读应用。

## 模块地图

| 路径 | 内容 |
|---|---|
| `flutter_legado/` | Flutter UI（Windows 构建主模块），`lib/` 为 Dart 源码 |
| `rust/` | Rust 工作区（legado-book / legado-core / legado-db / legado-engine / legado-fetcher / legado-ffi / legado-js / legado-layout / legado-net / legado-parser / legado-server） |
| `docs/` | 项目文档（计划、报告、规范、API 契约） |

## 验证命令

- **Android 原版单元测试**：仅在另备的完整原版工程根目录执行 `.\gradlew.bat :app:testAppReleaseUnitTest`。本仓库不包含原版源码或其 Gradle 构建入口；旧 `test.yml` 已移除。
- **Flutter**：SDK 3.47.7；在 `flutter_legado/` 下 `flutter analyze && flutter test`（CI：`.github/workflows/flutter-ci.yml`）
- **Flutter 测试分组**：普通测试 `flutter test --exclude-tags native`；真实FFI及分页集成测试 `flutter test --tags native`，先在 `rust/` 构建 `cargo build --locked -p legado-ffi --features quickjs`。宿主库可通过 `LEGADO_TEST_FFI_LIBRARY` 显式指定；缺库报错，不按 Windows 限制跳过。CI 分层见 [CI 编排说明](docs/CI_ORCHESTRATION_20261010.md)。
- **Rust**：在 `rust/` 下 `cargo test`（CI：`.github/workflows/rust-ci.yml`）
- **iOS**：`ios-ci.yml` 仅手动运行模拟器验证，不作为 PR 必需检查；`ios-build.yml` 保留设备 IPA 自动构建与手动入口。签名及诊断方法见 `docs/IOS_CI_SIGNING_SETUP.md`。
- **CI 总览**：`.github/workflows/`（tooling-ci / rust-ci / flutter-ci / ios-ci / ios-build / release；仓库自动化保持独立）
- **Python 工程工具**：Python 3.11+；根目录 `python scripts/dev.py test tooling`。生成与 Android FFI 编译见 [构建入口](docs/PYTHON_FFI_BUILD_20261011.md)，Gradle 只读门禁与解释器配置见 [Gradle 接线](docs/PYTHON_GRADLE_FFI_20261011.md)。Android APK 参数见 [Android 入口](docs/过期文档/PYTHON_ANDROID_CLEANUP_20261011.md)；Windows 使用 `python scripts/dev.py build windows --profile debug` 和 `python scripts/dev.py run windows --profile debug`，参数见 [Windows 入口](docs/PYTHON_WINDOWS_TOOLING_20261011.md)。iOS 正式 RustFFI 构建与 PDE 校验见 [iOS 入口](docs/PYTHON_IOS_TOOLING_20261011.md)，需要 macOS/Xcode。旧 Android/Windows/生成脚本与 Makefile 已删除；历史 iOS XCFramework 和设备 QA 保留各自独有能力。
- **MuMu快捷安装**：在仓库根目录执行 `python scripts/dev.py build android --emulator mumu --install`；通过MuMuManager动态查询已启动实例并自动连接ADB，已在线则复用，不自动启动模拟器或重启ADB服务；从PATH或Windows安装信息定位管理工具，找不到时仍可使用已连接实例。固定x86_64独立Debug APK，Rust库校验通过自动复用，否则重建；默认MainActivity启动并检查进程和异常。多个运行实例追加 `--device <设备编号>`，不写死端口，连接超时10秒；日志按次覆盖 `build/mumu/build-install.log`。不替代下述官方模拟器的UI/播放专项冒烟。
- **CI 编排**：工具与编排回归集中在 Tooling CI；Flutter/Rust 对 dev/master push 与 PR 按改动选择任务；iOS Build 对 dev/master 的应用改动自动构建。Android/Windows 平台构建通过 Release 的手动或Tag入口验证，不再单独运行Integration Smoke。手动范围与轻量验证见 [CI 编排说明](docs/CI_ORCHESTRATION_20261010.md)。

## 规范与文档路由（改动前必读）

Skills 只维护 `.agents/skills/` 的上游原文；其他工具入口通过
`python scripts/setup_skills.py` 初始化。来源与更新方法见
[Skills 维护说明](docs/SKILLS_MAINTENANCE.md)，项目特有约束以本文件和设计系统为准。

1. [docs/DEVELOPMENT_CONVENTIONS.md](docs/DEVELOPMENT_CONVENTIONS.md) — 项目开发规范：优先级分类（P0/P1/P2）、验证优先工作流、基准口径、Git 安全实践、Windows 编码处理、文档存放规范（自 `.qoder/rules/legado-dev-conventions.md` 迁移，2026-09-27）
2. [docs/REFACTORING_WORKFLOW.md](docs/REFACTORING_WORKFLOW.md) — 重构任务统一实施、Agent 派发、验证、证据与关闭流程
3. [docs/REFACTORING_ACTIVE_PLAN.md](docs/REFACTORING_ACTIVE_PLAN.md) — 当前唯一开放任务与进度状态入口
4. [docs/API_CONTRACT.md](docs/API_CONTRACT.md) — FFI API 契约（跨轨变更必须先更新并冻结契约）
5. [docs/TWO_TRACK_DEV_SPEC.md](docs/TWO_TRACK_DEV_SPEC.md) — Rust/Flutter 双轨边界、Mock 与 FRB/native 构建专项说明
6. [docs/SCREEN_1TO1_PARITY_SPEC_20260914.md](docs/SCREEN_1TO1_PARITY_SPEC_20260914.md) — 参考版视觉比对规范；状态回写 Active 计划
7. [docs/READING_FLOW_DEFECT_HUNT_PLAN_20260924.md](docs/READING_FLOW_DEFECT_HUNT_PLAN_20260924.md) — 阅读主流程缺陷发现/取证专项流程
8. [docs/design_system.md](docs/design_system.md) — 设计系统
9. [docs/SCREEN_1TO1_PARITY_LEDGER_20260914.md](docs/SCREEN_1TO1_PARITY_LEDGER_20260914.md) — 一比一视觉比对台账（完成状态回写 Active 计划）

> 历史计划与已结束批次材料（含 UI_FIX_PLAN.md 等 UI 批次材料）一律在 `docs/过期文档/`，仅作追溯，不作为当前需求或验收标准。

## 关键约束

- **原版/参考版对齐**：参考版是当前用户可见行为和视觉目标；按参考版核对布局、交互、结果、配色、字体和明暗主题。Android 原版用于语义交叉核对。若参考版与 Android 原版或用户已确认规则出现实质用户可见差异，暂停该项并向用户提供证据和选项，未经裁决不得自行选择。Rust + Flutter 内部架构保持现状，除非用户另行批准架构调整。详细流程见 `docs/REFACTORING_WORKFLOW.md`，逐屏方法见 `docs/SCREEN_1TO1_PARITY_SPEC_20260914.md`。
- **FFI 变更**：修改 Rust/Dart FFI 边界前，先更新 `docs/API_CONTRACT.md` 契约，再实施代码；跨轨阻塞项须 Rust 轨先行交付契约；契约修改需相关轨道负责人确认；Mock 数据使用从原 Android 应用抓取的真实 JSON
- **重构红线**：本项目为重构项目，**未经允许禁止新增 Android 原版不存在的功能**（用户明确授权的除外，如 LargeTitle 大标题、颜文字空态彩蛋、阅读热力图、AI 摘要改写/角色卡 Characters/相关书 RelatedBooks（2026-09-05 授权，记录正本见 `docs/过期文档/UI_ONE_TO_ONE_CLONE_PLAN_20260905.md` §〇）等，授权记录见提交与文档）；发现未授权的偏离项（如推荐算法等）必须清理，一切以不偏离重构核心为目标（2026-08-29 用户修订授权口径）
- **执行边界**：不得超范围删除或修改文件，删除/修改代码前必须先确认范围无误
- **保护逻辑与测试的场景依据**：新增防御分支、状态快照、锁、重试或专项测试前，先核对真实入口、交互约束、异步/平台事件及既有机制，说明可达触发路径和需要保障的行为。不能仅凭“理论上可能”增加处理，也不能通过测试直接篡改内部状态构造产品不可达场景。界面互斥不等于异步事件互斥；必要的生命周期和外部输入校验仍应保留。详见开发规范“场景可达性与保护成本”。（用户约定，2026-10-22）
- **开发阶段的旧偏好键处理**：废弃或重命名设置键时，按旧键不存在处理，直接移除旧键及其读写、模型、界面和备份分类引用。不主动清洗本地旧值，不增加旧键迁移、兼容读取、双写、专用备份过滤或相关兼容测试；用户明确要求兼容时再单独实施。本条仅适用于偏好设置键，不授权删除书籍、阅读进度等业务数据。（用户约定，2026-10-20）
- **计划驱动**：所有阶段按 `docs/REFACTORING_WORKFLOW.md` 实施；唯一开放项、任务状态及进度只维护于 `docs/REFACTORING_ACTIVE_PLAN.md`。专题文档只保存方法和证据，不另设状态源；历史计划不得重新作为当前任务来源。
- **UI 层职责边界**：UI 层只做界面渲染、交互与状态管理，不含业务逻辑；数据经 Rust Bridge 获取；遵循 UI 层与底层分离原则
- **文档存放**：新建计划/报告/交接类 `.md` 必须放 `docs/`；根目录仅保留 README.md、CHANGELOG.md、LICENSE、AGENTS.md 等约定文件
- **全中文规范**：汇报、代码注释全部使用中文；commit 描述/正文使用中文（类型/作用域按约定式提交用英文小写）
- **l10n 范围**：维持中文主语言；多语言资源与术语参考上游，逐步补齐应用文案及语言切换行为。

## Git 纪律与版本控制

- 每次改动验证通过后立即 commit 到本地；阶段性成果须 commit 并 push
- **提交信息必须遵循约定式提交（Conventional Commits）**：`<类型>[作用域]: <中文描述>`，类型用 `fix`/`feat`/`docs`/`refactor`/`test`/`chore` 等英文小写，作用域用 `ui`/`rust`/`tool`（替代旧式 `[UI]`/`[Rust]`/`[Tool]` 前缀，如 `fix(ui): ...`、`fix(rust): ...`）；`fix` 必须在正文说明根因、脚注关联 `Fixes #编号`；描述 ≤72 字符、正文行 ≤100 字符、不得混用类型、不得用模糊描述；详细规则见项目开发规范文件「Git 提交规范」章节
- 分支策略：`feature/rust-*` 与 `feature/ui-*` 独立开发，集成使用 `integration/*` 分支；仅从当前 HEAD 创建规范分支，不得改动已提交历史
- 署名规范：UI 层代码署名「— 子代理名称 + UI」，Bridge 层代码署名「— 子代理名称 + Bridge」，文档末尾附编写者署名与日期
- 批次修复按 pubspec 版本 patch 递增（如 2.0.0+2 → 2.0.1+3），每批同步更新 CHANGELOG 与应用内更新日志 `flutter_legado/assets/updateLog.md`（关于页展示，仅记录用户可见变化，按日期条目格式），记录版本号与贡献者；版本号记录于 CHANGELOG，commit subject 不带版本号
- 进度文档（docs/ 下）须与 git 提交记录保持同步，任务编号不得重叠

## 验证与交付流程

- **本地测试范围**：只运行本次改动直接影响的定向测试及必要的调用方回归，按测试文件、用例过滤或 crate 内测试过滤选择；不得默认运行全量 Flutter/Rust 测试或无关平台构建。只有定向失败表明影响扩大，或用户明确要求时才扩大范围，并说明原因。全量门禁交由既有 CI；已通过的检查不重复运行，除非代码再次修改或出现新的失败证据。（用户约定，2026-10-22）
- **UI测试价值**：优先验证交互、状态、结果与无障碍，不为颜色、字号、圆角、间距或组件默认值逐参数编写测试。可逆且低影响的样式调整不默认新增专项用例；既有用例中的机械样式断言应清理。明确缺陷的溢出、遮挡、命中、安全区及排版回归仍可验证几何关系，优先断言可用性而非锁死像素常量；已有行为覆盖时不重复添加。（用户约定，2026-10-22）
- **不逐页重复通用组件测试**：页面沿用通用开关、按钮、输入框、Sheet或提示组件时，不为每个设置重复验证点击、回调、禁用、关闭、文字显示或参数透传；原生/第三方组件自身行为不另测。项目封装新增的交互、语义或命中规则只在组件层保留必要覆盖，页面测试只验证实际新增的业务接线与用户结果；保存、错误处理等已有下层覆盖时，不再新增同义页面用例。清理时保留页面独有导航、副作用顺序、平台差异及真实缺陷回归，不把所有Widget测试一概删除。（用户约定，2026-10-24）
- 每轮修复后的两级验证：子代理先在**测试档模拟器**测试，测试通过后再安装到**用户验收档**通知用户实测验收
- **模拟器验证档（官方 Android SDK 模拟器 `Legado_API_36`）**：
  - **AVD 与系统镜像**：`Legado_API_36`，使用 `system-images/android-36/google_apis/x86_64`（Android 16 / API 36，userdebug 构建）；持久配置 `1080×1920`、`480 dpi`（逻辑尺寸 `360×640 dp`，与 `docs/parity_shots/` 历史基准对齐，无需每次 `wm` 覆盖）；ABI 支持 `x86_64,arm64-v8a`（含内置 `ndk_translation`）。
  - **工具与启停（使用新版 Android CLI，弃用 `sdkmanager`）**：
    - `android.exe`：`$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe`
    - `adb.exe`：`$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`
    - 启动：`& $android emulator start Legado_API_36`（阻塞至完全启动就绪后返回）；停止：`& $android emulator stop Legado_API_36`。
  - **设备号探测与能力**：每次执行前必须先用 `adb devices -l` 探测在线实例，认准 `model:sdk_gphone64_x86_64`（`device:emu64xa`）对应的 `<serial>`（如 `emulator-5554` 或 `emulator-5556`），所有 `adb` 命令显式加 `-s <serial>`。原生支持 `adb -s <serial> root`、标准单屏 `exec-out screencap -p`、`uiautomator dump`、剪贴板与输入法；我方应用语义文本在 **`content-desc`**（Flutter 语义树），不在 `text` 属性；模拟器内访问宿主机 `127.0.0.1` 用 **`10.0.2.2`**（SLIRP 网络不支持 ICMP `ping`，联网检查请用 TCP/HTTP）。
  - **冒烟脚本**（构建+安装+启动+崩溃检查）：`.\scripts\emulator_smoke_test.ps1 -Device <serial>`（可加 `-CheckUI` 做书架主界面元素检查；复用 APK 加 `-SkipBuild`）；退出码 0=通过 1=失败。
  - **端点时效性（每次派单前必读）**：本节及历史文档所载设备号/端口均随实例运行状态变化；每次设备任务前必须以 `adb devices -l` 与 `android.exe emulator list` 实时探测为准，**不得假设固定端口恒可用**。历史模拟器归档见 `docs/过期文档/MUMU_EMULATOR_NOTES_ARCHIVE_20261013.md`。
- **完成定义（DoD）**：判定「完成」的依据是**证据**，不是执行步骤：
  1. 代码改动须附「多代理协作规则」路由表中对应的证据，并在提交正文写明来源（CI 运行链接 / QA 报告路径 / 审查结论 / 截图路径）；
  2. **CI 能覆盖的验证不重复派角色**（`flutter analyze && flutter test`、`cargo test` 以 CI 结果为准），角色只用于 CI 覆盖不到的场景（实机冒烟、UI 交互、跨模块手动复现）；Android 原版 Gradle 测试仅在另备的完整原版工程内运行，不属本仓库 CI 覆盖；
  3. **高风险改动**（跨模块 / FFI 契约 / 公共 API / 大范围重构）必须在提交前取得 `code-reviewer` 结论；一般小修不强制派审查；
  4. **测试有效性红线（严禁形式主义文本断言）**：严禁编写直接读取生产代码（`.dart`/`.rs`）或配置文件（`.yml`）进行字符串检索的假测试（如 `expect(src.contains(...))` 或 `assertIn(..., yml)`）；测试必须断言真实行为、状态变更或渲染树，此类“源码守卫”不构成有效 DoD 证据；
  5. 子代理自述（无独立证据）不构成验收依据。
- 汇报纪律：确认问题彻底解决后才能汇报完成，如实汇报，不得夸大进度或完成度
- 反复出现的问题必须深挖根因、永久解决，禁止临时修补；发现的重大技术风险须正式写入重构计划文档并说明原因
- 当前开发环境为 Windows，无 make 命令：给用户的命令必须是可直接执行的 CMD 或 PowerShell 命令行，不要给 Makefile 目标

## 多代理协作规则

- 无明确要求不使用子代理，如果明确要求使用，按照以下要求
- 主 Agent 职责：① 拆解并分发任务至子代理；② 推进任务，子代理卡住时主动跟进协助解困；③ 验收任务
- **子代理执行原则**：
  - **主代理只做任务分解与审核**（拆解、派发、读 diff 复核、验收判定、文档与提交），**具体执行操作全部交给子代理**（编码、取证、构建、实机验证等），主代理不自行兜底实现
  - **禁止主代理兜底子代理**：子代理失败/超时/卡住时，须先向用户说明情况并**申请同意**后方可改由主代理接手；未获同意不得自行兜底
  - **子代理并行上限 = 2**：任意时刻最多两个子代理并行（原「可大规模并行」口径按此收敛）
- **Agent 路由表**（按任务能力选择执行者；名称是项目职责标签，不绑定特定 Agent 产品的配置名）：

  | 触发条件 | 执行职责 | 执行侧 | 证据形态 |
  |---|---|---|---|
  | 代码实现/修改 | 编码 Agent | 按项目授权环境 | 提交 + 自测输出 |
  | `flutter_legado/**`、`rust/**` 的常规验证 | 不额外派发；以 CI 为准 | CI | CI 运行结果 |
  | 需实机验证 | QA Agent | 经实时探测可用的测试设备 | 脚本退出码 + 日志/截图 |
  | UI 布局/交互改动 | UI 验收 Agent | 经实时探测可用的设备 | 同条件截图与差异记录 |
  | 跨模块 / FFI 契约 / 公共 API 变更，或大范围重构 | 独立审查 Agent | 仅提供最小必要上下文 | 提交前审查结论 |
  | 有 bug 且 CI/本地复现不出根因 | 调试 Agent | 仅提供最小复现和错误信息 | 根因结论 + 最小复现 |
  | 引入新依赖 / 技术选型 / 大范围调研与依赖梳理 | 研究 Agent | 按任务需要选择 | 调研结论 + 出处 |

  - Agent 名称、产品类型和可用工具以当前执行环境为准；本表仅定义职责和证据，不维护特定产品内置角色清单。
  - 需要云端/外部审查时只发送最小 diff 或最小复现与错误栈，不发送无关源码。
  - 常规任务先判断能否派发（可自包含、上下文隔离有价值、可并行），能派则派
- 冲突避让：多个子代理同时改代码时必须避让同一文件/模块；任务分配须满足文件不重叠、工作量平均、技能匹配三项原则
- 文档维护：每阶段结束须及时检查并更新所有相关文档（重构计划、进度、README 等），保证后续开发者可顺利接手
- 口头约定正式化：主动提示用户是否需要将对话中达成的口头约定整理成清单写入规则文件
