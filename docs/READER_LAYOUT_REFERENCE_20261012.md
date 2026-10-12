# 阅读排版参考与职责映射

本轮按用户指定规则实现 Dart 文本排版与行内段评。状态只登记于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)，本文保存来源与设计依据。

## 固定参考

2026-10-12 读取 HapeLee/legado-with-MD3 的 `main` 提交 `070ca1a9b2e491654f70c105bca9939968023940`：

| 上游源码 | 参考职责 | Dart 落点 |
|---|---|---|
| [ReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderTextShaper.kt) / [AndroidReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/platform/AndroidReaderTextShaper.kt) | 平台测量产出字形簇、宽度和字体度量，分页不依赖 Android Paint | Flutter TextPainter 与 TextLayoutEnvironment |
| [ChineseLineBreaker.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ChineseLineBreaker.kt) | 簇边界与 UTF-16 偏移分别保存，断点考虑中文禁则和拉丁词界 | chinese_line_breaker.dart 移植推进与回退，TextBreakRules 统一合法断点 |
| [ReaderPaginator.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderPaginator.kt) | 已测量行内项带尺寸/章节位置；会话逐行落位、形成页面并输出 | chapter_layout.dart、LinePaginator、分批排版会话 |
| [ReaderChapterBlockMeasurer.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderChapterBlockMeasurer.kt) | 测量与分页可交错推进，测量缓存和取消由会话管理 | 行级测量复用与可取消章节布局 |

## 本项目采用的规则

1. 保留 Flutter 塑形、原生选区与翻页，不采用上游 Canvas 绘制。
2. 中文断行核心用 Dart 移植上游推进、携带与回退逻辑；平台文字测量仍使用 Flutter。分页参考其逐行落位契约，不引入图片、HTML/CSS 和角色胶囊范围。
3. 最终行宽、高、基线、缩进、字距及段评几何只由布局决定，绘制消费结果。
4. 原文偏移使用 UTF-16；缩进和段评占视觉空间但不改变原文长度。段评由用户确认的段末回退、固定槽宽和显隐规则控制。
5. 上游允许部分标点超宽，本轮按 Flutter 最终整行塑形核对，不裁字、不越界，不新增字形压缩。已有段首引号悬挂只让出引号自身宽度，不再抵消整段缩进。
6. 按用户最新裁决删除历史分页与页码迁移。只恢复带坐标版本和章节标识的原文锚点；无有效锚点的旧记录从保存章节开头打开。数据库/云端负载未改结构，应用无原文坐标的云端记录时只恢复章节。当前布局的页号仍用于进度条和翻页。

## 上游断行实证

使用既有本地 Kotlin 编译器编译上述固定提交的原始 `ChineseLineBreaker.kt`，输入 23 组固定字形簇及宽度，导出簇断点、UTF-16 断点与行宽，保存为 `flutter_legado/test/fixtures/reader/md3_line_breaks.json`。Dart 对照测试逐项比较三种输出，覆盖独立首行容量、中文连续标点、拉丁单词、emoji、组合字符和 ZWJ 序列。

这是纯断行算法的相同输入对照，不代表 Android 与 Flutter 的字体塑形一致。本地直引号沿用统一禁则；上游允许的超宽行进入 Flutter 整行校验后可继续回退。分页、原生选区和段评分别由项目定向回归验证，不宣称整套 Android 排版引擎已经逐字复刻。

## 引号缩进与旧路径清理

旧实现把全部缩进宽度作为 `hangingWidth`，渲染时再整体左移，抵消了首行缩进。修复后缩进、引号悬挂和正文起点分别保存为几何数据，不插入虚拟空格。24 组实际 RenderParagraph 坐标回归覆盖四种中英文引号、三档缩进与两档文字缩放；旧实现有 18 组失败，修复后全部通过。

已删除 `zh_layout.dart`、历史整段分页及页号转换、虚拟前缀映射，以及没有生产调用方的仅返回末页接口和备用渲染器。显式回到章首和云端章节跳转会清除旧锚点，避免重新开书后恢复陈旧位置。

## 同文本布局诊断

