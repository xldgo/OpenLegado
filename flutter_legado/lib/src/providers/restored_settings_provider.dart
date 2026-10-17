import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap/restored_settings_refresher.dart';
import '../features/bookshelf/bookshelf.dart';
import 'backup_settings_provider.dart';
import '../features/bookshelf/application/bookshelf_settings_provider.dart';
import 'eye_protection_settings_provider.dart';
import 'general_settings_provider.dart';
import 'locale_settings_provider.dart';
import '../features/home/application/main_prefs_notifier.dart';
import 'read_record_settings_provider.dart';
import '../features/reader/application/reader_settings_provider.dart';
import 'theme/system_bar_notifier.dart';
import 'theme/theme_colors_notifier.dart';
import 'theme/theme_notifier.dart';
import 'ui_settings/ui_settings_notifier.dart';
import 'welcome_settings_provider.dart';
import 'config_settings_provider.dart';
import '../features/search/search_settings_provider.dart';
import '../features/read_aloud/read_aloud_settings_provider.dart';

/// 由应用Provider持有，页面关闭不截断已经开始的刷新。— Codex + UI
final restoredSettingsRefresherProvider = Provider<RestoredSettingsRefresher>(
  (ref) => RestoredSettingsRefresher([
    ('主题', () => ref.read(themeNotifierProvider.notifier).reload()),
    ('主题颜色', () => ref.read(themeColorsProvider.notifier).reload()),
    ('主界面', () => ref.read(mainPrefsProvider.notifier).reload()),
    ('界面布局', () => ref.read(uiSettingsProvider.notifier).reload()),
    ('系统栏', () => ref.read(systemBarProvider.notifier).reload()),
    ('书架设置', () => ref.read(bookshelfSettingsRepositoryProvider).reload()),
    ('阅读记录', () => ref.read(readRecordSettingsRepositoryProvider).reload()),
    ('基础阅读', () => ref.read(readerSettingsRepositoryProvider).reload()),
    ('字体目录', () => ref.read(readerFontRepositoryProvider).reload()),
    ('阅读配色', () => ref.read(readerStyleRepositoryProvider).reload()),
    ('语言', () => ref.read(localeSettingsRepositoryProvider).reload()),
    ('护眼', () => ref.read(eyeProtectionSettingsRepositoryProvider).reload()),
    ('欢迎页', () => ref.read(welcomeSettingsRepositoryProvider).reload()),
    ('应用行为', () => ref.read(generalSettingsRepositoryProvider).reload()),
    ('备份', () => ref.read(backupSettingsRepositoryProvider).reload()),
    ('漫画设置', () => ref.read(mangaSettingsRepositoryProvider).reload()),
    ('换源设置', () => ref.read(changeSourceSettingsRepositoryProvider).reload()),
    ('播放设置', () => ref.read(audioPlaybackSettingsRepositoryProvider).reload()),
    ('服务设置', () => ref.read(serviceSettingsRepositoryProvider).reload()),
    ('搜索设置', () => ref.read(searchSettingsRepositoryProvider).reload()),
    ('朗读设置', () => ref.read(readAloudSettingsRepositoryProvider).reload()),
    (
      '书架数据',
      () async {
        ref.invalidate(bookshelfNotifierProvider);
      },
    ),
  ]),
);
