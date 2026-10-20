# Rust 实践审查（2026-10-20）

本次由 Codex 单代理执行。先将 chore/dep-audit 的对称加密/RSA两个提交合入主目录，
合并提交为 `0f13ea76d`，主分支为 `feature/ui-reader-selection`。
后续并行发生的阅读器 UI 提交不属于本次 Rust 审查或合并成果。

审查范围：11个workspace crate的配置、依赖方向，以及Engine/DB/JS/网络/本地书/FFI/Server的关键实现路径。
方法为静态调用链核查、严格Clippy和小型真实行为探针；不是所有Rust文件的逐行审计，
也不是安全审计、Miri验证、设备性能测试或跨平台验收。未修改生产Rust代码。
任务与后续修复状态只在 REFACTORING_ACTIVE_PLAN.md 维护，本报告保存证据与建议。

## 结论

当前结构已经具备比较合理的Rust基础：Edition 2024、明确的实例资源归属、RAII、类型化FFI、
有界任务调度，以及默认/QuickJS双档门禁。不能再用早期“到处是全局数据库与JSON透传”概括现状。
但通过lint不等于异常路径和资源预算正确；数据库静默吞错与REST遗留实现仍有具体缺陷。
不建议启动全面架构重写，先处理下面的错误传播和边界问题。

## 已确认问题与建议

### R1：列表查询静默丢弃行解析错误（P1）

- 落点：`rust/legado-db/src/repository/book_repository.rs:178`、`:573`；
  同类写法分布在章节、书签、书源、阅读记录等Repository。
- `query_map`后的`filter_map(|r| r.ok())`将驱动/类型转换失败直接过滤，最后返回`Ok(Vec)`。
  上层无法区分“没有记录”和“本应存在的记录读取失败”，也可能把不完整列表当成完整快照。
- 修复方向：普通查询收集`Result<Vec<_>, _>`并带查询上下文传播；需要容错导入的流程应显式返回失败项，
  不能把同样的容错策略默默用于正常查询。先修书架/章节主路径，再按真实行为逐域扩展。
- 验收：真实内存SQLite中构造一行类型不匹配，单条/列表查询均返回失败，连接仍可继续使用；
  正常空表仍返回空集合。不建立历史数据库迁移或旧字段修补任务。

### R2：保存书籍时将读取失败当成不存在（P1）

- 落点：`rust/legado-engine/src/bookshelf_service/mod.rs:143`。
- `let Ok(Some(existing)) = repo.find_by_url(...) else { return Ok(()) }`把`Err`与`Ok(None)`合并。
  该函数本意是保留换源后的origin/toc等字段；读取失败后继续`repo.update`，反而允许陈旧对象覆盖当前来源。
- 修复方向：先`?`传播读取错误，仅对真正的`None`走新建分支；同一“读取合并再写”操作进一步核对事务范围，
  避免并发更新期间读写之间被插入换源。不以增加全局锁替代数据库事务。
- 验收：读取错误时保存失败且原行未变；正常新建、更新和保留换源字段继续成功。

### R3：Web音频端点低语速发生整数除零（P1）

- 落点：`rust/legado-server/src/handlers/audio.rs:167`至`:169`；
  实际路由为`POST /api/audio/speak`。
- 时长公式先把`speed_factor.max(0.1)`转换为`i64`，`0.5`等有效低速变成0，随后除零panic；
  `1.5`也会截断为1，时长估算失真。请求已经成功完成HTTP响应后仍会触发。
- 修复方向：校验有限且允许的语速范围，以浮点完成除法，最后显式处理舍入与整数范围；
  无效输入返回可识别的请求错误。修复实际handler，不只测试复制出来的算式。
- 验收：真实Router配回环音频服务，覆盖0.5、1、1.5、缺省与非法范围，不panic且时长单调合理。
  该问题影响Web REST路径，不能据此宣称Flutter正式朗读链路同样崩溃。

### R4：部分REST TTS仍绕过统一引擎网络资源（P2）

- 落点：`rust/legado-server/src/handlers/audio.rs:149`及`:159`；
  `rust/legado-server/src/handlers/tts.rs:70`；`rust/legado-net/src/tls.rs:26`。
- 两个`speak`入口忽略AppState、自行创建默认reqwest客户端，重复字符串模板实现；
  不消费Engine配置的代理/自定义Hosts/UA/共享Cookie及书源规则，且没有显式业务总期限。
  这与已具备TtsResources/TtsService的正式按ID合成路径并不一致。