基线取 `12d60d994` 的隔离引擎，新实现运行 `test/performance/reader_layout_benchmark_test.dart`。两者使用相同 6635 UTF-16 文本、120 段、320×580 内容区、首页 530、字号 18、行高 1.6、段距 8、缩进 36；先预热，再连续记录三轮。

| 实现 | 首个完整页面计算耗时（ms） | 整章计算耗时（ms） | 测量次数 | 页数 |
|---|---|---|---:|---:|
| 原实现 | 159.910 / 131.308 / 125.409 | 159.910 / 131.308 / 125.409 | 2400 | 30 |
| 缓存与分批会话实现（888f0f450） | 6.280 / 5.891 / 5.221 | 143.843 / 132.431 / 116.104 | 1591 | 27 |
| MD3 断行核心与独立缩进 | 5.971 / 4.862 / 5.176 | 135.227 / 127.530 / 111.334 | 1442 | 27 |

原实现完成整章后才提供页面，新会话在整章完成前可以输出完整页。页数变化来自连续逐行分页；测量次数减少约 33.7%。整章耗时区间重叠，不能据此证明整体更快。

取消虚拟缩进的重复测量后，最新实现比原实现少约 39.9% 测量；上述调试耗时仍不足以证明发布环境的收益。

上述是 `flutter test` 调试模式中的同步计算诊断，不包含界面帧调度和真实显示时间，不替代 profile 或设备性能采样。分批在段落边界让出执行权，单次平台文字测量和超长段落仍不可中断；深处锚点前的布局也必须先完成。

## 仍存在的实现差异与 Rust 边界

2026-10-12 重新读取上游 `main`，仍为以上固定提交，四个参考核心文件内容未变。当前对应的是中文断行的主要推进规则、两类坐标、首行独立容量及逐行分页职责；23 组同输入对照不构成所有输入等价证明。

| 项目 | 当前差异及处理 |
|---|---|
| 平台塑形 | 上游 TextPaint 提供簇宽和字体度量；本项目 TextPainter 测量真实 Flutter 行，并把最终环境交给正文和选区。字体回退、字距和缩放的结果不保证逐像素一致。 |
| 断点规则 | 本地禁则额外包含直引号等符号，拉丁词判定使用明确 Unicode 范围；上游按 Unicode 字符类别判断。窄标点回退条件、极窄首簇保护和 Float/整数容量也有适配差异，需继续扩大同输入对照覆盖。 |
| 右边界策略 | 上游在部分禁则场景允许标点超宽；本项目继续整行塑形回退，优先满足不裁字、不越界。 |
| 分页与行内模型 | 已实现普通段落逐行填页、独立行高、段评尾部回退；尚未复制上游全部 ReaderMeasuredBlock/ReaderElement 类型。段评是专门的尾部布局，通用行内图片、HTML、角色胶囊和页底对齐未纳入本轮。 |
| 分层与调度 | LinePaginator 和 ChineseLineBreaker 已独立；Flutter 测量、对齐和段评仍集中于 ParagraphLayoutEngine，没有独立 TextShaper 接口。分批仅能在段落之间让出线程，超长段落和深处锚点前的测量仍可能阻塞。 |
| 位置与同步 | 本地恢复使用版本化 UTF-16 锚点；无锚点记录只恢复章节。尚未扩展数据库与跨设备云同步协议，不宣称云端已同步原文锚点。 |

当前没有必须迁入 Rust 的排版模块。可作为后续候选的是使用已测量宽度的断行、已测量行的分页、索引与原文映射等纯数据计算；它们也可用 Dart isolate，是否值得迁移应由 profile 分项耗时决定。Flutter 的文字测量、Widget 和原生选区留在 UI 侧，不能把依赖 `dart:ui` 的整套引擎塞入普通 isolate，见 [Flutter 并发限制](https://docs.flutter.dev/perf/isolates)。若采用 Rust，需要一次批量传入段落/章节及测量数据、保持 UTF-16 契约并单独验证 FFI 成本。

`rust/legado-core/src/layout.rs` 的 LayoutEngine 仍按字号估算每行字数，并使用 Rust 字符串字节长度积累偏移；它由 Rust reader_state 消费，却不是 Flutter 正文的排版权威。不能直接接入替代真实 Flutter 字体测量，本轮未修改 Rust 或 FFI。

编写者：Codex｜2026-10-12
