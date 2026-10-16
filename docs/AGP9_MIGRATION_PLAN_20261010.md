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
| Kotlin Android 插件 | 2.2.20 | 实际配套更新为 2.4.21；内置 Kotlin 阶段再移除宿主显式应用 |
| `android.builtInKotlin` | false | 第一阶段 false；所有相关插件适配后改为 true |
| `android.newDsl` | false | Flutter 3.47.7 阶段继续显式 false |
| Flutter Gradle NDK | SDK 默认 28.2.13676358 | 保持 SDK 默认 |
| Rust Android NDK | 27.0.12077973 | AGP 阶段保持；后续用户同意统一至 28.2.13676358，见 ANDROID-NDK28-20261011 |
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
阶段 E 才从 app 插件块移除 `kotlin-android`。
宿主 `android.kotlinOptions` 已因 KGP 2.4.21 的实际错误在阶段 B 提前改为顶层 `kotlin.compilerOptions`，保持 JVM target 17。
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
原生构建前把 `ANDROID_NDK_HOME` 设置为本机 28.2.13676358 的安装目录；
当前 PS 默认查找该版本，显式路径仍由开发者配置。以下命令已按后续 NDK/RELRO 修复更新；
第 8 节的 NDK 27 结果保留为当时的实际证据。
用户最初暂缓 Android APK/iOS 模拟器测试；随后确认安装 MuMu 并允许必要的设备测试，Android 验证恢复，iOS 模拟器仍暂缓。以下为 Android 验证路线：

