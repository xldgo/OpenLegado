import 'dart:async';
import 'dart:convert';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../domain/contracts/tts_cache_repository.dart';
import '../../platform/tts/system_tts.dart';
import '../../platform/audio/app_audio_session.dart';
import '../../services/stream_audio_player.dart';
import 'playback/cloud_read_aloud_engine.dart';
import 'playback/http_read_aloud_engine.dart';
import 'playback/read_aloud_engine.dart';
import 'http_tts_voice_selection.dart';

/// 音色试听只持有独立播放会话，不拥有正文队列或默认选择。— Codex + UI
final class ReadAloudVoicePreview {
  ReadAloudVoicePreview({
    required this.player,
    required this.system,
    required CloudTtsSynthesizer Function() cloud,
    required CloudTtsRepository Function() engines,
    required HttpTtsSynthesizer Function() http,
    required TtsCacheRepository Function() cache,
    required this.onChanged,
    required this.onError,
    AppAudioSession? audioSession,
  }) : _audioSession = audioSession ?? AppAudioSession.instance {
    _audioEvents = _audioSession.events.listen((event) {
      // 试听不自动恢复；耳机断开/中断使本次试听彻底失效。
      if (event == AppAudioEvent.pause ||
          event == AppAudioEvent.stop ||
          event == AppAudioEvent.loss) {
        unawaited(stop());
      }
    });
    _cloud = CloudReadAloudEngine(
      synthesizer: cloud,
      repository: engines,
      player: player,
      cache: cache,
    );
    _http = HttpReadAloudEngine(synthesizer: http, player: player);
    player.onCompleted = (tag) {
      _cloud.handleCompleted(tag);
      _http.handleCompleted(tag);
    };
    player.onError = (error, tag) {
      _cloud.handleError(error, tag);
      _http.handleError(error, tag);
    };
    player.onProgress = (p, d, tag) {
      _cloud.handleProgress(p, d, tag);
      _http.handleProgress(p, d, tag);
    };
  }
  final StreamAudioPlayer player;
  final SystemTts system;
  final AppAudioSession _audioSession;
  late final StreamSubscription<AppAudioEvent> _audioEvents;
  AppAudioLease? _audioLease;
  final void Function(String?) onChanged;
  final void Function(Object) onError;
  late final CloudReadAloudEngine _cloud;
  late final HttpReadAloudEngine _http;
  ReadAloudEngine? _active;
  ReadAloudSession? _session;
  int _generation = 0;
  bool _systemActive = false, _closed = false;
  Future<void> stop() async {
    _generation++;
    _session?.cancel();
    _session = null;
    final active = _active;
    _active = null;
    final wasSystem = _systemActive;
    final lease = _audioLease;
    _audioLease = null;
    _systemActive = false;
    onChanged(null);
    try {
      await active?.stop();
      if (wasSystem) await system.stop();
    } finally {
      await lease?.release();
    }
  }

  Future<void> speak(
    ReadAloudVoice voice,
    String text, {
    bool draft = false,
    HttpTtsVoiceSelection? httpSelection,
  }) async {
    await stop();
    if (_closed) return;
    if (!voice.selectable) throw StateError('音色不可用');
    final generation = ++_generation;
    final session = ReadAloudSession(
      isCurrent: () => !_closed && generation == _generation,
      onCompleted: () => unawaited(stop()),
      onProgress: (_) {},
      onError: (e) {
        onError(e);
        unawaited(stop());
      },
    );
    _session = session;
    onChanged(voice.id);
    try {
      final lease = await _audioSession.acquire(userInitiated: true);
      if (!session.isCurrent) {
        await lease?.release();
        return;
      }
      if (lease == null) throw StateError('无法取得试听音频会话，请稍后重试');
      _audioLease = lease;
      if (voice.engineType == 'system') {
        if (voice.engineId != 'system:${system.selectedEngine}') {
          throw StateError('请先选择对应系统引擎');
        }
        _systemActive = true;
        final traits = jsonDecode(voice.traitsJson) as Map<String, dynamic>;
        unawaited(
          system.speak(text, voiceKey: traits['voiceKey'] as String?).then((o) {
            if (o == SystemTtsOutcome.completed) {
              session.complete();
            } else if (session.isCurrent) {
              unawaited(stop());
            }
          }, onError: (Object e) => session.fail(e)),
        );
        return;
      }
      final cloud = voice.engineType == 'cloud_tts';
      _active = cloud ? _cloud : _http;
      final traits = jsonDecode(voice.traitsJson);
      final httpVoice = cloud
          ? const HttpTtsVoiceResolution()
          : resolveHttpTtsVoice(
              int.parse(voice.engineId),
              [voice],
              httpSelection?.voiceId == voice.id
                  ? httpSelection
                  : HttpTtsVoiceSelection(voice.id),
            );
      final result = await _active!.speak(
        ReadAloudRequest(
          text: text,
          engineUrl: cloud ? 'cloud://${voice.engineId}' : '',
          engineId: cloud ? 0 : int.parse(voice.engineId),
          toneId: cloud ? null : voice.speakerId,
          speakerName: voice.displayName,
          emotionTag: cloud ? null : httpVoice.emotionTag,
          voicePresetId: cloud && !draft ? voice.id : null,
          cloudVoiceOptions: cloud && draft
              ? Map<String, dynamic>.unmodifiable({
                  ...traits as Map<String, dynamic>,
                  'voiceId': voice.speakerId,
                })
              : null,
        ),
        session,
      );
      if (result == ReadAloudStart.noAudio) throw StateError('当前环境未生成试听音频');
    } catch (_) {
      if (generation == _generation) await stop();
      rethrow;
    }
  }

  Future<void> dispose() async {
    _closed = true;
    await _audioEvents.cancel();
    await stop();
    await player.dispose();
  }
}
