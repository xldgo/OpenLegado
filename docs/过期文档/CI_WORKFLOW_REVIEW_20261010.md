# CI-WF-20261010 独立工作流审查证据

本报告只记录本批独立审查与守卫验证证据；任务进度以 [Active 计划](REFACTORING_ACTIVE_PLAN.md) 为准。

## 1. 结论与范围

**最新结论：最终守卫代码静态审查与最小真实 ARM fixture 复核通过，没有剩余提交前代码阻塞；修复后 Integration Smoke 实际通过，Android Release 完整打包尚未运行。** 首次实际 CI 中 Android 复制/meta 步骤失败，用户日志已确认本批主代理引入的连续四字节 FRB hash 扫描误报；该逻辑现已改为复制完整性及 strip 正规化 SHA256 校验。发布单独重跑的工件 ID 问题此前已修复。前一轮 111 个合成 fixture 是旧版本快照，不能作为最终代码通过或旧扫描正确性的证据，见 §8；修复后的实际 CI 证据见 §9。

- 基线：`a3302a0cc84b6892ea6833b8923836b166b45a36`。
- 审查对象：`.github/workflows/` 下的 `ios-ci.yml`、`ios-build.yml`、`rust-ci.yml`、`flutter-ci.yml`、`integration-smoke.yml`、`android-release.yml` 最终工作区文件；发布工作流按用户要求由 `flutter-release.yml` 重命名。
- 审查者与实施者独立；审查者只写本报告，没有修改工作流、脚本、应用源码，没有提交、推送或触发远端工作流。
- 已读取开发规范、重构流程、Active 本批任务、iOS 签名说明，并交叉读取既有 FFI 校验脚本、Android Gradle 配置、iOS podspec/图标声明和两项模拟器集成测试。以上交叉材料保持原状。

## 2. 实际行为核对

| 对象 | 核对结果 |
|---|---|
| iOS CI | 触发器只有 `workflow_dispatch`；使用 `aarch64-apple-ios-sim`、`iphonesimulator` SDK、独立 checkout/job 中的模拟器静态库。先 pod install，再构建与 PDE 校验；原图标状态测试及离线搜索阅读测试完整保留，均使用 pipefail，失败不能被 tee 吞掉。测试会覆写 Runner.app，报告和工作流均不把测试宿主重新启动当作生产首屏验收。 |
| iOS Build | 原有 push 路径 `flutter_legado/**`、`rust/**`、自身 workflow 不变；仅构建设备 `aarch64-apple-ios`，使用 iphoneos SDK。PNG 注入与删除 alternate `CFBundleIconName` 的历史包处理保持，未自行清理。PDE、指定图标文件、资产编译警告、最终 plist/引用资源、适用签名及 IPA 完整性均是硬失败路径；car 名称/大小探针及完整 car/plist 诊断仅在手动 `diagnostics=true` 时运行。 |
| iOS 产物与签名 | 签名、未签名分支只选择一份 IPA，工件名称仍为 `legado-ios-signed-ipa` 或 `legado-ios-unsigned-ipa`。有 P12 时签名步骤失败阻止后续交付，不回落伪装成功的 unsigned 包；无 P12 时跳过签名。最终修改版 app 直接重签，签名后仅复制/打包。准备和签名步骤没有 `set -x`，随机 keychain 密码不会因 shell 跟踪输出；上传路径不包含 signing 目录/P12/解码 profile 或 keychain。签名 IPA 内嵌描述文件属于既有交付内容。 |
| Flutter CI | 保留 `analyze` job 名称及原 `flutter analyze --no-fatal-infos`、`flutter test` 命令。移除 Android `needs` 后，Android 构建失败不会把常规检查跳过；自身 workflow 路径变动也触发检查。 |
| Integration Smoke | Android 两 ABI debug + QuickJS 构建/元数据/校验迁入独立 `android-ffi` job，与既有 Windows `ffi-smoke` 无 `needs`，可并行且独立失败。最终复制守卫检查本次 Cargo 产物非空、复制前后完整 SHA256 一致，并记录 `binarySha256`，不再扫描连续 i32 字节。Windows 原真实 DLL 构建与 `integration_test/ffi_smoke_test.dart -d windows` 命令保留。路径增加 Flutter CI/Android Release workflow，覆盖相关编排调整；发布文件引用已同步为 `android-release.yml`。 |
| Rust CI | fmt、默认 clippy、QuickJS clippy、默认 workspace 测试、JS/FFI/server QuickJS 测试及 cargo-audit 保留；未加入 skip/OOM 绕过。原单独 `cargo check --workspace` 不再重复运行，其默认 workspace 编译检查由保留的 `cargo clippy --workspace --all-targets` 覆盖。旧 `check` job 名保持，`always()` 汇总 quality/tests/audit，任何非 success 结果都使汇总失败。 |
| Android Release | arm64、x86_64 明确 QuickJS；armv7 保留 P2-24 已裁决的无 QuickJS 降级。直接使用已提交 FRB 2.11.1 生成物，没有安装 codegen 或构建后重生成；构建前核对 Dart/Rust hash/版本。最终复制守卫检查本次 Cargo 产物非空与复制完整性，只 strip JNI 副本，元数据分别记录 `sourceBinarySha256`、`packagedBinarySha256`，保留 release/quickjs/源码指纹及既有三 ABI 校验。APK 收集检查精确库路径且拒绝缺失/重复/其他 ABI 条目，并对本次 target 源库与 APK 库的临时副本使用同一 NDK strip，比较正规化 SHA256，原 target 产物不动。 |
| 发布权限 | 六份 workflow 默认均为 `contents: read`。只有 Release 的 `publish` job 有 `contents: write`，条件同时要求 push 与 `refs/tags/v`；手动运行即便选择标签也只构建/上传工件。发布下载生产者输出的实际 artifact ID，不按消费者 attempt 推测工件。 |

