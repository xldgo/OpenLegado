import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 文件选择器可能返回临时副本，规则引用转为应用持久资源。
final class HighlightRuleFiles {
  static Future<String> install(String path) async {
    final source = File(path);
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/highlight_resources');
    await directory.create(recursive: true);
    final name = source.uri.pathSegments.last;
    final destination = File(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    await source.copy(destination.path);
    return destination.path;
  }
}
