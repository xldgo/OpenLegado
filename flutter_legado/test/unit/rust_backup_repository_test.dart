import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/business_dto.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_backup_repository.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repo = RustBackupRepository();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);
  test('旧版导入直接映射精确计数和消息，失败不冒充完成', () async {
    final dir = await Directory.systemTemp.createTemp('legado-old-import-dto-');
    addTearDown(() => dir.delete(recursive: true));
    when(() => bridge.crateFfiFfiImportOldData(dir: dir.path)).thenAnswer(
      (_) async => OldDataImportResultDto(
        books: BigInt.from(9007199254740993),
        bookSources: BigInt.two,
        replaceRules: BigInt.zero,
        messages: ['文件一😀', '文件二失败'],
      ),
    );
    final result = await repo.importOldData(dir.path);
    expect(result.books, 9007199254740993);
    expect(result.bookSources, 2);
    expect(result.replaceRules, 0);
    expect(result.messages, ['文件一😀', '文件二失败']);
    final failure = StateError('读盘失败');
    when(() => bridge.crateFfiFfiImportOldData(dir: dir.path))
        .thenThrow(failure);
    await expectLater(repo.importOldData(dir.path), throwsA(same(failure)));
  });
  test('类型化备份文件仍转换为原领域描述文本，不改字段顺序和大小', () async {
    when(() => bridge.crateFfiFfiBackupList(dir: 'dir')).thenAnswer(
      (_) async => [
        BackupFileDto(
          name: '备份.json',
          path: 'dir/file',
          size: BigInt.from(9007199254740993),
          modified: 123,
        ),
      ],
    );
    expect(await repo.backupList('dir'), [
      '{modified: 123, name: 备份.json, path: dir/file, size: 9007199254740993}',
    ]);
  });
  test('恢复返回已提交统计，原生失败仍上抛', () async {
    final dir = await Directory.systemTemp.createTemp('legado-backup-dto-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/backup.json').writeAsString('{}');
    final stats = RestoreStatsDto(
      books: BigInt.from(9007199254740993),
      bookmarks: BigInt.one,
      replaceRules: BigInt.two,
      bookSources: BigInt.from(3),
      rssSources: BigInt.from(4),
      readRecords: BigInt.from(5),
    );
    when(() => bridge.crateFfiFfiBackupRestore(path: file.path))
        .thenAnswer((_) async => stats);
    final restored = await repo.restore(file.path);
    expect(
      [
        restored.books,
        restored.bookmarks,
        restored.replaceRules,
        restored.bookSources,
        restored.rssSources,
        restored.readRecords,
      ],
      [9007199254740993, 1, 2, 3, 4, 5],
    );
    verify(() => bridge.crateFfiFfiBackupRestore(path: file.path)).called(1);
    final failure = StateError('恢复失败');
    when(() => bridge.crateFfiFfiBackupRestore(path: file.path))
        .thenThrow(failure);
    await expectLater(repo.restore(file.path), throwsA(same(failure)));
  });
}
