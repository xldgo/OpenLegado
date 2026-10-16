# CI-AUTO-20261010 自动化配置与验证证据

本报告保存配置设计和检查证据；任务状态仅记录于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。用户要求不使用子代理、审核前不自动提交，并已追加指令提交本地 commit。本轮由主代理直接实施与自审，不称作独立审查；本次提交授权不包含推送。

> 下文为 2026-10-10 的审计与授权记录；2026-10-11 新增的旧脚本清理候选见文末。
> 原记录中的“脚本保留”描述当时的实施范围，当前任务与用户修订以 Active 计划为准。

## 范围与配置

基线为 `06665408f`，分支为 `dev`。修改包括 `.github/` 自动化配置、三份仓库自动化 workflow 和必要说明；按用户追加的旧路径核查要求，另修正 `package.json` 仓库链接、iOS Podspec 首页和当前入口文档，并按其明确授权删除 8 个旧原版 Gradle 文件（含两个 Gradle 启动脚本）。`.github/scripts/`、`scripts/` 及 Rust/Flutter 辅助脚本、应用源码、现用依赖版本、Pod 构建字段与六份构建/发布 workflow 均未改动；没有应用可见变化，不递增应用版本或更新应用内日志。

| 配置 | 本轮落点 |
| --- | --- |
| `dependabot.yml` | Actions `/`、Cargo `/rust`、pub `/flutter_legado` 每周；Gradle `/flutter_legado/android` 每月。四个生态的普通版本更新均指向用户确认的 `dev`，各最多 3 个开放 PR。minor/patch 更新分组，major 单独开 PR。移除旧根 Gradle 和 `/modules/web` npm 监控。 |
| FRB 更新规则 | cargo 忽略 `flutter_rust_bridge*`，pub 忽略 `flutter_rust_bridge` 的普通语义版本更新；Rust、Dart、codegen 和生成代码由专项配套升级。本轮没有修改安全更新开关或自动合并配置。 |
| 标签与模板 | 新增 iOS、Windows、跨平台选项，以及 Dart/Rust、FFI、当前模块与测试路径；按用户指出的无效规则，移除旧 `app/`、`modules/` 与根 Gradle 的路径分类。历史 Issue 的“Android 与 Web”文字仍可识别为跨平台。设备或浏览器名 iPhone/Safari 不再单独推断 Web 模块；明确 Web 服务关键词仍可匹配。模板发布版/CI 链接改为当前仓库。 |
| `triage-labels.yml` | 事件自动标签保留，历史回填删除周计划、仅保留手动入口。校验范围新增 Dependabot 与发布分类 YAML。旧脚本的 `--self-test` 依赖已移除路径，不再由 workflow 调用；改为当前 Flutter/Rust 路径及内容正负例，保留旧脚本语法检查。路径标签 job 增加 `issues: write`，支持创建首次出现的标签。 |
| `pr-review.yml` | 同仓库、非草稿、非机器人且带 `review` 标签的 PR 才审查；添加其他标签不启动审查，也不参与审查 job 的并发取消。保留标签时，提交更新/重新打开/转为可审查会重审。移除硬编码用户名排除，使用官方支持的 `sandbox: read-only`。 |
| 审查评论 | 发评论前重新读取 PR；提交已变化、关闭、转为草稿或移除 `review` 标签时跳过。正常结果继续更新原有机器人标记评论，不覆盖人工评论。 |
| `stale.yml` | 保留原 cron、Issue 30+5 天和每轮 100 次操作参数；PR stale/close 显式设为 `-1`，Issue 豁免 `confirmed,in-progress`。没有运行自动清理。 |
| `release.yml` | 分类改为中文，性能分类兼容 `impact: performance`，增加依赖更新和维护分类。此配置用于 GitHub 生成发布说明，不改变 Android Release 当前自定义正文或发布行为。 |

