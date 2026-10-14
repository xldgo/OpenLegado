/// WelcomeSettings 普通偏好，不包含存储与加载状态。— Codex + UI
final class WelcomeSettings {
  const WelcomeSettings({
    this.showTime = 500,
    this.customWelcome = false,
    this.imageDay = '',
    this.imageNight = '',
    this.showText = true,
    this.showIcon = true,
    this.showTextDark = true,
    this.showIconDark = true,
    this.defaultToRead = false,
  });
  final int showTime;
  final bool customWelcome;
  final String imageDay;
  final String imageNight;
  final bool showText;
  final bool showIcon;
  final bool showTextDark;
  final bool showIconDark;
  final bool defaultToRead;

  WelcomeSettings copyWith({
    int? showTime,
    bool? customWelcome,
    String? imageDay,
    String? imageNight,
    bool? showText,
    bool? showIcon,
    bool? showTextDark,
    bool? showIconDark,
    bool? defaultToRead,
  }) => WelcomeSettings(
    showTime: showTime ?? this.showTime,
    customWelcome: customWelcome ?? this.customWelcome,
    imageDay: imageDay ?? this.imageDay,
    imageNight: imageNight ?? this.imageNight,
    showText: showText ?? this.showText,
    showIcon: showIcon ?? this.showIcon,
    showTextDark: showTextDark ?? this.showTextDark,
    showIconDark: showIconDark ?? this.showIconDark,
    defaultToRead: defaultToRead ?? this.defaultToRead,
  );

  @override
  bool operator ==(Object other) =>
      other is WelcomeSettings &&
      showTime == other.showTime &&
      customWelcome == other.customWelcome &&
      imageDay == other.imageDay &&
      imageNight == other.imageNight &&
      showText == other.showText &&
      showIcon == other.showIcon &&
      showTextDark == other.showTextDark &&
      showIconDark == other.showIconDark &&
      defaultToRead == other.defaultToRead;

  @override
  int get hashCode => Object.hashAll([
    showTime,
    customWelcome,
    imageDay,
    imageNight,
    showText,
    showIcon,
    showTextDark,
    showIconDark,
    defaultToRead,
  ]);
}
