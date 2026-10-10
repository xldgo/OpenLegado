# Legado — Rust + Flutter 跨平台阅读器

[![Rust CI](https://github.com/xldgo/OpenLegado/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/xldgo/OpenLegado/actions/workflows/rust-ci.yml)
[![Flutter CI](https://github.com/xldgo/OpenLegado/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/xldgo/OpenLegado/actions/workflows/flutter-ci.yml)

Legado（阅读）是一款免费开源的小说阅读器，正在从 Android 原生 Kotlin 架构迁移为 **Rust 核心引擎 + Flutter UI** 的跨平台架构。

---

## 项目结构

```
├── rust/               # Rust 核心引擎（8 个 crate）
│   ├── legado-core/    # 公共基础层（数据模型、错误、加密、排版）
│   ├── legado-parser/  # 书源规则解析（CSS/XPath/JsonPath/Regex）
│   ├── legado-net/     # HTTP 网络引擎（reqwest + 中间件）
│   ├── legado-js/      # JavaScript 沙箱（QuickJS）
│   ├── legado-book/    # 书籍格式解析（EPUB/TXT/MOBI/PDF）
│   ├── legado-db/      # SQLite 数据库（rusqlite）
│   ├── legado-ffi/     # FFI 出口（flutter_rust_bridge）
│   └── legado-server/  # HTTP 服务（axum）
├── flutter_legado/     # Flutter UI 层（62 个 Screen 页面）
├── app/                # [旧] Android 原生 Kotlin 代码
├── modules/            # [旧] Android 子模块（rhino/web/book）
└── CHANGELOG.md        # 更新日志
```

---

## 快速开始

### 环境要求

- Rust stable（见 `rust/rust-toolchain.toml`）
- Flutter SDK >= 3.8.0
- Android NDK r26+（交叉编译时需要）

### 编译与测试

```powershell
# Rust 检查与测试
cd rust
cargo test -p legado-ffi --features quickjs

# Flutter
cd flutter_legado
flutter pub get
flutter analyze
flutter test
```

详细开发指南见 [rust/DEVELOPMENT.md](rust/DEVELOPMENT.md) 与 [AGENTS.md](AGENTS.md)。

---

## GitHub Actions

| 工作流 | 职责与触发 |
| --- | --- |
| [Rust CI](.github/workflows/rust-ci.yml) | 自动执行质量检查、默认/QuickJS 测试与依赖审计 |
| [Flutter CI](.github/workflows/flutter-ci.yml) | 自动执行 Dart 分析与测试，不等待 Android 原生构建 |
| [Integration Smoke](.github/workflows/integration-smoke.yml) | Windows 真实 FFI 冒烟与 Android FFI 构建校验，可自动或手动执行 |
| [iOS CI](.github/workflows/ios-ci.yml) | **仅手动**运行模拟器编译、图标状态检查和离线搜索阅读测试，不作为 PR 必需检查 |
| [iOS Build](.github/workflows/ios-build.yml) | 保留设备 IPA 自动构建与手动入口；签名配置见 [iOS 构建说明](docs/IOS_CI_SIGNING_SETUP.md) |
| [Android Release](.github/workflows/android-release.yml) | 手动运行只生成 Android APK 工件，`v*` tag 触发构建并发布 |

标签、自动审查和其他仓库自动化保留独立入口。工作流与现有脚本的当前进度、审查及验证证据统一记录于 [Active 计划](docs/REFACTORING_ACTIVE_PLAN.md)。

编写者：Codex 主代理｜2026-10-10

---

## 文档

| 文档 | 内容 |
|------|------|
| [AGENTS.md](AGENTS.md) | Agent 工作入口与验证命令 |
| [rust/README.md](rust/README.md) | Rust 引擎架构与 Crate 说明 |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | FFI / BookApi 契约 |
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
