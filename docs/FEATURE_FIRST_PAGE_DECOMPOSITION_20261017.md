# 页面解构与 Feature-first 目录规范化

## 决策与基线

以 `feature/ui-reader-selection` / `afe49a7ff` 为基线，用户于 2026-10-17 确认实施。
本方案沿用 Flutter 表现层、Riverpod、现有 Repository 和 Rust 排版核心；结构调整服务于
职责清晰与行为可验证，不以清空目录、文件行数或新增抽象数量作为完成标准。
当前状态与验证结果只登记在 [活动计划](REFACTORING_ACTIVE_PLAN.md)。

选择混合组织方式：页面及专属应用状态按 Feature 收拢，共享领域契约、数据服务、平台能力
和应用依赖组装保持独立。拒绝纯路径搬迁、重复 Controller/State 和所有模块套用空分层。
不改 FFI、Repository 契约、数据库、存储格式、依赖、版本号及用户可见交互。

## 批次顺序与边界

| 批次 | 范围 | 实施顺序 | 验收重点 |
|---|---|---|---|
| B1 文本阅读器 | `features/reader/` | 会话编排 → 页面与已有浮层 → 路径迁移 | 唯一状态、章节加载、进度、选区与翻页回归 |
| B2 书籍详情 | `features/book_detail/` | 复用现有 Notifier/Service，拆 builders 和弹窗 | 真实 Widget 输入与事件边界、阅读/书架操作不变 |
| B3 目录 | `features/toc/` | 过滤排序 → 缓存观察 → 列表及菜单 | 章节索引正确、订阅启停、书签与下载状态同源 |
| B4 漫画阅读器 | `features/reader_comic/` | 图片项/缓存预加载 → 条漫/分页视图 → 页面编排 | 逆向索引、位置恢复、重试和模式切换 |
| B5 长尾归拢 | 设置、RSS、规则、多媒体等 | 逐业务域移动页面与专属状态 | 旧路径引用清零、路由与交互保持 |

每批先拆职责，再单独整理路径，便于审查与回滚；不把两个重型模块混在一个实施批次。
已有页面内部组件、阅读器选区、翻页控制与布局适配优先复用。原路径引用同步更新，只有
确有跨批次消费者时才短暂保留导出壳，迁移结束删除；不增加历史数据兼容层。

## B1a：阅读会话编排

新增 `features/reader/application/reader_session_controller.dart`：

- 负责开书、目录及正文加载、章节导航、刷新、换源后重载、原文锚点、进度保存和阅读计时。
- 构造注入阅读、书架、阅读记录仓储、记录偏好、正文服务和原文位置存储，不持有 Ref。
- 依赖由 Notifier 首次会话操作时装配，同一 Provider 周期共用；释放或重建时销毁旧实例。
- 通过明确宿主端口读写既有 ReaderState，不缓存第二份当前书籍、正文、目录或页码。
- 迁移现有开书/加载代际与重入守卫，销毁后停止状态回写。
- ReaderNotifier 保留公开入口、设置与颜色投影、工具栏状态、跨章分页器和全局页信息。
- 只通过分页重置端口通知宿主清理旧书布局，不将分页算法移入会话控制器。
- B1a提取时ReaderState暂留原路径；B1b再统一迁入application并更新消费者和生成物关联。

阅读器视图、选择区域和翻页动画不在 B1a 改动范围。布局衍生状态、选区矩形及动画控制器
仍由表现层持有；后续不新建与现有状态并行的 ReaderUiState。

## B1b：页面、浮层与专属状态归拢

- 将阅读页迁入 `features/reader/presentation/`，现有阅读菜单、快捷/完整设置及其直属
  弹层迁入 `presentation/overlays/`；保留原组件与交互，不复制第二套实现。
- 提取 ReaderControlsOverlay，组合阅读菜单、经典朗读条及恢复跟随/从当前页朗读操作。
  阅读页传入当前状态与事件回调，原文位置计算仍使用现有页面与会话入口。
- ReaderNotifier、ReaderState及其Freezed生成物、阅读设置注入迁入同一Feature的
  `application/`；已有B1a实现原样保留，只调整依赖路径。
- 同步更新路由、共享注入、Widget和测试引用，删除原路径，不保留重定向薄壳。
- 本步不移动正文排版、选区和翻页实现；共享主题、朗读条、平台与数据能力保持既有归属。
- 验收既有菜单命中与关闭顺序、设置入口、朗读控制、开书与章节导航；完整静态分析及
  对应行为测试通过后回填Active，不把目录归拢当作整个阅读页业务拆分完成。

## 后续模块约束

### B1c：章节附加任务与书源恢复

- ReaderChapterCoordinator接管加载完成观察、前后各两章预取及段评摘要规则选择和请求。
  摘要只有一份不可变快照，绑定书籍/书源/章节，页面只消费数量与点击参数。
- ReaderSourceRecoveryController接管自动换源开关读取、三次重试限制、首个非同源候选选择、
  切源及重开编排，并提供登录书源查找；页面负责现有登录弹层与提示文案展示。
- 两者注入既有Repository/Service，通过状态读取、重开和通知回调接入；不持有Ref或Context。
  页面释放后拒绝迟到结果；不新增缓存、搜索算法、存储或FFI接口。
- 相关单元测试直接调用组件，覆盖预取窗口、规则开关、过期摘要、重入/重试与失败提示；
  复验实际阅读页的自动换源、预取、段评及既有菜单/翻页用例。

