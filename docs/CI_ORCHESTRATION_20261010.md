# CI 编排与按改动选择任务

任务状态只记录于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。最初编排任务为
`CI-ORCH-20261010`，实施基线 `bdea9b155`；2026-10-11 的工具集中与平台隔离任务为
`CI-PLATFORM-SCOPING-20261011`，实施基线 dev `d087e3db9`。

## 决策与范围

此前普通开发分支 push 和 PR 都会触发检查，Flutter/Rust 任意改动都会启动两个
原生冒烟作业，iOS 设备包也会在开发分支自动构建。用户要求先优化编排，后迁移
Python 构建工具。本批保留正式编译、测试、签名、图标、产物校验及发布步骤。

将自动 push 限定为 `dev/master`，PR 检查针对这两个目标分支。开发分支通过 PR
或手动入口验证；合入后的检查针对集成结果，PR 使用实际合并提交相对事件 base
计算差异。push 使用本次事件的 before/after，覆盖一次 push 中的全部提交。
浅检出缺少 before 时按 SHA 补取；无法取得有效差异即失败，不默认跳过。

采用项目内标准库 Python 判定器与一份薄 composite action，避免增加路径过滤
第三方 Action 和多份规则。只做任务选择与汇总，不承担 native 构建和元数据校验。
其用户价值是减少无关构建；本批不声称已经测得构建时间或费用降幅。

## 触发与检查入口

| Workflow | 自动入口 | 手动入口与检查 |
|---|---|---|
| Tooling CI | `dev/master` push、指向两分支的 PR | 支持手动；集中执行编排规则、Python 工具回归及 actionlint，不安装 Flutter/NDK/Xcode |
| Flutter CI | `dev/master` push、指向两分支的 PR | 保留手动完整检查；原 `analyze` 作业内按范围执行 SDK 安装、分析和测试 |
| Rust CI | 同上 | 新增手动完整检查；原 `check` 汇总，所需 quality/tests/audit 必须成功 |
| Integration Smoke | 同上 | `all/android/windows`；`check` 汇总所选原生任务的结果；仅验证工具时使用 Tooling CI |
| iOS Build | `dev/master` push | 保留设备包手动入口；Linux 先判定，相关改动才申请 macOS Runner |
| iOS CI | 无自动入口 | 保持仅手动模拟器验证 |
| Android Release | `v*` tag | 保持手动只构建；Tag 发布条件、产物 ID 和 publish 权限不变 |

Tooling/Flutter/Rust/Integration 的自动 workflow 不再通过顶层 paths 跳过；无关改动也提供
轻量检查结果，避免将来设置必需检查时长期 Pending。当前仓库 dev/master 未受保护，
本批不修改保护或 Ruleset。选择失败、必要任务失败/取消/意外跳过，汇总均失败；
只有明确判定不需要的 job 才允许 skipped。

## Android 发行签名

本地使用已忽略的 `flutter_legado/android/key.properties`，填写 `storeFile=release.jks`、
`storePassword`、`keyAlias`、`keyPassword`；密钥位于 `android/app/release.jks`。
`storeFile` 相对 `android/app/` 解析；Properties 中的反斜杠需要转义。
Gradle Release 检查必填项与文件是否存在，实际密码由 Android 签名工具检查；Debug 不要求发行配置。

