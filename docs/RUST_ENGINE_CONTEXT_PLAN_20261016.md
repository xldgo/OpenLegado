# Rust 引擎上下文收敛设计与实施方案

任务编号：ENGINE-CONTEXT-20261016。优先级：P1。

本文件保存设计、代码依据和分批验收方法；任务状态只维护于
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。方案中的待实施设计不代表代码已改造或测试通过；
实际已验证范围以 Active 对应批次及其证据为准。

## 1. 基线、授权与范围

- 基线：主目录分支 `feature/ui-reader-selection` 已提交的
  `d897d8c64f8217847e33969a9a6ee9a6ee9aeb8d267e7`。
- 工作树：`build/worktrees/rust-engine-context`；分支：`feature/rust-engine-context`。
- 主目录另有未提交的 Flutter/RSS 及契约、Active 文档修改，未复制、暂存或覆盖。
- 用户要求：在 worktree 中执行，先形成完整计划，不使用子代理。
- 文档先于实现形成；后续实现限定 Rust 引擎状态及宿主接线；不主动提交、推送、合并或触发 CI。
- 保持 Flutter/Dart、FRB 2.13.0、Rust stable、依赖版本、数据库 schema 和应用版本不变。
- 不夹带 JSON DTO 强类型化、页面迁移、排版算法、TTS 功能、性能调参或工作流改版。

## 2. 对原报告的核实与纠正

| 报告判断 | 当前代码依据 | 结论与设计影响 |
|---|---|---|
| Rust 有十个 workspace crate | [Cargo.toml](../rust/Cargo.toml) | 属实；新增装配 crate 后为十一个，不把它描述为现有模块 |
| core 位于 DB/网络/抓取的上层 | [core](../rust/legado-core/Cargo.toml)、[db](../rust/legado-db/Cargo.toml)、[net](../rust/legado-net/Cargo.toml)、[fetcher](../rust/legado-fetcher/Cargo.toml) | 不成立；db、net、fetcher 依赖 core，把持有它们的 Context 放 core 会产生依赖环 |
| App 内 Server 另开数据库连接池 | [server_api](../rust/legado-ffi/src/api/server_api.rs)、[db_state](../rust/legado-ffi/src/db_state.rs)、[server](../rust/legado-server/src/server.rs) | 已过时；内嵌 Web/MCP 已从 FFI 同一池取连接，独立二进制才自行打开库 |
| Server 数据访问仍受单连接互斥限制 | [AppState](../rust/legado-server/src/state.rs)、[with_state_db](../rust/legado-server/src/handlers/web_book.rs) | 属实；长期保留池连接且有 try_lock/block_in_place/无值降级路径；替换时要同时迁移异步 handler 与同步抓取回调 |
| FFI/Server 限流器分叉 | [FFI registry](../rust/legado-ffi/src/api/source_rate_limit.rs)、[Server registry](../rust/legado-server/src/handlers/web_book.rs) | 属实；共享算法不等于共享窗口实例，书源保存后的刷新也必须落到同一实例 |
| Cookie 完全没有共享 | [http_state](../rust/legado-ffi/src/http_state.rs)、[JS network](../rust/legado-js/src/host_api/network.rs) | 不准确；FFI 和 JS 网络池已共享 HTTP CookieStore，但 JS 自身还有内存表，Server 仍每次装配独立客户端并预载 DB |
| fetcher 只要传入 deps 就已无全局状态 | [deps](../rust/legado-fetcher/src/deps.rs)、[web_book](../rust/legado-fetcher/src/web_book.rs)、[tts_fetcher](../rust/legado-fetcher/src/tts_fetcher.rs) | 不成立；正文/书籍元信息/章节映射缓存、epoch 和 TTS 默认存储仍有进程级状态 |
| 只有 FFI/Server 两个 Tokio runtime | [FFI runtime](../rust/legado-ffi/src/runtime.rs)、[Server runtime](../rust/legado-ffi/src/api/server_api.rs)、[JS runtime](../rust/legado-js/src/host_api/runtime_bridge.rs) | 不完整；JS 同步网络桥也持有 runtime，不能直接合并后保留嵌套 block_on |
| 用内存池即可实现并行测试 | [Database](../rust/legado-db/src/connection.rs) | 需要条件；当前内存池大小为一，持有 Database 时再次取连接会等待；多连接 :memory: 也不共享数据 |
| 替换一个 Arc 就支持安全重启 | [JS Cookie sink](../rust/legado-js/src/host_api/cookie_store.rs)、[JS 变量](../rust/legado-js/src/host_api/variable_store.rs) | 不成立；first-wins 钩子、在途请求、任务、缓存与目录同样必须隔离和收尾 |
| 只要 FFI 签名不变就不需要 native 重建 | [双轨规范](TWO_TRACK_DEV_SPEC.md) | 不成立；可不改绑定，但 Rust 输入指纹已变，真实应用验证前必须重建对应 native 产物 |

原报告中的性能收益、测试加速幅度和“零功能破坏”尚无测量证据。
SQLite/r2d2 访问是同步阻塞操作，不能因函数外包一层 async 就当成异步 I/O。
本任务不承诺移除所有 static：编译后的纯正则、不可变常量和不依赖账号/库身份的缓存可继续共享。
原报告关于 FRB TypedData 必然零拷贝的表述也不作为本任务前提；传输和编解码需另行测量。

## 3. 目标依赖与职责

推荐新增 `legado-engine`，由两个宿主共同依赖，承担资源装配、生命周期和必要的共享服务：

```text
legado-ffi ─────┬──→ legado-engine ──→ legado-db / legado-fetcher / legado-net
               │                     └──→ legado-js / legado-core
               └──→ legado-server ──→ legado-engine

legado-fetcher ──→ legado-js / legado-net / legado-parser / legado-core
legado-db / legado-net / legado-parser / legado-book ──→ legado-core
legado-core ──→ legado-layout
```

上图仅展示与此次决策有关的依赖，非完整 Cargo 依赖清单。
底层 crate 不反向依赖 engine，engine 不依赖 ffi/server。
现有业务 crate 保持自身职责，不把仓储、抓取算法、书源规则和所有 API 搬进 engine。

### 3.1 选项与取舍

| 选项 | 优点 | 问题 | 选择 |
|---|---|---|---|
| Context 放 core | 少一个 crate | core 需反向依赖 db/net/fetcher，形成环或迫使无关的大范围分层重写 | 不采用 |
| 放 server，供 ffi 复用 | 表面修改较少 | 头less 引擎依赖 HTTP 宿主，保留宿主拥有业务资源的问题 | 不采用 |
| fetcher 新增全局单例 | 容易让两个限流入口取到同一 Arc | 多库/测试/关闭仍共享身份；无法解决 DB/Cookie 生命周期 | 不采用 |
| 新增 engine 上层装配 crate | 依赖无环，宿主平等，资源可独立构造 | 增加一个内部 crate；须管理 feature 透传和构建矩阵 | 推荐 |

该调整服务于现有“Rust 核心 + Flutter UI”的边界，不改变项目中心或公开产品能力。
不新增通用插件系统、依赖注入框架或任务调度框架；只建立有真实消费者的类型。

### 3.2 Context 组成与可见性

| 类型 | 持有内容 | 不持有 |
|---|---|---|
| EngineContext | storage、network、fetch/JS 服务、任务生命周期的窄句柄 | Flutter 状态、FRB StreamSink、Axum router、监听端口、UI 设置页 |
| StorageContext | 成功初始化后的 pool 与同一身份的数据库路径 | 长期借出的连接、全局当前库查询闭包 |
| NetworkContext | 可重建的客户端配置/槽位、共享 CookieStore、绑定 storage 的持久化后端 | 新建第二套 Cookie 规则、指向“当前全局引擎”的动态写库回调 |
| FetchContext | 书源限流表、需要隔离的抓取缓存和请求会话工厂 | 整章排版算法、所有仓储接口 |
| JS 宿主资源 | Cookie/变量/cache/网络能力句柄与来源会话 | EngineContext 类型本身、可跨线程随意搬动的 QuickJS VM |
| TaskScope | 引擎取消根、宿主/操作子作用域和可等待的任务登记 | 单个用于取消所有搜索/朗读的公共 AtomicBool |
| 宿主适配器 | FFI 根持有者，或 ServerConfig、鉴权、监听任务 | 第二份 DB/客户端/限流窗口 |

以上是职责边界，不要求每行都创建一个独立模块或 crate。
字段默认私有，提供 db 闭包访问、客户端快照和限流等窄方法，避免到处传递万能 Context。
解析、断行、模型转换等纯函数继续收取具体输入；只有应用编排入口接收 Context/能力句柄。

### 3.3 Runtime 的所有权

不默认把 `Arc<Runtime>` 塞入 Context。引擎任务持有 Context、Context 持有 runtime
容易产生保活环，也可能在异步线程上 drop runtime。

- 运行时由宿主/最外层监督者拥有；Context 如需派发，仅持 Handle 或窄执行接口。
- 独立 server 可使用现有 Tokio 运行时；FFI 可使用自己的持有者，不额外制造嵌套 runtime。
- 首几批保留现有运行时数量、线程数、栈大小、超时和已设置的优先级。
- JS 的同步网络桥改造完成并验证前，不统一合并 FFI/Server/JS runtime。
- 需要线程池时优先复用有界 spawn_blocking 或现有 QuickJS 工作线程，不预先引入 Rayon。
- 不把“使用 Rust”或“降低 nice”解释为保证永不影响 UI；实际争用需单独度量。

