# 纯音频播放统一方案

任务进度只维护于 [Active](REFACTORING_ACTIVE_PLAN.md) 的 `MEDIA-CONSOLIDATION-20261015`。
本文保存职责、实施方法和验收边界，不维护第二份状态。

## 最新范围

用户于2026-10-15明确：正文 HTTP/云 TTS、音频书及音色试听统一到 `just_audio`，
取消旧纯音频后端及回退；暂不删除视频相关代码。

保留视频页面、弹幕、视频分组、视频悬浮窗、Android视频服务、Rust视频接口及
`video_player` 依赖。最初方案A2～A5的视频删除部分全部后置，不由本任务执行。
`local_media_source*` 不再被纯音频使用，本批也不删除，以免扩展清理范围。
不修改Rust/FRB契约、数据库、工作流、包标识或版本；版本保持2.0.373+374。
沿用当前worktree及前批未提交播放器队列，不创建分支，不自动提交、推送或触发CI。

## 依据与历史差异

上游固定为 HapeLee/legado-with-MD3 `4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5`。
[HttpReadAloudService](https://github.com/HapeLee/legado-with-MD3/blob/4ef08aafe7901ca0bf552d3bc0aaf2d6ce1a20d5/app/src/main/java/io/legado/app/service/HttpReadAloudService.kt)
复用原生播放器并在零间隔时追加后续媒体，具体队列对照和测量口径见 [TTS_ALIGNMENT](TTS_ALIGNMENT.md)。

当前上游无完整视频书源开书分支，但本项目历史P4-3、V-B批次按Android原版已有明确立项和
用户素材记录，不能追认为未经授权代码。用户本次明确保留视频，因此不再以此差异发起删除。
[历史视频调研](VIDEO_TRACK_SURVEY_20261005.md)只作追溯。

## 职责和实现

| 能力 | 归属 |
| --- | --- |
| 纯音频调用契约 | `StreamAudioPlayer`，不导入视频插件 |
| 文件、网络音频、正文播放列表 | `ReadAloudAudioPlayer`，统一just_audio实现 |
| 正文TTS | 共用播放器实例；合成、租约、原文和章末仍由既有协调层处理 |
| 音频书 | 同一适配器播放网络URL，保留进度、倍速和章末语义 |
| HTTP/云音色试听 | 同一适配器的独立实例，复用取消和租约生命周期 |
| 系统语音 | 既有SystemTts/flutter_tts |
| 焦点、中断、通知、媒体按键 | 既有MediaSessionBridge/AudioService，播放器不重复接管 |
| 视频播放 | 既有video_player及全部专用功能保持 |

1. 将 `StreamAudioPlayer` 改为抽象纯音频契约；ReadAloudAudioPlayer只继承契约提供的
   回调字段，不继承视频控制器或调用super回退。本地文件、网络URL和队列共用同一原生对象。
2. 保留currentTag、进度/完成回调、seek、实时倍速和原位换绑恢复；加载/停止采用代数失效，
   旧请求和旧原生事件不得覆盖新会话，未知时长或暂停不能误报完成。
3. 增加带归属tag的异步错误回调：音频书错误暂停并显示原因，不当成自然章末；
   试听/单文件TTS错误进入现有ReadAloudSession，旧错误不能结束新试听或新章节。
4. 装载失败先清理原生引用；文件引擎随后释放租约。主播放器由Provider销毁时释放，
   独立试听沿用预览对象的dispose，不新增第二套音频会话或焦点控制。
5. 将旧视频平台音频测试替换为just_audio适配器行为回归；原视频页焦点配置测试保留。
   前批旧/新后端对照日志保留历史证据，原生测试只验收当前实现，不伪造新的前后性能对照。

音频书取址沿用既有FFI返回的mediaUrl，未在本批增加源级Header的FFI传输或新规则解析；
不将本地HTTP夹具当成所有受认证书源、HLS或远端Range服务器都已验收。

## 验收

- 正文队列顺序、跨分片、原文进度、暂停恢复、迟到追加/取消、段间停顿和章末定时。
- 音频书URL、章内seek/恢复、倍速、自然章末/手动切章、旧章错误与进度归属。
- HTTP/云/系统音色试听取消、租约释放和异步错误；实例隔离不与正文共享来源或标签。
- 适配器前后台不自行暂停或恢复；焦点和媒体按键继续由既有协调层处理。
- Windows真实本地WAV与loopback HTTP（支持HEAD/Range/查询串）验证网络播放、暂停、
  seek、换绑及完成；Android打包/native校验与实际Android运行时结果分别记录。
- iOS后台/锁屏仍按用户安排后置，不能由Windows/Android测试替代。

原生集成测试只在隔离测试实例运行，执行前备份并确认可读，命令明确
`flutter test --no-uninstall ... -d <隔离设备号>`，测试后恢复正常应用入口。
不得再将MuMu用户验收实例作为integration_test宿主；本轮不安装到MuMu。
前批MuMu原数据恢复仍独立未完成，不能以新构建或新测试通过销账。

每批交付可审核diff、实际验证及未测范围；提交、推送、合并和CI继续需要用户明确指令。
回退只恢复本批代码，不清空设备、数据库、书源或凭据，不覆盖前批未提交成果。

编写者：Codex｜2026-10-15