脚本与应用代码的保护范围差异检查没有输出：

```powershell
git diff --name-only a3302a0cc84b6892ea6833b8923836b166b45a36 -- scripts rust/scripts flutter_legado/scripts app modules rust/legado-ffi flutter_legado/lib
```

## 3. 已修复的审查发现

**CI-WF-20261010-R1：发布作业单独重跑时丢失构建工件，修复后通过。**

初版上传与下载都用 `flutter-apk-${{ github.run_id }}-${{ github.run_attempt }}`。最小情景为 build 在 attempt 1 成功上传 `flutter-apk-12345-1`，publish 临时失败后只重跑失败作业；attempt 2 的 publish 将寻找未上传的 `flutter-apk-12345-2`。GitHub 官方说明 [run_attempt 随重跑递增、run_id 保持](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)，并支持 [仅重跑失败或指定作业](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)。该结论是依据官方语义与名称替换 fixture 的推导，没有触发实际发布。

最终修复链为 `upload-apk.outputs.artifact-id` → `build.outputs.artifact_id` → `needs.build.outputs.artifact_id` → download `artifact-ids`。消费者先硬校验单一数字 ID；`merge-multiple: true` 保证 APK 落在发布所用目录，不多套工件名子目录。输入/输出和目录行为已与 [upload-artifact v4 定义](https://raw.githubusercontent.com/actions/upload-artifact/v4/action.yml)、[download-artifact v4 定义](https://raw.githubusercontent.com/actions/download-artifact/v4/action.yml) 及 [download 实现](https://raw.githubusercontent.com/actions/download-artifact/v4/src/download-artifact.ts) 核对。

独立复核：build1/publish1 与 build1/publish2 都选择生产者 ID `501`；重新构建 build3 后 publish4 选择生产者 ID `503`。源码断言确认最终 publish 不引用 `run_attempt`，且不存在 name/ID 混用。真实 Bash 守卫接受 `501`、`503`，拒绝空值、`abc`、`501,503`、前置空格、末尾换行与 `-1`，八例符合预期。

## 4. 扫描修复前版本的独立验证快照

本节保留扫描修复前的实际执行记录。其 111 个合成 fixture 只证明当时输入符合旧守卫的执行预期，没有覆盖真实 ARM 编译器对常量的指令编码；该审查漏检已在 §8 用真实对象与实际旧守卫补齐。本节不冒充最新守卫验证结果。

本机为 Windows；临时工具为官方 actionlint v1.7.12 与 PyYAML 6.0.3。Python 通过 `sys.path.insert` 临时载入 `.tmp_ci_workflow_validation/python-deps`，未安装全局依赖。使用 YAML `BaseLoader` 避免 YAML 1.1 把 `on` 读成布尔键。临时 fixture 使用 `tempfile.TemporaryDirectory` 自动回收，没有新增永久测试脚本。

该阶段 actionlint 命令：

```powershell
.\.tmp_ci_workflow_validation\actionlint.exe -shellcheck= -pyflakes= .github/workflows/ios-ci.yml .github/workflows/ios-build.yml .github/workflows/rust-ci.yml .github/workflows/flutter-ci.yml .github/workflows/integration-smoke.yml .github/workflows/android-release.yml
```

结果：退出码 **0**，无诊断。此命令明确禁用外部 shellcheck/pyflakes，因此没有把这两项计作已执行验证。

另用 PowerShell here-string 经 `python -X utf8 -` 运行内存审查 harness：逐 job 提取 run 块，以 `C:/Program Files/Git/bin/bash.exe --noprofile --norc -n` 检查 Bash 语法，GitHub 表达式只在语法检查阶段替换为占位符；Windows 默认 PowerShell run 块不交给 Bash。提取 Python heredoc 后执行 `compile(..., 'exec')`。该阶段结果：**六份 YAML 解析通过，55 个 Bash run 块语法通过，8 个 Python heredoc 编译通过**。

守卫 fixture 提取实际 run 或 heredoc，直接在子进程执行，没有另写一份守卫实现。Bash 执行形态为 `bash --noprofile --norc -e -o pipefail -c <实际 run>`；Python 执行形态为 `python -X utf8 -c <实际 heredoc> <fixture 参数>`。

| 验证面 | fixture 与执行结果 |
|---|---|
| Rust 汇总 | success/failure/cancelled/skipped 的三项笛卡尔积，**64 例**；仅全部 success 返回 0，其余全部返回 1。 |
| FRB 版本/hash | Integration 与 Release 分别测试一致、hash 不一致、错误版本、缺 hash，**8 例**；一致返回 0，负例返回 1。 |
| 动态库复制/元数据 | debug 与 release 的合法内嵌 hash、无 hash 二进制，**4 例**；合法库成功，负例失败。另读取生成 JSON，核对 mode/hash/QuickJS/源码指纹；armv7 release 明确 false，两种模式其余对应 ABI 为 true。源码指纹变量使用 fixture 值，未运行真实 native 构建。 |
| APK 校验 | 三 ABI 合法 ZIP、错误内嵌 hash、错误 ABI 库路径、缺少指定 ABI APK，**4 例**；仅合法三包通过。 |
| 最终图标 plist/资源 | phone+iPad 完整声明、缺 launcher、残留 CFBundleIconName、缺引用 PNG、坏 plist，**5 例**；仅完整声明通过。 |
| IPA 内部校验 | 有效结构、缺 plist、坏 plist、缺 Runner、空 Runner，**5 例**；仅有效结构通过。ZIP 由 Python fixture 构造，验证使用 workflow 的实际 Python 段。 |
| PDE 失败传播 | 设备与模拟器分别验证有符号、无符号、nm 失败；另验证符号仅在 Runner.debug.dylib 的模拟器情景，**7 例**。nm 由 Bash 函数返回 fixture 输出；合法情景通过，缺符号/命令失败均报红。 |
| 签名失败传播 | 实际签名 run 块，security/codesign 为无真实证书的 Bash 替身；正常、framework 签名失败、顶层签名失败、最终验证失败，**4 例**；只有正常情景返回 0。该测试只证明失败传播。 |
| signed/unsigned 选择 | 执行实际 package run 中分支选择部分，**2 例**；空 P12 选择原 unsigned 名称，有 P12 选择原 signed 名称。同一步只有一处 zip/上传路径，没有第二份重复输出。 |
| 发布工件 ID | 修复后的实际 ID 守卫，**8 例**，结果见 R1；另核对生产者/消费者表达式及三种 attempt 情景。 |

以上共 **111 个旧版本守卫执行情景**符合当时合成 fixture 的预期；其中复制/APK 合成输入不足以证明四字节扫描是可靠的产物验证方法。另做源结构断言，核对手动 iOS 触发器、原设备 push 路径、Flutter/Android/Windows job 无 needs、硬门禁无 continue-on-error、四项诊断的手动开关，以及五种事件/ref 的发布条件。

中间完整打包 shell fixture 因本机 Git Bash 没有 `zip` 停在 `zip: command not found`，故**没有计作完整打包通过**；之后只执行实际名称选择段，IPA Python 校验另用 ZIP fixture 验证。首次载入 PyYAML 未设置临时 sys.path 的工具尝试同样未计为验证结果。

### 实现侧最终全仓复验补充

以下由实现侧 L2（ci_cleanup）最终复验提供，**不是独立审查者亲自执行的结果**：本批六份 workflow 的 actionlint 退出码为 0；全仓九份 workflow 的 actionlint 退出码为 1，唯一诊断是未修改的 `pr-review.yml:40` 使用 `openai/codex-action@v1` 未声明的 `permission-profile` 输入。L2 确认该文件与 HEAD 逐字相同，此问题属于既有自动化，本轮不修改。

L2 的广义嵌入 Python AST 检查计为 10 段，包含其额外识别的嵌入形式；本报告独立检查按 Python heredoc 提取，计为 8 段。两者检查口径不同，独立审查数字保持原记录，不将实现侧结果合并为独立执行证据。

### Android Release 命名调整的独立复核

用户指出该发布链只产出 Android APK，实施者随后将 `flutter-release.yml` 重命名为 `android-release.yml`，显示名称与 Release 标题同步为 `Android Release`；concurrency 前缀调整为 `android-release`，动态 APK 工件前缀调整为 `android-apk`。Integration push/pull_request 中两处发布文件路径引用同步更新。

独立审查将这两份最终文件的声明命名替换反向还原后计算 SHA256：还原结果与上一轮工作区原始字节摘要分别完全相同，证明其余字节没有变化。旧发布文件不存在，新文件存在；artifact ID 跨 job 传递、构建命令、触发条件、权限、失败守卫均保持。对最终六份 workflow 再次执行上列 actionlint，退出码 0；工作流范围 `git diff --check` 退出码 0。该轮没有重跑前述 111 个守卫情景，保留原已完成证据。R1 中的 `flutter-apk-12345-*` 为重命名前的历史复现场景，最终动态前缀已是 `android-apk`。

## 5. 必需检查与未覆盖边界

- 旧 Rust `check`、Flutter `analyze`、Integration `ffi-smoke`、iOS Build `build` 的 job ID 保留；新增加 Rust quality/tests/audit、Integration android-ffi，删除 Flutter 的 android-ffi-sync。如果远端分支保护仍要求旧 android-ffi-sync，应迁移到 Integration 的 android-ffi；远端 rulesets/branch protection 未读取，不能宣称已兼容全部必需检查配置。
- iOS CI 仅手动运行，没有自动 PR check。仓库说明已明确其不作为 PR 必需门禁，远端设置仍须核实。已有路径过滤会让无关变动不创建 workflow run；若某受路径过滤的 job 被无条件设为必需检查，可能保持 pending。这一配置风险不是本次静态 YAML 检查能够排除的。
- 没有运行 macOS/iOS 原生构建、真实 nm、真实 codesign、真实设备安装、Android NDK/APK 构建、Windows FFI smoke 或远端发布。常规 Rust/Flutter 测试未在审查角色重复执行，应以提交后的相应 CI 证据为准。
- 当前 PDE 检查证明 nm 输出含目标符号名，沿用既有判定方式；fixture 只验证有/无符号与命令失败传播，不证明实际 Mach-O 可由 Dart 运行时解析。前版连续四字节 FRB hash 扫描已证实存在误拒绝/误接受，现已撤销；最终产物守卫检查复制完整性与相同 NDK strip 后的 SHA256，同时保留源码 FRB 版本/hash 和指纹校验，完整构建链仍须修复后远端复验。
- 签名素材、profile/证书匹配与目标设备 UDID 没有实测；代码签名命令失败会报红，并不构成已可真机安装的证据。图标历史补丁维持原包形状，不证明真机换图标 `-54` 已解决。

## 6. 最终审查快照

以下为最终工作区文件原始字节 SHA256，用于界定本报告的审查对象；提交行尾归一化可改变字节摘要。

| 文件 | SHA256 |
|---|---|
| ios-ci.yml | `212d30308a68277f15b614850659453bd76c0b662eaaa2f14f6c9d56791980bb` |
| ios-build.yml | `245c4329625bcb31ea48ddf6c65c66b88597fa4c9abb475e49e4b4e9fb926a4d` |
| rust-ci.yml | `55bc99620a091a0080515dccbe3d0fd21e846db54dea06e138392283b531ade1` |
| flutter-ci.yml | `27ef5e7cb0b44f999d4a4b93fed4908ee0b243c10224847ffcd2a17f04ce675d` |
| integration-smoke.yml | `d533a6a3abfaca568228bb17e20da0fac6ef57614ffbfb917e875621871d2d5a` |
| android-release.yml | `296767429212aa6ed5ec082836cb6a2cecd53b38fe993b47fe19fcb812455918` |
| stale.yml | `29be44b9cc9dfe609bfd575ba69a59bf2e4ed48c6891d1fe8fa5d8d542c82cdb` |

## 7. 用户追加的 stale 限定移除审查

基于工程提交 `2301a2e183439d49942176f814dcb7fd3004e5c3`，仅审查 `.github/workflows/stale.yml` 删除 `github.repository == 'ZhangGHGitHub/LegadoTeamFlutter'` 的一行 job 条件。独立读取 diff 并解析修改前后 YAML：删除旧映射中的该 `if` 后，两份结构完全相同；schedule `30 1 1/5 * *`、手动入口、`issues: write`、`actions/stale@v11`、30 天标记加 5 天关闭和每轮 100 次操作参数均未变化。行为改变限定为不再按旧仓库名称跳过 job，符合本次用户追加要求。

独立复验：§4 的六文件 actionlint 命令末尾追加 `.github/workflows/stale.yml`，七份受影响 workflow 检查退出码 0；stale YAML 解析/结构对照与 `git diff --check -- .github/workflows/stale.yml` 均退出码 0。此追加审查没有重跑原 111 个守卫情景，没有触发 stale workflow、实际自动清理或关闭 issue/PR，运行时行为仍未实测。结论：该单行改动静态审查通过，没有新增提交前阻塞。

stale 工作区原始字节 SHA256：`29be44b9cc9dfe609bfd575ba69a59bf2e4ed48c6891d1fe8fa5d8d542c82cdb`。最新七份受影响文件快照统一见 §6。

## 8. 首次实际 CI 失败与产物守卫修复复核

### 首次 CI 与直接触发点

主代理取得的首次终态证据：[Flutter CI](https://github.com/xldgo/OpenLegado/actions/runs/38024497488)、[Rust CI](https://github.com/xldgo/OpenLegado/actions/runs/38024497519)、[iOS Build](https://github.com/xldgo/OpenLegado/actions/runs/38024497525) 成功；[Integration Smoke](https://github.com/xldgo/OpenLegado/actions/runs/38024497493) 中 Windows smoke 成功，Android job `114132328476` 在复制/meta 步骤失败。审查者没有启动这些运行，状态来源为主代理已取得的远端结果。

用户随后提供该失败步骤原文：`aarch64-linux-android 动态库未嵌入当前 FRB hash`，随后退出码 1。该文字与已提交 Python 四字节扫描守卫的 `SystemExit` 一致，确认本次触发点。此前日志接口 403、凭据读取被自动审批拒绝时没有足够原文；用户提供文本后已补齐，不再把触发点登记为未知。本审查没有读取凭据或绕过日志访问限制。

**本批主代理引入的连续小端 i32 四字节扫描是本次误判根因。** 编译器可以用指令立即数返回 FRB 常量，并不保证 ELF 中出现完整连续字节。本轮也揭示此前独立审查的合成 fixture 漏检了这个编译器边界，不能用旧 111 例通过淡化实际 CI 失败。

### 真实 ARM 对象与实际旧守卫的独立复现

实现侧 L2 使用既有 clang 23.1.3，以 `--target=aarch64-linux-android21 -O2` 编译 `int current_frb_hash(void) { return -1293445466; }`。材料位于 `.tmp_ci_workflow_validation/arm64-hash-guard-fixture/` 的 `.c`、`.o`、`.s` 与 `result.json`；编译命令、反汇编记录由 L2 提供，不是审查者亲自构建。对象以 `mov w0, #0x96a6`、`movk w0, #0xb2e7, lsl #16` 返回该常量。

审查者亲自读取对象，核对 ELF 头与 AArch64 machine 编号、1032 字节大小、SHA256 `d1b26ae56716dab8c3b124f29cafd855d94e6f6699b3194862499be98ceaa4cb`，以及不存在小端模式 `a696e7b2`。随后从提交 `5c2c17f86` 提取实际旧 Python 段，独立运行两项最小复现：

- 旧 copy 守卫拒绝该有效 ARM 对象，stderr 与用户提供的错误逐字相同。
- 旧 APK 守卫接受仅附有当前 i32 模式的无关旧 blob，证明字节标记也会误接受，不能证明产物来源一致。

该材料是最小 ARM ELF 对象与人工 ZIP，不是完整 Rust `.so` 或完整 APK 构建；它证明扫描假设错误，实际 CI 日志另行证明同一守卫是本次失败触发点。

### 最终替代守卫及 strip 边界

Integration debug 改为本次非空 target 产物的复制前后 SHA256 一致，记录 `binarySha256`。Release 同样先验证完整复制，只对 JNI 副本执行本次 NDK `llvm-strip --strip-unneeded`，原 target 不动；元数据分别记录源与打包副本摘要，保留 contentHash/mode/QuickJS/源码指纹。FRB 源码版本/hash 前置检查与原 verify 脚本调用保持，未修改脚本、应用或依赖。

独立审查另发现，直接要求 APK 与未 strip Cargo 产物字节相同会误拒绝合法打包处理；[Android 官方打包配置说明](https://developer.android.com/reference/tools/gradle-api/8.3/com/android/build/api/dsl/JniLibsPackaging) 中 `keepDebugSymbols` 即用于让指定 native 库不被 strip。本仓未启用该保留配置，因此最终 APK 守卫对本次源库和 ZIP 内库的临时副本使用同一 strip 工具正规化后比较 SHA256。strip 命令使用 `check=True`，失败硬退出；只忽略被合法裁剪的符号等差异，不忽略运行时代码字节变化。

### 最终代码的独立验证与限制

从最后工作区提取实际 Python 段执行，未另写一份守卫实现。正规化调整前已独立执行 17 个情景：debug/release 接受无连续 i32 的 ARM 对象、拒绝空/缺源与复制损坏；APK 拒绝旧库即便附当前 i32、单字节变化、缺库、错误/额外 ABI、重复库、空/缺源。此 17 例用于定位和校验中间 SHA 实现，其中 Release 后续加入 strip，不将全部 17 例当作最终 Release 重跑结果。

最终代码另独立执行 **8 个情景**：Release 复制合法对象成功且仅处理副本、Release strip 非零退出失败；APK 合法一次 strip 成功、二次 strip 成功、修改 `.text` 指令字节的旧对象即便尾附当前 i32 也失败、APK strip 非零退出失败、缺库失败、错误 ABI 路径失败。另核对三组路径映射元数据的 source/packaged 摘要、contentHash、mode、QuickJS 和指纹，确认所有 target 源字节不变。fixture 使用同一 ARM 对象映射到各目标路径，只验证守卫与映射，不冒充审查者完成三 ABI 编译。

审查者用现有 LLVM 23.1.3 工具执行一次/二次 strip，结果字节相同，正规化 SHA256 为 `20b11ff21c19204b9e8d8ca3caae5892b14924cd88020411cb26959358fa4021`。也独立使用已安装 NDK 29 的 strip 对原 fixture 临时副本验证幂等性，摘要一致；首次沙箱目录访问被拒，随后自动审批批准仅该本地 fixture 工具操作，无凭据访问。最终实际守卫 fixture 使用可访问的 LLVM 23 工具根模拟 `NDK_TOOLCHAIN`，**CI 固定 NDK 27，没有运行该版本或真实 Gradle/APK 打包**。

实现侧另提供 `.tmp_ci_workflow_validation/workflow-strip-fixture/result.json` 的 13 个最终实际代码情景与真实 ARM64/armv7/x64 fixture 证据；此项明确为实现侧补充，不并入审查者的 8 例。

最终独立静态复验：七份受影响 workflow 的 actionlint v1.7.12 退出码 0；本轮两份修改文件 YAML 解析通过，16 段 Bash `-n` 与 5 个 Python heredoc `compile` 通过，`git diff --check` 退出码 0。结构对照确认相较 `5c2c17f86` 只修改三处授权 run 块，其他 job、触发、权限、FRB 前置守卫、verify 调用和发布 ID 路径保持。最终七份工作区 SHA256 已刷新到 §6。

**此轮关闭的是误判守卫的实现与独立最小验证；修复后 Integration Android 与首轮 Android Release 完整打包仍需远端证据，不能报告已发布或平台全部通过。**

编写者：Codex ci_review（独立 code-reviewer）｜2026-10-10

## 9. 修复提交的实际 CI 证据

主代理通过公开 GitHub Actions API 复核提交 `8e086b99f20e4584bfb8ed5380757d7a988de0bc` 的 [Integration Smoke](https://github.com/xldgo/OpenLegado/actions/runs/38026442739)：`status=completed`、`conclusion=success`、`head_sha` 与修复提交一致。此前 §8 的“修复后 Integration 待复验”为当时的证据边界，现由该实际运行补齐。

- [Android 作业](https://github.com/xldgo/OpenLegado/actions/runs/38026442739/job/114138175099) 成功：双 ABI 原生编译、复制和 SHA256 元数据、既有 FFI 校验通过。
- [Windows 作业](https://github.com/xldgo/OpenLegado/actions/runs/38026442739/job/114138174924) 成功：DLL 编译及真实 FFI 冒烟通过。

本次没有运行 Android Release 的完整 APK 打包、手动 iOS CI 或真机签名安装，不能将 Integration 的成功当作这些专项通过的证据。Flutter/Rust/iOS Build 的首轮成功仍关联工程提交 `2301a2e18`。

补充编写者：Codex 主代理｜2026-10-10
