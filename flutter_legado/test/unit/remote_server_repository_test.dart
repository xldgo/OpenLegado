import 'package:flutter_legado/src/data/repositories/preferences_remote_server_repository.dart';
import 'package:flutter_legado/src/domain/models/remote_server_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serversKey = 'remote_servers';
const _selectedKey = 'remote_server_id';
const _first = RemoteServerConfig(
  id: 1,
  name: '服务器一',
  url: 'https://one.example',
  username: '账号',
  password: ' 口令 ',
);
const _second = RemoteServerConfig(
  id: 2,
  name: '服务器二',
  url: 'https://two.example',
);

class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);

  final SharedPreferences delegate;
  String? failureKey;
  bool throwsOnFailure = false;

  @override
  String? getString(String key) => delegate.getString(key);
  @override
  int? getInt(String key) => delegate.getInt(key);

  Future<bool> _finish(String key, Future<bool> writing) async {
    final result = await writing;
    if (key == failureKey) {
      failureKey = null;
      if (throwsOnFailure) throw StateError('模拟写入异常');
      return false;
    }
    return result;
  }

  @override
  Future<bool> setString(String key, String value) =>
      _finish(key, delegate.setString(key, value));
  @override
  Future<bool> setInt(String key, int value) =>
      _finish(key, delegate.setInt(key, value));
  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('缺省为空列表和默认选中项，不补写存储', () async {
    final saved = await PreferencesRemoteServerRepository().load();
    expect(saved.servers, isEmpty);
    expect(saved.selectedId, defaultRemoteServerId);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('真实Preferences恢复原五字段JSON与选中项，快照列表不可变', () async {
    final repository = PreferencesRemoteServerRepository();
    await repository.save(_first);
    await repository.select(_first.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(
      prefs.getString(_serversKey),
      '[{"id":1,"name":"服务器一","url":"https://one.example","username":"账号","password":" 口令 "}]',
    );
    final saved = await PreferencesRemoteServerRepository().load();
    expect(saved.servers.single.toJson(), _first.toJson());
    expect(saved.selectedId, 1);
    expect(() => saved.servers.add(_second), throwsUnsupportedError);
    final input = [_first];
    final snapshot = RemoteServerSnapshot(servers: input);
    input.clear();
    expect(snapshot.servers.single.id, 1);
  });

  test('损坏JSON或非列表回退空目录，不覆盖原存储及选中项', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedKey, 7);
    for (final raw in ['损坏', '{}', '[{"id":"错误类型"}]']) {
      await prefs.setString(_serversKey, raw);
      final saved = await PreferencesRemoteServerRepository().load();
      expect(saved.servers, isEmpty);
      expect(saved.selectedId, 7);
      expect(prefs.getString(_serversKey), raw);
    }
  });

  test('连续新增编辑选择删除读最新持久值，不丢其他服务器', () async {
    final repository = PreferencesRemoteServerRepository();
    await Future.wait([
      repository.save(_first),
      repository.save(_second),
      repository.save(_first.copyWith(name: '已编辑')),
      repository.select(1),
      repository.delete(2),
    ]);
    final saved = await repository.load();
    expect(saved.servers.single.name, '已编辑');
    expect(saved.selectedId, 1);
    final external = PreferencesRemoteServerRepository();
    await external.save(_second);
    await repository.save(_first);
    expect((await repository.load()).servers.map((s) => s.id), [1, 2]);
  });

  for (final throwsOnFailure in [false, true]) {
    test('列表写入${throwsOnFailure ? '异常' : '拒绝'}保持原值，可重试', () async {
      final real = PreferencesRemoteServerRepository();
      await real.save(_first);
      final prefs = await SharedPreferences.getInstance();
      final controlled = _ControlledPreferences(prefs)
        ..failureKey = _serversKey
        ..throwsOnFailure = throwsOnFailure;
      final repository = PreferencesRemoteServerRepository(
        loadPreferences: () async => controlled,
      );
      await expectLater(repository.save(_second), throwsStateError);
      await prefs.reload();
      expect(
        (await repository.load()).servers.single.toJson(),
        _first.toJson(),
      );
      await repository.save(_second);
      expect((await repository.load()).servers.length, 2);
    });

    test('选中项写入${throwsOnFailure ? '异常' : '拒绝'}保持缺键，可重试', () async {
      final prefs = await SharedPreferences.getInstance();
      final controlled = _ControlledPreferences(prefs)
        ..failureKey = _selectedKey
        ..throwsOnFailure = throwsOnFailure;
      final repository = PreferencesRemoteServerRepository(
        loadPreferences: () async => controlled,
      );
      await expectLater(repository.select(1), throwsStateError);
      await prefs.reload();
      expect(prefs.containsKey(_selectedKey), isFalse);
      expect((await repository.load()).selectedId, defaultRemoteServerId);
      expect((await repository.select(1)).selectedId, 1);
    });

    for (final key in [_serversKey, _selectedKey]) {
      test('删除当前服务器$key${throwsOnFailure ? '异常' : '拒绝'}恢复两键，可重试', () async {
        final real = PreferencesRemoteServerRepository();
        await real.save(_first);
        await real.save(_second);
        await real.select(1);
        final prefs = await SharedPreferences.getInstance();
        final before = prefs.getString(_serversKey);
        final controlled = _ControlledPreferences(prefs)
          ..failureKey = key
          ..throwsOnFailure = throwsOnFailure;
        final repository = PreferencesRemoteServerRepository(
          loadPreferences: () async => controlled,
        );
        await expectLater(repository.delete(1), throwsStateError);
        await prefs.reload();
        expect(prefs.getString(_serversKey), before);
        expect(prefs.getInt(_selectedKey), 1);
        final saved = await repository.delete(1);
        expect(saved.servers.single.id, 2);
        expect(saved.selectedId, defaultRemoteServerId);
        expect((await real.load()).selectedId, defaultRemoteServerId);
      });
    }
  }

  test('删除其他服务器保持当前选中项与同一快照中的其他记录', () async {
    final repository = PreferencesRemoteServerRepository();
    await repository.save(_first);
    await repository.save(_second);
    await repository.select(1);
    final saved = await repository.delete(2);
    expect(saved.servers.single.id, 1);
    expect(saved.selectedId, 1);
  });

  test('初始读取异常向上传递，队列允许随后重试', () async {
    var fail = true;
    final repository = PreferencesRemoteServerRepository(
      loadPreferences: () async {
        if (fail) throw StateError('模拟读取异常');
        return SharedPreferences.getInstance();
      },
    );
    await expectLater(repository.load(), throwsStateError);
    fail = false;
    expect((await repository.load()).servers, isEmpty);
  });
}
