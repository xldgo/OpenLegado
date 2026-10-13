import '../../data/services/rust_source_checker.dart';
import '../../data/repositories/rust_book_source_repository.dart';
import '../../services/cover_decode_loader.dart';
import '../../data/repositories/rust_bookshelf_repository.dart';
import '../../data/repositories/rust_book_group_repository.dart';
import '../../data/bridge/runtime_configuration.dart';
import '../../data/services/rust_http_tts_synthesizer.dart';
import '../../data/bridge/rust_runtime.dart';
import '../../data/repositories/rust_bookmark_repository.dart';
import '../../data/repositories/rust_read_record_repository.dart';
import '../../data/repositories/rust_http_tts_repository.dart';
import '../../platform/app_environment.dart';
import '../../services/book_api.dart';
import '../../services/mock_book_api.dart';
import '../../services/rust_api.dart';
import 'rust_bootstrap.dart';
import 'settings_runtime_configuration.dart';

/// 应用装配点集中选择实现和生命周期。— Codex + UI
BookApi createBookApi({
  bool useMock = const bool.fromEnvironment('USE_MOCK'),
  RustBootstrap? bootstrap,
}) {
  if (useMock) return MockBookApi();
  final startup =
      bootstrap ??
      RustBootstrap(
        runtime: const NativeRustRuntime(),
        environment: const NativeAppEnvironment(),
        configurationSource: SettingsRuntimeConfiguration(),
      );
  return RustApi(
    initialize: startup.initialize,
    readingConfigSync: startup.configurationSync,
    bookmarkRepository: const RustBookmarkRepository(),
    readRecordRepository: const RustReadRecordRepository(),
    httpTtsRepository: const RustHttpTtsRepository(),
    httpTtsSynthesizer: const RustHttpTtsSynthesizer(),
    bookshelfRepository: const RustBookshelfRepository(),
    bookGroupRepository: const RustBookGroupRepository(),
    sourceChecker: const RustSourceChecker(),
    bookSourceRepository: const RustBookSourceRepository(
      onSourcesChanged: CoverDecodeLoader.invalidateSourceRegistry,
    ),
  );
}

/// 初始化成功后返回原实例，供根 ProviderScope 注入；失败原样上抛。
Future<BookApi> initializeBookApi({BookApi? api}) async {
  final instance = api ?? createBookApi();
  await instance.initialize();
  return instance;
}

/// 消费者不识别具体 RustApi；Mock 缺少此能力时保持空操作。
ReadingConfigSync readingConfigSyncFor(BookApi api) => api is ReadingConfigSync
    ? api as ReadingConfigSync
    : const NoopReadingConfigSync();
