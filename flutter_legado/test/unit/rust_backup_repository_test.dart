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
  test('恢复忽略统计载荷但等待真实结果，原生失败仍上抛', () async {
    final dir = await Directory.systemTemp.createTemp('legado-backup-dto-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/backup.json').writeAsString('{}');
    final stats = RestoreStatsDto(
      books: BigInt.one,
      bookmarks: BigInt.zero,
      replaceRules: BigInt.zero,
      bookSources: BigInt.zero,
      rssSources: BigInt.zero,
      readRecords: BigInt.zero,
    );
    when(() => bridge.crateFfiFfiBackupRestore(path: file.path))
        .thenAnswer((_) async => stats);
    await repo.restore(file.path);
    verify(() => bridge.crateFfiFfiBackupRestore(path: file.path)).called(1);
    final failure = StateError('恢复失败');
    when(() => bridge.crateFfiFfiBackupRestore(path: file.path))
        .thenThrow(failure);
    await expectLater(repo.restore(file.path), throwsA(same(failure)));
  });
}
