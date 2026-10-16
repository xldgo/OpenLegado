import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/data/services/mock_network_service.dart';
import 'package:flutter_legado/src/data/services/mock_local_server_service.dart';
import 'package:flutter_legado/src/data/services/mock_rule_execution_service.dart';
import 'package:flutter_legado/src/providers/network_provider.dart';
import 'package:flutter_legado/src/providers/local_server_provider.dart';
import 'package:flutter_legado/src/providers/rule_execution_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/providers/association/association_notifier.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mock服务与根配置共享同一存储；Web停止不影响MCP配置', () async {
    final api = MockBookApi();
    await api.localServerService.setServerPort(4321);
    expect(await api.configRepository.getConfig('server_port'), '4321');
    await api.localServerService.startServer(port: 8080);
    expect(await api.configRepository.getConfig('server_running'), 'true');
    expect((await api.localServerService.getServerStatus()).port, 8080);
    await api.localServerService.setMcpPort(1236);
    await api.localServerService.stopServer();
    expect((await api.localServerService.getServerStatus()).running, isFalse);
    expect(await api.configRepository.getConfig('mcpPort'), '1236');
    await api.localServerService.setMcpPort(0);
    expect(await api.configRepository.getConfig('mcpPort'), '0');
  });

  test('hosts写入、清空及校验失败与根配置保持一致', () async {
    final api = MockBookApi();
    await api.networkService.setCustomHosts('{"example.test":"127.0.0.1"}');
    expect(
      await api.configRepository.getConfig('customHosts'),
      '{"example.test":"127.0.0.1"}',
    );
    await expectLater(
      api.networkService.setCustomHosts('[]'),
      throwsFormatException,
    );
    expect(
      await api.configRepository.getConfig('customHosts'),
      '{"example.test":"127.0.0.1"}',
    );
    await api.networkService.setCustomHosts('');
    expect(await api.configRepository.getConfig('customHosts'), '');
  });
  test('MockMCP越界不覆盖原配置', () async {
    final api = MockBookApi();
    await api.localServerService.setMcpPort(1236);
    await expectLater(
      api.localServerService.setMcpPort(80),
      throwsArgumentError,
    );
    expect(await api.configRepository.getConfig('mcpPort'), '1236');
  });
  test('Mock响应类型化，明确保留无真实网络和规则执行的占位', () async {
    final api = MockBookApi();
    final get = await api.networkService.httpGet('https://example.test');
    expect(get.body, isEmpty);
    expect(get.url, 'https://example.test');
    expect(
      (await api.networkService.httpGetBytes('https://image.test')).bytes,
      isEmpty,
    );
    expect(
      (await api.networkService.httpPost(
        'https://example.test',
        'data',
      )).isSuccess,
      isTrue,
    );
    expect(await api.ruleExecutionService.parseRule('原文', 'p', 'css'), '原文');
    expect(await api.ruleExecutionService.evalJs('1+1'), 'undefined');
    expect(await api.ruleExecutionService.getJsEngineVersion(), 'mock-quickjs');
  });
  test('根装配共享实例，三个窄Provider均可独立替换', () {
    final api = MockBookApi();
    final root = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(root.dispose);
    expect(root.read(networkServiceProvider), same(api.networkService));
    expect(root.read(localServerServiceProvider), same(api.localServerService));
    expect(
      root.read(ruleExecutionServiceProvider),
      same(api.ruleExecutionService),
    );
    final network = MockNetworkService(configs: {});
    final server = MockLocalServerService(configs: {});
    const rules = MockRuleExecutionService();
    final isolated = ProviderContainer(
      overrides: [
        networkServiceProvider.overrideWithValue(network),
        localServerServiceProvider.overrideWithValue(server),
        ruleExecutionServiceProvider.overrideWithValue(rules),
        bookApiProvider.overrideWith((ref) => throw StateError('不应读取根实例')),
      ],
    );
    addTearDown(isolated.dispose);
    expect(isolated.read(networkServiceProvider), same(network));
    expect(isolated.read(localServerServiceProvider), same(server));
    expect(isolated.read(ruleExecutionServiceProvider), same(rules));
    final injected = MockBookApi(
      networkService: network,
      localServerService: server,
      ruleExecutionService: rules,
    );
    expect(injected.networkService, same(network));
    expect(injected.localServerService, same(server));
    expect(injected.ruleExecutionService, same(rules));
    expect(createBookApi(useMock: true), isA<MockBookApi>());
  });

  test('关联导入使用独立网络Provider，HTTP错误不解析正文或写入', () async {
    final network = NetworkServiceMock();
    when(() => network.httpGet('https://example.test')).thenAnswer(
      (_) async => const HttpTextResponse(statusCode: 503, body: '{}'),
    );
    final container = ProviderContainer(
      overrides: [
        networkServiceProvider.overrideWithValue(network),
        bookApiProvider.overrideWith((ref) => throw StateError('不应读取根实例')),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(associationNotifierProvider.notifier)
        .loadFromUrl('https://example.test');
    final state = container.read(associationNotifierProvider);
    expect(state.isLoading, isFalse);
    expect(state.items, isEmpty);
    expect(state.error, contains('503'));
  });
}
