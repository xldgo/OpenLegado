import 'package:flutter_legado/src/domain/models/backup_restore_stats.dart';
import 'package:flutter_legado/src/domain/models/old_data_import_result.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_legado/src/data/services/backup_preferences_service.dart';
import 'package:flutter_legado/src/data/services/backup_service.dart';
import 'package:flutter_legado/src/domain/contracts/restore_ignore_repository.dart';
import 'package:flutter_legado/src/domain/models/restore_ignore_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Ignore extends Fake implements RestoreIgnoreRepository {
  RestoreIgnoreConfig config = RestoreIgnoreConfig();
  @override
  Future<RestoreIgnoreConfig> load() async => config;
}

class _FailedPreferences extends BackupPreferencesService {
  @override
  Future<Map<String, dynamic>> collectForBackup(
    Map<String, bool> ignore,
  ) async => throw StateError('偏好读取失败');
  @override
  Future<void> applyFromBackup(
    Map<String, dynamic>? data,
    Map<String, bool> ignore,
  ) async => throw StateError('偏好写入失败');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  const stats = BackupRestoreStats(
    books: 2,
    bookmarks: 1,
    replaceRules: 3,
    bookSources: 4,
    rssSources: 5,
    readRecords: 6,
  );
  late MockRustApi api;
  late _Ignore ignore;
  late Directory directory;
  late File file;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'reader_font_size': 18.0});
    api = MockRustApi();
    ignore = _Ignore();
    directory = await Directory.systemTemp.createTemp('legado-backup-test-');
    file = File('${directory.path}/backup.json');
    addTearDown(() => directory.delete(recursive: true));
    when(() => api.backupRepository.backup(any()))
        .thenAnswer((_) async => file.path);
    when(() => api.backupRepository.restore(any()))
        .thenAnswer((_) async => stats);
  });
  BackupService service({BackupPreferencesService? preferences}) =>
      BackupService(
        repository: api.backupRepository,
        webDav: api.webDavService,
        bookshelf: api.bookshelfRepository,
        sources: api.bookSourceRepository,
        ignore: ignore,
        preferences: preferences,
      );

  test('本地业务文件与偏好一并备份，忽略规则保持', () async {
    await file.writeAsString('{"books":[]}');
    final result = await service().backupLocal(directory.path);
    expect(result.preferencesError, isNull);
    final payload = jsonDecode(await file.readAsString()) as Map;
    expect(payload['books'], isEmpty);
    expect(payload['appPrefs']['reader_font_size'], 18.0);
    verify(() => api.backupRepository.backup(directory.path)).called(1);
  });

  test('偏好备份失败保留业务文件并返回失败，不重复生成文件', () async {
    await file.writeAsString('{"books":[]}');
    final result = await service(preferences: _FailedPreferences())
        .backupLocal(directory.path);
    expect(result.path, file.path);
    expect(result.preferencesError, isStateError);
    expect(await file.readAsString(), '{"books":[]}');
    verify(() => api.backupRepository.backup(directory.path)).called(1);
  });

  test('损坏备份JSON不伪装成偏好已备份', () async {
    await file.writeAsString('[{');
    final result = await service().backupLocal(directory.path);
    expect(result.preferencesError, isFormatException);
    expect(await file.readAsString(), '[{');
  });

  test('业务恢复先完成，随后应用偏好', () async {
    await file.writeAsString(
      '{"books":[],"appPrefs":{"reader_font_size":24.0}}',
    );
    when(() => api.backupRepository.restore(file.path)).thenAnswer((_) async {
      expect(
        (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
        18.0,
      );
      return stats;
    });
    final result = await service().restoreLocal(file.path);
    expect(result.stats, same(stats));
    expect(result.preferencesError, isNull);
    expect(
      (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
      24.0,
    );
  });

  test('业务恢复失败不提前修改设置', () async {
    await file.writeAsString(
      '{"books":[],"appPrefs":{"reader_font_size":24.0}}',
    );
    when(() => api.backupRepository.restore(any()))
        .thenThrow(StateError('数据库写入失败'));
    await expectLater(service().restoreLocal(file.path), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
      18.0,
    );
  });

  test('偏好格式错误在调用业务恢复前拒绝', () async {
    await file.writeAsString('{"books":[],"appPrefs":[]}');
    await expectLater(service().restoreLocal(file.path), throwsFormatException);
    verifyNever(() => api.backupRepository.restore(any()));
  });

  test('业务已恢复但偏好失败返回部分完成，不重做业务恢复', () async {
    await file.writeAsString(
      '{"books":[],"appPrefs":{"reader_font_size":24.0}}',
    );
    final result = await service(preferences: _FailedPreferences())
        .restoreLocal(file.path);
    expect(result.stats, same(stats));
    expect(result.preferencesError, isStateError);
    verify(() => api.backupRepository.restore(file.path)).called(1);
  });

  test('忽略本地书通过临时载荷过滤，源文件不变且临时文件清理', () async {
    ignore.config = RestoreIgnoreConfig({'localBook': true});
    final original = jsonEncode({
      'books': [
        {'bookUrl': 'local', 'origin': 'loc_book'},
        {'bookUrl': 'dav', 'origin': 'dav:https://example/book'},
        {'bookUrl': 'remote', 'origin': 'https://source.example'},
      ],
    });
    await file.writeAsString(original);
    String? usedPath;
    when(() => api.backupRepository.restore(any())).thenAnswer((call) async {
      usedPath = call.positionalArguments.first as String;
      final payload = jsonDecode(await File(usedPath!).readAsString()) as Map;
      expect((payload['books'] as List).single['bookUrl'], 'remote');
      return stats;
    });
    await service().restoreLocal(file.path);
    expect(usedPath, isNot(file.path));
    expect(await File(usedPath!).exists(), isFalse);
    expect(await file.readAsString(), original);
  });

  test('未支持的ZIP在调用仓储之前明确拒绝，不修改设置', () async {
    final path = '${directory.path}/backup.zip';
    await expectLater(
      service().restoreLocal(path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          '格式提示',
          contains('JSON备份'),
        ),
      ),
    );
    verifyNever(() => api.backupRepository.restore(any()));
    expect(
      (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
      18.0,
    );
  });

  test('旧版导入结果沿用消息或计数格式', () async {
    when(() => api.backupRepository.importOldData(any())).thenAnswer(
      (_) async => const OldDataImportResult(
        books: 0,
        bookSources: 0,
        replaceRules: 0,
        messages: ['导入书籍', '导入书源'],
      ),
    );
    expect(await service().importOldData(directory.path), '导入书籍\n导入书源');
    when(() => api.backupRepository.importOldData(any())).thenAnswer(
      (_) async => const OldDataImportResult(
        books: 2,
        bookSources: 3,
        replaceRules: 1,
        messages: [],
      ),
    );
    expect(
      await service().importOldData(directory.path),
      '书架 2 · 书源 3 · 替换规则 1',
    );
  });
}