GitHub Actions 需设置四项 Repository Secrets：`ANDROID_KEYSTORE_BASE64`（整份 JKS 的 Base64）、
`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。后三项填写实际值，
不包含 Properties 转义。另设置公开 Variable `ANDROID_SIGNING_CERT_SHA256` 为发行证书指纹，
当前指定证书为 `9395c57290fb1f62b40fd59e166f8d6c791ac282318842a3a868df4a37f701b5`。

工作流调用 `.github/scripts/android_signing.py` 将密钥恢复至 `RUNNER_TEMP/legado-release.jks`，
通过 `ANDROID_KEYSTORE_PATH` 传入 Gradle，结束时用同一脚本的 `--clean` 删除这一临时文件。
密码与别名在 Flutter 构建步骤通过环境注入，不写入日志或产物。
现有 `collect apk android` 使用 `--signing-cert-sha256` 检查三个 APK 的签名有效性和证书指纹，
原有 Rust 库校验继续执行，全部通过才收集上传。不新增签名 CLI 或独立预检工具。

Tag 发布、手动只构建、Artifact ID 与权限范围保持不变。本地检查不代表远程发行包已构建；
当前验证状态见 Active 计划。签名接入依据：[Flutter 签名配置](https://docs.flutter.dev/deployment/android#configure-signing-in-gradle)、
[Android apksigner](https://developer.android.com/tools/apksigner)。

## 改动分类

权威实现为 [.github/scripts/ci_changes.py](../.github/scripts/ci_changes.py)，
回归矩阵为 [test_ci_changes.py](../.github/scripts/test_ci_changes.py)。

Flutter CI分为changes、flutter-checks、native-tests与analyze汇总。保留原analyze检查名，
选择失败、被选中任务失败/取消/意外跳过都不能通过；未选中任务允许跳过。

- flutter-checks运行架构门禁、按相关输入选择的生成检查、静态分析及
  `flutter test --no-pub --exclude-tags native`。普通测试不编译原生库，且显式指定不存在的
  LEGADO_TEST_FFI_LIBRARY，避免错误初始化被本机旧库掩盖；只有FRB生成复核需要Rust工具链。
- native-tests在Linux单次执行`cargo build --locked -p legado-ffi --features quickjs`，
  显式传入本次debug `.so`，运行`flutter test --no-pub --tags native`。
  标签覆盖通用FFI契约与仍依赖真实分页的阅读器集成用例，不按所在目录假定测试类型。
- 原生组选中范围包括Rust生产输入、FRB与数据/领域/平台/共享状态、阅读器/搜索/朗读、
  依赖锁文件和相关编排。独立书架/设置页面及非阅读器普通组件实现变化不单独选择原生组。
  本轮测试文件和共享夹具变化先保守选择两组，不声称已做到逐用例最小依赖选择。
- Rust crate独立集成测试变化只走Rust CI；两处正式排版测试载荷目录因被Dart读取，仍选原生组。
  纯文档变化不启动原生编译；iOS模拟器手动约定、设备包触发和Windows宿主冒烟保持。
- `dart_test.yaml`登记native标签；新增原生用例须显式标记。普通组缺库即失败，用来暴露遗漏分组，
  不通过skip或退回Mock消除失败。全量本地`flutter test`仍会运行两组，需先构建宿主库。

本地验证结果与平台限制登记于Active计划；Windows通过不代表Linux/macOS已实际运行，
编排静态检查通过也不代表远程Actions已通过。不以分组前后单次本地耗时推断远程成本下降。

- 普通 Dart 页面走 Flutter 检查；在 dev/master 上影响应用内容时构建 iOS 设备包。
- Android/Windows/iOS 平台目录分别选择所属平台；Android FFI 作业只证明原生库
  编译和复制校验，不替代 APK/Gradle 宿主构建。
- Rust 生产源码、Cargo 输入、FRB 绑定、Dart native 入口、模型、设备桥接与依赖
  文件覆盖相应原生检查；资源 Markdown 属于应用输入，不作为纯文档忽略。
- 工具的权威范围为 [input_scopes.py](../scripts/tooling/input_scopes.py)，指纹与路由共用。
  Android、Windows、iOS 的已分类工具只选择自身平台及 Tooling CI；共享模块、CLI 和
  尚未分类的工具选择三个原生平台及 Tooling CI，不因工具改动启动 Flutter/Rust 业务测试。
  打包工具修改仍验证所属平台，但不改变 Rust 库指纹；代码生成工具修改先运行 Tooling CI，
  真正生成的 Rust/Dart 源码变化再选择各自消费者。
- Tooling CI 是编排与 Python 工具回归的唯一自动入口；其他 workflow 的本地 action
  只计算差异。测试、编排脚本/action 修改仅选择 Tooling CI；workflow 修改另选自身消费者。
  Tooling CI 与原生 workflow 独立运行，不增加跨 workflow 调度依赖；需强制合入门禁时可将
  Tooling CI 的 `check` 与所需平台检查一起设为必需检查。
- Rust 树仅排除已核对的宿主驱动脚本 `build-ios.sh`、`gen_rar5_fixture.py`，它们分别选择
  iOS 和 Rust 验证。新 Rust 脚本默认仍视为共享编译输入。`third_party/**` 保守选择全部消费者。
  详细指纹口径见 [工具说明](过期文档/PYTHON_FFI_TOOLING_20261010.md)。

重命名按删除旧路径、新增新路径处理，两侧模块都检查。手动范围覆盖自动差异选择。

## 验证与回滚

```powershell
python -m unittest discover -s .github/scripts -p test_ci_changes.py -v
python scripts/dev.py test tooling
.\.tmp_ci_workflow_validation\actionlint.exe
git diff --check
```

以下为最初 `CI-ORCH-20261010` 的历史证据；当前批次结果只回写 Active 计划。

本地 16 项测试通过，覆盖范围矩阵、手动选择、多提交 push、PR 合并差异、删除与
重命名、中文空格路径、浅检出补取基线、输出与失败汇总。actionlint 与差异检查通过。
对照基线 YAML 逐值确认 Rust 质量/测试/审计、Android/Windows 冒烟及 iOS 设备 build
作业的原步骤保持；Android Release、iOS CI 完全保持。

实现提交 `27351fd68` 的 [Integration Smoke routing 运行](https://github.com/xldgo/OpenLegado/actions/runs/38062145455)
成功：Linux Runner 上编排回归通过，changes/check 两个作业成功，android-ffi/ffi-smoke
均按手动范围 skipped。验证了本地 action、输出传递、条件跳过与汇总接线；没有启动
APK、iOS 模拟器或全量 native 编译。Flutter/Rust/iOS 的自动触发与条件通过本地矩阵和
YAML 审计核对，尚未通过真实 PR/集成分支 push 逐一运行，不声称原生构建已复验。

手动验证通过已注册的 Integration Smoke workflow 在开发分支运行，未合入 master。
Git 推送使用本次进程的 SSH HTTP CONNECT 代理 `127.0.0.1:7897`，没有修改全局配置。

回滚只撤销本批编排与辅助文件提交，原构建脚本和平台流程仍可使用。
下一阶段再实施源码/构建指纹和只读 FFI 校验；本批不删除旧 sh/ps1。

依据：[GitHub 事件过滤与检查状态](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#using-filters)、
[任务条件与 needs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idif)。

编写者：Codex｜2026-10-10

修订者：Codex｜2026-10-11（工具回归集中与平台范围共享）

## 生成一致性与静态门禁（2026-10-19）

显式Flutter依赖恢复统一使用`pub get --enforce-lockfile`；Flutter CI不再放行info级lint。
架构规则由`flutter_legado/tool/check_architecture.dart`解析Dart指令语法树，覆盖条件导入、
转导出及路径规范化：features/widgets/providers禁止直接引用生成桥接，domain不得依赖UI或具体实现。
此检查是静态门禁，业务、取消和生命周期仍以运行行为测试验收。

生成检查独立按输入选择：Dart模型目录、状态及Freezed/JSON生成物、build.yaml；FRB桥接目录、
FFI源码/清单、Rust工作区清单/锁文件、FRB配置。两者共享pubspec及生成工具输入。
新增生成输入若不属于上述路径，须同时扩展判定器及范围测试；普通页面改动不重新生成。
手动完整Flutter CI复核两种生成链；Integration单选Android/Windows不运行生成检查。
FRB codegen版本读取运行时契约，cargo-expand固定为本轮实测1.0.127；不改变Rust stable策略。

生成复核使用临时目录，检出新增/删除/修改并拒绝依赖声明漂移；原工作区保持不变。
iOS模拟器仍仅手动，现有工作流触发器、签名、发布条件和权限保持。

编写者：Codex + UI/Tool｜2026-10-19
