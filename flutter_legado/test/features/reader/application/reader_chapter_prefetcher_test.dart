import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/domain/models/download_settings.dart';
import 'package:flutter_legado/src/features/reader/application/reader_chapter_prefetcher.dart';
import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Content extends Mock implements ChapterContentService {}

void main() {
  late _Content content;
  late ReaderChapterPrefetcher queue;
  late List<(String, int)> calls;
  late List<Completer<String>> gates;
  final state = ReaderState(
    currentBook: const Book(
      bookUrl: 'https://book/1',
      origin: 'https://source/1',
    ),
    currentChapterIndex: 3,
    chapters: List.generate(
      10,
      (i) => BookChapter(url: 'https://chapter/$i', index: i),
    ),
  );
  setUp(() {
    content = _Content();
    calls = [];
    gates = [];
    when(() => content.read(any(), any())).thenAnswer((invocation) {
      calls.add((
        invocation.positionalArguments[0] as String,
        invocation.positionalArguments[1] as int,
      ));
      final gate = Completer<String>();
      gates.add(gate);
      return gate.future;
    });
    queue = ReaderChapterPrefetcher(content);
    addTearDown(() {
      queue.dispose();
      for (final gate in gates) {
        if (!gate.isCompleted) gate.complete('正文');
      }
    });
  });
  Future<void> finish(int index, {bool fail = false}) async {
    if (fail) {
      gates[index].completeError(StateError('抓取失败'));
    } else {
      gates[index].complete('正文');
    }
    await Future<void>.delayed(Duration.zero);
  }

  test('按设置和距离有界调度，重复窗口合并在途及成功请求', () async {
    const settings = DownloadSettings(preDownloadNum: 3, preDownloadNumPrev: 2);
    queue.plan(state, settings);
    expect(calls.map((c) => c.$2), [4, 2]);
    queue.plan(state, settings);
    expect(calls, hasLength(2));
    await finish(0);
    expect(calls.map((c) => c.$2), [4, 2, 5]);
    await finish(1);
    await finish(2);
    await finish(3);
    await finish(4);
    expect(calls.map((c) => c.$2), [4, 2, 5, 1, 6]);
    queue.plan(state, settings);
    expect(calls, hasLength(5));
  });

  test('数量为0关闭，本地书不调度；首尾章不越界', () async {
    queue.plan(state, const DownloadSettings(preDownloadNum: 0));
    queue.plan(
      state.copyWith(
        currentBook: state.currentBook!.copyWith(bookType: BookType.local),
      ),
      const DownloadSettings(),
    );
    queue.plan(
      state.copyWith(
        currentBook: state.currentBook!.copyWith(origin: BookType.localTag),
      ),
      const DownloadSettings(),
    );
    expect(calls, isEmpty);
    queue.plan(
      state.copyWith(currentChapterIndex: 0),
      const DownloadSettings(preDownloadNum: 1, preDownloadNumPrev: 100),
    );
    expect(calls.map((c) => c.$2), [1]);
    await finish(0);
    queue.plan(
      state.copyWith(currentChapterIndex: 9),
      const DownloadSettings(preDownloadNum: 100, preDownloadNumPrev: 1),
    );
    expect(calls.map((c) => c.$2), [1, 8]);
  });

  test('关闭或销毁后，在途请求收尾不再拉取旧窗口', () async {
    queue.plan(state, const DownloadSettings());
    expect(calls, hasLength(2));
    queue.plan(state, const DownloadSettings(preDownloadNum: 0));
    await finish(0);
    await finish(1);
    expect(calls, hasLength(2));
    queue.plan(state, const DownloadSettings());
    queue.dispose();
    await finish(2);
    await finish(3);
    expect(calls, hasLength(4));
  });

  test('切书后只推进新窗口，旧任务仍计入并发上限', () async {
    queue.plan(state, const DownloadSettings());
    final other = state.copyWith(
      currentBook: state.currentBook!.copyWith(bookUrl: 'https://book/2'),
    );
    queue.plan(other, const DownloadSettings(preDownloadNum: 1));
    expect(calls, hasLength(2));
    await finish(0);
    expect(calls, [
      ('https://book/1', 4),
      ('https://book/1', 5),
      ('https://book/2', 4),
    ]);
    await finish(1);
    expect(calls, hasLength(3));
  });

  test('换源不能复用旧源在途身份，失败后仍推进后续章', () async {
    queue.plan(state, const DownloadSettings(preDownloadNum: 3));
    final other = state.copyWith(
      currentBook: state.currentBook!.copyWith(origin: 'https://source/2'),
    );
    queue.plan(other, const DownloadSettings(preDownloadNum: 3));
    await finish(0, fail: true);
    expect(calls.map((c) => c.$2), [4, 5, 4]);
    await finish(1);
    await finish(2, fail: true);
    expect(calls.map((c) => c.$2), [4, 5, 4, 5, 6]);
  });
}
