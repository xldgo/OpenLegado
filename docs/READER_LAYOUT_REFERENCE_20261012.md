# 阅读排版参考与职责映射

本轮按用户指定规则实现 Dart 文本排版与行内段评。状态只登记于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)，本文保存来源与设计依据。

## 固定参考

2026-10-12 读取 HapeLee/legado-with-MD3 的 `main` 提交 `070ca1a9b2e491654f70c105bca9939968023940`：

| 上游源码 | 参考职责 | Dart 落点 |
|---|---|---|
| [ReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderTextShaper.kt) / [AndroidReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/platform/AndroidReaderTextShaper.kt) | 平台测量产出字形簇、宽度和字体度量，分页不依赖 Android Paint | Flutter TextPainter 与 TextLayoutEnvironment |
| [ChineseLineBreaker.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ChineseLineBreaker.kt) | 簇边界与 UTF-16 偏移分别保存，断点考虑中文禁则和拉丁词界 | TextClusterMap、中文断行与合法断点 |
| [ReaderPaginator.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderPaginator.kt) | 已测量行内项带尺寸/章节位置；会话逐行落位、形成页面并输出 | chapter_layout.dart、LinePaginator、分批排版会话 |
| [ReaderChapterBlockMeasurer.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderChapterBlockMeasurer.kt) | 测量与分页可交错推进，测量缓存和取消由会话管理 | 行级测量复用与可取消章节布局 |

## 本项目采用的规则

1. 保留 Flutter 塑形、原生选区与翻页，不采用上游 Canvas 绘制。
2. 只借鉴职责与数据契约；不整份翻译 Android 实现，不引入图片、HTML/CSS 和角色胶囊范围。
3. 最终行宽、高、基线、缩进、字距及段评几何只由布局决定，绘制消费结果。
4. 原文偏移使用 UTF-16；缩进和段评占视觉空间但不改变原文长度。段评由用户确认的段末回退、固定槽宽和显隐规则控制。
5. 上游允许部分标点超宽，本轮按照用户要求优先不裁字、不越界，不新增标点压缩或光学悬挂。
6. 原文锚点记录带坐标版本与章节标识；保留旧数据库/云端格式兼容。历史页码先用旧分页语义转换，不能直接当作字符偏移。

## 同文本布局诊断

基线取 `12d60d994` 的隔离引擎，新实现运行 `test/performance/reader_layout_benchmark_test.dart`。两者使用相同 6635 UTF-16 文本、120 段、320×580 内容区、首页 530、字号 18、行高 1.6、段距 8、缩进 36；先预热，再连续记录三轮。

| 实现 | 首个完整页面计算耗时（ms） | 整章计算耗时（ms） | 测量次数 | 页数 |
|---|---|---|---:|---:|
| 原实现 | 159.910 / 131.308 / 125.409 | 159.910 / 131.308 / 125.409 | 2400 | 30 |
| 缓存与分批会话实现 | 6.280 / 5.891 / 5.221 | 143.843 / 132.431 / 116.104 | 1591 | 27 |

原实现完成整章后才提供页面，新会话在整章完成前可以输出完整页。页数变化来自连续逐行分页；测量次数减少约 33.7%。整章耗时区间重叠，不能据此证明整体更快。

上述是 `flutter test` 调试模式中的同步计算诊断，不包含界面帧调度和真实显示时间，不替代 profile 或设备性能采样。分批在段落边界让出执行权，单次平台文字测量和超长段落仍不可中断；深处锚点前的布局也必须先完成。

编写者：Codex｜2026-10-12
