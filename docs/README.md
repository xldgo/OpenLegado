# 项目文档索引

本文件夹统一存放 Legado 项目根目录的过程、报告、交接、分析与规范类文档。

> 说明：`README.md`、`CHANGELOG.md`、`LICENSE` 按社区惯例保留在项目根目录；`rust/`、`flutter_legado/` 等子项目内部文档仍保留在各自目录下。

## 重构状态与流程

- 当前待办、待核验和合并验收清单：只查看 [REFACTORING_ACTIVE_PLAN.md](REFACTORING_ACTIVE_PLAN.md)；已完成批次通过Git历史与专题证据追溯。
- Rust 资源归属、生命周期和双宿主接线方案：[RUST_ENGINE_CONTEXT_PLAN_20261016.md](RUST_ENGINE_CONTEXT_PLAN_20261016.md)；进度仍只维护于 Active。
- 页面职责拆分与 Feature-first 批次边界：[FEATURE_FIRST_PAGE_DECOMPOSITION_20261017.md](FEATURE_FIRST_PAGE_DECOMPOSITION_20261017.md)；进度仍只维护于 Active。
- 功能私有组件归位与阅读服务分层：[FEATURE_OWNERSHIP_MIGRATION_20261022.md](FEATURE_OWNERSHIP_MIGRATION_20261022.md)；进度仍只维护于 Active。
- FFI 强类型、字节传输、类型化流和句柄改造建议：[FFI_TRANSPORT_MODERNIZATION_20261017.md](FFI_TRANSPORT_MODERNIZATION_20261017.md)；进度仍只维护于 Active。
- Agent 派发、实施、验证、证据和关闭：遵循 [REFACTORING_WORKFLOW.md](REFACTORING_WORKFLOW.md)。
- 通用开发规范（优先级分类、验证流程、Git 提交规范、Windows 编码）：[DEVELOPMENT_CONVENTIONS.md](DEVELOPMENT_CONVENTIONS.md)。
- 本文件不维护测试数字、分支负责人或第二份阶段状态，避免旧基线被误认为当前结果。

## 基准口径

- 功能与行为核对见 [重构工作流](REFACTORING_WORKFLOW.md)，UI目标与验收见 [设计系统](design_system.md)；本索引不另立比对口径。
- 历史截图目录（`baseline_android/`、`baseline_flutter/`、`baseline_reference/`、`parity_shots/` 等）所载采集日期、工具与模拟器信息为**历史取证事实，不代表当前设备状态**。
- 当前设备任务必须以执行前实时探测为准（MuMu/官方模拟器在线实例、ADB 端点、网络与应用变体）；不把文档中的固定端口或旧设备可用记录当作当前保证。

## 📑 现行文档目录

### 1. 计划与执行规范

| 文档 | 说明 |
| --- | --- |
| [REFACTORING_ACTIVE_PLAN.md](REFACTORING_ACTIVE_PLAN.md) | 当前唯一后续重构执行计划与开放项台账 |
| [REFACTORING_WORKFLOW.md](REFACTORING_WORKFLOW.md) | Agent 派发、实施、验证与关闭的统一流程规范 |
| [DEVELOPMENT_CONVENTIONS.md](DEVELOPMENT_CONVENTIONS.md) | 通用开发规范（优先级分类、验证流程、Git 提交规范） |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Legado 开发指南（版本发布、标签及分支流程） |
| [VERSION_CONTROL.md](VERSION_CONTROL.md) | 项目版本控制与发布流程记录 |

### 2. 核心架构与 API 契约

| 文档 | 说明 |
| --- | --- |
| [API_CONTRACT.md](API_CONTRACT.md) | BookApi 接口契约文档（UI 轨与 Rust 轨唯一接口基准） |
| [SOURCE_JS_PARITY_AUDIT_20261022.md](SOURCE_JS_PARITY_AUDIT_20261022.md) | 固定原版/参考版快照下的书源JS行为审计、已复现差异及修复建议 |
| [TWO_TRACK_DEV_SPEC.md](TWO_TRACK_DEV_SPEC.md) | 双轨协作开发规范（UI 轨与 Rust 轨分离开发及边界），只写做法 |
| [TWO_TRACK_DEV_RATIONALE.md](TWO_TRACK_DEV_RATIONALE.md) | 双轨规范背景与原理说明（为什么这样规定），章节号与规范对应 |
| [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md) | Rust 服务边界逐批变更记录（记录性文档，不构成新约束） |
| [SETTINGS_ARCHITECTURE.md](SETTINGS_ARCHITECTURE.md) | 设置业务分类、存储与状态边界、逐项清单规范及迁移顺序 |
| [UI_THEME_ARCHITECTURE.md](UI_THEME_ARCHITECTURE.md) | 主题、调色板与配色架构规范 |
| [FLUTTER_DATA_BOUNDARIES.md](FLUTTER_DATA_BOUNDARIES.md) | Flutter 初始化职责与数据访问渐进拆分方案 |
| [AUDIO_PLAYER_UNIFICATION.md](AUDIO_PLAYER_UNIFICATION.md) | 正文朗读、音频书和试听统一 just_audio 的边界与验收方案 |
| [TTS_ALIGNMENT.md](TTS_ALIGNMENT.md) | 原版 TTS 行为与播放队列对齐规范 |
| [api.md](api.md) | 阅读 Web API 说明及 Android 原版参考 |

