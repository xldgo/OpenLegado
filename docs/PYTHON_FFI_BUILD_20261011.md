# Python 生成与 Android FFI 构建迁移

本文保存阶段 C 的设计与验收证据；后续 Gradle/Android CI 已接入 Python。
APK 编排和旧入口删除范围见 [Android 构建入口](PYTHON_ANDROID_CLEANUP_20261011.md)。
本文的“暂保留旧脚本”描述属于阶段 C 的历史边界。

本文记录 `PYTHON-BUILD-20261011` 的实施方法和验证证据；任务状态只在
[Active 计划](REFACTORING_ACTIVE_PLAN.md) 维护。基线 `bb9fbe303a880c9afd7eb0bdb928cd1d10a797ad`，
分支 `feature/ui-python-ffi-build`。本批由主代理实现和复核，不使用子代理；应用版本
`2.0.369+370`，Flutter/FRB 版本保持，Rust 使用工程的 stable 配置。

## 命令

Python 3.11+，使用 PATH 中已安装的 Rust、Dart、FRB 和 SDK。以下为根目录 PowerShell
命令；其他当前目录可通过 `dev.py` 绝对路径调用，显式相对路径参数按调用者目录解析。

```powershell
python scripts/dev.py generate dart
python scripts/dev.py generate dart --check
python scripts/dev.py generate bridge
python scripts/dev.py generate bridge --check
python scripts/dev.py build ffi android --profile debug --abis arm64-v8a,x86_64
python scripts/dev.py verify ffi android --profile debug --abis arm64-v8a,x86_64 --cargo-target-dir rust/target
python scripts/dev.py build ffi android --profile release --abis arm64-v8a,armeabi-v7a,x86_64
python scripts/dev.py test tooling
```

构建可用 `--ndk <目录>` 和 `--cargo-target-dir <目录>` 明确指定路径。没有增加 APK
构建、安装、启动命令；现有 build-apk.ps1 等入口继续使用，下一批按消费者迁移。
旧 sh/ps1、Gradle 和正式 workflow 构建步骤均未切换。

## 生成行为

- Dart：`dart pub get --enforce-lockfile` 后执行 `dart run build_runner build`。不升级
  依赖，不默认删除冲突输出。`--check`复制当前lib与生成配置到临时目录，实际生成并比对
  新增/删除/修改，核对依赖声明及锁文件；不覆盖原工作区。
- FRB：从双方 runtime 读取精确版本，检查已安装生成器版本和 cargo-expand；执行现有
  `flutter_rust_bridge.yaml`，生成后核对两端 hash/版本。缺少工具时报告安装命令，不由
  Python 安装；不关闭应用，不重编 DLL，也没有增加 `--skip-fvm-install`。
- Windows 直接调用 Flutter SDK 自带的 `dart.exe`，保持同一 SDK 的 FLUTTER_ROOT；
  工程编排不拼接 bat/cmd。FRB 内部保留其默认的 SDK/FVM 检测行为。
- 普通 FRB 生成和 `--check` 都复制当前工作区的 Rust、Flutter lib、依赖锁定文件和相关配置到临时目录，
  包含未提交与未跟踪输入；不创建 Git worktree，不复制本地 `.fvmrc`，不改原工作区。
  Cargo 输出也放在该临时副本内。`--check` 检出新增、删除或改变桥接文件、Rust 生成文件
  或模块入口时失败；文本比对归一化 CRLF/LF，Rust 缓存指纹仍按实际字节计算。
- 只允许现有相对输出边界，不让隔离生成指向原目录或外部目录。依赖声明/锁文件变化
  被报告为失败，不能以生成成功掩盖依赖漂移。普通生成成功后只同步带 FRB 生成标识的
  Dart 文件及 `frb_generated.rs`，支持新增、删除和修改；手写桥接入口和 Rust 模块入口
  意外改变时拒绝发布。生成器删除无关 Freezed/JSON 生成物只影响临时副本。
- 生成期间原输入发生变化则拒绝发布；相同输出保持原文件与修改时间。同步时使用
  单文件原子替换，失败回滚本次输出，不提供跨进程、多文件事务隔离保证。

## Android 构建与发布

1. ABI/QuickJS、NDK 28.2.13676358、Clang API 21 和 16 KB 链接参数来自同一策略文件。
   Debug 仅 arm64/x86_64、均启用 QuickJS；Release 另包含明确不启用 QuickJS 的 armv7。
2. NDK 优先显式参数，其次 NDK 环境变量，再 SDK 环境变量或 Android local.properties
   中对应版本目录。已指定但版本错误时失败，不按名称挑最新版，也不自动安装 NDK。
3. 使用工程 rust-toolchain.toml 的 channel；实际 rustc、Cargo、Clang 和 NDK 版本
   写入元数据，不固定某个 Rust stable 版本。Cargo `--locked --no-default-features`，
   按策略显式启用 feature。编译器、ar 和 linker 直接使用 NDK 原生 exe。
