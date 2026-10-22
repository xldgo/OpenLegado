# Flutter 功能归属迁移方案

基线：dev / f25eff188。用户授权逐步实施、每步本地提交；状态与验证结果只维护在
[活动计划](REFACTORING_ACTIVE_PLAN.md)的FEATURE-OWNERSHIP-20261022，不推送或触发CI。

## 目的与边界

让功能私有界面回到所属feature，数据存取与原生适配回到data，纯协议与数据回到domain。
保留现有Riverpod、路由、Rust/FRB签名、数据库、存储键、资源释放和所有用户可见行为。
此为既有分层规则的应用，不新增框架、use-case壳、转发文件或统一feature模板。

公共App控件、共享实体、登录/编辑基础组件、应用装配、主题和平台能力不随单一调用数搬家。
本轮不扁平化所有feature，不删除孤儿组件，不重组audio/read_aloud业务依赖，不拆大型页面。
应用版本保持2.0.439+440；纯结构变化不写面向用户的更新日志。

## 批次

| 步骤 | 范围 | 目标 | 验证 |
|---|---|---|---|
| F1 | explore四组件、定时任务调试、替换/RSS分组、系统TTS设置 | 各自features/*/widgets | 发现布局/导航、任务消费者、规则列表及TTS管理的既有定向回归 |
| F2 | 视频弹幕、悬浮按钮、长按倍速、视频设置 | features/video/widgets | 弹幕、倍速、设置与浮窗调用方回归 |
| F3 | widgets/reader与paragraph_layout_engine | features/reader的layout/selection/turn/widgets/navigation；朗读专属面板归read_aloud | 文字测量/选区/翻页/开书及朗读面板必要回归 |
| F4 | reader_position_store | 锚点归domain/models，偏好存储归data/repositories | 原存储与阅读会话用例，不改锚点编码和存储键 |
| F5 | reader_layout_service/data | 传输接口/结果/会话归domain；Rust实现与DTO转换归data；InheritedWidget归reader | 会话取消/迟到响应/协议解码与Flutter编排回归 |

每步同步生产、测试、工具中的import/export/part和实际构建路径引用；不批量修改历史证据。
生成代码不手改，无生成需求不运行codegen；移动的文件不留旧路径兼容导出。
步骤F4/F5仅改变Dart内部职责，实施前在API契约记录不变项，不增加FRB方法。

## 验收与回滚

只复用直接受影响的行为测试，不为路径或目录新增源码文本测试，不默认跑全量及设备构建。
定向分析、既有架构门禁和diff复核分别检查导入、分层与范围；测试按实际依赖选取，
纯路径调整以语义不变复核为主，不把测试数量当作收益。
F3保留阅读器私有的测量/选区/翻页分组，不把所有文件堆进根目录；跨功能入口仍可引用所属功能。
F5禁止domain依赖Flutter、Bridge或data，禁止data反向依赖feature；原生实现从装配点注入。
纯Dart传输替身不证明真实FFI运行；本轮不重编Rust或宣称设备功能验收。

每步复核后本地提交；不使用子代理，单代理复核不标作独立审查。失败只回退当前批次，
保留之前已交付提交和其他任务未提交修改。后续发现的行为问题另立项，不借迁移顺手改协议。

编写者：Codex + UI / Bridge｜2026-10-22
