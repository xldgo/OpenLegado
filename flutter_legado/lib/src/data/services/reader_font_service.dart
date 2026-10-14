import 'package:flutter/foundation.dart';

import '../../domain/contracts/reader_font_repository.dart';
import '../../domain/contracts/reader_settings_repository.dart';
import '../../domain/models/reader_font.dart';
import '../../domain/models/reader_settings.dart';
import '../../platform/reader_font_files.dart';

/// 复用文件加载和目录接口，编排导入及运行时注册。— Codex + UI
final class ReaderFontService {
  ReaderFontService({
    required this.repository,
    required this.settings,
    required this.files,
  });

  final ReaderFontRepository repository;
  final ReaderSettingsRepository settings;
  final ReaderFontFiles files;

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

  Future<int> loadSelected(ReaderSettings selected) async {
    final families = <String>{
      if (selected.fontFamily?.startsWith('Custom_') ?? false)
        selected.fontFamily!,
      if (selected.titleFontFamily.startsWith('Custom_'))
        selected.titleFontFamily,
    };
    if (families.isEmpty) return 0;
    for (final font in await repository.load()) {
      if (!families.contains(font.family)) continue;
      try {
        await files.load(font);
      } catch (error) {
        debugPrint('阅读字体加载失败：${font.family}，$error');
      }
    }
    return files.revisionFor(families);
  }

  Future<String> importFont(
    String name,
    Uint8List bytes, {
    required bool title,
  }) async {
    final font = await files.install(name, bytes);
    await repository.add(font);
    await settings.update(
      fontFamily: title ? null : font.family,
      titleFontFamily: title ? font.family : null,
    );
    return font.label;
  }
}