```powershell
$agp9Root = 'E:\code\workspace\OpenLegado\.tmp_agp9_migration\worktree'

# 页对齐参数由仓库 rust/.cargo/config.toml 提供，无需设置额外 Rustflags。

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
现有入口：[Release](../.github/workflows/release.yml)、
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

### AGP / Gradle / Kotlin 兼容模式

- AGP 9.2.1 / Gradle 9.4.1 配置通过；wrapper 的 `distributionSha256Sum` 来自官方 `.sha256` 文件，为 `708d2c6ecc97ca9a11838ef64a6c2301151b8dd10387e22dc1a12c30557cab5b`。
- 原 KGP 2.2.20 触发 Flutter 的 Gradle 不兼容提示；官方表列出其完整支持范围止于 Gradle 8.14。2.4.20–2.4.21 覆盖 Gradle 9.4.1 与 AGP 9.2.1，配套采用补丁版 2.4.21。
- KGP 更新后的首次配置失败明确指向旧 `kotlinOptions.jvmTarget` 的错误级弃用；仅将宿主 JVM 目标配置改为顶层 `compilerOptions`，保持 17。没有禁止警告、跳过兼容校验或改共享 Pub 缓存。
- Java 17.0.20.1 下 `flutter analyze --suggestions` 显示四项工具兼容；最终 `gradlew.bat help --warning-mode all` 成功，日志为工作树 `.tmp_agp9_tools/gradle-help-final.log`。
- Flutter 自带 Gradle 插件与第三方旧 DSL 的弃用警告仍存在；当前 TTS 为明确的内置 Kotlin 待适配项，兼容模式下可配置。
- 本机缺少对应 Java 17 与 Rust NDK 27，分别在工作树忽略目录下载并核对官方校验后解压；进程内选择，不改变全局 Java 设置。Flutter Gradle 自动补装 SDK 默认 NDK 28.2，Rust 构建仍明确使用 NDK 27.0.12077973。
- 原构建脚本无 UTF-8 BOM，Windows PowerShell 5.1 解析失败；改用本机已有 PowerShell 7 执行，不修改脚本内容或编码。

来源：[Gradle 分发包校验值](https://services.gradle.org/distributions/gradle-9.4.1-all.zip.sha256)、
[Kotlin 官方兼容表](https://kotlinlang.org/docs/gradle-configure-project.html#apply-the-plugin)。

### 提交与设备准备

- 用户要求将之前的依赖升级提交压缩为 `1805569d6`，本次三项 Android 实现压缩为 `d035e2702`；新旧文件树摘要完全相同，两条分支使用精确 `force-with-lease` 原子推送。
- 主 checkout 的 CI 工作区修改及暂存区未被覆盖；迁移 worktree 的计划提交同步重建祖先关系。
- MuMu 实时探测：新安装路径 `C:\Program Files\NetEase\MuMu`，index 0，Android 15 / API 35，adb `127.0.0.1:16384` 为 device；支持 x86_64。本记录只是当前连接证据，后续仍需重新探测。
- Android 构建与设备验证按用户最新授权恢复，实际结果后续回填；iOS 模拟器继续暂缓。

### 原生库与本地环境

- 本机 Rust stable 实际为 1.99.0；明确使用 NDK 27.0.12077973，为三个 target 设置 16 KB 链接参数。aarch64 与 x86_64 的 release 库启用 QuickJS，当前源码指纹及 FRB 契约校验通过。
- armv7 启用 QuickJS 时，`rar 0.4.0` 的 `nom::take(u64)` 在 32 位平台缺少 `ToUsize` 实现。既有脚本按 Android Release 的策略降级为不启用 QuickJS，构建成功。本轮不修改 Rust 依赖或解析器；32 位包不具备本次 64 位包的 JS 能力。
- 对打包副本使用 NDK 27 的 `llvm-strip --strip-unneeded`，保留 Cargo 原产物；三 ABI 的 ELF 加载段均为 16384 对齐。包内库还须与 Cargo 原产物经同一工具正规化后核对 SHA-256，不能用 FRB hash 代替来源验证。
- 首次 Android 宿主编译失败来自 Kotlin 增量缓存：C 盘 Pub 源码与 E 盘工程不能转换相对路径。为该工作区设置 E 盘独立 `PUB_CACHE`，复用当前锁定包，移除该插件失败的增量缓存后，原 `:android_file_picker:compileDebugKotlin` 成功。保持增量编译，不修改全局 Pub/Gradle 设置或插件源码。
- 本机 PowerShell 7 用于执行无 BOM 的原生脚本；Java、代理、Pub 缓存与官方 Flutter 资产源均为进程设置。新 worktree 执行依赖恢复后需要使用相同环境，不依赖其他 checkout 的生成配置。
- 当前 MuMu 为 4 KB 页环境。APK ZIP/ELF 对齐检查与 MuMu 启动不能代替 16 KB 页设备的运行验证。
- 本地日志位于工作树 `.tmp_agp9_tools/native-release.log`、`android-file-picker-kotlin-final.log`；产物校验使用同目录 `verify-native-apks.py`。日志与工具为忽略的验证材料，不写入提交正文。

### Android 编译与首轮冒烟（2026-10-11）

- `flutter build apk --debug --no-pub` 成功，全部原生插件完成编译；首次构建自动补装 Android SDK 36 与 CMake 3.22.1。APK 中三 ABI 的 Rust 库均与当前 Cargo 原产物经 NDK 27 strip 正规化后的摘要一致。
- `:app:testDebugUnitTest` 成功，四类既有宿主测试共 24 项，失败/错误/跳过均为零。覆盖存储参数、媒体 Session、通知文本与视频逻辑，不等同听书或通知权限的真实设备验收。
- MuMu 上运行既有 `emulator_smoke_test.ps1 -Device 127.0.0.1:16384 -SkipBuild`，6 项检查通过：在线、APK 存在、安装、版本、进程和崩溃检查。UI 转储已显示书架与搜索入口；未使用历史端点。
- 日志：工作树 `.tmp_agp9_tools/apk-debug.log`、`apk-debug-native-check.log`、`android-jvm-tests.log`、`mumu-smoke.log`；JVM 原始 XML 在 `flutter_legado/build/app/test-results/testDebugUnitTest/`。
- 真实 FFI 的三个测试全部通过：初始化、版本读取与数据库查询。现有平台无关的离线搜索阅读测试也在 MuMu 通过：本地 HTTP 书源导入、两条搜索结果、章节目录、第一章正文及 UI 点击翻到第二章。分别使用 `ffi_smoke_test.dart` 与 `e2e_search_read_ios_test.dart`；文件名含 iOS 不代表本次运行了 iOS。
- 设备测试日志为工作树 `.tmp_agp9_tools/mumu-ffi-smoke.log` 和 `mumu-reading-e2e.log`。阅读样本只含 CSS，未覆盖实际 JS 书源、WebView 登录、后台 TTS 与通知权限。
- 三 ABI release APK 构建成功，原生库正规化摘要、包名、签名、版本与 ZIP 对齐通过；64 位包内所有 `.so` 的 LOAD 段满足 16 KB 对齐。app 版本仍为 `2.0.369+370`，ABI split 使用 Flutter 既有规则生成 versionCode 1370 / 2370 / 4370。
- 集成测试后的首次 release 使用 `--no-pub`，遗留了测试插件注册，导致 `IntegrationTestPlugin` 找不到；恢复正常 `flutter build apk --release --split-per-abi` 流程后生成文件正确过滤 dev 插件，构建成功。不手改注册文件，lockfile 未变化。
- 最终日志为工作树 `.tmp_agp9_tools/apk-release-final.log`、`apk-release-native-check.log`、`apk-release-package-check.log`，清单/签名/ELF 原始报告为 `android-package-report.json`。RELRO 结果单独登记，不由前述校验推导兼容。

### 新发现的 RELRO 对齐风险（2026-10-11）

NDK 27 构建出的 Rust 库虽有 16 KB LOAD 对齐，但 `GNU_RELRO` 虚拟地址加内存长度的末尾模 16384 仍非零：aarch64 为 `0x1000`、x86_64 为 `0x3000`、armv7 为 `0x1000`。该项是直接读取本次 ELF 程序头所得，不是设备运行失败的推断。

Android 官方新增说明指出，NDK 27 及以下未设置相应链接参数的 RELRO 保护区可能在 16 KB 环境导致段错误。现有 CI/本地设置只指定 `max-page-size`，LOAD/ZIP 检查不能证明 RELRO 合规；本轮 MuMu 为 4 KB，不能排除该风险。最终包中部分 Flutter/JNI/AndroidX 等第三方库也有非零 RELRO 余数，须作为待核查项记录，不能单靠 Rust 修复宣称整包运行兼容。

用户于 2026-10-11 确认：AGP 迁移后单独修复 Rust 原生链接参数，分开提交。实际状态维护于 Active 计划。

来源：[Android 16 KB RELRO 检查与编译要求](https://developer.android.com/guide/practices/page-sizes#relro)。

用户授权的独立修复已补齐参数，并按追加要求仅在本地验证 x86_64 新库、测试 APK
及 MuMu 真实 FFI；其余 ABI 由后续平台构建验证。方法与证据见
[Rust Android RELRO 修复记录](ANDROID_RELRO_20261011.md)，当前状态只维护于 Active 计划。

### app_links 7.2.2 与最终设备回归（2026-10-11）

- AGP 真实构建通过后解除版本上限，改用 `^7.2.2`。新版要求 Linux 1.0.4 / Web 1.0.5，移除无调用方的传递包 gtk；Linux 注册文件由 Flutter 同步生成，其他包未升级。
- 精确依赖恢复成功；链接服务、解析器、导入页面和测试定向分析零问题。5 项解析测试通过；后续连同欢迎页导航门控测试共 10 项通过，不重复计数为额外覆盖。
- MuMu 暴露旧、新 app_links 在重复热启动链接时关闭弹窗。相同 release 模式的 7.0.0 基线与 7.2.2 均复现；Flutter Android embedding 源码证实 `onNewIntent` 额外发送默认 `pushRouteInformation`，与现有 MethodChannel 重复处理。
- 按 Flutter 与插件官方接线要求，在 MainActivity 清单设置 `flutter_deeplinking_enabled=false`。关闭重复处理后，冷启动还暴露欢迎页的 `pushReplacementNamed` 会替换初始弹窗；复用已经测试的欢迎页门控，等待主页就绪后 attach 深链，不重写导入业务、导航体系或页面。
- 最终 release APK 在 MuMu 通过冷启动、热启动、重复去重、关闭后再次打开及 yuedu 入口。检查每次新生成的 UI XML；MuMu uiautomator 写出后返回 139，记录该工具退出，并按应用 PID 检查崩溃，避免混淆工具和应用。无 src 测试只打开弹窗，不请求外网或写入书源。
- 三 ABI 最终包已重新构建并核对 Rust 来源、清单/版本/签名/ZIP 与 LOAD 对齐。用户版本保持 `2.0.369+370`；测试结束安装正常 release 包，未清空应用数据。Android 走原自定义通道，iOS 的插件事件流与 Linux/Web/Windows 运行仍未验收。
- 日志：工作树 `.tmp_agp9_tools/app-links-analysis.log`、`deep-link-startup-tests.log`、`mumu-deep-links-baseline.log`、`mumu-deep-links-agp9-final.log`、`apk-release-agp9-final.log`、`apk-release-agp9-final-native.log`、`apk-release-agp9-final-package.log`。提交不含这些本地日志正文。

来源：[Flutter 默认深链处理退出说明](https://docs.flutter.dev/ui/navigation/deep-linking#migrating-from-plugin-based-deep-linking)、
[app_links Android 接线](https://github.com/llfbandit/app_links/blob/main/doc/README_android.md)。

编写者：Codex｜2026-10-10；补充构建与设备证据｜2026-10-11
