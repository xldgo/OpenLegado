# Legado 开发者指南

> Legado 是一款开源网络文学阅读器，本项目为 Rust + Flutter 双端重构版本。

---

## 项目概述

本项目采用 **Rust 核心引擎 + Flutter 跨平台 UI** 架构，通过 `flutter_rust_bridge` (FFI) 连接两端：

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI 层                      │
│              (flutter_legado/)                       │
│     40 个页面 · 952 个测试 · 103+ FFI 函数            │
└────────────────────────┬────────────────────────────┘
                         │  flutter_rust_bridge (FFI)
┌────────────────────────▼────────────────────────────┐
│                    legado-ffi                        │
│           (cdylib / staticlib 入口)                  │
├──────────┬──────────┬──────────┬──────────┬─────────┤
│legado-   │legado-   │legado-   │legado-   │legado-  │
│parser    │net       │js        │book      │db       │
├──────────┴──────────┴──────────┴──────────┴─────────┤
│                   legado-core                        │
│            (公共类型 / 错误 / 工具)                   │
└─────────────────────────────────────────────────────┘

legado-server — 独立 HTTP 服务（axum + 53 REST + 5 WS + MCP）
```

### 核心能力

- **书源规则解析**：CSS / XPath / JsonPath / Regex 四解析器 + AnalyzeRule 统一门面
- **JS 沙箱引擎**：QuickJS 真实实现，40+ 宿主 API，java 命名空间兼容
- **网络引擎**：reqwest + 中间件链（重试/限流/Cookie）+ WebDAV 云同步
- **书籍格式**：EPUB / TXT / MOBI / PDF 解析 + 导出
- **数据库**：SQLite Schema v95 + 25 个 Repository + Room 数据导入
- **HTTP 服务**：axum REST API + WebSocket 实时通道 + MCP Server
- **Flutter UI**：书架 / 阅读器 / 搜索 / 书源管理 / 设置 / RSS 等 40 个页面

---

## 环境配置

### 1. Rust 工具链

```bash
# 安装 rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup install stable
```

> **Windows 注意**：若 `cargo` 命令不可识别，在 PowerShell 中执行：
> ```powershell
> $env:PATH = "C:\Users\<用户名>\.cargo\bin;$env:PATH"
> ```

### 2. Flutter SDK

参考官方文档：https://flutter.dev/docs/get-started/install

当前工程使用 Flutter 3.47.7（随附 Dart 3.13.5）：
```bash
flutter --version
```

### 3. flutter_rust_bridge CLI

```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
```

### Python 工程工具

安装 Python 3.11 或更新版本后，在仓库根目录执行：

```powershell
python scripts/dev.py fingerprint rust
python scripts/dev.py test tooling
```

Android FFI 的严格只读校验、元数据格式和现有流程迁移边界见
[Python 工具说明](过期文档/PYTHON_FFI_TOOLING_20261010.md)。Android 旧脚本已删除，旧元数据不会自动转换。
Python 代码生成和 Android FFI 编译命令见 [构建入口说明](PYTHON_FFI_BUILD_20261011.md)；
生成绑定与重编原生库分别执行。Android Gradle 与两处 Android CI 已接入 Python，
解释器配置、Mock 限制及未迁移入口见 [Gradle 接线](PYTHON_GRADLE_FFI_20261011.md)。
APK 构建、可选安装与删除范围见 [Android 入口说明](PYTHON_ANDROID_CLEANUP_20261011.md)。

### 4. C 编译器（QuickJS 需要）

- **Windows**: Visual Studio Build Tools (MSVC)
- **Linux**: `build-essential`
- **macOS**: Xcode Command Line Tools
- **iOS 原生校验**：在 `rust/` 执行 `rustup component add llvm-tools-preview`；静态库使用当前 Rust 自带的 `llvm-nm`，最终应用仍使用 Xcode `nm`。

### 5. 验证环境

```bash
cargo --version
flutter --version
flutter_rust_bridge_codegen --version
```

---

## 目录结构

```
legado/
├── rust/                        # Rust workspace（8 个 crate）
│   ├── legado-core/             # 公共基础层：数据模型、加密、排版、换源、WebBook
│   ├── legado-parser/           # 书源规则解析：CSS/XPath/JsonPath/Regex/AnalyzeUrl
│   ├── legado-net/              # 网络引擎：HTTP/Cookie/RSS/WebDAV/中间件
│   ├── legado-js/               # JS 沙箱：QuickJS + 40+ 宿主 API
│   ├── legado-book/             # 书籍格式：EPUB/TXT/MOBI/PDF 解析与导出 + TXT 搜索
│   ├── legado-db/               # 数据库：SQLite Schema v95 + 17 Repository
│   ├── legado-ffi/              # FFI 出口：flutter_rust_bridge 聚合层
│   ├── legado-server/           # HTTP 服务：axum REST + WS + MCP
│   ├── Cargo.toml               # Workspace 配置
│   ├── DEVELOPMENT.md           # Rust 端详细开发文档
│   └── PROGRESS.md              # 历史任务记录；当前进度见 docs/REFACTORING_ACTIVE_PLAN.md
├── flutter_legado/              # Flutter 跨平台 UI
│   ├── lib/                     # Dart 源码
│   ├── test/                    # Flutter 测试（24 个文件）
│   ├── scripts/                 # 构建/代码生成脚本
│   └── pubspec.yaml             # Flutter 依赖配置
├── .github/workflows/           # CI/CD 工作流
├── CHANGELOG.md                 # 版本更新日志
└── DEVELOPMENT.md               # 本文件
```

Android 原版源码及其 Gradle 构建文件不随本仓库分发；需要原版测试时另备完整工程。Flutter Android 使用 `flutter_legado/android/` 内的独立 Gradle 配置。

---

## 构建命令

### Rust

```bash
cd rust

