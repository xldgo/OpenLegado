# Python 指纹与只读 FFI 校验

本文保存指纹协议说明与阶段 B 的历史验收证据；后续 Android 构建与校验接线已经迁移。
当前命令和旧脚本删除范围见 [Android 构建入口](PYTHON_ANDROID_CLEANUP_20261011.md)，
不得将本文记录的旧脚本作为当前开发入口。

本文保存 `PYTHON-FFI-20261010` 的命令、格式与验证证据。当前任务状态只登记在
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。基线为 `16cb270d283d2f13c69c2cda83d62570491fefeb`，
分支为 `feature/ui-python-ffi-validation`；Flutter、Rust stable、FRB 和应用版本保持当前值。

后续 Android 编译与生成入口见 [构建迁移说明](PYTHON_FFI_BUILD_20261011.md)。下文的
“尚无新生产者”描述属于本批阶段 B 基线；后续 Python 构建已经负责成功后写入 v2 元数据，
正式 Gradle/CI 消费者的迁移另行验收。

## 命令与执行边界

工具只依赖 Python 3.11+ 标准库。以下 PowerShell 命令从仓库根目录执行；也可以在其他
目录用脚本的绝对路径调用，仓库位置由 `dev.py` 自身位置决定。

```powershell
python scripts/dev.py fingerprint rust
python scripts/dev.py verify ffi android --profile debug --abis arm64-v8a,x86_64
python scripts/dev.py verify ffi android --profile release --abis arm64-v8a,armeabi-v7a,x86_64
python scripts/dev.py verify ffi android --profile debug --abis arm64-v8a,x86_64 --cargo-target-dir rust/target
python scripts/dev.py test tooling
```

`fingerprint` 只输出一行摘要；`verify` 不编译、不安装、不删除或改写库和元数据，也不生成
`__pycache__`。全部 ABI 通过后才输出成功信息；运行失败退出 1，命令语法错误退出 2。
ABI 空条目、重复条目、未知 ABI 和未批准的模式组合都会失败。

省略 `--cargo-target-dir` 时检查 jniLibs 与元数据，并明确报告“未核对 Cargo 源库”。
指定后还核对 `<目录>/<Rust target>/<profile>/liblegado_ffi.so`；源库缺失或摘要不同即失败。
相对的显式目录参数相对于调用者当前目录，不受仓库自动定位影响。这样不会把另一次构建
留在默认 target 目录的库悄悄当作本次来源，也不依赖当前机器的 Cargo 输出目录配置。

## Rust 指纹

当前算法标识为 `rust-tree-sha256-v2`：枚举 Rust 树内常规文件，排除任意深度名为 `target`
的目录，以及确认不参与 Cargo 编译的 `scripts/build-ios.sh`、`scripts/gen_rar5_fixture.py`；
相对路径使用 `/`，逐文件取实际字节 SHA-256，再将
`相对路径<TAB>小写摘要<LF>` 按 UTF-8 字节序排序、拼接、取整体 SHA-256。
不将文件范围改为 Git 已跟踪清单，不归一化 LF/CRLF，读取失败不能省略该文件。

业务源码、Cargo/锁文件、build.rs 与内嵌资源仍保留，新脚本默认纳入共享输入。
对旧流程的歧义采用明确失败规则：Rust 输入中的符号链接
与 Windows 重解析点会失败，避免 Cargo 编译外部文件但指纹未覆盖；含制表符、换行或
反斜杠的路径不支持。排除的 target 目录不参与这些检查。
UTF-8 字节排序遵循原 Bash 的口径；原 PowerShell 的 UTF-16 Ordinal 排序在补充平面
字符与部分 BMP 字符混合时可能不同，此类路径必须使用新入口重编，不能声称两者完全等价。

## 构建策略与元数据

`scripts/tooling/android-policy.json` 保存迁移基线，后续 Python 编译入口使用同一配置。
此阶段没有把既有 CI 的配置来源改到此文件。

| ABI | Rust target | Debug features | Release features |
|---|---|---|---|
| arm64-v8a | aarch64-linux-android | quickjs | quickjs |
| x86_64 | x86_64-linux-android | quickjs | quickjs |
| armeabi-v7a | armv7-linux-androideabi | 不支持 | 空集合 |

Rust Android NDK 28.2.13676358、Clang API 21、16 KB 链接参数与现有 CI 一致。
Python 不因为 QuickJS 失败而选择另一组 feature。

每份库旁的 `.so.meta` 要求以下字段；此处是 schema 示例，摘要是占位值：

```json
{
  "schemaVersion": 2,
  "fingerprintAlgorithm": "rust-tree-sha256-v2",
  "buildInputsAlgorithm": "android-ffi-inputs-sha256-v2",
  "contentHash": -123456,
  "frbCodegenVersion": "2.13.0",
  "rustFingerprint": "<64位小写SHA-256>",
  "buildInputsSha256": "<64位小写SHA-256>",
  "targetTriple": "aarch64-linux-android",
  "abi": "arm64-v8a",
  "profile": "debug",
  "features": ["quickjs"],
  "sourceSha256": "<64位小写SHA-256>",
  "packagedSha256": "<64位小写SHA-256>",
  "builtAt": "2026-10-10T00:00:00+00:00"
}
```

- FRB 版本从 pubspec、Cargo.toml 和双方生成文件读取，不写死 2.13.0；runtime 必须精确
  固定且与生成版本一致。contentHash 使用 i32 语义，允许负数，拒绝布尔值和越界值。
