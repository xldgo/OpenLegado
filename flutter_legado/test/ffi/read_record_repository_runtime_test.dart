/// 使用真实 Windows DLL 复核阅读记录直接适配与每日整秒增量。— Codex + Bridge
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (!Platform.isWindows) {
    test('阅读记录真实 FFI 验证需要 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实记录保持累计毫秒，重复写入不重复入账，CRUD 复用同一数据库', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/read-record-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createBookApi(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: const NativeRustRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeBookApi(api: api);
    final repository = api.readRecordRepository;
    expect(await repository.getReadRecords(), isEmpty);
    final start = DateTime.now().millisecondsSinceEpoch;
    const record = ReadRecord(
      bookName: '真实 FFI 测试',
      readTime: 1400,
      lastRead: -1,
      deviceId: '不覆盖设备',
    );
    await repository.putReadRecord(record);
    final stored = (await repository.getReadRecords()).single;
    expect(stored.readTime, 1400);
    expect(stored.lastRead, greaterThanOrEqualTo(start));
    expect(stored.deviceId, isEmpty);
    final updated = record.copyWith(readTime: 2999);
    await repository.putReadRecord(updated);
    await repository.putReadRecord(updated);
    expect((await repository.getReadRecords()).single.readTime, 2999);
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
    expect((await repository.getReadRecords()).single.bookName, '另一条');
    await repository.clearReadRecords();
    expect(await repository.getReadRecords(), isEmpty);
    await api.initialize();
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