## 4. 状态迁移清单

| 当前位置 | 状态 | 归属及处理 |
|---|---|---|
| ffi/db_state.rs | DB_POOL、DB_PATH | StorageContext；池和路径一起发布，失败不留下路径指向新库而池仍是旧库 |
| ffi/http_state.rs | 客户端、HTTP CookieStore、Cookie RMW 锁与 DB 后端 | NetworkContext/共享 Cookie 服务；保留读写、合并、清除和宽容失败语义 |
| ffi/source_login_cache.rs 与 server/web_book.rs | 登录内存表、两套查询后端 | SourceLoginCache 持有实例状态及唯一 StorageContext；原生两宿主共用，JS 变量同步另按执行链迁移 |
| ffi/source_rate_limit.rs 与 server/web_book.rs | 两份书源 registry | 同一 EngineContext 的一个 registry；不同引擎各自独立 |
| server/state.rs | Mutex<Database> | 换成 Arc<EngineContext>，每次操作短借连接；不再占一条连接直到服务停止 |
| server/web_book.rs | with_state_db、ServerCookiePersistence、每次新客户端 | 改为上下文能力；移除锁竞争即无值的分支和重复持久化算法 |
| js/network.rs、cookie_store.rs | first-wins 钩子、网络池、JS Cookie 表 | 注入 VM/执行器的宿主资源；同引擎共享，异引擎隔离，避免永久绑定第一个测试库 |
| js/variable_store.rs、cache_store.rs | 变量、FLOW_SCOPE、内存/磁盘缓存目录 | 引擎状态与单次书籍流程分开；来源/书籍维度保持，flow 不能由一条进程单槽决定 |
| fetcher/web_book.rs | 页面 body、book meta、章节映射、TOC epoch | 注入 FetchContext/请求会话；保持现有缓存容量、键和失效语义，增加引擎身份隔离 |
| fetcher/tts_fetcher.rs、tts_source.rs | 默认限流与默认内存 source store | 正式入口显式注入；审计所有默认入口消费者后删除隐式共享状态或限制到明确测试辅助 |
| fetcher/tts_control.rs | 按目录和输入键建立的弱引用合成锁 | 文件资源同步工具；同一物理缓存目录的写方必须互斥，不机械按引擎拆成两把锁 |
| net/cookie_store.rs、js/cookie_store.rs | 按域写锁，含依赖 static 生命周期的裸指针机制 | R4 与 JS 注入一起迁移为安全持有的锁作用域；不得删条目使已有 guard 悬空，不引入新的 unsafe |
| ffi/search.rs、source_check/debug、cache_download、download | 全局会话、取消、任务与恢复标记 | 任务作用域按现有协议区分宿主/操作；单宿主默认行为不改变，取消 Web 操作不误取消 App 操作 |
| ffi/server_api.rs | Web/MCP 端口、running、JoinHandle、专用 runtime | 留宿主服务管理器，监听服务消费 Context；先停服务/等待，再释放 Context |
| ffi 图片/音频/TTS 与 js 缓存目录 | 注入路径及运行时缓存 | 归属该引擎/宿主配置；保持当前默认值和注入优先级，不随意更改磁盘格式 |
| 各 crate 的纯正则、常量、诊断计数 | 不含用户/DB/来源身份的状态 | 可保留进程共享；不以 static 数量降为零验收 |

这是已定位的核心迁移入口，实施前还需逐入口追到真实消费者。
测试专用静态项与生产状态分开清点；没有迁走依赖的测试锁不提前删除。

## 5. 初始化、配置与关闭协议

### 5.1 保持现有 FFI 行为

本轮不新增或修改 FRB 导出签名、JSON、错误码、调用顺序要求和 Stream 事件顺序。
尤其不能把 `db_open` 从“已初始化则忽略重复调用”悄悄改为切库操作。

1. FFI 入口只在边界取一次当前资源快照；之后闭包、任务和持久化回调捕获同一实例。
2. 成功构造并迁移数据库后，才发布 pool + path。初始化失败不发布半成品。
3. 并发初始化由宿主初始化门控串行化；不在全局槽位写锁内做 DB/网络 I/O。
4. DB 初始化之前可使用的网络能力继续可用，不用 EngineNotInitialized 改写旧行为。
5. 为此保留宿主启动阶段的 NetworkContext，同一次启动的后续 Context 复用它的 CookieStore；
   DB 就绪后绑定实例内持久化能力并重建客户端，不能抛弃初始化前获得的内存 Cookie。
6. 持久化绑定与旧客户端升级必须有测试；采用实例内后端路由，不能在写回时重新查“全局当前库”。
7. 初始化中出现旧请求/JS 注册时，明确等待或使用该启动实例，不允许第一轮绑定测试库后永久占用。
8. 保留 customHosts 恢复、MCP 配置恢复、缓存目录注入及失败容忍顺序；恢复失败不得误报整个服务已启动。

内部启动阶段不构成新公开 API；不为过渡阶段设计独立对外协议。
真实调用顺序与现有测试若证明某个早期能力不可达，可进一步缩小过渡路径，而非保留无消费者的壳。

### 5.2 HTTP 配置更新

- 代理、证书、Cookie 开关等沿现有配置入口生效，不借重构改默认安全策略。
- 新客户端在锁外构造，成功后更新 NetworkContext 的客户端快照；失败保留旧可用配置。
- 替换客户端保留同一 CookieStore、持久化后端与书源限流表；Server 的下一次操作取得新快照。
- 旧请求可完成，但只写回其所属引擎的 storage；不能漂移到别的引擎。
- 路由不同 TLS/重定向策略的 JS 网络池保留必要派生客户端，不要求所有请求只能使用一个 reqwest 对象。

### 5.3 Cookie 不变式

- 继续按现有 ETLD+1 域规则共享，不改为每书源独立 Cookie。
- 保持 enabledCookieJar 的读写门控，默认项及 loginCheckJs 行为不变。
- 同引擎 FFI、HTTP、JS、Server 的变更应立即可见；清除覆盖各内存视图与 DB。
- 合并写入、删除与清空使用同一保护域，防止旧写方把已清 Cookie 复活。
- 保持域通道最外层；jar/JS 内存短锁不跨 DB/sink I/O，不跨 await。
- 客户端/全局持有者锁内不调用持久化后端；后端只捕获 storage/专用锁，不捕获根 Context。
- 核对 Server MCP 清除路径的独立删除锁，一并纳入共享服务，避免只合并 jar 而保留删除竞态。
- 不改变当前持久化失败仅记录诊断、不打断已成功网络请求的容忍策略。

### 5.4 引擎生命周期

内部生命周期采用 `Running → Draining → Stopped`，实例停止后不能重新启用旧取消根。
该状态仅用于运行期控制，不新增数据库字段、持久化版本号或所谓新旧数据兼容标识。

关闭顺序：

1. 禁止接纳新业务任务和新监听请求；进入 Draining。
2. 停止 Web/MCP listener 并等待监听任务，释放已绑定端口。
3. 取消各业务子作用域，按现有协议通知搜索、下载、TTS 等消费者。
4. 等待已登记网络/DB/JS 工作结束；已启动的 spawn_blocking 不能仅靠 abort 宣称终止。
5. 确认持久化回调结束后释放 JS VM、网络池、实例缓存和 storage 句柄。
6. 运行时监督者在异步任务之外释放自己拥有的 runtime；外部注入的 runtime 不由引擎销毁。

等待超过约定期限时返回明确未完成状态，不宣称安全切库，不发布新库使旧回调写进新库。
合作取消与 QuickJS 的执行期限/中断能力配合，不强杀任意线程。
防止 `Engine → Client → Persistence → Engine`、`Engine → Task → Engine` 的强引用环。

本轮的内部关闭/重建首先用于独立 Server 和测试；App 没有已授权的热切库 API 时不新增该能力。
数据库覆盖恢复、备份语义保持；将来公开热切库需要另行冻结 FFI 契约和数据安全方案。

## 6. 分批实施及各批出口

各批先通过自己的定向回归，再进入下一批；用户未授权时不自动提交。
不在每批创建新分支。临时委托只转发到新状态，不保留两套实际实现或失败回退。

### R0：冻结现状与并行边界

- 落点：本方案、Active；实现前补充状态—写方—读方—关闭方消费者表。
- 冻结 db_open 重复调用、未初始化错误、早期网络、Cookie、源刷新、服务启动失败和同端口重启语义。
- 测量现有服务启动所持连接数、相同文本/本地 HTTP fixture 的调用时延及线程/客户端数；已有重复测试优先复用。
- 测试计时与编译耗时分开；新 worktree 的冷缓存不能用来证明改造变慢/变快。
- 出口：风险入口均对应真实函数/既有行为样例，未测项明确登记。

### R1：新增 engine 与 StorageContext，接入 FFI 数据库状态