- JSON 重复字段、非有限数字、缺失字段、字段类型不符和旧 schema 都失败。
- `buildInputsSha256` 对排序键、紧凑分隔、ASCII 转义的 JSON 输入对象取 SHA-256。
  输入包括算法、Rust 指纹、FRB hash/版本、ABI、target、profile、features、NDK、Clang
  API、页大小和该平台的工具指纹。文件范围由 `input_scopes.py` 统一维护，包含共享原生模块
  与对应平台原生模块，不包含 CLI、其他平台模块、打包或代码生成工具；`__pycache__`、pyc、pyo
  不参与计算，尚未分类的工具文件默认纳入三个平台。具体字段实现见 `policy.py`。
- `sourceSha256` 代表 Cargo 原库；`packagedSha256` 代表 jniLibs 实际库，允许合法 strip
  后两者不同。这里只核对各自摘要，不在本阶段判断 strip 转换是否合法。
- 校验 ELF 头的位数、小端格式、ET_DYN 和 machine；它不是完整 ELF 装载验证。
- `builtAt` 要求 ISO8601 UTC，仅用于诊断，不按时间判断产物是否陈旧。

这些元数据用于防止构建来源误用，不能防止有人同时伪造库与全部元数据。实际 rustc
版本、NDK 安装真实性、编译命令和成功后原子化写入元数据需要下一阶段生产者记录并证明；
schema v2 不会凭一份声明证明编译已成功。最终 APK strip 比较和真实 FFI 调用仍分别验收。

## 平台隔离与协议迁移

公共 FRB 契约/schema 检查放在 `contracts.py`，Android NDK 操作放在 `android_toolchain.py`；
Windows 应用编排放在 `windows_app.py`，原生 DLL 操作保留在 `windows.py`。CLI 按命令导入模块，
Android 命令不再加载 iOS/Windows 代码；另一个平台模块变化不会使本平台原生库失效。

Android、Windows、iOS 的 `buildInputsAlgorithm` 均使用各自的 `*-ffi-inputs-sha256-v2`。
本次改变输入范围，旧 v1 元数据需要由正式构建入口重建后生成 v2 元数据；校验器不改写旧声明。
`schemaVersion` 仍为 2，库来源、打包摘要、架构、feature 与契约校验保持。
工具与 CI 编排回归只在独立 Tooling CI 执行一次，平台 workflow 只计算差异并执行所选检查。

## 阶段 B 的历史行为差异

旧 PS、Bash、Gradle 的校验继续原样工作，新命令作为旁路使用。新校验器拒绝缺指纹、
旧 schema、错误模式/feature、错误摘要与错误 ABI；不扫描库是否含四字节 FRB hash，
不警告后放行，也不补写元数据。目前还没有 schema v2 的生产构建入口，所以旧构建生成
的库不能直接通过新命令，必须等下一阶段成功构建后生成新元数据。

轻量 CI 前置步骤增加标准库测试，原生构建、签名、发布、手动触发与权限保持既有接线。
原生产物与模拟器验证按用户要求暂缓，不以合成 ELF fixture 代替这些验证。

## 阶段 B 的历史验证与回滚

实现提交为 `44a20d28f64fda4f51fd4d13a245498991ed00e9`。本地 Windows Python 3.13.15
与最低版本 Python 3.11.14 各运行 42 项测试：39 项通过，符号链接权限、FIFO 与非法文件名
三个宿主受限用例跳过；Linux 42 项全部通过。覆盖指纹固定样本、中文与空格路径、内容/路径/换行变化、
嵌套 target、读取失败、FRB 契约版本、旧/缺失/损坏元数据、ABI/profile/features 错配、
源库与打包库摘要、ELF 架构、工具输入变化、CLI 退出码与只读行为。

固定 fixture 的 Python、原 PowerShell、原 Bash 指纹均为
`204c176e55fa69798024c6191b6ab70dab76164bfd113e7867d9fb09120827a1`。
Bash 对照使用 HEAD 中未修改的脚本内容，避免 Windows checkout 的脚本 CRLF 影响解析；
fixture 中包含 CRLF 文件，按实际字节校验。当前 Rust 树的 Python/PowerShell 指纹均为
`f30ff3a22a05e6643d54adbb6c5224b5f588225cb1cfd46b00337cda143c62c1`。
实际工作区未提供 Android 库，新命令按预期退出 1，未生成或改写元数据。
原编排 16 项测试、actionlint、Python 3.11 语法检查和差异检查通过。

[Integration Smoke routing](https://github.com/xldgo/OpenLegado/actions/runs/38063850065)
对应上述实现 SHA，终态成功：changes 作业内原编排 16 项、新工具 42 项均成功；Linux
工具测试耗时 0.616 秒。check 成功，android-ffi 与 ffi-smoke 均为 skipped。没有启动
Flutter、NDK 或 macOS 构建。Linux 的三个宿主专属用例实际执行通过，固定摘要也相同。

按用户要求不使用子代理，提交前由主代理复核范围与失败分支，不将其称为独立审查。
正式 Gradle、native CI、FRB 生成物与应用代码没有修改。未运行真实 NDK/Gradle/Xcode
编译、APK strip、模拟器或真机回归；新元数据与真实产物的关系仍需下一阶段证明。

回滚可撤销本阶段工具与轻量测试接线提交；既有编译路径没有迁移，不需重写旧库元数据。
下一阶段在可用环境迁移 Android 编译与 FRB 生成，严格保留失败不降级、不复用旧产物的规则。

编写者：Codex｜2026-10-10
