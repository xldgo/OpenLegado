import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_synthesis_queue.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_synthesis_adapter.dart';

class _Lease implements TtsAudioLease {
  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
  }
}

class _ReleasedLease implements TtsAudioLease {
  final entered = Completer<void>();
  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
    entered.complete();
  }
}

class _Cache extends Fake implements TtsCacheRepository {
  final contexts = <TtsCacheContext>[];
  @override
  Future<void> record(String path, TtsCacheContext context) async {
    contexts.add(context);
  }
}

class _Synthesis extends Fake implements HttpTtsSynthesizer {
  final texts = <String>[];
  final pending = <String, Completer<HttpTtsSynthesisResult>>{};
  final cancels = <String, HttpTtsCancellation>{};
  int active = 0, peak = 0;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  }) async {
    texts.add(text);
    active++;
    if (active > peak) peak = active;
    final result = Completer<HttpTtsSynthesisResult>();
    pending[text] = result;
    cancels[text] = cancellation!;
    cancellation.addListener(() {
      if (!result.isCompleted) result.complete(const HttpTtsCancelled());
    });
    try {
      return await result.future;
    } finally {
      active--;
    }
  }

  void finish(String text, {TtsAudioLease? lease}) => pending[text]!.complete(
    HttpTtsAudio(audioPath: '/cache/tts_$text.mp3', lease: lease),
  );
}

