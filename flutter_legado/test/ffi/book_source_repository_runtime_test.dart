@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 直接书源适配的真实宿主 FFI 与通知时序回归。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_source_repository.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_edit_service.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('源配置共享数据库，变量仅更新单列，成功写入才通知失效', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/book-source-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: nativeTestRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final shared = api.bookSourceRepository;
    int notifications = 0;
    final repository = RustBookSourceRepository(
      onSourcesChanged: () => notifications++,
    );
    // 复用原版ContentRuleCompatibilityTest的batchSettings，集中验证一次完整往返。
    // 最后一项是本项目既定的整数字符串扩展。
    const batchSettings = <(String?, Object?, int?)>[
      (null, null, null),
      ('', null, null),
      (null, 0, 0),
      ('@js:batch()', null, null),
      (null, 4, 4),
      ('@js:batch()', 4, 4),
      ('@js:batch()', '10', 10),
    ];
    for (final (batch, size, expectedSize) in batchSettings) {
      final rule = {
        'content': 'body@text',
        'contentBatch': batch,
        'maxBatchSize': size,
      };
      for (final input in [rule, jsonEncode(rule)]) {
        final parsed = await const RustBookSourceEditService().parseSource(
          jsonEncode({
            'bookSourceUrl': 'fixture://parsed-batch',
            'bookSourceName': '批量规则',
            'ruleContent': input,
          }),
        );
        expect(parsed.ruleContent?.contentBatch, batch);
        expect(parsed.ruleContent?.maxBatchSize, expectedSize);
        expect(
          (await shared.getBookSources()).any(
            (s) => s.bookSourceUrl == parsed.bookSourceUrl,
          ),
          isFalse,
        );
        await shared.importBookSources(
          jsonEncode([
            {
              'bookSourceUrl': parsed.bookSourceUrl,
              'bookSourceName': parsed.bookSourceName,
              'ruleContent': input,
            },
          ]),
        );
        await shared.updateBookSource(parsed.copyWith(bookSourceName: '改名'));
        final rows = (jsonDecode(await shared.exportBookSources()) as List)
            .cast<Map<String, dynamic>>();
        final saved = BookSource.fromJson(
          rows.firstWhere(
            (row) => row['bookSourceUrl'] == parsed.bookSourceUrl,
          ),
        );
        expect(saved.ruleContent, parsed.ruleContent);
        await shared.deleteBookSource(parsed.bookSourceUrl);
      }
    }
    const source = BookSource(
      bookSourceUrl: 'fixture://source-a',
      bookSourceName: '真实源',
      bookSourceGroup: '分组',
      enabled: true,
      customOrder: 3,
    );
    final added = await repository.addBookSource(source);
    expect(added.bookSourceUrl, source.bookSourceUrl);
    expect(notifications, 1);
    await repository.updateBookSource(
      added.copyWith(bookSourceName: '已更新', customOrder: 5),
    );
    final beforeVariable = (await shared.getBookSources()).firstWhere(
      (s) => s.bookSourceUrl == source.bookSourceUrl,
    );
    await repository.setSourceVariable(source.bookSourceUrl, '变量');
    final afterVariable = (await shared.getBookSources()).firstWhere(
      (s) => s.bookSourceUrl == source.bookSourceUrl,
    );
    expect(afterVariable, beforeVariable.copyWith(variable: '变量'));
    expect(notifications, 3);
    await repository.disableBookSource(source.bookSourceUrl);
    expect(
      (await shared.getEnabledBookSources()).any(
        (s) => s.bookSourceUrl == source.bookSourceUrl,
      ),
      isFalse,
    );
    await repository.enableBookSource(source.bookSourceUrl);
    expect(
      (await shared.getEnabledBookSources()).any(
        (s) => s.bookSourceUrl == source.bookSourceUrl,
      ),
      isTrue,
    );
    await repository.sortBookSources(2, false);
    expect(await api.configRepository.getConfig('source_sort_key'), '2');
    expect(
      await api.configRepository.getConfig('source_sort_ascending'),
      'false',
    );
    expect(notifications, 5);
    expect(
      await repository.importBookSources(
        jsonEncode([
          source
              .copyWith(
                bookSourceUrl: 'fixture://source-b',
                bookSourceName: '已导入',
              )
              .toJson(),
        ]),
      ),
      1,
    );
    expect(notifications, 6);
    final exported = (jsonDecode(await repository.exportBookSources()) as List)
        .cast<Map<String, dynamic>>();
    expect(
      exported.any((s) => s['bookSourceUrl'] == 'fixture://source-b'),
      isTrue,
    );
    final beforeFailure = await shared.getBookSources();
    await expectLater(repository.importBookSources('坏JSON'), throwsA(anything));
    await expectLater(
      repository.setSourceVariable('fixture://missing', '值'),
      throwsA(anything),
    );
    expect(notifications, 6);
    expect(await shared.getBookSources(), beforeFailure);
    await repository.deleteBookSource(source.bookSourceUrl);
    expect(notifications, 7);
    expect(
      (await shared.getBookSources()).any(
        (s) => s.bookSourceUrl == source.bookSourceUrl,
      ),
      isFalse,
    );
    await api.runtime.initialize();
    expect(api.bookSourceRepository, same(shared));
  });
}

class _Environment implements AppEnvironment {
  _Environment(this.root);
  final String root;
  @override
  Future<String> databasePath() async =>
      '$root${Platform.pathSeparator}legado.db';
  @override
  Future<void> warmLocalBookStore() async {}
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async =>
      (await Directory('$root${Platform.pathSeparator}${cache.name}')
              .create(recursive: true))
          .path;
  @override
  Future<String?> deviceId() async => 'book-source-fixture';
}
