import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/data/services/file_metadata.dart';

void main() {
  test('相同订阅复用元数据，显式刷新重新读取；缺失文件无元数据', () async {
    final root = await Directory.systemTemp.createTemp('legado-stat-');
    final c = ProviderContainer();
    addTearDown(() async {
      c.dispose();
      await root.delete(recursive: true);
    });
    final file = File('${root.path}/book');
    await file.writeAsString('abc');
    final provider = fileMetadataProvider(file.path);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(provider.future))?.size, 3);
    await file.writeAsString('abcdef');
    expect((await c.read(provider.future))?.size, 3);
    c.invalidate(provider);
    expect((await c.read(provider.future))?.size, 6);
    await file.delete();
    c.invalidate(provider);
    expect(await c.read(provider.future), isNull);
  });
}
