import '../../models/reader_advanced_config.dart';
import '../models/reader_settings.dart';
import '../models/page_turn_mode.dart';

/// 阅读设置同源访问；高级配置不重复保存基础偏好和字体。— Codex + UI
abstract interface class ReaderSettingsRepository {
  ReaderSettings get current;
  Stream<ReaderSettings> watch();
  Future<ReaderSettings> load();
  Future<void> reload();

  /// 未传字段不变；正文字体空串删除选择，标题空串跟随正文。
  Future<void> update({
    PageTurnMode? pageTurnMode,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    String? titleFontFamily,
  });
  Future<ReaderAdvancedConfig> loadAdvanced();
  Future<void> saveAdvanced(ReaderAdvancedConfig config);
}
