# 阅读排版参考与职责映射

任务状态只登记于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。本文记录固定上游、实际模块边界及验证方法；应用版本保持 2.0.372+373。

## 固定上游

本轮参考 HapeLee/legado-with-MD3 的固定提交 `070ca1a9b2e491654f70c105bca9939968023940`，不跟随 main 浮动。纯计算实现从原始 Kotlin 移植，保留 GPL-3.0 来源信息。

| 上游源码 | 当前落点与职责 |
|---|---|
| [ChineseLineBreaker.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ChineseLineBreaker.kt) | `rust/legado-layout/src/line_breaker.rs`：簇索引、UTF-16 断点、中文禁则、标点悬挂与拉丁词界 |
| [ReaderPaginator.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderPaginator.kt) | `rust/legado-layout/src/paginator.rs`：逐行落位、段距、标题、分栏、页底对齐、通用内容块与会话输出 |
| [ReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderTextShaper.kt) / [AndroidReaderTextShaper.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/platform/AndroidReaderTextShaper.kt) | `flutter_text_shaper.dart`：Flutter TextPainter 产出簇宽、字体度量与样式，不再决定断行或分页 |
| [ReaderChapterBlockMeasurer.kt](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderChapterBlockMeasurer.kt) | 内容与测量职责分别落于 `chapter_document.dart`、FlutterTextShaper；`chapter_pagination_session.dart` 分批推进与取消 |

## 单一排版权威与模块边界

```text
章节原文 / 原文映射
    → FlutterTextShaper：平台字体测量
    → ReaderLayoutSession：异步批量协议
    → legado-layout：中文断行、行内位置、逐行分页
    → ChapterLayoutAdapter：最终几何与原文范围
    → 正文渲染、原生选区、阅读锚点
```

`legado-layout` 不依赖 Flutter、FRB、数据库、网络或字体运行时。`legado-ffi/layout_bridge` 只管理隔离会话、输入限额和取消；四个入口的冻结契约见 [纯计算契约](READER_LAYOUT_CONTRACT_20261012.md) 与 `API_CONTRACT.md §1.3.1`。

字形簇索引用于断行，UTF-16 偏移用于原文定位，两者显式分开。几何计算按上游 Float 使用 f32，并保留整数视口与整数除法顺序。Flutter 不再执行独立禁则修正、行尾回退或字距计算；每行的最终字形坐标同时服务绘制、选区和命中测试。

通用内容块包括正文、行内段落、图片、空行、分隔线及显式分页；行内项包括文字、图片、角色标记、背景音乐标记及本项目段评。样式、链接、背景、基线和章节位置保存在模型中。当前小说适配器产生正文与段评输入；保留其他类型的计算能力不意味着本轮新增对应阅读功能或完整 EPUB/CSS 解析。

高频字形采用结构字段与共享样式，FFI 将最终几何、原文位置、合并文字和低频附加字段分别传递；页面按编号引用共享缓冲，不添加格式标识或历史解析路径。紧凑存储只属于传输层，不改变上游核心的元素模型或几何。

## 原始 Kotlin 对照

`scripts/reader_layout_reference.py` 下载固定提交的原始 Kotlin，使用 Java 17 / Kotlin 2.3.0 编译执行。`Oracle.kt` 只适配输入与输出，不替换断行或分页算法；Compose Stable 注解使用无行为桩，测量模块仅取原始数据声明。

已提交的 `rust/legado-layout/tests/fixtures/md3.json.gz` 保存上游 revision、源码 SHA-256、Java runtime 与 260 组期望结果，其中 180 组断行、80 组分页。覆盖中文连续标点、拉丁词界、emoji/组合字符、首行容量、不同样式/基线、标题、分栏、图片、行内图片、角色/音乐标记、空行、分隔线、分页及页底对齐。

测试逐项比较簇边界、UTF-16 断点、页面身份、原文、元素类型与全部字段。几何误差仅允许 `max(0.0001, abs(expected) × 2 × f32::EPSILON)`，用于 Float 十进制输出舍入；不以截图、页数相同或自身 Rust 输出作为等价证据。另验证分批输出、取消、非法输入、段评扩展及压缩传输往返。

