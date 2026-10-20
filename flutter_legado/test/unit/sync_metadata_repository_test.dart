import 'dart:async';

import 'package:flutter_legado/src/data/repositories/preferences_sync_metadata_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);
  final SharedPreferences delegate;
  bool fail = false;
  bool throwOnFailure = false;
  bool failRead = false;
  Completer<void>? gate;
  final started = Completer<void>();

  @override
  int? getInt(String key) {
    if (failRead) throw StateError('模拟读取失败');
    return delegate.getInt(key);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    final success = await delegate.setInt(key, value);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) {
      fail = false;
      if (throwOnFailure) throw StateError('模拟写入失败');
      return false;
    }
    return success;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const key = 'sync_last_time';

  test('缺省无同步时间，不补写键', () async {
    expect(await PreferencesSyncMetadataRepository().load(), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('保留整数毫秒存储，重启式新仓储重读精度与本地时区语义', () async {
    final time = DateTime.utc(2026, 10, 15, 12, 34, 56, 789, 123);
    await PreferencesSyncMetadataRepository().save(time);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {key});
    expect(prefs.getInt(key), time.millisecondsSinceEpoch);
    await prefs.reload();
    final restored = (await PreferencesSyncMetadataRepository().load())!;
    expect(restored.millisecondsSinceEpoch, time.millisecondsSinceEpoch);
    expect(restored.isUtc, isFalse);
  });

  for (final throwsOnFailure in [false, true]) {
    for (final exists in [false, true]) {
      test(
        '时间写入${throwsOnFailure ? '异常' : 'false'}恢复${exists ? '旧值' : '缺键'}缓存和存储并可重试',
        () async {
          SharedPreferences.setMockInitialValues({if (exists) key: 1234});
          final prefs = await SharedPreferences.getInstance();
          final controlled = _ControlledPreferences(prefs)
            ..fail = true
            ..throwOnFailure = throwsOnFailure;
          final repository = PreferencesSyncMetadataRepository(
            loadPreferences: () async => controlled,
          );
          final changed = DateTime.fromMillisecondsSinceEpoch(5678);
          await expectLater(repository.save(changed), throwsStateError);
          expect(prefs.getInt(key), exists ? 1234 : null);
          expect(
            (await repository.load())?.millisecondsSinceEpoch,
            exists ? 1234 : null,
          );
          await prefs.reload();
          expect(prefs.getInt(key), exists ? 1234 : null);
          await repository.save(changed);
          expect((await repository.load())?.millisecondsSinceEpoch, 5678);
        },
      );
    }
  }

  test('时间保存读取排队，不越过未完成的写入', () async {
    final controlled = _ControlledPreferences(
      await SharedPreferences.getInstance(),
    );
    final gate = Completer<void>();
    controlled.gate = gate;
    final repository = PreferencesSyncMetadataRepository(
      loadPreferences: () async => controlled,
    );
    final writing = repository.save(DateTime.fromMillisecondsSinceEpoch(1234));
    await controlled.started.future;
    var readDone = false;
    final reading = repository.load().then((value) {
      readDone = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readDone, isFalse);
    gate.complete();
    await writing;
    expect((await reading)?.millisecondsSinceEpoch, 1234);
  });

  test('平台读取失败上抛，恢复后可重试', () async {
    final controlled = _ControlledPreferences(
      await SharedPreferences.getInstance(),
    )..failRead = true;
    final repository = PreferencesSyncMetadataRepository(
      loadPreferences: () async => controlled,
    );
    await expectLater(repository.load(), throwsStateError);
    controlled.failRead = false;
    expect(await repository.load(), isNull);
  });
}
