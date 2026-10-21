import 'package:flutter_legado/src/providers/network_provider.dart';
import 'package:flutter_legado/src/providers/replace_rule_repository_provider.dart';
import 'package:flutter_legado/src/platform/source_import_file_reader.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/preview_normalize_stub.dart';

import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart'
    show mockModeProvider;
import 'package:flutter_legado/src/app/bootstrap/source_import_factory.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/data/services/source_import_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/services/source_import_parser.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/features/imports/application/association_notifier.dart';

import '../mocks/mocks.dart';

class _RepositoryMock extends Mock implements BookSourceRepository {}

const _source =
    '{"bookSourceUrl":"https://source.test","bookSourceName":"中文源",'
    '"lastUpdateTime":"123","ruleToc":{"isVolume":"false"}}';

void main() {
  late _RepositoryMock repository;
  late SourceImportService service;
  late HttpTextResponse response;
  String? fileText;
  final fetched = <({String url, Duration timeout})>[];
  final readPaths = <String>[];
  final replaced = <({String json, String name, String url})>[];
  final imported = <String>[];

  setUp(() {
    repository = _RepositoryMock();
    fetched.clear();
    readPaths.clear();
    replaced.clear();
    imported.clear();
    response = const HttpTextResponse(statusCode: 200, body: _source);
    fileText = _source;
    when(() => repository.importBookSources(any())).thenAnswer((inv) async {
      imported.add(inv.positionalArguments.first as String);
      return 1;
    });
    service = SourceImportService(
      repository: repository,
      fetchText: (url, {required timeout}) async {
        fetched.add((url: url, timeout: timeout));
        return response;
      },
      readFile: (path) async {
        readPaths.add(path);
        return fileText;
      },
      applyReplaceRules: (json, name, url) async {
        replaced.add((json: json, name: name, url: url));
        return json.replaceAll('中文源', '替换源');
      },
      normalize: stubPreviewNormalize,
    );
  });

  test('审查回归：预览和确认导入共用归一化名称URL并保留原文', () async {
    final service = SourceImportService(
      repository: repository,
      fetchText: (_, {required timeout}) async => response,
      readFile: (_) async => null,
      applyReplaceRules: (json, name, url) async {
        expect(name, '12');
        expect(url, '34');
        expect(jsonDecode(json)['bookSourceName'], 12);
        return json;
      },
      normalize: (_) async => [
        {'bookSourceName': '12', 'bookSourceUrl': '34', 'lastUpdateTime': 0},
      ],
    );
    const input = '{"bookSourceName":12,"bookSourceUrl":34}';
    expect(
      (await service.fetchSourcesFromText(input)).single.bookSourceName,
      '12',
    );
    final result = await service.importFromJson(input);
    expect(result.success, 1);
    expect(result.failed, 0);
    expect((jsonDecode(imported.single) as List).single['bookSourceUrl'], 34);
  });

  test('审查回归：预览保留有效候选及其原始序号', () async {
    final parser = SourceImportParser(
      normalize: (_) async => [
        {
          'bookSourceUrl': 'https://first.test',
          'bookSourceName': '甲',
          'lastUpdateTime': 0,
        },
        {'error': '第2项结构错误'},
        {'error': 'ruleSearch语法错误'},
        {
          'bookSourceUrl': 'https://last.test',
          'bookSourceName': '乙',
          'lastUpdateTime': 0,
        },
      ],
    );
    final items = await parser.parseSourcesText(
      '[{"bookSourceUrl":"https://first.test","bookSourceName":"甲"},42,{"ruleSearch":"{broken"},{"bookSourceUrl":"https://last.test","bookSourceName":"乙"}]',
    );
    expect(items.map((s) => s.bookSourceName), ['甲', '乙']);
    expect(items.last.raw['bookSourceUrl'], 'https://last.test');
  });

  test('审查回归：全部候选失败时保留Rust字段错误', () async {
    final parser = SourceImportParser(
      normalize: (_) async => [
        {'error': '第 1 项 ruleSearch: 规则JSON语法错误'},
      ],
    );
    await expectLater(
      parser.parseSourcesText('[{"ruleSearch":"{broken"}]'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          '字段原因',
          contains('ruleSearch'),
        ),
      ),
    );
  });

  test('审查回归：Mock装配预览无需原生FFI且能确认导入', () async {
    final container = ProviderContainer(
      overrides: [mockModeProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    final service = container.read(sourceImportServiceProvider);
    const input =
        '{"bookSourceUrl":"https://mock-preview.test","bookSourceName":"Mock源"}';
    expect(
      (await service.fetchSourcesFromText(input)).single.bookSourceName,
      'Mock源',
    );
    expect((await service.importFromJson(input)).success, 1);
  });

  group('预览只读取输入', () {
    test('URL 预览保留原 JSON，不执行替换或入库', () async {
      final items = await service.fetchSourcesFromUrl('https://import.test');
      expect(fetched, [
        (url: 'https://import.test', timeout: const Duration(seconds: 30)),
      ]);
      expect(items.single.bookSourceName, '中文源');
      expect(items.single.lastUpdateTime, 123);
      expect(items.single.raw['lastUpdateTime'], '123');
      expect(items.single.raw['ruleToc'], {'isVolume': 'false'});
      expect(replaced, isEmpty);
      expect(imported, isEmpty);
      expect(readPaths, isEmpty);
    });

    test('文件预览与 URL 共用解析且不入库', () async {
      final items = await service.fetchSourcesFromFile('中文 空格.json');
      expect(readPaths, ['中文 空格.json']);
      expect(items.single.bookSourceName, '中文源');
      expect(fetched, isEmpty);
      expect(replaced, isEmpty);
      expect(imported, isEmpty);
    });

    test('HTTP 失败直接报告原状态，不尝试解析或写入', () async {
      response = const HttpTextResponse(statusCode: 503, body: '不是 JSON');
      await expectLater(
        service.fetchSourcesFromUrl('https://import.test'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'HTTP 请求失败：状态码 503',
          ),
        ),
      );
      expect(imported, isEmpty);
      expect(replaced, isEmpty);
    });

    test('缺失文件预览抛原文案', () async {
      fileText = null;
      await expectLater(
        service.fetchSourcesFromFile('missing.json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            '文件不存在：missing.json',
          ),
        ),
      );
      expect(imported, isEmpty);
    });

    test('无效预览 JSON 不执行任何写入', () async {
      response = const HttpTextResponse(statusCode: 200, body: '[]');
      await expectLater(
        service.fetchSourcesFromUrl('https://import.test'),
        throwsFormatException,
      );
      expect(imported, isEmpty);
      expect(replaced, isEmpty);
    });
  });

  group('输入共用逐条导入流程', () {
    for (final input in ['JSON', 'URL', '文件']) {
      test('$input 导入先替换再写入，透传名称、URL 与原始字段', () async {
        final result = switch (input) {
          'JSON' => await service.importFromJson(_source, unit: '自定义单位'),
          'URL' => await service.importFromUrl(
            'https://import.test',
            unit: '自定义单位',
          ),
          _ => await service.importFromFile('source.json', unit: '自定义单位'),
        };
        expect(result.total, 1);
        expect(result.success, 1);
        expect(result.hasErrors, isFalse);
        expect(result.unit, '自定义单位');
        expect(replaced.single.name, '中文源');
        expect(replaced.single.url, 'https://source.test');
        expect(jsonDecode(replaced.single.json), jsonDecode(_source));
        final source = (jsonDecode(imported.single) as List).single as Map;
        expect(source['bookSourceName'], '替换源');
        expect(source['lastUpdateTime'], '123');
        expect(source['ruleToc'], {'isVolume': 'false'});
      });
    }

    test('逐条失败后继续，不将整批改成一个事务', () async {
      final events = <String>[];
      final gate = Completer<int>();
      when(() => repository.importBookSources(any())).thenAnswer((inv) {
        final item =
            (jsonDecode(inv.positionalArguments.first as String) as List).single
                as Map;
        final name = item['bookSourceName'] as String;
        events.add(name);
        if (name == '一') return gate.future;
        if (name == '二') throw const AppException('第二条拒绝写入');
        return Future.value(1);
      });
      final task = service.importFromJson(
        jsonEncode([
          {'bookSourceUrl': 'https://1.test', 'bookSourceName': '一'},
          {'bookSourceUrl': 'https://2.test', 'bookSourceName': '二'},
          {'bookSourceUrl': 'https://3.test', 'bookSourceName': '三'},
        ]),
      );
      await pumpEventQueue();
      expect(events, ['一']);
      gate.complete(1);
      final result = await task;
      expect(events, ['一', '二', '三']);
      expect(result.total, 3);
      expect(result.success, 2);
      expect(result.failed, 1);
      expect(result.errors, ['导入「二」失败：第二条拒绝写入']);
    });

    test('替换能力失败保持原文，仍尝试写入', () async {
      service = SourceImportService(
        repository: repository,
        fetchText: (_, {required timeout}) async => response,
        readFile: (_) async => fileText,
        applyReplaceRules: (_, _, _) async => throw StateError('替换未就绪'),
        normalize: stubPreviewNormalize,
      );
      final result = await service.importFromJson(_source);
      expect(result.success, 1);
      expect(result.errors, isEmpty);
      expect((jsonDecode(imported.single) as List).single, jsonDecode(_source));
    });

    test('Repository 返回零时保留原逐条成功计数', () async {
      when(() => repository.importBookSources(any()))
          .thenAnswer((_) async => 0);
      final result = await service.importFromJson(_source);
      expect(result.total, 1);
      expect(result.success, 1);
      expect(result.failed, 0);
    });

    test('非对象失败、无必填字段跳过，两者不进入替换和写入', () async {
      final result = await service.importFromJson(
        '[null, {"bookSourceName":"缺URL"}, $_source]',
      );
      expect(result.total, 3);
      expect(result.success, 1);
      expect(result.failed, 1);
      expect(result.skipped, 1);
      expect(result.errors, [
        '第 1 项不是有效的 JSON 对象',
        '第 2 项校验失败：缺少 bookSourceUrl',
      ]);
      expect(imported, hasLength(1));
      expect(replaced, hasLength(1));
    });

    test('非字符串必填字段确认导入使用归一化结果', () async {
      final result = await service.importFromJson(
        '{"bookSourceName":123,"bookSourceUrl":"https://source.test"}',
      );
      expect(result.total, 1);
      expect(result.failed, 0);
      expect(result.success, 1);
      expect(result.skipped, 0);
      expect(imported, hasLength(1));
      expect(replaced.single.name, '123');
    });
  });

  group('失败与异常边界', () {
    test('URL HTTP 失败保留状态提示和单位', () async {
      response = const HttpTextResponse(statusCode: 404, body: 'not JSON');
      final result = await service.importFromUrl(
        'https://import.test',
        unit: '条目',
      );
      expect(result.total, 0);
      expect(result.unit, '条目');
      expect(result.errors, ['HTTP 请求失败：状态码 404']);
      expect(imported, isEmpty);
    });

    test('真实 async 超时沿用原 URL 失败提示，预览抛原异常', () async {
      final failure = TimeoutException('请求超时');
      service = SourceImportService(
        repository: repository,
        fetchText: (_, {required timeout}) async => throw failure,
        readFile: (_) async => fileText,
        applyReplaceRules: (json, _, _) async => json,
        normalize: stubPreviewNormalize,
      );
      final result = await service.importFromUrl('https://import.test');
      expect(result.errors, ['从 URL 导入失败：$failure']);
      await expectLater(
        service.fetchSourcesFromUrl('https://import.test'),
        throwsA(same(failure)),
      );
      expect(imported, isEmpty);
    });

    test('文件缺失与读取错误不混淆', () async {
      fileText = null;
      final missing = await service.importFromFile('missing.json', unit: '条目');
      expect(missing.unit, '条目');
      expect(missing.errors, ['文件不存在：missing.json']);
      final failure = FileSystemException('拒绝读取', 'locked.json');
      service = SourceImportService(
        repository: repository,
        fetchText: (_, {required timeout}) async => response,
        readFile: (_) async => throw failure,
        applyReplaceRules: (json, _, _) async => json,
        normalize: stubPreviewNormalize,
      );
      final failed = await service.importFromFile('locked.json');
      expect(failed.errors, ['读取文件失败：$failure']);
      await expectLater(
        service.fetchSourcesFromFile('locked.json'),
        throwsA(same(failure)),
      );
      expect(imported, isEmpty);
    });

    test('JSON 类型错误与语法错误保留不同前缀', () async {
      final shape = await service.importFromJson('123');
      expect(shape.errors, ['无效的 JSON 格式：期望数组或对象']);
      final syntax = await service.importFromJson('not JSON');
      expect(syntax.errors.single, startsWith('JSON 解析错误：'));
      expect(imported, isEmpty);
    });

    test('纯解析器保留非字符串、空白字段与未知字段', () async {
      final parser = SourceImportParser(normalize: stubPreviewNormalize);
      final items = await parser.parseSourcesText(
        '{"bookSourceName":123,"bookSourceUrl":" ","自定义":{"enabled":"false"}}',
      );
      expect(items.single.bookSourceName, '123');
      expect(items.single.bookSourceUrl, ' ');
      expect(items.single.raw['自定义'], {'enabled': 'false'});
      expect(
        parser.validateSource({
          'bookSourceUrl': items.single.bookSourceUrl,
          'bookSourceName': items.single.bookSourceName,
        }),
        isEmpty,
      );
    });
  });

  test('平台适配实际 UTF-8 中文/空格路径及文件缺失', () async {
    final directory = await Directory.systemTemp.createTemp(
      'legado-source-import-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}中文 书源.json');
    await file.writeAsString(_source, encoding: utf8);
    expect(await readSourceImportFile(file.path), _source);
    expect(await readSourceImportFile('${file.path}.missing'), isNull);
  });

  test('两个 Notifier 跟随窄依赖替换，在途导入仍使用捕获的实例', () async {
    final first = MockRustApi();
    final second = MockRustApi();
    final container = ProviderContainer(
      overrides: [
        sourcePreviewNormalizerProvider.overrideWithValue(stubPreviewNormalize),
        bookSourceRepositoryProvider.overrideWithValue(
          first.bookSourceRepository,
        ),
        networkServiceProvider.overrideWithValue(first.networkService),
        replaceRuleServiceProvider.overrideWithValue(first.replaceRuleService),
      ],
    );
    addTearDown(container.dispose);
    for (final api in [first, second]) {
      when(() => api.networkService.httpGet(any())).thenAnswer(
        (_) async => const HttpTextResponse(statusCode: 200, body: _source),
      );
      when(
        () => api.replaceRuleService.applyReplaceRulesToSource(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((inv) async => inv.positionalArguments.first as String);
      when(() => api.bookSourceRepository.importBookSources(any()))
          .thenAnswer((_) async => 1);
    }
    final inFlight = SourceImportService(
      repository: first.bookSourceRepository,
      fetchText: first.networkService.httpGet,
      readFile: readSourceImportFile,
      applyReplaceRules: first.replaceRuleService.applyReplaceRulesToSource,
      normalize: stubPreviewNormalize,
    );
    final source = container.read(sourceNotifierProvider.notifier);
    final association = container.read(associationNotifierProvider.notifier);
    await source.importService.importFromUrl('https://first.test');
    container.updateOverrides([
      sourcePreviewNormalizerProvider.overrideWithValue(stubPreviewNormalize),
      bookSourceRepositoryProvider.overrideWithValue(
        second.bookSourceRepository,
      ),
      networkServiceProvider.overrideWithValue(second.networkService),
      replaceRuleServiceProvider.overrideWithValue(second.replaceRuleService),
    ]);
    await source.importService.importFromUrl('https://second.test');
    await association.importService.importFromJson(_source);
    await inFlight.importFromJson(_source);
    verify(() => first.networkService.httpGet('https://first.test')).called(1);
    verifyNever(() => first.networkService.httpGet('https://second.test'));
    verify(() => second.networkService.httpGet('https://second.test'))
        .called(1);
    verify(() => first.bookSourceRepository.importBookSources(any())).called(2);
    verify(() => second.bookSourceRepository.importBookSources(any()))
        .called(2);
    for (final api in [first, second]) {
      verify(
        () => api.replaceRuleService.applyReplaceRulesToSource(
          any(),
          '中文源',
          'https://source.test',
        ),
      ).called(2);
      verifyNever(() => api.runtime.initialize());
    }
  });
}