ReadAloudRequest request(String text, {double speed = 1, String? version}) =>
    ReadAloudRequest(
      text: text,
      engineId: 1,
      engineUrl: 'https://tts',
      speed: speed,
      sourceVersion: version,
      cacheContext: TtsCacheContext(
        bookUrl: 'book',
        bookName: '书',
        chapterIndex: 0,
        chapterTitle: '第一章',
        paragraphIndex: 0,
        text: text,
      ),
    );
Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Synthesis synthesis;
  late _Cache cache;
  late ReadAloudSynthesisQueue queue;
  setUp(() {
    synthesis = _Synthesis();
    cache = _Cache();
    queue = ReadAloudSynthesisQueue(
      synthesize: (r, c) => synthesizeReadAloudRequest(r, c, http: synthesis),
      cache: () => cache,
    );
  });
  test('限制后台并发且逐批推进，不为整章创建无限任务', () async {
    queue.startWindow(
      key: 'a',
      concurrency: 2,
      chapters: Stream.value([for (var i = 0; i < 6; i++) request('$i')]),
    );
    await flush();
    expect(synthesis.texts, ['0', '1']);
    expect(synthesis.peak, 2);
    synthesis.finish('0');
    synthesis.finish('1');
    await flush();
    expect(synthesis.texts, ['0', '1', '2', '3']);
    synthesis.finish('2');
    synthesis.finish('3');
    await flush();
    synthesis.finish('4');
    synthesis.finish('5');
    await flush();
    expect(synthesis.peak, 2);
    expect(cache.contexts, hasLength(6));
  });
  test('当前段提升同输入后台请求，倍速变化不重合成，租约移交一次', () async {
    final lease = _Lease();
    queue.startWindow(
      key: 'a',
      concurrency: 1,
      chapters: Stream.value([request('甲')]),
    );
    await flush();
    final foreground = queue.foreground(
      request('甲', speed: 2),
      HttpTtsCancellation(),
    );
    synthesis.finish('甲', lease: lease);
    final result = await foreground;
    await flush();
    expect(synthesis.texts, ['甲']);
    expect(lease.releases, 0);
    expect(result, isA<HttpTtsAudio>());
    await (result as HttpTtsAudio).lease?.release();
    expect(lease.releases, 1);
  });
  test('后台已完成并开始释放租约时，前台重新获取缓存租约', () async {
    final backgroundLease = _ReleasedLease(), foregroundLease = _Lease();
    var calls = 0;
    final queue = ReadAloudSynthesisQueue(
      synthesize: (r, c) async {
        calls++;
        return HttpTtsAudio(
          audioPath: '/cache/same.wav',
          fromCache: calls > 1,
          lease: calls == 1 ? backgroundLease : foregroundLease,
        );
      },
      cache: () => cache,
    );
    final input = request('甲');
    queue.startWindow(
      key: 'a',
      concurrency: 1,
      chapters: Stream.value([input]),
    );
    await backgroundLease.entered.future;
    final result =
        await queue.foreground(input, HttpTtsCancellation()) as HttpTtsAudio;
    await queue.whenIdle();
    expect(calls, 2);
    expect(result.fromCache, isTrue);
    expect(result.lease, same(foregroundLease));
    expect(backgroundLease.releases, 1);
    expect(foregroundLease.releases, 0);
    await result.lease!.release();
    expect(foregroundLease.releases, 1);
  });

  test('当前段优先于后续段，抢占释放一个后台并发槽', () async {
    queue.startWindow(
      key: 'a',
      concurrency: 1,
      chapters: Stream.value([request('背景1'), request('背景2')]),
    );
    await flush();
    final foreground = queue.foreground(request('当前'), HttpTtsCancellation());
    await flush();
    expect(synthesis.cancels['背景1']!.isCancelled, true);
    expect(synthesis.texts, ['背景1', '当前']);
    synthesis.finish('当前');
    await foreground;
    await flush();
    synthesis.finish('背景2');
    await flush();
    expect(synthesis.peak, 1);
  });
  test('换窗口取消后台请求，旧完成不登记或污染新窗口', () async {
    queue.startWindow(
      key: 'old',
      concurrency: 1,
      chapters: Stream.value([request('旧')]),
    );
    await flush();
    queue.startWindow(
      key: 'new',
      concurrency: 1,
      chapters: Stream.value([request('新')]),
    );
    await flush();
    expect(synthesis.cancels['旧']!.isCancelled, true);
    synthesis.finish('新');
    await flush();
    expect(cache.contexts.map((c) => c.text), ['新']);
  });
  test('源快照不同不提升旧请求，停止取消等待和网络且不报合成失败', () async {
    queue.startWindow(
      key: 'a',
      concurrency: 1,
      chapters: Stream.value([request('甲', version: 'old')]),
    );
    await flush();
    final foreground = queue.foreground(
      request('甲', version: 'new'),
      HttpTtsCancellation(),
    );
    await flush();
    expect(synthesis.texts, hasLength(2));
    queue.cancelAll();
    expect(await foreground, isA<HttpTtsCancelled>());
    await flush();
    expect(queue.diagnostics, isEmpty);
  });
  test('非当前段成功结果登记后释放租约，失败三章停止且不改变前台', () async {
    final lease = _Lease();
    queue.startWindow(
      key: 'audio',
      concurrency: 1,
      chapters: Stream.value([request('甲')]),
    );
    await flush();
    synthesis.finish('甲', lease: lease);
    await flush();
    expect(lease.releases, 1);
    queue.startWindow(
      key: 'fail',
      concurrency: 1,
      chapters: Stream.fromIterable([
        for (var i = 0; i < 5; i++) [request('失败$i')],
      ]),
    );
    for (var i = 0; i < 3; i++) {
      await flush();
      synthesis.pending['失败$i']!.complete(
        const HttpTtsNoAudio(HttpTtsNoAudioReason.synthesisFailed),
      );
      await Future<void>.delayed(const Duration(milliseconds: 550));
      synthesis.pending['失败$i']!.complete(
        const HttpTtsNoAudio(HttpTtsNoAudioReason.synthesisFailed),
      );
    }
    await flush();
    expect(synthesis.texts.where((t) => t.startsWith('失败')), hasLength(6));
    expect(queue.diagnostics.last, contains('连续三章'));
  });
  test('云端同音色请求提升，变更音色拒绝复用旧任务，缓存租约释放一次', () async {
    final pending = <String, Completer<HttpTtsSynthesisResult>>{};
    final queue = ReadAloudSynthesisQueue(
      synthesize: (r, c) {
        final done = Completer<HttpTtsSynthesisResult>();
        pending[r.voicePresetId!] = done;
        c.addListener(() {
          if (!done.isCompleted) done.complete(const HttpTtsCancelled());
        });
        return done.future;
      },
      cache: () => cache,
    );
    ReadAloudRequest cloud(String voice) => ReadAloudRequest(
      text: '甲',
      engineUrl: 'cloud://fixture',
      voicePresetId: voice,
    );
    queue.startWindow(
      key: 'cloud',
      concurrency: 1,
      chapters: Stream.value([cloud('a')]),
    );
    await flush();
    final same = queue.foreground(cloud('a'), HttpTtsCancellation());
    final lease = _Lease();
    pending['a']!.complete(
      HttpTtsAudio(audioPath: '/cache/a.wav', lease: lease),
    );
    final audio = await same as HttpTtsAudio;
    expect(lease.releases, 0);
    await audio.lease!.release();
    expect(lease.releases, 1);
    queue.startWindow(
      key: 'cloud2',
      concurrency: 1,
      chapters: Stream.value([cloud('a')]),
    );
    await flush();
    final changed = queue.foreground(cloud('b'), HttpTtsCancellation());
    await flush();
    expect(pending.keys, contains('b'));
    pending['b']!.complete(const HttpTtsAudio(audioPath: '/cache/b.wav'));
    await changed;
    queue.cancelAll();
    await queue.whenIdle();
  });
}
