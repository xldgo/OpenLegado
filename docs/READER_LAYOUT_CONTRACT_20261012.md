# 阅读布局纯计算契约

本契约由 `API_CONTRACT.md §1.3.1` 引用。用户已授权纯计算迁入 Rust；不增加新的阅读产品功能。

## 输入、输出与坐标

运行时入口为 `readerLayoutBegin(LayoutConfigDto) -> LayoutSession`；句柄的
`push(Vec<LayoutBlockDto>)` 和 `finish()` 返回 `LayoutReplyDto`，`cancel()` 同步取消。
不再传递 sessionId、schemaVersion 包装或 JSON 字符串；Kotlin 对照 fixture 的 JSON 只是测试文档，
不构成第二套运行时协议。配置、块与行内项采用对应 DTO/Enum。
rustMicros 记录方法内载荷校验、模型转换、布局和紧凑结果装配的墙钟微秒，不含最终 SSE 编解码；
Flutter 的调用总耗时包含 Rust 耗时，不能将两者直接相加。

几何使用上游 Float 对应的 f32，视口宽高为整数；整数除法、浮点累计及截断按上游执行顺序。
原文坐标为 UTF-16 半开区间，簇索引用于断行，二者不得互换。平台测量输出簇和宽度，
Rust 不重新塑形字体。零长度的背景音乐/段评元素允许存在；文本和角色标记保留各自原文语义。

`config` 对应 `ReaderPaginationConfig`：章节身份、视口、四边内距、行高、基线、
字距、段距、标题间距/居中、分栏、滚动、页底对齐、下划线及角色档案快照。
装饰和字体资源仅传数据/资源标识，不传 Flutter 或 Android 对象。

内容块由 LayoutBlockDto 的类型枚举区分：`paragraph`（已测量正文）、`inlineParagraph`（通用行内项）、
`image`、`blankLine`、`rule`、`pageBreak`。正文保留 text/clusters/clusterWidthsPx/style/
chapterPosition/缩进/对齐及测量覆盖项；行内段落保留完整行高、基线、字号、缩进、
装饰、词间对齐及逐项样式几何。行内项类型为 `text`、`image`、`roleCast`、`bgmScene`
和项目扩展 `review`，字段对应上游同名数据模型，段评另含段落标识、查询标识及原文锚点。
Rust 强类型模型为字段与默认值的执行定义，禁止静默忽略未知字段。

输出页面保留上游 ReaderPage 的页面身份、文本、视口、内容边界、滚动高度、
revision 和最终元素集合。元素携带最终 bounds，文字/段评携带 baselinePx；
渲染、选择和命中测试消费这些结果，不能二次断行或缩窄正文。
页面 text 保留上游图片占位语义；复制、搜索和 TTS 使用原文范围，不使用该展示串。

输出使用唯一的紧凑列式结构，不添加格式版本标识或兼容分支：共享 `textStyles`；
LayoutReplyDto 携带 count、合并文字 text、geometry、positions 和稀疏 extras。
geometry 为 Vec<u8> 直传的小端 f32 数组，每字形五项 left/top/right/bottom/baseline；
positions 为 Vec<u8> 直传的小端 u32 数组，每字形四项 sourceOffset/paragraphIndex/styleIndex/
合并文字 UTF-16 endOffset。起点为前一字形 endOffset，首字形起点为零。
页面 elements 中的整数引用共享字形编号，非文字元素保持完整对象和原顺序。
extras 以字形编号为键，保存非默认标记、链接及背景边框等字段。
Flutter 校验缓冲长度、几何、样式与文字范围后使用只读视图，不恢复每字形动态数组。
缺少当前契约必需字段直接报错，不解析历史传输格式。

已输出的 Rust 页面转移所有权，不在会话里保留历史元素副本；仍保留一页前瞻和绝对页编号。
Flutter 页面与行引用同一元素存储，复制、选区和朗读继续使用原文 UTF-16 范围。

## 会话与取消

每个会话一块前瞻以决定真实段末间距；未确定章末的页面延迟一页输出，与上游一致。
finish 输出余页并释放核心和并发许可。cancel 幂等；被取消的会话不得继续输出。
客户端结束后显式 dispose 句柄；GC 只作引用回收兜底，不替代在途取消。
Rust 核心不包含 FFI 注册表；opaque LayoutSession 持有独立核心与并发许可，保留载荷/资源上限。
客户端切章、重排、销毁或发生错误时取消旧会话，并用代际标识拒绝迟到结果。
禁止逐字符 FFI 往返；推送已测量块的批次，并分别记录编码、调用、Rust 计算和解码耗时。

## 上游与扩展边界

参考固定提交的原始 `ChineseLineBreaker.kt` 与 `ReaderPaginator.kt`。
普通正文标点悬挂、行内段落收窄、标题、分栏、行高与基线采用相同规则。
同输入的簇/UTF-16 边界、页栏与类型须精确相等；几何比较声明 f32 累计误差。
不得用截图或自身 Rust 输出生成的期望代替原始 Kotlin 对照。

段评是显式扩展：紧跟末尾正文，占用固定槽宽；必要时回退合法断点，保持尾部正文与
段评同行。数量正数变化仅重绘；显隐变化重新布局并保持原文锚点。极窄区域使用紧凑图标。
模型中保留上游角色/音乐类型不等于开启对应产品功能。

Flutter 已有的“关闭中文排版”设置以显式 `breakMode: plain` 保留朴素断行；
默认 `breakMode: chinese` 执行上游算法。plain 是项目已有设置的扩展路径，不宣称来自上游。
首页独立标题的测量占位使用上游 Rule 内容块表达，不另改首页的分页判定。

编写者：Codex｜2026-10-12；传输契约修订：2026-10-17
