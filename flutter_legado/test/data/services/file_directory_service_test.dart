import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/services/file_directory_service.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('legado-files');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('快照记录目录与真实字节数，之后读取不重新访问文件', () async {
    await Directory('${root.path}/子目录').create();
    final file = File('${root.path}/书籍.txt');
    await file.writeAsBytes([1, 2, 3]);
    final snapshot = await FileDirectoryService().load(root);
    await file.delete();
    expect(snapshot.singleWhere((e) => e.isDirectory).path, endsWith('子目录'));
    expect(snapshot.singleWhere((e) => !e.isDirectory).size, 3);
    expect(() => snapshot.clear(), throwsUnsupportedError);
  });
  test('单文件元数据失败保留未知大小，目录失败向上传递', () async {
    await File('${root.path}/书籍.txt').writeAsString('test');
    final service = FileDirectoryService(
      stat: (_) async => throw const FileSystemException('无权限'),
    );
    final snapshot = await service.load(root);
    expect(snapshot.single.size, isNull);
    expect(snapshot.single.path, endsWith('书籍.txt'));
    await expectLater(
      service.load(Directory('${root.path}/missing')),
      throwsA(isA<FileSystemException>()),
    );
  });
  test('大量文件最多同时读取八份元数据', () async {
    for (var i = 0; i < 23; i++) {
      await File('${root.path}/$i').writeAsString('a');
    }
    var pending = 0;
    var maximum = 0;
    final snapshot = await FileDirectoryService(
      stat: (entity) async {
        pending++;
        if (pending > maximum) maximum = pending;
        await Future<void>.delayed(Duration.zero);
        final stat = await entity.stat();
        pending--;
        return stat;
      },
    ).load(root);
    expect(maximum, inInclusiveRange(2, 8));
    expect(snapshot, hasLength(23));
    expect(snapshot.every((e) => e.size == 1), isTrue);
  });
}
