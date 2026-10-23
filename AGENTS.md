# AGENTS.md

本文件只提供仓库入口、必须遵守的执行边界与规范路由；详细规则以对应文档为准。
项目概览、工具链和构建安装方法见 [README.md](README.md)。

## 模块地图

| 路径 | 内容 |
|---|---|
| `flutter_legado/` | Flutter界面、状态管理及平台适配 |
| `rust/` | Rust业务、数据库、解析、网络、JS、分页及FFI工作区 |
| `docs/` | 当前规范、任务与专题证据 |

## 开始任务前

1. 读取 [开发规范](docs/DEVELOPMENT_CONVENTIONS.md)：测试范围与价值、保护逻辑、旧偏好键、Git安全、提交格式、版本/日志及文档存放规则。
2. 读取 [重构工作流](docs/REFACTORING_WORKFLOW.md)：目标与授权范围、实施步骤、设备验证、审查、证据和交付规则。
3. 核对 [Active计划](docs/REFACTORING_ACTIVE_PLAN.md)：唯一当前任务与状态入口。历史材料不作为新任务来源。

## 按改动读取

| 改动 | 必须读取 |
|---|---|
| Rust/Flutter边界、领域接口、Mock、FRB/native | [双轨规范](docs/TWO_TRACK_DEV_SPEC.md)、[API契约](docs/API_CONTRACT.md)；先冻结变更契约，再实现 |
| UI组件、主题与交互 | [设计系统](docs/design_system.md) |
| 阅读主流程缺陷 | [缺陷取证流程](docs/READING_FLOW_DEFECT_HUNT_PLAN_20260924.md) |
| CI、测试分组与手动构建 | [CI编排说明](docs/CI_ORCHESTRATION_20261010.md) |
| Python生成与Android FFI | [构建入口](docs/PYTHON_FFI_BUILD_20261011.md)、[Gradle接线](docs/PYTHON_GRADLE_FFI_20261011.md) |
| Windows构建与运行 | [Windows入口](docs/PYTHON_WINDOWS_TOOLING_20261011.md) |
| iOS构建、符号及签名 | [iOS入口](docs/PYTHON_IOS_TOOLING_20261011.md)、[签名说明](docs/IOS_CI_SIGNING_SETUP.md) |
| 设备操作与MuMu安装 | [工作流设备说明](docs/REFACTORING_WORKFLOW.md#设备验证说明)、[README](README.md#编译与测试) |
| Skills维护与初始化 | [Skills维护说明](docs/SKILLS_MAINTENANCE.md) |

## 执行边界

- 用户当前指令优先；未明确要求不使用子代理。多代理获授权后才适用工作流中的派发规则。
- 仅处理授权范围，保留用户及其他执行者的未提交修改；不擅自扩大功能或改写已提交历史。
- 分支使用 `feature/rust-*`、`feature/ui-*`，集成使用 `integration/*`；只从当前HEAD创建。用户已指定当前分支或worktree时按其指令执行。
- 验证通过后本地提交；阶段推送遵循用户当前授权，不能用通用流程覆盖明确的“不推送”要求。
- 汇报、注释和提交描述使用中文；l10n保持中文主语言，资源与术语参考上游。
- 项目UI只负责界面、交互与状态，业务经领域契约访问Rust；不因参考上游而擅自更换内部架构。

## 常用验证入口

本地只选择本次受影响的文件或用例，不直接照搬全量CI命令；具体范围见开发规范。

| 范围 | 入口 |
|---|---|
| Flutter | `flutter_legado/` 下定向 `flutter analyze <路径>`、`flutter test <测试路径>` |
| Rust | `rust/` 下 `cargo test -p <crate> <用例过滤>` |
| Python工具 | 根目录 `python scripts/dev.py test tooling`，定向筛选见CLI帮助 |

完整普通/native测试分组、宿主库准备及CI职责见CI编排说明；设备能力和限制见工作流。

编写者：Codex｜2026-10-24