4. 通过 Clang `--target`/`--sysroot` 等价实现现有 android21 wrapper 的目标配置；
   目标专用 CC/AR/CFLAGS 同时覆盖连字符/下划线两种变量写法。启用 cc-rs 的
   CC_SHELL_ESCAPED_FLAGS，使含空格路径可解析。bindgen 参数只传给对应 Android
   target，不使用旧 CI 的全局参数，避免污染宿主及切换 ABI 时重复重编宿主依赖。
   子进程清理会覆盖既定参数的通用环境项，父进程和本机环境配置保持。
5. Cargo 成功退出后还必须输出本次 compiler-artifact 对应的目标库，不能只从 target
   中寻找旧文件。Cargo 正常增量复用允许；失败不重试其他 feature/profile，不复制旧库。
6. 构建前固定源码、契约和工具输入摘要，构建后再次核对；中途改变输入则不发布。
   全部请求 ABI 成功后在临时目录复制库，Release 仅 strip 副本，生成 schema v2。
7. 严格验证临时库/元数据与 Cargo 源库，再整体替换 jniLibs 目录；未选择的库保持内容。
   发布失败或最终校验失败恢复原目录；恢复本身失败时保留旧目录备份，不随临时文件清理。
   构建锁防止两个 Python 构建并发；旧 Gradle
   尚不使用此锁，当前应避免同时编译和打包。目录替换不是跨进程读者的事务隔离保证。

NDK 27 原先未安装，本轮根据 [Google 官方 SDK 仓库清单](https://dl.google.com/android/repository/repository2-3.xml)
并行安装，不覆盖已有 NDK 28/29。Windows ZIP 大小 781482169 字节，官方 SHA1
`0ea2756e6815356831bda3af358cce4cdb6a981e`，大小和摘要均核对后才解压。
SDK 实际安装路径只保留在本地环境，工程没有写死个人路径。

参数传递和退出码依据 [Python subprocess](https://docs.python.org/3.11/library/subprocess.html)，
Cargo 子进程配置依据 [Cargo 环境变量](https://doc.rust-lang.org/cargo/reference/environment-variables.html)。
cc-rs/bindgen 的目标参数与 FRB 行为同时核对本机已锁定版本源码，没有修改 Cargo registry。

## 验证证据与边界

实现提交 `1b3e5d1f71b08f084c5834b76c452f06e9bbf871`。Windows Python 3.11/3.13
各运行 69 项测试，66 项通过，3 项因宿主不支持的文件类型或符号链接权限跳过；Linux
69 项全部通过。覆盖 Cargo 失败且旧库存在、禁止 feature 降级、
缺产物事件、源输入变化、strip 失败、整组替换/回滚、并发锁、NDK 错版本、环境发现、
参数含空格/元字符、原始退出码、生成器版本错配以及脏工作区隔离。

[同一实现提交的轻量 routing 运行](https://github.com/xldgo/OpenLegado/actions/runs/38067819023)
通过：changes/check 成功，原有 16 项编排测试和新增工具测试成功；android-ffi/ffi-smoke
两个原生作业正确跳过，没有启动全量 CI。9 份 workflow 的 actionlint 与差异检查通过。

真实生成与构建：

- FRB 2.13.0 隔离生成成功，当前生成物无差异；原工作区桥接文件不变。FRB 的默认
  FVM 检测打印了安装提示，随后继续生成并成功，未增加跳过选项或修改 FVM 配置。
- 新 Dart 入口成功执行 build_runner，写入 48 个生成输出，Git 中无应用源码或锁文件差异。
- Windows + NDK 27 的 arm64/x86_64 Debug QuickJS 编译成功，来源确认与元数据校验通过。
  初次构建期间工具发生修改，输入守卫正确拒绝发布；稳定实现后重新成功构建。
- 两份真实 ELF 的 LOAD 段对齐均为 `0x4000`，PDE 主/同步派发符号存在；使用同一 NDK
  对真实 Debug 库的副本执行 strip 成功，源库保持原摘要。该证据不等于 Release 编译或
  16 KB 页设备运行成功。
- Release 三 ABI 和 strip 的流程由正反 fixture 覆盖；真实 Release 编译、APK 最终校验、
  Android 运行时 smoke、Linux/macOS 原生编译、模拟器/设备未在本阶段验证。

本批的完成范围是新生成/Android FFI 编排入口及上述可用环境验证，不能宣称整套 Python
迁移完成或跨平台运行已验收。后续接入 Gradle/CI 时分别验证消费者与真实产物，再决定旧入口删除。

主代理复核了版本来源、ABI/feature 参数、生成隔离、失败不复用旧产物、发布及恢复失败
时原目录的保留路径；相关正反测试通过。按用户要求未使用独立子代理审查。
本地生成/构建日志和 ELF 记录存放在忽略目录 `.tmp_ci_workflow_validation/`，不写入提交正文。

回滚本批工具提交即可恢复此前旁路只读校验；原生产 workflow 仍使用旧入口。新 v2 元数据
需要由对应新构建重新生成，不能通过手工改字段伪装为成功编译。

编写者：Codex｜2026-10-11
