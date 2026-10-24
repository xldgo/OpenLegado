# Legado — Rust + Flutter 跨平台阅读器

[![Rust CI](https://github.com/xldgo/OpenLegado/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/xldgo/OpenLegado/actions/workflows/rust-ci.yml)
[![Flutter CI](https://github.com/xldgo/OpenLegado/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/xldgo/OpenLegado/actions/workflows/flutter-ci.yml)

Legado（阅读）是一款免费开源的小说阅读器，正在从 Android 原生 Kotlin 架构迁移为 **Rust 核心引擎 + Flutter UI** 的跨平台架构。

---

## 项目结构

```
├── rust/               # Rust 核心引擎（11 个 crate）
│   ├── legado-core/    # 公共基础层（数据模型、错误、加密）
│   ├── legado-parser/  # 书源规则解析（CSS/XPath/JsonPath/Regex）
│   ├── legado-net/     # HTTP 网络引擎（reqwest + 中间件）
│   ├── legado-js/      # JavaScript 沙箱（QuickJS）
│   ├── legado-book/    # 书籍格式解析（EPUB/TXT/MOBI/PDF）
│   ├── legado-db/      # SQLite 数据库（rusqlite）
│   ├── legado-layout/  # 纯计算排版内核
│   ├── legado-fetcher/ # 共享书源抓取与规则编排
│   ├── legado-engine/  # 资源装配、实例状态与任务生命周期
│   ├── legado-ffi/     # FFI 出口（flutter_rust_bridge）
│   └── legado-server/  # HTTP 服务（axum）
├── flutter_legado/     # Flutter UI 层（页面与专属状态按 Feature 组织）
└── CHANGELOG.md        # 更新日志
```

Flutter 页面与专属状态位于 `flutter_legado/lib/src/features/`；共享领域契约、数据服务、
平台能力及应用装配保持独立。目录归属见 [页面与状态组织方案](docs/FEATURE_FIRST_PAGE_DECOMPOSITION_20261017.md)。

Android 原版源码及其 Gradle 工程不随本仓库分发；语义对照或原版测试需另备完整原版工程。当前 Android 构建入口在 `flutter_legado/android/`。

---

## 快速开始

### 环境要求

- Rust stable（见 `rust/rust-toolchain.toml`）
- Flutter SDK 3.47.7（随附 Dart 3.13.5）
- iOS 15+、Android API 24+；iOS 构建需要 macOS / Xcode
- Android Rust FFI 与 Flutter Gradle 统一使用 NDK 28.2.13676358（r28c）

### 编译与测试

```powershell
# Rust 检查与测试
cd rust
cargo test -p legado-ffi --features quickjs

# Flutter
cd ..\flutter_legado
flutter pub get
flutter analyze
flutter test
```

详细开发指南见 [rust/DEVELOPMENT.md](rust/DEVELOPMENT.md) 与 [AGENTS.md](AGENTS.md)。
Python 指纹与 Android FFI 只读校验的命令和迁移边界见
[工程工具说明](docs/过期文档/PYTHON_FFI_TOOLING_20261010.md)。
Android Rust/APK 构建统一使用 `python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64`，
其参数与清理范围见 [Android 构建入口](docs/过期文档/PYTHON_ANDROID_CLEANUP_20261011.md)。
MuMu一键构建、覆盖安装并启动（默认Debug，固定x86_64独立APK）：

```powershell
python scripts/dev.py build android --emulator mumu --install
```

自动查询已启动的MuMu并连接ADB，已连接时直接复用；多个运行实例追加 `--device <设备编号>`。
通过PATH或Windows安装信息定位MuMuManager，读取实例实际端点，不写死端口，也不自动启动模拟器。
WSL支持读取宿主Windows安装信息并转换路径，关闭Windows PATH继承时也可自动发现；需要启用Windows互操作。
连接最多等待10秒，失败显示端点和原因；不会重启共享ADB服务。找不到MuMuManager时仍可使用已连接实例。
Rust库通过现有指纹、ABI、模式与摘要校验就自动复用，否则重新编译；失败不使用旧库兜底。
沿用默认MainActivity启动，最多等待30秒确认应用初始化完成，同时检查初始化失败及未处理异常；不清除应用数据。
每次日志覆盖保存至 `build/mumu/build-install.log`。使用其他当前目录时指定 `dev.py` 的绝对路径。

Android Release 的分 ABI APK 校验与收集复用同一工具，命令见 [Release 工具说明](docs/过期文档/PYTHON_ANDROID_RELEASE_20261011.md)。
Windows 使用 `python scripts/dev.py build windows --profile debug` 构建，
`python scripts/dev.py run windows --profile debug` 启动开发会话；参数见 [Windows 工具说明](docs/PYTHON_WINDOWS_TOOLING_20261011.md)。
iOS 正式静态库使用 `python scripts/dev.py build ffi ios --target device --profile release`；
模拟器将 `device` 改为 `simulator`。这些命令需要 macOS/Xcode，接线与校验见 [iOS 工具说明](docs/PYTHON_IOS_TOOLING_20261011.md)。
iOS 图标兼容处理、plist 诊断和 IPA 打包也使用该 Python 入口；IPA 打包与签名分别执行，命令见同一说明。

---

## GitHub Actions

| 工作流 | 职责与触发 |
| --- | --- |
| [Rust CI](.github/workflows/rust-ci.yml) | dev/master push、PR 按改动执行双功能档Clippy、一次QuickJS工作区测试与审计；支持手动完整检查 |
| [Flutter CI](.github/workflows/flutter-ci.yml) | dev/master push、PR 按改动执行 Dart 分析与测试；支持手动完整检查 |
| [iOS CI](.github/workflows/ios-ci.yml) | **仅手动**运行模拟器编译、图标状态检查和离线搜索阅读测试，不作为 PR 必需检查 |
| [iOS Build](.github/workflows/ios-build.yml) | dev/master 的应用相关改动自动构建设备 IPA，其他分支手动；签名配置见 [iOS 构建说明](docs/IOS_CI_SIGNING_SETUP.md) |
| [Release](.github/workflows/release.yml) | 手动选择平台及是否发布（默认只构建）；正式`vX.Y.Z` tag发布，Alpha使用独立构建标签 |
| [PR Code Review](.github/workflows/pr-review.yml) | 同仓库非草稿、非机器人 PR 添加 `review` 标签后审查；保留标签时随提交更新重审 |
| [Triage Labels](.github/workflows/triage-labels.yml) | 自动按内容与路径打标签；历史 Issue/PR 标签回填仅手动运行 |
| [Stale Issues](.github/workflows/stale.yml) | 按 30+5 天参数清理 Issue；豁免 `confirmed`、`in-progress` 标签，不自动处理 PR |

[Dependabot](.github/dependabot.yml) 每周检查 Actions、Rust Cargo 和 Flutter pub，每月检查 Flutter Android Gradle；普通版本更新 PR 指向 `dev`，小版本更新分组，FRB 由专项配套升级。安全更新仍针对默认分支，不新增自动合并规则。首次使用自动审查与 stale 豁免前，请在仓库创建 `review`、`confirmed`、`in-progress` 标签；新平台和语言的路径标签由标签工作流按需创建。

工作流与现有脚本的当前进度、审查及验证证据统一记录于 [Active 计划](docs/REFACTORING_ACTIVE_PLAN.md)，自动化配置与检查方法见 [自动化整理证据](docs/过期文档/CI_AUTOMATION_REVIEW_20261010.md)。Dependabot 配置和默认分支上的定时/Issue 自动化需在用户审核、提交并进入默认分支后生效。

编写者：Codex 主代理｜2026-10-10

---

## 文档

| 文档 | 内容 |
|------|------|
| [AGENTS.md](AGENTS.md) | Agent 工作入口与验证命令 |
| [rust/README.md](rust/README.md) | Rust 引擎架构与 Crate 说明 |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | FFI 与领域接口契约 |
| [docs/AUDIT_FIX_TASKS_20260814.md](docs/过期文档/AUDIT_FIX_TASKS_20260814.md) | 审计修复任务清单（已归档，仅供追溯） |
| [CHANGELOG.md](CHANGELOG.md) | 版本更新日志 |

---

## 版本与发布

- 当前版本：**2.0.60+62**（Flutter `pubspec.yaml`）
- 功能基准：Android 原版 `com.legado.app.release` 3.26081008
- 版本规范：[语义化版本](https://semver.org/lang/zh-CN/)
- 提交规范：中文说明 + `[Rust]` / `[UI]` / `[docs]` 前缀

---

## 致谢

基于 [gedoor/legado](https://github.com/gedoor/legado) 开源项目。

修订者：Codex 主代理｜2026-10-10（同步仓库自动化说明，清理旧 Gradle 入口并明确原版参考范围）
