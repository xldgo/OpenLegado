# 正文重新分段对照样例

`content_resegment.json` 的 expected 来自实际运行上游 Kotlin `ContentHelp.reSegment`，
不是按 Rust 实现反推。原版 LegadoTeam/legado 提交 `363540972`，路径
`app/src/main/java/io/legado/app/help/book/ContentHelp.kt`；参考 HapeLee 提交 `c4182eb9b`
仅将 makeDict 的 Java Pattern 改写为等价 Kotlin Regex。

生成时复制原函数到临时目录，只把 Math.random() 改为每条样例的 random 值，使用本机
Kotlin 2.4.21 编译并运行。恢复生产调用时仍使用随机数，不固定用户的长段切分。
输入覆盖错误换行、标题、空白、对话及引用、重复词条、长段和 UTF-16 代理对；
不同随机值只用于验证概率切分，不为每个私有辅助函数重复建用例。

临时编译器入口及输出位于本地 build/resegment；无需 Android 环境运行永久 Rust 回归。

编写者：Codex + Rust｜2026-10-24
