# 双轨协作开发规范·背景与原理（TWO_TRACK_DEV_RATIONALE）

**日期**: 2026-10-19
**版本**: v1.0
**配套规范**: [TWO_TRACK_DEV_SPEC.md](TWO_TRACK_DEV_SPEC.md) v1.4

> 本文只解释规范「为什么这样规定」，**不规定做法**；做法一律以
> [TWO_TRACK_DEV_SPEC.md](TWO_TRACK_DEV_SPEC.md) 为准。章节号与规范对应，便于回查。
> 两文内容冲突时，以规范的规则为准，本文只提供理由。
> 逐批 Rust 服务边界记录另见 [RUST_SERVICE_BOUNDARY_LOG.md](RUST_SERVICE_BOUNDARY_LOG.md)。

---

## 1. 为什么分轨（对应规范 §1）

Legado Flutter 重构采用 **Rust 核心引擎 + Flutter 跨平台 UI** 架构，两端通过
`flutter_rust_bridge`（FFI）连接。分轨源于以下痛点：

- **UI 迭代被 Rust 交叉编译拖慢**：每次修改 Rust 代码都需重新编译 cdylib、执行 codegen、
  同步 DLL，一次完整循环耗时数分钟，严重拖慢 UI 调整节奏。
- **UI 对齐需要高频迭代**：Flutter 端按参考版截图核对用户可见布局和交互；纯 Dart UI
  可先用 Mock 开发，再进入双轨集成验证。
- **任务级并行**：按轨划分文件边界后，UI 与 Rust 引擎的工作可由不同任务或代理并行推进；
  分工与并行上限以统一工作流为准。

目标：解耦迭代节奏、明确文件归属、契约驱动协作、规避已知坑。

## 2. 为什么这样划边界（对应规范 §2）

- `services/` 现存 1 处 `bridge/ffi` 引用（`app_update_service.dart` 等含业务逻辑）。
  按 §2.1(3) 的判定规则它应归 Rust 轨，但改造牵动业务逻辑，故列为历史遗留：
  **改动前须走契约评审**，不因为它是"平台服务"就默认放行给 UI 轨。
- `routes.dart` 被 46 个文件反向引用，形成循环依赖，改动会同时波及两侧，
  故规定**独占批次**处理，不允许夹带在常规 UI 批次里。
- `lib/src/rust/` 仅剩 `.gitkeep.dart` 占位（codegen 产物已迁至 `bridge/`），待清理。
- `models/` 与 `services/` 判定时"不确定就按 Rust 轨处理并走契约评审"，
  是因为这两处是跨轨数据结构的实际流通点，判错的代价由两侧共同承担。

## 3. FFI 与 codegen 为什么有这些铁律（对应规范 §3）

### 3.1 为什么 codegen 后必须走 Python 构建入口

Python 入口（`scripts/dev.py`）在完成编译与复制的同时执行**严格摘要校验**；
直接 `cargo build` 会绕过该校验，产出未经核对的库，失配要拖到运行期才暴露。
规范里保留的等价底层命令仅作排障参考，不作为交付路径。

### 3.2 content hash 为什么会失配

每次 codegen 会重新计算双侧 content hash。若 codegen 后未重编译 Rust DLL/.so，
旧二进制中嵌入的 hash 与新生成的 Dart 侧 hash 不一致，启动即报：

```
Content hash on Dart side (X) is different from Rust side (Y),
indicating out-of-sync code
```

Android Gradle 调用同一 Python 只读校验器检查契约、源码与工具指纹、ABI/profile/features、
元数据和实际库摘要，就是为了让这类失配在**构建期**暴露，而不是留给运行期。

### 3.3 为什么 `LEGADO_SKIP_RUST_BUILD` 只对 Android 生效

