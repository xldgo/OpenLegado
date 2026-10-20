import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';

class _Repository implements CloudTtsRepository {
  final inner = MockCloudTtsRepository();
  @override
  Future<List<CloudTtsEngine>> list() => inner.list();
  @override
  Future<List<String>> voices(String provider) => inner.voices(provider);
  bool failSave = false, failDelete = false;
  @override
  Future<void> save(CloudTtsEngine engine) async {
    if (failSave) throw StateError('DB 失败');
    await inner.save(engine);
  }

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('DB 删除失败');
    await inner.delete(id);
  }
}

class _Credentials implements CloudTtsCredentialStore {
  final values = <String, String>{};
  bool failWrite = false, failDelete = false, failAfterWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('安全存储不可用');
    values[key] = value;
    if (failAfterWrite) throw StateError('写入后确认失败');
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('密钥删除失败');
    values.remove(key);
  }
}

void main() {
  late _Repository repo;
  late _Credentials credentials;
  late CloudTtsSettings settings;
  const engine = CloudTtsEngine(id: 'cloud1', name: '测试云端');
  setUp(() {
    repo = _Repository();
    credentials = _Credentials();
    var id = 0;
    settings = CloudTtsSettings(
      repo,
      credentials,
      newId: () => 'fixture${id++}',
    );
  });
  const polly = CloudTtsEngine(
    id: 'polly',
    name: 'Polly',
    provider: 'aws_polly',
    region: 'us-east-1',
    model: 'neural',
  );
  test('Polly 成组凭据可分别轮换，未修改项保留，不进入元数据', () async {
    await settings.save(polly, apiKey: 'access', secretKey: 'secret');
    var saved = (await repo.list()).single;
    expect(jsonDecode(credentials.values[saved.credentialKey]!), {
      'apiKey': 'access',
      'secretKey': 'secret',
    });
    expect(jsonEncode(saved.toJson()), isNot(contains('secret')));
    final first = saved.credentialKey;
    await settings.save(polly);
    expect((await repo.list()).single.credentialKey, first);
    await settings.save(polly, secretKey: 'second');
    saved = (await repo.list()).single;
    expect(credentials.values, hasLength(1));
    expect(jsonDecode(credentials.values[saved.credentialKey]!), {
      'apiKey': 'access',
      'secretKey': 'second',
    });
    await settings.save(polly, apiKey: 'next');
    saved = (await repo.list()).single;
    expect(jsonDecode(credentials.values[saved.credentialKey]!), {
      'apiKey': 'next',
      'secretKey': 'second',
    });
    await settings.delete(saved);
    expect(credentials.values, isEmpty);
  });
  test('Polly 缺项拒绝保存，数据库失败保留整组旧凭据', () async {
    await expectLater(settings.save(polly, apiKey: 'access'), throwsStateError);
    expect(credentials.values, isEmpty);
    await settings.save(polly, apiKey: 'access', secretKey: 'secret');
    final old = (await repo.list()).single;
    repo.failSave = true;
    await expectLater(
      settings.save(polly, secretKey: 'new-secret'),
      throwsStateError,
    );
    expect(credentials.values, {
      old.credentialKey: jsonEncode({
        'apiKey': 'access',
        'secretKey': 'secret',
      }),
    });
    expect((await repo.list()).single.credentialKey, old.credentialKey);
  });
  test('Polly 原密钥损坏须成组重填，不回显内容', () async {
    await settings.save(polly, apiKey: 'access', secretKey: 'secret');
    final old = (await repo.list()).single;
    credentials.values[old.credentialKey] = 'broken-private';
    await expectLater(
      settings.save(polly, apiKey: 'next'),
      throwsA(predicate((e) => !e.toString().contains('broken-private'))),
    );
    await settings.save(polly, apiKey: 'next', secretKey: 'new');
    expect(credentials.values, hasLength(1));
  });
  test('凭据与元数据分开，更新引用后才清理旧凭据，空编辑保留', () async {
    await settings.save(engine, apiKey: 'private');
    final first = (await repo.list()).single;
    expect(jsonEncode(first.toJson()), isNot(contains('private')));
    expect(credentials.values[first.credentialKey], 'private');
    await settings.save(engine);
    expect((await repo.list()).single.credentialKey, first.credentialKey);
    await settings.save(engine, apiKey: 'new-private');
    final second = (await repo.list()).single;
    expect(second.credentialKey, isNot(first.credentialKey));
    expect(credentials.values, {second.credentialKey: 'new-private'});
  });
  test('数据库保存失败删除新凭据，旧配置/凭据完整保留', () async {
    await settings.save(engine, apiKey: 'old');
    final old = (await repo.list()).single;
    repo.failSave = true;
    await expectLater(settings.save(engine, apiKey: 'new'), throwsStateError);
    expect((await repo.list()).single.credentialKey, old.credentialKey);
    expect(credentials.values, {old.credentialKey: 'old'});
  });
  test('安全存储失败不写 DB，无凭据不冒充成功', () async {
    credentials.failWrite = true;
    await expectLater(settings.save(engine, apiKey: 'key'), throwsStateError);
    expect(await repo.list(), isEmpty);
    await expectLater(settings.save(engine), throwsStateError);
    expect(await repo.list(), isEmpty);
  });
  test('删除元数据失败保留凭据；成功后清理；失败后的队列仍可运行', () async {
    await settings.save(engine, apiKey: 'key');
    final saved = (await repo.list()).single;
    repo.failDelete = true;
    await expectLater(settings.delete(saved), throwsStateError);
    expect(credentials.values, hasLength(1));
    repo.failDelete = false;
    await settings.delete(saved);
    expect(await repo.list(), isEmpty);
    expect(credentials.values, isEmpty);
  });
  test('旧凭据清理失败准确报告已保存，不能撤销新引用', () async {
    await settings.save(engine, apiKey: 'old');
    credentials.failDelete = true;
    await expectLater(
      settings.save(engine, apiKey: 'new'),
      throwsA(predicate((e) => e.toString().contains('配置已保存'))),
    );
    final saved = (await repo.list()).single;
    expect(credentials.values[saved.credentialKey], 'new');
  });
  test('安全存储落盘后抛错也清理新引用，保留原凭据与数据库', () async {
    await settings.save(engine, apiKey: 'old');
    final old = (await repo.list()).single;
    credentials.failAfterWrite = true;
    await expectLater(settings.save(engine, apiKey: 'new'), throwsStateError);
    expect(credentials.values, {old.credentialKey: 'old'});
    expect((await repo.list()).single.credentialKey, old.credentialKey);
  });
  test('MiMo 更新不能更换服务商，失败后保留旧密钥与元数据', () async {
    const mimo = CloudTtsEngine(
      id: 'cloud1',
      name: 'MiMo',
      provider: 'mimo',
      model: 'mimo-v2.5-tts',
    );
    await settings.save(mimo, apiKey: 'mimo-key');
    final saved = (await repo.list()).single;
    await expectLater(
      settings.save(engine, apiKey: 'other-provider-key'),
      throwsStateError,
    );
    expect((await repo.list()).single.provider, 'mimo');
    expect(credentials.values, {saved.credentialKey: 'mimo-key'});
  });
}
