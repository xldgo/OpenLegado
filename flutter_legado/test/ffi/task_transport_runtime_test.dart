library;

@Timeout(Duration(minutes: 3))
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/task_dto.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/services/rust_cache_download_service.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/models/book.dart';

void main() {
  if (!Platform.isWindows) {
    test('需要Windows DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实本地章节下载发出初始和终态快照，退订不取消任务', () async {
    final root = Directory(
      '.dart_tool/task-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
    final file = File('${root.absolute.path}/小说.txt');
    await file.writeAsString(
      List.generate(30, (i) => '第$i章 标题\n\n这是第$i章正文。\n\n').join(),
    );
    const books = RustBookshelfRepository();
    await books.addBook(
      Book(bookUrl: file.path, name: '观察测试', origin: 'loc_book'),
    );
    final chapters = await bridge.readerGetChapters(bookUrl: file.path);
    expect(chapters.total, 30);
    const service = RustCacheDownloadService();
    final first = Completer<void>();
    final completed = Completer<void>();
    final sub = service.watchTasks().listen(
      (tasks) {
        if (!first.isCompleted) {
          first.complete();
        }
        if (tasks.any(
              (v) => v.bookUrl == file.path && v.status == 'completed',
            ) &&
            !completed.isCompleted) {
          completed.complete();
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completed.isCompleted) completed.completeError(e, st);
      },
    );
    await first.future.timeout(const Duration(seconds: 5));
    final id = await service.cacheDownloadStart(file.path, 0, 29);
    await completed.future.timeout(const Duration(seconds: 15));
    await sub.cancel().timeout(const Duration(seconds: 3));
    final progress = await service.cacheDownloadProgress(id);
    expect(progress.status, 'completed');
    expect(progress.completed, 30);
    expect(await service.cacheDownloadCancel(id), isTrue);
    expect((await service.cacheDownloadProgress(id)).status, 'completed');
    final missing = await service.cacheDownloadProgress(99999999);
    expect(missing.status, 'notFound');
    expect(await service.listDownloadingChapters(file.path), isEmpty);
    final taskId = await bridge.downloadAddTask(
      bookUrl: 'book',
      chapterUrl: 'chapter',
      chapterTitle: '章',
      chapterIndex: 2,
      priority: 3,
    );
    final queue = await bridge.downloadListByBook(bookUrl: 'book');
    expect(queue.single.id, taskId);
    expect(queue.single.status, DownloadStatusDto.pending);
    await bridge.downloadUpdateProgress(taskId: taskId, progress: 0.25);
    expect(
      (await bridge.downloadListByBook(bookUrl: 'book')).single.progress,
      0.25,
    );
    expect((await bridge.downloadGetStats()).total, BigInt.one);
  });
}
