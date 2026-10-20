# Flutter 依赖逐项升级记录

任务与进度以 [Active 计划](REFACTORING_ACTIVE_PLAN.md) 的 `DEPS-UPGRADE-20261010` 为准。
基线为 `c3bc6c406`；用户于 2026-10-10 要求逐个升级、针对性验证，跳过整套 CI，
Android APK/iOS 模拟器测试暂缓。使用本地代理 `127.0.0.1:7897`，只设置当前进程环境。

## 现有职责

| 依赖 | 项目中的用途 |
|---|---|
| `flutter_riverpod` | 书架、搜索、阅读等页面的状态与依赖注入 |
| `file_picker` | 本地书籍、书源、备份、字体、图片及导出目录选择 |
| `share_plus` | 系统分享书籍、书源、书签及选中文字 |
| `flutter_local_notifications` | iOS 下载进度与阅读状态通知；Android 走现有原生通道 |
| `flutter_markdown` | 帮助文档的 Markdown 渲染与自定义样式 |
| `palette_generator` | 从书籍封面提取主色，供书籍详情页的“跟随封面换肤”使用 |
| `device_info_plus` | 获取 iOS 的 IDFV，注入 Rust 设备标识上下文 |
| `package_info_plus` | 应用版本和更新判断 |
| `app_links` | 应用链接接收与导入分发 |
| `cached_network_image` | 书籍封面下载、缓存与展示 |
| `video_player` | 视频播放与媒体控制 |

## 执行规则与实际结果

每项只更新对应依赖及必须配套的传递依赖，保持锁文件；兼容修改与该依赖同次提交。
针对已使用 API 运行分析和相关测试；原生权限、系统弹窗、实际分享/通知及打包结果，
必须有真实平台证据才能声明通过。每项提交带 `[skip ci]`，不重复触发完整 CI。

| 项目 | 修改与验证 |
|---|---|
| Markdown | `flutter_markdown 0.7.7+1` → `flutter_markdown_plus 1.0.12`；保持帮助样式、自定义标题 builder 与链接回调；帮助目录分析零问题，标题渲染与章节解析共 4 项测试通过 |
| 封面取色 | `palette_generator 0.3.3+7` → `palette_generator_plus 1.0.0`，显式使用 `LegacyQuantizer`；服务分析零问题，5 组固定图片主色与旧实现逐值相同，另验证空/缺失/损坏文件回退，共 3 项测试通过 |
| 通知 | `18.0.1` → `22.3.1`；初始化/显示/取消改为命名参数，iOS 补通知中心 delegate；通道文件分析零问题，现有音频通知定时与去重 8 项通过；权限及真实系统通知暂未验收 |
| 网络图片 | `cached_network_image 3.4.1` → `4.0.4`；封面组件分析零问题，漫画缓存/封面解码/复合图片地址 46 项测试通过；保持现有占位图和错误组件 |
| 应用链接 | `app_links 6.4.1` → `7.0.0`，保留 `<7.1.0` 上限；深链服务分析零问题，现有导入链接解析 5 项通过；系统链接分发暂未实测 |
| 状态管理 | `flutter_riverpod 2.6.1` → `3.4.3`；保留 Notifier 结构和手动重试，迁移分类 family 构造；分析无错误/警告，相关书架/搜索/阅读/发现/音频/同步/设置测试通过；原有两条测试代码 info 保留 |
| ZIP | `archive 4.0.9` → `4.4.0`；底栏皮肤服务分析通过，使用 Python 标准库生成 ZIP 的独立解码样本通过，现有底栏格式/备份 18 项通过 |
| 偏好存储 | `shared_preferences 2.5.5` → `2.5.6`；现有设置读写/阅读偏好迁移 48 项通过，保留现有存储键 |
| 图片解码 | `image 4.10.1` → `4.10.2`；图库二维码 URL/中文回环与非二维码/损坏输入 4 项通过 |
| 二维码扫描 | `mobile_scanner 7.4.0` → `7.4.2`；扫码页面分析零问题，Dart 调用保持；相机权限与真实扫码暂缓 |
| 外部链接 | `url_launcher 6.3.2` → `6.3.3`；外链确认组件与平台桥接服务分析零问题，保留原有 LaunchMode；实际系统浏览器/应用跳转暂未验收 |
| Android 文件访问 | `saf 2.1.0` → `2.1.2`；书签导出分析零问题，仍使用现有目录选择与字节写入；新版构建脚本保留 AGP 8/KGP 分支，真实授权与文件写入暂未验收 |
| iOS 风格图标 | `cupertino_icons 1.0.9` → `2.0.0`；评论详情组件分析零问题，新旧 `CupertinoIcons.ttf` 的 SHA256 完全相同；主工程无需更换 Cupertino 导入 |
| 媒体播放 | `video_player 2.11.1` → `2.14.1`，必需的 Android 实现更新为 `2.12.2`；音视频调用分析零问题，焦点/悬浮窗交接/连播/进度/地址解析 31 项通过；实际平台播放与打包暂缓 |
| 文件选择 | `file_picker 8.3.7` → `13.1.0`；迁移静态 API、单选/多选返回值与保存 URI；字体改用文件字节读取；相关页面分析零问题，单选取消、多书导入、文件保存与既有导入导出回归通过 |
| 系统分享 | `share_plus 10.1.4` → `13.3.1`；16 处调用迁移至 `SharePlus.instance.share(ShareParams(...))`；保持文本、文件与标题；相关页面分析零问题，书籍分享载荷与现有分享回归通过 |
| 设备信息 | `device_info_plus 11.5.0` → `13.3.0`；现有 iOS `identifierForVendor` 字段仍为可空字符串，无需修改设备标识或 FFI 契约；调用文件分析零问题，真实设备取值暂未验收 |
| 应用版本 | `package_info_plus 9.0.1` → `10.2.2`；保持现有版本解析与缓存；调用文件分析零问题，新增平台版本值与缓存回归通过 |

