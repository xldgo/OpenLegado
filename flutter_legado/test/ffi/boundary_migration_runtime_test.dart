@Tags(['native'])
@Timeout(Duration(minutes: 2))
library;

// 新增领域边界只验真实跨语言传输与装配，算法矩阵仍由Rust单测承担。— Codex + Bridge
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_reading_repository.dart';
import 'package:flutter_legado/src/data/services/rust_read_aloud_planner.dart';
import 'package:flutter_legado/src/data/services/rust_search_aggregation_service.dart';
import 'package:flutter_legado/src/data/services/rust_content_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../helpers/native_ffi.dart';

void main() {
  setUpAll(() async {
    final dir = Directory(
      '.dart_tool/boundary-native-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await RustLib.init(externalLibrary: nativeTestLibrary());
    await bridge.init();
    await bridge.dbOpen(path: '${dir.absolute.path}/data.db');
  });
  tearDownAll(RustLib.dispose);

  test('朗读能力、页面范围及批量请求切分经真实库返回UTF16位置', () async {
    const repo = RustCloudTtsRepository();
    final capabilities = await repo.providerCapabilities();
    expect(capabilities, contains('mimo'));
    expect((await repo.speechLimits('mimo')).maxUtf16Units, greaterThan(0));
    const planner = RustReadAloudPlanner();
    final units = await planner.plan(
      '甲😀\n乙',
      mode: ReadAloudSplitMode.page,
      pages: [(start: 0, end: 3), (start: 3, end: 5)],
    );
    expect(
      units.map(
        (u) =>
            (u.start, u.end, u.text, u.sourceParagraphIndex, u.isParagraphEnd),
      ),
      [(0, 3, '甲😀', 0, true), (4, 5, '乙', 1, true)],
    );
    final parts = await planner.partition('mimo', ['甲😀', '乙']);
    expect(parts, [
      [(start: 0, text: '甲😀')],
      [(start: 0, text: '乙')],
    ]);
    await expectLater(
      planner.plan(
        '甲😀',
        mode: ReadAloudSplitMode.page,
        pages: [(start: 0, end: 2), (start: 2, end: 3)],
      ),
      throwsA(isA<AppException>()),
    );
  });
  test('查询聚合句柄跨批返回投影，首条完整书籍元数据不丢失', () async {
    final session = const RustSearchAggregationService().open('甲');
    try {
      const first = SearchResult(
        book: Book(
          bookUrl: 'first',
          name: '甲',
          author: '作者',
          origin: 'a',
          tocUrl: 'toc',
          variable: '完整变量',
        ),
        sourceName: '首源',
      );
      await session.addAll([first]);
      await session.addAll([
        const SearchResult(
          book: Book(bookUrl: 'second', name: '甲', author: '作者', origin: 'b'),
          hasReadRecord: true,
        ),
      ]);
      final result = (await session.snapshot()).single;
      expect(result.book, first.book);
      expect((result.sourceName, result.hasReadRecord), ('首源', true));
      expect(result.origins, {'a', 'b'});
    } finally {
      await session.close();
    }
  });
  test('正文搜索流可取消旧HTTP，新订阅仍返回真实正文及命中范围', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}';
    final entered = Completer<void>(), release = Completer<void>();
    var requests = 0;
    final serving = server.listen((request) async {
      try {
        request.response.headers.contentType = ContentType.html;
        if (request.uri.path == '/toc') {
          request.response.write(
            "<div class='chapter'><a href='$base/chapter'>第一章</a></div>",
          );
        } else {
          if (++requests == 1) {
            entered.complete();
            await release.future;
          }
          request.response.write("<div class='content'>甲😀关键词乙</div>");
        }
        await request.response.close();
      } catch (_) {
        // 被取消的HTTP允许对端先断开。
      }
    });
    try {
      await bridge.sourceAdd(
        source: bookSourceToDto(
          BookSource.fromJson({
            'bookSourceUrl': base,
            'bookSourceName': '边界验证源',
            'ruleToc': {
              'chapterList': 'class.chapter',
              'chapterName': 'tag.a@text',
              'chapterUrl': 'tag.a@href',
            },
            'ruleContent': {'content': 'class.content@text'},
          }),
        ),
      );
      await const RustBookshelfRepository().addBook(
        Book(
          bookUrl: '$base/book',
          name: '测试书',
          origin: base,
          tocUrl: '$base/toc',
        ),
      );
      final reading = RustReadingRepository(
        dispatchAction: (_) async => throw StateError('不应产生平台请求'),
      );
      expect(await reading.refreshToc('$base/book', base), hasLength(1));
      const search = RustContentSearchService();
      Stream<ContentSearchBatch> run(String query) => search.search(
        bookUrl: '$base/book',
        query: query,
        useRegex: false,
        useReplace: false,
        scope: ContentSearchScope.network,
        currentChapterIndex: 0,
      );
      final oldEvents = <ContentSearchBatch>[];
      final old = run('旧').listen(oldEvents.add);
      try {
        await entered.future.timeout(const Duration(seconds: 10));
      } finally {
        await old.cancel();
      }
      final current = await run('关键词')
          .toList()
          .timeout(const Duration(seconds: 10));
      final hit = current.expand((b) => b.hits).single;
      expect((hit.sourceStart, hit.sourceEnd), (3, 6));
      expect(
        hit.snippet.substring(hit.highlightStart, hit.highlightEnd),
        '关键词',
      );
      expect(current.last.chapterIndex, 0);
      expect(current.last.error, isNull);
      expect(oldEvents.expand((b) => b.hits), isEmpty);
    } finally {
      if (!release.isCompleted) release.complete();
      await serving.cancel();
      await server.close(force: true);
    }
  });
}
