import 'dart:async';

import 'package:flutter_legado/src/data/repositories/preferences_webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keys = [
  'sync_webdav_url',
  'sync_webdav_username',
  'sync_webdav_password',
  'sync_webdav_remote_dir',
  'sync_webdav_device_name',
];

/// 使用真实Preferences保存和重读，并模拟写入后返回失败的内存缓存行为。
class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);

  final SharedPreferences delegate;
  String? failureKey;
  bool throwsOnFailure = false;
  Completer<void>? writeGate;
  final started = Completer<void>();

  @override
  String? getString(String key) => delegate.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    final success = await delegate.setString(key, value);
    if (!started.isCompleted) started.complete();
    await writeGate?.future;
    if (failureKey == key) {
      failureKey = null;
      if (throwsOnFailure) throw StateError('模拟平台异常');
      return false;
    }
    return success;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const previous = WebDavConnection(
    url: 'https://old.example',
    username: '旧账号',
    password: '  旧口令  ',
    remoteDir: '/old/',
    deviceName: '旧设备',
  );
  const changed = WebDavConnection(
    url: 'https://new.example',
    username: '新账号',
    password: '  新口令  ',
    remoteDir: '/new/',
    deviceName: '新设备',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('缺省五字段保持原默认且缺键不补写', () async {
    final repository = PreferencesWebDavConnectionRepository();
    expect(await repository.load(), const WebDavConnection());
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('真实Preferences重新加载五字段，密码首尾空白不变', () async {
    final repository = PreferencesWebDavConnectionRepository();
    final saved = await repository.save(
      const WebDavConnection(
        url: ' https://new.example ',
        username: ' 新账号 ',
        password: '  新口令  ',
        remoteDir: ' /new/ ',
        deviceName: ' 新设备 ',
      ),
    );
    expect(saved, changed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(await PreferencesWebDavConnectionRepository().load(), changed);
    expect(prefs.getKeys(), _keys.toSet());
  });

  test('保存空目录使用/legado/，读取已存值不额外trim', () async {
    final repository = PreferencesWebDavConnectionRepository();
    expect(
      (await repository.save(const WebDavConnection(remoteDir: '  ')))
          .remoteDir,
      '/legado/',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keys.first, ' 原存值 ');
    await prefs.setString(_keys[3], '');
    final loaded = await repository.load();
    expect(loaded.url, ' 原存值 ');
    expect(loaded.remoteDir, '');
  });

  for (final throwsOnFailure in [false, true]) {
    for (final key in _keys) {
      test('写入${throwsOnFailure ? '异常' : '拒绝'}在$key时回退，后续load和重试一致', () async {
        final real = PreferencesWebDavConnectionRepository();
        await real.save(previous);
        final prefs = await SharedPreferences.getInstance();
        final controlled = _ControlledPreferences(prefs)
          ..failureKey = key
          ..throwsOnFailure = throwsOnFailure;
        final repository = PreferencesWebDavConnectionRepository(
          loadPreferences: () async => controlled,
        );

        await expectLater(repository.save(changed), throwsStateError);
        expect(await repository.load(), previous);
        await prefs.reload();
        expect(await real.load(), previous);
        expect(await repository.save(changed), changed);
        expect(await real.load(), changed);
      });
    }
  }

  test('首次保存失败恢复缺键而非补写默认值', () async {
    final prefs = await SharedPreferences.getInstance();
    final controlled = _ControlledPreferences(prefs)..failureKey = _keys[2];
    final repository = PreferencesWebDavConnectionRepository(
      loadPreferences: () async => controlled,
    );
    await expectLater(repository.save(changed), throwsStateError);
    await prefs.reload();
    expect(prefs.getKeys(), isEmpty);
    expect(await repository.load(), const WebDavConnection());
  });

  test('连续保存和读取按调用顺序排队，不读取半份连接', () async {
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    final controlled = _ControlledPreferences(prefs)..writeGate = gate;
    final repository = PreferencesWebDavConnectionRepository(
      loadPreferences: () async => controlled,
    );
    final first = repository.save(previous);
    await controlled.started.future;
    var readCompleted = false;
    final between = repository.load().then((value) {
      readCompleted = true;
      return value;
    });
    final second = repository.save(changed);
    await Future<void>.delayed(Duration.zero);
    expect(readCompleted, isFalse);
    gate.complete();
    await first;
    expect(await between, previous);
    await second;
    expect(await repository.load(), changed);
  });

  test('读取加载器异常向上传递，队列允许之后重试', () async {
    var fail = true;
    final repository = PreferencesWebDavConnectionRepository(
      loadPreferences: () async {
        if (fail) throw StateError('模拟读取失败');
        return SharedPreferences.getInstance();
      },
    );
    await expectLater(repository.load(), throwsStateError);
    fail = false;
    expect(await repository.load(), const WebDavConnection());
  });
}
