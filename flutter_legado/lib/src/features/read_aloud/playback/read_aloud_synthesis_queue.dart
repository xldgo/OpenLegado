import 'dart:async';
import 'dart:convert';

import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../domain/contracts/tts_cache_repository.dart';
import '../../../services/read_aloud_diagnostics.dart';
import 'read_aloud_engine.dart';

/// 前台优先的有界合成队列；不保存正文位置、不调用播放器。— Codex + UI
final class ReadAloudSynthesisQueue {
  ReadAloudSynthesisQueue({required this.synthesize, required this.cache});
  final Future<HttpTtsSynthesisResult> Function(
    ReadAloudRequest,
    HttpTtsCancellation,
  )
  synthesize;
  final TtsCacheRepository Function() cache;
  final _jobs = <_Job>[];
  int _running = 0, _limit = 1, _window = 0;
  String? _windowKey;
  final _diagnostics = <String>[];
  final _idleWaiters = <Completer<void>>[];
  bool isWindowCurrent(String key) => key == _windowKey;
  Future<void> whenIdle() {
    if (_running == 0) return Future.value();
    final waiter = Completer<void>();
    _idleWaiters.add(waiter);
    return waiter.future;
  }

  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  void _log(Object error) {
    _diagnostics.add('预合成失败：$error');
    if (_diagnostics.length > 100) _diagnostics.removeAt(0);
  }

  String _key(ReadAloudRequest r) => jsonEncode([
    r.engineId,
    r.engineUrl,
    r.sourceVersion,
    r.text,
    r.pitch,
    r.volume,
    r.voiceName,
    r.toneId,
    r.speakerName,
    r.emotionTag,
    r.voicePresetId,
    r.cloudVoiceOptions,
  ]);
  void configure(int limit) {
    _limit = limit.clamp(1, 8);
  }

  Future<HttpTtsSynthesisResult> foreground(
    ReadAloudRequest request,
    HttpTtsCancellation cancellation,
  ) {
    final key = _key(request);
    final existing = _jobs
        .where((j) => j.key == key && !j.cancel.isCancelled && !j.foreground)
        .firstOrNull;
    final job = existing ?? _Job(key, request, _window);
    job.foreground = true;
    job.request = request;
    if (existing == null) _jobs.insert(0, job);
    void cancel() {
      job.cancel.cancel();
      if (!job.running && !job.result.isCompleted) {
        _jobs.remove(job);
        job.result.complete(const HttpTtsCancelled());
      }
    }

    cancellation.addListener(cancel);
    if (_running >= _limit && !job.running) {
      final victim = _jobs
          .where((j) => j.running && !j.foreground && !j.cancel.isCancelled)
          .lastOrNull;
      victim?.cancel.cancel();
    }
    _pump();
    return job.result.future.whenComplete(
      () => cancellation.removeListener(cancel),
    );
  }

  void _pump() {
    while (_running < _limit) {
      final queued = _jobs
          .where((j) => !j.running && !j.result.isCompleted)
          .toList();
      if (queued.isEmpty) return;
      queued.sort(
        (a, b) => a.foreground == b.foreground ? 0 : (a.foreground ? -1 : 1),
      );
      final job = queued.first;
      if (job.cancel.isCancelled) {
        _jobs.remove(job);
        job.result.complete(const HttpTtsCancelled());
        continue;
      }
      job.running = true;
      _running++;
      unawaited(_run(job));
    }
  }

  Future<HttpTtsSynthesisResult> _attempt(_Job job) async {
    final r = job.request;
    try {
      ReadAloudDiagnostics.instance.count(
        job.foreground
            ? 'synthesis.foreground_attempt'
            : 'synthesis.background_attempt',
      );
      return await synthesize(r, job.cancel);
    } catch (error) {
      if (job.foreground) rethrow;
      return HttpTtsNoAudio(
        HttpTtsNoAudioReason.synthesisFailed,
        synthesisError: error,
      );
    }
  }

