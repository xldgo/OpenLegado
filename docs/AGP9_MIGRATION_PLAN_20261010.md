# Android AGP 9 迁移方案

任务编号：`AGP9-MIGRATION-20261010`。状态只维护于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。
本文以 `bdea9b1558d5e4ebcb56a2d7ac838f7a9ded5095` 为基线，记录迁移范围、源码核查、实施顺序和验收要求。
初次交付为独立 worktree 和计划；2026-10-10 用户批准开始实施。实际结果见第 8 节，任务状态见 Active 计划。

## 1. 工作区与范围

- 分支：`feature/ui-agp9-migration`，从当前依赖升级分支的 HEAD 创建。
- worktree：`E:\code\workspace\OpenLegado\.tmp_agp9_migration\worktree`。
- 主 checkout 继续保留 `feature/ui-dependency-upgrades`；迁移与后续回退在新 worktree 内处理。
- Flutter 保持 3.47.7、Dart 下限保持 3.13、FRB 保持 2.13.0、Rust 保持 stable。
- 范围为 Flutter Android 构建链、必要的 Android 插件实现及对应验证；应用版本保持 `2.0.369+370`。
- 阅读界面、数据库、FFI 契约、签名方式、应用 ID、iOS CocoaPods 与 CI 拓扑沿用现状。

worktree 不包含忽略的 `local.properties`、`.dart_tool`、构建目录和 `jniLibs`。
实施时在新目录恢复锁定依赖，并按本机实际 SDK 路径准备 `android/local.properties`。
Gradle wrapper 启动脚本与 JAR 也未纳入当前仓库，先通过 Flutter 的平台准备流程生成，
确认 wrapper 读取本工作树的 `gradle-wrapper.properties`，再调用 `gradlew.bat`。
不得复制主 checkout 的 `package_config.json` 或旧构建目录，它们可能指向另一份源码。
原生库须由当前 worktree 构建，或通过现有指纹、模式、ABI 与契约校验后复用。

## 2. 当前配置与候选组合

| 项目 | 基线 | 迁移方案 |
|---|---|---|
| AGP | 8.12.1 | 候选 9.2.1，配置和真实构建通过后固定 |
| Gradle wrapper | 8.14 | 配套 9.4.1；设置官方分发包 SHA-256 |
| Java / JVM target | 17 / 17 | 保持 |
| Kotlin Android 插件 | 2.2.20 | 第一阶段保留；内置 Kotlin 阶段再移除宿主显式应用 |
| `android.builtInKotlin` | false | 第一阶段 false；所有相关插件适配后改为 true |
| `android.newDsl` | false | Flutter 3.47.7 阶段继续显式 false |
| Flutter Gradle NDK | SDK 默认 28.2.13676358 | 保持 SDK 默认 |
| Rust Android NDK | 27.0.12077973 | 保持，独立验证 `.so` 与 APK 打包 |
| Android SDK 目标 | 使用 Flutter 默认值 | 记录实际值，不因 AGP 支持更高 API 而额外提高 |

