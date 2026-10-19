library;

/// P2-29c 后续 失败章查询 Dart↔Rust 真实数据链运行时验证（契约 §2.43.8）
///
/// 加载当前宿主rust/target/debug原生库（解析策略对齐
/// audio_cache_runtime_test.dart / ffi_stream_sink_runtime_test.dart），
/// 经真实 FRB wire 验证：
///
/// - `cacheDownloadFailedChapters` 返回 JSON 整型数组形态（无失败 = `[]`，
///   可经 jsonDecode 解析为 List，对应 `CacheDownloadService.listFailedChapters` 的
///   `List<int>` 解析口径）
/// - `CacheDownloadService.listFailedChapters`（契约 §2.43.8 Dart 封装）端到端可达
/// - 查询零写入：重复调用结果恒定
///
/// 失败记入/成功移除/持久化/恢复回读的完整数据链由 Rust 单测覆盖
/// （rust/legado-ffi/src/api/cache_download_api.rs，本地 TXT 夹具不联网）。
/// 前置条件：先在 rust/ 下构建当前宿主原生库
/// （cargo build -p legado-ffi --features quickjs）。
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:io';

import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/frb_generated.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const noTaskBook = 'http://p2438-no-task.example.com/book';
  late NativeTestApi api;

  setUpAll(() async {
    final lib = nativeTestLibrary();
    await RustLib.init(externalLibrary: lib);
    await bridge.init();
    // 隔离数据库：无该书的批量下载任务，保证断言确定性
    final sep = Platform.pathSeparator;
    final dbDir = Directory('.dart_tool${sep}ffi_failed_chapters_test');
    dbDir.createSync(recursive: true);
    final dbFile = File('${dbDir.path}${sep}p2_43_8_failed_chapters.db');
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    await bridge.dbOpen(path: dbFile.path);
    api = createTestApplication(useMock: false) as NativeTestApi;
  });

  group('失败章查询真实原生库运行时验证（契约 §2.43.8）', () {
    test('FFI：无任务书返回 JSON 空数组 `[]`（整型数组形态）', () async {
      final json = await bridge.cacheDownloadFailedChapters(
        bookUrl: noTaskBook,
      );
      expect(json, isEmpty);
    });

    test(
      'Dart 封装可达且零写入：CacheDownloadService.listFailedChapters 重复调用恒定空',
      () async {
        expect(
          await api.cacheDownloadService.listFailedChapters(noTaskBook),
          isEmpty,
        );
        expect(
          await api.cacheDownloadService.listFailedChapters(noTaskBook),
          isEmpty,
        );
        final json = await bridge.cacheDownloadFailedChapters(
          bookUrl: noTaskBook,
        );
        expect(json, isEmpty, reason: '查询为纯读，重复调用不得改写任务快照');
      },
    );
  });
}
