import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application_dependencies.dart';
import 'rust_bootstrap.dart';
import '../../data/bridge/runtime_configuration.dart';
import '../../features/appearance/appearance_settings_provider.dart';

/// 只返回Riverpod装配，不创建可供业务层定位服务的根对象。— Codex + UI
ProviderContainer createApplicationContainer({
  bool useMock = const bool.fromEnvironment('USE_MOCK'),
  RustBootstrap? bootstrap,
  List<Override> overrides = const [],
}) => ProviderContainer(
  overrides: [
    mockModeProvider.overrideWithValue(useMock),
    themeConfigSyncProvider.overrideWith(
      (ref) => ref.watch(mockModeProvider)
          ? const NoopThemeConfigSync()
          : ref.watch(rustBootstrapProvider).configurationSync,
    ),
    if (bootstrap != null) ...[
      rustBootstrapProvider.overrideWithValue(bootstrap),
    ],
    ...overrides,
  ],
  retry: (retryCount, error) => null,
);

/// 初始化失败不返回未就绪的应用，调用方负责容器生命周期。
Future<void> initializeApplication(ProviderContainer container) =>
    container.read(appRuntimeProvider).initialize();
