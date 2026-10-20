import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_reader_font_repository.dart';
import '../data/services/font_catalog_service.dart';
import '../domain/contracts/reader_font_repository.dart';
import '../domain/contracts/font_catalog.dart';
import '../domain/models/reader_font.dart';
import '../platform/reader_font_files.dart';

/// 共享字体资产的唯一实例；界面与阅读偏好分别持有选择。— Codex + UI
final readerFontRepositoryProvider = Provider<ReaderFontRepository>((ref) {
  final repository = AppReaderFontRepository();
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final readerFontsProvider = StreamProvider<List<ReaderFont>>(
  (ref) => ref.watch(readerFontRepositoryProvider).watch(),
);
final readerFontFilesProvider = Provider<ReaderFontFiles>(
  (ref) => ReaderFontFiles(),
);
final fontCatalogServiceProvider = Provider<FontCatalog>(
  (ref) => FontCatalogService(
    repository: ref.watch(readerFontRepositoryProvider),
    files: ref.watch(readerFontFilesProvider),
  ),
);
