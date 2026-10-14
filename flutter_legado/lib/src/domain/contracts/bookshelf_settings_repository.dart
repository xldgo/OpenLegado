import '../models/bookshelf_settings.dart';

/// 普通偏好的读取、订阅与显式字段更新。— Codex + UI
abstract interface class BookshelfSettingsRepository {
  BookshelfSettings get current;
  Stream<BookshelfSettings> watch();
  Future<BookshelfSettings> load();
  Future<void> reload();
  Future<void> update({
    bool? isGridView,
    int? gridColumns,
    GroupMode? groupMode,
    int? selectedGroupIndex,
    bool? openBookInfoByClickTitle,
    bool? deleteBookAlert,
  });
}
