# SQLite 内置与系统链接体积实验

编写者：Codex + Rust｜2026-10-24

## 实测结果

以 `feature/rust-workspace-deps` / `960b3492d` 的真实 `legado-ffi` 为对象，在 Windows x86_64 上改用系统 SQLite：DLL 减少 **1.55 MiB（3.35%）**，单 DLL 的 ZIP 压缩文件减少 **0.86 MiB（5.10%）**。

| 项目 | 内置 SQLite | Windows 系统 SQLite | 减少 |
|---|---:|---:|---:|
| Release DLL | 48,560,640 B（46.31 MiB） | 46,933,504 B（44.76 MiB） | 1,627,136 B |
| ZIP / Deflate 9 | 17,666,797 B（16.85 MiB） | 16,765,366 B（15.99 MiB） | 901,431 B |
| 实际 SQLite 版本 | 3.53.2 | 3.53.4 | 系统版本随 Windows 变化 |
| 数据库探针 | schema 112 / 33 表 / 事务读写通过 | schema 112 / 33 表 / 事务读写通过 | — |
| DLL 独立加载 | 通过 | 通过 | — |

这是最终 DLL 的真实差值，没有以静态归档或编译缓存体积替代。系统库由 Windows 提供，本实验不额外分发 SQLite DLL；如果改为随应用另带外置 DLL，必须把该文件计入包体积，不能直接沿用此收益。

## 对照条件

- Windows 11 `10.0.26300`，Rust `1.99.0`，目标 `x86_64-pc-windows-msvc`。
- 两组都是 `cargo build --locked --offline --release -p legado-ffi --features quickjs --lib`，沿用项目 `thin LTO`、默认优化等级 3、unwind、不额外 strip；同一临时源码目录、输出目录和构建环境。
- 内置组：`rusqlite 0.40.2` / `libsqlite3-sys 0.38.2`，启用 `bundled`。
- 系统组：移除 `bundled`，显式保留其隐含的 `modern_sqlite`，保持 Rust 绑定一致。通过 `SQLITE3_LIB_DIR` 和 `SQLITE3_STATIC=0` 使用 Windows SDK `10.0.26100.0` 的导入库；只在实验目录将 `winsqlite3.lib` 复制命名为 `sqlite3.lib`，导入库内部仍指向 `winsqlite3.dll`。
- PE 导入检查确认：内置组未导入 `winsqlite3.dll`，系统组实际导入它。删除 `bundled` 本身不会替代这套系统链接配置。
- 取消 C 源码编译后，Cargo 要求更新实验副本的锁文件：仅删除 `libsqlite3-sys → cc` 构建依赖边。所有包的名称、版本、来源和校验和完全相同；其余依赖未升级。正式锁文件和正式依赖声明逐字节不变。
- 系统 SQLite 和随 crate 内置 SQLite 的版本、编译选项不同。本实验衡量“改用本机系统库”的实际方案，不是同一 SQLite 构建的纯链接模式理论比较。

## 运行验证与边界

两组均从独立子进程加载完整 DLL，并分别运行临时 `legado-db` example：通过正式 `Database::open` 新建文件库及迁移，然后执行事务写入、查询并核对中文值。探针只存在于忽略目录的源码副本，不加入生产代码或永久测试。

未运行全量业务测试、Flutter 或整包构建。数据库探针不代表所有 SQL 功能、迁移历史或生产场景都已验证。ZIP 数字仅是同一 DLL 的压缩对照，不是 APK、IPA 或 Windows 安装包的实测节省量。Android、iOS 的架构、系统 SQLite 接入方式和版本不同，不能直接套用本次数值。

内置组首先冷编译、系统组复用缓存，因此构建日志中的耗时不能用于比较编译速度；也没有测量启动速度、数据库性能或内存收益。

## 本地证据与复核

证据位于本 worktree 的 `build/sqlite-size-20261024/`（忽略目录，不提交二进制）：

- `environment.json`：工具链、Windows 系统 SQLite 版本和编译选项。
- `source-Cargo.toml` / `source-Cargo.lock`：正式输入快照。
- `run_experiment.py` / `project/rust/`：编排及实际临时源码。
- `bundled-build.log` / `system-build.log`：两次完整 FFI 构建。
- `bundled-probe.log` / `system-probe.log`：实际迁移、事务与版本输出。
- `bundled-imports.txt` / `system-imports.txt`、两份 `*-load.log`：PE 链接和运行时加载证据。
- `system-lock-diff.json`：唯一锁文件依赖边变化。
- 两份 `legado_ffi-*.dll`、ZIP、`*-result.json` 及 `summary.json`：产物、摘要和原始测量值。

参考：[rusqlite 的 bundled 说明](https://github.com/rusqlite/rusqlite#usage)、[微软系统 SQLite 接入说明](https://learn.microsoft.com/en-us/windows/apps/develop/data-access/sqlite-data-access)。正式依赖策略本次保持 `bundled`；本实验不实施平台切换。
