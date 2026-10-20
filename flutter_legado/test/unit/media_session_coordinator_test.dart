import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

import '../fixtures/media_session_coordinator_fixture.dart';

void main() {
  late MediaSessionFixture fixture;
  late List<MediaSessionFixture> instances;

  void testSession(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      fixture = MediaSessionFixture();
      instances = [fixture];
      try {
        await body(tester);
      } finally {
        for (final instance in instances) {
          await instance.close();
        }
      }
    });
  }

  testSession('独立初始化合并并发请求，重复调用不重复订阅', (tester) async {
    final gate = Completer<void>();
    fixture.audio.initBarrier = gate.future;
    final first = fixture.coordinator.init();
    final second = fixture.coordinator.init();
    expect(fixture.audio.initCount, 1);
    gate.complete();
    await Future.wait([first, second]);
    await fixture.coordinator.init();
    expect(fixture.state.isMediaSessionReady, isTrue);
    expect(fixture.audio.initCount, 1);
    fixture.audio.buttons.add(MediaButtonEvent.pause);
    await tester.pump();
    expect(fixture.actions, ['暂停']);
  });

  testSession('暂停等待原生屏障，期间新播放接管后旧暂停不释放焦点', (tester) async {
    await fixture.start();
    final paused = Completer<void>();
    fixture.coordinator.preparePause();
    fixture.state = fixture.state.copyWith(state: PlayerState.paused);
    final releasing = fixture.coordinator.notifyPaused(after: paused.future);
    await tester.pump();
    expect(fixture.audio.focusAbandons, 0);
    fixture.token++;
    fixture.coordinator.prepareResume();
    fixture.state = fixture.state.copyWith(state: PlayerState.playing);
    await fixture.coordinator.activate();
    paused.complete();
    await releasing;
    expect(fixture.audio.focusAbandons, 0);
  });

  testSession('停止等待原生音频结束后释放，迟到停止不释放新会话', (tester) async {
    await fixture.start();
    final stopped = Completer<void>();
    fixture.token++;
    fixture.coordinator.invalidate();
    fixture.state = fixture.state.copyWith(state: PlayerState.idle);
    fixture.coordinator.notifyStopped(after: stopped.future);
    await tester.pump();
    expect(fixture.audio.focusAbandons, 0);
    stopped.complete();
    await tester.pump();
    expect(fixture.audio.focusAbandons, 1);
    await fixture.start();
    final late = Completer<void>();
    fixture.state = fixture.state.copyWith(state: PlayerState.idle);
    fixture.coordinator.notifyStopped(after: late.future);
    fixture.token++;
    await fixture.start();
    late.complete();
    await tester.pump();
    expect(fixture.audio.focusAbandons, 1);
  });

  testSession('媒体按钮按设置切段或切章，音频书始终按章', (tester) async {
    await fixture.start(stream: false);
    fixture.audio.buttons.add(MediaButtonEvent.skipToNext);
    await tester.pump();
    fixture.audio.buttons.add(MediaButtonEvent.skipToPrevious);
    await tester.pump();
    expect(fixture.actions, ['下一段', '上一段']);
    fixture.perChapter = true;
    fixture.audio.buttons.add(MediaButtonEvent.skipToNext);
    await tester.pump();
    fixture.audio.buttons.add(MediaButtonEvent.skipToPrevious);
    await tester.pump();
    expect(fixture.actions.sublist(2), ['下一章', '上一章']);
    fixture.perChapter = false;
    fixture.state = fixture.state.copyWith(isStreamMode: true);
    fixture.audio.buttons.add(MediaButtonEvent.skipToNext);
    await tester.pump();
    expect(fixture.actions.last, '下一章');
    expect(fixture.preferencesLoads, 5);
    fixture.audio.buttons.add(MediaButtonEvent.pause);
    await tester.pump();
    fixture.audio.buttons.add(MediaButtonEvent.play);
    await tester.pump();
    fixture.audio.buttons.add(MediaButtonEvent.stop);
    await tester.pump();
    expect(fixture.actions.sublist(5), ['暂停', '恢复', '停止']);
    expect(fixture.state.state, PlayerState.idle);
    expect(fixture.audio.focusAbandons, 2);
  });

  testSession('中断期间切换会话，旧 gain 不恢复新书；重复中断保留同次恢复意图', (tester) async {
    await fixture.start();
    fixture.audio.focus.add(AudioFocusEvent.lossTransient);
    await tester.pump();
    fixture.audio.focus.add(AudioFocusEvent.lossTransient);
    await tester.pump();
    fixture.audio.focus.add(AudioFocusEvent.gain);
    await tester.pump();
    expect(fixture.actions, ['暂停', '恢复']);
    fixture.audio.focus.add(AudioFocusEvent.lossTransient);
    await tester.pump();
    fixture.token++;
    fixture.state = fixture.state.copyWith(bookUrl: '另一书');
    fixture.audio.focus.add(AudioFocusEvent.gain);
    await tester.pump();
    expect(fixture.actions, ['暂停', '恢复', '暂停']);
    expect(fixture.state.state, PlayerState.paused);
  });

  testSession('临时焦点中断恢复，手动暂停及永久失焦取消恢复，duck保持播放', (tester) async {
    await fixture.start();
    fixture.audio.focus.add(AudioFocusEvent.lossTransient);
    await tester.pump();
    expect(fixture.state.state, PlayerState.paused);
    fixture.audio.focus.add(AudioFocusEvent.gain);
    await tester.pump();
    expect(fixture.state.state, PlayerState.playing);
    fixture.audio.focus.add(AudioFocusEvent.lossTransientCanDuck);
    await tester.pump();
    expect(fixture.actions, ['暂停', '恢复']);
    fixture.audio.focus.add(AudioFocusEvent.lossTransient);
    await tester.pump();
    fixture.pause();
    fixture.audio.focus.add(AudioFocusEvent.gain);
    await tester.pump();
    expect(fixture.state.state, PlayerState.paused);
    await fixture.resume();
    fixture.audio.focus.add(AudioFocusEvent.loss);
    await tester.pump();
    fixture.audio.focus.add(AudioFocusEvent.gain);
    await tester.pump();
    expect(fixture.actions.where((action) => action == '恢复'), hasLength(2));
    expect(fixture.state.state, PlayerState.paused);
  });

  testSession('标题章节与定时独立去重，同书切章复用封面', (tester) async {
    await fixture.start();
    final initialCount = fixture.audio.metadata.length;
    await fixture.coordinator.activate();
    expect(fixture.audio.metadata, hasLength(initialCount));
    fixture.timerLabel = '剩余 3 章';
    await fixture.coordinator.updateMetadata();
    expect(fixture.audio.metadata.last.title, '测试书');
    expect(fixture.audio.metadata.last.artist, '第一章');
    expect(fixture.audio.metadata.last.timerText, '剩余 3 章');
    await fixture.chapter(1);
    await fixture.coordinator.updateMetadata();
    expect(fixture.audio.metadata.last.artist, '第二章');
    expect(fixture.artwork.requests, hasLength(1));
    await fixture.coordinator.setWakeLock(true);
    expect(fixture.audio.wakeLock, isTrue);
  });

  testSession('停止重播更换身份，迟到的封面不能覆盖当前会话', (tester) async {
    final old = Completer<Uint8List?>(), current = Completer<Uint8List?>();
    fixture.artwork.resolve = (_, _) =>
        fixture.artwork.requests.length == 1 ? old.future : current.future;
    await fixture.start();
    final previousTarget = fixture.target;
    fixture.stop();
    await fixture.start();
    expect(fixture.target.sessionToken, isNot(previousTarget.sessionToken));
    old.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(fixture.audio.artwork, isEmpty);
    current.complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(fixture.audio.artwork.single.bytes, [2]);
    expect(fixture.coordinator.ownsTarget(previousTarget), isFalse);
  });

  testSession('隐私锁定隐藏标题和章节，过滤锁定前的封面', (tester) async {
    final old = Completer<Uint8List?>();
    fixture.artwork.resolve = (_, hidden) =>
        hidden ? Future.value(null) : old.future;
    await fixture.start();
    final previousTarget = fixture.target;
    fixture.hidden = true;
    await fixture.coordinator.updateMetadata();
    await tester.pump();
    expect(fixture.audio.metadata.last.title, '私密书籍');
    expect(fixture.audio.metadata.last.artist, isEmpty);
    expect(fixture.artwork.requests.last.hidden, isTrue);
    old.complete(Uint8List.fromList([9]));
    await tester.pump();
    expect(fixture.audio.artwork.every((call) => call.bytes == null), isTrue);
    expect(fixture.coordinator.ownsTarget(previousTarget), isFalse);
  });

  testSession('周期进度节流与去重，暂停状态及时发布，停止后取消时钟', (tester) async {
    await fixture.start();
    final calls = fixture.audio.progress.length;
    fixture.clock = 100;
    fixture.state = fixture.state.copyWith(positionMs: 5000);
    await tester.pump();
    expect(fixture.audio.progress, hasLength(calls));
    fixture.clock = 1100;
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.audio.progress.last.position, 5000);
    expect(fixture.audio.progress.last.duration, 60000);
    fixture.pause();
    await tester.pump();
    expect(fixture.audio.progress.last.state, 'paused');
    final pausedCount = fixture.audio.progress.length;
    fixture.clock = 2200;
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.audio.progress, hasLength(pausedCount));
    fixture.stop();
    fixture.clock = 4000;
    await tester.pump(const Duration(seconds: 2));
    expect(fixture.audio.progress, hasLength(pausedCount));
  });

  testSession('系统音频定位保留暂停并写回，拒绝旧章和未知时长', (tester) async {
    await fixture.start();
    fixture.pause();
    final target = fixture.target;
    fixture.audio.seeks.add(MediaSeekRequest(target: target, position: 25000));
    await tester.pump();
    expect(fixture.player.lastSeekPosition, const Duration(seconds: 25));
    expect(fixture.state.positionMs, 25000);
    expect(fixture.state.state, PlayerState.paused);
    expect(fixture.saves.single, (position: 25000, force: true));
    await fixture.chapter(1);
    await fixture.coordinator.seek(
      MediaSeekRequest(target: target, position: 10000),
    );
    expect(fixture.player.seekCount, 1);
    fixture.state = fixture.state.copyWith(durationMs: 0);
    await fixture.coordinator.updateMetadata();
    await fixture.coordinator.seek(
      MediaSeekRequest(target: fixture.target, position: 10000),
    );
    expect(fixture.player.seekCount, 1);
  });

  testSession('连续系统定位最终落在最新请求，停止后的请求不执行', (tester) async {
    await fixture.start();
    final target = fixture.target;
    final gate = Completer<void>();
    fixture.player.seekBarrier = gate.future;
    final first = fixture.coordinator.seek(
      MediaSeekRequest(target: target, position: 10000),
    );
    await tester.pump();
    final second = fixture.coordinator.seek(
      MediaSeekRequest(target: target, position: 20000),
    );
    gate.complete();
    fixture.player.seekBarrier = null;
    await Future.wait([first, second]);
    expect(fixture.state.positionMs, 20000);
    expect(fixture.saves, [(position: 20000, force: true)]);
    fixture.stop();
    final count = fixture.player.seekCount;
    await fixture.coordinator.seek(
      MediaSeekRequest(target: target, position: 30000),
    );
    expect(fixture.player.seekCount, count);
  });

  testSession('正文进度从原文派生，系统定位不启动播放器或恢复暂停', (tester) async {
    fixture.setPosition(8);
    await fixture.start(stream: false);
    expect(fixture.audio.progress.last.position, 2000);
    expect(fixture.audio.progress.last.duration, 10000);
    expect(fixture.audio.progress.last.speed, 1);
    fixture.pause();
    await fixture.coordinator.seek(
      MediaSeekRequest(target: fixture.target, position: 1000),
    );
    expect(fixture.sourceSeeks, [(0, 4)]);
    expect(fixture.audio.progress.last.position, 1000);
    expect(fixture.state.state, PlayerState.paused);
    expect(fixture.player.seekCount, 0);
    expect(fixture.player.resumeCount, 0);
    expect(fixture.player.playedLocalFiles, isEmpty);
  });

  testSession('释放取消订阅和周期刷新，可重新初始化且不复用旧身份', (tester) async {
    await fixture.start();
    final old = fixture.target;
    await fixture.coordinator.release();
    expect(fixture.state.isMediaSessionReady, isFalse);
    expect(fixture.audio.buttons.hasListener, isFalse);
    expect(fixture.audio.focus.hasListener, isFalse);
    expect(fixture.audio.seeks.hasListener, isFalse);
    final progressCount = fixture.audio.progress.length;
    fixture.audio.buttons.add(MediaButtonEvent.stop);
    fixture.clock = 2000;
    await tester.pump(const Duration(seconds: 2));
    expect(fixture.actions, isEmpty);
    expect(fixture.audio.progress, hasLength(progressCount));
    await fixture.start();
    expect(fixture.audio.initCount, 2);
    expect(fixture.coordinator.ownsTarget(old), isFalse);
    fixture.audio.buttons.add(MediaButtonEvent.pause);
    await tester.pump();
    expect(fixture.actions, ['暂停']);
  });

  testSession('独立实例互不干扰，幂等销毁后不再访问宿主或发布迟到封面', (tester) async {
    final pending = Completer<Uint8List?>();
    fixture.artwork.resolve = (_, _) => pending.future;
    await fixture.start();
    final second = MediaSessionFixture();
    instances.add(second);
    await second.start();
    fixture.hostDisposed = true;
    fixture.coordinator.dispose();
    fixture.coordinator.dispose();
    pending.complete(Uint8List.fromList([1]));
    await tester.pump(const Duration(seconds: 2));
    await fixture.coordinator.publishProgress();
    await fixture.coordinator.updateMetadata();
    await fixture.coordinator.activate();
    expect(fixture.audio.releaseCount, 1);
    expect(fixture.audio.artwork, isEmpty);
    second.audio.buttons.add(MediaButtonEvent.pause);
    await tester.pump();
    expect(second.state.state, PlayerState.paused);
    expect(fixture.audio.buttons.hasListener, isFalse);
  });
}
