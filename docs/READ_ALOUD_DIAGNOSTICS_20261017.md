# 朗读重播与发热取证

本说明只描述采集与分析方法；任务状态以REFACTORING_ACTIVE_PLAN中的
TTS-DIAGNOSTICS-20261017为准。实现参考用户提供的
CLOUD_TTS_THERMAL_ANALYSIS_20261017.md，不把其量级估算当作设备实测。

## iPhone操作

1. 安装包含本批代码的Release IPA，覆盖安装并保留应用数据。无需额外dart-define或开启CI图标诊断。
2. 设置→关于→开启“朗读诊断”，再使用原有引擎、音色、倍速开始朗读。
3. 听到段首重播时记下大概时间；方便时回到关于页点击“标记刚才的段首重播”。
   标记记录点击时间，不等于实际故障发生的精确时刻。
4. 点击“导出朗读诊断并停止采集”，从系统分享面板保存或发送JSONL文件。
   这只停止采集，不停止朗读；取消分享后可再次导出。
5. 30分钟后自动停止，也可随时手动关闭；应用重启后不自动恢复采集。

日志默认关闭。启用后每5秒汇集原生通知并异步批量落盘，不调用fsync；每15秒记录资源、
回调计数与帧汇总，不逐帧写日志。内存最多256条/64KiB，溢出丢弃最旧事件并计数；
64KiB指编码后的事件内容，不代表整个诊断对象的真实内存占用。
采集文件最多两个1MiB，临时导出复用单个文件。应用被强制终止时最后一批内存事件可能丢失。
关闭后移除帧、生命周期与原生通知观察，取消定时器并恢复原有电池监测状态。

## 字段与关联

每行是一条JSON：session、seq、wallMs、monoUs、event和该事件字段。
session是一次手动采集的身份；generation是播放会话代次。Dart的player/tag与iOS的item
只在当前进程内有效，二者不是同一标识。file是文件名SHA-256的前16位，跨两侧关联音频；
不同目录下同名文件可能同标识，不能把它当作文件内容摘要。
不写正文、书名、密钥、Header、完整请求URL或音频路径，不收集第三方错误响应文本。

| 事件 | 作用 |
|---|---|
| player.load.request/done、play、pause、resume、stop、speed | 应用显式播放操作 |
| player.append.begin/end | 批量追加前后的项数/索引/位置/状态，addedCount及匿名标签/文件列表 |
| player.seek | 显式定位及原因，含队尾恢复下一项、暂停恢复和用户定位 |
| player.item_changed、sample、position_backwards | 当前音频身份、每秒状态和同一标签位置后退超过200ms的线索 |
| playlist.cue_started | 正文段落/分片、租约保留量、准备位置preparedNext与提交位置queuedNext |
| native.event | iOS音频项时间不连续、结束、停顿、失败、中断、路由变化及原生时间 |
| synthesis.window_start/cancel、chapter_batch | 窗口代次、每章实际分片数、并发和待处理量 |
| synthesis.job.begin/end | 前后台归属、取消、结果、缓存命中和端到端任务耗时 |
| cloud.synthesis.begin/end、cloud.ffi.begin/end、cloud.audio | 配置/凭据读取耗时、FFI总耗时、产物大小和匿名文件身份 |
| resources.summary | RSS/峰值RSS、回调/尝试/重建等区间计数、帧数、最大build/raster耗时 |
| native.resources | iOS应用进程CPU、热状态、电池、低电量模式及前后台状态 |
| system_tts.speak/pause/resume/stop | 系统朗读路径的显式操作，不能与文件队列混为一谈 |

## 段首重播的判读

- 先找user.heard_replay前十几秒的同一个file/tag。
- 有第二次load或显式seek：沿应用调用原因检查；主动拖动产生的位置后退属于正常行为。
- 没有对应Dart定位、但有相同原生item的time_jump：说明系统观察到该项时间不连续，
  结合discard/append前后位置判断相关性。通知本身不能证明由哪一个插件内部方法触发。
- 新item出现：检查是否同文件被再次装载，避免把正常换到下一段的位置归零当成回退。
- 两侧位置都正常但听到重复：保留对应音频文件单独试听；日志不包含音频内容，无法排除合成产物自身重复。

章节队列调整后播放期间不再产生discard或retire事件；这些名称仅用于解释旧诊断包。
retained表示本章仍持有的全部租约，不等于前方待播项数，历史项增长不代表预合成窗口扩大。
批量追加完成回调前queuedNext可能暂时落后于已观察到的原生索引，应结合append.end判断。
位置采样不再触发换项，新项等待下一份原生位置基点，不能将换项附近短暂无段内采样认定为停播。

原生通过AVPlayerItem公开通知被动观察，不修改just_audio、运行时方法或播放行为。
不读取AVQueuePlayer私有字段，未覆盖插件每一次内部方法调用；也不保证所有很短的跳转
都会被Dart位置流捕获。系统TTS不使用AVPlayerItem，不能套用同一音频项通知判据。

## 发热对照

固定书籍/起点、音色、倍速、亮度、蓝牙、充电及室温，分别采集约10分钟：
原参数、预下载章节数为0、并发为1、原参数锁屏。每组先恢复近似初始温度与电量，
避免上一组积累的热量影响结论；记录前后台/听书页/阅读页等操作阶段。
开启诊断本身有开销，因此各组使用相同诊断设置，不直接与未开诊断的读数混比。

- CPU：原生getrusage的user+system累计秒数差/系统运行时间差×100，100%表示一个核心，
  多线程可超过100%；包含Rust线程，不代表整机耗电或某一线程归因。
- 热状态：0 nominal、1 fair、2 serious、3 critical；不是摄氏温度，iOS此处没有电池温度读数。
- 电池：batteryLevel为0..1，-1表示不可读；短时间/充电时不能据此精确计算能耗。
- bytes：新产物文件长度汇总，不是实际网络流量/写盘syscall数；缓存命中和取消分别看对应字段。
  大小读取异步进行，最多8个在途采样；采样跳过或文件提前回收时汇总可能偏少，见size_sample_skipped。
- 耗时：FFI端到端包含内部缓存/网络/写入，本批不拆分Rust目录扫描和fsync，不据此证明二者占比。
- 帧：framesOver16ms是固定16.667ms阈值统计，不等同于实际掉帧；帧回调没有按帧写文件。
  Release中可用的阶段信息可能少于Profile，不以空统计推断没有UI开销。

公开API依据：[时间跳转通知](https://developer.apple.com/documentation/avfoundation/avplayeritem/timejumpednotification)、
[系统热状态](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property)。

编写者：Codex｜2026-10-17