- 路径：workspace/Cargo.lock、新 engine、ffi/db_state、初始化内部接线及相关测试。
- 使用现有 Database 初始化和迁移逻辑，提取 pool 后立刻归还初始连接。
- 将池和路径合并为同一个实例身份，db_state 转为唯一实现的宿主入口，不再另存 DB_POOL/DB_PATH。
- 首批只保证 storage 的实例隔离；不声称网络/JS 已无全局污染。
- 内存测试每个实例独立池且归还初始连接；并发、锁竞争和事务测试用唯一临时文件库。
- 出口：初始化成功/失败/重复/并发、两实例隔离、释放初始连接、相对书籍路径解析回归通过。
- 回滚：整批恢复 db_state 接线和 workspace 变更，不涉及 schema 或业务数据转换。

### R2：Server 改为消费同一 Context，统一书源限流窗口

- 路径：server/state、启动入口、handlers/legacy 及对应测试，ffi/server_api、source_rate_limit。
- 内嵌 Web/MCP 接收当前 Arc；独立二进制自行构建 EngineContext，两个独立进程不声称共享内存状态。
- AppState 移除 Mutex<Database>，只保留 Context 与宿主自己的端口/鉴权/会话等状态。
- async handler 通过有界阻塞 DB 闭包完成连接获取与 SQL，错误传播到现有 HTTP/MCP 错误映射。
- 所有同一事务的 SQL 在同一闭包/连接内完成；禁止把 repository/guard 带出再跨 await。
- 同步 FetcherDeps 查询在合法阻塞/JS 工作线程短借连接，移除 with_state_db 的锁竞争无值回退。
- 数据库操作结束后才进入网络或 JS；单连接测试也不允许持连接再入抓取回调。
- FFI/REST 书源保存和导入成功后刷新 Context 的同一 limiter；失败不刷新。
- 出口：无长期池连接占用；FFI/REST 共用窗口、双向刷新、current_thread 下并发 DB 查询不丢值；
  默认/quickjs 构建、Web/MCP 绑定失败及原端口重启通过。
- 回滚：同批回退两个宿主接线，不能仅回退一端而留两套 registry。

### R3：HTTP 与 Cookie 共享服务

- 路径：engine/network、ffi/http_state、server/web_book 与 MCP Cookie 路径；必要的 net 能力接口。
- 搬迁现有 DB Cookie 后端和合并/清除原语；FFI/Server 不再重复实现同一算法。
- Server 不再每次抓取新建客户端，复用同引擎网络快照和 CookieStore。
- 保持 source_cookie_jar、代理、证书、重定向、登录校验和配置更新行为。
- JS 现有钩子先接到当前 Context 能力；明确这是单宿主过渡，下一批解决 first-wins/多实例。
- 出口：localhost fixture 验证双向 Set-Cookie、显式 setCookie、持久化、合并、清除不复活、配置替换与早期网络升级。
- 回滚：同时回退 HTTP/JS 钩子/Server Cookie 三侧，避免半共享。

实现补充（验收结果与进度仅登记 Active）：

- `legado-engine/src/network.rs` 承载共享 jar、客户端配置槽位和实例绑定的 Cookie 后端；
  后端只持 StorageContext，不回调 FFI 全局句柄，客户端不反向持有根引擎。
- 根持有者保留数据库打开前的 NetworkContext；绑定时按内存优先合并并写回早期 Cookie，
  原有客户端使用的后端随该实例启用持久化。再次绑定另一数据库明确失败。
- 统一 Web 抓取、RSS、REST/MCP 书源检查及旧 Web 图片代理的默认客户端；
  异步入口首次装配放在阻塞任务中。订阅更新使用原有单独配置的 reqwest 客户端，策略保留。
- 真实 localhost 回归发现 reqwest 的隐藏 jar 在共享 jar 清空后仍发送旧 Cookie；
  改为共享 provider，全部发送路径在请求级 task-local 作用域内携带 CookieJar 写入许可。
  该作用域只表示本次请求的开关，不查找或切换引擎；文本、字节、流式和重定向共用它。
- CookiePersistence 的 `preload` 将 DB 快照读取与 jar 回填纳入同一写通道，
  修复清除夹在“读取旧行/回填内存”之间时的复活窗口。jar 锁和客户端槽位锁不跨 DB I/O。
- JS 显式写入仅将本次变更键合并至共享后端，避免旧全量视图覆盖较新的 HTTP Cookie；
  未适配后端继续收到完整串回调。WebView 回流即时同步共享 jar；MCP 清除通过当前网络实例同步 jar 与
  已注册的 JS 镜像，保留未加载 DB 的网络能力、持久化宽容失败与现有归一键语义。
- JS 的 first-wins 钩子、独立 JS 内存表及 net/default JS 的域锁注册表仍是进程级协调；
  将安全持有的域锁迁移与 R4 的 JS 资源注入一起实施，避免只换一侧造成锁序分叉。
  本批不逐出旧域锁条目、不新增 unsafe，也不声称 JS 多引擎隔离已经完成。

### R4：JS 宿主状态与抓取缓存实例化

- 路径：js/host_api、engine_pool/executor/source_engine，fetcher/deps/web_book/TTS 默认装配、两宿主注入。
- 在 js crate 定义只依赖能力接口的宿主资源类型，VM/执行器构造时注入；不让 js 引用 engine。
- 替换 first-wins Cookie/来源查询钩子及持久化闭包；变量/cache/目录按引擎绑定。
- `flow` 明确为来源/书籍请求会话，传入 JS 执行上下文；不能只换成另一个引擎级“当前流程”单槽。
- 不用 thread_local 跨 async await 推断当前引擎；QuickJS 线程亲和性和沙箱/超时策略保留。
- 元信息、body、章节映射、TOC epoch 和登录/explore overlay 随实例隔离；纯正则可共享。
- customHosts resolver 仍沿用进程级配置，最终网络多实例隔离验收须覆盖其归属，不能仅凭客户端/罐隔离判定完成。
- TTS 正式路径继续注入 storage、registry 和取消；清理默认全局状态前核对所有消费者。
- 文件缓存锁按实际目录/输入资源保持互斥，避免不同 Context 写同一文件时发生冲突。
- 出口：同 URL/同 key/不同库两引擎的 Cookie/变量/cache 不串；两个书籍流程交错执行不丢会话变量；
  释放旧实例后钩子不引用旧库；默认与 quickjs 网络/书源/TTS fixture 均通过。
- 回滚：按完整 JS 构造和调用链回退，不能只恢复某个全局钩子。

#### R4a：抓取缓存先与 JS 状态分开迁移

- `legado-fetcher::web_book_state::WebBookState` 保存 HTML、BookMeta、章节所属书、
  下一章映射及 TOC epoch。EngineContext 持有 Arc，FetcherDeps 显式注入；
  clone 的依赖共享状态，独立构造的依赖隔离状态。
- 保留 45 秒 HTML TTL、32 条 HTML 上限、512 条 BookMeta 和 8192 条章节映射上限，
  合并、复合键、清空与最旧淘汰规则均不变。原来每次请求的详情/目录首抓页继续请求，
  不因状态迁移扩大缓存命中范围。
- FFI 根持有者保存开库前的缓存，成功初始化时注入原实例；内嵌 Server 从同一
  EngineContext 取得，独立 Server 自行构造。读缓存不访问全局当前数据库。
- TOC epoch 只变为引擎内代数；同引擎现有刷新取消规则保持，按书籍/操作的取消归属
  由后续 flow 和任务子作用域接替，不据此认定同引擎多书互不取消。
- 行为证据包括同 URL 不同 HTML 的两实例实网夹具、元信息/下一章关系隔离、
  依赖 clone 复用与 Weak 释放、TTL/容量，以及开库前后 FFI 与内嵌 Web
  共用目录后续页缓存。跨宿主夹具关闭分页源站，首抓页保持可用，验证实际缓存消费者。

#### R4b 及后续 JS 迁移的实施边界

- 迁移基线中的 `variable_store::GLOBAL_VARIABLES/FLOW_SCOPE`、parser 全局兜底读者、
  QuickJS 引擎缓存、JS Cookie 表和 first-wins 网络/来源钩子属于同一执行链。
  只迁出表或只改解析器回调都不能证明 JS 多实例隔离。
- 先确定 VM/执行器构造参数，再按源规则、mainJs 编排、loginCheckJs、TTS 及宿主
  直接执行入口迁移真实消费者；同时明确规则子解析器如何继承同一 flow 和变量读者。
- Flow 使用显式会话句柄，来源/书籍键用于定位，不能把进程单槽替换为引擎单槽。
  在途 A 流程必须持有 A 的资源，启动 B 不得清掉 A；不能用线程局部当前值跨 await。
- VM 缓存所有者与回调捕获的资源分开，避免“缓存 → VM → 回调 → 同一缓存/宿主”的
  Arc 环；释放测试应覆盖真实 VM 回调，不能仅断言空容器 Weak。
- JS/net 域锁随 Cookie 能力注入一并处理，旧回调不能继续查找另一实例资源。
  纯正则与纯脚本分析缓存可共享；有用户/来源/目录身份的数据必须绑定实例。
- R4a 不改变上述 JS 全局表和测试锁，也不新增临时 JsHost 空壳或对外隔离声明。

##### R4b1：VM 缓存资源接线

