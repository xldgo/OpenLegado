# 路由迁移方案

代码基线：主目录 `feature/ui-reader-selection`，A～F 整理提交 `fd544317d`～`e3b412895`，订阅导航补验 `1c2fe833f`。
本文件记录迁移方案与设计约束；执行状态和验证只见 [活动计划](REFACTORING_ACTIVE_PLAN.md)。
具体输入与结果见 [57项路由清单](ROUTE_INPUTS_20261019.md)。

## 结论与选型

建议使用 Flutter 团队维护的 go_router，保留当前 Riverpod、material_ui、Glass 组件和自定义 Route。
不改写正文、排版或播放控制，不将主页 PageView 改成多个独立 Navigator。
官方推荐 go_router，但也保留直接 Navigator 的使用场景；采用它的收益是统一路由输入、
参数验证与外部导航，而非提升排版性能或自动解决应用生命周期问题。

2026-10-19 核验 pub.dev 官方 API：最新稳定版 18.1.0，要求 Dart ^3.12.0、Flutter >=3.44.0，
依赖 material_ui ^1.0.0、cupertino_ui ^1.0.0；发行归档 pages/material.dart 已导入 material_ui。
与本项目 Flutter 3.47.7 / Dart 3.13.5、material_ui 1.6.0 的声明范围相容。
这只是静态依赖范围核验，实施时仍需正常 pub get 和 lockfile 差异审核，不代表已验证运行兼容。
第一轮不同时增加 go_router_builder 或升级现有依赖，手写少量明确参数类型即可。

## 现状与迁移难点

源码盘点：route_names.dart 有57个名称；lib/src 中有120处 pushNamed、2处 pushReplacementNamed，
分别涉及49、2个文件；另外有大量直接 Navigator.push、弹窗、Sheet 和结果返回。
计数为排除整行注释后的静态检索，不等同于120条独立用户流程。

| 位置 | 当前职责 | 迁移要求 |
|---|---|---|
| app.dart / AppRouter | MaterialApp、路由表、特殊Route与5个Observer | router实例随App存活；主题重建不重建导航栈；保留全局Key及观察器 |
| route_names / route_arguments | 57个路径；多数Book/String/Map参数，视频有独立类型 | 区分目标标识、可重建参数和瞬时动效参数；按目标验证 |
| BookOpenUtils / 书架 / 详情 | 准备书籍、ReaderNotifier装载、开读后刷新 | 复用刚提取的BookDetailService；结果返回后仅刷新原书 |
| BookReaderRoute | 封面展开、固定全屏正文、图片租约和减少动画 | 用自定义Page.createRoute复用原Route，不以普通淡入替换 |
| ReadAloudPlayerRoute | 胶囊展开与交互关闭、封面资源 | 独立Page适配；保留会话门禁和资源释放 |
| ChangeSourceSheetRoute | 非不透明、底部滑入、返回新bookUrl | 自定义Page返回原PopupRoute，保留String结果 |
| ReaderScreen / ReaderExitController | PopScope、保存进度、临时书入架确认 | 返回仍只进入既有退出控制器，不另加重复确认/保存 |
| PrivacyAppGate / BookGate等 | 启动验证、书籍/分组授权、回锁 | 保留组件级门禁及动效快照门禁，不仅依赖一次redirect |
| DeepLinkService / PlatformBridge | legado/yuedu导入、浏览器/视频等平台动作 | 事件先解析成动作；导入是操作而非普通页面URL |
| MediaPlaybackNavigation | 等欢迎页结束、会话校验、复用已有播放页 | 保留等待和去重；不简单go到播放器并清空返回栈 |
| HomeScreen | PageView滑动、延迟建页、显隐、双击底栏动作 | 原样保留，不默认使用StatefulShellRoute.indexedStack替换 |

## 参数与导航语义