# 编译检查（最快）
cargo check --workspace

# Debug 构建
cargo build --workspace

# Release 构建（服务端部署）
cargo build --release -p legado-server

# Android 交叉编译（Windows）
python ../scripts/dev.py build ffi android --profile release --abis arm64-v8a,armeabi-v7a,x86_64
```

### Flutter

```bash
cd flutter_legado

# 安装依赖
flutter pub get

# 运行（热重载）
flutter run

# 构建 APK
python ../scripts/dev.py build android --profile release --abis arm64-v8a,armeabi-v7a,x86_64 --split-per-abi

# Windows 桌面构建
python ../scripts/dev.py build windows --profile debug
# Windows 开发会话（先重编 DLL，保留热重载）
python ../scripts/dev.py run windows --profile debug
```

### FFI Bridge 代码生成

Rust API 变更后需重新生成 Dart bindings：

```bash
cd flutter_legado
python ../scripts/dev.py generate bridge
# 只读隔离复核
python ../scripts/dev.py generate bridge --check
```

### Makefile（2026-09-22 归档）

> 根目录 `Makefile` 已移入 `docs/过期文档/Makefile` 归档（`过期文档/PENDING_DELETE_20260920.md` §P4，已归档）：当前开发环境为 Windows、无 `make` 命令（见 AGENTS.md「关键约束」），且 `make build`/`make gen` 等目标已不存在。
> Flutter 子目录的 Makefile 也已删除。生成、Android/Windows 编排使用 `python scripts/dev.py`；检查/测试/独立清理使用 Cargo/Flutter 原生命令，见 AGENTS.md「验证命令」。Windows 参数和未测边界见 [Windows 工具说明](PYTHON_WINDOWS_TOOLING_20261011.md)。

---

## 测试命令

### Rust 测试

```bash
cd rust

# 全 workspace 测试（默认，不含 QuickJS）
cargo test --workspace

# 含 QuickJS feature 的完整测试
cargo test -p legado-js --features quickjs