- `legado-js::JsResources` 持有非词法规则与 mainJs 的 `EngineCache`，不依赖 engine/宿主。
  EngineContext 持有 Arc，FetcherDeps、FFI 装配函数和 Server 接线显式传入。
  默认独立构造的执行器/JsSourceEngine 不再读取隐式共享的缓存槽位。
- 缓存保留每实例 32 条 LRU、jsLib/setup/mainJs 变化失效、mainJs 构造失败后带绑定重评，
  以及词法重声明回退新 VM 的规则。URL 映射 jsLib 和原有 fresh_engine 路径继续使用新 VM。
- 运行期学到的重声明识别记录也归属 JsResources，不能因另一实例先遇到同一脚本错误，
  就使本实例跳过自身 VM、丢掉原有脚本状态；纯正则/静态分析仍可按既定规则共享。
- loginCheckJs 的首检与 errResponse 二次检测显式复用同一资源；预校验、URL 模板、
  列表/详情/目录/正文解析、发现页、字典、预更新和 AutoTask 消费所属 FFI/Fetcher 资源。
  TTS 已注入的独立 SourceExecutor 继续每次构造新 VM，不扩展其缓存范围。
- 初始化结果使用具名 CachedEngine，携带本次 jsLib 错误，避免相同书源标识的全局
  capability ledger 覆盖异常原因；台账保留诊断用途，其实例化不包含在此子批。
- VM 缓存不捕获 JsResources/EngineContext；缓存和执行器的释放用真实 VM、已注册
  宿主回调和 Weak 验证。仅删除原 VM 缓存测试锁，变量/Cookie/flow 测试锁仍有实际作用。
- 后续 R4b2 再迁移变量读写、parser 兜底读者、显式 flow 句柄及 Cookie/网络宿主能力。
  本子批只能证明 VM 自身的 JS 全局变量不跨实例，不能证明 java.put/get 或 Cookie 已隔离。
- R4b2 必须核对“详情 → 目录 → 正文”跨调用变量连续性，不能每次 FFI 调用都创建立即丢弃的空 flow。
  同时核对缓存 VM 如何消费本次显式 flow：回调不能永久捕获第一次请求的 flow，
  也不能反向捕获拥有自身缓存的 JsResources；parser 子分析器须继承同一变量读者。
  先通过两个书籍流程交错、同书连续调用和资源释放用例，再逐个移除旧读者与测试锁。

##### R4b2a：解析器变量读取能力

- 删除 parser 的进程级变量读取器注册与槽位，AnalyzeRule 只使用自身 VariableReader，
  未显式注入读者时可委托当前 JsExecutor；没有任何能力的独立解析器保持空值。
  本地绑定、bookName/title 及本地非空变量的优先级保持。
- 子规则复制当前读者；显式读者即使未命中也不再穿透到另一个执行器读者。
  变量读取回调没有全局持有者，实例并行测试与 Weak 释放测试不再需要 parser 全局锁。
- 现有书源、目录分页、字典、封面与调试入口明确接线。段评传递已配置的 AnalyzeRule，
  摘要/详情/回复条目继承读者与执行器，但仍各自持有独立本地变量表；默认档不伪造 JS 执行器。
- QuickJsExecutor 与 flow_variable_reader 暂仍访问既有 JS 全局表与当前 flow，
  本子批没有隔离 java.put/get、Cookie 或交错书籍会话。只有 parser 专用旧锁可删除，
  FFI/fetcher/JS 的实际全局变量测试锁继续保留。
- 后续继续把变量能力与显式 FlowHandle 装配到执行器及 native 回调；缓存 VM 必须消费
  本次会话，并保留同书详情→目录→正文跨调用连续性，不能捕获第一请求或形成 Arc 环。

##### R4b2b：变量能力与 HTTP TTS 先行接线

- VariableStore 提供裸键存取；VariableScope 明确持有某流程，读链为 flow→裸键→本书 bookVar。
  流程注册表保留最近 32 条强引用，用 Weak 找回仍在途的同键流程，逐出不撤销在途句柄。
  此上限不等同原 flow 单槽语义；书源切换时仍需核对跨阶段保留策略，不能仅跑合成夹具。
- JsResources 拥有独立变量数据 Arc；TtsSourceStore 显式提供变量能力，DB 适配从 FFI 根取得，
  内存宿主各自持有。裸 cache 跨合成保留；临时 flow 使用 fresh_flow，每次请求独立。
- QuickJsEngine::new_with_variables 将明确句柄注入真实 get/set/remove/clear、put/get/setLocal、
  __lgStore 与书籍变量桥；回调不持有 JsResources/EngineContext/VM 缓存。旧构造沿用原能力，
  两路通过 VariableBinding 共用数据算法，暂不删除未迁移书源仍在使用的全局表与测试锁。
- HTTP TTS 的请求头、URL、响应校验、java.getResponse 重试与 java.initUrl 重算持同一 flow；
  不能在临时执行器重建时丢失变量，也不能把持久 cache 随 flow 一起清空。
- 此子批只接入非缓存 VM 的 HTTP TTS。规则书源、mainJs、书籍绑定覆盖层、封面/调试及
  登录缓存读取尚须成组切换；VM 初始化/每次执行都应消费本次句柄，不固定捕获首请求。
  JS Cookie、网络钩子及全局 Header/目录仍待迁移；不声称整个 TTS 或整个 JS 已实例隔离。

##### R4b2c：缓存执行时的流程绑定

- VM 注册一次宿主变量回调，回调捕获 BoundVariables 而非首次 flow。
  eval/compiled 在该 VM 的上下文锁内绑定传入能力，RAII 在返回/错误/展开退出时恢复；
  不用反复替换函数，脚本此前保存的原生函数引用仍读取本次 flow。
- 普通与显式流程的 eval 共用内部实现，compiled 保留原来的 ctx.eval 选项和错误转换。
  普通/带参数/compiled/字节求值的预算均在获得上下文锁后开始，排队调用不能重置在途预算。
- JsResources 的 for_flow 返回共享同一存储/VM/词法记录的独立视图；不同数据所有者创建独立
  缓存及词法记录。底层 EngineCache 也校验存储身份，不能把同 tag 的外部存储当成缓存命中。
- 初始化脚本使用本次 flow，缓存 VM 常驻能力只保留未绑定书籍的存储；缓存命中时再绑定
  本次 flow，词法/fresh 回退同样使用明确能力。mainJs 的初始化、重评和 compiled 调用接通。
- 字典 URL/showRule 已接入：规则标签与查询词定位 flow，串行/并发不同词不互串；无 QuickJS
  档仍提供实例读者，不伪造执行器。原网络与解析逻辑保持。
- 规则书源的 book overlay、登录缓存和目录/正文入口仍须成组迁移，当前不能关闭总任务。
  新增 VM/原生函数引用、两线程同 VM、错误/展开恢复、mainJs、所有者切换与 Weak 回收回归。

##### R4b2d：书籍流程身份与变量锚点

- 普通命名流程不再隐式充当书籍 URL；book_flow/for_book 使用结构化的来源 URL＋书籍 URL，
  与普通命名流程分开注册。书籍原文取址点保留原样，不改 DB 或外部数据格式。
- 书籍 variable 覆盖由引擎变量存储持有，按来源和书籍分组；type/reverseToc 在流程状态中，
  进入 B 不清除 A。LRU 逐出后在途句柄仍能重入，失去所有强引用后新流程不继承旧会话标志；
  书籍变量仍跨流程保留。此结构不承诺书籍持久覆盖表已实现容量限制。
- book 原生读写、构造期覆盖快照与 parser 读者使用同一能力；显式书籍流程不混读旧裸 bookVar，
  缓存 VM 的已保存回调随每次执行换绑。普通直接执行的裸键桥与未迁移全局入口仍保持原语义。
- 无 QuickJS 的规则/上下文/目录适配器也消费显式读者；目录上下文只保存读取能力，
  不为 @get 引入 VM。未接入显式视图的生产消费者继续使用原读者，不只切换读取一侧。
- 本子批只建立能力和验证适配器；正式书源、登录缓存、书籍绑定及深链正文须成组迁移。
  不能把原生桥/解析器回归记为真实详情→目录→正文或完整 EngineContext 已通过。

##### R4b2e：主书源元信息来源键

- 切换显式书籍变量前，先修正 book 元信息缓存的身份断层：章节反查已携带来源，
  末端 BookMeta 也必须按（来源 URL，bookUrl）查询，不能在此退回 URL 单键。
- 详情写入、目录合并、章节反查、详情绑定及换源 overlay 锚点解析强制传入来源；
  同来源跨 FFI/Web 仍共用引擎缓存，独立来源同 URL 不相互合并元信息。
- 保留 512 个复合条目的容量、满表仅新键触发清空、非空字段合并、DB 变量优先及
  既有缺失回退。稳定书籍主键与目录取址点仍严格分开。
- 增加同引擎同书籍/章节 URL 的双来源回归，并以真实本地 HTTP 正文请求验证
  book.name/author/variable；旧单键代码必须能被此回归拒绝。
- 此项只是正式变量链迁移的前置修复，不代表 book overlay/登录缓存已实例隔离。
  页面 HTML 缓存的请求身份仍须随正式接线核对，不把元信息键的修复泛化到所有缓存。

