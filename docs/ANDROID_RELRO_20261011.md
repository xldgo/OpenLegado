# Rust Android RELRO 修复记录

任务：`ANDROID-RELRO-20261011`。当前状态见 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。

## 根因与范围

AGP 迁移后的实际 ELF 检查发现，Rust NDK 27 构建只设置
`max-page-size=16384`。LOAD 对齐通过，但 ARM64/x86_64 的 RELRO 末尾余数分别为
4096/12288。用户同意从 `1325e1e58` 开始单独修复，保持 AGP 提交独立。

[Android 官方说明](https://developer.android.com/guide/practices/page-sizes#relro)
要求 NDK 27 及以下同时设置 `max-page-size=16384` 与 `common-page-size=16384`；
RELRO 虚拟地址加内存长度的末尾必须按 16 KB 对齐。

三个 Android target 在 `rust/.cargo/config.toml` 统一配置；机器相关的 linker 路径
仍由本机/CI 提供。PS、Bash 及现有 Android Release/Integration Smoke 在复制前调用
`rust/scripts/verify-android-elf.py`（Python 3 标准库，无额外依赖）。校验同时覆盖 LOAD
和 RELRO，PS 的旧库复用路径也须通过。
不修改业务、FFI 契约、依赖、签名或第三方库；应用保持 `2.0.369+370`。

## 验证记录

- 使用同一 NDK 27 编译最小 C 动态库：仅 max 参数的 RELRO 末尾为 `0x9000`，
  双参数为 `0xc000`。新校验器接受后者并拒绝前者及当前旧 Rust ARM64/x86_64 库。
- 用户进一步要求减少重复编译，本批只验收 x86_64 新库及对应测试 APK/MuMu FFI。
  ARM64 编译已停止，armv7 未启动；其实际产物由后续正常平台构建验证。
- 16 项正反例通过，覆盖实际旧/新 ELF、损坏头表、错误 ABI、LOAD 对齐/大小/
  地址及 RELRO 末尾、文件缺失、多文件混合失败与 quiet 无输出。两份 workflow 的
  actionlint、PS/Bash 语法与差异检查通过。
- Rust stable 1.99.0 / NDK 27 的实际 x86_64 release 库启用 QuickJS，四个 LOAD 均为
  `0x4000`，RELRO 末尾为 `0x2238000`，模 16384 为零。原始库、strip 后库和 APK 内
  库均通过生产 ELF 校验；包内库经同一 NDK strip 正规化后的摘要与 Cargo 产物一致。
- Rust 源码指纹为 `fc0e23b9446ec47066eab83cd42ff17d94de8cba0bafc1656db919b88f46c568`；
  原始库 SHA-256 为 `7b8c0438a1561206b62631cc35cdc8551755f24802adf6dc2d0fc50156179666`，
  打包库为 `61c43e0338a8f5daa606bb5c9f66caae02db02f33b0982045c81ce8d02c5a751`。
- 只构建一份 x86_64 FFI 测试 APK，SHA-256 为
  `50f4b9e615d534bcd255854624b28fcabd60f9741b6a388371cdb2961467cb6f`。
  宿主为 Debug，Rust 库为上述 release；临时 `--build-number=4370` 匹配设备上既有
  split APK 的 Android versionCode，pubspec 不变。包内其他旧 ABI 库不属于本次验收。
- MuMu Android 15 / x86_64 的现有 `ffi_smoke_test.dart` 三项真实测试通过：初始化、
  版本往返及书源数据库查询。测试后覆盖恢复先前 AGP 正常 release APK，启动及当前 PID
  崩溃检查通过；没有卸载或清除应用数据。本批未生成三 ABI 正式发布包。

本地原始证据位于 worktree 的 `.tmp_agp9_tools/`：`relro-validator-tests.log`、
`native-x86-relro.log`、`native-x86-elf.log`、`apk-ffi-relro-native.log`、
`mumu-ffi-relro.log` 和 `mumu-relro-restore.log`。这些是临时证据，不是工程配置入口。

## NDK 28 统一与定向验证

后续任务 `ANDROID-NDK28-20261011` 从 `8c5a4ceaf` 开始；用户同意将 Rust 与 Flutter
统一至 `28.2.13676358`（r28c），只验证一个 ABI，跳过 CI。
两个现有 Android workflow 的安装/链接路径已更新；PS 默认选择 28.2，不因本机存在
27/29 而改用其他版本，仍保留显式 `ANDROID_NDK_HOME` 路径。Flutter 3.47.7 的默认值已
核对为同一版本。显式页对齐参数和 ELF 门禁保留，历史 NDK 27 证据不改写。

- 已安装 NDK r28c / Clang 19.0.1 的 x86_64 release QuickJS 构建成功，未降级或复用旧库。
  首次沙箱不能执行 SDK 编译器，旧库回退结果被拒绝作为证据；授权执行同一工具链后通过。
- NDK 默认选择/显式路径两项探测、PS 语法、两份 workflow actionlint 和差异检查通过。
- 当前源码指纹为 `ffdf692dd5dde538ba93aa5b762a3c3b90061aa1b1268c7c2d2154ed4c0a5f74`。
  原始库 SHA-256 为 `16872422cc5e33a4c21a36cf5e19fd842d51c04020be39398ada3fbb2e9532e4`，
  打包库为 `a910fa754a645f587a5be67879c67c1b014564c111903c375e35de2d3620bf15`。
  复制与包内库均与 Cargo 原产物经同一 NDK 28 strip 后的摘要一致；四个 LOAD 为 16384，
  RELRO 末尾按 16 KB 对齐。
- 单份 FFI 测试 APK SHA-256 为
  `ecccc16e36b50c8b3c10944096ea77072c713fa780a906e9cf2771080d5ab5ed`；沿用 Debug 宿主、
  release Rust 库和临时 versionCode 4370，pubspec 不变。MuMu 三项真实 FFI 均通过。
  测试后恢复先前 AGP 正常 APK，冷启动及当前 PID 崩溃检查通过，未卸载或清除数据。
  测试包中的其他旧 ABI 不属于本次验收，未生成正式多 ABI 发布包。

本地证据：`.tmp_agp9_tools/ndk28-selection.log`、`ndk28-compiler.log`、
`native-x86-ndk28.log`、`native-x86-ndk28-prepare.log`、`ndk28-ffi-verify.log`、
`apk-ffi-ndk28-native.log`、`mumu-ffi-ndk28.log` 和 `mumu-ndk28-restore.log`。
当前状态只维护于 Active 计划。

## 平台限制与回退

MuMu 的实测页大小是 4096；设备 FFI 通过只证明该环境可运行。
AGP 包检查还发现部分 Flutter/JNI/AndroidX 库有非零 RELRO 余数，须独立核查上游与
16 KB 设备行为，不能把 Rust 修复扩大为整包兼容结论。iOS 模拟器验证仍暂缓。

回退可恢复本批 Cargo/脚本/workflow 改动后重建 Rust 库；不能仅替换 `.meta` 复用旧库。
本批使用 `[skip ci]`，不启动全量 CI。

编写者：Codex｜2026-10-11
