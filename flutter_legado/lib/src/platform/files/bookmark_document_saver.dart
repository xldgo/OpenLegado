import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

import '../../domain/models/bookmark_export_document.dart';

/// 平台保存端口；取消返回null，保存失败上抛。— Codex + UI
abstract interface class BookmarkDocumentSaver {
  Future<String?> save(
    BookmarkExportDocument document, {
    String? initialDirectory,
  });
}

/// 保留原SAF/应用目录回退和其他平台目录选择行为，不参与格式生成。
final class PlatformBookmarkDocumentSaver implements BookmarkDocumentSaver {
  const PlatformBookmarkDocumentSaver();

  /// 选择目录并写入文件（共用流程，按平台分支）
  ///
  /// [Task #54 | 2026-08-10] 缺陷④修复：Android 10+ scoped storage 下
  /// file_picker getDirectoryPath 返回的普通路径无直写权（EACCES），
  /// 改走 SAF（对标原版 ACTION_CREATE_DOCUMENT）；SAF 失败时降级写入
  /// 应用专属外部存储目录（无权限要求）；桌面保留原路径直写 — QoderCN
  @override
  Future<String?> save(
    BookmarkExportDocument document, {
    String? initialDirectory,
  }) async {
    if (Platform.isAndroid) {
      return _saveAndroid(document);
    }
    return _saveDesktop(document, initialDirectory);
  }

  /// Android：优先 SAF 目录选择 + createFile 写入；
  /// SAF 不可用/失败时降级写入应用专属外部存储目录。
  /// 用户取消（null）时静默返回 null。
  Future<String?> _saveAndroid(BookmarkExportDocument document) async {
    final fileName = document.fileName;
    try {
      final saf = Saf();
      // ACTION_OPEN_DOCUMENT_TREE 目录选择（持久化写权限）；
      // 用户取消返回 null → 静默（对齐原版 SAF 取消语义）
      final dir = await saf.pickDirectory(writePermission: true);
      if (dir == null) return null;
      // 对标原版 ACTION_CREATE_DOCUMENT：重名时系统/包内自动追加后缀，
      // 不覆盖既有文件
      final doc = await saf.writeFileBytes(
        dir.uri,
        fileName,
        document.mimeType,
        utf8.encode(document.content),
      );
      return doc.name;
    } catch (_) {
      // 退方案 C：SAF 不可用（模拟器无 DocumentsProvider/插件异常等）
      // → 写入应用专属外部存储目录（无权限要求）
      final dir = await getExternalStorageDirectory();
      if (dir == null) rethrow;
      final file = File(_joinPath(dir.path, fileName));
      await file.writeAsString(document.content, flush: true);
      return file.path;
    }
  }

  /// 桌面/其余平台：保留既有 file_picker 选目录 + 路径直写逻辑
  Future<String?> _saveDesktop(
    BookmarkExportDocument document,
    String? initialDirectory,
  ) async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: '选择书签导出目录',
      initialDirectory:
          (initialDirectory != null && initialDirectory.isNotEmpty)
          ? initialDirectory
          : null,
    );
    // 用户取消选择
    if (dir == null) return null;
    final fileName = document.fileName;
    final file = File(_joinPath(dir, fileName));
    await file.writeAsString(document.content, flush: true);
    return file.path;
  }

  /// 路径拼接（兼容末尾带/不带分隔符的目录路径）
  String _joinPath(String dir, String fileName) {
    if (dir.endsWith(Platform.pathSeparator) || dir.endsWith('/')) {
      return '$dir$fileName';
    }
    return '$dir${Platform.pathSeparator}$fileName';
  }
}
