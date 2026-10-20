import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/reader_font.dart';
import '../services/settings_write_queue.dart';

/// 文件定位、导入和FontLoader注册；不读写偏好。— Codex + UI
final class ReaderFontFiles {
  ReaderFontFiles({
    Future<Directory> Function()? documents,
    Future<void> Function(String, Uint8List)? register,
  }) : _documents = documents ?? getApplicationDocumentsDirectory,
       _register = register ?? _registerFont;

  final Future<Directory> Function() _documents;
  final Future<void> Function(String, Uint8List) _register;
  final _queue = SettingsWriteQueue();
  final _stamps = <String, String>{};
  final _revisions = <String, int>{};

  static Future<void> _registerFont(String family, Uint8List bytes) =>
      (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();

  int revisionFor(Set<String> families) => families.isEmpty
      ? 0
      : Object.hashAll(
          families.map((family) => (family, _revisions[family] ?? 0)),
        );

  Future<ReaderFont> load(ReaderFont font) async {
    await _queue.run(() async {
      final file = File(
        '${(await _documents()).path}${Platform.pathSeparator}'
        '${font.path.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await file.exists()) {
        throw FileSystemException('字体文件不存在', file.path);
      }
      final stat = await file.stat();
      final stamp =
          '${file.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
      if (_stamps[font.family] != stamp) {
        await _register(font.family, await file.readAsBytes());
        _stamps[font.family] = stamp;
        _revisions[font.family] = (_revisions[font.family] ?? 0) + 1;
      }
    });
    return font;
  }

  Future<ReaderFont> install(String name, Uint8List bytes) async {
    final stem = name
        .split(RegExp(r'[/\\]'))
        .last
        .split('.')
        .first
        .replaceAll(' ', '');
    if (stem.isEmpty) throw ArgumentError('字体文件名为空');
    final family = 'Custom_$stem';
    final directory = Directory(
      '${(await _documents()).path}${Platform.pathSeparator}fonts',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$family.ttf');
    await file.writeAsBytes(bytes);
    final font = ReaderFont(family: family, path: 'fonts/$family.ttf');
    await load(font);
    return font;
  }
}
