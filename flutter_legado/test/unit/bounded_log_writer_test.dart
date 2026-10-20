import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/bounded_log_writer.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('legado-log-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('合并写入保持中文和提交顺序，flush等待完成', () async {
    final file = File('${root.path}/log');
    final writer = BoundedLogWriter(file);
    for (var i = 0; i < 100; i++) {
      writer.add('中文$i\n');
    }
    await writer.flush();
    expect(await file.readAsLines(), List.generate(100, (i) => '中文$i'));
    await writer.close();
    writer.add('关闭后');
    expect((await file.readAsLines()).length, 100);
  });
  test('待写入队列有界，保留较新完整行', () async {
    final file = File('${root.path}/log');
    final writer = BoundedLogWriter(file, maxPendingBytes: 8);
    writer.add('1111');
    writer.add('2222');
    writer.add('3333');
    await writer.flush();
    expect(await file.readAsString(), '22223333');
    expect(writer.droppedLines, 1);
  });
  test('文件轮转与过大单行均不突破配置上限', () async {
    final file = File('${root.path}/log');
    final writer = BoundedLogWriter(file, maxFileBytes: 10);
    writer.add('12345678');
    await writer.flush();
    writer.add('abcd');
    await writer.flush();
    writer.add('12345678901');
    await writer.flush();
    expect(await file.readAsString(), 'abcd');
    expect(writer.droppedLines, 1);
  });
  test('写入失败不影响业务，目录恢复后仍可继续写入', () async {
    final file = File('${root.path}/missing/log');
    final errors = <Object>[];
    final writer = BoundedLogWriter(file, onError: (e, s) => errors.add(e));
    writer.add('失败');
    await writer.flush();
    expect(errors, hasLength(1));
    await file.parent.create();
    writer.add('成功');
    await writer.flush();
    expect(await file.readAsString(), '成功');
  });
  test('错误回调再次抛错也不产生未捕获异常', () async {
    final writer = BoundedLogWriter(
      File('${root.path}/missing/log'),
      onError: (_, _) => throw StateError('诊断回调失败'),
    );
    writer.add('日志');
    await writer.flush();
    await writer.close();
  });
}
