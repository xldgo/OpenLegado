/// LocaleSettings 普通偏好，不包含存储与加载状态。— Codex + UI
final class LocaleSettings {
  const LocaleSettings({this.locale = 'system'});
  final String locale;

  LocaleSettings copyWith({String? locale}) =>
      LocaleSettings(locale: locale ?? this.locale);

  @override
  bool operator ==(Object other) =>
      other is LocaleSettings && locale == other.locale;

  @override
  int get hashCode => Object.hashAll([locale]);
}
