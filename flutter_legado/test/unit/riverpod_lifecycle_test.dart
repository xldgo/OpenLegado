import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/providers/bottom_bar_skin_notifier.dart';
import 'package:flutter_legado/src/providers/explore/explore_notifier.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/features/search/search.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initializers = <String, void Function(ProviderContainer)>{
    '书架': (container) => container.read(bookshelfNotifierProvider),
    '发现': (container) => container.read(exploreNotifierProvider),
    '搜索': (container) => container.read(searchNotifierProvider),
    '阅读设置': (container) => container.read(readerNotifierProvider),
    '主题': (container) => container.read(themeNotifierProvider),
    '界面设置': (container) => container.read(uiSettingsProvider),
    '底栏皮肤': (container) => container.read(bottomBarSkinProvider),
  };

  for (final initializer in initializers.entries) {
    for (final started in [false, true]) {
      test(
        '${initializer.key}：${started ? '加载中' : '刚初始化'}销毁不会写回失效状态',
        () async {
          SharedPreferences.setMockInitialValues({});
          final gate = Completer<void>();
          final api = MockRustApi();
          when(api.bookshelfRepository.getBooks).thenAnswer((_) async {
            await gate.future;
            return [];
          });
          when(api.bookGroupRepository.getBookGroups).thenAnswer((_) async {
            await gate.future;
            return [];
          });
          when(api.bookSourceRepository.getBookSources).thenAnswer((_) async {
            await gate.future;
            return [];
          });
          when(api.searchHistoryRepository.getSearchHistory)
              .thenAnswer((_) async {
                await gate.future;
                return [];
              });
          when(() => api.configRepository.getConfig('searchScope'))
              .thenAnswer((_) async {
                await gate.future;
                return null;
              });
          final container = ProviderContainer(
            overrides: mergeTestOverrides([...api.overrides]),
          );
          initializer.value(container);
          if (started) await Future<void>.delayed(Duration.zero);
          container.dispose();
          gate.complete();
          // 未取消的底层请求可以完成，但不能再更新已销毁的状态。
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        },
      );
    }
  }
}
