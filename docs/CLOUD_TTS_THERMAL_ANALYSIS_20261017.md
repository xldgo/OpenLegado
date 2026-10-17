# 云 TTS 朗读发热问题：定位报告与解决方案

- 编写：主 Agent（分析）/ 2026-10-17
- 范围：仅定位与分析，未修改任何源码
- 结论性质：代码级根因推演 + 量级估算；最终定级需按 §五 的设备取证确认

---

## 一、结论摘要

发热不是单点缺陷，而是「合成 / 缓存 / 播放 / UI」四层持续唤醒叠加的结果。按预期贡献排序：

| 级别 | 问题 | 位置 | 影响 |
|---|---|---|---|
| **P0** | 云 TTS 预合成窗口默认覆盖「当前章剩余全部段落 + 后续 10 章」，3 并发，切章即取消重跑 | `read_aloud_controller.dart:582-655`、`read_aloud_synthesis_queue.dart:209-244` | 起播后数分钟内持续满负荷网络 + 落盘；每章切换重复一次 |
| **P0** | 缓存查找为「全目录扫描」，每次合成（含命中）都扫一遍；每个文件 2 次 `fsync` | `tts_speak.rs:151-173`、`tts_speak.rs:206`、`tts_cache.rs:185` | I/O 随缓存文件数线性恶化，云 TTS 输出 WAV 进一步放大写量 |
| **P1** | 播放期位置回调 16–200 ms 一次（短音频接近 60 Hz），逐次构造位置对象并向上广播 | `read_aloud_audio_player.dart:179`、`read_aloud_controller.dart:169-171` | 持续 CPU 唤醒，且驱动下游 UI 重建 |
| **P1** | 朗读胶囊封面 `_rotation.repeat()`（20 s 一圈）在可见时按帧重建整棵胶囊子树 | `read_aloud_capsule_host.dart:346`、`:484-490` | 可见期间 60–120 fps 常驻重建/重绘 |
| **P1** | 听书页每个进度变化都重建整章正文列表容器 | `read_aloud_player_screen.dart:355-371` | 听书页打开时按进度重建十余个列表项 |
| **P2** | 每段合成重复读取引擎列表 + 安全存储凭据；每段一次队列裁剪（`removeAudioSourceRange`） | `rust_cloud_tts_synthesizer.dart:24-32`、`file_read_aloud_playlist.dart:122-137` | 单次开销小，但每段一次，长期累积 I/O 与 IPC |

> 一句话根因：**朗读期间应用几乎从不真正空闲**——后台在不停合成十几章音频，前台在不停重绘，中间还夹着全目录扫描与逐文件 fsync。

---

## 二、链路梳理（云 TTS 朗读）

```
ReadAloudController._speakCurrentParagraph                read_aloud_controller.dart:315
  └─ _filePlaybackCues()  默认 paragraphIntervalMs=0 → 整章所有段落展开为 cue   :483-522
  └─ FileReadAloudPlaylist.speak()                        file_read_aloud_playlist.dart:53
       ├─ _synthesize(cue) → CloudTtsSynthesizer
       │    └─ RustCloudTtsSynthesizer.synthesize()        rust_cloud_tts_synthesizer.dart:16
       │         ├─ repository.list()            每次：全量云端引擎（DB）
       │         ├─ credentials.read()           每次：安全存储解密（Keystore）
       │         └─ FFI cloudTtsSpeak            rust/legado-ffi/src/api/cloud_tts_api.rs:22
       │              ├─ storage.with_database()  每次：DB 取引擎 + 取音色
       │              ├─ TtsCache::open()        每次：canonicalize + 全局表加锁
       │              ├─ SpeakCache::get()       每次：**整个缓存目录扫描**
       │              └─ 网络 → WAV → put()      每次：write + **sync_all** + rename
       └─ player.appendPlaylist / discardPlayedItems     每段一次队列变更
  └─ _startCloudPrefetch()                                  read_aloud_controller.dart:582
       └─ ReadAloudSynthesisQueue.startWindow → _fill()     read_aloud_synthesis_queue.dart:209
            └─ 当前章剩余全部段落 + 后续 10 章整章 → 3 并发排队合成
```

播放侧 `just_audio`：`positionStream` + `playbackEventStream` 双订阅 → `_sync()` →
`FileReadAloudPlaylist.onProgress` → `ReadAloudController._publishReadAloudPosition()` →
`readAloudPosition.value = ...` → 阅读页 / 听书页监听。

