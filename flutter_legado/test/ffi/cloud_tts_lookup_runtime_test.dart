@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 真实缓存命中请求的元数据/凭据调用计数，不替代设备 IPC 或功耗测量。— Codex + Bridge
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

import '../helpers/native_ffi.dart';

class _Repository implements CloudTtsRepository {
  final inner = const RustCloudTtsRepository();
  int lists = 0, gets = 0;
  @override
  Future<CloudTtsEngine?> get(String id) {
    gets++;
    return inner.get(id);
  }

  @override
  Future<List<CloudTtsEngine>> list() {
    lists++;
    return inner.list();
  }

  @override
  Future<void> save(CloudTtsEngine engine) => inner.save(engine);
  @override
  Future<void> delete(String id) => inner.delete(id);
  @override
  Future<List<String>> voices(String provider) => inner.voices(provider);
}

class _Credentials implements CloudTtsCredentialStore {
  int reads = 0;
  Future<void> Function()? onRead;
  final values = {'cloud-tts:lookup:current': 'private-key'};
  @override
  Future<String?> read(String key) async {
    reads++;
    final value = values[key];
    final hook = onRead;
    onRead = null;
    await hook?.call();
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('缓存命中仍核验配置与凭据，记录实际读取次数', () async {
    final root = Directory(
      '.dart_tool/cloud-lookup-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${root.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${root.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    server.listen((request) async {
      calls++;
      expect(request.headers.value('authorization'), 'Bearer private-key');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['input'], '同一段正文');
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.add(utf8.encode('ID3fixture'));
      await request.response.close();
    });
    final repo = _Repository(), credentials = _Credentials();
    await repo.save(
      CloudTtsEngine(
        id: 'lookup',
        name: '测量',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        credentialKey: 'cloud-tts:lookup:current',
      ),
    );
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    for (var i = 0; i < 3; i++) {
      final result = await synth.synthesize(
        engineId: 'lookup',
        text: '同一段正文',
      ) as HttpTtsAudio;
      expect(result.fromCache, i != 0);
      await result.lease!.release();
    }
    expect(calls, 1);
    expect(repo.lists, 0);
    expect(repo.gets, 3);
    expect(credentials.reads, 3);
    debugPrint(
      '三次合成：list=${repo.lists}，get=${repo.gets}，credentials=${credentials.reads}，HTTP=$calls',
    );
    expect(await repo.inner.get('missing'), isNull);
    final saved = (await repo.inner.get('lookup'))!;
    expect(saved.toJson(), (await repo.inner.list()).single.toJson());
    expect(jsonEncode(saved.toJson()), isNot(contains('private-key')));
    await repo.save(
      CloudTtsEngine.fromJson({...saved.toJson(), 'enabled': false}),
    );
    await expectLater(
      synth.synthesize(engineId: 'lookup', text: '同一段正文'),
      throwsA(anything),
    );
    expect(credentials.reads, 3);
    expect(calls, 1);
    await repo.save(saved);
    credentials.onRead = () async {
      await repo.save(
        CloudTtsEngine.fromJson({...saved.toJson(), 'enabled': false}),
      );
    };
    // Flutter 查询之后停用引擎，Rust 的当前状态检查仍须阻止命中缓存。
    await expectLater(
      synth.synthesize(engineId: 'lookup', text: '同一段正文'),
      throwsA(anything),
    );
    expect(calls, 1);
    expect(credentials.reads, 4);
    await repo.save(saved);
    credentials.onRead = () async {
      await repo.save(
        CloudTtsEngine.fromJson({
          ...saved.toJson(),
          'credentialKey': 'cloud-tts:lookup:rotated',
        }),
      );
    };
    // 在 Flutter 读密钥期间替换引用，即使音频已缓存，也必须由 Rust 拒绝旧引用。
    await expectLater(
      synth.synthesize(engineId: 'lookup', text: '同一段正文'),
      throwsA(predicate((e) => e.toString().contains('凭据在读取期间已变更'))),
    );
    expect(calls, 1);
    expect(credentials.reads, 5);
    await repo.delete('lookup');
    expect(await repo.inner.get('lookup'), isNull);
    await expectLater(
      synth.synthesize(engineId: 'lookup', text: '同一段正文'),
      throwsA(anything),
    );
    expect(calls, 1);
    expect(credentials.reads, 5);
    final before = repo.gets;
    final cancel = HttpTtsCancellation()..cancel();
    expect(
      await synth.synthesize(
        engineId: 'lookup',
        text: '同一段正文',
        cancellation: cancel,
      ),
      isA<HttpTtsCancelled>(),
    );
    expect(repo.gets, before);
  });
}