AGP 9.2 的官方兼容表要求 Gradle 至少 9.4.1、JDK 17；9.2.1 为该系列补丁版本。
因此不能只替换 `settings.gradle.kts` 中的 AGP 数字。
来源：[Android AGP 9.2 发布说明](https://developer.android.com/build/releases/agp-9-2-0-release-notes)。

本机 Flutter 3.47.7 的 `packages/flutter_tools/lib/src/android/gradle_utils.dart`
模板为 AGP 9.1.0 / Gradle 9.3.1，工具建议认识的 Gradle 上限也是 9.3.1。
该文件明确说明这些常量不构成完整构建支持承诺；9.2.1 / 9.4.1 需要实际验证。
若失败与这组版本有关，先用模板组合定位，保持 app_links 7.0.0 的版本上限，
不能同时跳过版本校验、升级 Flutter 或继续叠加插件变化。

## 3. 三种迁移分别验收

1. **AGP 9 兼容模式**：AGP / Gradle 升级，保持旧 Kotlin 插件和旧 DSL。
2. **内置 Kotlin**：宿主和相关插件完成适配，开启 `android.builtInKotlin=true`。
3. **新版 DSL**：另行迁移；当前 Flutter SDK 尚使用旧扩展类型，不能在本批直接开启。

Flutter 官方说明，3.44 支持 AGP 9 的旧 Kotlin 兼容模式，3.47 起支持内置 Kotlin。
应先确认应用和插件均已迁移再开启内置 Kotlin。
来源：[Flutter 应用迁移说明](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)。

本机 SDK 的 `packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt`
仍将 Android 扩展转换为 `AbstractAppExtension` 并访问 `applicationVariants`。
`disable_new_dsl_migration.dart` 也仍自动补充 `android.newDsl=false`。
这是保留该标志的具体依据，不能把开启新版 DSL 当成 AGP 9 验收条件。

## 4. 插件核查与处理清单

以下基线版本来自已提交 lockfile，Gradle 行为来自对应版本的本机 Pub 包源码；
新版候选及迁移起点来自上游发布说明。源码审计不代表已在 AGP 9 下编译通过。

| 插件 / 实现 | 基线核查 | 处理 |
|---|---|---|
| `shared_preferences_android 2.4.23` | 直接应用 `kotlin-android` | 2.4.24 起声明迁移；候选 2.4.28，单独升级并验证原有偏好值、列表和类型兼容 |
| `url_launcher_android 6.3.30` | 直接应用 `kotlin-android` | 6.3.31 起声明迁移；候选 6.3.33，单独升级并保持原有 LaunchMode |
| `webview_flutter_android 4.12.0` | 直接应用 `kotlin-android` | 4.12.1 起声明迁移；候选 4.14.1，单独升级并检查 Cookie、JS、导航与登录回调 |
| `flutter_tts 4.2.5` | 直接应用旧 Kotlin 插件，保留 `kotlinOptions` | 当前最新稳定版仍为该版本；内置 Kotlin 的重点阻塞候选，先保留兼容模式 |
| `dynamic_color 2.1.0` / `screen_brightness_android 2.1.6` | 按 AGP 主版本决定是否应用 KGP，未读取宿主的 built-in 标志 | 两种模式分别检查；不能仅凭 `agpMajor >= 9` 判定旧模式也可编译 |
| `device_info_plus 13.3.0` / `package_info_plus 10.2.2` / `share_plus 13.3.1` | 按 AGP 与 built-in 标志条件应用 KGP | 第一阶段保留版本，分别确认扩展类型和实际 Kotlin 编译器 |
| `android_file_picker 2.0.1` | 按 built-in 标志分支，但仍使用旧 `LibraryExtension` 和独立 AGP/KGP classpath | 保留旧 DSL；优先核查类型转换、插件 classpath 与编译目标，不强制全局覆盖依赖 |
| `mobile_scanner 7.4.2` / `saf 2.1.2` | 已有条件应用 KGP 的分支 | 保留版本，检查两种模式与插件任务注册 |
| `video_player_android 2.12.2` | 未显式应用 KGP，但配置 Kotlin 扩展 | 验证 Flutter 在旧模式补应用 KGP、内置模式直接编译；Media3 仍为 1.9.2 |
| `app_links 7.0.0` | 当前声明 AGP 8.11.1 | AGP 9 构建稳定后再单独评估 7.2.2；其发布包声明 AGP 9.2.1 |
| 通知、sqflite、integration_test | 基线 Android 脚本未显式应用 KGP | 检查插件注册、desugaring、JUnit 与资源处理，不能由此直接宣称完全兼容 |
| `path_provider_android 2.3.1`、`jni`、`jni_flutter` | 涉及 JNI / Code Assets；path_provider 的元数据标为非 Gradle 原生模块 | 核对最终 native 资产；不对没有 Android Gradle 入口的包套用 KGP 替换 |

上游迁移起点：[偏好存储](https://pub.dev/packages/shared_preferences_android/changelog)、
[外部链接](https://pub.dev/packages/url_launcher_android/changelog)、
[WebView](https://pub.dev/packages/webview_flutter_android/changelog)。
TTS 版本依据：[上游稳定版列表](https://pub.dev/packages/flutter_tts/versions)。

TTS 若仍无稳定版适配，应保留第一阶段成果，把内置 Kotlin 单独登记为待适配。
确需维护补丁时，限定为 Gradle 接线，用可审阅的仓库内补丁或固定提交的依赖来源，
保留许可证和上游差异；实施前明确维护范围。不得直接改共享 Pub 缓存或为了构建替换 TTS 功能。

## 5. 实施顺序与提交边界

| 阶段 | 修改范围 | 退出条件 |
|---|---|---|
| A：基线与插件准备 | worktree SDK 配置；三项 Android 实现按包单独更新 lockfile | 每项依赖解析及相关分析/回归通过；锁文件差异仅含必需依赖 |
| B：AGP 9 兼容模式 | `android/settings.gradle.kts`、Gradle wrapper、必要兼容配置 | 9.2.1 / 9.4.1 / Java 17 配置成功；保留两个 false 标志，旧 KGP 仍可用 |
| C：原生构建验收 | 当前工作树的 Rust 库、宿主 Kotlin/JVM、debug 与 release APK | 真实构建和产物校验通过，FFI 校验仍在 preBuild 链路中；才能关闭 AGP 9 构建迁移 |
| D：应用链接 | 单独调整 app_links 上限与 lockfile，必要的平台接线 | 导入解析及冷/热启动链接去重回归；跨平台改动分别登记未验证项 |
| E：内置 Kotlin | 宿主插件应用与 compilerOptions、残留第三方接线 | 相关插件均完成迁移，built-in=true / newDsl=false 下重复通过 C 的适用验证 |

阶段 B 不同时移除宿主 KGP。若出现 Kotlin 元数据或插件 classpath 冲突，依据实际错误
单独调整必要的 KGP 组合，不用全局 force 掩盖冲突。
阶段 E 才从 app 插件块移除 `kotlin-android`，
把 `android.kotlinOptions` 移至顶层 `kotlin.compilerOptions`，保持 JVM target 17。
确认没有旧插件仍需要宿主 KGP 声明后，再清理 settings 中的显式 KGP 版本。
内置模式的 Kotlin 编译器由 AGP 配套依赖提供，记录实际版本，不另强行统一插件 stdlib。
接线依据：[Flutter 插件迁移说明](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)。

app_links 7.2.2 还改变了链接排队和 Activity 重建时的重发行为；Windows/iOS/macOS 也有修复。
因此解除 `<7.1.0` 上限应独立提交，不能只用 Android 配置成功作为所有平台的验收证据。
来源：[app_links 更新记录](https://pub.dev/packages/app_links/changelog)。

## 6. 验证顺序与成本控制

先运行不依赖模拟器的配置检查，失败时修复当前阶段，不继续叠加。
在 worktree 的 Flutter 目录准备好 SDK 路径和锁定依赖后：

```powershell
$agp9Root = 'E:\code\workspace\OpenLegado\.tmp_agp9_migration\worktree'
Set-Location (Join-Path $agp9Root 'flutter_legado')
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --suggestions
Set-Location (Join-Path $agp9Root 'flutter_legado/android')
.\gradlew.bat --version
.\gradlew.bat help --warning-mode all
```

APK/JVM 构建需要当前 worktree 的 native 库。
原生构建前明确把 `ANDROID_NDK_HOME` 设置为本机 27.0.12077973 的安装目录；
本地脚本自动探测会选择最新目录，不能依赖该探测来保证 NDK 版本。
用户已暂缓 Android APK/iOS 模拟器测试；以下是恢复验证后的执行路线，本轮不运行：

```powershell
$agp9Root = 'E:\code\workspace\OpenLegado\.tmp_agp9_migration\worktree'

# 当前进程：沿用 Android Release 对三个 Rust target 的 16 KB 链接参数。
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS = '-C link-arg=-Wl,-z,max-page-size=16384'
$env:CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_RUSTFLAGS = '-C link-arg=-Wl,-z,max-page-size=16384'
$env:CARGO_TARGET_X86_64_LINUX_ANDROID_RUSTFLAGS = '-C link-arg=-Wl,-z,max-page-size=16384'

# 仓库根目录：只构建，不安装；debug 最低 ABI 集为 arm64-v8a / x86_64。
Set-Location $agp9Root
.\flutter_legado\scripts\build-apk.ps1 -BuildOnly

# Flutter Android 工程目录：既有存储参数、媒体 Session、通知文字及视频逻辑回归。
Set-Location (Join-Path $agp9Root 'flutter_legado/android')
.\gradlew.bat :app:testDebugUnitTest --warning-mode all

# 仓库根目录：准备三 ABI 的 release Rust 库；参数在执行前按本机 NDK 路径复核。
Set-Location $agp9Root
.\rust\scripts\build-android.ps1 -Mode release -Targets "aarch64,armv7,x86_64"

# Flutter 目录：与既有 Android Release 一致的三 ABI 打包。
Set-Location (Join-Path $agp9Root 'flutter_legado')
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64
```

最终产物至少核对：三 ABI 的 Rust 库、FRB 契约/源码指纹、NDK strip 正规化摘要、
插件 native 资产、清单权限、包名、签名和版本。保留既有 16 KB 链接参数，
APK ZIP 对齐、ELF 段对齐与 16 KB 设备实际运行分别记录，不能互相代替。
现有入口：[Android Release](../.github/workflows/android-release.yml)、
[本地构建](../flutter_legado/scripts/build-apk.ps1)、
[原生校验](../rust/scripts/verify-ffi-android.ps1)。

插件只跑对应的偏好读写、外链、WebView、TTS 生命周期和链接导入测试。
普通 Dart Mock 通过不能证明系统弹窗、权限、偏好旧数据或音频真实行为。
候选稳定且用户恢复 APK 验证后，优先手动运行一次既有 Android Release，
不触发 iOS/Rust/Flutter 全套 CI，不新增一次性 workflow。
提交使用 `[skip ci]`；本轮计划提交也跳过 CI。

## 7. 回退与完成条件

- 每个阶段独立提交；出现编译或运行回退，先回退该阶段，不改已推送历史。
- 基线是 bdea9b155 的 AGP 8.12.1 / Gradle 8.14 / KGP 2.2.20；主 checkout 保留该基线。
- app_links 的上限只在候选构建成功后解除；回退构建链时同步回退其依赖提交。
- 构建迁移完成须有实际配置、宿主编译、debug/release APK 和 native 校验证据。
- 内置 Kotlin 另行验收；newDsl 迁移另行排期。设备与 iOS 专属验收缺能力时保留待办。
- 本轮文档校验与 worktree 创建只关闭计划交付范围，不构成 AGP 9 构建通过。

## 8. 实施证据（2026-10-10）

### 偏好存储 Android 实现

- 锁定项 `shared_preferences_android`：2.4.23 → 2.4.28，其他依赖未变。
- `flutter pub get --enforce-lockfile` 成功；工作树单独生成依赖配置。
- 对 `settings_service.dart` 和下列三个测试文件执行 `dart analyze`，零问题。
- `settings_service_test.dart`、`reader_pref_migration_test.dart`、`restore_ignore_prefs_test.dart` 共 55 项通过。
- 本地输出：工作树 `.tmp_agp9_tools/preferences-tests.log`。这些测试使用 Mock，未验证 Android 原生旧数据读取。

### 外部链接 Android 实现

- 锁定项 `url_launcher_android`：6.3.30 → 6.3.33，其他依赖未变。
- 精确依赖恢复成功；对 16 个 `url_launcher` 调用文件及 `source_login_screen_test.dart` 定向分析，零问题。
- 来源登录页面既有 Widget 测试 1 项通过，输出为工作树 `.tmp_agp9_tools/url-tests.log`。
- 未改动 URI 和 LaunchMode；页面测试未调用 Android 的 Intent，外链实际启动待原生验证。

### WebView Android 实现

- 锁定项 `webview_flutter_android`：4.12.0 → 4.14.1，其他依赖未变。
- 精确依赖恢复成功；6 个 `webview_flutter` 调用文件及下列测试文件分析零问题。
- `source_login_test.dart` 与 `webview_login_header_test.dart` 共 13 项通过，输出为工作树 `.tmp_agp9_tools/webview-tests.log`。
- 这些测试覆盖应用侧登录信息与请求头解析；Android Cookie、JS 执行、页面导航及登录回调仍待原生验证。

编写者：Codex｜2026-10-10