##### R4b2f：原生登录缓存服务

- SourceLoginCache 由 EngineContext 拥有，保存登录头/用户信息的内存值和绑定的 StorageContext；
  FFI 薄适配与 Web 的 login_header/source setup 消费同一实例，删除 FFI 私有全局表。
  FFI 抓取依赖的登录头和 setup 回调捕获本次服务，不在后续回调中重新查全局根。
- EngineHolder 在开库前可持有服务；首个成功初始化接续同一 Arc，将早期值/删除按原键写回。
  后端只绑定一次；独立上下文不共享状态，服务不回查 FFI 当前根实例，也不反向持有根。
- 内存命中只短取数据锁，不等待 SQL；回填、写入、删除和绑定使用操作门控协调，
  数据锁不跨数据库 I/O。显式删除保留内存记录，持久化失败不能被旧数据库值复活；
  仍沿用可选登录缓存的仅内存降级，不修改外部错误协议或 schema。
- Web 的 infoMap 与登录查询分开短借，不能在持有池连接时再调用登录服务；
  单连接内存上下文的适配测试和真实 Web 请求分别验证，FFI 文件池夹具使用唯一临时文件。
- 本子批迁移原生共享服务，JS 旧变量表及 sync_login_cache_from_js 的读取来源保持，
  避免只迁一侧。下一子批须统一 JS 写入/删除、原生缓存及 setup 回读，不宣称 JS 已隔离。

##### R4b2g：JS 登录能力直连实例服务

- JS crate 定义 SourceLoginStore/Header/Info 窄数据能力，由 engine/SourceLoginCache 实现；
  JS 不反向依赖 engine/db。VM 只捕获数据服务，与可按次切换的 VariableScope 分开。
- FFI 根资源在开库前就注入原生同一服务，EngineContext 装配核对服务身份；缓存 VM、
  fresh/词法回退、mainJs、登录/发现/付费/回调、图片解码和 js_eval 入口共用装配。
  VM 缓存身份同时核对变量存储和登录服务，不能复用其他服务的回调。
- 登录保留原有裸键，对其 get/put/remove 直接访问服务；删除返回值在服务操作门控内
  与删除一起完成，数据锁不跨数据库访问。缺失不回退旧变量表，@get 与非 VM 档读者一致。
- setup 在已注入服务时使用执行时登录值，不把生成时的登录快照写回；未注入服务的独立
  JS 用法仍可使用原预置参数。登录写入即生效，脚本随后抛错不撤销已成功写入。
  删除 sync_login_cache_from_js 及四个事后复制调用，避免 V2 原生命令被旧 JS 值覆盖。
- clearVariables 清变量能力，登录态属于持久缓存，显式 removeLoginHeader/Info 才删除。
  HTTP TTS 使用自己的 BaseSource/登录持久化协议，本批不改该独立协议。
- 新回归覆盖独立引擎、实际 SQL 行、缓存及词法回退、过期 setup/删除、mainJs/按次 flow、
  缓存服务身份和 Weak 释放；两档解析器覆盖登录 @get。真实 FFI/Web 夹具在 quickjs 档
  通过 V1 登录写入、发现动作更新/删除驱动请求，default 档仍通过原生接口驱动。
- 相关命令输出保存在忽略目录 build/engine-context-r4-validation 的 r4b2g-*，结果只在
  Active 登记；本节不维护第二套完成状态。不据此宣称主书源普通变量、Cookie 或任务关闭已完成。

##### R4b2h：正式书源变量流程整体接线

- JsResources 默认持有本实例的未绑定书籍能力，生产解析器/执行器不回退全局变量表。
  来源流程以用途、来源、查询/分类为结构化身份；书籍流程按来源及逻辑书籍身份注册。
- 抓取器在搜索、详情、目录及正文入口取得不可变依赖视图，HTTP 等待、URL规则、header、
  loginCheck、正文分页及 mainJs 消费同次资源；创建另一流程不修改既有在途句柄。
- 详情/目录/正文绑定构造及 book overlay 写回使用相同书籍能力；深链缺少关系时按来源/章节
  创建独立流程，不读前一本书。已知目录只依据已观察的唯一详情关系恢复书籍，不以目录URL猜测。
- 稳定书籍身份与实际详情取址点分开：显式绑定的同来源书籍能力不被请求URL覆盖，
  preUpdate 与刷新使用稳定主键；详情结果的URL字段维持既有协议，元信息及变量绑定用逻辑锚点。
- FFI 搜索 URL 与响应解析共用查询流程；发现 URL/mainJs/列表元素共用分类流程。
  登录/付费/回调入口使用来源能力；字典用结构化规则/查询身份，自动任务使用独立临时句柄，
  MCP诊断从所属 Server 引擎注入资源。移除生产 begin_book_flow，不保留空转发壳。
- 短期页面缓存按来源、URL及来源请求头分区，避免同引擎同URL跨源复用响应；
  容量/TTL保持，尚未把所有自动jar状态加入缓存键，不据此声称完整请求缓存现代化。
- 旧流程测试改为断言显式书籍能力；新真实HTTP/mainJs链覆盖交错书籍、同URL不同源、
  深链、稳定主键/取址点差异及独立根，真实目录缓存回归覆盖来源/请求头变化和重复命中。
  Windows非阻塞监听夹具在accept后显式恢复流的阻塞模式，避免WouldBlock偶发失败。
- engine测试复用已锁定serde_json（仅新增dev依赖边）；不更新任何外部包版本。
  结果只登记Active，不以此替代JS Cookie/网络钩子、任务关闭及剩余全局状态迁移。

##### R4b2i：发现参数共享服务

- SourceInfoMap 拥有来源参数的内存表、操作门控及单一存储后端，FFI 只做转发。
  Web 和 FFI 的 setup 回调捕获同一数据服务，不分别读取私有内存表和数据库。
- put/ensure_default 的回填、读改写及落库保持同一操作顺序；状态锁不跨 SQL。
  开库前写入按键合并到已打开的库，早期空读取不阻止数据库回填；持久化失败保留内存值。
- 保留 infoMap_<sourceUrl> JSON、发现控件、JS 代理与事后逐键回写语义。
  并发旧脚本整图回写的合并策略不在本批擅自改变，不把服务实例化当作代理原生化。
- 新服务使用已有 serde_json，外部依赖版本不变。验证结果统一登记 Active。

##### R4c：Cookie 写通道与网络能力成组迁移

- 先以 core 的 KeyedWriteCoordinator 统一同步算法：屏障、排序去重域锁、弱索引，
  不返回伪造的静态守卫，不用 Arc::into_raw 永久保留每次取锁的引用。
- HTTP 响应写回、JS 写/清、FFI 删除、数据库接续/回填及 Web 删除同时换用闭包 API，
  此步骤保持原保护域，不在切换一半时让 JS/HTTP 分属不同协调器。
- 再与 JS Cookie/网络能力一起迁移协调器的资源归属；独立引擎各持一份，
  同引擎 VM、四组客户端和原生入口共用同一 Cookie 存储及写通道。
- 闭包内不得再次取得同一协调器或等待异步工作；客户端构造/回填在域操作之前完成。
  默认 JS 档复用 core 纯同步能力，不引入网络或 QuickJS 特征。
- 除底层并发与释放测试，还要复验已有同域写/删/全清/回填和真实跨宿主请求链；
  算法测试不能代替最终实例接线或原生运行证明。

##### R4c2：主要 JS 网络入口的实例注入

- HttpResources 保存四池、来源头和远程 jsLib 内存缓存；CookieAccess 只提供数据操作。
  EngineContext 注入同一 NetworkContext 的 jar/持久化能力；独立 VM 默认自有内存资源。
- HTTP、ajax/connect 及批量请求在同步入口建立 RequestResources，不在异步执行中读取当前来源。
  保留 URL/超时/代理/重定向/返回协议及各方法原来的头合并范围，不顺便扩充接口行为。
- VM 直接消费规范 Cookie 罐，保留 set/replace 的空值差异、按键合并和失败时内存生效；
  首次网络前即可读取已存 Cookie。缓存 VM 校验网络身份，早期资源在建库后接续。
- WebView 三种桥接载荷显式消费所属 VM 的 Cookie，字段和来源键不变，空 URL 不携带；
  不通过旧 JS 镜像间接回填，也不以载荷验证代替真正 WebView/设备运行。
- TTS 的临时 VM、重试及响应脚本沿用存储能力提供的网络资源，不在每次 eval 时换成新罐。
  本批只捕获 TTS 的变量/网络资源，其 DB/登录回调的全局发现另由 R6 收口。
- URL 映射 jsLib 的下载和 64 项缓存使用所属 HttpResources，保留旧键/TTL/失败规则。
  默认下载器必须显式取得能力，删除全局 jsLib 内存缓存，不以新客户端配旧缓存代替隔离。
- 文件、字体、压缩档案及旧工具池/测试注册槽仍需成组迁移和删除；
  域协调器仍在前一步共同保护域，不能据本批声称全部 JS 状态或写通道已经实例化。

##### R4c3：间接下载、字体与自动文件缓存的实例归属

