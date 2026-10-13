import 'dart:math';

import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_credential_store.dart';

/// 配置写入协调：平台与数据库不能伪装成同一事务。— Codex + UI
final class CloudTtsSettings {
  CloudTtsSettings(
    this.repository,
    this.credentials, {
    String Function()? newId,
  }) : _newId = newId ?? randomCloudTtsId;
  final CloudTtsRepository repository;
  final CloudTtsCredentialStore credentials;
  final String Function() _newId;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> save(CloudTtsEngine engine, {String? apiKey}) =>
      _serial(() async {
        final existing = (await repository.list())
            .where((e) => e.id == engine.id)
            .firstOrNull;
        final previous = existing?.credentialKey;
        String? created;
        if (apiKey != null) {
          if (apiKey.trim().isEmpty) throw StateError('API Key 不能为空');
          created = 'cloud-tts:${engine.id}:${_newId()}';
          try {
            await credentials.write(created, apiKey);
          } catch (error, stack) {
            try {
              await credentials.delete(created);
            } catch (_) {
              throw StateError('安全存储写入失败，新凭据清理也失败');
            }
            Error.throwWithStackTrace(error, stack);
          }
        }
        final key = created ?? previous;
        if (key == null || key.isEmpty) throw StateError('请输入 API Key');
        try {
          await repository.save(engine.withCredential(key));
        } catch (error, stack) {
          if (created != null) {
            try {
              await credentials.delete(created);
            } catch (_) {
              throw StateError('配置保存失败，新凭据清理也失败，请重试');
            }
          }
          Error.throwWithStackTrace(error, stack);
        }
        if (created != null && previous != null && previous != created) {
          try {
            await credentials.delete(previous);
          } catch (_) {
            throw StateError('配置已保存，旧凭据清理失败');
          }
        }
      });
  Future<void> delete(CloudTtsEngine engine) => _serial(() async {
    final current = (await repository.list())
        .where((e) => e.id == engine.id)
        .firstOrNull;
    if (current == null) throw StateError('云端引擎不存在');
    await repository.delete(engine.id);
    try {
      await credentials.delete(current.credentialKey);
    } catch (_) {
      throw StateError('配置已删除，凭据清理失败');
    }
  });
}

String randomCloudTtsId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
