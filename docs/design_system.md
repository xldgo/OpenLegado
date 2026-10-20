# Legado Flutter 设计规范文档（Material Design 3）

## 系统栏设置边界（2026-10-20）

普通页面固定边到边与透明系统栏，不再提供全局沉浸开关或对应持久化设置。
SystemBarBinder按当前主题顶底背景计算图标明暗，经SystemBarController和SystemBarService
同步到平台；Android状态栏及导航栏图标均更新，系统对比度遮罩关闭。
阅读器继续独立控制显隐，菜单临时显示、切页、退出和前台恢复遵循页面归属。
应用内底栏不透明度、模糊和玻璃参数保持独立，不作为系统栏背景开关。

编写者：Codex + UI｜2026-10-20

## 下载与缓存设置（2026-10-19）

主设置“其他”分组新增“下载与缓存”，命名路由/download_cache_settings。
参照HapeLee main/c4182eb9的DownloadCacheConfigScreen，页面按HTTP缓存、下载设置、
图片缓存、网络、其他操作分组，复用SettingsBody/SettingsGroup/SettingTile。
原高级页移除对应项，既有离线缓存列表和缓存统计页面保持各自职责。

并发配置标题为“更新和搜索线程数”，副说明为“线程数太多会卡顿”。
Sheet复用AppSettingsSheet，仅保留数字输入框，1～256限制在非法输入时提示，
不重复放置滑块或生效时机说明；取消不写入、非法值保留编辑、失败由仓储回退。
弹层期间只设置防重入标记，背景行保持原外观及箭头；维护执行的忙碌状态独立处理。
清理和压缩继续确认，执行时互斥禁用，离页后不发布迟到提示；
正文清理仅删除已下载正文及章节缓存标记，配置、下载记录、登录和音频进度保持。
不将无释放量的压缩返回值报告为成功。清理章节后同步清除章级重复标题镜像标记。

正文“向后预下载”为当前章之后，“向前预下载”为当前章之前，范围均为0～100，
默认10/0，0关闭对应方向；公共数字Sheet编辑，取消不保存。两项通过统一设置服务
持久化到SharedPreferences的preDownloadNum/preDownloadNumPrev，并通知阅读器更新窗口。
预取最多2个辅助请求同时执行，切书/换源/离页停止旧窗口后续调度；已发出的FFI请求允许收尾。

未接线的图片缓存容量/保留和User-Agent继续只读展示旧值并标明待实现，
不新增无消费者的设置写入。封面缓存显示自有图片文件的实际大小，点按确认后清理已有封面缓存，失败可重试；
加载中的图片继续完成并可重新缓存，不承诺清理后持续为零。漫画缓存保留禁用占位，
副说明为“待实现”，不显示虚构大小、不提供清理回调；Cronet继续未接线。
封面仍由CachedNetworkImage展示，注入应用级专属CacheManager，普通及解密结果共用
缓存范围。清理不影响本地封面原件、漫画、RSS、正文或音频，不强制移除当前显示帧。

书籍缓存下载线程数使用独立CacheDownloadSettingsRepository，经共享AppSettingsService
写入Rust配置cacheBookThreadCount；范围1～8、默认8，数字Sheet取消不写入、失败回退。
副说明明确新任务生效。多个显式离线任务按书籍FIFO，队首书内并发，保留原取消与断点恢复。
不复用搜索线程数或正文前后预下载的SharedPreferences键。