- 文件下载、cacheFile/importScript、字体、ZIP/7z/RAR 及 ajaxTestAll 的同步回调显式借用本 HttpResources；
  不引入新来源 Header/写回门控。删除无调用方的 misc.connect 副本，保留正式 network.connect_full。
- FontResources 持有句柄表、容量 4 的解析 LRU 与私有磁盘缓存；自动 URL 文件缓存同样按资源隔离，
  同 URL 的并发加载由实例 keyed coordinator 串行协调，临时文件完整写入后再发布，失败清理临时文件。临时目录在最后一个持有资源的 VM/宿主释放后清理。
  fontId、JS 参数、显式文件路径与沙箱规则保持；旧临时缓存不再复用，不声明跨进程持久缓存兼容。
- 二进制 ZIP 实际请求暴露旧 get_bytes 的文本中转损坏，受影响入口使用既有 get_raw 保留字节；
  实际 ZIP、非 UTF-8 文件、双 VM 不同 Cookie 的字体替换与自动文件读取均有回归。
- 抓取正文、各分页请求头及正文 WebView 载荷只读本次注入客户端的 jar；最小 FetcherDeps 构造的 JS
  内存能力与该客户端共罐，正式宿主继续注入完整持久化服务，不回查宿主全局。
- 删除进程四池及 CookieStore/持久化/来源开关 first-wins 注册，删除无消费者的 global_headers；
  网络协议夹具独立装配，保留四池复用、真实 keep-alive、冷启动、403 跨池重种与来源三态断言。
  WebView 回流已同步更新共享 jar，不再拆除连接池。
- 尚待成组迁移：旧 JS Cookie 镜像/sink、发现直发和音频缓存两处镜像读取、FFI 清除适配，
  Cookie 写协调器所有权；旧测试镜像需由实例真实链路替换，之后删除对应全局测试锁。
  本子批不等于 R4 或整个第四阶段完成，R5/R6 的监督关闭与任务资源捕获仍继续。

##### R4c4：权威 Cookie 罐与写通道所有权

- 移除 GLOBAL_COOKIES、CookieSink、开库注册/回填、清除镜像钩子、默认档额外域协调器；
  CookieAccess 是两档均可消费的数据能力，正式宿主由同一 NetworkContext 实现。
- 发现页直发、音频缓存与全部正文/WebView 读者消费已捕获客户端的 jar；
  域/裸键解释及原始键覆盖由 net 的纯函数统一。FFI 清除委托所属网络实例，保留先清内存、
  后 SQL 及失败上抛；JS 清除仍吞持久化错误并保留已生效的内存修改。
- CookieStore 持有 Arc 写协调器；共享罐的 HTTP 响应写回、JS、预载、绑定和删除使用同一保护域。
  获取协调器的短读锁先释放，再进入域/全量门控；全清只清内容。深拷贝罐建立独立写通道，
  外层 Arc 克隆和客户端派生保留原通道。不新增进程注册表，也不扩展 Tokio 池或线程优先级。
- 删除仅为旧 sink 设立的 test-support feature、自依赖与旧镜像测试文件；
  原语义由实例真实数据库/VM/HTTP 回归替代，不保留兼容模式或为测试重造镜像。
  仍使用 FFI 根资源的测试继续串行；实例测试直接独立装配，保留并发/持久化失败/释放验证。
- 独立库/同域/裸键/原始键覆盖、批量及不变值写入次数、内存优先预载、清除后不复活、
  DB 故障的内存与错误边界、同罐互斥/跨罐不互斥、资源释放均须验证；真实 JS 绑定/FFI/Web
  的接线证据保留。移除旧算法后不把测试数量的增减作为覆盖率或性能改善证据。
- 本批不引入持久化失败 tombstone：失败的删除明确返回失败，之后显式预载仍可能读取未删 DB 行，
  不宣称持久清除成功。监督关闭、任务存储/会话捕获及其余宿主全局状态仍由 R5/R6 继续。

### R5：业务任务作用域与关闭协议

- 路径：engine/tasks、ffi 搜索/下载/校验/调试/TTS/缓存任务、Server 会话及服务管理器。
- 保留现有搜索 session token、下载标识和事件协议，将资源归属从进程迁为引擎和宿主。
- 每个操作有子取消作用域；不把“停止某次朗读”升级成取消整引擎。
- 登记并等待在途工作，所有异步回写捕获原 storage/会话；结束后不读取新全局句柄继续写。
- 先实现监督关闭，再决定能否减少 runtime 数量；不同时引入新的线程优先级或并发上限。
- 出口：停止不再产生事件/文件/DB 迟到写；服务端口释放；关闭幂等；关闭超时不误报；
  外部 runtime 不销毁，旧实例可回收，新实例不承接旧取消状态。
- 回滚：保留既有 UI/FFI 可见任务协议，按任务组整体回退生命周期接线。

##### R5a：任务作用域基础与装配（先旁路，不冒充生产任务完成迁移）

- TaskGroup 根/子组及 TaskHandle 独立取消位、短同步发布门控、克隆凭据寿命与在途登记。
  同组取消禁止新登记并阻止后续发布，父/兄弟/其他引擎不被子组取消；计数只随最后凭据释放减少。
- 同步 cancel 等待已进入的发布段退出；发布段不得重入取消/关闭或跨 await。
  异步 shutdown 只请求取消，再用 Notify 等登记释放，不同步卡住 worker 等发布锁；
  超时保留在途记录并返回 false。CPU/阻塞任务不强杀，派发时须保留 TaskHandle 克隆。
- 注册表只存任务弱引用；快照后在登记锁外升级/释放，避免最后一份强引用析构再次取登记锁。
  取消标志可供旧轮询逻辑读取，写侧必须经 cancel 通知，不能自行置位而漏唤醒等待者。
- EngineContext 装配任务组，析构只请求取消，不销毁外部 runtime。EngineHolder 在开库前后接续同一组，
  所有可失败装配结束后才注入早期任务组，避免初始化失败误取消已有工作。
- 任务组基础回归涵盖取消范围、克隆寿命、超时不伪成功、同步发布收口、异步关闭不阻塞、
  等待唤醒、并发登记/释放/快照、根释放；失败开库和重复开库通过宿主装配测试补证。
- 本子批尚未把旧 search/download/check/debug/server/TTS 等任务登记到此能力；
  下一批按任务组迁移状态持有者、事件发布和数据依赖捕获，再验证正式任务关闭。

##### R5b 优先接线范围：搜索会话

- 将 CURRENT_SEARCH_SESSION 的状态所有权从进程静态移为引擎/宿主实例；SearchSession 保留现有
  session_id、取消/暂停轮询语义，以 TaskHandle 登记在途工作，不另建全局取消旗标。
- 新会话替换旧会话时，先在短槽位锁内替换，再在锁外取消旧凭据，避免发布回调与会话锁形成锁环。
  异步中的 is_current/clear_if_same 使用会话捕获的原所有者，不重新从 FFI 根发现另一个会话。
- spawn_blocking/逐源子任务必须保留凭据克隆；停止前后的事件和持久化提交消费同一短发布门控，
  不能只在 await 前检查一次标志，或结束外层 future 后就把未结束的阻塞任务当成结束。
- 保留 cancel/pause/resume 和搜索流 JSON 契约；先覆盖 A 被 B 取代、旧 A 清理不能清 B、暂停/恢复、
  sink 关闭、阻塞工作取消、原实例数据写回与任务关闭，再迁移下载/校验/调试/Server 各组。

##### R5b 资源与锁序细化

- SearchTasks 归属宿主，根 TaskGroup 在开库前后接续；槽位保存弱会话，操作只持任务与数据能力。
  替换者先放入新槽位、释放槽位锁，再等待旧发布退出；析构只通知，不等待发布锁，不取消兄弟工作。
- SearchContext 在入口固定 StorageContext、JS、登录/infoMap、限流与客户端；正式逐源/阻塞阶段不重新发现根。
  详情回退复用同一次 FetcherDeps；计时编号从操作传递，不能读取另一个搜索的当前编号。
- URL、登录校验、正文解析和 mainJs 工作保留凭据；收集器被丢弃时 AbortSources 自动中止派发的异步源。
  阻塞任务仍按真实寿命登记，TaskGroup 关闭超时保留在途状态。取消不强杀已经执行的 JS/CPU；
  本批收口的是搜索结果、事件和 searchBooks 提交，其他 JS 副作用及下载任务在对应后续组继续处理。
- 收集与持久化/事件使用短同步发布门控；sink 错误在退出门控后取消，不能重入同一发布锁。
  暂停保持旧软暂停语义，取消通过任务通知唤醒；空源、异常和外部丢弃均释放原槽位。
- 全量复验发现旧测试库只按 PID 命名，Windows 重用进程号后会打开四天前的测试库；
  R6 中的这项测试隔离修复前置：每轮独占创建新测试文件，现有串行锁和生产 DB 访问不改。

##### R5c 下一组边界：真实章节缓存下载与旧队列管理

- 入口盘点：cache_download_api 的 NEXT_TASK_ID/TASKS/RESTORED、快照索引及恢复线程；
  download_api 的 DOWNLOAD_MANAGER 是另一套队列状态，不能把它误作当前章节缓存 worker。
