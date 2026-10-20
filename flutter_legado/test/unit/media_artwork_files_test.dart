import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/audio/media_artwork_files.dart';

void main() {
  test('缩略图内容真实落盘，裁剪缓存时保留当前URI且不触碰其他文件', () async {
    final root = await Directory.systemTemp.createTemp('legado-media-artwork-');
    addTearDown(() => root.delete(recursive: true));
    final files = MediaArtworkFiles(directory: () async => root);
    final bytes = Uint8List.fromList([1, 2, 3]);
    final first = await files.write(bytes);
    expect(await File.fromUri(first).readAsBytes(), bytes);
    final unrelated = File('${root.path}/untouched.txt');
    await unrelated.writeAsString('保留');
    for (var i = 0; i < 14; i++) {
      await files.write(Uint8List.fromList([i]));
    }
    await files.prune(keep: first);
    expect(await File.fromUri(first).exists(), isTrue);
    expect(
      await Directory('${root.path}/media_notification_artwork').list().length,
      8,
    );
    expect(await unrelated.readAsString(), '保留');
  });
}