用户于 2026-10-10 同意最后四个包一起升级，解决新旧包对 `win32 6`/`win32 5` 的约束冲突。
本组共更新 17 项直接及必需传递依赖，移除不再依赖的 `flutter_plugin_android_lifecycle`；
锁定 `win32 6.4.0`，未执行全量依赖升级。四个包及兼容代码同次提交。

文件选择的单选返回 `PlatformFile?`，多选返回文件列表；取消分别按 null/空列表处理。
新版 `saveFile` 接收完整字节、负责写入并返回 URI，页面不再把 URI 当路径重复写入。
保留原有取消兜底、文件内容和格式；图片选择显式保留 Android 原有的压缩质量 30，
其他平台使用新插件默认值。macOS 生成注册文件同步使用 `file_picker_darwin`。

本组两轮定向回归分别通过 56 项、57 项测试（书架测试文件有重叠，不作为独立项合计）；
新增单选取消、多书导入、保存 content URI、书籍分享载荷、应用版本缓存五项用例。
修改涉及的页面、服务与测试分析零问题；原生文件弹窗、iOS 图库行为、系统权限、
真实分享与平台构建仍按用户要求暂缓，平台桩测试不能替代这些验证。

三个 Plus 插件声明 AGP ≥8.12.1、Gradle ≥8.13、Java 17、Kotlin 2.2。
宿主 AGP 从 8.11.1 配套调整为 8.12.1；Gradle 8.14、Java 17、Kotlin 2.2.20 保留。
iOS 宿主最低版本 15.0 满足新文件选择实现的 14.0 下限，RustFFI/CocoaPods 接线保持。
以上为声明与源码审计；Android/iOS 实际编译尚未验证。

