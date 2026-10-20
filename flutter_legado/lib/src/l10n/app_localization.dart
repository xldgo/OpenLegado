import 'package:flutter/widgets.dart';

import 'app_strings.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// 正式页面由本地化代理驱动重建；独立旧页面继续兼容 AppStrings 入口。
extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppStrings.current;
}
