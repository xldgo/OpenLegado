# Windows Python 构建与运行入口

本文记录 `PYTHON-WINDOWS-20261011` 的命令、行为差异与交付边界；状态仅维护于
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。基线为 `01cec318cd963316f2d2939d3b4affe33dad570f`，
分支为 `feature/ui-python-windows-tooling`，应用版本保持 `2.0.369+370`。
实现提交为 `7f9293595e150e4945d24f7311224abdb3e2f5ab`，实际构建与运行结果本轮未验收。

## 命令

2026-10-18在Flutter 3.47.7完成正式Windows x64 Release构建及最终DLL来源校验。
该SDK的Windows命令不接受`--target-platform`，Python入口使用宿主默认架构；当前
Rust入口限定x64 MSVC，应用产物也核对在x64目录。若本机换过JDK但CMake仍引用旧JNI
路径，可在对应构建目录重新配置时清除`JAVA_*`缓存，无需修改插件或项目依赖。
本次仅验证编译与打包，不代表动效和平台功能已完成运行验收，状态与证据见Active计划。

以下命令在仓库根目录使用 Python 3.11+；从其他目录调用入口也按脚本位置定位仓库。

```powershell
# 独立编译当前 Rust DLL，生成来源元数据
python scripts/dev.py build ffi windows --profile debug
python scripts/dev.py build ffi windows --profile release

# 只读校验当前源码、绑定、模式、feature、库摘要与 Cargo 来源
python scripts/dev.py verify ffi windows --profile debug

# 构建 Windows 应用，不自动启动
python scripts/dev.py build windows --profile debug
python scripts/dev.py build windows --profile release

# 编译 DLL 后启动 Flutter 开发会话，保留热重载
python scripts/dev.py run windows --profile debug

# 显式清理当前 target 的 legado-ffi，应用命令同时执行 flutter clean
python scripts/dev.py build windows --profile debug --clean

# 原 Makefile 的显式 stub 开发能力，仅 Debug 允许
python scripts/dev.py run windows --profile debug --no-quickjs

# 生成绑定与重编原生库分别执行
python scripts/dev.py generate bridge
python scripts/dev.py generate bridge --check
```

构建/运行需要 Windows x64、Rust MSVC host 和 Flutter Windows 原生工具链。
`--cargo-target-dir` 或 `CARGO_TARGET_DIR` 可选已安装环境的输出目录，不写死用户路径。
只读 Windows DLL 校验不依赖 Windows 宿主，可在其他系统检查已有 PE 文件及元数据。

默认启用 QuickJS，CI Windows Smoke 固定使用 Debug QuickJS；`--no-quickjs` 是显式开发选项，
会输出能力降级说明，Release 拒绝，编译失败不会自动重试无 QuickJS。
`run windows` 通过一次 `flutter run` 构建并启动，避免先执行重复的 Flutter build；
命令保持到开发会话退出。`build windows` 完成后直接交付应用路径。

## 产物来源与复制

Cargo 使用项目 stable 工具链、`--locked`、明确的 `x86_64-pc-windows-msvc` target/profile/features。
需要成功返回及 JSON 产物记录；旧 DLL 的存在不能替代本次成功编译。
实际 Cargo 文件位于 `<target-dir>/x86_64-pc-windows-msvc/<profile>/legado_ffi.dll`，
成功后复制到 `<target-dir>/<profile>/legado_ffi.dll`，维持现有 CMake/Dart 的默认搜索布局。

DLL 旁记录 `.dll.meta` schema v2，使用独立的 `windows-ffi-inputs-sha256-v2` 输入标识，
包含 Rust 实际字节指纹、共享及 Windows 原生工具指纹、FRB 契约、target/profile/features、源库/复制摘要
及工具版本诊断信息。校验只读；旧或缺失元数据需要用新命令重编，不能补写指纹。
PE 检查限定基本 x64 DLL 头，不能替代运行时装载、导出符号或真实 FFI 调用。

2026-10-11 起，应用编排位于 `windows_app.py`，原生 DLL 构建与校验位于 `windows.py`；
平台输入由 `input_scopes.py` 统一维护，CLI、应用打包及其他平台工具不进入 Windows DLL 指纹。
本次算法从 v1 迁移至 v2，需要正式重建后生成元数据。

Python 将当前 Cargo 输出目录通过子进程环境 `LEGADO_RUST_FFI_DIR` 交给 CMake。
Debug 取 Debug DLL，Profile/Release 取 Release DLL；移除缺库时跨 profile 复制 Release 的回退。
新入口构建前同步已有应用目录的库，构建后再次核对来源及最终复制摘要。
旧 exe 输出在构建前移除，避免未产生新 exe 时误用残留。复制或占用失败立即报错，
要求用户手动关闭应用，不按进程名强制结束任何应用。

CMake 对直接 Flutter Mock 开发仍保留 OPTIONAL。只有通过 Python 的真实构建完成严格来源
校验；直接 `flutter build/run` 不会自动生成 DLL 元数据，不能作为本工具的同等校验证据。

## 删除与调用迁移

删除下列六个文件，不保留转发壳：

| 旧入口 | 当前方式 |
|---|---|
| `build-windows.ps1`、`build-windows.bat` | `build windows`；需要启动时另用 `run windows` |
| `run-windows.ps1` | `run windows` |
| `generate-bridge.ps1`、`generate-bridge.sh` | `generate bridge`；原生库另行编译 |
| `flutter_legado/Makefile` | 平台编排使用 Python；检查、测试、独立清理使用 Cargo/Flutter |

除 Makefile 外，表内旧文件均位于 `flutter_legado/scripts/`。
原 Makefile 的 QuickJS/stub 开发分支已显式迁移；生成不再绑定 DLL 编译。
旧生成 Bash 的 Linux/macOS 原生编译副作用取消，这两种宿主仍可显式使用原生 Cargo 命令，
不将 Windows CLI 伪装成它们的原生构建。正式 iOS RustFFI 路径留到下一批。

Integration Smoke 的 Windows Job 改用同一 Python build/verify，保留原 Job 名称、触发条件、
权限、缓存、Flutter 版本和真实 `ffi_smoke_test.dart` 命令；本批未触发工作流。
Windows/Android 共用 Cargo JSON 产物确认函数；Android 编译矩阵及发布流程保持。
有效文档、FRB 配置注释和应用错误提示均改用新命令；历史调查记录保留原路径作为证据。

## 未测边界与回滚

用户要求跳过验证：本轮未运行工具测试、actionlint、Flutter/Cargo 构建、应用、设备或 Actions。
新增 11 项 Windows fixture 测试及一项 CI 接线断言但未执行，不宣称 Windows 实际可用或
跨平台校验通过。既有 Android APK/JDK 17 以及 iOS 验收边界保持未测。

SDK/JDK/FRB/应用版本与 Rust stable 配置保持。本批工具输入变化会使此前元数据失效，
下次使用新入口编译并重新写入；不在本轮为旧库伪造元数据。
回滚可撤销本批 CLI、CMake 和 CI 接线；旧无元数据 DLL 应重新编译，不能将回退旧文件作为
新只读校验通过的证据。iOS 静态库、CocoaPods、图标、签名与 IPA 发布步骤未修改。

编写者：Codex｜2026-10-11
