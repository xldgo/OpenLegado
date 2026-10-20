import 'package:material_ui/material_ui.dart';

/// 通用Sheet标题规则，通过ThemeData统一配置并继承局部主题。— Codex + UI
@immutable
class AppSheetTheme extends ThemeExtension<AppSheetTheme> {
  const AppSheetTheme({this.centerTitle = true});

  final bool centerTitle;

  @override
  AppSheetTheme copyWith({bool? centerTitle}) =>
      AppSheetTheme(centerTitle: centerTitle ?? this.centerTitle);

  @override
  AppSheetTheme lerp(covariant AppSheetTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
