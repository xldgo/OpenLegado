# iOS 正式 RustFFI、图标与 IPA 工具

本文保存任务 `PYTHON-IOS-20261011` 与 `PYTHON-IOS-PACKAGING-20261011` 的行为、命令和交付边界；当前状态只维护于
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。基线提交为 `db415d4b2`，
实施分支为 `feature/ui-python-ios-tooling`，实现提交为 `c165e50dc`。

## 正式产物与矩阵

| 目标 | Rust target | Apple SDK | Rust profile / feature | Flutter 宿主 |
| --- | --- | --- | --- | --- |
| device | `aarch64-apple-ios` | `iphoneos` | Release / QuickJS | Release，无签名构建后沿用原签名步骤 |
| simulator | `aarch64-apple-ios-sim` | `iphonesimulator` | Release / QuickJS | Debug，沿用原模拟器集成测试 |

Cargo 产物仍为 `liblegado_ffi.a`，复制路径仍为
`flutter_legado/ios/RustFFI/libliblegado_ffi.a`。保留 podspec 的 `vendored_libraries`、
`-force_load`、死代码裁剪和 strip 配置。Python 不修改 Podfile、Xcode 接线、签名方式和 IPA 命名。

两份 workflow 在独立 Runner 检出中分别构建。设备和模拟器库不能混用；同一本地工作区内
切换目标会覆盖这一个 RustFFI 文件，校验根据目标元数据拒绝错配。

历史 `rust/scripts/build-ios.sh` 输出 XCFramework，包含正式矩阵以外的 Intel 模拟器及 stub 选项，
未完成实际 macOS 验证。全仓有效引用审计没有发现正式构建消费者，当前仅有脚本自身、
目录说明与 CI 路由 fixture；它不作为正式流程使用，本轮只补充说明，不把它的未验证能力搬入新入口。

## 命令

根目录入口要求 Python 3.11+。脚本以自身位置定位仓库，其他目录可用绝对脚本路径调用。
以下原生 iOS 操作需要 macOS/Xcode，Windows/Linux 直接报告平台不支持，不安装或切换本机工具链。

```powershell
# 两条独立命令，按当前要构建的宿主选择其一
python scripts/dev.py build ffi ios --target device --profile release
python scripts/dev.py build ffi ios --target simulator --profile release

# 只读校验 RustFFI 与本次 Cargo 产物
python scripts/dev.py verify ffi ios --target device --profile release

# Flutter 构建完成后，检查最终应用的已定义 PDE 分发器符号
python scripts/dev.py verify app ios --target device --profile release --app flutter_legado/build/ios/iphoneos/Runner.app --cargo-target-dir rust/target
python scripts/dev.py verify app ios --target simulator --profile release --app flutter_legado/build/ios/iphonesimulator/Runner.app --cargo-target-dir rust/target
```

`--profile release` 描述 Rust 静态库，不代表模拟器 Flutter 宿主必须为 Release。
FFI 构建入口没有无 QuickJS、自动降级、自动安装目标、生成 XCFramework 或自动构建/签名 IPA 的选项。
Rustup 目标安装继续由现有 CI 安装步骤负责；本地须自行准备对应目标。

`--cargo-target-dir` 可明确指定或核对输出目录；未传入时遵循 `CARGO_TARGET_DIR`，否则使用
`rust/target`。显式相对路径相对调用目录，环境变量相对路径相对 Cargo 工作目录 `rust/`。
验证始终核对源 `.a`，仅拷贝 RustFFI 文件而缺少对应 Cargo 产物不能视为通过。

## 与旧编排的行为差异

1. 保留 `cargo rustc --release --target … --lib --crate-type staticlib --features quickjs`；新增
   `--locked`、显式无默认 feature 和 Cargo JSON 产物确认。成功的增量编译可接受，失败或缺产物消息不能复制旧库。
2. SDK 继续由 `xcrun --sdk … --show-sdk-path` 选择。`IPHONEOS_DEPLOYMENT_TARGET` 从现有
   `AppFrameworkInfo.plist` 读取，并要求 Podfile、RustFFI podspec、Xcode 工程声明一致，当前值为 15.0。
   模拟器保持 clang 识别的 `aarch64-apple-ios-simulator` bindgen 参数，含空格路径通过参数解析保留。
   子进程清除继承的 bindgen 目标覆盖值，防止本地从模拟器切回设备时使用错目标参数。
3. 复制前校验静态归档头、`lipo` 单一 arm64 架构和已定义 PDE 符号；构建前后比较源码与工具输入。
   临时复制摘要通过后原子替换 `.a` 与 `.a.meta`；中断造成两者不匹配时后续门禁失败，不自动修复。
4. 同一工作区 native 构建使用排他锁，避免两个目标同时发布到同一 RustFFI 路径。
   锁不覆盖后续 CocoaPods/Flutter 构建；同一工作区不要并行编译不同目标的宿主应用。
5. 原 `nm | grep` 可能命中未定义引用或同名子串；新校验要求准确符号名称及全局文本定义 `T`。
   最终设备包检查 `Runner`；模拟器检查 `Runner` 和 `Runner.debug.dylib`，至少一处包含定义才通过。

## 元数据与校验含义

相邻文件 `libliblegado_ffi.a.meta` 使用共用 schema v2，记录：

- Dart/Rust 契约 hash 与实际 FRB runtime/codegen 版本；版本从当前工程读取。
- Rust 文件树指纹、CLI/工具实现指纹及算法标识 `ios-ffi-inputs-sha256-v1`。
- `targetTriple`、arm64、Release、QuickJS、SDK 种类和最低系统版本。
- Cargo 源库与 RustFFI 复制库 SHA-256、UTC 构建时间，Rust/Cargo/SDK 版本诊断信息。