它是**环境变量**而非 `--dart-define`，读取点仅两处：
`flutter_legado/android/ffi-verification.gradle.kts:57` 与 `scripts/tooling/android_app.py:204`
（后者对真实 APK 编排直接拒绝该变量）。Windows / iOS / macOS 没有对应的 Gradle 接线，
桌面端跳过 Rust 编译的方式是**直接使用 Mock 模式运行**，不存在等价跳过开关。

### 3.4 为什么构件必须原子重建（funcId 分派错位）

frb 的调用桥按 **funcId 序号**把 Dart 调用分派到 Rust 函数。不同 codegen 批次产出的
Dart 生成物与 .dll/.so 混搭运行时，funcId 序号错位，Dart 调用会被分派到**另一个 Rust 函数**——
后果是参数类型错位的随机崩溃（native segfault / 栈溢出）或静默数据错乱。
这类故障的堆栈不含 Dart 符号，极难定位，历史上已多次踩中，因此规定整套重建而非局部修补。

### 3.5 为什么约束不能写进生成文件

`lib/src/bridge/ffi.dart` 顶部曾手写配对警示，被一次 codegen 直接抹除。
`bridge/` 目录与 `frb_generated.*` 均为 codegen 产物，任何手写注释都会被下次 codegen 清除，
因此需要持久化的约束只能写入规范文档，不能依赖生成文件里的注释。

### 3.6 构建入口为什么要复核复制摘要

CMake 负责复制对应 profile 的 DLL；Python 传入当前 Cargo 输出目录并**复核最终复制摘要**，
且不跨模式回退，避免"Release 构建配 Debug 库"这类只在运行期暴露的错配。
旧 Windows/生成脚本及 Makefile 已删除，入口统一到 Python。

## 4. 契约层为什么长这样（对应规范 §4）

- **全能根接口被移除**：`BookApi`、`RustApi` 全能根接口和 `bookApiProvider` 已从生产链路移除，
  改为按领域划分的窄 Repository/Service 契约。原因是全能接口会把任意一次能力变更
  放大为全链路改动，违背"契约驱动、按领域解耦"的目标。
- 保留 `--dart-define=USE_MOCK=true` 的切换机制，是为了让 UI 轨在 Rust 侧能力未就绪时
  仍能按契约并行开发，而不是等真实实现。

## 5. 排版测试为什么要这样准备（对应规范 §7.2）

- `test/helpers/native_reader_layout.dart` 复用正式 `NativeReaderLayoutTransport` 与
  FRB Opaque 会话，**每个测试 worker 初始化一次绑定**，用例结束清理尚未关闭的句柄；
  不启动应用或打开数据库。这样测的是真实绑定，而不是另写一套分页算法。
- 需要真实分页的 Widget 测试用 `pumpNativeReaderLayout` / `settleNativeReaderLayout`
  交替等待真实 I/O 和推进测试帧；**只调用 `pumpAndSettle` 不保证原生回调已经完成**——
  原生 I/O 不占用 Dart 的微任务与帧调度，`pumpAndSettle` 可能在回调返回前就判定"已静止"。
- 默认从当前工作树 `rust/target/debug/` 加载 DLL/so/dylib；复用其他 Cargo 目录时，
  将 `LEGADO_TEST_FFI_LIBRARY` 设为实际原生库绝对路径。绑定与原生库必须来自同一契约。
- 旧"逐次启动进程、重放全部内容"的宿主及专用 JSON 测试链路已退役：
  它另有一套分页实现，验的不是生产路径。测试辅助器现在只负责调度与清理。
- 上游算法样例在 Rust 侧完整比对，真实 FRB 只抽取两种代表载荷验证映射与句柄，
  是为了把"算法正确性"和"绑定正确性"两件事分开，避免用 Dart 测试去复刻 Rust 算法。

## 6. 版本沿革

| 版本 | 日期 | 变化 |
|---|---|---|
| v1.0 | 2026-10-19 | 从 `TWO_TRACK_DEV_SPEC.md` v1.3 拆出背景与原理；规范同步升 v1.4 |

---

**最后更新**: 2026-10-19

— 主代理，2026-10-19
