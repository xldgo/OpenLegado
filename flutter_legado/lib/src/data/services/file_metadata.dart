import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 相同路径在订阅期间共用异步元数据；绘制不直接访问磁盘。— Codex + UI
final fileMetadataProvider = FutureProvider.autoDispose
    .family<FileStat?, String>((ref, path) async {
      if (kIsWeb || path.isEmpty) return null;
      try {
        final stat = await File(path).stat();
        return stat.type == FileSystemEntityType.file ? stat : null;
      } on FileSystemException {
        return null;
      }
    });