通知插件 Android 要求 compileSdk 36、minSdk 24、Java 17、AGP ≥8.11.1 与 desugaring ≥2.1.4；
当前 Flutter 3.47 默认平台值和工程配置均满足，既有 desugaring 2.1.5 保留。
本机缺少符号链接权限；只为工作区的忽略目录创建 Windows 插件目录联接后，
`flutter pub get --enforce-lockfile` 成功。未改全局开发者模式或 SDK 配置，未进行原生构建。

`app_links 7.0.0` 声明 AGP 8.11.1，宿主 AGP 8.12.1 满足其要求；7.1 起转为 AGP 9，
最新 7.2.2 的 Android 构建文件声明 AGP 9.2.1。当前保留 AGP 8 的升级边界，
新版 Android 构建链及实际平台分发需另行验证后再解除版本上限。

`video_player_android 2.12.2` 移除显式 KGP 应用，Flutter 3.47.7 的
`FlutterPluginUtils.detectApplyingKotlinGradlePlugin` 在 built-in Kotlin 关闭时会为插件
补应用 `kotlin-android`。本工程已声明 KGP，保留 `android.builtInKotlin=false`，
不迁移 AGP 9；新旧插件声明的 Media3 均为 1.9.2，原生悬浮窗继续使用同一版本。
以上是构建配置审计，不能替代暂缓的 Android 编译及真实播放验证。

`material_color_utilities` 的 0.13.0 是 Flutter 3.47.7 SDK 精确约束；
未强行覆盖为 0.13.1。其余传递依赖只在对应直接依赖要求时更新，未全量解锁升级。

Riverpod 迁移中，214 份文件经逐文件对照确认只有 import 隐藏名称调整；
不再隐藏主库未导出的 `ChangeNotifierProvider`，继续隐藏与 FFI 类型冲突的 `Provider`。
分类 family 参数改为构造参数，保留 autoDispose。
新版默认自动重试在应用根作用域关闭，保持原有请求和手动重试行为。

实际测试暴露了书架/主题加载在销毁后写 state，以及音频 onDispose 读取 state 的问题。
已为启动加载补 mounted 检查，音频销毁保存改用生命周期前捕获的 API 与最新状态快照。
新增 14 项启动销毁测试和 2 项分类请求迟到测试；现有音频进度保存测试明确校验退出写库。
同步配置测试分别检查真实值变化通知和同值不重复通知，不再依赖旧版对象身份比较。
验证采用定向测试文件；未运行全量测试或远端 CI。

## 停维护包的替代依据

- `flutter_markdown_plus` 是原 Markdown 包的继续维护版本，优先验证现有
  `Markdown`、`MarkdownStyleSheet`、自定义 builder 和链接处理的兼容性。
- 封面取色目前使用 `PaletteGenerator.fromImageProvider`，采样 128×128、颜色上限 64，
  读取 `dominantColor`。替换需先比对算法与固定图片结果，不直接改为另一套主题算法。
  实际选择 `palette_generator_plus` 的旧量化算法；`palette_generator_master` 为算法重写，
  未采用。新增测试的期望颜色来自替换前运行同组图片所得基线。

参考：[Markdown Plus](https://pub.dev/packages/flutter_markdown_plus)、
[Palette Generator Plus](https://pub.dev/packages/palette_generator_plus)、
[Riverpod 3 迁移](https://riverpod.dev/docs/3.0_migration)、
[通知插件迁移与平台要求](https://pub.dev/packages/flutter_local_notifications)、
[应用链接更新说明](https://pub.dev/packages/app_links/changelog)、
[Android 播放器更新说明](https://pub.dev/packages/video_player_android/changelog)、
[文件选择迁移说明](https://pub.dev/packages/file_picker/changelog)、
[分享插件平台要求](https://pub.dev/packages/share_plus)、
[设备信息更新说明](https://pub.dev/packages/device_info_plus/changelog)、
[应用版本更新说明](https://pub.dev/packages/package_info_plus/changelog)、
[AGP 8.12 平台要求](https://developer.android.com/build/releases/agp-8-12-0-release-notes)。

编写者：Codex｜2026-10-10