1. 书籍、章节等可重建身份使用稳定键和明确参数；Book只作为可选首屏快照。
   书籍URL需要用Uri queryParameters编码，不能直接拼到路径中；日志不输出私密参数/凭据。
   搜索参数定义query/sourceUrls/groups，视频沿用VideoScreenArgs，目录和换源约定返回类型。
2. BookCoverOrigin、ReadAloudCapsuleAnchor包含闭包、几何或图像引用，只能是本次导航的瞬时extra。
   不序列化它们；冷启动/来源不在场时采用现有淡入退路，不假造封面起点。
3. `/reader`目前依赖全局ReaderNotifier，单靠URL不能恢复指定书。
   深链入口需要一次性的ReaderEntry装载协调：解析身份、走现有隐私授权、校验当前会话，
   必要时调用既有openBook，再呈现正文。不能在pageBuilder每次重建时再次openBook。
   当前UI门禁不等于所有入口都尚未加载数据，必须独立验证装载发生的时机。
4. 普通详情/阅读/目录/编辑使用push并等待pop结果。go只用于明确的启动完成/根目的地重置；
   它会按目的地重建栈，不能批量替换现有push，否则书架返回刷新、目录结果和退出路径会变化。
5. Page key由入口key与完整URI共同确定：主题重建保持实例，同路径更换查询参数创建新实例，
   避免沿用旧初始化输入；保留RouteSettings.name与arguments语义，
   原Observer仍比较`/welcome`、`/audio`等名字，不能让Page名称悄悄变成另一套标识。
6. 首轮保持现有扁平路径，`/sources/edit`的前缀不自动意味着源列表必须作为父页面留在栈中。
   未知路径回到首页；通过末尾正常匹配的兜底GoRoute承载，保留原路径名称及继续导航能力，
   不把正常兜底放在无法继续压栈的错误匹配状态，不默认暴露英文Page Not Found。
   缺参回退和readingStats别名等逐项列入R1，不顺便改变错误页面或新增导航功能。
7. 局部确认框、设置Sheet、导入确认页可继续用Navigator.push/pop。
   直接压入的页面不会自动成为可深链地址，父路由被go替换时也会移除，应按操作会话收尾。
   不为迁移而把每个对话框都注册成GoRoute。

## 自定义Route与门禁

GoRoute.pageBuilder提供自定义Page，Page.createRoute返回现有BookReaderRoute、
ReadAloudPlayerRoute或换源PopupRoute，**settings传Page自身**，使Navigator的Page/Route归属成立。
封面起点由该Page的arguments提供，书籍身份同时编码入URI；不能再临时创建
另一个RouteSettings取代Page。Route完成和销毁语义保持，先用独立测试应用证明再接正式入口。

胶囊展开仍直接push同一个ReadAloudPlayerRoute并等待其completed，保留路由动画与图片交接监听。
通知等无锚点入口通过AppRoutePage创建该Route，不为统一表面API额外制造动画移交协议。
这类局部Navigator导航是go_router支持的用法，不存在第二份命名路由或旧框架回退。

普通页使用material_ui.MaterialPageRoute，由AppRoutePage创建；发行源码已支持该设计包，仍需验证Hero、主题、本地化和iOS转场。
保留appRouteObserver、systemBarRouteObserver、TopRouteWatcher、ReadAloudCapsuleObserver、
MediaPlaybackNavigation在同一根Navigator。Router由State初始化并在dispose释放，不放build内创建。
AppGlassHost、兼容主题桥、验证码/WebView监听、系统栏和朗读胶囊宿主继续包裹router child。

组件级隐私门禁保留；redirect/onEnter只用于可重入、无弹窗副作用的启动/目标判定。
异步授权对话框和正文装载不放在redirect内。回锁后不能继续画封面快照，返回不能重复确认。
当前阅读器canPop=false，不承诺迁移顺带启用iOS边缘返回；这属于独立交互决策。

## 外部入口