---

## 三、根因分项

### 3.1 预合成窗口过大且每章重跑（P0，主因）

**机制**

1. 一段起播成功后立刻启动预合成（`read_aloud_controller.dart:455-457`）。
2. 窗口第一批 = `remaining`（当前章剩余分片）+ `for p in paragraph+1..` 当前章**剩余全部段落**（`:621-626`）。
3. 随后按 `audioPreDownloadNum`（默认 **10**，`read_aloud_settings.dart:13`）继续预合成后续整章（`:628-647`）。
4. 并发数 = `ttsPreSynthesisConcurrency`（默认 **3**，`:14`），由 `startWindow` 传入。
5. 窗口 key 含 `chapterIndex`；**每次切章都会换 key** → `cancelBackground()` 取消在途任务，再从头铺一遍新窗口（`read_aloud_synthesis_queue.dart:193-207`）。已合成章节仅靠缓存命中兜底，仍需逐个走一遍查找与校验。
6. `_fill` 只受「批次」约束，**没有"领先播放多少段"的上限**，一旦启动就跑到窗口结束。

**量级估算**（中文正文，默认 paragraph 划分）

- 每章约 20–40 段；每段 < 600 字符，百炼/OpenAI 一般 1 次请求/段 → **每章 20–40 次请求**。
- 窗口 = 当前章 + 10 章 ≈ **200–400 次云端请求**；3 并发、单次 1–3 s → **连续 2–5 分钟满负荷合成**。
- 云 TTS 仅输出 WAV（24 kHz/16 bit 单声道 ≈ 48 KB/s，`cloud_tts_provider.dart:26-39`）：4 s 段落 ≈ 190 KB，一章 ≈ **5–8 MB**，窗口 ≈ **50–90 MB 落盘**。
- 每 8–12 分钟读一章，就重复一次上述过程（缓存命中也需重新校验）。

**为什么"只有云 TTS"明显**

- 系统 TTS 由系统合成，应用侧无请求、无落盘。
- HTTP TTS 通常返回 mp3（约为 WAV 的 1/10 体积），且引擎文本上限更大、请求数更少。
- 云 TTS 是「网络 + 服务端 + 本地 WAV 落盘 + 逐段播放」四重叠加，是唯一会在朗读全程持续占用射频与存储的路径。

**一分钟自测（无需改代码）**

设置 → 朗读设置 → **预下载章节数 = 0**（`read_aloud_controller.dart:585-588` 会直接取消后台预合成），同一本书朗读 10 分钟对比温度/耗电。若温差明显，即锁定本条为主因。

---

### 3.2 缓存查找 O(N) + 逐文件 fsync（P0，放大器）

`SpeakCache::get()` 不是按 key 直接拼路径，而是 `read_dir` 遍历整个缓存目录，对每个条目做 `is_file()` + `metadata()`（`tts_speak.rs:151-173`）。它被每一次合成调用，**包括纯缓存命中**（`cloud_tts.rs:240-246`）。

- 缓存文件数 N 随使用增长（默认保留 10 分钟，`audioCacheCleanTime`，但长听期间会累积到数千个）；
- 每次窗口 200–400 次查找 × N 个条目 → 数万到百万级 `stat` 系统调用；
- 每次写入还伴随 `sync_all()`（`tts_speak.rs:206`）+ 索引 JSON 的 `sync_all()`（`tts_cache.rs:185`），即**每段 2 次 fsync**；WAV 体积是 mp3 的 10 倍以上，进一步拉长写窗口。

这条不是"发热主因"，但它是把 3.1 的窗口开销成倍放大的乘数，且**随使用时间恶化**（越听越慢、越听越热），与用户"用一会儿更明显"的主观感受吻合。

---

### 3.3 播放期高频位置回调（P1）

`ReadAloudAudioPlayer` 同时监听 `playbackEventStream` 与 `positionStream`（`read_aloud_audio_player.dart:176-183`），每次回调进 `_sync()` 并直接调用 `_progress`（`:129`）。`just_audio`（0.10.6）的 `positionStream` 走 `createPositionStream` 默认参数（`steps: 800`、`minPeriod ≈ 16ms`、`maxPeriod ≈ 200ms`），
短音频（4–6 s 段落）实际接近 **60 Hz**；具体频率需在设备上按 §5.1 采样确认（该默认值以包内实现为准，勿以本报告为唯一依据）。