来源：[上游页面](https://github.com/HapeLee/legado-with-MD3/blob/c4182eb9bcdd2e52eb6bb44d14c37856e592a99a/app/src/main/java/io/legado/app/ui/config/downloadCacheConfig/DownloadCacheConfigScreen.kt)。

编写者：Codex + UI｜2026-10-19

## 开书导航（2026-10-19）

对齐参考版main / 15e1337a：书架单击不区分是否未读，按书籍类型直接进入阅读器或
播放器，长按进入详情；首页最近阅读、阅读记录与离线缓存采用相同直开规则。
详情加载与刷新只更新展示数据，点击阅读按钮才打开阅读器。直开返回来源页面，
不额外压入详情页；正常详情页进入阅读后仍返回详情。

书架列表、网格与详情阅读按钮通过BookCoverHero.originFor查找当前路由内可见封面，
向文字阅读器传递BookCoverOrigin。BookReaderRoute采用480ms翻开/400ms合上，
位移、尺寸、圆角及书脊旋转共用完整缓动进度，边翻盖边放大，返回同步合盖缩回，
不设置翻开延迟或提前结束放大。纸面与封面共用平移、等比缩放的绘制矩阵，文字随纸面
真实放大；封面正面可见时纸面同高，翻过侧面后纸面才延展为屏幕比例，返回反向收拢。
专用圆角裁剪只处理该边界和圆角。封面正常进场固定来源卡片比例，在该比例下使用cover裁切，
不逐帧跟随屏幕比例裁切或拉伸图片；来源移动/改变尺寸时，返回从当前绘制帧连续重定向，
同时平滑匹配新来源比例，不在切换方向时重新捕获图片造成闪变。
绕左侧书脊叠加三维旋转，带轻微透视及纸面阴影，超过90度只绘制纸张背面，
不镜像展示封面文字。正文始终按最终视口布局，不在动画期间重新分页或完成时重新挂载。
封面转场不等待阅读会话切书；未就绪时隐藏旧正文，仍按目标书处理隐私保护。
正文不做整体渐变透明合成，完成后可正常显示后续会话/错误状态；仅保留纸面外阴影和书脊渐变。
首页最近阅读、首页及阅读总览排行榜、阅读记录三种模式从被点击卡片内查找封面，
经BookOpenUtils统一传递，不要求每张缩略图注册Hero；同书重复出现时不取其他行的封面。
图像使用已解码帧的独立引用，不拉网、不重新解密、不截取全文；返回重新测量起点。
无封面、尚未加载、默认占位或返回来源失效时，使用项目主题默认导航动画，
不再单独淡入淡出；切换外层动画也保留同一正文元素。减少动态效果时直接切换。
阅读日历只打开日期明细，不新增开书行为；无封面的离线缓存、启动和通知入口使用默认转场。
路由完成后保持不透明，来源页停绘；图片引用随路由释放。隐私加载/失败/回锁时
不绘制飞行封面，保留原退出保存门禁。已有章节spinner与网络加载独立于动画，
不增加人为加载等待；漫画/音频/视频路由保持原行为，不新增动效开关。

编写者：Codex + UI｜2026-10-20

## 液态玻璃资源与主题边界（2026-10-18）

liquid_glass_widgets 固定 1.13.0，仅通过项目材质适配接入。AppGlassRuntime
在启动时与设置/FFI并行预热，每次进程只初始化一次；预热失败保留普通材质，
不作为FFI错误阻止启动。库的帧预算告警监视器关闭，性能结论使用独立profile取证。
AppGlassHost在应用主题内提供明确亮度与固定standard质量，尊重系统减少动态效果
和高对比度；不在页面build中重复调用修改库全局配置的wrap。
AppGlassStyle集中转换最终底色和模糊输入，颜色alpha不二次相乘；库blur暂使用
原有逻辑像素参数，实际效果需设备校准，不宣称与高斯sigma视觉等效。
公共页面不依赖第三方导航模型；玻璃导航与按钮按批次接入，不替换全站页壳。

悬浮导航通过AppFloatingBottomBar适配GlassTabBar.bottom，保留AppNavSpec、
SkinNavIcon与应用切页回调。useFloatingBottomBarLiquidGlass默认false，独立于
enableBlur；资源未预热成功时使用普通材质。液态模式使用既有底栏blur/tint参数，
普通模式使用原有背景规则。底栏保留64dp基准高度、左右16dp；玻璃模式底部取安全区与
12dp最小留白的较大值，不再相加，普通模式保持12dp加安全区。外侧留白由项目统一计算。
库负责玻璃/选中指示器/按压与拖动反馈，不再叠加旧
AnimatedScale；普通模式仅保留选中背景过渡，尊重减少动态效果。
库按下选择及拖动释放回调均转发应用，重复点击仍可触发书架双击回顶；普通模式
在点击完成时转发。玻璃图标不额外嵌套Material按钮，以免竞争手势或重复语义。
应用明确传入前景颜色，库的两套图标视觉层只保留一组无障碍入口。
固定standard质量是本轮接线策略；组件行为测试使用minimal档位验证真实导航，
不能据此声明standard着色器视觉、Impeller表现或GPU开销已验收。

顶栏liquidGlass档通过TopBarActionStyler与TopBarButton的背景适配GlassContainer，
独立按钮绘制36dp圆形，合并动作只绘制一层36dp高的圆角胶囊；玻璃背景IgnorePointer，
原IconButton/AppMenuButton保留48dp点击区域、禁用态、键盘、长按提示及菜单定位。
不新增GlassIconButton手势层或自定义缩放，减少动态效果继续由既有按钮和库作用域处理。
合并仅作用于右侧动作；返回按钮独立、Plain档不合并。胶囊背景在48dp点击层内缩6dp，
单动作自然退化为36dp圆形；不再给单按钮叠加胶囊内边距或塞进leading的固定宽度。
预热状态变化保留按钮/菜单所在节点，避免菜单被重建。未预热成功回退原半透明实色。
按钮底色保持原色alpha乘0.5，光学blur固定8逻辑像素，独立于整栏设置；
AppSurfaceMaterial.button统一参数，AppGlassStyle执行库参数转换。glass档仍使用实色。
文字动作与自定义菜单入口不压入图标槽位；已有页面的显式plain档优先于全局样式。
搜索范围与筛选动作在合并模式不再绘制独立圆形底色，筛选开启时用primary图标区分，
不覆盖胶囊材质；未合并时保留原有激活底色与前景组合。

主页悬浮底栏使用AppScaffold.extendBody让正文在底栏后方绘制；默认页壳仍不延伸。
主页在Scaffold的body上下文取得实际底栏占用高度，经AppBottomBarInset提供给
各子页，不硬编码胶囊/安全区总高度；移除Scaffold为extendBody注入的正文底部
padding，避免嵌套SafeArea把整个视口缩回。尾部留白仅添加到ListView内容padding
或Sliver尾部，保证末项能滚到可操作区域；标准栏、隐藏、侧栏与键盘遮挡时不叠加。
作用域限于主页子树，独立路由默认零占用；切换模式保持页面、控制器与滚动状态。

编写者：Codex + UI｜2026-10-18

> 数据来源：`flutter_legado/lib/src/theme/app_theme.dart`（MD3 主题装配）、`md3_colors.dart`（12 套内置调色板）、`app_typography.dart`（M3 字阶）
> Token 来源基准：Material Design 3 官方指南（Expressive 视觉层），12 套内置命名主题 × 亮/暗 tonal 配对，语义槽位与 Android 原版一一对应
>
> **定位说明（2026-09-27）**：本文只定义 Flutter 实现使用的主题 Token 与生成关系，不定义产品视觉目标。布局、间距、形态、图标、文案、配色、字体和明暗主题均按参考版截图一比一验收，执行依据为 `SCREEN_1TO1_PARITY_SPEC_20260914.md` 与对应台账；MD3 Token 是实现工具，不能覆盖参考版基准。旧版“视觉风格自由”及仅按 Material 规范验收的描述均已废止。修改 Token 时同步维护本文与代码实现（`md3_colors.dart` 走生成器）。

## 胶囊底栏文字（2026-10-18）

胶囊默认显示全部导航文字。主页复用labelVisibilityMode：auto与labeled都显示全部，
unlabeled保持纯图标；标准底栏仍按原三档处理，不改偏好数据。AppFloatingBottomBar
通过默认true的showLabels参数接收结果，GlassTab使用label/null，名称语义始终保留。
普通胶囊采用相同图标+文字结构；不实现只选中标签或额外文字显隐动画。
底栏选中/未选中字重统一由NavigationBarTheme.labelTextStyle按状态提供，默认600/500；
普通与Glass胶囊读取该主题字重，字号与行高仍来自labelSmall，不修改全局字阶。
文字前景显式跟随应用主题，单行超出省略；64dp为基准，大字时将内容行高向上取整
后增加底栏高度，避免分数字体度量溢出。正文尾部留白继续消费实际测得的占用。

玻璃胶囊参照组件库示例采用28dp图标与0dp图文间距，皮肤图片同步28dp；标签继续使用
项目labelSmall（默认11sp）及界面字体。普通胶囊的图标、标签与间距不受此调整影响。
0dp指布局盒之间的间距，图标字形与文字行框内仍有留白，不裁切文字行高。

编写者：Codex + UI｜2026-10-18

## 阅读器 Glass 控件（2026-10-18）

用户批准阅读器采用新的 Glass 界面，不保留旧布局或材质开关。第一批使用独立返回
按钮、右侧共用表面动作组及书名/章节信息面板；书名置于信息面板内，避免在正文上
直接绘制低对比度文字，也避免窄屏下被动作组挤压。进度和五键操作分为两个悬浮面板，
左右12dp、间隔10dp、底部12dp加安全区、四角28dp。正文与排版布局不变。

ReaderMenuControlTheme集中向SDK Cupertino和GlassTheme传递局部阅读主题的亮度与
强调色；应用仍使用material_ui主题。ReaderMenuControlButton/ProgressSlider只接受
图标、文案、数值及回调；实际使用GlassButton/GlassSlider，不在页面复制手势或物理
动画。独立按钮绘制自身材质，组内按钮透明且不叠加表面，热区至少48dp。
AppGlassSurface仅绘制背景，资源未就绪使用普通表面；控件本身采用minimal档位，
保持同一新布局和交互。该降级不对应用户可切换的旧设计。

菜单保留原有弹层控制器、外部点击/滑动关闭顺序与220/180ms过渡。弹出菜单内容、
设置Sheet、选区和朗读浮层在后续批次迁移；不为本批提前复制一套业务控制器。
minimal组件验证不等于真实GPU外观或性能验收；设备profile按用户要求后置。

章节首次加载与等待分页锚点使用 GlassProgressIndicator.circular，采用库默认20dp尺寸、
2.5dp描边及应用主题强调色。LoadingIndicator通过可选indicator插槽复用居中提示布局，
其他页面默认波浪指示器不变。章节spinner通过TickerMode响应系统减少动态效果，
静止时仍显示加载提示；切章已有正文的冻结帧、错误与空态不受替换影响。

编写者：Codex + UI｜2026-10-18

## 背景材质与参数单位（2026-10-18）

UiSettings、普通设置仓储与组件材质统一使用 0–1 double 不透明度，设置界面显示
百分比，滑块直接编辑 0–1 值。普通背景与模糊底色分开保存，按全局模糊开关选用，
不叠乘两项设置，也不依次覆盖；顶栏默认 1/0.73、底栏默认 1/0.40。
新字段使用明确的新偏好键，旧字节/百分比键不读取、不迁移、不双写。
UiSettingsValues 统一读写的有限值和范围检查；模糊 sigma 限制为 0–48，
卡片圆角为 4–28 逻辑像素整数。非有限值回退对应参数默认值。

AppSurfaceMaterial 在主题层解析模式和背景，保留输入颜色 alpha，再乘以选定比例。
AppSurfaceBackdrop 仅在最终形状内执行高斯模糊；sigma 为零时不创建过滤器。
Sliver 头部使用 AppSliverSurfaceBackdrop 按可见 paintBounds 裁剪，透传原滚动几何、
命中和语义；缓存随 sigma 变化的过滤器及合成层并随卸载释放，不替换内建大标题布局。
顶栏、可折叠头部、标准底栏、悬浮底栏与阅读菜单复用同一规则；文字图标不随背景比例变淡，
菜单进出动画独立处理。显式透明源色不新增底色或模糊；普通背景设为零不关闭
已启用的模糊模式。不透明背景保留既有主题表面色调；半透明背景避免默认色调抬高 alpha。

独立按钮、动作槽和合并胶囊共用按钮材质底色，浓度独立于栏背景。
glass使用半透明实色，liquidGlass在资源就绪时采用上述光学背景，未就绪时同色回退。
颜色 ARGB 编码、漫画颜色矩阵、详情封面图像滤镜和进出动画不属于此设置单位。

编写者：Codex + UI｜2026-10-18

---

## 设置 Sheet 与表单（2026-10-14）

`AppBottomSheet.showContent` 统一弹层打开、安全区域、最大640dp宽度与调用方的关闭策略；
`AppBottomSheet.content` 提供固定标题与可滚动正文、键盘避让。
朗读管理的添加引擎类型列表及音色的引擎选择列表都使用该正文壳，避免仅调用
showContent后手写标题/列表而绕过共用行主题；长列表由壳提供滚动，标题保持固定。
`AppSettingsSheet` 组合取消/标题/保存栏，禁用状态和关闭回调由页面传入。
标题对齐由ThemeData的AppSheetTheme扩展统一配置，默认居中；AppBottomSheet与
AppSettingsSheet共用NavigationToolbar，左右操作不等宽时标题仍居中，局部可显式覆盖。
标题旁状态通过titleSuffix接入同一标题组，不另起一行。
AppBottomSheet（含show/content）和AppSettingsSheet正文默认EdgeInsets.zero，
设置行铺满正文并用ListTile.contentPadding保留文字留白；共用正文的默认行形状为
矩形，分组可自行覆盖。弹层由外层Material按Sheet形状裁剪Ink。标题、键盘避让和
安全区域仍由外壳负责，不计入正文留白。表单编辑器和阅读明细显式声明内容间距；
混合正文中的滑块、分段控件、快捷按钮单独留出16dp，设置行不再套水平Padding。快捷项使用AppSheetPresetGrid
等宽铺满当前行，窄屏或大字体减少列数，控件保留原有Material交互。
`AppSettingsForm` 统一12dp控件间距，可选分组标题、说明和错误提示；错误使用当前
主题error色和无障碍即时提示。输入控件、芯片和设置行继续使用标准Material组件。

公共组件不读取TTS、Repository或Riverpod，不执行保存/校验/试听，也不替页面决定
未保存内容的关闭策略。首批应用于云端引擎、HTTP引擎和音色编辑器，删除无引用的
朗读专用Sheet壳；既有AppBottomSheet入口继续可用，阅读器拖动面板和帮助文档
保持独立布局。组件与主题/键盘/宽屏测试共同验证布局，不用各页面重复拼接间距。

编写者：Codex UI｜2026-10-14

## 标签对齐规则（2026-10-14）

全局 TabBarTheme 不指定 tabAlignment，由组件依据 isScrollable 选择合法默认值。
固定标签只使用 fill/center；可滚动标签需要保持左对齐时在组件显式设置 start。
标签 Widget 回归使用实际 AppTheme 的浅色与深色主题，避免默认测试主题掩盖配置断言。

## 独立设计库（2026-10-11）

应用和测试使用 `package:material_ui/material_ui.dart` 与
`package:cupertino_ui/cupertino_ui.dart`，不再使用 SDK 内的 Material/Cupertino 类型。
当前直接依赖版本为 Material 1.6.0、Cupertino 1.0.2。

本次用户授权设计库迁移引起的合理外观、间距及动画变化，不要求像素级一致；
保留功能、主题、背景图与数据行为，不为复刻旧组件外观增加兼容样式。
此例外限定于本次迁移，不替代其他任务的参考版验收要求。

`flutter_markdown_plus` 尚使用旧设计库；应用入口通过官方兼容桥提供其主题和本地化，
帮助文档样式直接传递共用的 `TextStyle`、颜色及绘制类型，避免两套 `ThemeData` 相互传入。
兼容桥仅服务第三方组件，待依赖迁移后移除；第三方源码不修改。

组件语言由 `appLocaleProvider` 统一选择中文、英文或跟随系统；应用启动恢复
`app_locale`，设置变更即时通知 `MaterialApp`。`supportedLocales` 声明中文与英文，
沿用独立设计库的 Material、Cupertino、Widgets 本地化代理，并注册 ARB 应用文案代理。
跟随系统时响应系统语言变化，未支持的语言回退中文。新页面使用 `context.l10n`；
`AppStrings` 暂时兼容未迁移页面，转发同一份生成资源。文案来源与生成方法见
[多语言说明](LOCALIZATION.md)，分批覆盖及验收边界以 Active 计划为准。

编写者：Codex UI｜2026-10-11

---

## 应用主题解析入口（2026-10-13）

外观通用组在字体大小之后提供“字体设置”，使用共用Sheet选择默认字体或已导入的
TTF/OTF字体，并提供当前字体预览。界面选择由AppearanceSettings.fontFamily及
app_font_family管理，保存前完成注册；默认选择与阅读正文、标题选择相互独立。
共享字体目录与加载能力，不重复维护字体文件或缓存；冷启动重新注册已选择的字体。
字体不可用时使用默认界面字体并在设置中提示，用户可以重新导入或恢复默认。
应用明暗及局部主题共用字体装配；正文由ReaderBodyTypography隔离界面字体继承，
保持原阅读字体、标题字体、字号与行距的独立设置。系统图标不使用自定义文字字体。


`app_theme_resolver.dart` 使用只读 `AppThemePreferences` 和日夜 `ThemeColorOverrides`
计算两套主题；复用现有内置色板、参数化引擎与 `AppTheme` 组件装配。
`appThemePreferencesProvider` 按相关字段映射已有设置；`app.dart` 传入平台动态颜色
并判断本地背景图是否可用。
主题计算和组件装配不读取全局 UI 设置镜像，卡片圆角由调用方显式提供，默认 20dp；
阅读菜单局部换色继承应用已解析的卡片形状。

动态取色作为主题模式分组内配色横滑行的首项，与内置色板共用 `paletteId` 互斥选择，
不另设壁纸开关。动态模式使用完整系统明暗色板，不叠加自定义四色或参数化风格；
平台未提供的一侧回退 GR 绿色色板，纯黑模式和卡片圆角继续生效。Android12+取系统
壁纸色，桌面端取系统强调色；现有插件不支持iOS系统壁纸取色。
色卡按当前亮度显示圆形三色预览，64dp卡片、16dp圆角，选中描边2dp在前景绘制；
滚动两端16dp、上下8dp留白，避免设置分组裁剪轮廓。应用返回前台重新读取系统色板，
预览共用该结果，不单独请求插件。
普通配色保留主色映射标题栏、强调色映射全局 Tint 的既有规则；纯黑先应用于深色
色板，自定义背景再按原优先级覆盖。详细输入与后续边界见
[主题管理与 UI 架构方案](UI_THEME_ARCHITECTURE.md)。

## 通用组件的设置作用域（2026-10-13）

设置由已有 Notifier 更新和保存，主题输入只读派生。应用宿主将当前 UI 设置快照
通过 `UiSettingsScope` 提供给 Navigator、页面和全局浮层；通用顶栏、详情背景、
设置行和阅读菜单按用途订阅，不读取全局镜像。没有应用宿主的独立组件使用默认值，
预览和测试若需自定义配置，显式提供作用域快照。分组和组件布局规则不变。

跨平台设置组件按用途命名：SettingsBody、SettingsSectionHeader、
SettingsSectionFooter、SettingsGroup、SettingTile 和 SheetDragHandle。
开关、菜单与步进设置行复用 SettingTile；标题为 titleMedium，说明为
bodySmall / onSurfaceVariant，右侧值为 labelMedium 强调字阶 / primary。
值和说明在禁用时采用 disabledColor；预览与值基于行宽限制空间，不按屏幕宽度计算。
菜单选择行无箭头，页面跳转行保留箭头；把手读取当前 BottomSheetTheme。
MenuAnchor 的 OverlayPortal 继承入口主题，根浮层中的菜单也沿用局部配色。
实际 Cupertino 组件保持原接线，不将平台能力并入通用设置行。

布局、圆角、模糊、分隔线及其他界面偏好使用纯 UiSettings 快照，由共享设置
仓储读取。开关与选项保存失败提示并回退，圆角和模糊对话框等待组合参数的保存
结果；组件不直接读取存储，不改现有尺寸、配色、动画或阅读器行为。

书架、阅读记录、语言、护眼及欢迎页偏好分别由类型化仓储提供同一共享快照。
设置页不再维护已保存值的局部副本，欢迎时长仅在拖动期间保留预览；保存失败提示
并回退。护眼快捷按钮与完整设置读取同一来源，滤镜和时段规则保持。

主题自定义颜色与背景使用纯 ThemeColorsSettings，经共享配置仓储投影；颜色
槽位在数据层转换原偏好键，组件只消费实际快照。颜色选择、恢复默认、预设应用、
主题导入及背景保存失败均提示并回退，不显示虚假的成功信息。
尚未接入实际功能的设置保留行和值，使用标准组件禁用态；保留原说明并换行追加
“待实现”，原本没有说明的只显示“待实现”。功能接线后移除提示并启用对应设置，
不影响已有有效入口。

## 系统栏与页面归属（2026-10-13）

SystemBarBinder在当前帧主题更新后向共享SystemBarController提交普通页面样式，
不再等待系统栏偏好加载或参与备份恢复。阅读器只在页面可见期间接管显隐，
全局主题变化保留为最新应用样式，离开阅读器后恢复；前台恢复重新下发当前请求。
平台调用串行执行，过期排队项忽略，Android 原生前台恢复避让阅读器归属。

独立页面使用 PageRoute，模态弹层使用 PopupRoute 或标准 Dialog/BottomSheet 入口。
换源保持命名路由、返回 bookUrl 和原滑入滑出动画，使用 PopupRoute；系统栏观察器
只跟踪独立页面，也处理弹层上方再打开页面的路径，不依赖路由名称或特殊标记。
朗读界面是独立全屏页面，透明只服务胶囊转场，继续使用 PageRoute。

当前 Android target 36 的手动系统栏模式受系统限制，见
[Flutter 平台说明](https://api.flutter.dev/flutter/services/SystemChrome/setEnabledSystemUIMode.html)；
控制归属整理保持已有显示请求方式，平台能力的实际支持需单独核对。

## 详情页局部主题（2026-10-13）

封面主色经 `ColorScheme.fromSeed` 与 `AppTheme.withColorScheme` 生成完整主题，
基础主题和有效种子不变时复用目标。详情页以 `AnimatedTheme` 进行 400ms 换肤，
内容在主题内构建，背景、标签、标题栏、阅读按钮和标准弹层使用同一主题。
阅读按钮继承 FAB 主题，不额外覆写固定绿底；跟随封面关闭或取色失败时回退应用主题。

页面 Scaffold 的稳定上下文承载变量编辑、分组、移出书架确认及登录等弹层，
不使用外层 State 上下文捕获主题。单独跳转的新页面仍使用应用主题。
完整局部装配保留基础主题的平台、字阶、圆角、密度、转场与扩展；与阅读菜单共用
装配入口，不改变阅读正文背景或排版。

## 阅读菜单局部主题（2026-10-13）

正文继续使用阅读背景、文字和排版配置。页面通过 `ReaderMenuThemeHost`
统一解析并缓存菜单主题，保留随页面存活的菜单上下文；正文继承原应用主题。
`ReaderMenuTheme` 将该主题应用于顶栏、底栏、亮度控件、书源徽章和朗读返回按钮。
选区工具栏进入全局 Overlay 时捕获同一主题；书签、高亮、字典和菜单管理从
页面的菜单上下文打开，选区浮窗销毁后上下文仍然有效。编辑内容使用标准
`showDialog` 携带局部主题，输入控制器由编辑器组件随离场释放。
默认直接继承应用主题；跟随阅读背景时以正文纯色为种子生成完整 MD3 色板；
自定义时可用日夜主色生成色板，或指定 `primary`、`surfaceContainerHigh`
（菜单背景）、`surfaceContainerLow`（弹层与控件背景）。顶栏文字可单独覆盖，
默认使用 `onSurface`，普通顶栏图标使用 `onSurfaceVariant`。

菜单明暗跟随应用；默认模式保留应用纯黑配置，独立生成的菜单主题不额外套用纯黑，
与上游 `ReadBookColorTheme` 保持一致。毛玻璃使用共用材质解析入口与顶栏、底栏的模糊 sigma 和浮点底色不透明度；
普通模式使用对应背景不透明度，百分比只用于界面展示。正文分页树不进入菜单主题。

参考：[上游 ReadBookColorTheme](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/read/ReadBookColorTheme.kt)。
当前正文仅接入纯色背景，不扩展图片背景；配色复用现有 Dart 2021 色彩规范，
不新增上游 2025 规范或 Liquid Glass 实现。旧 `readBarStyleFollowPage` 配置在读取时
由独立迁移入口转换为菜单模式后移除；Rust、FFI 和数据库格式不变。

阅读设置保留“背景与配色”二级页，集中放置正文背景、菜单配色、护眼模式三个卡片。
护眼参数与应用外观设置共用，按上游 RGB 色温矩阵过滤全局画面一次；不修改保存的
颜色、不叠加到局部主题。支持手动、跟随深色、强度与定时时段；关闭时不创建滤镜
图层，定时时每分钟及回到前台重算生效状态。
参考：[上游 EyeProtection](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/ui/book/read/EyeProtection.kt)。

正文排版统一为单套持久化配置，明暗切换不重载另一套边距和排版；菜单明暗颜色仍
分别保存。“日夜共用排版”字段和分桶读写已移除；一次性迁移保留此前实际使用的
布局，再清理旧键，运行时不保留双套排版逻辑。

正文纯色配色使用同一 ReaderStyle 中的日夜背景与文字色，内置微信读书及预设1～5
来自 HapeLee/legado-with-MD3@60a7cca 的 defaultData/readConfig.json。修改保存到
当前样式的当前日夜一侧；切换模式、选择其他样式再返回均不重置配色。既有颜色
转入自定义样式，预览使用正文相同颜色解析；颜色变更不改分页几何。当前尚未接入
完整图片、墨水屏及样式管理；手动日夜覆盖仅当前阅读会话有效，背景卡片的切换
按钮根据有效模式显示太阳或月亮并更新操作提示，见
[设置分类方案](SETTINGS_ARCHITECTURE.md) 第 12 节。

编写者：Codex｜2026-10-13

## 1. 内置调色板（12 套）

数据来源：参考仓库 HapeLee/legado-with-MD3@`6dc297221a22e532354810fb2804592dd08e5a9d`
的 `res/values/colors.xml` + `values-night/colors.xml`，每套 47 个 M3 tonal role（亮/暗配对），
role 值逐字拷贝（非重推导）；由 `flutter_legado/tool/gen_md3_colors.py` 生成 `md3_colors.dart`，
锚点与对比度由 `test/unit/md3_palette_test.dart` 守护。

| id | 显示名 | seed 锚点（亮色 primary） | 特例说明 |
|----|--------|--------------------------|----------|
| `wh` | 纯白 | `#5C5C5C` | **默认调色板**（paletteId 未设置时） |
| `gr` | 森绿 | `#4C662B` | |
| `lemon` | 柠檬 | — | |
| `koharu` | 小春 | `#8F4A4D` | 亮 surface `#FFF8F7` / 暗 surface `#1A1111` |
| `yuuka` | 优香 | — | |
| `phoebe` | 菲比 | — | |
| `sora` | 穹 | `#3B608F` | 暗 surface 深蓝调 `#111318` |
| `august` | 八月 | — | |
| `carlotta` | 卡洛塔 | — | |
| `mujika` | 姆吉卡 | — | |
| `elink` | 墨水 | `#000000` | 墨水屏灰阶：暗面 surface 允许纯黑（登记例外） |
| `transparent` | 透明 | `#000000` | 表面全透明，配合背景图使用（对比度矩阵豁免） |

- 持久化：`SharedPreferences` 键 `app_palette_id`（本地存储，非 Rust FFI，免 API_CONTRACT）。
- 未知 `paletteId` 由 `Md3Palettes.byId` 回退 `wh`（回滚路径）。

### 1.1 默认调色板 WH 关键 role（亮/暗）

| Token | 亮色 | 暗色 | 用途 |
|-------|------|------|------|
| `primary` | `#5C5C5C` | 见 `md3_colors.dart` | 主色 / Tint（按钮、链接、选中态） |
| `onPrimary` | `#FFFFFF` | — | 主色上的前景 |
| `primaryContainer` | `#747474` | — | 主色容器（FAB、图标容器） |
| `surface` | `#F8F8F8` | `#141313`（着色深灰，非纯黑） | 页面背景 / Scaffold |
| `onSurface` | `#1C1B1B` | — | 主要文字 |
| `onSurfaceVariant` | `#444748` | — | 次要文字、列表图标 |
| `outlineVariant` | `#C4C7C7` | — | 分隔线、弱边框 |

> 其余 11 套及全部 47 role 的权威值一律以 `md3_colors.dart` 为准（本档不重复罗列，避免双源漂移）。

### 1.2 Tonal Surface 层次映射（组件 → role）

| 组件 | Role |
|------|------|
| Scaffold / AppBar 背景 | `surface` |
| 分组卡片（Card / SettingsGroup） | 亮 `surfaceContainerLowest` / 暗 `surfaceContainerLow` |
| 底部导航栏 | `surfaceContainer` |
| 操作菜单 / 表单下拉菜单 | `surfaceContainerLow` |
| BottomSheet | `surfaceContainerLow` |
| Dialog | `surfaceContainerHigh` |
| 普通表单输入框填充 | `surfaceContainerLow` |
| 指示器（NavigationBar pill） | `secondaryContainer` |

### 1.3 用户自定义主题并存模型（themeConfigList 功能完整保留）

- **优先级**：自定义已应用的 4 色（主色调/强调色/背景色/底部操作栏，日/夜各一套）> 内置 palette 对应 role。
- 映射：`colorAccent`→`primary`+`secondary`+`surfaceTint`、`colorPrimary`→AppBar 背景（未设时回退 `colorBackground`）、`colorBackground`→`surface`/Scaffold、`colorBottomBackground`→底部导航栏背景；AppBar 前景按背景明暗动态计算（`_onColor`）。
- 背景/壁纸：`_ThemeBackgroundLayer` + `bgImage/bgImageN` prefs，与 12 套主题正交保留。
- 底栏皮肤（bottom_bar_skin）：完整保留，与主题正交。

---

### 1.4 默认深色主题的容器层次（2026-10-11）

默认调色板的页面底色为 `#101418`；`AppTheme.palette` 装配时将最低容器、
普通容器、高容器、最高容器与亮表面分别统一为 `#0B0F12`、`#24282C`、
`#2B2F34`、`#34383D`、`#393D42`，低容器保留 `#1D2024`。
这些为本轮用户授权的配色调整，覆盖默认深色主题历史遗留的亮灰色层次；
参考资源生成的原始调色板数据仍作为来源记录。浅色及其他调色板不变。
浅色与深色模式下普通 tonal 顶栏图标按钮均使用透明常态底色，保留圆形按压反馈；
独立按钮、顶栏动作槽与合并动作布局共用该规则。

顶栏图标按钮外层点击区域统一为 48dp，内层保留 plain 40dp、其他档位 36dp
的视觉尺寸和既有图标大小。文字操作保留自身宽度，不套用图标槽限制。
普通选择项使用 DropdownMenu，表单选择项使用 DropdownMenuFormField，沿用
全局输入主题；不可编辑的选择使用 selectOnly，保留空值、回填及保存语义。
订阅源与单章换源复用 AppSearchField，书源规则输入保留独立标签与代码入口。
普通 AlertDialog 使用 dialogTheme 的形状，二维码白底保留扫码用途。

操作菜单统一经 `app_menu.dart` 使用标准 `MenuAnchor`、`MenuItemButton` 与
`CheckboxMenuButton`，共用入口只管理选项、回调及系统返回时关闭菜单，
不自行绘制弹层。书架、顶栏更多、文字触发和书源行长按使用同一接线；
表单保留 `DropdownMenu` / `DropdownMenuFormField`，不改为操作菜单。
两类菜单共用 16dp 圆角、`surfaceContainerLow` 底色及 4dp 阴影；
操作菜单行最低高度 48dp、横向边距 16dp，文字采用 bodyMedium。
分隔线使用标准 Divider，两侧各留 16dp。以上数值为项目统一配置。

数量徽标使用标准 `Badge.count(maxCount: 99)`，共用 `BadgeThemeData` 的
error/onError 颜色、18dp 高度及 11sp 文字，不再手动绘制书架数字容器。
共用 BadgeWidget 只保留角标位置、显隐和自定义底色能力。

编写者：Codex UI｜2026-10-11

纯黑深色模式在 `AppTheme.palette` 统一应用，默认主题、各内置色板和参数化配色
均通过同一入口处理：页面与最低容器为 `#000000`，低容器与普通容器为 `#0A0A0A`，
高容器为 `#121212`。仅深色模式生效；关闭时使用当前主题原有颜色。
自定义颜色继续按原优先级覆盖，背景图片保留原规则。
阅读正文默认深色与夜间预设同步纯黑开关：软件深色且开启纯黑时为 `#000000`，
关闭为 `#1A1A1A`，自动文字为 `#CCCCCC`。浅色预设和自定义背景、文字保留用户选择。
阅读菜单章节信息下方不重复放置快捷按钮，底部顺序统一为目录、全文搜索、
自动翻页、朗读、设置。右上更多菜单不重复放置界面设置与查看目录入口。
阅读进度条左右外边距为 4dp，让透明底色的上一章/下一章按钮更靠近两侧；保留完整点击区域，首末章及加载期间禁用对应操作。
滑条使用 4dp 圆角轨道、14dp 圆形手柄与按压反馈，不显示密集刻度；
移除滑条上方页码与目录百分比，不显示拖动数值气泡；章节和章内页码的原有寻址语义保留。
书源列表通过开关表示启停状态，不重复显示“开启/关闭”文字；批量勾选保留原有行为。

主页面标题统一使用 headlineMedium 并设置为 28sp，左对齐且与操作按钮同排；
发现和订阅保留当前分组的次级副标题，搜索收起后不保留额外高度。
书架含加载与错误状态使用同一字号，按钮与其他主页面共用全局顶栏样式，
不再单独固定 plain；透明常态底色及 48dp 点击区域沿用共用组件规则。

首页在今日阅读目标下方直接展示阅读热力图卡片，沿用首页卡片底色与圆角，
不使用折叠控件、折叠箭头及其分割线。
热力图只显示每日阅读时长，显示时读取现有日统计数据，不提供按本数切换；
加载期间显示进度指示，失败说明原因。阅读记录页不重复放置热力图。

首页与阅读总览共用的阅读时长榜保留24dp卡片外圆角，卡片显式裁剪点击水波纹。
标题单独保留16dp内边距，榜单行铺满卡片宽度且无独立圆角；行内容左8dp、右16dp、
垂直6dp留白放在点击区域内部，行号占位24dp，不缩小整行点击反馈范围。

编写者：Codex + UI｜2026-10-20

### 1.5 搜索输入（2026-10-11）

替换净化、书源管理、字典查询、文件管理、阅读记录与书签使用 `AppSearchField`，高度 48dp、胶囊形状、
零阴影和无描边；底色为 `surfaceContainerLow`，文字用 `onSurface`，
提示和搜索图标用 `onSurfaceVariant`。输入非空时提供清除入口。
常规页面通过 `AppSearchRow` 装配在标题栏下方，左右边距 16dp；字典查询按钮同排。
目录章节行的全宽背景及点击反馈使用直角，避免无左右留白的高亮仍带圆角；
字数标签等行内独立控件保留自身圆角。
目录页开启搜索时在标题栏内使用同一 AppSearchField，保留自动聚焦与三页签共用筛选；
清除取消待执行的防抖并立即恢复列表，关闭搜索恢复原标题，不增加搜索行。
目录的搜索框仍位于标题栏内，使用淡入淡出且不改变顶栏高度。
发现、订阅、离线缓存、书源管理、订阅源管理、替换规则、文件管理、阅读记录与书签的
列表搜索默认隐藏，通过搜索按钮展开；展开时高度和透明度同步变化，正文连续移动，
收起后不保留空白。顶栏搜索由 `AppScaffold` 和 `DynamicSearchAppBar` 共用动画进度，
阅读记录和换源使用相同的 `AppSearchTransition` / `AppSearchReveal`。
展开 220ms、收起 180ms，支持过渡中反向；收起立即释放输入焦点并关闭搜索区域的命中及语义。
控制器与筛选策略由页面保留：阅读记录、目录和离线缓存关闭搜索时仍清除筛选，其他管理页保留查询；
书签使用键盘搜索提交，清除时恢复全部书签。字典查询及独立全局搜索作为主要输入保持常驻。
组件只统一呈现，实时筛选和提交查询仍由页面回调负责。

编写者：Codex UI｜2026-10-14

### 1.6 设置导航与列表（2026-10-11）

我的页按内容与规则、外观、同步与服务、定时任务、其他五组排列。
五个分组标题通过 SettingsGroup 的可选 title 放入卡片顶部，使用 titleSmall/
onSurfaceVariant，无图标、不可点击、不参与行间分隔线。
标题独立留白，设置行保留原有边距；卡片之间留 16dp，不额外给整卡内容加统一内边距。
内容与规则包含书源、订阅源、TXT 目录规则、替换净化、字典查询、字典规则和高亮标注；
定时任务管理及运行开关独立成组。同步与服务包含 Web/MCP 服务、备份与恢复和缓存管理。
外观组只包含外观与阅读界面，高级移至其他组，保留隐私、书签、阅读记录、文件管理、关于和退出。
主题模式仅在外观页配置，不再提供我的页快捷项。
不保留独立设置主页，首页齿轮切换至我的页并定位其他分组。
子设置页通过 `AppScaffold` / `LegadoAppBar` 将返回与标题同排，
列表复用 `IosGroupedBody` / `SettingsGroup` / `IosListTile` 的底色、字体、圆角和点击反馈。
分组组件位于 `settings_widgets.dart`。`SettingsGroup` 默认分隔线避开相邻行的图标列：
有图标时左侧留 56dp，无图标时留 16dp，右侧统一留 16dp；`separatorIndent` 可覆盖左侧缩进。
我的页直接使用该默认规则。

编写者：Codex UI｜2026-10-11

“我的”二级设置页（外观、高级、备份与恢复、关于）沿用卡片内标题，顶部与组间留
16dp，不添加整卡统一内边距。设置与弹层的布尔选项复用 SettingSwitchRow；弹层已有
内容边距时允许行内零边距。二级页使用 LegadoAppBar，TXT 目录规则不再单独使用大标题。
文件管理、书签和阅读记录的搜索显隐与过渡遵循 §1.5，目录返回保持原行为。
管理列表主标题使用 titleMedium，副文本使用 bodySmall/onSurfaceVariant，操作图标保持
透明背景。规则与书签卡片使用 16dp 圆角和 surfaceContainer，点击反馈服从外层圆角裁剪；
规则高亮与选中状态保留语义色。普通列表由行内容负责水平留白，避免列表和行双重缩进；
带勾选框的行保留控件所需边距。书源及订阅源现有分割线右侧同样留 16dp。

免责声明和更新日志复用 HelpScreen 的 Markdown 内容与共用 Sheet 入口；
标题、列表、链接、主题及关闭图标沿用帮助文档查看器。

### 1.6.1 隐私设置（2026-10-14）

隐私页沿用返回与标题同排、卡片内分组标题：解锁凭据、验证时机、权限与数据。
总开关默认关闭，没有隐私密码时禁用；修改/清除须验证旧密码，密码不回填。
生物识别按硬件能力显示不可用原因，只有认证和存储均成功才开启；改密撤销快捷凭据。
有效期为每次、本次应用会话、离开前台前；仅最后一种显示宽限时间。
Android显示通知/后台设置入口，iOS仅通知；Firebase后置。锁定内容不创建原文、封面及原来的语义/长按菜单；
紧凑格子仅显示锁图标，保留“私密书籍”语义。分组锁定只替换内容区，顶部导航可操作。
朗读胶囊和封面转场锁定后立即移除，不以渐隐代替隐私遮蔽。

编写者：Codex UI｜2026-10-14

### 1.7 阅读设置（2026-10-11）

阅读快捷抽屉直接展示设置项，不单独显示“阅读设置”标题及其留白；
完整阅读设置页沿用返回与标题同排的顶栏。

用户批准将完整阅读设置与阅读快捷面板分开。完整设置按字体与排版、背景与配色、
翻页与操作、标题与信息、页面与屏幕、内容与工具栏六组进入独立页面，返回与标题同排。
复杂的页面边距使用子页面，字体选择沿用既有字体管理；不叠加“更多”弹层。
阅读中只展示字号、背景、翻页动画与亮度，并提供“全部阅读设置”入口。
两种入口共享控件和设置源，每项在完整设置内只有一个归属；关闭父选项隐藏相关子项，
原值保留。页眉页脚与顶部状态条分别标注，日夜共用排版沿用现有布局存储。

字体与排版按正文字体、间距与缩进、中文排版三个分组排列；字号并入字体，
字间距、行距、段间距采用名称与当前值在上、整行滑条在下的统一布局。
行距保留字号倍数语义，段间距保留逻辑像素语义，不合并配置值；字重按细体、常规、粗体排列，选项文字分别使用 300、400、700 字重预览。
阅读设置选项名称统一使用与 SettingSwitchRow 相同的 titleMedium，说明与当前值保留次级层次；
简繁转换使用标题在上、全宽分段按钮在下的两行布局。
完整阅读设置、快捷面板及相关配置区块共用 SettingsGroup，不再保留阅读专用卡片容器。
设置分组不统一添加整圈内边距，也不在分组内容外保留旧整组 Padding；标题、列表行和滑条
按内容分别留白，文字水平起点为 16dp；滑条和分段按钮
可作为 Column 等自由布局传入，避免在控件内部自动添加分割线。
亮度卡片直接显示跟随系统亮度开关，不另加亮度控制标题；关闭后显示手动滑条。
阅读设置开关统一复用 SettingSwitchRow，含亮度、页眉页脚、页面边距、屏幕及工具栏设置。
无图标时不预留图标列，主标题使用 titleMedium，说明使用 bodySmall；整行可点击切换，
保留合并语义与禁用行为。设置行默认继承 ListTileTheme 的左右 16dp 边距，
不重复指定同值 contentPadding；仅对话框等特殊对齐场景显式覆盖。
翻页动画由 ListTile 自身响应点击，分组容器不负责整卡点击。
日夜共用排版放在阅读设置总入口的独立分组。章节标题隐藏时收起字体、字号增量及上下边距，
原值保留；标题字号按正文基础上的增量显示，不展示为绝对字号。

亮度开关统一称为“跟随系统亮度”，Android/iOS 均恢复应用亮度覆盖，
不修改设备的系统自动亮度开关；关闭后使用手动滑条。设置页与阅读底栏复用同一控件，
同步实际应用亮度，调节失败显示提示。退出正文或漫画阅读时恢复系统亮度。

编写者：Codex UI｜2026-10-11

## 2. 字体层级（M3 type scale，跟随系统字体）

不指定 fontFamily——运行时自动取系统字体。字阶对齐 Material 3 官方 type scale：

| 层级 | 字号 | 字重 | 行高 | 字间距 | 用途 |
|------|------|------|------|--------|------|
| displayLarge | 57 | w400 | 64/57 | -0.25 | 超大数字/展示 |
| displayMedium | 45 | w400 | 52/45 | 0 | |
| displaySmall | 36 | w400 | 44/36 | 0 | |
| headlineLarge | 32 | w400 | 40/32 | 0 | |
| headlineMedium | 28 | w400 | 36/28 | 0 | 页面大标题 |
| headlineSmall | 24 | w400 | 32/24 | 0 | 区块标题 |
| titleLarge | 22 | w400 | 28/22 | 0 | AppBar 标题 |
| titleMedium | 16 | w500 | 24/16 | 0.15 | 列表主文字 |
| titleSmall | 14 | w500 | 20/14 | 0.1 | 小标题 / Tab |
| bodyLarge | 16 | w400 | 24/16 | 0.5 | 正文 |
| bodyMedium | 14 | w400 | 20/14 | 0.25 | 辅助正文 |
| bodySmall | 12 | w400 | 16/12 | 0.4 | 小字说明 |
| labelLarge | 14 | w500 | 20/14 | 0.1 | 按钮文字 |
| labelMedium | 12 | w500 | 16/12 | 0.5 | 分组标题 / 标签 |
| labelSmall | 11 | w500 | 16/11 | 0.5 | 极小标签 |

**行高规范**：行高以分数形式写入 TextStyle（`height`），随字号等比缩放。

---

## 3. 间距 Token

| Token | 值 | 用途 |
|-------|-----|------|
| `spacing.xs` | 4 | 图标与文字间距、紧凑内边距 |
| `spacing.sm` | 8 | 列表项内部小间距 |
| `spacing.md` | 12 | 输入框内边距、卡片内元素间距 |
| `spacing.lg` | 16 | 列表项水平内边距、区块间距 |
| `spacing.xl` | 24 | 按钮水平内边距、区块之间大间距 |
| `spacing.xxl` | 32 | 页面级分隔 |

---

## 4. 圆角 Token（Expressive 大圆角）

Flutter 无 Expressive shape scale preset，经 component theme 显式落地（`app_theme.dart`）：

| Token | 值 | 用途 |
|-------|-----|------|
| `radius.card` | 20 | 卡片 / 分组容器（cardTheme） |
| `radius.control` | 12 | 输入框、SnackBar、ListTile 形状 |
| `radius.extraLarge` | 28 | Dialog / BottomSheet（M3 extraLarge） |
| `radius.menu` | 16 | PopupMenu / DropdownMenu |
| `radius.fab` | 16 | FloatingActionButton |
| StadiumBorder | 全圆角 | Elevated/Filled/Outlined 按钮（Expressive） |

---

## 5. 组件主题约定

### 5.1 AppBar
- 背景：`surface`（自定义主题时为 colorPrimary/colorBackground 回退）
- 前景：`onSurface`（自定义时按背景明暗动态计算）
- elevation 0，滚动抬升 `scrolledUnderElevation 3`（M3 tonal surfaceTint）
- 标题左对齐（centerTitle: false）

### 5.2 NavigationBar（底部导航，M3 pill 指示器）
- 背景：`surfaceContainer`（自定义时 colorBottomBackground）
- 指示器：`secondaryContainer` pill
- 选中图标：`onSecondaryContainer`；未选中：`onSurfaceVariant`
- 高度 80，label 常显；激活底栏皮肤时渲染用户图（bottom_bar_skin）

### 5.3 Card / 分组容器（SettingsGroup）
- 背景：亮 `surfaceContainerLowest` / 暗 `surfaceContainerLow`
- 圆角 20，elevation 0，无边框
- 分隔线：`outlineVariant` 1px（带缩进）

### 5.4 ElevatedButton / FilledButton / OutlinedButton / TextButton

四类按钮使用当前 ColorScheme 与 TextTheme 的 M3 默认样式，不在全局重复指定
颜色、形状、尺寸、状态描边或阴影。页面局部明确设置的错误色、紧凑布局和
功能选项形状继续优先生效。

- ElevatedButton：`surfaceContainerLow` 底、`primary` 前景，普通态 elevation 1。
- FilledButton：`primary` 底、`onPrimary` 前景；tonal 变体使用对应容器颜色。
- OutlinedButton：`primary` 前景，默认状态描边；禁用态按组件规则减弱。
- TextButton：默认文字按钮颜色和状态反馈，尺寸及内边距由组件解析。

导出对话框的确认操作使用 FilledButton，取消使用 TextButton，通过组件类型
区分操作重点，沿用当前主题颜色。

### 5.4.1 Chip（标签与筛选）

标准 Chip、ChoiceChip、FilterChip、ActionChip 和 InputChip 使用 material_ui 的
M3 默认样式，颜色、描边、形状与内边距不在全局统一覆写。标签文字根据当前
ColorScheme/TextTheme 和选中状态解析，应用明暗主题与阅读器局部主题沿用同一规则。
普通单选与筛选的选中容器使用 secondaryContainer，前景使用 onSecondaryContainer。
日志级别的语义颜色、紧凑工具栏及专用自绘分类控件保留各自用途，不套用普通标签规则。

### 5.5 InputDecoration（输入框）
- 普通设置、表单与对话框输入统一使用 `surfaceContainerLow` 填充，四角圆角 12dp。
- 普通态：`outlineVariant` 1dp 描边；聚焦态：`primary` 2dp 描边。
- 错误态：`error` 1dp 描边，聚焦错误态 2dp；禁用态使用减弱的边线。
- 水平内边距 16dp、垂直 12dp；多行和密码输入沿用自身的行数与行为。
- 搜索输入沿用 §1.5 的胶囊样式，代码编辑器及已有自绘输入保留专用样式。
- 本次用户授权统一外观，替代历史 B3 的小圆角下划线输入形态。

### 5.6 ListTile
- 水平内边距：16；图标色：`onSurfaceVariant`（IosListTile 默认容器 `primaryContainer` + `onPrimaryContainer` 图标，可覆写）

### 5.7 Divider（分割线）
- `outlineVariant`，厚度 1，间距 1

### 5.8 FloatingActionButton
- 背景：`primaryContainer`；前景：`onPrimaryContainer`；elevation 3，圆角 16

### 5.9 Dialog
- 背景：`surfaceContainerHigh`，圆角 28

### 5.10 BottomSheet
- 背景：`surfaceContainerLow`，顶部圆角 28；拖拽把手 = IosGrabber（32×4，`onSurfaceVariant`）

帮助文档、更新日志与免责声明统一通过 showHelpDocument 打开标准模态 Sheet，
继承入口主题和全局 Sheet 形状、底色、把手及默认动画。竖屏正文容器采用安全区域
及把手后约 90% 的可用高度，横屏采用全部可用高度；宽屏沿用 M3 默认 640dp 宽度
上限并居中。标题栏固定，保留目录、源码与关闭图标按钮，正文独立滚动，底部避让
系统区域；文档内容不再嵌套 Dialog。

### 5.11 TabBar
- 选中/指示器：`primary`；未选中：`onSurfaceVariant`；indicatorSize label

### 5.12 Switch / Checkbox / Radio / Slider / Progress

Slider 与 RangeSlider 的新版 M3 默认外观由 AppTheme 的 sliderTheme 统一启用，
局部主题通过同一装配入口继承。当前 material_ui 1.6 需要 year2023=false；
仅在该配置行说明并忽略弃用标记，控件不重复声明版本开关。
专用进度控件可保留已有轨道与滑块形状，局部 SliderTheme 从当前主题 copyWith，
避免新建完整主题而丢失全局默认设置。

Slider、Switch、Checkbox、Radio 和 IconButton 不在全局覆盖配色与交互状态，
由组件根据当前 ColorScheme 解析选中、禁用、按压、悬停与焦点状态。
Slider 保留新版外观开关，按用户授权使用 noOverlay 取消圆形按压状态层，
其他默认状态反馈仍由组件解析；Checkbox 保留现有形状。
- 跟随 M3 默认主题（不再覆写为 iOS 绿等自定义色）

### 5.13 PopupMenu / DropdownMenu
- 背景：`surfaceContainer`，圆角 16，elevation 3

### 5.14 SnackBar
- 背景：`inverseSurface`；文字：`onInverseSurface`；浮动式，圆角 12

### 5.15 Tooltip
- 背景：`inverseSurface`；文字：`onInverseSurface`，圆角 4

---

## 6. 图标使用规范

| 场景 | 颜色 Token | 说明 |
|------|-----------|------|
| 列表前导图标 | `colorScheme.onSurfaceVariant` | 通过 ListTileTheme 统一 |
| IosListTile 图标容器 | `primaryContainer` 底 + `onPrimaryContainer` 图标 | 可经 iconBackground/iconColor 覆写 |
| 操作图标（AppBar） | `AppBar.foregroundColor` | 跟随 AppBar 主题 |
| 功能入口图标 | `colorScheme.primary` | 强调可交互 |
| 空状态占位图标 | `colorScheme.onSurfaceVariant` | 低对比、不抢眼 |
| 状态指示图标 | 语义色（green/orange/error） | 需适配亮暗（暗色用 shade300） |
| 媒体覆盖层图标 | `#FFFFFF` | 仅在深色覆盖层上使用 |

**图标字体**：Batch 1 起引入 Material Symbols（默认内置/功能图标与底栏 SVG），无法映射为单 glyph 的插画用 MD3 矢量等价物（`过期文档/UI_MD3_PLAN.md` 第三节，已归档）。

**禁止**：
- 禁止使用 `Colors.black` 作为通用图标色（暗色下不可见）
- 禁止使用 `Colors.grey` 硬编码（应使用 `onSurfaceVariant`）

> 历史兼容：`AppColors.ios*Light/Dark` 系统色常量（红/橙/黄/绿/…）保留供高亮预设、设置页图标底色等
> 功能色引用，各屏按批次迁移至 M3 token 后逐步退役。

---

## 7. 暗色模式规范

### 7.1 核心原则

1. **所有颜色必须来自 Theme Token**：通过 `Theme.of(context).colorScheme.*` 获取
2. **禁止硬编码颜色**：不允许在 widget 中直接写 `Colors.white`/`Colors.black`/`Color(0xFF...)` 作为通用 UI 颜色
3. **着色暗面（tonal，非纯黑）**：12 套调色板暗面 surface 均为带主题色调的深灰（如 wh `#141313`、sora `#111318`、koharu `#1A1111`）；唯 elink（墨水屏）按参考仓库为纯黑（登记例外）

### 7.2 对比度标准（WCAG AA）

| 类型 | 最低对比度 |
|------|-----------|
| 普通文本（< 18sp） | ≥ 4.5:1 |
| 大号文本（≥ 18sp 或 14sp 加粗） | ≥ 3:1 |
| 图标/图形元素 | ≥ 3:1 |

**自动化守护**：`test/unit/md3_palette_test.dart` 对 11 套不透明调色板 × 亮/暗全矩阵断言
onSurface/onSurfaceVariant/onPrimary/onXxxContainer×容器/surfaceContainer 系 ≥ 4.5；
登记例外：elink `onSecondaryContainer/secondaryContainer` = 3.95（参考仓库原始值，按 AA-large 3.0 守护）。

### 7.3 暗色模式检查清单

- [ ] 文本颜色使用 `onSurface` / `onSurfaceVariant`
- [ ] 图标颜色使用 `onSurfaceVariant` / `primary`
- [ ] 背景色使用 Tonal Surface 层次（1.2 节映射表）
- [ ] 分割线使用 `outline` / `outlineVariant`
- [ ] 状态色（成功/警告/错误）在暗色背景下对比度达标
- [ ] 无 `Colors.grey` / `Colors.black` / `Colors.white` 硬编码用于通用 UI

### 7.4 例外场景（允许硬编码）

| 场景 | 说明 |
|------|------|
| 阅读器/漫画阅读器 | 沉浸式全屏，自管理背景色（`reader_config_panel` 可跟随 colorScheme） |
| 视频播放覆盖层 | 半透明黑色遮罩 + 白色控件 |
| 滑动操作按钮 | 彩色背景 + 白色前景 |
| 主题配置预览 | 展示固定色板供用户选择（12 内置 + 自定义） |

---

## 8. 使用方式

```dart
// app.dart 装配：按 paletteId + themeMode（ThemeNotifier 驱动全局实时切换）
final palette = Md3Palettes.byId(themeState.paletteId);
MaterialApp(
  theme: AppTheme.palette(brightness: Brightness.light, palette: palette),
  darkTheme: AppTheme.palette(brightness: Brightness.dark, palette: palette),
  themeMode: themeState.themeMode, // 亮/暗/跟随系统
)

// 自定义主题 4 色叠加（themeConfigList 保留功能）
AppTheme.palette(
  brightness: Brightness.light,
  palette: palette,
  primary: c(themeColors.primary),          // AppBar 背景
  accent: c(themeColors.accent),            // primary/secondary/surfaceTint
  background: c(themeColors.background),    // surface/Scaffold
  bottomBackground: c(themeColors.bottomBackground), // 底部导航栏
)

// 在 Widget 中获取颜色
final colorScheme = Theme.of(context).colorScheme;
Text('标题', style: TextStyle(color: colorScheme.onSurface))
Icon(Icons.menu, color: colorScheme.onSurfaceVariant)
```

---

编写者：Qoder ｜ 2026-08-28（MD3 Batch 0：本档重写为 MD3 token 单一事实源，随 `md3_colors.dart`/`app_theme.dart` 落地同步）


设置中的单选弹出菜单行统一使用 `SettingMenuRow<T>`，内部复用 `AppMenuAnchor`
与设置行基础布局。整行打开菜单，当前选项在菜单中标记；行尾只显示当前值，
不添加箭头，长值可换行。选项和当前值可附带图标预览，配置保存由页面负责。
页面跳转行继续使用右箭头，开关、滑块和数值输入保留各自控件。
数值步进设置使用 `SettingStepperRow`，共用名称、减号、当前值与加号布局；
单位、步长和上下限由调用方提供，联动与保存留在页面。阅读设置卡片不绘制
自动行间分隔线，仅在边距或标题间距调节区域上下保留分隔线。
阅读设置的页眉与页脚按同一结构展示显示模式、提示内容、边距和分隔线；
阅读状态条独立归入屏幕与工具栏，避免与系统状态栏和页眉页脚混淆。

普通页面使用 material_ui 的平台默认转场与时长，不再覆盖 Android 动画或按路由分档；
换源底部弹层和阅读菜单 overlay 使用各自的专用动画。恢复默认的用户授权日期为 2026-10-12。

编写者：Codex｜2026-10-12

正文选区菜单使用阅读器专用 `ReaderSelectionToolbar`：12dp 圆角、surfaceBright、
紧凑模式 6dp 阴影，多行模式 12dp 阴影。图标置于标签上方，动作之间不绘制分隔线，
只有主要动作与固定折叠入口之间保留分隔线。主要动作横向滚动；多行模式换行，
超过高度后纵向滚动。菜单优先放在选区下方，给手柄留白，空间不足时移到上方，
左右避让 16dp 与安全区。原生选区、拖动手柄和原文映射保持现有实现。
菜单管理负责主要／折叠／隐藏分组、排序、图标和多行偏好，保存后统一应用。
此专用菜单由用户在 2026-10-12 授权参考上游实现，普通输入框继续使用标准选区菜单。

编写者：Codex｜2026-10-12

## 自定义动效与系统偏好（2026-10-18）

AppMotion读取系统减少动态效果；自定义搜索展开、菜单、选区与折叠内容即时落到目标。
标准Material组件保留自身行为。骨架扫光只在页面TickerMode启用、应用前台且系统允许
动画时运行；朗读既有后台停止策略继续保留。普通整行计数和空态统一AppAnimatedTextLine，
退场文字排除读屏语义，多行提示可指定maxLines。曲线对象归State创建并释放，不在动画帧内
重复创建。封面Hero与详情主题/背景、朗读转场保持；悬浮底栏双层缩放明确后置至iOS液态玻璃阶段。

编写者：Codex + UI｜2026-10-18

主导航的点击切换使用280ms可中断滑动，用户拖动可接管；默认页恢复及页签集合变化仍即时同步。
书架动作组切换和行尾标记使用180ms轻量过渡，退场内容立即排除点击、焦点与语义。
搜索场景只淡入当前内容，不为退场动画同时挂载共享控制器的旧页面；结果增量和续页不改变场景身份。

编写者：Codex + UI｜2026-10-18

漫画图片淡入只针对实际首帧就绪的新图片，不包裹加载/错误占位；内存/磁盘缓存和同步帧直接显示。
原300ms淡入开关继续有效，系统减少动态效果即时结束；不叠加外层与图片组件两套淡入。
主导航保活子页按当前逻辑页签控制TickerMode。系统动效偏好途中改变时，导航/菜单到达目标，
选区退场仍须真正移除Overlay，不能留下透明命中层。

编写者：Codex + UI｜2026-10-18
