import 'package:flutter/foundation.dart';

import '../../domain/contracts/reader_font_repository.dart';
import '../../domain/contracts/font_catalog.dart';
import '../../domain/models/reader_font.dart';
import '../../platform/reader_font_files.dart';

/// 界面与阅读器共用字体目录和加载，不在这里保存各自的字体选择。— Codex + UI
final class FontCatalogService implements FontCatalog {
  FontCatalogService({required this.repository, required this.files});
  final ReaderFontRepository repository;
  final ReaderFontFiles files;

  @override
  Future<({List<ReaderFont> fonts, List<String> missing})>
  loadAvailable() async {
    final fonts = <ReaderFont>[];
    final missing = <String>[];
    for (final font in await repository.load()) {
      try {
        fonts.add(await files.load(font));
      } catch (error) {
        missing.add(font.family);
        debugPrint('自定义字体加载失败：${font.family}，$error');
      }
    }
    return (
      fonts: List<ReaderFont>.unmodifiable(fonts),
      missing: List<String>.unmodifiable(missing),
    );
  }

  @override
  Future<String?> loadFamily(String family) async {
    if (family.isEmpty) return null;
    final font = (await repository.load())
        .where((font) => font.family == family)
        .firstOrNull;
    if (font == null) throw StateError('字体不在目录中：$family');
    await files.load(font);
    return font.family;
  }

  @override
  Future<ReaderFont> importFont(String name, Uint8List bytes) async {
    final font = await files.install(name, bytes);
    await repository.add(font);
    return font;
  }
}
