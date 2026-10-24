import '../../domain/contracts/reader_style_repository.dart';
import '../../domain/models/reader_style.dart';
import '../services/app_settings_service.dart';
import '../settings/reader_style_store.dart';
import 'app_reader_settings_repository.dart';

/// 配色与布局共用同一文档；有效排版由阅读设置仓储投影。— Codex + Data
final class AppReaderStyleRepository implements ReaderStyleRepository {
  AppReaderStyleRepository(AppSettingsService service)
    : _store = ReaderStyleStore(
        service,
        layoutAddresses: AppReaderSettingsRepository.layoutAddresses,
      );
  final ReaderStyleStore _store;

  @override
  ReaderStyles get current => _store.current;
  @override
  Stream<ReaderStyles> watch() => _store.watch();
  @override
  Future<ReaderStyles> load() => _store.load();
  @override
  Future<void> reload() => _store.reload();
  @override
  Future<void> select(String id) => _store.select(id);
  @override
  Future<void> setShareLayout(bool enabled) => _store.setShareLayout(enabled);
  @override
  Future<String> createFromTemplate(String id, String name) =>
      _store.createFromTemplate(id, name);
  @override
  Future<void> restorePreset(String presetId) => _store.restorePreset(presetId);
  @override
  Future<void> updateColors({
    required bool isNight,
    required ReaderColors Function(ReaderColors colors) update,
  }) => _store.updateColors(isNight: isNight, update: update);
}