- 继续让既有Android通道和iOS app_links接收legado/yuedu导入动作，通过应用导航协调器等待启动完成。
  不让Router和插件同时处理同一URI。Android已显式关闭flutter_deeplinking_enabled；
  实施时补核iOS的FlutterDeepLinkingEnabled策略，插件持有的scheme应明确单一接收方。
- 通知点击仍核验MediaPlaybackTarget会话；已有目标页则回到它，否则push；不重新创建播放会话。
- 视频悬浮窗回全屏沿用VideoScreenArgs、播放状态和临时MPD归属，不能只保留bookUrl。
- 网页式可寻址URL是后续能力；本轮不新增公开Universal Links域名或改变用户授权的导入行为。

## 实施批次与门槛

| 批次 | 交付 | 必须验证 |
|---|---|---|
| R1 参数准备 | 列出57个目标的输入/结果/外部入口；将重载Map参数收敛为明确类型，保留当前导航 | 缺参、错类型、Book快照缺失、结果类型及现有路由行为 |
| R2 旁路原型 | 引入锁定的go_router，在测试应用验证Material UI、3种自定义Page和退出/门禁 | 封面往返、图片释放、非不透明换源、PopScope、主题更新不丢栈、observer顺序 |
| R3 原子切换 | MaterialApp.router + 完整GoRoute表 + 所有命名导航消费者 + 根Key/Observer/平台入口 | 冷/热启动、主页保活、返回刷新、外部通知/导入与视频回全屏；全静态分析和定向回归 |
| R4 清理 | 删除旧generateRoute、旧参数读取分支与迁移辅助入口，整理文档 | 没有遗留pushNamed依赖；局部Navigator仍正常；重复导航及迟到操作不会串页 |

R3不能只迁几个页面便启用新根：go_router管理的Navigator不提供原onGenerateRoute，
残留Navigator.pushNamed会失败。按功能组准备改动，最终在同一可回滚切换提交同步启用。
不长期并行维护两套路由表，也不新增产品内的“新旧路由”开关。
若R2原型不满足现有封面/退出协议，先修Page适配，不能靠删除动效或绕过保存门禁推进。

## 验收与回滚

定向行为至少覆盖：启动后仅一个主页、未读直开/长按详情、连点只开一次、阅读进度返回刷新、
目录/换源/二维码/编辑结果、私密书验证取消与回锁、通知重复点击、深链冷启动和导入取消、
视频悬浮窗恢复、主页滑动和各Tab位置保持、主题/文字缩放变化，以及封面减少动画。

复用现有app/routing/app_router_test、book_reader_route_test、书架与朗读导航回归，
新增Router栈/外部入口行为测试；不使用源码字符串断言作为测试。
设备视觉、iOS返回与外部唤醒由用户设备确认，本地widget测试不能代替实机结论。
每批本地提交；切换失败整体回退R3，再恢复原路由入口，既有业务/数据库保持不变。

## 官方依据

- [Flutter架构建议](https://docs.flutter.dev/app-architecture/recommendations)：推荐go_router，也承认直接Navigator场景。
- [导航概览](https://docs.flutter.dev/ui/navigation)：命名路由限制与Router适用范围。
- [go_router发行与版本](https://pub.dev/packages/go_router)：18.1.0；本文核验官方版本API及实际发行归档，不依赖main的版本号。
- [导航与结果返回](https://pub.dev/documentation/go_router/latest/topics/Navigation-topic.html)：go/push、结果、extra和直接Navigator的边界。
- [自定义转场](https://pub.dev/documentation/go_router/latest/topics/Transition%20animations-topic.html)、
  [Page.createRoute](https://api.flutter.dev/flutter/widgets/Page/createRoute.html)：自定义Page/Route接线。
- [深链配置](https://docs.flutter.dev/ui/navigation/deep-linking)：使用第三方插件时避免默认处理器重复处理。

编写者：Codex + UI｜2026-10-19
