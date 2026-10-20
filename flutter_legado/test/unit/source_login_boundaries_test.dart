import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_source_login_repository.dart';
import 'package:flutter_legado/src/data/services/source_login_service.dart';
import 'package:flutter_legado/src/domain/models/source_login_credentials.dart';
import 'package:flutter_legado/src/domain/services/source_login_codec.dart';
import 'package:flutter_legado/src/features/book_sources/source_login_providers.dart';
import 'package:flutter_legado/src/models/misc.dart' show LoginKeyValue;
import 'package:flutter_legado/src/features/book_sources/application/source_login/source_login_notifier.dart';

import '../mocks/mocks.dart';

void main() {
  group('原始存储与转换', () {
    test('Mock 存储保留任意字符串、结构、空值及源隔离', () async {
      final repository = MockSourceLoginRepository();
      const info = '{"邮箱":"a@test","嵌套":{"unknown":true}}';
      await repository.putLoginInfo('A', info);
      await repository.putLoginHeader('A', '非 JSON');
      expect(await repository.getLoginInfo('A'), info);
      expect(await repository.getLoginHeader('A'), '非 JSON');
      expect(await repository.getLoginInfo('B'), '');
      await repository.putLoginInfo('A', '');
      expect(await repository.getLoginInfo('A'), '');
      expect(await MockSourceLoginRepository().getLoginHeader('A'), '');
    });

    test('转换保留原容错，Cookie 值中的等号和非 Cookie 头', () {
      const codec = SourceLoginCodec();
      final value = codec.decode(
        '{"token":"t"}',
        '{"cOoKiE":" sid=a=b; broken; theme=dark ","X-Count":3}',
      );
      expect(value.token, 't');
      expect(value.cookies, [
        const LoginKeyValue(name: 'sid', value: 'a=b'),
        const LoginKeyValue(name: 'theme', value: 'dark'),
      ]);
      expect(value.headers, [const LoginKeyValue(name: 'X-Count', value: '3')]);
      expect(codec.decode('{"邮箱":"原始表单"}', '[]').token, '{"邮箱":"原始表单"}');
      expect(codec.decode('plain token', 'bad header').token, 'plain token');
      expect(codec.decode('', '').cookies, isEmpty);
    });

    test('固定快照与原 Header 合并、重复键及 Cookie 覆盖保持', () {
      final cookies = [const LoginKeyValue(name: 'sid', value: 'a=b')];
      final value = SourceLoginCredentials(
        token: 't',
        cookies: cookies,
        headers: [
          const LoginKeyValue(name: 'X', value: '1'),
          const LoginKeyValue(name: 'X', value: '2'),
          const LoginKeyValue(name: '', value: '忽略'),
          const LoginKeyValue(name: 'Cookie', value: '旧值'),
        ],
      );
      cookies.clear();
      final json = const SourceLoginCodec().encode(value);
      expect(jsonDecode(json.infoJson), {'token': 't'});
      expect(jsonDecode(json.headerJson), {'X': '2', 'Cookie': 'sid=a=b'});
      expect(() => value.cookies.clear(), throwsUnsupportedError);
    });

    test('Provider 分享根引用，替换后跟随且不初始化', () {
      final first = MockRustApi();
      final second = MockRustApi();
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          sourceLoginRepositoryProvider.overrideWithValue(
            first.sourceLoginRepository,
          ),
        ]),
      );
      addTearDown(container.dispose);
      expect(
        container.read(sourceLoginRepositoryProvider),
        same(first.sourceLoginRepository),
      );
      container.updateOverrides(
        mergeTestOverrides([
          sourceLoginRepositoryProvider.overrideWithValue(
            second.sourceLoginRepository,
          ),
        ]),
      );
      expect(
        container.read(sourceLoginRepositoryProvider),
        same(second.sourceLoginRepository),
      );
      verifyNever(first.runtime.initialize);
      verifyNever(second.runtime.initialize);
      expect(
        createTestApplication(useMock: true).sourceLoginRepository,
        isA<MockSourceLoginRepository>(),
      );
    });
  });

  group('顺序服务与旧配置', () {
    late SourceLoginRepositoryMock repository;
    late SourceLoginService service;
    final calls = <String>[];
    String? legacy;
    setUp(() {
      calls.clear();
      legacy = null;
      repository = SourceLoginRepositoryMock();
      when(() => repository.getLoginInfo(any())).thenAnswer((_) async => '');
      when(() => repository.getLoginHeader(any())).thenAnswer((_) async => '');
      when(() => repository.putLoginHeader(any(), any())).thenAnswer((_) async {
        calls.add('header');
      });
      when(() => repository.putLoginInfo(any(), any())).thenAnswer((_) async {
        calls.add('info');
      });
      service = SourceLoginService(
        repository: repository,
        readLegacy: (_) async {
          calls.add('legacy-read');
          return legacy;
        },
        clearLegacy: (_) async {
          calls.add('legacy-clear');
        },
      );
    });

    test('新存储任一项非空就不读旧配置', () async {
      when(() => repository.getLoginHeader('A')).thenAnswer((_) async => '{}');
      await service.load('A');
      expect(calls, isEmpty);
    });

    test('旧配置只转换展示，加载不写入或清除', () async {
      legacy = jsonEncode({
        'token': 'old',
        'cookies': [
          {'name': 'sid', 'value': 'v'},
        ],
        'headers': [
          {'name': 'X', 'value': 'h'},
        ],
      });
      final value = await service.load('A');
      expect(value.token, 'old');
      expect(value.cookies.single.value, 'v');
      expect(value.headers.single.value, 'h');
      expect(calls, ['legacy-read']);
      verifyNever(() => repository.putLoginInfo(any(), any()));
      verifyNever(() => repository.putLoginHeader(any(), any()));
    });

    test('旧配置坏 JSON 保留原失败边界', () async {
      legacy = 'bad';
      await expectLater(service.load('A'), throwsFormatException);
    });

    test('先写 Header 后 Info，两次成功才清理旧键', () async {
      await service.save('A', SourceLoginCredentials(token: 't'));
      expect(calls, ['header', 'info', 'legacy-clear']);
    });

    test('Header 失败不写 Info，不清旧键', () async {
      final error = StateError('拒绝 Header');
      when(() => repository.putLoginHeader(any(), any())).thenThrow(error);
      await expectLater(
        service.save('A', SourceLoginCredentials()),
        throwsA(same(error)),
      );
      verifyNever(() => repository.putLoginInfo(any(), any()));
      expect(calls, isEmpty);
    });

    test('Info 失败保留已成功 Header，不伪造事务或清旧键', () async {
      final error = StateError('拒绝 Info');
      when(() => repository.putLoginInfo(any(), any())).thenThrow(error);
      await expectLater(
        service.save('A', SourceLoginCredentials()),
        throwsA(same(error)),
      );
      expect(calls, ['header']);
    });

    test('旧键清理失败仍按原尽力清理语义成功', () async {
      final tolerant = SourceLoginService(
        repository: repository,
        readLegacy: (_) async => null,
        clearLegacy: (_) async => throw StateError('清理失败'),
      );
      await tolerant.save('A', SourceLoginCredentials());
      expect(calls, ['header', 'info']);
    });
  });

  group('按源编辑会话', () {
    late SourceLoginRepositoryMock repository;
    late ProviderContainer container;
    setUp(() {
      repository = SourceLoginRepositoryMock();
      when(() => repository.getLoginInfo(any())).thenAnswer((_) async => '');
      when(() => repository.getLoginHeader(any())).thenAnswer((_) async => '');
      when(() => repository.putLoginHeader(any(), any()))
          .thenAnswer((_) async {});
      when(() => repository.putLoginInfo(any(), any()))
          .thenAnswer((_) async {});
      final service = SourceLoginService(
        repository: repository,
        readLegacy: (_) async => null,
        clearLegacy: (_) async {},
      );
      container = ProviderContainer(
        overrides: [sourceLoginServiceProvider.overrideWithValue(service)],
      );
      for (final url in ['A', 'B']) {
        container.listen(sourceLoginNotifierProvider(url), (_, _) {});
      }
      addTearDown(container.dispose);
    });
    SourceLoginNotifier notifier(String url) =>
        container.read(sourceLoginNotifierProvider(url).notifier);
    SourceLoginState state(String url) =>
        container.read(sourceLoginNotifierProvider(url));

    test('A 源凭据不会出现在空 B 源，再加载空 A 源也清空', () async {
      when(() => repository.getLoginInfo('A'))
          .thenAnswer((_) async => '{"token":"A-token"}');
      await notifier('A').load();
      await notifier('B').load();
      expect(state('A').token, 'A-token');
      expect(state('B').token, '');
      when(() => repository.getLoginInfo('A')).thenAnswer((_) async => '');
      await notifier('A').load();
      expect(state('A').token, '');
      expect(state('A').cookies, isEmpty);
    });

    test('同源较早加载结果不覆盖后发结果', () async {
      final gate = Completer<String>();
      when(() => repository.getLoginInfo('A')).thenAnswer((_) => gate.future);
      final old = notifier('A').load();
      when(() => repository.getLoginInfo('A'))
          .thenAnswer((_) async => '{"token":"new"}');
      await notifier('A').load();
      gate.complete('{"token":"old"}');
      await old;
      expect(state('A').token, 'new');
    });

    test('迟到加载失败不会覆盖当前结果', () async {
      final gate = Completer<String>();
      when(() => repository.getLoginInfo('A')).thenAnswer((_) => gate.future);
      final old = notifier('A').load();
      when(() => repository.getLoginInfo('A'))
          .thenAnswer((_) async => '{"token":"new"}');
      await notifier('A').load();
      gate.completeError(StateError('旧错误'));
      await old;
      expect(state('A').token, 'new');
      expect(state('A').error, isNull);
    });

    test('加载期间输入或清空使旧回填失效', () async {
      final gate = Completer<String>();
      when(() => repository.getLoginInfo('A')).thenAnswer((_) => gate.future);
      final load = notifier('A').load();
      notifier('A').setToken('正在输入');
      gate.complete('{"token":"旧值"}');
      await load;
      expect(state('A').token, '正在输入');
      expect(state('A').isLoading, isFalse);
    });

    test('保存使用源与输入快照，重复调用共用同一 Future', () async {
      final gate = Completer<void>();
      when(() => repository.putLoginHeader(any(), any()))
          .thenAnswer((_) => gate.future);
      final a = notifier('A');
      a.setToken('snapshot');
      a.addHeader('X', 'old');
      final save = a.save();
      expect(a.save(), same(save));
      a.setToken('edited');
      notifier('B').setToken('B-token');
      gate.complete();
      await save;
      verify(() => repository.putLoginInfo('A', '{"token":"snapshot"}'))
          .called(1);
      verify(() => repository.putLoginHeader('A', '{"X":"old"}')).called(1);
      verifyNever(() => repository.putLoginInfo('B', any()));
      expect(state('A').token, 'edited');
      expect(state('B').token, 'B-token');
    });

    test('加载期间拒绝保存，保存期间加载不会覆盖草稿', () async {
      final readGate = Completer<String>();
      when(() => repository.getLoginInfo('A'))
          .thenAnswer((_) => readGate.future);
      final a = notifier('A');
      final loading = a.load();
      await expectLater(a.save(), throwsStateError);
      readGate.complete('');
      await loading;
      a.setToken('draft');
      final writeGate = Completer<void>();
      when(() => repository.putLoginHeader(any(), any()))
          .thenAnswer((_) => writeGate.future);
      final saving = a.save();
      await a.load();
      expect(state('A').token, 'draft');
      writeGate.complete();
      await saving;
    });

    test('写入失败保留输入，可重试且停止等待状态', () async {
      final a = notifier('A');
      a.setToken('draft');
      when(() => repository.putLoginInfo(any(), any()))
          .thenThrow(StateError('失败'));
      await expectLater(a.save(), throwsStateError);
      expect(state('A').token, 'draft');
      expect(state('A').isSaving, isFalse);
      when(() => repository.putLoginInfo(any(), any()))
          .thenAnswer((_) async {});
      await a.save();
      expect(state('A').error, isNull);
    });

    test('销毁后加载结果不回写', () async {
      final gate = Completer<String>();
      when(() => repository.getLoginInfo('A')).thenAnswer((_) => gate.future);
      final task = notifier('A').load();
      container.dispose();
      gate.complete('{"token":"late"}');
      await task;
    });
  });
}