### B1d：退出阅读边界

- ReaderExitController接管书架权威判定、返回入架偏好读取、临时书清理、确认后入架和
  退出前进度保存；确认框、提示和Navigator仍通过页面回调执行。
- 沿用既有已入架直接退出、未入架关闭提示后清理退出、确认入架/取消清理规则和重入保护。
  不新增存储或退出策略；设置读取失败保留在阅读页并提示重试。
- 复验独立决策/调用顺序及现有真实退出确认框Widget测试，生命周期保存路径仍使用
  ReaderNotifier.saveProgress，不把阅读页按目标行数强行拆成转发层。

- 书籍详情复用 BookDetailNotifier/BookDetailService；将共享私有状态的 part 代码提取为
  有明确输入与回调的 Widget，不再增加平行 BookDetailController。
- 目录组合现有书签与下载能力，不复制它们的事实状态；轮询及订阅随路由生命周期启停。
- 详情表现组件明确为封面信息、操作按钮、阅读状态、简介、背景与变量对话框；
  页面继续持有UI生命周期及动作/导航组装，加载和刷新复用现有Notifier/Service。
- 目录过滤器只持有查询、防抖和显示顺序；缓存观察器只有一份只读快照，注入仓储、
  下载服务、音频事件和当前书籍读取端口，不注入Ref/Context，不产生新的下载任务表。
  路由被覆盖时停止轮询与订阅，返回恢复；章节项和菜单以明确输入/回调渲染。
- 漫画保留 LocalBookService/Rust 的 CBZ 读取边界；预加载服务只管理既有加载任务和缓存
  窗口，不持有页面滚动/动画控制器，不借重构新增缓存策略。
- Provider 按能力所有权迁移：Feature 独有状态归 Feature，共享内容、网络、缓存和注入
  保持共享归属；不机械要求 providers 只剩语言与主题。

## B4：漫画图片与预载边界

- ComicImageItem消费明确的书籍/书源、表现设置、仓储及平台能力，管理单图加载生命周期；
  失败、重试和长按通过回调交回页面。CBZ读取继续使用LocalBookService，解码与磁盘缓存
  继续使用BookImageRepository，不增加FFI或原生实现。
- ComicPreloadService只管理章节范围去重与预载代际，接收每次调度的书籍/书源和URL；
  不缓存第二份页面进度，不持有Ref、Context、滚动或动画控制器。直连预载由页面注入。
- 解码缓存原本还供文本图片正文使用，因此放入共享data/services，保持原键和策略。
- ComicWebtoonView承载条漫列表/缩放/间隔/留白；MangaPagedView承载原分页与逆向映射。
  页面管理两者控制器、恢复、自动阅读、平台生命周期与导航，不按目标行数强行另建状态。
- 页面、专属弹层及字节解析分别收拢至Feature的presentation/application；共享仓储、
  设置模型和平台能力保持原归属，旧入口引用同步迁移。

## B5：长尾页面与状态归属

本批复用已经形成的页面/Notifier/Repository职责，只收拢目录和修正引用；
不借路径迁移改写业务、路由名称、Provider声明或生成模型。

| 业务域 | 页面与专属状态归属 |
|---|---|
| 首页与书架 | home/presentation与application；书架偏好注入归bookshelf/application |
| 设置与引导 | settings/presentation；欢迎页面归onboarding/presentation |
| RSS | rss/presentation、application，阅读历史归application/history |
| 规则 | rules/presentation；替换、TXT目录、高亮与订阅状态归application下对应子目录 |
| 词典 | dictionary/presentation与application，词典规则编辑仍归rules |
| 书源与详情 | 登录、调试、换源页面/状态归book_sources；元信息编辑和换封面归book_detail |
| 发现 | explore/presentation与application，保留原part和生成物关系 |
| 媒体 | 音频播放页面/状态归audio，朗读页面归read_aloud，视频归video |
| 外观 | 底栏皮肤页面/状态归appearance；字体管理页面归reader |
| 缓存与自动任务 | cache/presentation；automation/presentation与application |
| 导入与文件 | imports承载本地/压缩包/关联导入及状态；remote_books承载远程书库；files承载文件管理 |
| 日志与工具 | logs/presentation与application；browser承载浏览器，tools承载扫码、代码编辑及cURL工具 |

页面及其独有状态不再从screens/和对应旧Provider目录消费，不保留导出壳。
根providers/仍保留共享仓储/服务装配、配置投影、主题/系统栏、同步与应用生命周期；
例如explore_dependencies仍是共享书源查询/调试能力的装配导出，不随页面Notifier搬迁。
生成文件按原始字节迁移，库的part/import/export指令只更新目标路径。

## 验证与回滚

每批执行完整静态分析和相关行为测试。B1a 直接测试无 Riverpod 宿主的控制器，并复验既有
ReaderNotifier、刷新、换源、原文位置与阅读记录测试。断言真实状态、返回值和仓储调用。
后续表现层提取覆盖浮层命中及关闭顺序、连续翻页、选区操作；漫画覆盖模式切换与位置恢复。
设备与 CI 未执行时明确记为未验证，不用单元测试代替真实交互验收。

本轮由 Codex 直接实现和自查，不使用子代理；没有独立审查时如实标记。用户本轮已授权逐批验证后本地提交一次，前三批后继续授权B4、B5；未经另行授权
不推送或触发 CI。每批可独立撤销自身修改，不涉及数据迁移或其他模块回滚。

编写者：Codex｜2026-10-17
