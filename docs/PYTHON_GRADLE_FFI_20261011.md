# Gradle 接入 Python FFI 校验

本文保存 Gradle 接线批次的方法与验收证据。后续 Android 旧入口已删除，
APK 编排与设备 QA 构建段已迁到 Python，见 [Android 构建入口](PYTHON_ANDROID_CLEANUP_20261011.md)。
本文的 build-apk/emulator 待迁移记录属于该批次历史边界。

本文记录 `PYTHON-GRADLE-20261011` 的方法和证据；状态只在
[Active 计划](REFACTORING_ACTIVE_PLAN.md) 维护。基线 `85f4827d9`，分支
`feature/ui-gradle-ffi-validation`。按用户要求主代理执行，不使用子代理；应用版本
`2.0.369+370`，Flutter 3.47.7、FRB 2.13.0、Rust stable 保持。

## 构建分工与变化

- 独立 `python scripts/dev.py build ffi android ...` 编译 Rust、复制库和生成 v2 元数据。
- Gradle 的 `preDebugBuild`、`preReleaseBuild`、`preProfileBuild` 分别依赖只读校验任务。
  Profile 使用 release Rust 库；不通过请求的任务名称猜测模式。手动入口
  `verifyRustFfiLibs` 继续校验 Debug，Release 可调用 `verifyReleaseRustFfiLibs`。
- 薄适配保存在 `flutter_legado/android/ffi-verification.gradle.kts`，调用同一
  `scripts/dev.py verify ffi android`。不调用 Cargo，不修复、不回填缺失元数据。
  Gradle 中原有连续四字节扫描、仅比 FRB hash 的旧元数据放行已移除。
- ABI/Flutter 平台映射读取 `android-policy.json`。显式 `target-platform` 决定请求 ABI；
  未指定时 Debug 为 arm64/x86_64，Release/Profile 为三 ABI。普通 APK 的 build type
  ABI 过滤与校验请求一致；分 ABI 构建继续交给 Flutter splits，避免过滤器冲突。
  当前策略不支持 armv7 Debug，显式请求时失败，不用 release 库代替。
- 校验任务没有输出缓存，每次执行重新读取源码、库和元数据；声明式属性与注入的
  ExecOperations 避免捕获 Gradle 脚本对象。策略文件通过 fileContents provider 读取，
  改变 ABI 策略时配置缓存也必须失效。

任务实现依据 [Gradle 服务注入](https://docs.gradle.org/8.14/userguide/service_injection.html)
及 [配置缓存要求](https://docs.gradle.org/8.14/userguide/configuration_cache_requirements.html)。

## Python 环境与命令

Python 3.11+ 为 Android Gradle 构建的明确依赖。解释器选择：
`-PlegadoPython=<单个可执行路径>` → `PYTHON` 环境变量 → Windows 的 `python` 或其他
平台的 `python3`。参数数组传递路径，不把参数或可执行路径拼成 shell 命令。
不自动安装 Python，缺少解释器或校验失败会阻止构建。

根目录 PowerShell 示例：

```powershell
python scripts/dev.py build ffi android --profile debug --abis arm64-v8a,x86_64
Set-Location flutter_legado
flutter build apk --debug --target-platform android-arm64,android-x64
```

上述 APK 命令是后续使用入口，本批按用户要求未执行 APK 构建。
Android Studio 的 Gradle 环境也需要找到 Python；可设置 `PYTHON`，或在本机 Gradle
配置中设置 `legadoPython`，不要将个人路径提交到仓库。

`LEGADO_SKIP_RUST_BUILD=1` 仅在本地 Debug、Dart defines 中恰好一条 `USE_MOCK=true`
且没有冲突时允许跳过。Release/Profile、CI/GitHub Actions 中禁止绕过，错误编码也失败。
仅传 Mock define 或仅设置跳过变量都不能绕过；Mock 只用于纯 UI 本地开发。

## CI 与旧入口

Android Release 和 Integration Smoke 的 Android 作业此前产出旧格式元数据，不能满足
新门禁。本批同步将其 Rust 编译、复制/strip、元数据与校验步骤接入已验证的 Python
入口，保留原 ABI/QuickJS 策略、NDK 版本、Rust stable、缓存和超时。

Job 名称、触发条件、权限、Tag 发布条件、签名、artifact ID 传递以及最终 APK
NDK strip 正规化校验保持；Windows/iOS 正式构建路径保持。
用户于 2026-10-11 要求跳过后续验证，本批未运行 routing、原生作业或发布。

旧 sh/ps1 暂不删除。旧 Android 编译脚本会写旧元数据，不能作为新 Gradle 门禁的
生产者；使用 Python 构建入口。build-apk/emulator 辅助入口及其他平台仍待迁移，
不能用修改 `.meta` 或跳过验证掩盖旧脚本不兼容。

## 验证证据与边界

实现提交 `5b841ae44c904943b7f0b39c4d046961aa686838`。用户叫停前的结果如下；
后续验证按用户要求跳过：

- Python 69 项工具测试中 66 项通过、3 项因 Windows 宿主能力限制跳过；9 份 workflow
  的 actionlint 与差异检查通过。
- 10 项真实 Gradle fixture 测试通过：Debug/Release/Profile 接线、指定 ABI、配置缓存命中后源码
  变化拒绝旧库、策略变化重选 ABI、旧/缺元数据只读失败、缺解释器、非零返回、
  本地 Mock 条件、CI/Release 禁止跳过、错误/冲突 defines 和未知/重复平台。
- Windows 双 ABI Debug QuickJS 构建成功，生成当前工具输入对应的 v2 元数据。
- 实际 Android 工程尝试执行 `preDebugBuild`，在 AGP 依赖的 Gradle 缓存目录重命名
  阶段遇到 `AccessDeniedException`；尚未执行到 FFI 校验。独立短路径缓存复验随后停止，
  不将 fixture 成功写成实际工程成功。
- 本机原有 PATH 的 Java 为 GraalVM JDK 24，本轮此前 fixture 使用它；工程 source/
  target 和 CI 仍为 Java 17，没有安装或升级 JDK、没有改全局 PATH。JDK 24 验证进程
  已停止；计划的临时 JDK 17 下载未执行，Java 17 验收未完成。
- 未运行本批 Linux routing、NDK Linux/macOS 构建、Release/最终 APK、Android
  运行时或设备验收；后续复验边界保留。

Gradle fixture 命令（填写本机已经安装的 Gradle 8.14 目录）：

```powershell
$env:LEGADO_TEST_GRADLE_HOME = '你的 Gradle 安装目录'
$env:LEGADO_TEST_JAVA = '你的 JDK 17 目录\bin\java.exe'
python tests/gradle/test_ffi_verification.py
```

没有指定运行环境时该独立测试组会明确跳过，不能作为通过证据。本地证据保存在
忽略目录 `.tmp_ci_workflow_validation/`，提交正文只描述改动。
回滚时同时回退 Gradle 接线与两处 Android CI 生产者；旧生成物不要手动转换格式。

编写者：Codex｜2026-10-11
