import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次目录加载的元数据快照；界面排序、过滤和绘制不再访问文件系统。— Codex + UI
class FileEntrySnapshot {
  const FileEntrySnapshot({required this.path, required this.type, this.size});
  final String path;
  final FileSystemEntityType type;
  final int? size;
  bool get isDirectory => type == FileSystemEntityType.directory;
  FileSystemEntity get entity => switch (type) {
    FileSystemEntityType.directory => Directory(path),
    FileSystemEntityType.link => Link(path),
    _ => File(path),
  };
}

class FileDirectoryService {
  FileDirectoryService({Future<FileStat> Function(FileSystemEntity)? stat})
    : _stat = stat ?? ((entity) => entity.stat());
  final Future<FileStat> Function(FileSystemEntity) _stat;

  Future<List<FileEntrySnapshot>> load(Directory directory) async {
    final entries = await directory.list(followLinks: false).toList();
    final snapshots = List<FileEntrySnapshot?>.filled(entries.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < entries.length) {
        final index = next++;
        final entity = entries[index];
        final type = entity is Directory
            ? FileSystemEntityType.directory
            : entity is Link
            ? FileSystemEntityType.link
            : FileSystemEntityType.file;
        int? size;
        if (type == FileSystemEntityType.file) {
          try {
            final stat = await _stat(entity);
            if (stat.type != FileSystemEntityType.notFound) size = stat.size;
          } on FileSystemException {
            // 单个文件消失或无权限时保留条目，以未知大小显示。
          }
        }
        snapshots[index] = FileEntrySnapshot(
          path: entity.path,
          type: type,
          size: size,
        );
      }
    }

    await Future.wait(
      List.generate(entries.length.clamp(0, 8), (_) => worker()),
    );
    return List.unmodifiable(snapshots.cast<FileEntrySnapshot>());
  }
}

final fileDirectoryServiceProvider = Provider<FileDirectoryService>(
  (ref) => FileDirectoryService(),
);
