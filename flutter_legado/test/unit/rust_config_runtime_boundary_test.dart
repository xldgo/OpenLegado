import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_config_repository.dart';
import 'package:flutter_legado/src/data/bridge/rust_app_runtime.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustConfigRepository();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);
  test('原配置键和值原样传递，空字符串读取为null，删除写空串', () async {
    when(() => bridge.crateFfiFfiConfigGet(key: 'empty'))
        .thenAnswer((_) async => '');
    when(() => bridge.crateFfiFfiConfigGet(key: 'key'))
        .thenAnswer((_) async => 'value');
    when(() => bridge.crateFfiFfiConfigSet(key: 'key', value: '新值'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiConfigSet(key: 'key', value: ''))
        .thenAnswer((_) async => true);
    expect(await repository.getConfig('empty'), isNull);
    expect(await repository.getConfig('key'), 'value');
    await repository.setConfig('key', '新值');
    await repository.deleteConfig('key');
    verify(() => bridge.crateFfiFfiConfigSet(key: 'key', value: '')).called(1);
  });
  test('枚举在适配器解码，不伪造空结果；写入拒绝和原生异常传播', () async {
    when(() => bridge.crateFfiFfiConfigGetAll())
        .thenAnswer((_) async => {'a': '2', 'b': 'true'});
    expect(await repository.getAllConfigs(), {'a': '2', 'b': 'true'});
    when(() => bridge.crateFfiFfiConfigGetAll()).thenAnswer((_) async => {});
    expect(await repository.getAllConfigs(), isEmpty);
    when(() => bridge.crateFfiFfiConfigSet(key: 'fail', value: 'x'))
        .thenAnswer((_) async => false);
    await expectLater(repository.setConfig('fail', 'x'), throwsStateError);
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiConfigGet(key: 'fail')).thenThrow(error);
    await expectLater(() => repository.getConfig('fail'), throwsA(same(error)));
    when(() => bridge.crateFfiFfiConfigSet(key: 'fail', value: ''))
        .thenThrow(error);
    await expectLater(
      () => repository.deleteConfig('fail'),
      throwsA(same(error)),
    );
  });
  test('应用运行时委托完整启动，查询版本不触发启动，失败原样传播', () async {
    var initialized = 0;
    final runtime = RustAppRuntime(
      startup: () async {
        initialized++;
      },
    );
    when(() => bridge.crateFfiFfiVersion()).thenAnswer((_) async => '原生版本');
    expect(await runtime.getVersion(), '原生版本');
    expect(initialized, 0);
    await runtime.initialize();
    expect(initialized, 1);
    final error = StateError('启动失败');
    final failing = RustAppRuntime(startup: () async => throw error);
    await expectLater(failing.initialize(), throwsA(same(error)));
    when(() => bridge.crateFfiFfiVersion()).thenThrow(error);
    await expectLater(() => runtime.getVersion(), throwsA(same(error)));
  });
}