每次回调链路：`_sync` → `onProgress` → 字符偏移换算 → `ReadAloudPosition` 新对象 → `ValueNotifier` →
`_host.publishProgress()`（内部 900 ms 节流，安全）→ 阅读页 / 听书页监听者。

虽然 `ReadAloudPosition` 实现了 `==`、字符粒度会把通知降到 **5–15 次/秒**，但**回调本体仍是 60 Hz**，且下游：

- 阅读页 `_scheduleAloudFollow()` 每次通知都 `ensureVisualUpdate()` + 申请一帧（`reader_page_view.dart:219-227`）；
- 听书页 `ValueListenableBuilder` 包住**整章正文列表**（`read_aloud_player_screen.dart:355-371`），每次通知重建 `ReadAloudChapterText` 的 `ListView.builder` 可见项。

### 3.4 胶囊循环动画（P1，可见时）

`_FloatingCapsuleState._sync()` 在「显示中 + 播放中 + 未减弱动效」时执行 `_rotation.repeat()`（`read_aloud_capsule_host.dart:341-349`），周期 20 秒；该 controller 与 `_expansion/_movement/_edgeRetraction` 一起被 `AnimatedBuilder` 合并监听（`:484-490`），因此**只要胶囊可见，整棵胶囊子树（含 `ClipOval` + `Transform.rotate` + `FittedBox` 封面、进度环、按钮）就按帧重建与重绘**，最高跟到屏幕刷新率（90/120 Hz 机型更明显）。

注：阅读页在菜单收起时 `hidden == true`，动画会停（`:170-175`），所以这条主要在「书架/目录/听书页」以及「阅读页菜单展开」时生效。

### 3.5 每段重复的元数据与凭据读取（P2）

`RustCloudTtsSynthesizer.synthesize()` 每次（含预合成）都执行 `repository.list()`（全量引擎 + JSON 解析）与
`credentials.read()`（安全存储/Keystore 解密）（`rust_cloud_tts_synthesizer.dart:24-32`）；Rust 侧每次再查两次 DB
（引擎 + 音色，`cloud_tts_api.rs:40-86`）。单次毫秒级，但一次窗口数百次，属于稳定浪费。

### 3.6 每段一次队列裁剪（P2，需实测）

`FileReadAloudPlaylist._retire()` 在每段起播时调用 `discardPlayedItems()` → `removeAudioSourceRange(0, before)`
（`file_read_aloud_playlist.dart:122-137`、`read_aloud_audio_player.dart:230-249`）。Android 上这会重建 ExoPlayer 时间线；
单段开销不大，但与本仓库此前的 iOS「段首重播」问题同源（见 2026-10-17 记忆条目），修改时需一并评估。

---

## 四、解决方案

### P0-1 预合成改为「滚动领先量」模型（主修）

**改法**

1. `ReadAloudSynthesisQueue` 从「推窗口」改为「拉窗口」：只暴露 `ensureAhead(currentCueIndex, aheadCount)`，
   维持「当前段 + 前视 6–8 段」在队列/缓存中，播放推进时补充；不再一次性展开整章。
2. 跨章预合成默认只保留 **1 章**（可配置上限），`audioPreDownloadNum` 不再接入正常朗读路径，
   而是留给「批量缓存」独立功能（仓库已有 B2 单章预下载 FFI：`bridge/ffi/ffi.dart:1569`）。
3. `_fill` 增加硬上限：窗口内已完成数 ≥ `aheadCount` 立即停止，等下一次 `ensureAhead` 唤醒。
4. 切章不再 `cancelBackground()` 全量取消，而是保留已排队任务、只做窗口平移。

**预期收益**：起播后满载合成时间从 2–5 分钟降到 <30 s；请求数降低约一个数量级；API 费用同步下降。
**风险**：弱网下可能出现「合成跟不上播放」的空档，需要保留"当前段优先 + 失败重试一次"的现有语义（`read_aloud_synthesis_queue.dart:121-143`）。

> **需先裁决**：上游 Android 原版的 `preDownloadNum` 是否真的在**普通朗读**中预取 10 章。若上游只在「缓存全部/批量下载」中使用该参数，本项属于偏离项，改动即恢复对齐；若上游确实预取，则需用户确认"为控温主动降低预取量"这一行为差异。

### P0-2 缓存查找改 O(1)、写入合并

