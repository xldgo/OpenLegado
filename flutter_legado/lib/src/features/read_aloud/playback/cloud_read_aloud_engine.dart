import 'dart:async';

import '../../../domain/models/read_aloud_content.dart';

import '../../../domain/contracts/cloud_tts_repository.dart';
import '../../../domain/contracts/cloud_tts_provider.dart';
import '../../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../../domain/contracts/tts_cache_repository.dart';
import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../services/stream_audio_player.dart';
import 'file_read_aloud_engine.dart';
import 'read_aloud_engine.dart';
import 'read_aloud_synthesis_queue.dart';

/// 分片只属于当前段落，章节衔接由控制器协调，通知/定时仍由宿主拥有。— Codex + UI
final class CloudReadAloudEngine
    implements ReadAloudEngine, ReadAloudPlaylistEngine {
  CloudReadAloudEngine({
    required CloudTtsSynthesizer Function() synthesizer,
    required StreamAudioPlayer player,
    required TtsCacheRepository Function() cache,
    this.repository,
    ReadAloudSynthesisQueue? queue,
  }) : _file = FileReadAloudEngine(
         player: player,
         synthesize: (request, cancellation) async {
           if (queue != null) return queue.foreground(request, cancellation);
           final result = await synthesizer().synthesize(
             engineId: cloudTtsId(request.engineUrl),
             text: request.text,
             voiceId: request.voicePresetId,
             voiceOptions: request.cloudVoiceOptions,
             cancellation: cancellation,
           );
           if (result is HttpTtsAudio && request.cacheContext != null) {
             try {
               await cache().record(result.audioPath, request.cacheContext!);
             } catch (_) {
               await result.lease?.release();
               rethrow;
             }
           }
           return result;
         },
       );
  final FileReadAloudEngine _file;
  ReadAloudRequest? get currentRequest => _request;
  final CloudTtsRepository Function()? repository;
  bool _playlistActive = false;
  @override
  bool get supportsPlaylist => _file.supportsPlaylist;
  @override
  Future<ReadAloudStart> speakPlaylist(
    List<ReadAloudPlaylistCue> cues,
    ReadAloudSession session, {
    required void Function(ReadAloudPlaylistCue) onCueStarted,
  }) {
    _playlistActive = true;
    _parent = session;
    _request = cues.first.request;
    return _file.speakPlaylist(
      cues,
      session,
      onCueStarted: (cue) {
        _request = cue.request;
        onCueStarted(cue);
      },
    );
  }

  ReadAloudSession? _parent;
  ReadAloudRequest? _request;
  List<String> _parts = [];
  int _index = 0;
  @override
  bool get canResume => _file.canResume && _request != null;
  ReadAloudSession _child(ReadAloudSession parent) {
    final base = _parts.take(_index).fold<int>(0, (n, p) => n + p.length);
    return ReadAloudSession(
      isCurrent: () => identical(_parent, parent) && parent.isCurrent,
      onProgress: (offset) => parent.reportProgress(base + offset),
      onError: parent.fail,
      onCompleted: () {
        if (!identical(_parent, parent) || !parent.isCurrent) return;
        if (_index + 1 == _parts.length) {
          parent.complete();
          return;
        }
        parent.reportProgress(base + _parts[_index].length);
        _index++;
        unawaited(_next(parent));
      },
    );
  }

  Future<void> _next(ReadAloudSession parent) async {
    try {
      await _file.stop();
      if (!identical(_parent, parent) || !parent.isCurrent) return;
      final result = await _speakPart(parent);
      if (result == ReadAloudStart.noAudio) {
        parent.fail(StateError('云端合成未返回音频'));
      }
    } catch (error) {
      parent.fail(error);
    }
  }

  ReadAloudRequest _partRequest(int index) {
    final request = _request!;
    final context = request.cacheContext;
    return request.copyWith(
      text: _parts[index],
      cacheContext: context == null
          ? null
          : TtsCacheContext(
              bookUrl: context.bookUrl,
              bookName: context.bookName,
              chapterIndex: context.chapterIndex,
              chapterTitle: context.chapterTitle,
              paragraphIndex: context.paragraphIndex,
              text: _parts[index],
            ),
    );
  }

  List<ReadAloudRequest> get remainingRequests => [
    if (_request != null)
      for (var i = _index + 1; i < _parts.length; i++) _partRequest(i),
  ];

  Future<ReadAloudStart> _speakPart(ReadAloudSession parent) =>
      _file.speak(_partRequest(_index), _child(parent));

  @override
  Future<ReadAloudStart> speak(
    ReadAloudRequest request,
    ReadAloudSession session,
  ) async {
    if (_parent != null) await stop();
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _parent = session;
    _request = request;
    var limit = 4000;
    final resolveRepository = repository;
    if (resolveRepository != null) {
      final engines = await resolveRepository().list();
      if (!identical(_parent, session) || !session.isCurrent) {
        return ReadAloudStart.cancelled;
      }
      final engine = engines
          .where((e) => e.id == cloudTtsId(request.engineUrl))
          .firstOrNull;
      if (engine == null || !engine.enabled) throw StateError('云端引擎不存在或已停用');
      limit = cloudTtsProfile(engine.provider).textLimit;
    }
    _parts = splitCloudSpeechText(request.text, limit: limit);
    _index = 0;
    if (_parts.isEmpty) return ReadAloudStart.noAudio;
    return _speakPart(session);
  }

  void handleCompleted(Object? tag) => _file.handleCompleted(tag);
  void handleError(Object error, Object? tag) => _file.handleError(error, tag);
  void handleProgress(Duration position, Duration duration, Object? tag) =>
      _file.handleProgress(position, duration, tag);
  @override
  Future<void> pause() {
    _parent?.cancel();
    return _file.pause();
  }

  @override
  Future<void> stop({Future<void>? playbackStopped}) {
    _parent?.cancel();
    _parent = null;
    _playlistActive = false;
    _request = null;
    _parts = [];
    _index = 0;
    return _file.stop(playbackStopped: playbackStopped);
  }

  @override
  Future<ReadAloudStart> resume(ReadAloudSession session) {
    if (!canResume || !session.isCurrent) {
      return Future.value(ReadAloudStart.cancelled);
    }
    _parent = session;
    return _file.resume(_playlistActive ? session : _child(session));
  }
}

/// 4000 UTF-16 上限比远端字符上限保守；不拆代理对、组合音标或 ZWJ 字形簇。
List<String> splitCloudSpeechText(String text, {int limit = 4000}) =>
    splitSpeechRequests(text, limit: limit).map((part) => part.text).toList();