  Future<void> _run(_Job job) async {
    HttpTtsAudio? audio;
    final trace = ReadAloudDiagnostics.instance.begin('synthesis.job', {
      'queue': identityHashCode(this),
      'job': identityHashCode(job),
      'foreground': job.foreground,
      'running': _running,
      'limit': _limit,
      'window': job.window,
      'textUnits': job.request.text.length,
      'pending': _jobs.length,
    });
    String outcome = 'error';
    bool? fromCache;
    try {
      var result = await _attempt(job);
      if (!job.foreground &&
          result is HttpTtsNoAudio &&
          !job.cancel.isCancelled) {
        // 对照上游：后台合成失败等待 500ms 后重试一次，取消立即唤醒。
        final wake = Completer<void>();
        final timer = Timer(
          const Duration(milliseconds: 500),
          () => wake.complete(),
        );
        void cancel() {
          if (!wake.isCompleted) wake.complete();
        }

        job.cancel.addListener(cancel);
        await wake.future;
        timer.cancel();
        job.cancel.removeListener(cancel);
        if (!job.cancel.isCancelled) result = await _attempt(job);
      }
      if (result is HttpTtsAudio) audio = result;
      outcome = result is HttpTtsAudio
          ? 'audio'
          : result is HttpTtsCancelled
          ? 'cancelled'
          : 'no_audio';
      fromCache = audio?.fromCache;
      if (job.cancel.isCancelled ||
          (!job.foreground && job.window != _window)) {
        job.result.complete(const HttpTtsCancelled());
      } else {
        final context = job.request.cacheContext;
        if (audio != null && context != null) {
          try {
            await cache().record(audio.audioPath, context);
          } catch (error) {
            _log(error);
          }
        }
        if (job.cancel.isCancelled) {
          job.result.complete(const HttpTtsCancelled());
        } else {
          if (result is HttpTtsNoAudio && !job.foreground) {
            _log(result.synthesisError ?? '没有音频');
          }
          job.result.complete(result);
          if (job.foreground && audio != null) audio = null; // 租约交给播放器。
        }
      }
    } catch (error, stack) {
      if (job.foreground && !job.cancel.isCancelled) {
        job.result.completeError(error, stack);
      } else {
        if (!job.cancel.isCancelled) _log(error);
        job.result.complete(const HttpTtsCancelled());
      }
    } finally {
      ReadAloudDiagnostics.instance.count('synthesis.completed');
      if (fromCache == true) {
        ReadAloudDiagnostics.instance.count('synthesis.cache_hit');
      }
      trace?.finish({
        'outcome': outcome,
        'fromCache': fromCache,
        'cancelled': job.cancel.isCancelled,
        'foreground': job.foreground,
      });
      try {
        await audio?.lease?.release();
      } catch (error) {
        _log(error);
      }
      _jobs.remove(job);
      _running--;
      _pump();
      if (_running == 0) {
        for (final waiter in _idleWaiters) {
          waiter.complete();
        }
        _idleWaiters.clear();
      }
    }
  }

  /// 同一章节窗口在自然换段时复用；换书、源或几何无关合成参数时取消旧窗。
  void startWindow({
    required String key,
    required int concurrency,
    required Stream<List<ReadAloudRequest>> chapters,
  }) {
    _limit = concurrency.clamp(1, 8);
    if (_windowKey == key) {
      _pump();
      return;
    }
    cancelBackground();
    _windowKey = key;
    ReadAloudDiagnostics.instance.event('synthesis.window_start', {
      'queue': identityHashCode(this),
      'window': _window,
      'limit': _limit,
    });
    final generation = _window;
    unawaited(_fill(chapters, generation));
  }

  Future<void> _fill(
    Stream<List<ReadAloudRequest>> chapters,
    int generation,
  ) async {
    var consecutiveFailures = 0;
    try {
      await for (final requests in chapters) {
        if (generation != _window) return;
        ReadAloudDiagnostics.instance.event('synthesis.chapter_batch', {
          'queue': identityHashCode(this),
          'window': generation,
          'requests': requests.length,
          'textUnits': requests.fold<int>(0, (sum, r) => sum + r.text.length),
        });
        var failures = 0;
        // 工作数量有界：每批最多并发上限，不为整章创建成千上万个 Future。
        for (var start = 0; start < requests.length; start += _limit) {
          if (generation != _window) return;
          final batch = <_Job>[];
          for (final r in requests.skip(start).take(_limit)) {
            final job = _Job(_key(r), r, generation);
            _jobs.add(job);
            batch.add(job);
          }
          _pump();
          for (final job in batch) {
            final result = await job.result.future;
            if (result is! HttpTtsAudio) failures++;
          }
        }
        consecutiveFailures = failures > requests.length / 2
            ? consecutiveFailures + 1
            : 0;
        if (consecutiveFailures >= 3) {
          _log('连续三章合成失败，停止预合成');
          return;
        }
      }
    } catch (error) {
      if (generation == _window) _log(error);
    }
  }

  void cancelBackground() {
    ReadAloudDiagnostics.instance.event('synthesis.window_cancel', {
      'queue': identityHashCode(this),
      'window': _window,
      'running': _running,
      'pending': _jobs.length,
    });
    _window++;
    _windowKey = null;
    for (final job in List<_Job>.of(_jobs)) {
      if (!job.foreground) {
        job.cancel.cancel();
        if (!job.running) {
          _jobs.remove(job);
          job.result.complete(const HttpTtsCancelled());
        }
      }
    }
  }

  void cancelAll() {
    cancelBackground();
    for (final job in List<_Job>.of(_jobs)) {
      job.cancel.cancel();
      if (!job.running) {
        _jobs.remove(job);
        job.result.complete(const HttpTtsCancelled());
      }
    }
  }
}

final class _Job {
  _Job(this.key, this.request, this.window);
  final String key;
  ReadAloudRequest request;
  final int window;
  final cancel = HttpTtsCancellation();
  final result = Completer<HttpTtsSynthesisResult>();
  bool foreground = false, running = false;
}
