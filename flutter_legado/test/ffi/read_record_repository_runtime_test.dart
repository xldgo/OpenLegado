@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 使用真实宿主原生库 复核阅读记录直接适配与每日整秒增量。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:io';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实记录保持累计毫秒，重复写入不重复入账，CRUD 复用同一数据库', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/read-record-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: nativeTestRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final repository = api.readRecordRepository;
    expect(await repository.getReadRecords(), isEmpty);
    final start = DateTime.now().millisecondsSinceEpoch;
    const record = ReadRecord(
      bookName: '真实 FFI 测试',
      author: '真实作者',
      readTime: 1400,
      lastRead: -1,
      deviceId: '不覆盖设备',
    );
    await repository.putReadRecord(
      record,
      bookUrl: 'test://book',
      chapterIndex: 7,
    );
    final firstSessions = await repository.getReadRecordSessions();
    expect(firstSessions.single.bookUrl, 'test://book');
    expect(firstSessions.single.chapterIndex, 7);
    expect(firstSessions.single.durationMs, 1400);
    final stored = (await repository.getReadRecords()).single;
    expect(stored.readTime, 1400);
    expect(stored.lastRead, greaterThanOrEqualTo(start));
    expect(stored.deviceId, isEmpty);
    final updated = record.copyWith(readTime: 2999);
    await repository.putReadRecord(updated);
    await repository.putReadRecord(updated);
    expect((await repository.getReadRecords()).single.readTime, 2999);
    expect(await repository.getReadRecordSessions(), hasLength(2));
    final year = DateTime.now().year;
    final daily = await repository.readRecordDailyList(year);
    expect(
      daily.fold<int>(0, (sum, row) => sum + (row['seconds'] as num).toInt()),
      2,
    );
    expect(await repository.readRecordDailyList(year - 1), isEmpty);
    await repository.putReadRecord(
      const ReadRecord(bookName: '另一条', readTime: 0),
    );
    await repository.deleteReadRecord(record.bookName);
    expect(await repository.getReadRecords(), isEmpty);
    expect(await repository.getAllReadRecordDetails(), isEmpty);
    final beforeMidnight = DateTime(
      2025,
      12,
      31,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;
    final afterMidnight = DateTime(2026, 1, 1, 0, 0, 1).millisecondsSinceEpoch;
    await repository.putReadRecord(
      ReadRecord(
        bookName: '同名',
        author: '甲',
        startTime: beforeMidnight,
        lastRead: afterMidnight,
        readTime: 2000,
      ),
    );
    await repository.putReadRecord(
      ReadRecord(
        bookName: '同名',
        author: '乙',
        startTime: afterMidnight,
        lastRead: afterMidnight + 1500,
        readTime: 3500,
      ),
    );
    final details = await repository.getAllReadRecordDetails();
    expect(details, hasLength(3));
    final previousYear = await repository.getReadRecordDetails(2025);
    expect(previousYear.single.readTime, 1000);
    expect(
      previousYear.single.lastRead,
      DateTime(2026, 1, 1).millisecondsSinceEpoch,
    );
    final thisYear = await repository.getReadRecordDetails(2026);
    expect(thisYear.map((d) => d.author).toSet(), {'甲', '乙'});
    expect(thisYear.fold<int>(0, (sum, d) => sum + d.readTime), 2500);
    await repository.deleteReadRecordDetail('同名', '甲', '2025-12-31');
    expect(await repository.getReadRecordDetails(2025), isEmpty);
    final remainingSessions = await repository.getReadRecordSessions();
    final authorSession = remainingSessions.singleWhere((s) => s.author == '甲');
    expect(
      authorSession.startTime,
      DateTime(2026, 1, 1).millisecondsSinceEpoch,
    );
    await repository.deleteReadRecordSessions([
      authorSession.id,
      authorSession.id,
    ]);
    expect((await repository.getReadRecords()).single.readTime, 1500);
    expect((await repository.getAllReadRecordDetails()).single.author, '乙');
    await repository.deleteReadRecord('同名', author: '乙');
    expect(await repository.getReadRecordSessions(), isEmpty);
    await repository.deleteReadRecord('同名');
    expect(await repository.getAllReadRecordDetails(), isEmpty);
    expect(await repository.readRecordDailyList(2026), isEmpty);
    await repository.clearReadRecords();
    expect(await repository.getReadRecords(), isEmpty);
    await api.runtime.initialize();
    expect(api.readRecordRepository, same(repository));
  });
}

class _Environment implements AppEnvironment {
  _Environment(this.root);
  final String root;

  @override
  Future<String> databasePath() async =>
      '$root${Platform.pathSeparator}legado.db';
  @override
  Future<void> warmLocalBookStore() async {}
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async =>
      (await Directory('$root${Platform.pathSeparator}${cache.name}')
              .create(recursive: true))
          .path;
  @override
  Future<String?> deviceId() async => 'read-record-fixture';
}