安全更新仍使用默认分支；配置 `target-branch: dev` 后，普通版本更新块的分组等选项不应用于默认分支的安全更新。该规则见 [GitHub Dependabot 目标分支说明](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#target-branch)。FRB 普通更新的排除不代表安全风险可以跳过人工处置。

`pull_request_target` 标签 job 保持只调用标签 action，不 checkout 或执行 PR 中的脚本。PR 配置校验使用只读权限；历史脚本保留语法检查和明确的手动回填入口，内容及路径配置验证使用当前工程的情景。新标签创建所需权限见 [actions/labeler 权限说明](https://github.com/actions/labeler#permissions)。

## 同类旧路径核查

按用户要求检查当前纳入 Git 的配置、workflow、脚本、工程文本和文档中的旧根目录 `app/`、`modules/`、旧 Flutter 目录、旧 workflow 名及旧仓库网址。历史计划、变更记录、生成的旧 Wiki 和源码中的原版语义引用保留为来源证据，不把字符串命中直接视为失效运行路径。

| 当前入口中的遗漏 | 本轮处理 |
| --- | --- |
| `package.json` 的 repository / bugs / homepage、`RustFFI.podspec` 的 homepage | 从旧 `LegadoTeamFlutter` 仓库改为 `xldgo/OpenLegado`；不改包版本、依赖、脚本或 Pod 链接参数。 |
| Issue 模板的联系入口 | 不再将 Rust/Flutter 的简繁转换问题引导至旧 Android 依赖仓库；提供当前项目说明，原版 Wiki 明确标注为参考资料。 |
| `rust/README.md` 的发布 workflow、两个开发指南的发布分支 | 发布入口改为 `android-release.yml`；清理不存在的 `origin main` 示例，改为推送经审核的当前分支及本次 tag。分支表同步当前 `master` 默认分支与 `dev` 开发集成分支；没有执行任何推送。 |
| 当前开发文档仍将 `rust/PROGRESS.md` 当作任务入口 | 当前进度链接统一指向 Active 计划，原文件保留历史记录；历史任务中的 `flutter-release.yml` 名称不追改。 |
| `docs/api.md` 的 13 处 `/app/...` 相对链接 | 去掉两个失效目录标题链接，11 处源码引用改为 Android 原版上游，并声明参考用途；HTTP 请求示例及接口参数未改。上游五个引用目标已通过网页核查：[BookSource.kt](https://github.com/LegadoTeam/legado/blob/master/app/src/main/java/io/legado/app/data/entities/BookSource.kt)、[ReplaceRule.kt](https://github.com/LegadoTeam/legado/blob/master/app/src/main/java/io/legado/app/data/entities/ReplaceRule.kt)、[Book.kt](https://github.com/LegadoTeam/legado/blob/master/app/src/main/java/io/legado/app/data/entities/Book.kt)、[BookProgress.kt](https://github.com/LegadoTeam/legado/blob/master/app/src/main/java/io/legado/app/data/entities/BookProgress.kt)、[ReaderProvider.kt](https://github.com/LegadoTeam/legado/blob/master/app/src/main/java/io/legado/app/api/ReaderProvider.kt)。 |
| README / AGENTS 的原版目录说明与验证口径 | 不再将本次工作区实际不存在的 `app/`、`modules/` 列为仓库分发目录；原版对照与测试需另备完整工程，原版 Gradle 测试不属于当前 CI 覆盖，补齐 Rust 工作区模块。 |

以下 **6 份脚本**仍含旧路径，按用户“脚本先不删除”的要求保留，本轮内容也未修改：

| 脚本 | 旧引用与当前调用情况 |
| --- | --- |
| `.github/scripts/backfill-labels.rb` | `--self-test` 中的两个旧 Android 样例；workflow 已换用当前工程的标签情景。主回填逻辑仍读取当前配置，保留明确的手动调用。 |
| `.github/scripts/build-help-highlight.sh` | 写入旧 `app/src/main/assets/web/help/js/`；当前 9 份 workflow 无调用。 |
| `.github/scripts/test-help-highlight.js` | 读取旧 `app/src/main/assets/web/help/`；当前 workflow 无调用。 |
| `.github/scripts/cronet.sh` | 写入旧 `app/cronet-proguard-rules.pro`、根 `gradle.properties` 与原版更新日志；当前 workflow 无调用。 |
| `.github/scripts/verify-cronet.sh` | 校验旧 `app/cronetlib`、`app/so`、Cronet 元数据与根 Gradle 配置；当前 workflow 无调用。 |
| `.github/scripts/test-extract-latest-update.sh` | 使用原版更新日志及 `app/`、`modules/` 的历史变更范围；当前 workflow 无调用。 |

`triage-labels.yml` 中保留的旧漫画路径为负例，专门验证旧规则不再匹配；它不是触发或分类规则。`flutter_legado/android/app/src/...` 是当前 Flutter Android 工程的有效路径。`.gitignore` 原版目录排除、`.gitattributes` Web 资产来源注释，以及 Rust/Flutter 的原版语义注释继续保留。核查范围内，当前 workflow 的有效路径规则未再发现旧原版目录依赖，未发现旧 `flutter_legado/lib/screens`、`providers`、`services` 目录引用。

## 用户授权的旧 Gradle 文件删除

用户在核查清单后明确同意删除 8 个旧原版 Gradle 文件；该授权包括根 Gradle 启动脚本，不扩展到其他脚本、原版源码或当前 Flutter Android 工程。

| 已删除文件 | 原用途 |
| --- | --- |
| `build.gradle` | 旧原版根构建配置 |
| `settings.gradle` | 引入旧 `:app`、`:modules:book`、`:modules:rhino`，配置旧 Maven 仓库 |
| `gradle.properties` | 旧原版 Gradle/Kotlin/Android 与 Cronet 参数 |
| `gradle/libs.versions.toml` | 旧原版依赖和插件版本目录 |
| `gradlew` | 旧原版 Unix Gradle 启动脚本 |
| `gradlew.bat` | 旧原版 Windows Gradle 启动脚本 |
| `gradle/wrapper/gradle-wrapper.jar` | 旧原版 Wrapper 程序 |
| `gradle/wrapper/gradle-wrapper.properties` | 旧原版 Wrapper 配置 |

删除前核实：8 个目标均为工作区内的独立文件，Git diff 为空；本次工作区没有 `app/` 或 `modules/`，Git 中也不跟踪这些原版模块。使用 PowerShell 的 `Remove-Item -LiteralPath` 逐项删除，没有递归清理目录。删除后文件均不存在，Git 删除清单与用户授权的 8 项完全一致。

当前 Flutter Android 的独立 Gradle 配置、20 个 Kotlin 源码/测试文件、原生资源、Rust/Flutter 辅助脚本和六份构建 workflow 保持原状。`third_party/maven/` 内的 HtmlUnit JAR/POM/来源说明及 Java 探针继续用于原版 JS 转换语义核对；`package.json` 的 Commitizen 工具保留。旧 Cronet 脚本仍引用已删除的根配置，不再具备本仓库内独立运行条件；它们没有当前 workflow 调用，按用户要求保留，未来若复用须对接另备完整原版工程。

## 本地验证

2026-10-10 在 Windows、Node 24.21.0 下执行，验证工具与 fixture 均位于忽略的 `.tmp_ci_workflow_validation/`，没有新增永久脚本。

- 全部 **9 份 workflow** 通过 actionlint 1.7.12，退出码 0。
- 全部 **16 份 `.github` YAML** 经 js-yaml 5.1.0 解析及重复键检查通过。
- **14 个内容标签情景**通过：iOS/Windows 表单、跨平台及历史选项、未勾选与已勾选 PR、设备名误匹配、Web 明确关键词、IPA 构建问题及历史音频/备份情景。
- **18 个路径情景**通过：Flutter 阅读/漫画/音频/书架、Rust FFI/解析/数据库、三个原生平台、manifest/锁文件、当前测试、Web 资源、点目录文档及旧 Android/根 Gradle 不再匹配的负例。使用 actions/labeler v7 依赖范围内的 minimatch 10.2.5，启用与 action 一致的 `dot: true`。
- **10 个审查触发情景**通过：从实际 YAML 提取条件执行，覆盖有/无 `review`、无关标签、草稿、机器人、fork、原排除用户名及 PR 状态事件。
- **8 个评论情景**通过：执行实际 workflow JavaScript，使用内存模拟 GitHub API；覆盖创建/更新、提交变化、移除标签、草稿、关闭、标签大小写及人工评论保护，没有真实网络写入。
- 结构检查确认四个 Dependabot 目录/频率/目标分支/PR 上限与 FRB 排除、模板和标签对应、标签 job 权限、手动回填与 Issue 清理参数。
- 入口文档相对文件链接检查通过；元数据与基线比对确认 `package.json` 仅三个仓库网址变化，Podspec 仅首页变化，API 文档的全部请求代码块与基线一致。
- 删除范围检查通过：8 个目标均不存在，Git `--diff-filter=D` 恰好为授权清单；Flutter Android、原版探针材料、辅助脚本和六份构建 workflow 的受保护 diff 为空。未重复运行应用构建或实机测试。
- 提交前 `git diff --check` 通过。受保护脚本、应用代码、依赖与六份构建 workflow 的 diff 为空；Rust README/开发指南和 Podspec 首页为上述明确例外。验证时暂存区为空，HEAD 为基线 `06665408f`；随后按用户最新指令提交本地 commit，不推送。

复核命令（PowerShell）：

```powershell
$workflowPaths = @(rg --files .github/workflows | Where-Object { $_ -match '\.ya?ml$' })
& .\.tmp_ci_workflow_validation\actionlint.exe @workflowPaths
node .tmp_ci_workflow_validation/automation-check.cjs
git diff --check
git diff --stat
```

本机没有 Ruby，未执行 workflow 中新的 Ruby 标签验证或旧脚本的语法检查；上述标签情景使用实际配置和 JavaScript 正则/minimatch，不能冒充 Ruby 自测。旧脚本本体保持原状，其 `--self-test` 仍针对旧 Android 映射，因此不再作为本批 CI 的验证入口。新 Ruby 检查需用户审核后的实际 PR 运行补充证据。

## 生效与证据边界

本轮没有运行应用构建、Dependabot 实际解析/开 PR、真实自动标签、付费 Codex 审查或 stale 清理。静态检查与模拟 API 情景通过，不代表这些远端服务已经运行成功。

Dependabot 配置、Issue 和 schedule 自动化需在用户审核、提交并进入默认分支后按 GitHub 规则生效。普通更新的目标仍为 `dev`，不改变仓库默认分支。首次使用需在 GitHub 创建 `review`、`confirmed`、`in-progress` 标签；新增平台/语言路径标签可由具有创建权限的 labeler 自动建立。API 密钥继续使用原有 `CODE_REVIEW_API_KEY` 与可选代理地址，未读取或设置密钥。

发布分类只调整 `.github/release.yml`，没有启用 Android workflow 的自动生成发布说明，也没有扩展 iOS Release 功能。

本次本地提交主题为 `chore(tool): 整理仓库自动化并清理旧 Gradle 构建文件`，提交正文关联 `CI-AUTO-20261010` 及本报告。用户授权提交替代此前“等待审核、不自动提交”的交付约束，保留不推送、未运行远端自动化及 Ruby 验证待补的边界。

其他规则出处：[Dependabot 配置项](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)、[PR 事件与权限语义](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target)、[OpenAI Codex Action 输入](https://learn.chatgpt.com/docs/github-action)、[Stale 参数](https://github.com/actions/stale)。

编写者：Codex 主代理｜2026-10-10

## 旧 CI 脚本清理候选（2026-10-11）

本节记录 `CI-SCRIPT-CLEANUP-20261011` 的清理依据，基线为 `a9833ac33`；
当前进度只维护于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。用户先要求 doctor 后置并准备清理，
随后明确批准删除旧 APK、Web 资产推送、帮助页构建及 Cronet 四类共 9 个文件；
更新日志提取及蓝奏云/Telegram 分发的 4 个文件暂时保留。未执行这些脚本的内容。

以下是原始 13 个候选的用途和引用依据；当前删除范围限定为上述获准四类：

| 文件 | 原用途 | 当前引用与删除依据 |
| --- | --- | --- |
| `collect-apks.sh`、`remove-universal-apks.sh`、`test-collect-apks.sh` | 移动/命名旧原版 APK，删除 universal 包及对应测试 | 仅配套测试调用；当前 Android Release 使用 `collect apk android` 检查三个 ABI 并收集 Flutter APK，不消费旧命名规则。 |
| `extract-latest-update.sh`、`test-extract-latest-update.sh` | 提取原版日期更新日志及检查其源码变更日期 | 仅配套测试调用；测试读取不再跟踪的原版 `app/` 日志与 `modules/`。当前 Release 正文由 workflow 设置，不调用此提取器。 |
| `push-web-assets.sh`、`test-push-web-assets.sh` | 将生成 Web 资产提交同步并推送到 master，包含模拟远端测试 | 仅配套测试调用；旧 Web 资产更新 workflow 已无现行入口，无需把推送逻辑迁入 Python。 |
| `build-help-highlight.sh`、`test-help-highlight.js` | 构建/验证旧原版帮助页 highlight.js | 无当前调用，固定读写 `app/src/main/assets/web/help/`，该目录不在当前版本控制中。Flutter 帮助页和 Rust 服务帮助资源仍在使用，保留这些实际资源。 |
| `cronet.sh`、`verify-cronet.sh` | 更新/验证旧原版 Cronet JAR、原生库、元数据和混淆规则 | 无当前调用；依赖已删除的根 `gradle.properties` 及不再跟踪的 `app/cronetlib` 等文件，不是 Flutter/Rust 网络构建的一部分。 |
| `lzy_web.py`、`tg_bot.py` | 旧蓝奏云与 Telegram 文件分发 | 无当前 workflow 或工程入口调用；当前 APK/IPA 通过 Actions Artifact，Android Tag 通过 GitHub Release 交付，不消费这两个上传脚本。 |

引用核对包括全部当前 workflow、composite action、工程脚本、测试、开发入口文档，
并用 Git 跟踪文件检索补充隐藏目录。剩余引用限于上述配套测试、脚本自身、
本报告与 `.qoder/repowiki/` 的历史生成文档/元数据；没有发现当前生产调用。
`.qoder` 快照中的路径继续作为历史资料，不重写大份生成元数据，也不将其当成当前构建依据。

用户批准的删除清单（均位于 `.github/scripts/`）：

- 旧 APK：`collect-apks.sh`、`remove-universal-apks.sh`、`test-collect-apks.sh`。
- 旧 Web 资产推送：`push-web-assets.sh`、`test-push-web-assets.sh`。
- 旧帮助页构建：`build-help-highlight.sh`、`test-help-highlight.js`。
- 旧 Cronet：`cronet.sh`、`verify-cronet.sh`。

删除前检查 Git 工作区仅有既有清理文档修改，九个脚本没有未提交改动。
解析全部目标的绝对路径，确认它们均位于本仓库 `.github/scripts/`，不是目录或符号链接，
再使用 PowerShell `Remove-Item -LiteralPath` 删除明确文件，没有递归清理或修改其他脚本。

首批保留的工具与理由：

- `extract-latest-update.sh`、`test-extract-latest-update.sh`：用户暂时保留更新日志提取能力及配套测试，不在本轮改接 Flutter 日志。
- `lzy_web.py`、`tg_bot.py`：用户暂时保留两个分发渠道，不调用它们，也不更改账号或机器人配置。
- `.github/scripts/ci_changes.py`、`test_ci_changes.py`：composite action 和 CI 汇总门禁正在使用。
- `.github/scripts/backfill-labels.rb`：`triage-labels.yml` 仍有语法检查和手动历史标签回填入口。
- `rust/scripts/build-ios.sh`：历史 XCFramework 独有的 Intel 模拟器/Debug/stub 能力未迁移，正式 macOS 路径也待复验；此次不删除。
- `rust/scripts/gen_rar5_fixture.py`：Rust 归档测试注明样本由此生成，保留可重现来源。
- `scripts/` 中设备冒烟、搜索探针及视觉比对脚本：属于独立 QA 能力，不按扩展名清理。
- `flutter_legado/scripts/archive/`：已有历史隔离，本次不扩展到旧批次修复脚本裁决。

按授权清单直接删除旧实现与配套测试，不保留转发壳、不搬运失效功能。
当前入口文档未发现调用这些已删除文件，历史证据中的路径保留为历史记录。
本次没有运行测试、actionlint、构建、设备任务或 Actions，没有远端/设备通过证据。
用户已授权将删除与文档变更一并本地提交，使用 `[skip ci]`；本次授权不包含 push。
应用版本保持 `2.0.369+370`，文件删除不改变 workflow 触发、权限或发布行为。

补充编写者：Codex｜2026-10-11