1. `SpeakCache::get()`：按已知扩展名（`mp3/wav/aac/m4a/ogg/amr/flac`）逐个 `path.exists()` 探测，删除目录扫描；
   或维护进程内 `HashSet<key>` 索引（启动时一次扫描）。
2. `put()` 的 `sync_all()` 降级为普通 `flush()`，仅在"应用退后台/停止朗读"时统一 `sync`；
   索引 JSON 合并写入（每段一条 append-only 记录，或内存聚合后批量落盘）。
3. 顺带修正 `record()` 的 `checked_path()` 每次 `canonicalize()` 的重复系统调用。

**预期收益**：缓存命中路径从 O(N) 系统调用降为常数级，随使用时间不再劣化；写入 syscall 减少约一半。

### P1-1 位置回调节流

- 在 `ReadAloudAudioPlayer` 内用 `createPositionStream(steps: 1, minPeriod: 250ms, maxPeriod: 500ms)`
  （或对 `_sync` 做时间戳节流），把向上层广播压到 **4 Hz**；
- 阅读页跟随（`_scheduleAloudFollow`）再加一层 150–250 ms 合并；
- 段落切换、暂停/继续、seek 仍走即时更新，保证交互不迟钝。

**预期收益**：播放期 CPU 唤醒次数下降约 90%，UI 帧调度显著减少。

### P1-2 胶囊动画去常驻

1. 把 `RotationTransition` 收缩到最小子树（仅封面一层）并加 `RepaintBoundary`，避免整棵胶囊随帧重建；
2. 20 s 一圈的旋转视觉收益极低：建议改为「起播 2 s 内转一小段后停」或「仅展开态旋转」；
3. 保留 `MediaQuery.disableAnimations` 与后台/隐藏判断。

### P1-3 听书页只订阅段落变化

`ReadAloudChapterText` 的 `activeIndex` 改为独立 `ValueNotifier<int>`（仅在段落变化时通知），
外层不再用 `ValueListenableBuilder` 包整章列表；进度条单独订阅位置。

### P2-1 会话级元数据缓存

一次朗读会话内缓存 `cloud engines`、`voices`、`credential`，段落级只传 engineId；
凭据仅在引擎/密钥变更时失效。

### P2-2 队列裁剪策略

`discardPlayedItems()` 改为「队列长度 > 6 时才裁剪」或「暂停/停止时统一裁剪」，减少 ExoPlayer 时间线重建次数；
同时顺带消化 iOS 段首重播问题（同一处逻辑）。

---

## 五、验证与验收

### 5.1 取证（Windows PowerShell，Android 模拟器/真机）

```powershell
# 设备号（每次实时探测，勿假设固定端口）
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices -l

# 线程级 CPU 占用（每 2 s 采样，看 legado-ffi-worker / 1.ui / raster）
& adb -s <serial> shell top -H -p (adb -s <serial> shell pidof io.legado.flutter) -d 2

# 温度与降频状态
& adb -s <serial> shell dumpsys thermalservice

# 整机耗电归因（前后各取一次，比较 UID 与 wakelock）
& adb -s <serial> shell dumpsys batterystats --charged io.legado.flutter

# 网络请求量（粗略：对比前后 /proc/net 计数或抓包统计）
& adb -s <serial> shell cat /proc/net/tcp | wc -l
```

推荐用 Perfetto 抓 60–120 s 轨迹（`CPU` + `Binder` + `Network` + `Frames`），重点看：
`legado-ffi-worker*` 的调度密度、`1.raster`/`1.ui` 帧提交频率、`keystore`/`binder` 调用量。

### 5.2 A/B 矩阵（10 分钟/组，同一本书同一章起点）

| 组 | 变量 | 目的 |
|---|---|---|
| A | 现状（预下载 10、并发 3） | 基线 |
| B | 预下载章节数 = 0 | 验证 3.1 |
| C | 预合成并发 = 1 | 验证并发放大 |
| D | 熄屏播放（A 组同参数） | 区分 UI 侧（3.3/3.4）与后台侧（3.1/3.2） |
| E | 修复后 | 验收 |

### 5.3 验收指标

- 10 分钟朗读的平均 CPU 占用（应用进程）下降 ≥ 50%；
- 电池温度上升 ≤ 2 ℃（对照 A 组）；
- 云端请求数与写盘字节数下降 ≥ 80%；
- 播放连续性不退化：不出现"合成跟不上"的空档（以 `prefetchDiagnostics` 与人工听感为准）；
- 帧率不下降：阅读页跟随、听书页滚动无卡顿。