- 恢复/创建/查询/取消捕获同一实例服务和原 StorageContext，保留任务 ID、0-based 闭区间、
  失败章节、持久快照字段与重启续传语义；恢复和任务索引读改写不能只靠先置位的全局 AtomicBool。
- worker 必须持真实任务凭据到线程退出；任务表可保存状态，不得永久强持凭据导致终态永远在途。
  服务/任务回调不捕获根 EngineContext，状态表与执行能力分离，关闭拒绝新任务，超时保留记录。
- 必须一起追踪 download_one → reader::get_chapter_content_full / cache_api::save_chapter_content：
  在线正文路径自身就会写缓存，仅在外层 persist_snapshot 前检查取消不足以拒绝迟到正文。
  抓取、正文缓存提交和进度快照须共同捕获原实例；短提交门控不跨网络、JS 或 await。
- 原取消终态及断点快照的保存属于控制面，需与业务正文写入区分并明确取消/关闭顺序，
  不把停止后的任意写入都放开，也不因取消位已置而丢失既有 cancelled 状态或续传断点。
- 先覆盖本地/在线实际下载、两实例同 ID 隔离、并发恢复/创建、取消后无迟到正文、
  线程启动失败、持久化失败、真实未结束 worker 关闭超时，再切下一组校验/调试/服务任务。

##### R5c 资源、提交与终态顺序细化

- CacheDownloads 的状态表只弱持 worker 凭据；创建/恢复装配串行，抓取不持装配/SQL/发布锁。
  持久化快照、索引与 nextId 在 BEGIN IMMEDIATE 事务内更新，恢复失败不消耗一次性标志。
  主体线程包含 panic 收尾，线程启动失败落 failed 并释放登记；查询不以终态记录保活 worker。
- 正文原文算法提取为 ChapterContent，前台网络正文登记根任务并继续净化，后台直接消费原文。
  缓存命中/本地书不创建网络客户端；FetcherDeps 工厂只持固定数据能力，缺缓存时才取所属客户端。
  本地相对书籍路径按原存储文件的父目录解析，不使用后台线程的宿主根查询。
- 缓存正文、命中字数自愈、网络字数回填与媒体副内容共用本次短发布门控；
  取消先通知并排空已进入的发布，再写 cancelled 控制面快照，不推进未确认的章节。
  收尾完成前凭据不释放；重复取消不重写终态或重建已清理的 KV，取消后的 panic 不覆盖 cancelled。
- 取消不强杀正在执行的网络/JS/本地解析；当前章节完成后进入取消收尾，其后正文/媒体提交被拒绝。
  shutdown 超时真实保留在途登记，显式等待成功后不再有该 worker 的正文/快照写入。
  其他 JS 内部副作用与其余入口仍按 R5/R6 边界继续迁移，不扩张本组完成口径。
- 文件库存储维持相邻 ruleData；内存库使用各自独占的临时数据根，StorageContext 克隆共享目录寿命，
  最后能力释放时只删除自己创建的临时目录；从不删除文件库或宿主显式目录。
  文件库父目录作为既有数据容器；同父目录或显式同目录按现有盘位置共享，不承诺自动按 DB 文件名隔离。
  显式目录在装配点固定，后台线程不再读取其他线程/后续覆盖；前台原规则数据入口仍保留覆盖优先级。
- 旧 DownloadManager 仅是 FFI 宿主的队列模型，本组迁移其实例所有权，不与真正的章节 worker 合并；
  Web 宿主队列和服务任务的监督/装配仍由下一组服务边界处理，不能据此宣称双宿主队列已经统一。
- engine 新增 serde、rusqlite 两条直接依赖，复用已锁定的工作区依赖；外部包版本不升级。

##### R5d 校验与调试操作的归属和收尾方法

- OperationSlot 为校验与调试提供各自独立的弱引用槽位，任务凭据归属宿主根组。
  替换先在短锁内发布新槽，再在锁外取消旧操作；旧操作结束按身份清理，不清空新槽。
  操作只持任务能力与弱所有者，OperationGuard 在入口被丢弃时只通知取消和清理自身。
- 校验删除 CHECK_CANCELLED；单源也登记根任务，批量仍按原顺序串行检查。
  书源从固定 StorageContext 加载，保留禁用源、缺失源占位和错误降级，网络使用固定 NetworkContext。
  取消可终止等待中的异步校验；结果发布在短门控内，sink 错误在门控外取消。
  复核确认原 FFI 校验没有书源状态回写，不为本次迁移增加新的写入功能。
- 调试删除 DEBUG_CANCELLED、SESSION_ID、SESSION 与 EMITTER，DebugRun 固定原存储/依赖/日志回调/时间起点。
  五种关键字分流、阶段顺序、状态码和日志格式保持；详情/目录/正文/搜索不再重入宿主根装配。
  发现分支共用显式依赖入口，规则源与 mainJs 均使用原 JS/客户端/登录/infoMap 能力。
  媒体副内容发布使用原任务门控；原生内部章节补齐必填 is_vip=false，修复原调试正文提前报错。
- spawn_blocking 调试持有自己的原会话直到真实退出；入口丢弃、替换或根析构不等于阻塞工作已经结束。
  有界 shutdown 对迟到网络任务返回超时，直到真实 worker 退出；不强持根，不强杀网络或 JS。
  原 VM java.log 只写 stderr，调用链未注册调试 emitter；不新增注册槽，也不借机增加 UI 日志能力。
- 回归使用真实 localhost HTTP/JS/数据库/媒体大文件状态、回调结果与任务寿命，
  不读取生产源码做字符串守卫；移除旧流式共享取消锁，仍操作 FFI 根的其他测试锁保持。
- 后续独立精搜/换源控制、服务停止/端口释放、音频/TTS 及剩余任务入口继续逐组迁移。
  通用操作槽与原搜索软暂停控制器的去重在真实消费者收口后评估，不提前合并业务协议。

##### R5e1 独立搜索入口的任务与数据边界

- SearchContext 将业务任务凭据与 UI 搜索槽位区分：多源入口仍使用 SearchSession，
  独立单源和精搜只使用根任务组中的独立 TaskHandle，不替换 UI 的搜索/软暂停状态。
- TaskGuard 只拥有入口的取消责任；入口被丢弃或提前返回时仅通知取消，不同步等待阻塞闭包。
  URL 构建、登录检查、正文解析与 mainJs 分别持有该任务凭据，直到真实计算/网络回调退出。
  该凭据不持 EngineContext，根析构后旧 worker 仍受原任务组登记，不因外层 future 结束而提前注销。
- 精搜固定存储的启用源列表和一套执行依赖，逐源顺序、名称作者完全匹配、首个命中即停与
  既有 JSON/普通失败文案不变；不新增 searchBooks 写入，不重建全局 flow 兼容层。
  根取消优先结束等待，不能把取消当作某个来源失败而继续后续源或伪装正常未命中。
- 启用源加载从原存储能力查询，保留 customOrder、空串/空数组全部启用与指定 URL 过滤规则；
  解析错误仍先返回原 FFI 错误，不因未开库替换为另一个错误。
- 行为用例通过真实 localhost HTTP 阻塞四类阶段、观察任务数量和根 Weak 释放，
  并核对精搜来源请求顺序/命中/作者/未落库及 UI 搜索互不取消；不使用源码文本守卫。

##### R5e2 换源缓存、增强与提交的下一组边界

- 迁移前 SWITCH_PREFETCH_CACHE 与 SWITCH_APPLY_EPOCH 位于旧模块；只监督单源搜索不足以完成整条换源迁移。
  缓存归属实例并保留每次搜索开始清空、30000 总章数守卫、详情-only/完整/部分命中规则。
- 搜索/增强须固定原存储与任务，候选提交、缓存写入和流事件共用有效会话门控。
  sink 关闭或父流丢弃后不继续增强或落库；不能只包装单源后仍让旧增强写入新缓存。
- apply 取消须与事务提交形成短同步门控，取消返回后不能新进入旧书源提交。
  取消同时作用于原 WebBookState 的 TOC 代数；固定变量回读、媒体回写和下一章登记能力。
  新会话替换/取消在槽锁外排空旧发布，保留稳定 bookUrl、字段合并和失败事务回滚。
- 后续还需服务关闭/端口、音频/TTS 与 R6；本子批不删除仍操作宿主根状态的测试锁。

##### 剩余服务与宿主数据的实现边界

- ServiceHost 拥有 Web/MCP 两个监听槽及共享 ServerServices；runtime 仍在宿主。
  每次启动使用独立子组，stop 等待端口释放，对请求/阻塞工作有界等待，超时保留真实登记。
- AppState 注入作用域和共享会话服务；下载队列与 EngineContext 共用同一模型。
  目录批次、书源检查子任务与升级后的 WebSocket 单独登记，旧任务不能清除新服务状态。
- MediaState 保存注入路径、下载取消状态及独立云请求客户端；HTTP TTS 来源存储捕获 storage/JS/login/rate。
  取消关闭只禁止后续发布，不宣称强杀同步 JS；真实返回前仍持有登记。
- JsHostResources 持缓存、配置、设备身份及并发原语；VM 只克隆数据能力，不持根实例或 VM LRU。
  正式 FFI 保留既有缺省缓存目录；独立 JS 资源使用自身可回收目录，显式注入目录不自动删除。
