import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';

import '../fixtures/read_aloud_controller_fixture.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late ReadAloudControllerFixture fixture;
  setUp(() {
    fixture = ReadAloudControllerFixture();
    addTearDown(() async {
      fixture.dispose();
      await flushReadAloud();
    });
  });

  test('控制器独立加载纯正文并发布原文位置，不持有第二份书章状态', () async {
    await fixture.controller.play();
    expect(fixture.system.texts, ['第一段。']);
    expect(fixture.controller.currentParagraphs, ['第一段。', '第二段。']);
    expect(fixture.state.chapters[0].text, ReadAloudControllerFixture.first);
    fixture.system.onProgress!(1, 3);
    expect(fixture.controller.readAloudPosition.value!.offset, 1);
    expect(fixture.controller.readAloudPosition.value!.paragraphEnd, 4);
    expect(fixture.mediaStarts, 1);
  });

  test('自然完成依次切段切章，末章完成交回宿主停止', () async {
    await fixture.controller.play();
    fixture.system.requests[0].complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.system.texts, ['第一段。', '第二段。']);
    fixture.system.requests[1].complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.nextCalls, 1);
    expect(fixture.state.currentIndex, 1);
    expect(fixture.system.texts.last, '新章。');
    fixture.system.requests[2].complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    fixture.system.requests[3].complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.stopCalls, 1);
    expect(fixture.state.state, PlayerState.idle);
    expect(fixture.controller.readAloudPosition.value, isNull);
  });

  test('选中文字定位到原文段落，开始位置不进入第一段', () async {
    fixture.controller.beginSession();
    await fixture.controller.locateStart(text: '第二段。');
    await fixture.controller.play();
    expect(fixture.system.texts, ['第二段。']);
    expect(fixture.controller.currentParagraphIndex, 1);
    expect(fixture.controller.readAloudPosition.value!.offset, 6);
  });

  test('暂停恢复等待平台确认，暂停前完成回调不推进段落', () async {
    await fixture.controller.play();
    final barrier = Completer<void>();
    fixture.system.pauseBarrier = barrier.future;
    fixture.pause();
    final resumed = fixture.resume();
    await flushReadAloud();
    expect(fixture.system.texts, hasLength(1));
    fixture.system.requests.first.complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.controller.currentParagraphIndex, 0);
    barrier.complete();
    await resumed;
    expect(fixture.system.texts, ['第一段。', '第一段。']);
    expect(fixture.state.state, PlayerState.playing);
  });

  test('暂停定位原文后保持暂停，恢复只朗读新位置后缀', () async {
    await fixture.controller.play();
    fixture.pause();
    await flushReadAloud();
    await fixture.controller.seekToChapterPosition(1, 1);
    expect(fixture.state.state, PlayerState.paused);
    expect(fixture.system.texts, hasLength(1));
    expect(fixture.controller.readAloudPosition.value!.offset, 1);
    await fixture.resume();
    expect(fixture.system.texts.last, '章。');
  });

  test('系统切HTTP后旧系统完成不能跳段，复用现有文件引擎', () async {
    await fixture.controller.play();
    fixture.engineUrl = 'https://tts.test';
    await fixture.controller.restart();
    await flushReadAloud();
    expect(fixture.synthesis.inputs.first, '第一段。');
    expect(fixture.player.playedLocalFiles, hasLength(1));
    fixture.system.requests.first.complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.controller.currentParagraphIndex, 0);
    expect(fixture.player.playedLocalFiles, hasLength(1));
    fixture.player.completePlayback();
    await flushReadAloud();
    expect(fixture.controller.currentParagraphIndex, 1);
    expect(fixture.player.playedLocalFiles, hasLength(2));
  });

  test('停止清理段落且已停止的系统完成不会自动续播', () async {
    await fixture.controller.play();
    fixture.stop();
    fixture.system.requests.first.complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.state.state, PlayerState.idle);
    expect(fixture.controller.currentParagraphs, isEmpty);
    expect(fixture.controller.readAloudPosition.value, isNull);
    expect(fixture.system.texts, hasLength(1));
  });

  test('HTTP预合成按原窗口读取后续章，不提前播放或改写当前章号', () async {
    fixture.engineUrl = 'https://tts.test';
    await fixture.controller.play();
    await flushReadAloud();
    expect(fixture.synthesis.inputs, ['第一段。', '第二段。', '新章。', '末段。']);
    expect(fixture.player.playedLocalFiles, hasLength(1));
    expect(fixture.state.currentIndex, 0);
    expect(fixture.cache.records.map((r) => r.chapterIndex), [0, 0, 1, 1]);
  });

  test('读取失败发布原错误，修复后可重新播放', () async {
    when(
      () => fixture.api.readingRepository.getChapterContentFull(any(), any()),
    ).thenThrow(StateError('书源失败'));
    await fixture.controller.play();
    expect(fixture.state.state, PlayerState.error);
    expect(fixture.state.errorMessage, contains('书源失败'));
    when(
      () => fixture.api.readingRepository.getChapterContentFull(any(), any()),
    ).thenAnswer((_) async => '恢复正文。');
    await fixture.controller.play();
    expect(fixture.state.state, PlayerState.playing);
    expect(fixture.system.texts, ['恢复正文。']);
  });

  test('更改分段方式保持原文锚点，不写入独立偏好副本', () async {
    await fixture.controller.play();
    fixture.system.onProgress!(2, 3);
    await fixture.controller.setContentSplit(ReadAloudSplitMode.symbols, '。');
    expect(fixture.settings.current.splitMode, ReadAloudSplitMode.symbols);
    expect(fixture.controller.readAloudPosition.value!.offset, 2);
    expect(fixture.system.texts.last, '段。');
  });

  test('页面重排后按原文锚点恢复，暂停时不提前起播', () async {
    const content = ReadAloudControllerFixture.first;
    await fixture.controller.setContentSplit(ReadAloudSplitMode.page, '');
    fixture.controller.registerPages(fixture.state.bookUrl, 0, content, [
      (start: 0, end: 2),
      (start: 2, end: content.length),
    ]);
    await fixture.controller.play(paragraphIndex: 1);
    expect(fixture.system.texts.last, '段。');
    fixture.system.onProgress!(1, 2);
    fixture.pause();
    await flushReadAloud();
    final starts = fixture.system.texts.length;
    fixture.controller.registerPages(fixture.state.bookUrl, 0, content, [
      (start: 0, end: 3),
      (start: 3, end: content.length),
    ]);
    await flushReadAloud();
    expect(fixture.state.state, PlayerState.paused);
    expect(fixture.controller.readAloudPosition.value!.offset, 3);
    expect(fixture.system.texts, hasLength(starts));
    await fixture.resume();
    expect(fixture.system.texts.last, '。');
  });

  test('章末停止规则优先于下一章与单章循环', () async {
    fixture.stopAtBoundary = true;
    fixture.state = fixture.state.copyWith(mode: AudioPlayMode.singleLoop);
    await fixture.controller.play(paragraphIndex: 1);
    fixture.system.requests.first.complete(SystemTtsOutcome.completed);
    await flushReadAloud();
    expect(fixture.stopCalls, 1);
    expect(fixture.nextCalls, 0);
    expect(fixture.system.texts, ['第二段。']);
  });

  test('独立控制器不共享段落、位置或引擎，释放幂等', () async {
    final other = ReadAloudControllerFixture(bookUrl: 'other-book');
    addTearDown(other.dispose);
    await fixture.controller.play();
    await other.controller.play(paragraphIndex: 1);
    expect(fixture.controller.currentParagraphIndex, 0);
    expect(other.controller.currentParagraphIndex, 1);
    fixture.dispose();
    fixture.dispose();
    await flushReadAloud();
    expect(fixture.system.disposals, 1);
    other.system.onProgress!(1, 3);
    expect(other.controller.readAloudPosition.value!.bookUrl, 'other-book');
  });
}
