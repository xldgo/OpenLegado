# Flutter 3.47.7 升级验证记录

本文保存 2026-10-10 的变更依据和本地验证证据；当前任务状态以
[Active 计划](REFACTORING_ACTIVE_PLAN.md#flutter-sdk-20261010flutter-3477-升级p1) 为准。

## 基线与范围

- 基线：`dev`，`e4c9a9764ae54481ceae7e44c2812335f51170ff`。
- 执行分支：`chore/flutter-3.47.7`，应用版本保持 `2.0.369+370`。
- 本批为 SDK、构建配置及生成器兼容调整，业务源码、阅读界面、数据库格式和 FFI 契约保持原样。
- 按用户要求直接执行，不使用子代理；本地验证及审核后，用户于 2026-10-10 授权提交、推送升级分支并运行 Actions 测试。

## 工具链与配置

| 项目 | 实际结果 |
| --- | --- |
| FVM | Scoop 安装的 4.3.1 已是检查时的最新版本 |
| Flutter | 3.47.7 stable，framework revision `abaf9c523780a608bd46686fd5e53740a07077f8` |
| Dart | SDK 随附 3.13.5；项目语言下限仍为 3.8 |
| Rust | 工作区、CI 和本地默认使用 `stable`；本次实际编译器为 1.99.0 |
| FRB | Dart/Rust runtime 与已提交绑定仍为 2.11.1 |
| iOS | Podfile、Runner、Flutter framework plist、RustFFI pod 和 Rust 构建入口统一为 15.0 |
| Android | Flutter 默认 compile/target API 36、min API 24、NDK 28.2.13676358；与旧 SDK 的默认值相同 |

新 Flutter SDK 位于 `C:\Users\share\scoop\persist\fvm\versions\3.47.7`，其 `bin` 已加入用户 PATH，
新终端可以直接调用 `flutter` 和 `dart`。用户授权删除的旧 FVM 缓存实际为 Flutter 3.29.3，已移除。
`.fvm/` 和 `.fvmrc` 已加入忽略规则；项目文档不要求使用个人的 FVM 安装或 PATH 配置方式。

Rust 最初经官方 `rustup-init` 安装 1.97.1，选择最小安装及 `--no-modify-path`。
用户随后安装 rustup 并补齐 PATH；现已通过该 rustup 安装并切换默认 `stable`，项目不再固定 1.97.1。

五份 Flutter workflow 使用 3.47.7，既有触发方式及作业拆分保持原状。Rust CI 和 Android
目标补装命令也使用 `stable`。Rust Android 构建仍使用原来的 NDK 27.0.12077973；它与 Flutter
Gradle 是独立构建链，最终 native 库的 ABI、系统 API 和 16 KB 页兼容仍需验证。

`flutter.config.enable-swift-package-manager: false` 保持现有 CocoaPods 依赖接线；
`RustFFI.podspec` 的 `-force_load` 和符号保留选项未移除。
`analysis_options.yaml` 的 build/平台排除项来自新 SDK 自带的配置迁移。

## 依赖与生成代码

保留原 lockfile，先执行依赖解析，再根据实际失败调整生成器兼容组合。
SDK 带来的运行依赖变化为 intl、matcher、meta、test_api 和 vector_math；FRB 及 Riverpod
运行库未跨版本升级。Freezed/JSON annotation 的声明下限与实际锁定版本对齐。

旧 analyzer 6.4.1 不能解析已有测试中的数字分隔符，代码生成因此失败。
生成器调整为 build_runner 2.5.4、Freezed 2.5.8、json_serializable 6.9.5、Riverpod generator/lint
2.6.4 及 custom_lint 0.7.x。实际解析到 analyzer 7.6 时，analyzer_plugin 0.12 的 Element API
编译失败，故明确固定 analyzer 7.3.0，未添加 dependency_overrides。

39 份已提交的 Dart 生成文件重新生成，其中 35 份产生差异，主要为格式、生成注释和
`JsonKey(ignore: true)` 改为显式的序列化排除属性。没有手工修改生成物。
重复生成写入 0 个输出，39 份文件的 SHA256 与第一次成功生成后完全一致。

生成器仍提示所支持的分析器语言版本低于 Dart SDK 3.13；当前包语言下限为 3.8，
现有源码生成及测试已通过。这是已记录的工具兼容限制，不表示生成器已支持全部 Dart 3.13 新语法。

FRB 的 Rust/Dart content hash 同为 `-1293445466`，codegen version 同为 `2.11.1`；
绑定文件保持原样。本轮未重新生成 FRB，固定版本生成器的独立复现仍需补充。

## 本地验证

| 检查 | 结果 | 本地日志（仓库根目录 `.tmp_ci_workflow_validation/`） |
| --- | --- | --- |
| `flutter pub get --enforce-lockfile --offline` | 退出码 0 | `flutter-3.47-lockfile-check.log` |
| Flutter 静态分析 | 零问题，退出码 0 | `flutter-3.47-analyze.log` |
| Dart build_runner | 成功；重复执行输出 0 个、摘要不变 | `flutter-3.47-generate.log`、`flutter-3.47-generate-repeat.log` |
| `cargo build --locked -p legado-ffi --features quickjs` | Rust stable 构建成功 | `flutter-3.47-rust-stable-build.log` |
| `cargo clippy -p legado-net --all-targets -- -D warnings` | async-trait 补丁更新后通过，退出码 0 | `flutter-3.47-rust-net-clippy.log` |
| `flutter test --no-pub --reporter expanded` | 2239 项通过，退出码 0 | `flutter-3.47-test-final.log` |
| Windows `integration_test/ffi_smoke_test.dart` | 原生宿主构建成功，3 项通过，退出码 0 | `flutter-3.47-integration-final.log` |
| Windows 包内 DLL 校验 | 与本次 stable 构建的源 DLL 摘要一致 | `flutter-3.47-bundle-check.log` |
| actionlint 1.7.12 | 9 份 workflow 通过 | 本地命令输出 |
| `git diff --check` | 通过 | 本地命令输出 |

Windows CMake 原来引用仅在 `flutter/` 子目录定义的 `PROJECT_DIR`，导致顶层 Rust DLL
目录解析错误。本次改用 `CMAKE_CURRENT_SOURCE_DIR/../../rust/target` 定位产物。
最终 Windows 包内 `legado_ffi.dll` 与新编译源库的 SHA256 均为：

```text
293E17EF510A3744F37B6BF91F716461FF68D03DF5FFD811424D954DA5114E0F
```

首次全量测试因本机没有 Rust DLL 出现 5 个失败；构建真实 native 库后完成上表的全量复验。
Windows 冒烟覆盖初始化、版本调用和书源数据库查询，不覆盖真实网站或完整阅读路径；
日志仍包含 Windows 缺少 Android 设备 ID channel 的提示。

本机未启用 Windows Developer Mode，FVM 与插件符号链接使用项目临时目录内的目录联接完成。
Windows TTS 插件需要的 NuGet 已安装。旧镜像缺少新引擎产物，验证进程改用官方
`storage.googleapis.com` / `pub.dev`；未改写用户的全局镜像设置。
上述日志为本机忽略的验证产物，本文保留可审查的命令、结果与摘要。

## Actions 运行与兼容修复

升级提交 `dba4d91775cbcb8e2efe07ae89dfd9138dcf8e4c` 已推送到 `origin/chore/flutter-3.47.7`。
初次 [Flutter CI](https://github.com/xldgo/OpenLegado/actions/runs/38040396074) 通过，
[Integration Smoke](https://github.com/xldgo/OpenLegado/actions/runs/38040396097) 的 Android FFI 作业通过。

初次 [Rust CI](https://github.com/xldgo/OpenLegado/actions/runs/38040396090) 的 Clippy 失败于
`async-trait 0.1.91` 生成的重复 `must_use` 属性。上游
[0.1.92](https://github.com/dtolnay/async-trait/releases/tag/0.1.92) 已删除该冗余属性，
故通过 `cargo update -p async-trait --precise 0.1.92` 仅更新这一项补丁版本及摘要。
工作区业务代码与 FFI 契约无需改动，原有 `-D warnings` 门禁保留。
本地 legado-net 全目标 Clippy 复验通过；提交 `ce52ccad9` 的完整 Rust CI 也已通过，
包括格式、默认/QuickJS Clippy、测试、安全审计及汇总门禁。

GitHub 默认分支是 `master`，尚未包含 `android-release.yml`、`ios-ci.yml`，两次直接手动触发均返回 404。
独立分支 `ci/verify-flutter-3.47.7` 的提交 `3da9b1b17` 只添加一次性验证入口，
逐项复用上述两个 workflow 的构建作业，不含发布作业；应用源码与 `dba4d9177` 相同。
[移动端验证运行](https://github.com/xldgo/OpenLegado/actions/runs/38040761715) 的 iOS 模拟器作业通过，
包括 Rust 静态库、宿主构建、PDE 符号、图标状态集成测试 1 项和离线搜索阅读测试 1 项。
离线用例使用真实 Rust FFI 与本地书源，验证搜索、详情、进入正文及手势翻章；不覆盖真实网站。
该运行整体失败来自 Android 的分 ABI 配置，不能将整个运行标为通过。

初次 [iOS Build](https://github.com/xldgo/OpenLegado/actions/runs/38040396070) 已完成设备应用编译及
PDE 符号检查，但 legacy 图标资源门禁发现 `launcher160x60@2x.png` 缺失。
原兼容复制只显式处理 76、152、180 像素，120 像素散文件依赖 actool 输出。
现补齐六个备选图标的 120 像素复制，保留 24 文件门禁、最终 plist 和签名/IPA 校验。
这一调整使用已有图标源文件，完整性以重跑的最终包验证为准。

第二次 [iOS Build](https://github.com/xldgo/OpenLegado/actions/runs/38042143248) 已通过 24 文件检查，
但最终 plist 校验发现 legacy 转换只删除 `CFBundleIconName`，未补充 `CFBundleIconFiles`。
现按 iPhone / iPad 分别写入已复制的 `launcherN60x60` / `launcherN76x76` 文件基名，
保留最终引用资源检查；不据此宣称旁载换图标限制已解决。
字段依据见 [Apple CFBundleIconFiles 文档](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleicons/cfbundlealternateicons/appiconreferencename/cfbundleiconfiles)。
本地执行 workflow 内原转换与校验代码：完整的 12 个声明和资源通过，缺资源、缺备选声明均被拒绝。
提交 `3afdf0c18` 的 [最终 iOS Build](https://github.com/xldgo/OpenLegado/actions/runs/38043508339) 已通过，
包括设备 PDE 符号、24 个散文件、最终 plist 引用及 IPA 完整性校验。
上传产物为 `legado-ios-unsigned-ipa`，33,771,299 字节；仓库未配置签名素材，签名步骤跳过。

独立移动端验证的三种 Android Rust ABI 编译完成，但 APK 配置失败于
`ndk.abiFilters` 与 Flutter `--split-per-abi` 同时启用。
按 SDK 中的 splits 处理方式，仅在普通构建中保留已有三种 ABI 过滤；
分 ABI 构建由 Flutter splits 处理，NDK 版本、应用标识及最低系统要求保持原样。
配置依据见 [Flutter ABI 过滤迁移说明](https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android)。
修正后的独立验证分支 `ci/verify-flutter-3.47.7-r2`，提交 `e91bd85ba`，只添加 Android 验证入口，
应用源码与 `c6097ab9f` 相同，build 作业与现有 Android Release 完全一致且不执行发布。
[Android APK 复验](https://github.com/xldgo/OpenLegado/actions/runs/38042393959) 已通过：
三种 release ABI 编译、APK 构建、包内 Rust 库唯一 ABI 与 NDK strip 正规化摘要校验、产物上传均成功。
产物 `android-apk-38042393959-1` 包含 arm64-v8a、armeabi-v7a、x86_64 三份 APK，归档 93,642,141 字节。

已完成的远端验证如下，后续提交未改变对应受测源码时沿用该证据：

| 检查 | 受测提交 | 结果 |
| --- | --- | --- |
| [Flutter CI](https://github.com/xldgo/OpenLegado/actions/runs/38042143246) | `c6097ab9f` | 静态分析及 Flutter 测试通过 |
| [Rust CI](https://github.com/xldgo/OpenLegado/actions/runs/38040975074) | `ce52ccad9` | quality / tests / audit / check 全部通过 |
| [Integration Smoke](https://github.com/xldgo/OpenLegado/actions/runs/38042143259) | `c6097ab9f` | Windows 真实 FFI 与 Android FFI 作业通过 |
| [iOS 模拟器作业](https://github.com/xldgo/OpenLegado/actions/runs/38040761715/job/114180364793) | `3da9b1b17`，应用源码同 `dba4d9177` | 构建、PDE 与两项集成测试通过 |
| [Android APK](https://github.com/xldgo/OpenLegado/actions/runs/38042393959) | `e91bd85ba`，应用源码同 `c6097ab9f` | 三种 ABI 的最终包及库校验通过 |
| [iOS 设备 IPA](https://github.com/xldgo/OpenLegado/actions/runs/38043508339) | `3afdf0c18` | PDE、图标资源/声明、IPA 校验及未签名产物上传通过 |

本轮提交和推送使用升级分支，独立验证入口仅保留在两个验证分支；未合并默认分支、创建标签或发布 Release。
本地与远端升级分支均已包含上述修正；最后回填验证证据的文档提交不改变受测应用和 workflow。

## Android 与 Java 环境 Action 更新

按用户追加要求，`android-release.yml` 使用 `actions/setup-java@v6`；
该文件及 `integration-smoke.yml` 使用 `android-actions/setup-android@v4`，共更新 3 处引用。
[setup-java v6](https://github.com/actions/setup-java/blob/v6/action.yml) 与
[setup-android v4](https://github.com/android-actions/setup-android/blob/v4/action.yml)
支持现有输入，显式 Java 17 和 NDK 27.0.12077973 配置保持原值，
Android 命令行工具采用新版 Action 的默认版本。

9 份 workflow 的 actionlint 与 `git diff --check` 通过；修改 fixup 到已有 Flutter 升级提交，
继续使用 `[skip ci]`，本次未运行远端环境安装或应用构建，实际行为由后续正常构建验证。
Dart SDK 下限和 FRB 依赖未在本批调整。任务状态见 Active 计划的 `CI-SETUP-20261010`。

## 验收边界与后续证据

- Android：远端新 APK、三种 ABI 与包内 Rust 库校验通过；本机缺少 cmdline-tools，16 KB 页设备运行尚未验证。
- iOS：模拟器静态库/宿主、离线阅读集成测试及未签名设备 IPA 构建/包校验通过；已有数据覆盖安装尚未复验，以已可用版本为基线。签名和真机图标能力未由本轮未签名构建验证。
- FRB：真实运行时往返已验证；固定版本 codegen 重新生成的独立复现尚未执行。
- macOS/Linux：本批未构建；macOS 模板仍为原来的 10.15，不能据此宣称适配新 SDK 的 macOS 支持下限。
- 远端 CI：已获授权并推送；Rust stable 的完整 Linux 质量门禁和 Flutter/FFI 门禁已通过，结果及受测提交见上表。

## 官方依据

- [Flutter Windows 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json)
- [Flutter 支持平台](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter 项目 SwiftPM 配置](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [Rust iOS deployment target](https://doc.rust-lang.org/rustc/platform-support/apple-ios.html)
- [Android 16 KB 页兼容要求](https://developer.android.com/guide/practices/page-sizes)

编写者：Codex｜2026-10-10
