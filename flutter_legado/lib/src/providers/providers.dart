import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/book_api.dart';
import '../app/bootstrap/book_api_bootstrap.dart';
import '../data/bridge/runtime_configuration.dart';
import '../services/settings_service.dart';

/// BookApi 全局 Provider（Riverpod 注入层）
///
/// 正式启动由 main 注入已经初始化的同一实例；独立测试可覆盖此 Provider。
/// 未覆盖时使用同一工厂，按 --dart-define=USE_MOCK 选择实现：
/// - USE_MOCK=true → MockBookApi（纯 Dart 假数据，UI 轨独立开发用）
/// - 默认 → RustApi（真实 FFI 实现，需 Rust DLL）
///
/// 使用方式：在 Notifier 中通过 `ref.read(bookApiProvider)` 获取实例。
final bookApiProvider = Provider<BookApi>((ref) => createBookApi());

/// 配置刷新复用应用装配的实现；Mock 保持空操作。— Codex + UI
final readingConfigSyncProvider = Provider<ReadingConfigSync>(
  (ref) => readingConfigSyncFor(ref.watch(bookApiProvider)),
);

/// SettingsService 全局 Provider（F3-18：统一注入，禁止 UI 直接 new）
final settingsProvider = Provider<SettingsService>((ref) => SettingsService());
