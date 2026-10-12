import 'book_api.dart';
import 'mock_book_api.dart';
import 'rust_api.dart';

/// 集中选择启动实现，遵循现有 USE_MOCK 配置。— Codex + UI
BookApi createBookApi({
  bool useMock = const bool.fromEnvironment('USE_MOCK'),
}) => useMock ? MockBookApi() : RustApi();

/// 初始化成功后返回原实例，供根 ProviderScope 注入；失败原样上抛。
Future<BookApi> initializeBookApi({BookApi? api}) async {
  final instance = api ?? createBookApi();
  await instance.initialize();
  return instance;
}