- 响应也未先校验状态，文本错误体可能被当作`audio_url`成功返回；每次重新创建Client失去连接池复用。
- 修复方向：先明确URL直连便利接口与按源ID规则接口的契约，保留入口形态，
  共用相应引擎网络能力、错误校验和取消/期限；不把任意URL强行解释成数据库TTS源。
- 验收：真实回环服务验证404/500不是成功音频、实例网络配置生效、取消与读取期限有效。
  暂未实测代理失配或悬挂请求；以上配置旁路由调用链确认，不能量化为已测网络性能下降。

### R5：压缩包读取没有显式资源预算（P1风险，未做OOM实测）

- 落点：`rust/legado-book/src/cbz.rs:124`和`rust/legado-book/src/archive.rs:92`。
- CBZ直接以档案声明的解压后大小`Vec::with_capacity(entry.size() as usize)`预分配；
  ZIP导入以无界`read_to_end`读取每个书籍条目。当前代码未给单条目、总解压量、条目数建立应用层预算。
- `Result<Vec<u8>>`不能使分配失败自动变成可恢复错误；压缩炸弹/畸形长度与合法超大文件需分开处理。
  此处没有实测耗尽内存，不宣称存在已利用的漏洞或测得具体内存增幅。
- 修复方向：基于产品支持范围制定预算，检查元数据并对实际输出使用有上限的读取，
  配合`try_reserve`和显式错误；ZIP落盘导入可流式写临时文件，成功后提交；CBZ字节返回保留但有界。
  不能只信压缩包头部声明，也不只依靠UI页面限制。
- 验收：用小预算fixture验证超额、错误长度、条目过多与失败残留；无需真的分配巨量内存。

### R6：JS同步异步桥只判断是否在Runtime，没有区分Runtime类型（P2）

- 落点：`rust/legado-js/src/host_api/runtime_bridge.rs:35`至`:44`。
- `Handle::try_current()`成功即调用`block_in_place`；在`current_thread`运行时该API会panic。
  当前正式宿主主要使用多线程或专用JS线程，因此不能把它描述为所有生产请求都会失败。
- 修复方向：明确同步入口执行环境，在宿主边界统一派到已有阻塞/专用线程；
  对不支持的环境返回清晰错误或提供真正异步入口。不要简单在阻塞池里无限嵌套运行时。