重新生成夹具需要已有的 Kotlin/Gradle 编译器缓存：

```powershell
python scripts/reader_layout_reference.py --java-home '<本机 Java 17 目录>' --proxy http://127.0.0.1:7897
```

运行纯核心检查：

```powershell
cd rust
cargo test -p legado-layout --all-targets
cargo clippy -p legado-layout --all-targets -- -D warnings
cd ..
python scripts/dev.py build ffi windows --profile debug
cd flutter_legado
flutter test test/unit/reader_layout_service_test.dart test/widget/reader_native_selection_test.dart
```

上例的原生库构建命令适用于Windows；Linux/macOS使用
`cargo build --locked --manifest-path rust/Cargo.toml -p legado-ffi --features quickjs`。
共享其他Cargo输出目录时，以 `LEGADO_TEST_FFI_LIBRARY` 指定实际原生库的绝对路径。

纯Rust算法测试直接验证固定上游样本；组件样式、菜单等局部行为使用固定布局输入。
需要文字测量、重排、选区几何配合的Flutter测试复用正式FRB传输，不加载应用数据库，
不再逐次启动外部程序或重算历史内容。80组上游页面、取消和容量归还集中在
`test/ffi/reader_layout_runtime_test.dart`，该文件支持本机Windows/Linux/macOS原生库。
Flutter CI在同一作业内准备本机FFI库再测试，不构建APK、IPA或桌面应用；首次整库编译
成本高于旧小型宿主，不能仅凭测试执行变快就认定CI总耗时下降。

原生测试的worker初始化、Widget异步等待和句柄清理见
[双轨规范§7.2](TWO_TRACK_DEV_SPEC.md#72-集成验证步骤)。测试专用进程/文件JSON链路不用于
应用性能评估；真实性能仍按下述Profile基准测量。

## 本轮数据所有权与缓存

Rust已输出页面从会话移出，保留上游要求的一页延迟与绝对页编号；Flutter按只读视图消费共享
数值缓冲，行文字与选择几何不再持有逐字副本。完整布局缓存同时限制三章与16 MiB估算预算，
超大章节仍可阅读但不进入完整缓存；相邻章按距离串行预排。预算只约束缓存数据估算，不是RSS。
性能数据和未验证范围见 [Profile结果](READER_LAYOUT_PROFILE_20261012.md)，状态只维护于Active。

## 明确保留的差异

- 平台测量：Flutter TextPainter 与 Android TextPaint 的字体回退、塑形、缩放和度量可以不同；相同测量输入的断行与分页对照必须通过。
- 项目扩展：段评零原文长度、末尾合法正文同行、固定槽宽与紧凑图标；保留已授权的段首引号悬挂及现有关闭中文排版设置。默认中文路径仍使用上游算法，不用本地溢出修正改写结果。
- 宿主 UI：Flutter 保留原生选区、独立章节标题、翻页动画与阅读设置；首页标题占位通过已测量内容块输入，不重写分页规则。
- 阅读位置：使用章节标识与版本化 UTF-16 锚点；没有有效锚点的历史/云端记录只恢复章节，数据库与云同步格式保持原有边界。

这些差异分别验证，不宣称不同平台的同一本书必然逐像素、逐页相同。Unicode 词界分类依据固定 Java 17 对照表，不以 Dart 的另一套字符分类替代。

## 删除与性能口径

已删除旧 `legado-core/src/layout.rs` 的按字号估字数算法，以及 Dart 重复的 ChineseLineBreaker、TextBreakRules、LinePaginator 和未分页回退渲染。Rust reader_state 只接收已排版的 UTF-16 页面范围，换章/关闭时清空旧范围；不再自行推测页数或使用 UTF-8 字节偏移。

原六步的调试诊断与迁移前采样属于历史基线，不代表当前 Rust 实现的性能。实施前后以独立 Profile 包、同一设备/窗口/文本/字体配置比较，并记录编码、调用、Rust 计算、解码及真实帧；方法与结果见 [Profile 基准](READER_LAYOUT_PROFILE_20261012.md)。不预设 Rust 必然更快，单次超长段的平台测量仍不可中断，深处锚点仍需先排前文。

编写者：Codex｜2026-10-12