---

## 六、落地顺序（建议）

1. **先取证定性**（§5.2 的 B/C/D 三组，约 30 分钟）——避免在错误假设上改架构；
2. B 组验证通过后先落 **P0-1 + P0-2**（改 `read_aloud_synthesis_queue.dart` / `tts_speak.rs`），这是收益最大、风险可控的一步；
3. 再做 **P1-1 / P1-2 / P1-3**（纯 UI/回调层，独立可回滚）；
4. 最后 **P2** 收尾；
5. 全部按 `docs/REFACTORING_WORKFLOW.md` 走 Agent 派发与证据链，测试以 CI（`flutter analyze && flutter test`、`cargo test`）为准，实机温升必须留真实采样日志。

---

## 七、需要用户裁决的两点

1. **预下载语义**：上游原版是否在普通朗读中预取 10 章？若否，本项属偏离，直接改回；若是，需要确认"为控温降预取量"是否可接受（会影响弱网/离线体验）。
2. **音质与体积**：云 TTS 仅 WAV，能否改请求更小体积的格式（OpenAI 支持 mp3/opus/aac）。百炼/MiMo 固定 WAV，若短时间无法改变，可考虑落盘前转码（会增加 CPU，需实测权衡）。

---

## 八、已实施（2026-10-17，仅 P0-2 / P1，未含预合成窗口调整）

本节记录本批实际落地的改动。预合成窗口（§3.1）仍待上游语义裁决后再动。

| 项 | 文件 | 改动 | 预期 |
|---|---|---|---|
| 缓存查找 O(1) | `rust/legado-core/src/tts_speak.rs` | `SpeakCache::get` 由"遍历目录 + 逐条 stat"改为按 7 种已知扩展名逐个探测；顺带消除 `tts_{key}.mp3.part` 被误命中 | 每次合成从 O(N) 降到 ≤7 次 `stat`，命中通常 1 次 |
| 落盘同步减半 | `tts_speak.rs`、`tts_cache.rs` | 音频 `sync_all` → `sync_data`；索引 JSON 取消 `sync_all`（仅 rename 发布） | 每段 fsync 从 2 次降到 ≤1 次且更轻 |
| 位置回调节流 | `read_aloud_audio_player.dart` | 新增 `progressInterval`（默认 250 ms），只对 `positionStream` 采样节流；播放事件、换项、完成、暂停恢复不节流 | 位置发布 60 Hz → 4 Hz，诊断计数 `player.progress_publish` 可直接对比 |
| 胶囊旋转解耦 | `read_aloud_capsule_host.dart` | **旋转动画保留**（20 s/圈不变），但只把 `Transform.rotate` 收进封面自己的 `AnimatedBuilder`，不再并入整棵胶囊的重建；进度环改为折叠态不构建 + `RepaintBoundary` | `ui.capsule_build` 从每帧一次降到展开/换段时一次；进度环为确定值，本身无自转 |
| 听书页正文按段重建 | `read_aloud_player_screen.dart` | 新增 `_ParagraphScope`：只在 `paragraphIndex` 变化时重建 `ReadAloudChapterText`，段内位置只驱动进度条 | `ui.chapter_text_build` 由每次位置发布降为每段一次 |

**验证结果**

- `cargo test -p legado-core --lib`：816 passed / 0 failed（含新增 `test_speak_cache_get_is_key_exact_and_never_returns_partial_files`）。
- `flutter test`（read_aloud_audio_player / read_aloud_controller / audio_tts_playback / audio_cloud_prefetch / read_aloud_diagnostics / file_read_aloud_playlist / read_aloud_player_screen / reader_controls_overlay / toc_chapter_cache_state）：全部通过。
- 新增用例「位置流按间隔合并发布，播放事件与换项仍即时上报」覆盖节流窗口与即时通道。
- `flutter analyze`：仅剩 1 条**既有** info（`read_aloud_diagnostics.dart:55` 的 `unnecessary_underscores`，来自 80880bef8，本批未改动该文件）。
- **既有失败**（与本批无关，改动前 stash 基线同样失败）：`read_aloud_audio_player_test.dart` 用例「追加后的缓冲状态不当成音频结束，不强制定位」，来自 d9a03d1ce。

**未做**：§3.1 预合成窗口（等裁决）、§3.5 队列裁剪策略、§3.6 每段元数据缓存。
