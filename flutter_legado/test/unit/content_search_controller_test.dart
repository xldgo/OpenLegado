import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/search/application/content_search_controller.dart';
import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';

class _History extends Mock implements SearchHistoryRepository {}

class _Search implements ContentSearchService {
  final calls =
      <
        ({
          String book,
          String query,
          bool regex,
          bool replace,
          ContentSearchScope scope,
          int current,
        })
      >[];
  final streams = <StreamController<ContentSearchBatch>>[];
  final cancelled = <int>[];
  final closing = <int, Completer<void>>{};
  @override
  Stream<ContentSearchBatch> search({
    required String bookUrl,
    required String query,
    required bool useRegex,
    required bool useReplace,
    required ContentSearchScope scope,
    required int currentChapterIndex,
  }) {
    final index = streams.length;
    calls.add((
      book: bookUrl,
      query: query,
      regex: useRegex,
      replace: useReplace,
      scope: scope,
      current: currentChapterIndex,
    ));
    final stream = StreamController<ContentSearchBatch>(
      onCancel: () {
        cancelled.add(index);
        return closing[index]?.future;
      },
    );
    streams.add(stream);
    return stream.stream;
  }
}

const hit = ContentSearchHit(
  sourceStart: 3,
  sourceEnd: 6,
  snippet: '甲关键词乙',
  highlightStart: 1,
  highlightEnd: 4,
);
const batch = ContentSearchBatch(
  chapterIndex: 2,
  chapterTitle: '第三章',
  hits: [hit],
  scanned: 3,
  total: 5,
);
Future<void> pump() => Future<void>.delayed(Duration.zero);
void main() {
  late _History history;
  late _Search service;
  late ContentSearchController controller;
  late List<String> errors;
  setUp(() {
    history = _History();
    service = _Search();
    errors = [];
    when(() => history.addSearchKeyword(any(), any())).thenAnswer((_) async {});
    controller = ContentSearchController(
      bookUrl: 'book',
      bookName: '书',
      history: history,
      matching: service,
      log: (op, e, s) => errors.add(op),
    );
  });
  tearDown(() async {
    controller.dispose();
    for (final done in service.closing.values) {
      if (!done.isCompleted) done.complete();
    }
    for (final stream in service.streams) {
      await stream.close();
    }
  });
  Future<void> search(
    String query, {
    ContentSearchScope scope = ContentSearchScope.network,
    bool replace = false,
    bool regex = false,
  }) => controller.search(
    query,
    currentChapterIndex: 2,
    useRegex: regex,
    useReplace: replace,
    scope: scope,
  );
  test('选项完整传入原生，增量结果/诊断/进度和截断状态由批次驱动', () async {
    final running = search(
      '  关键词  ',
      scope: ContentSearchScope.cached,
      replace: true,
      regex: true,
    );
    expect(service.calls.single, (
      book: 'book',
      query: '关键词',
      regex: true,
      replace: true,
      scope: ContentSearchScope.cached,
      current: 2,
    ));
    service.streams.single.add(const ContentSearchBatch(scanned: 0, total: 5));
    service.streams.single.add(batch);
    service.streams.single.add(
      const ContentSearchBatch(
        chapterIndex: 3,
        chapterTitle: '第四章',
        scanned: 4,
        total: 5,
        error: '离线',
      ),
    );
    service.streams.single.add(
      const ContentSearchBatch(
        chapterIndex: 4,
        chapterTitle: '第五章',
        hits: [hit],
        scanned: 5,
        total: 5,
        limitReached: true,
      ),
    );
    await service.streams.single.close();
    await running;
    expect(controller.state.results.map((r) => r.chapterIndex), [2, 4]);
    expect(controller.state.results.first.hit, same(hit));
    expect(
      (
        controller.state.scanned,
        controller.state.total,
        controller.state.limitReached,
        controller.state.searching,
      ),
      (5, 5, true, false),
    );
    expect(errors, ['搜索章节3']);
    expect(() => controller.state.results.clear(), throwsUnsupportedError);
    verify(() => history.addSearchKeyword('关键词', '书')).called(1);
  });
  test('新搜索独立启动，旧订阅取消尚未结束也不能覆盖新查询', () async {
    final old = search('旧');
    service.closing[0] = Completer<void>();
    final latest = search('新');
    expect(service.cancelled, [0]);
    service.streams.first.add(batch);
    service.streams.last.add(batch);
    await service.streams.last.close();
    await latest;
    await old;
    expect(controller.state.query, '新');
    expect(controller.state.results, hasLength(1));
    service.closing[0]!.complete();
    await pump();
    expect(controller.state.query, '新');
  });
  test('停止保留已有结果，清空和页面销毁各取消当前订阅', () async {
    var running = search('关键词');
    service.streams.last.add(batch);
    await pump();
    controller.cancel();
    await running;
    expect(controller.state.results, hasLength(1));
    expect(controller.state.searching, false);
    running = search('再次');
    controller.clear();
    await running;
    service.streams.last.add(batch);
    await pump();
    expect(controller.state.query, '');
    expect(controller.state.results, isEmpty);
    running = search('退出');
    controller.dispose();
    await running;
    expect(service.cancelled, [0, 1, 2]);
  });
  test('空结果和整体错误结束加载，不让失败查询卡住', () async {
    var running = search('[', regex: true);
    await service.streams.last.close();
    await running;
    expect(controller.state.results, isEmpty);
    expect(controller.state.searching, false);
    running = search('故障');
    service.streams.last.addError(StateError('数据库关闭'));
    await running;
    expect(controller.state.searching, false);
    expect(errors, ['正文搜索']);
  });
}