只读校验不编译、不写文件、不补元数据；缺失、旧 schema、错目标、源码/工具变化或摘要不匹配均失败。
源码/契约检查、文件摘要和已定义符号检查不能替代真实 Flutter FFI 调用。
`lipo` 只证明 arm64 架构，设备/模拟器来源由显式 Cargo 目标和元数据约束；元数据不是防恶意篡改的签名。
本批工具实现变化也会使其他平台旧输入摘要失效，需要按当前入口重编；不能补写新指纹复用旧库。

## 交付与未测边界

本轮由主代理执行，不使用子代理。用户要求跳过验证，未执行 Python 测试、actionlint、Cargo、
Flutter、模拟器、真机或任何 Actions。新增 16 项 iOS fixture、一项 CLI 参数用例和一项 CI 接线用例，
只静态复核，没有通过结果；fixture 也不能证明真实 Apple 工具输出或最终链接正确。

实际 macOS `cargo rustc` JSON 产物、`xcrun lipo/nm` 输出、QuickJS/bindgen 编译、RustFFI 最终链接、
IPA 和原集成测试仍需后续定向验收；本轮没有新的运行 URL、构建日志或设备证据。
Git 提交和 push 使用 `[skip ci]`，不修改默认分支，不触发完整平台验证。

## 回滚

回退本阶段的两份 iOS workflow 接线即可恢复基线 Cargo/复制/符号流程；Python 新入口可独立撤回。
Podfile、podspec、签名、图标、应用数据与 FFI 协议未改，无数据库迁移。
回退后旧流程不产生新的 v2 来源信息，再启用 Python 门禁时必须重新编译，不为旧静态库补元数据。

## 设备图标、plist 与 IPA 编排

任务 `PYTHON-IOS-PACKAGING-20261011` 从 `1c81a8767` 沿用当前分支，新增
`scripts/tooling/ios_bundle.py`；下列命令替换 `ios-build.yml` 的对应内嵌逻辑。
文档随代码提交，不另做提交号回填；原 RustFFI 构建流程不变。

```powershell
# 三类只读检查分别执行，--assets / --build-log / --app 每次只选一个
python scripts/dev.py verify icons ios --assets flutter_legado/ios/Runner/Assets.xcassets
python scripts/dev.py verify icons ios --build-log flutter_legado/ios_device_build.log

# 必须在 codesign 之前调用；保持原散文件复制与 legacy 声明转换
python scripts/dev.py prepare icons ios --assets flutter_legado/ios/Runner/Assets.xcassets --app flutter_legado/build/ios/iphoneos/Runner.app
python scripts/dev.py verify icons ios --app flutter_legado/build/ios/iphoneos/Runner.app

# 打包需要 macOS；输入是最终应用（已签名或未签名），此命令不签名、不再修改源应用
python scripts/dev.py package ios --app flutter_legado/build/ios/iphoneos/Runner.app --ipa flutter_legado/build/ios/iphoneos/app-unsigned.ipa
python scripts/dev.py verify ipa ios --ipa flutter_legado/build/ios/iphoneos/app-unsigned.ipa

# 只复制 plist 并导出包含 Icon 的顶层字段，不修改源 plist
python scripts/dev.py export plist ios --app flutter_legado/build/ios/iphoneos/Runner.app --output-dir flutter_legado/build/ios/device-plist
```

图标处理保留以下规则：

- 源引用检查仍只针对 `launcher1` 至 `launcher6` 的 `Contents.json`；改用 JSON 解析，
  支持含空格文件名，坏 JSON、空槽位列表或缺文件失败。没有 filename 的单个槽位继续交给 actool 判断。
- 编译日志包含 `unassigned children` 就失败，最多列出十处；缺日志现在明确失败，不能当作无警告。
- 继续复制 24 个备选图标散文件和 `AppIcon60x60@3x.png`。仅对带 `CFBundleIconName` 的
  备选条目转换，iPhone 引用 `launcherN60x60`，iPad 引用 `launcherN76x76`。
  至少转换六条，非十二条仍警告；缺省 iPad 区段可接受，已转换的包不能再次执行转换。
- 最终门禁要求恰好六个备选图标、非空 `CFBundleIconFiles`、对应散文件存在，
  不接受残留资产名或越界文件名。准备步骤先确认全部源图标和转换条件，再写包，最后执行同一门禁。

IPA 继续调用原 macOS `cp -r` 与 `zip -qry`，保留原生复制和符号链接打包语义。
每次使用新的临时 Payload/ZIP，完整性检查通过后替换输出；失败不覆盖已有 IPA，
workflow 失败后也不会继续上传旧包。只读校验检查全部 ZIP 条目 CRC、唯一性、有效 plist 字典
和非空普通 Runner 文件；不提取归档，不把这个结果当作签名或运行验证。

写入位置限定于本仓库 `flutter_legado/build`；打包输出和诊断输出不能覆盖源应用。
证书判断及 `artifact_name` / `ipa_path` 仍由 workflow 设置，签名命令、诊断条件及工件名保持。
car 名称/尺寸启发式探针继续仅在手动诊断开启时运行；此批不处理历史图标切换故障。

新增 20 项图标/IPA fixture、两项 CLI 用例和一项 workflow 接线用例，按用户要求均未运行；未执行 actionlint、
Cargo、Flutter、codesign、真实 ZIP 打包或 Actions。合成归档不能证明 macOS 的权限/符号链接、
签名保留或真实安装有效。这些项目需后续定向复验，当前没有相应通过证据。

回滚本批 `ios-build.yml` 接线可恢复原图标/IPA 内嵌步骤，RustFFI/CocoaPods 接线无需回退。
工具文件变化会让现有 native 元数据的工具摘要失效，后续构建须重编，不补写旧库元数据。

编写者：Codex｜2026-10-11