- UI 动作只归属本次同步 JS 求值作用域，异常/panic 恢复外层；发现页、书源回调和 TTS 不再共用进程队列或刷新标志。
- CustomHosts 的解析/查表只有一份实现。正式网络、JS、订阅、WebDAV 和云请求捕获所属映射；
  面向独立工具的低层默认适配不属于正式引擎资源，不能用于证明两个引擎共享状态。
- 进程共享的纯正则、诊断计数/告警、runtime、同路径文件互斥与原子命名序号不属于业务实例槽，按用途保留。
  操作 FFI 根/独立工具默认适配的测试继续持对应锁，不能把所有测试锁批量删除。

### R6：薄化宿主、清理过渡与集成验证

- 用窄能力替换已迁移编排内的 db_state/http_state 全局查询；纯函数不接万能 Context。
- 所有实际消费者迁走后删除过渡函数/重复实现，不保留永久 legacy 模式。
- 测试按实例独立装配；仅在不再访问全局状态后删除对应测试锁，不能整文件删 test_support。
- 核对默认及 quickjs feature 透传，禁止新增 engine 使 armv7 无意启用 quickjs。
- 更新模块地图/双轨文档和 Active，只记录实际完成范围；API_CONTRACT 仅登记实际受影响语义。
- 运行相关 Rust 门禁与真实 native 链路；应用 UI 重构合流后再做跨轨集成。
- 出口：能力/状态归属与代码一致；目标模块无重复资源所有者；行为回归、资源释放与构建证据齐全。

依赖顺序为 `R0 → R1 → R2 → R3 → R4 → R5 → R6`。
R0 的测量样例、纯函数检查可独立准备；同一 Cookie/JS 装配链不拆成并行写入任务。

## 7. 与 Flutter 重构并行的边界

可以并行，但“文件零重叠、两轨完全独立”是过度承诺。

| 范围 | Rust 轨 | Flutter 轨 | 合流规则 |
|---|---|---|---|
| Rust crate 及内部测试 | 本任务拥有 | 不改 | 默认/quickjs 门禁 |
| Flutter screens/features/providers | 不改 | 页面与状态职责拆分 | 调用既有 Repository/FRB |
| FFI 导出、JSON、错误与事件 | 保持 | 保持 | 需变化时另开跨轨契约批次 |
| API_CONTRACT/Active/模块地图 | 只改自身段落 | 只改自身段落 | 合流时按段落合并，不整文件覆盖 |
| native 产物与指纹 | Rust 轨重建并校验 | 不复用失配的旧库 | 分平台构建，不能用旧库“测试新 Rust” |
| baseline 更新 | 先确认其他工作树状态 | 独立继续 | 不擅自 rebase/合并对方未提交工作 |

不需变更 FRB 导出时不为了目录整理强行重新生成绑定；最终核对生成输入和产物一致性。
即使绑定 hash 没变，Python 源码指纹门禁也要求重建 native。
Android 模拟器/Windows 可测项与 iOS macOS 环境项分别报告，不把 Windows 的 cargo test 当成 iOS 构建证明。

## 8. 必须覆盖的行为回归

| 编号 | 行为 | 必须证明 |
|---|---|---|
| E01 | 两个独立库/Context 交错读写 | 数据和路径不串，临时文件唯一 |
| E02 | 构造失败、并发/重复 db_open | 不发布半初始化状态，不改现有重复调用语义 |
| E03 | 同 Context Web/MCP/FFI | 共用 DB 与 limiter，启动不长期占连接 |
| E04 | 异步 DB 高竞争、current_thread | 不因互斥失败变成 None/空数据；错误明确 |
| E05 | 跨宿主限流与保存刷新 | 同源共用窗口，失败保存不刷新，独立引擎不共享窗口 |
| E06 | Cookie 双向更新与重建 | FFI/JS/Server 立即互见，早期内存值保留 |
| E07 | Cookie 合并/删除/全清并发 | 不丢并集，不复活，无锁顺序死锁 |
| E08 | 同 key 不同引擎的 JS/缓存 | 不串变量、登录态、目录及 body/book meta |
| E09 | 同引擎多个书籍 flow 交错 | 切另一本书不清仍运行会话的数据 |
| E10 | 任务取消与配置更新 | 操作互不误取消，旧请求仅写原所属存储 |
| E11 | 关闭与端口重启 | listener 真释放、在途工作有明确结局、关闭幂等 |
| E12 | 独立 server 构造/释放 | 不依赖先初始化 FFI，也不回调 FFI 全局状态 |
| E13 | 实例释放 | Weak/资源计数等行为证明无强引用环，不能只搜索源码判断 |
| E14 | FFI 既有查询/任务/备份协议 | 参数、错误、事件序和恢复行为不变 |
| E15 | default/quickjs/native | feature 不倒灌；Windows/Android/iOS 分别按环境报告真实结果 |

使用标准库/仓库已有测试设施和 localhost HTTP fixture；不把外网站点波动当成必需门禁。
不以 grep 字符串断言代替行为测试；源码检索只用于迁移覆盖审查。
不添加复杂 UI 验收矩阵，不因 Rust 内部重构要求逐屏截图。

### 验证命令与成本控制

以下均为未来实施时的命令，当前未执行；在 worktree 的 `rust/` 中运行。
每批先运行所改模块的测试过滤器，失败即修复，不重复跑所有平台 CI。

```powershell
cargo test --locked -p legado-engine
cargo test --locked -p legado-server
cargo test --locked -p legado-ffi
cargo test --locked -p legado-engine -p legado-server -p legado-ffi --features quickjs
```

涉及 JS/fetcher 的批次再增加其受影响测试。集成批次对齐当前 Rust CI：

```powershell
cargo fmt --all -- --check
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo clippy --locked -p legado-engine -p legado-js -p legado-ffi -p legado-server --features quickjs --all-targets -- -D warnings
cargo test --locked --workspace
cargo test --locked -p legado-js -p legado-ffi -p legado-server --features quickjs
```

engine 的 quickjs feature 随实现建立，未建立前不能把上述未来命令记为通过。
新增 workspace 成员需要正常更新 Cargo.lock；更新后使用 --locked，不借机升级依赖。
用户授权运行 CI 时优先 Rust/必要集成范围，不全跑 Flutter、APK、IPA 工作流。

native 回归从 worktree 根目录使用已有 Python 入口，按环境选择，不一次全平台执行：

```powershell
python scripts/dev.py build ffi windows --profile debug
python scripts/dev.py build ffi android --profile debug --abis x86_64
python scripts/dev.py verify ffi android --profile debug --abis x86_64
```

iOS 只在 macOS/Xcode 环境运行对应 device/simulator 入口。
任何未运行项均保留“未验证”，不能以计划中的命令或旧构建成功替代。

### 性能与资源口径

- 先记录基线，再用同数据、同配置、同构建档对比；编译、测试执行和服务操作耗时分别记录。
- 优先观察 Server 稳态占用连接数、HTTP 客户端创建次数、并发响应 p50/p95、关闭完成时间。
- 内存比较注明 OS 指标/RSS 或私有字节、采样点和重复次数；Arc/对象数仅是资源归属证据，不冒充内存实测。
- 无可用平台或测试数据时不承诺百分比收益；本任务首先解决一致性、隔离和生命周期。

## 9. 风险、回滚与交付标准

| 风险 | 防护 | 不可接受的捷径 |
|---|---|---|
| Context 变成新上帝对象 | 私有字段、窄能力、应用入口持有；纯算法不依赖它 | 每个函数都加 ctx 参数但仍读全局 |
| 单连接测试重新死锁 | 连接短借、网络/JS 前释放；竞争用文件池 | 统一把内存池 max_size 改大 |
| Cookie 锁与删除竞态 | 一个服务、一套保护域，保留宽容失败 | 为减少锁直接删除历史门禁 |
| 运行时嵌套/drop/panic | 监督者 owns runtime，异步任务只借 Handle | Context 随处 drop Arc<Runtime> |
| 快速初始化或迟到写 | 原实例快照、门控、失败不发布 | 每次写回重新查 GLOBAL_ENGINE |
| JS 隔离只完成一半 | 显式宿主资源、flow 会话、first-wins 消除 | 仅把 GLOBAL_VARIABLES 外包一层 Context |
| native 误用旧产物 | 重建、严格指纹与 ABI/profile/features 校验 | 跳过 Gradle/Python 校验 |
| 并行分支公共文档冲突 | 仅改本任务段落；合流复核语义 | 用一个 worktree 的整份文档覆盖另一个 |

各批的回滚单位是完整资源接线；保留已提交基线，不重写历史。
本任务不做 schema 变更或磁盘格式迁移，因此不需要数据降级脚本。
回退 Rust 后仍应重建匹配的 native 产物，不能继续混用新旧库。

最终交付逐批记录：文件范围、外部行为差异、运行命令/结果、真实环境边界及未测项。
只有共享资源、独立实例、任务关闭和实际构建分别有证据时，才称完整 EngineContext 收敛。
完成 R1/R2 仅能称数据库/限流批次完成，不能提前宣称全局状态消失或支持任意多宿主热重启。

编写者：Codex｜2026-10-16
