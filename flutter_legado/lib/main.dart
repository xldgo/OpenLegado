import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/routes.dart';
import 'src/app/bootstrap/application_dependencies.dart';
import 'src/app/bootstrap/application_scope.dart';
import 'src/app/bootstrap/application_bootstrap.dart';
import 'src/app/bootstrap/rust_bootstrap.dart';
import 'src/data/bridge/rust_runtime.dart';
import 'src/platform/app_environment.dart';
import 'src/app/bootstrap/app_settings_factory.dart';
import 'src/app/bootstrap/settings_runtime_configuration.dart';
import 'src/app/session/reader_theme_session.dart';
import 'src/features/reader/application/reader_settings_provider.dart';
import 'src/data/repositories/app_appearance_settings_repository.dart';
import 'src/data/repositories/app_backup_settings_repository.dart';
import 'src/providers/app_settings_provider.dart';
import 'src/services/crash_log_service.dart';

void main() {
  runZonedGuarded(
    () async {
      final totalSw = Stopwatch()..start();

      WidgetsFlutterBinding.ensureInitialized();

      // 只装配共享设置服务；目录读取仍由日志服务需要备份时触发。
      late final ProviderContainer container;
      final appSettings = createAppSettingsService(
        configRepository: () => container.read(configRepositoryProvider),
      );

      // 1. 崩溃日志服务（最先初始化，确保后续异常可被捕获）
      final readerThemeSession = ReaderThemeSession();
      var sw = Stopwatch()..start();
      await CrashLogService.instance.init(
        backupSettings: AppBackupSettingsRepository(appSettings),
      );
      debugPrint('[启动] CrashLogService 初始化耗时：${sw.elapsedMilliseconds}ms');

      // 2. 注册全局错误捕获
      FlutterError.onError = (details) {
        CrashLogService.instance.logError(details.exception, details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        CrashLogService.instance.logError(error, stack);
        return true;
      };

      // 3. 读取上次崩溃日志
      final lastCrash = await CrashLogService.instance.getLastCrashLog();

      // 4. 并行初始化：SharedPreferences 与 Rust FFI 无依赖，可并行
      // SharedPreferences 预热供 SettingsService；启动和界面使用同一Provider容器。
      sw = Stopwatch()..start();
      container = createApplicationContainer(
        overrides: [
          appSettingsServiceProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(appSettings.dispose()));
            return appSettings;
          }),
          readerThemeSessionProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(readerThemeSession.dispose()));
            return readerThemeSession;
          }),
          rustBootstrapProvider.overrideWith(
            (ref) => RustBootstrap(
              runtime: const NativeRustRuntime(),
              environment: const NativeAppEnvironment(),
              configurationSource: SettingsRuntimeConfiguration(
                appSettings: appSettings,
                readingSession: readerThemeSession,
                appearance: AppAppearanceSettingsRepository(appSettings),
              ),
            ),
          ),
        ],
      );
      try {
        final apiInitialization = initializeApplication(container);
        await Future.wait<Object?>([
          SharedPreferences.getInstance(),
          apiInitialization,
        ]);
      } catch (e, stack) {
        CrashLogService.instance.logError(e, stack);
        container.dispose();
        await appSettings.dispose();
        await readerThemeSession.dispose();
        debugPrint('[Legado] 初始化失败：$e');
        runApp(_FfiErrorApp(error: e.toString()));
        return;
      }
      debugPrint('[启动] 并行初始化（prefs+FFI）耗时：${sw.elapsedMilliseconds}ms');

      // 5. 冷启动始终经闪屏路由（对齐 WelcomeActivity；时长 0 则立即进主页）
      const initialRoute = AppRoutes.welcome;

      debugPrint('[启动] 总启动耗时：${totalSw.elapsedMilliseconds}ms');

      // 6. 启动应用（传入崩溃日志）
      // ProviderScope 为 Riverpod 全局作用域：全部状态管理已迁移至 Riverpod Notifier
      // （主题/书架/书源/RSS/阅读统计/同步/书签/替换规则/定时任务/阅读器/搜索/发现等）
      runApp(
        ApplicationScope(
          container: container,
          child: LegadoApp(initialRoute: initialRoute, lastCrashLog: lastCrash),
        ),
      );
    },
    (error, stack) {
      // Zone 级异常兜底：记录到崩溃日志
      CrashLogService.instance.logError(error, stack);
    },
  );
}

/// FFI 初始化失败时显示的错误页面
class _FfiErrorApp extends StatelessWidget {
  final String error;

  const _FfiErrorApp({required this.error});

  String get _fixHint {
    final lower = error.toLowerCase();
    final isHashMismatch =
        lower.contains('content hash') ||
        lower.contains('out-of-sync') ||
        lower.contains('rustcontenthash');

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (isHashMismatch) {
        return 'Android 上 Rust .so 与当前 Dart 桥接代码不同步（content hash 失配）。\n\n'
            '请在仓库根目录执行：\n'
            'python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64\n\n'
            'Release 包请改用 --profile release，并指定实际需要的 ABI。\n'
            '然后重新安装 APK。';
      }
      return '请确认已构建 Android Rust FFI 动态库：\n'
          '在仓库根目录执行：\n'
          'python scripts/dev.py build android --profile debug --abis arm64-v8a,x86_64\n'
          '然后重新安装 APK；Release 包请改用 --profile release。';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return '请在仓库根目录启动开发会话（先重编译 DLL）：\n'
          'python scripts/dev.py run windows --profile debug\n\n'
          'Release 包请改用 --profile release；DLL 被占用时先手动关闭应用。';
    }

    return '请确认已构建 Rust FFI 动态库，然后重新运行应用。\n'
        '纯 UI 开发可使用：flutter run --dart-define=USE_MOCK=true';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Rust 引擎初始化失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Text(
                  _fixHint,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
