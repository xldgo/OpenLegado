import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/reader_theme_session.dart';
import '../../../domain/models/reader_theme_mode.dart';
import '../../../domain/models/reader_settings.dart';
import '../../../domain/models/reader_font.dart';
import '../../../domain/contracts/reader_font_repository.dart';
import '../../../data/repositories/app_reader_font_repository.dart';
import '../../../data/services/reader_font_service.dart';
import '../../../platform/reader_font_files.dart';
import '../../../data/repositories/app_reader_settings_repository.dart';
import '../../../data/repositories/app_reader_style_repository.dart';
import '../../../domain/contracts/reader_style_repository.dart';
import '../../../domain/models/reader_style.dart';
import '../../../domain/contracts/reader_settings_repository.dart';
import '../../../providers/app_settings_provider.dart';

final readerSettingsRepositoryProvider = Provider<ReaderSettingsRepository>(
  (ref) => AppReaderSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

final readerSettingsProvider = StreamProvider<ReaderSettings>(
  (ref) => ref.watch(readerSettingsRepositoryProvider).watch(),
);

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

final readerFontServiceProvider = Provider<ReaderFontService>(
  (ref) => ReaderFontService(
    repository: ref.watch(readerFontRepositoryProvider),
    settings: ref.watch(readerSettingsRepositoryProvider),
    files: ref.watch(readerFontFilesProvider),
  ),
);

final readerStyleRepositoryProvider = Provider<ReaderStyleRepository>(
  (ref) => AppReaderStyleRepository(ref.watch(appSettingsServiceProvider)),
);

final readerStylesProvider = StreamProvider<ReaderStyles>(
  (ref) => ref.watch(readerStyleRepositoryProvider).watch(),
);

final readerThemeSessionProvider = Provider<ReaderThemeSession>((ref) {
  final session = ReaderThemeSession();
  ref.onDispose(() => unawaited(session.dispose()));
  return session;
});

final readerThemeModeProvider = StreamProvider<ReaderThemeMode>(
  (ref) => ref.watch(readerThemeSessionProvider).watch(),
);