# 测试单个 crate
cargo test -p legado-core
cargo test -p legado-parser
cargo test -p legado-net
cargo test -p legado-js
cargo test -p legado-book
cargo test -p legado-db
cargo test -p legado-ffi
cargo test -p legado-server
```

### Flutter 测试

```bash
cd flutter_legado
flutter test
```

### 测试统计

| 组件 | 测试数 | 说明 |
|------|--------|------|
| Rust workspace（默认） | 1409 | 8 个 crate 全量测试 |
| Rust QuickJS feature | 327 | legado-js 含 QuickJS 额外测试 |
| Rust legado-ffi | 105 | FFI 导出函数测试 |
| Flutter | 952 | Widget + 单元测试（2026-08-02 实测，Phase 5.4 去重 bookshelf_provider_test 后） |
| **总计** | **2361** | |

---

## 质量门禁

所有代码提交前必须通过以下检查（零问题）：

### Rust

```bash
cd rust

# Clippy lint（-D warnings 严格模式）
cargo clippy --workspace --all-targets -- -D warnings

# 格式化检查
cargo fmt --all -- --check

# 格式化修复
cargo fmt --all
```

### Flutter

```bash
cd flutter_legado

# 静态分析
flutter analyze
```

### CI 流水线

Flutter/Rust 自动检查针对 `dev/master` push 和指向这两个分支的 PR，
按改动选择任务；开发分支可通过PR或手动入口验证。Rust CI对默认功能与QuickJS运行
全目标Clippy，执行一次QuickJS工作区测试及依赖审计；不再默认/QuickJS重复跑整套测试。
Flutter CI执行分析与测试；页面、状态编排及渲染改动走普通组，桥接、数据、契约等输入
再触发Linux原生组。手动native/all范围仍可完整复核原生组。

Tooling CI 集中运行编排回归、Python 工具回归与 workflow 语法检查，也可手动运行；
其他 workflow 的范围判定步骤只读取 Git 差异。iOS Build 仅对 dev/master 的应用相关改动
自动构建设备包，其他分支手动；iOS CI 保持仅手动模拟器验证。Integration Smoke已移除，
Android/Windows平台构建通过Release的Tag发布与手动只构建入口验证。

任务范围、门禁语义与轻量回归命令见 [CI 编排说明](CI_ORCHESTRATION_20261010.md)。
工具的原生输入由 `scripts/tooling/input_scopes.py` 统一分类：平台原生模块只影响自身，
打包工具不进入 Rust 库指纹，共享与尚未分类的工具影响三个原生平台的构建输入；
自动CI只选择仍有消费者的任务，不为Android/Windows额外启动原生冒烟。

---

## 版本与发布

### 当前版本

| 组件 | 版本 | 说明 |
|------|------|------|
| 整体项目 | v4.0.0-alpha | Git tag 格式 |
| Rust crates | 0.2.0 | Workspace 统一版本 |
| Flutter app | 2.0.0+2 | pubspec.yaml |

### Git 提交规范

项目使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范：

```bash
git commit -m "feat: 新增书源批量导出功能"
git commit -m "fix: 修复阅读器翻页闪烁"
git commit -m "perf: 优化引擎池化内存占用"
```

类型前缀：`feat` / `fix` / `perf` / `refactor` / `docs` / `test` / `chore` / `ci`

### 发布流程

1. 确保所有测试通过 + 质量门禁零问题
2. 更新 `CHANGELOG.md`
3. 递增版本号（Cargo.toml + pubspec.yaml）
4. `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. 先推送已审核的发布提交（`git push origin HEAD`），再只推送本次 tag（`git push origin vX.Y.Z`）；发布入口为 [release.yml](../.github/workflows/release.yml)。

---

## 相关链接

- [Rust 端详细开发文档](../rust/DEVELOPMENT.md) — 架构设计、代码结构、调试技巧
- [当前任务与进度](REFACTORING_ACTIVE_PLAN.md) — 唯一开放任务入口；旧 Rust 任务记录仅作历史参考
- [更新日志](../CHANGELOG.md) — 版本历史记录
- [Flutter 客户端](../flutter_legado/README.md) — UI 层文档
- [上游 Legado 项目](https://github.com/gedoor/legado) — Kotlin 原版
- [本项目仓库](https://github.com/xldgo/OpenLegado) — Rust+Flutter 版

修订者：Codex 主代理｜2026-10-10（修正仓库、发布与当前进度入口；同步旧 Gradle 文件删除范围）