- 依据：[Tokio block_in_place](https://docs.rs/tokio/latest/tokio/task/fn.block_in_place.html)
  明确说明current_thread会panic；同一任务内的join分支也会暂停。

### R7：内部错误过早字符串化，重试依赖英文消息（P2）

- 落点：`rust/legado-core/src/error.rs:10`至`:18`、
  `rust/legado-db/src/repository/book_repository.rs:87`、
  `rust/legado-engine/src/bookshelf_service/mod.rs:82`至`:85`。
- Database/Network/JsEngine等错误主要只存String，数据库错误的驱动码和source链因此丢失；
  阅读进度保存再通过`contains("locked") || contains("busy")`判断重试，容易随文案变化失准。
- 修复方向：先为数据库保留可判断的Busy/Locked类别与source，再在传输边界转错误码/显示文案；
  避免core反向依赖DB驱动，使用合适的错误层次或source包装。只对需要自动决策的路径先落地，
  不把整仓String错误一次性替换，也不把正常JS异常文本传递视为同类问题。
- [Rust错误处理指南](https://doc.rust-lang.org/book/ch09-03-to-panic-or-not-to-panic.html)
  区分可恢复错误与程序不变量；这里需要保留可恢复失败的信息，而不是统一panic或默认值。

### R8：MOBI递归字典缓存可以进一步去掉unsafe（P2维护项）

- 落点：`rust/legado-book/src/mobi.rs:599`、`:759`、`:776`。
- 当前UnsafeCell读写已经缩短借用范围，未发现跨递归持有可变引用的直接证据，
  没有认定现有实现必然UB。但这是一段可用`&mut self`短借用表达的单所有者缓存，不必依赖裸指针。
- 修复方向：优先显式可变借用，确需`&self`时才考虑RefCell且释放借用后递归；
  保留嵌套深度护栏与缓存行为。不要为删除unsafe引入不必要的Arc/Mutex。
- 其余抽查到的字节复制/FFI平台调用应保留局部封装与安全说明；
  [Rust官方建议](https://doc.rust-lang.org/book/ch20-01-unsafe-rust.html)
  是把必要unsafe封装在安全接口内，不是要求机械清零unsafe数量。

## 已具备、应保留的实践

| 方面 | 当前证据 | 评价 |
|---|---|---|
| 分层与资源归属 | EngineContext；Server AppState接收Arc；JS资源按实例注入 | 不再各自拥有全局业务数据库，不应重新引入大而全单例 |
| 数据库调度 | StorageContext::run用Semaphore限制并发，再spawn_blocking取连接执行 | 正确隔离同步SQL；permit留在真实阻塞工作内 |
| 任务生命周期 | TaskGroup/TaskHandle/TaskGuard、Weak登记、有界shutdown | 取消与真正结束分开，异步Future丢弃不冒充阻塞工作已停止 |
| 搜索调度 | source_batches有界在飞任务与Drop取消 | 不按源数无限创建排队任务 |
| FFI | DTO、Opaque排版/资源句柄、类型化StreamSink与Vec字节 | 已完成的现代化改造应保留，不重新描述为全量JSON透传或零拷贝 |
| 脚本状态 | 增量签名摘要、自有字节快照、失败初始化失效、沙箱回归 | 状态边界比隐式容错与无界缓存更清晰 |
| 并发锁 | 多处短临界区std::sync::Mutex，不跨await持有 | 不应机械改成Tokio Mutex；[官方指南](https://tokio.rs/tokio/tutorial/shared-state)也认可短同步临界区 |
| Cargo | Edition 2024、resolver 3、按crate声明Tokio features、受控release thin LTO | 配置方向合理；不据此声称具体包体或性能收益 |

进程级Runtime、只读常量表和有界纯计算缓存不等于业务状态泄漏，不能仅凭`static`判定必须迁移。
同理，常量正则的`expect`、测试中的`unwrap`、析构时尽力清理临时文件，应按不变量和失败后果判断，
不宜用全仓机械替换、全面改async Mutex或引入更多包装trait作为“最佳实践”目标。

## 验证证据与边界

- 合并前两侧干净；主目录独有106个改动路径、worktree独有11个路径与合并暂存树对象逐项一致。
  五个共享路径为两份日志、契约、Active和pubspec，保留双方内容，使用2.0.407+408，不额外提版本。
- 本次严格Clippy：`cargo clippy --locked --workspace --all-targets --features quickjs -- -D warnings`通过，
  Windows宿主耗时157.5秒；包含依赖编译，不能作为纯lint或应用性能指标。
- 真实行为探针`cargo run --locked -p legado-server --features quickjs --example audit_practices_probe`退出0：
  真实SQLite单查失败但书架列表成功为空；保存陈旧对象成功且覆盖来源；实际Router在成功回环响应后因speed=0.5除零；
  真实JS桥在current_thread Runtime下panic。后两项由隔离任务/catch_unwind捕获并断言，不是忽略失败。
  证据`build/rust-practices-audit/behavior-probe.log`，源码副本同目录；未改变生产函数或测试宿主。
- `cargo fmt --all -- --check`退出1，6个既有文件不符合当前rustfmt输出：
  `legado-db/src/migration/http_tts_columns_v110.rs`、`legado-db/src/migration/migrations.rs`、
  `legado-db/src/migration.rs`、`legado-db/src/repository/http_tts_repository.rs`、
  `legado-db/src/repository/mod.rs`、`legado-ffi/src/api/privacy_api.rs`。
  这些文件不是本次两批JS合并引入的格式改动；本轮没有自动格式化，不能宣称全量Rust门禁已绿。
  此为P2维护问题，但会阻断现有Rust CI格式任务；可在功能修复前以独立小提交处理。
- 默认档`cargo clippy --locked --workspace --all-targets -- -D warnings`也通过，耗时53.1秒。
  原始证据目录为`build/rust-practices-audit/`，分别为clippy-workspace.log、clippy-default.log、fmt.log与behavior-probe.log。
- 探针已从legado-server/examples移除，Rust跟踪文件与合并提交0f13ea76d逐项一致。
  审查期间另一路UI提交6f69ca797没有修改Rust；本轮文档提交只包含本报告与Active新增记录。
- 不触发远程CI，不跑全套workspace/Flutter测试、不构建DLL/APK/IPA、不安装设备；
  不宣称Linux/Android/iOS验收。临时探针不保留在生产crate或永久测试目录。

建议修复顺序：R1/R2数据库错误传播 → R3音频panic → R5资源预算 → R4/R6宿主边界 → R7/R8局部整理。
不为这轮检查修改公开FFI、数据库schema或模块拓扑；实施各项时再冻结所需契约并补针对性行为回归。

编写者：Codex + Rust｜2026-10-20
