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

编写者：Codex｜2026-10-12
