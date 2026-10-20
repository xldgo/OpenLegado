import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 系统媒体插件消费本地缩略图；限制缓存数量且不删除当前使用文件。— Codex + UI
class MediaArtworkFiles {
  MediaArtworkFiles({Future<Directory> Function()? directory})
    : _directory = directory ?? getTemporaryDirectory;
  final Future<Directory> Function() _directory;
  int _counter = 0;
  Future<Directory> _root() async =>
      Directory('${(await _directory()).path}/media_notification_artwork')
          .create(recursive: true);

  Future<Uri> write(Uint8List bytes) async {
    final root = await _root();
    final file = File(
      '${root.path}/${DateTime.now().microsecondsSinceEpoch}-${_counter++}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.uri;
  }

  Future<void> prune({Uri? keep}) async {
    final root = await _root();
    final files = await root
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.png'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    final retired = files.where((file) => file.uri != keep);
    for (final file in retired.skip(keep == null ? 8 : 7)) {
      try {
        await file.delete();
      } on FileSystemException {
        /* 并发清理已删除的缩略图。 */
      }
    }
  }
}
