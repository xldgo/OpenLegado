import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';

/// 独立仓储测试显式装配共享服务，并在用例结束后释放。— Codex + UI
AppReaderSettingsRepository createTestReaderSettingsRepository({
  Future<SharedPreferences> Function()? preferences,
}) {
  final service = AppSettingsService(
    storages: {
      SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(
        preferences: preferences,
      ),
    },
  );
  // 部分仓储在普通 setUp 装配；释放由原事件循环完成，不在 Widget 假时钟内等待。
  addTearDown(() => unawaited(service.dispose()));
  return AppReaderSettingsRepository(service);
}
