import '../../models/reader_advanced_config.dart';
import '../models/reader_settings.dart';
import '../models/page_turn_mode.dart';
import '../models/reader_page_layout_settings.dart';

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
    bool? tocLoadWordCount,
    bool? chapterInSystemBrowser,
  });

  /// 只修改传入的正文排版字段，不保存其他页面的旧快照。
  Future<void> updateTextLayout({
    double? paragraphSpacing,
    double? letterSpacing,
    int? paragraphIndent,
    bool? textFullJustify,
    int? textBold,
    bool? italic,
    bool? useZhLayout,
    bool? hangingPunctuation,
  });
  Future<void> updatePageLayout({
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? doubleHorizontalPage,
  });
  Future<void> updatePageEdge(
    ReaderPageEdge edge, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? mode,
    bool? showLine,
    int? leftTip,
    int? middleTip,
    int? rightTip,
  });
  Future<void> updateTitle({
    int? mode,
    int? size,
    int? topSpacing,
    int? bottomSpacing,
  });
  Future<ReaderAdvancedConfig> loadAdvanced();
  Future<void> saveAdvanced(ReaderAdvancedConfig config);
}
