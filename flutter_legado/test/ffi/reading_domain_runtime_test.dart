@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

// 阅读域类型化结果的真实宿主原生库 往返。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:io';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/repositories/rust_book_group_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cache_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_chapter_cache_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_highlight_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_highlight_rule_repository.dart';
import 'package:flutter_legado/src/data/services/rust_database_maintenance_service.dart';
import 'package:flutter_legado/src/domain/models/book_highlight.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final root = Directory(
      '.dart_tool/reading-domain-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await RustLib.init(externalLibrary: nativeTestLibrary());
    await bridge.init();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  tearDownAll(RustLib.dispose);

  test('章节缓存经真实服务与绑定往返，单章清理不删他章', () async {
    const chapters = RustChapterCacheRepository();
    const cache = RustCacheRepository();
    const maintenance = RustDatabaseMaintenanceService();
    const book = 'fixture://cache😀';
    for (var index = 0; index < 2; index++) {
      expect(
        await bridge.saveChapterContent(
          bookUrl: book,
          chapterIndex: index,
          title: '第$index章',
          content: '正文😀$index',
          chapterUrl: 'chapter://$index',
        ),
        isTrue,
      );
    }
    expect(await chapters.getCachedChapter(book, 0), '正文😀0');
    expect(await chapters.listCachedChapterUrls(book), [
      'chapter://0',
      'chapter://1',
    ]);
    final entries = await bridge.cacheListCachedChapters(bookUrl: book);
    expect(entries.map((e) => e.url), ['chapter://0', 'chapter://1']);
    expect(entries.every((e) => e.wordCount.isEmpty), isTrue);
    expect(await cache.getCacheBookCount(), 1);
    expect(await cache.getCacheChapterCount(), 2);
    expect(await cache.getCacheSize(), greaterThan(0));
    expect(await chapters.clearChapterCache(book, 0), 1);
    expect(await chapters.getCachedChapter(book, 0), isEmpty);
    expect(await chapters.getCachedChapter(book, 1), '正文😀1');
    expect(await chapters.clearBookCache(book), 1);
    await cache.clearCacheBefore(0);
    expect(await cache.getCacheChapterCount(), 0);
    expect(await maintenance.shrinkDatabase(), greaterThanOrEqualTo(0));
  });

  test('标注经真实绑定往返，UTF-16范围、样式、自动主键和覆盖均保持', () async {
    const repo = RustHighlightRepository();
    expect(await repo.highlightListAll(), isEmpty);
    const item = BookHighlight(
      bookUrl: 'book://高亮😀',
      chapterUrl: 'chapter://3',
      bookName: '小说😀',
      bookAuthor: '作者',
      chapterIndex: 3,
      chapterPos: 2,
      chapterPosEnd: 9,
      layoutTitleLength: -1,
      chapterName: '第三章',
      bookText: '甲😀正文',
      style: '{"type":"background","color":-65536}',
      note: '原笔记',
    );
    final first = await repo.highlightAdd(item);
    final second = await repo.highlightAdd(item);
    expect(first, greaterThan(0));
    expect(second, isNot(first));
    final updated = item.copyWith(time: first, note: '更新😀');
    expect(await repo.highlightAdd(updated), first);
    final byBook = await repo.highlightListByBook(bookUrl: item.bookUrl);
    expect(byBook, hasLength(2));
    expect(
      byBook.singleWhere((e) => e.time == first).toJson(),
      updated.toJson(),
    );
    expect(
      (await repo.highlightListByChapter(
        bookUrl: item.bookUrl,
        chapterIndex: 3,
      )).map((e) => e.toJson()),
      byBook.map((e) => e.toJson()),
    );
    expect(
      await repo.highlightListByChapter(bookUrl: item.bookUrl, chapterIndex: 4),
      isEmpty,
    );
    expect(
      (await repo.highlightSearch(keyword: '甲😀')).map((e) => e.time).toSet(),
      {first, second},
    );
    const largeTime = 9007199254740993;
    await repo.highlightAdd(item.copyWith(time: largeTime, chapterIndex: 4));
    expect(
      (await repo.highlightListAll()).any((e) => e.time == largeTime),
      isTrue,
    );
    expect(await repo.highlightDelete(time: first), isTrue);
    expect(await repo.highlightDelete(time: first), isFalse);
    expect(await repo.highlightDeleteByBook(bookUrl: item.bookUrl), 2);
    expect(await repo.highlightListAll(), isEmpty);
  });

  test('规则经真实绑定保存全字段，保留范围、空值与启用过滤', () async {
    const repo = RustHighlightRuleRepository();
    expect(await repo.highlightRuleList(), isEmpty);
    const rule = HighlightRule(
      name: '类型化规则😀',
      pattern: '甲😀',
      isRegex: true,
      applyToTitle: true,
      scope: '小说',
      style: '{"textColor":-65536}',
      sortOrder: -2,
      timeoutMillisecond: 9007199254740993,
    );
    final id = await repo.highlightRuleSave(rule);
    expect(id, greaterThan(0));
    final saved = (await repo.highlightRuleList()).single;
    expect(saved.toJson(), rule.copyWith(id: id).toJson());
    expect(
      (await repo.highlightRuleFindEnabled(
        bookName: '小说',
        origin: '其他源',
      )).single.id,
      id,
    );
    expect(
      await repo.highlightRuleFindEnabled(bookName: '其他书', origin: '其他源'),
      isEmpty,
    );
    await repo.highlightRuleSave(saved.copyWith(isEnabled: false));
    expect(
      await repo.highlightRuleFindEnabled(bookName: '小说', origin: '其他源'),
      isEmpty,
    );
    final global = await repo.highlightRuleSave(
      const HighlightRule(name: '全局', scope: null),
    );
    expect(
      (await repo.highlightRuleFindEnabled(
        bookName: '任意',
        origin: '源',
      )).single.scope,
      isNull,
    );
    expect(await repo.highlightRuleDelete(id: global), isTrue);
    expect(await repo.highlightRuleDelete(id: id), isTrue);
    expect(await repo.highlightRuleDelete(id: id), isFalse);
    expect(await repo.highlightRuleList(), isEmpty);
  });

  test('分组列表经真实绑定保留隐私、封面和可见性，写入参数不扩展', () async {
    const repo = RustBookGroupRepository();
    final group = await repo.addBookGroup(
      const BookGroup(groupName: '私密😀', isPrivate: true, order: -2),
    );
    final stored = (await repo.getBookGroups()).singleWhere(
      (e) => e.groupId == group.groupId,
    );
    expect(stored, group);
    expect(stored.cover, isNull);
    expect(stored.enableRefresh, isTrue);
    expect(stored.bookSort, -1);
    expect(stored.onlyUpdateRead, isFalse);
    expect(await repo.bookGroupSetShow(group.groupId, false), isTrue);
    await repo.updateBookGroup(
      group.copyWith(groupName: '更新', cover: 'cover://😀'),
    );
    final updated = (await repo.getBookGroups()).singleWhere(
      (e) => e.groupId == group.groupId,
    );
    expect(
      updated,
      group.copyWith(groupName: '更新', cover: 'cover://😀', show: false),
    );
    await repo.deleteBookGroup(group.groupId);
    expect(
      (await repo.getBookGroups()).any((e) => e.groupId == group.groupId),
      isFalse,
    );
  });
}
