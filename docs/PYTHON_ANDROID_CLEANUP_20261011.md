# Android 构建入口与旧脚本删除范围

本文保留 Android 批次的方法与证据；后续 Windows/旧生成脚本和 Makefile 已清理，
当前 Windows 入口见 [Windows 工具说明](PYTHON_WINDOWS_TOOLING_20261011.md)。
Android Release 后续已接入统一 APK 校验与收集，当前命令见 [Release 工具说明](PYTHON_ANDROID_RELEASE_20261011.md)。

本文记录 `PYTHON-CLEANUP-20261011` 的命令与行为差异；状态只维护于
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。基线为 `cd5f97c99d7ebb1a123d764875cc90e88092bb2d`，
分支为 `feature/ui-android-script-cleanup`，应用版本保持 `2.0.369+370`。
实现提交为 `56fff0af4d8349e388ec3d4d209186c953a6fcf1`；本批不提供运行时通过声明。

## 当前命令

在仓库根目录使用已经配置 PATH 的 Flutter 与 Python 3.11+：

```powershell
# 编译 Rust、校验原生库、打包 Debug APK，再检查包内来源
python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64

# Release 分 ABI APK；armv7 预先关闭 QuickJS，不做失败降级
python scripts/dev.py build android --profile release --abis arm64-v8a,armeabi-v7a,x86_64 --split-per-abi

# 跳过 Rust 编译，仍检查当前 profile/ABI 的源码、工具与元数据
python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64 --skip-rust

# 单独只读检查最终 APK；只在临时副本中 strip
python scripts/dev.py verify apk android --profile debug --abis arm64-v8a,x86_64 --apk flutter_legado/build/app/outputs/flutter-apk/app-debug.apk

# 确认当前 adb 设备编号，再显式安装并启动
adb devices
python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64 --install --device <当前设备编号>
```

`--clean` 显式执行 `flutter clean`；`--ndk` 指定策略要求版本的 NDK；`--cargo-target-dir`
指定或核对 Cargo 输出目录。`--adb` 可显式选择 adb，未指定时查 PATH/SDK/local.properties，
不使用固定盘符。分 ABI 安装按设备报告的 ABI 选本次 APK；无对应 ABI、离线、安装失败
或启动未确认均失败，不报告安装成功。默认只构建，不自动触碰设备。

Flutter 的目标平台从同一 Android 策略读取，Gradle 使用当前 Python 解释器做只读校验。
Windows 通过 PATH 对应 SDK 的原生 Dart 启动现有 Flutter tool snapshot，避免批处理命令拼接；
SDK 未初始化时提示先运行 `flutter doctor`。本工具不安装或升级 Flutter、Rust、NDK、JDK。

APK 检查要求请求 ABI 的 Rust 库完整且唯一，与已严格校验的 jniLibs 经同一 NDK strip
正规化后的摘要一致。构建前删除本次请求的旧 APK 输出；编译、打包或校验失败立即返回非零。
该检查证明打包来源，不能替代真实 FFI 运行时冒烟。

## 已删除与保留

删除七个已被 Python 覆盖的入口，不提供转发壳：

| 旧文件 | 当前入口 |
|---|---|
| `rust/scripts/build-android.ps1`、`build-android.sh` | `build ffi android` |
| `rust/scripts/verify-ffi-android.ps1`、`verify-ffi-android.sh` | `verify ffi android` |
| `rust/scripts/rust-fingerprint.ps1`、`rust-fingerprint.sh` | `fingerprint rust` |
| `flutter_legado/scripts/build-apk.ps1` | `build android` |

原有调用方迁移包括模拟器脚本的构建段、Makefile 的 Android 目标、应用 FFI 错误提示、
CI 范围规则与当前开发文档；Makefile 不再实现 Android 编译/校验算法。
历史调查和旧批次证据保留原路径，不能再当作可执行入口。

`emulator_smoke_test.ps1` 保留进程、崩溃日志、版本、可选 UI/听书检查，构建段调用 Python，
必须明确传入当前 `-Device`，取消已弃用的固定雷电默认编号。
旧脚本曾混用 Rust Release 与 Flutter Debug，新入口依既定严格矩阵统一为 Debug/Debug；
本冒烟结果不能当作 Release 性能数据。`-SkipBuild` 仍沿用已有 APK 的设备 QA 路径。

Windows 构建/运行、旧 FRB PowerShell 入口中的 Windows DLL 操作、iOS 历史 XCFramework
脚本仍有本批未覆盖的能力，保留到对应平台迁移阶段；正式 iOS RustFFI/签名/图标接线未修改。

## 交付边界与回滚

按用户“跳过验证”的要求，本轮不运行 Python/Gradle/Dart 测试，不构建 APK，不连接设备，
不触发 Actions。新增测试覆盖 APK 来源、缺库/重复 ABI、合法 strip、失败阻断、安装选择与
Windows 启动参数，但本轮未执行；不据此宣称实际平台验收通过。

本批改变了 Rust 文件集合及工具输入，先前 FFI 元数据会失效。下次构建使用新命令成功编译后
重新产生元数据，不能为旧库补写当前指纹。Rust stable、Flutter/FRB/JDK 与应用版本保持原配置。
回滚仅回退本批代码/引用；恢复旧入口仍不能作为当前 Gradle v2 门禁的生产者，需重新构建库。

编写者：Codex｜2026-10-11