### 3. 视觉、排版与比对基准

| 文档 | 说明 |
| --- | --- |
| [design_system.md](design_system.md) | Legado 设计系统与组件设计规范 |
| [READING_FLOW_DEFECT_HUNT_PLAN_20260924.md](READING_FLOW_DEFECT_HUNT_PLAN_20260924.md) | 阅读主流程缺陷发现与取证方法 |
| [READER_LAYOUT_CONTRACT_20261012.md](READER_LAYOUT_CONTRACT_20261012.md) | 排版渲染核心契约 |
| [READER_LAYOUT_PROFILE_20261012.md](READER_LAYOUT_PROFILE_20261012.md) | 阅读排版性能剖析与基线测试规范 |
| [READER_LAYOUT_REFERENCE_20261012.md](READER_LAYOUT_REFERENCE_20261012.md) | 阅读器排版参考基准说明 |
| [LOCALIZATION.md](LOCALIZATION.md) | 多语言与本地化规范 |

### 4. 工程工具链、CI 与平台接线

| 文档 | 说明 |
| --- | --- |
| [CI_ORCHESTRATION_20261010.md](CI_ORCHESTRATION_20261010.md) | CI 编排说明（工具回归、任务触发与手动轻量验证） |
| [IOS_CI_SIGNING_SETUP.md](IOS_CI_SIGNING_SETUP.md) | iOS Build 签名与 IPA 交付；手动 iOS CI、诊断入口与排障 |
| [PYTHON_FFI_BUILD_20261011.md](PYTHON_FFI_BUILD_20261011.md) | Python FFI 构建入口与生成规范 |
| [PYTHON_GRADLE_FFI_20261011.md](PYTHON_GRADLE_FFI_20261011.md) | Gradle 只读门禁与解释器配置接线说明 |
| [PYTHON_WINDOWS_TOOLING_20261011.md](PYTHON_WINDOWS_TOOLING_20261011.md) | Windows 构建与运行工具说明 |
| [PYTHON_IOS_TOOLING_20261011.md](PYTHON_IOS_TOOLING_20261011.md) | iOS 正式静态库构建、来源元数据与应用 PDE 校验 |
| [SKILLS_MAINTENANCE.md](SKILLS_MAINTENANCE.md) | Agent Skills 维护说明与更新方法 |

---

## 🗄️ 历史与过期文档归档

所有已交付结束的历史批次材料（含已结项专项计划、阶段性审计报告、单次技术调研、Code Review 结论等）已统一归档至 **[docs/过期文档/](过期文档/README.md)**，仅供追溯与参考，不再作为当前开发依据。

- [过期文档索引与替代关系](过期文档/README.md)
- 已废止的[一比一规范](SCREEN_1TO1_PARITY_SPEC_20260914.md)、[视觉台账](SCREEN_1TO1_PARITY_LEDGER_20260914.md)与[深色台账](DARK_THEME_PARITY_LEDGER_20260920.md)保留原路径供旧引用追溯，不属于现行规范或待办来源。

---

## 📁 文档存放规范

为维护项目根目录整洁，特制定以下文档存放规范：

1. **统一存放位置**：后续所有新建的计划、报告、交接、分析类 `.md` 文档必须创建在 `docs/` 文件夹内，**不允许散落在项目根目录**。
2. **子项目文档**：`rust/`、`flutter_legado/` 等子项目内部文档保留在各自子项目目录下。
3. **根目录例外**：`README.md`、`CHANGELOG.md`、`LICENSE` 按社区惯例保留在项目根目录。
4. **引用路径**：跨目录引用文档时使用正确的相对路径（如 `docs/` 内文档引用 `rust/` 下文档应写为 `../rust/xxx.md`）。
5. **及时归档**：阶段性任务结项或被新方案取代后，应及时将历史过程报告移动至 `docs/过期文档/`，保持主目录仅保留当前有效事实与规范。

修订者：Codex｜2026-10-24（更新现行UI验收入口，旧视觉比对材料只作历史追溯）
