import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/reader_theme_session.dart';
import '../../domain/models/reader_theme_mode.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/models/reader_font.dart';
import '../../domain/contracts/reader_font_repository.dart';
import '../../data/repositories/app_reader_font_repository.dart';
import '../../data/services/reader_font_service.dart';
import '../../platform/reader_font_files.dart';
import '../../data/repositories/app_reader_settings_repository.dart';
import '../../data/repositories/app_reader_style_repository.dart';
import '../../domain/contracts/reader_style_repository.dart';
import '../../domain/models/reader_style.dart';
import '../../domain/contracts/reader_settings_repository.dart';
import '../app_settings_provider.dart';
import '../../models/reader_advanced_config.dart';

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

/// 高级配置共用阅读仓储，界面即时更新，存储按操作顺序保存快照。
class ReaderAdvConfigNotifier extends Notifier<ReaderAdvancedConfig?> {
  late ReaderSettingsRepository _repository;
  Future<ReaderAdvancedConfig>? _loading;
  bool _disposed = false;
  int _generation = 0;

  @override
  ReaderAdvancedConfig? build() {
    _repository = ref.watch(readerSettingsRepositoryProvider);
    _disposed = false;
    final generation = ++_generation;
    _loading = null;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() async {
      if (_disposed || generation != _generation) return;
      try {
        await ensureLoaded();
      } catch (error) {
        if (!_disposed && generation == _generation) {
          debugPrint('阅读配置加载失败: $error');
        }
      }
    });
    return null;
  }

  Future<ReaderAdvancedConfig> ensureLoaded() {
    if (state case final current?) return Future.value(current.copy());
    return _loading ??= _load(_generation, _repository);
  }

  Future<ReaderAdvancedConfig> _load(
    int generation,
    ReaderSettingsRepository repository,
  ) async {
    try {
      final loaded = await repository.loadAdvanced();
      if (_disposed || generation != _generation) return loaded.copy();
      state ??= loaded.copy();
      return state!.copy();
    } finally {
      if (!_disposed && generation == _generation) _loading = null;
    }
  }

  /// 可等待的统一提交入口；失败交回调用方，保留即时界面状态。
  Future<void> commit(ReaderAdvancedConfig config) {
    final snapshot = config.copy();
    state = snapshot.copy();
    return _repository.saveAdvanced(snapshot);
  }

  /// 页面无需等待磁盘写入；失败记录诊断，不产生未处理异步异常。
  void update(ReaderAdvancedConfig config) {
    unawaited(
      commit(config).catchError((Object error) {
        debugPrint('阅读配置保存失败: $error');
      }),
    );
  }
}

final readerAdvConfigProvider =
    NotifierProvider<ReaderAdvConfigNotifier, ReaderAdvancedConfig?>(
      ReaderAdvConfigNotifier.new,
    );
