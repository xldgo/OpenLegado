import 'dart:async';
import 'dart:convert';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/repositories/preferences_restore_ignore_repository.dart';
import 'package:flutter_legado/src/domain/models/restore_ignore_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 使用真实Preferences验证失败后内存缓存与重读结果。
class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);

  final SharedPreferences delegate;
  bool fail = false;
  bool throwOnFailure = false;
  bool failRead = false;
  Completer<void>? gate;
  final started = Completer<void>();

  @override
  String? getString(String key) {
    if (failRead) throw StateError('模拟平台读取异常');
    return delegate.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final saved = await delegate.setString(key, value);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) {
      fail = false;
      if (throwOnFailure) throw StateError('模拟平台写入异常');
      return false;
    }
    return saved;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认八项全false，键顺序不变，缺键不补写', () async {
    final config = await PreferencesRestoreIgnoreRepository().load();
    expect(config.values, {
      'readConfig': false,
      'themeMode': false,
      'themeConfig': false,
      'coverConfig': false,
      'bookshelfLayout': false,
      'showRss': false,
      'threadCount': false,
      'localBook': false,
    });
    expect(config.values.keys, RestoreIgnoreConfig.keys);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('原JSON只认布尔true，未知项忽略，读取不改写原JSON', () async {
    const raw =
        '{"readConfig":true,"themeMode":"true","themeConfig":1,"coverConfig":false,"bookshelfLayout":true,"showRss":true,"threadCount":true,"localBook":true,"unknown":true}';
    SharedPreferences.setMockInitialValues({PrefKeys.restoreIgnore: raw});
    final config = await PreferencesRestoreIgnoreRepository().load();
    expect(config.values, {
      'readConfig': true,
      'themeMode': false,
      'themeConfig': false,
      'coverConfig': false,
      'bookshelfLayout': true,
      'showRss': true,
      'threadCount': true,
      'localBook': true,
    });
    expect(
      (await SharedPreferences.getInstance()).getString(PrefKeys.restoreIgnore),
      raw,
    );
  });

  test('空串、损坏JSON与非Map维持默认，不回写原始数据', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in ['', '损坏JSON', '[]', 'true', 'null', '1']) {
      await prefs.setString(PrefKeys.restoreIgnore, raw);
      expect(
        await PreferencesRestoreIgnoreRepository().load(),
        RestoreIgnoreConfig(),
      );
      expect(prefs.getString(PrefKeys.restoreIgnore), raw);
    }
  });

  test('值对象复制并冻结输入，只保留八项；真实Preferences恢复相同快照', () async {
    final input = <String, Object?>{'readConfig': true, 'unknown': true};
    final config = RestoreIgnoreConfig(input);
    input['readConfig'] = false;
    expect(config['readConfig'], isTrue);
    expect(config.values.containsKey('unknown'), isFalse);
    expect(() => config.values['readConfig'] = false, throwsUnsupportedError);
    await PreferencesRestoreIgnoreRepository().save(config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(), {PrefKeys.restoreIgnore});
    expect(jsonDecode(prefs.getString(PrefKeys.restoreIgnore)!), config.values);
    expect(await PreferencesRestoreIgnoreRepository().load(), config);
  });

  for (final throwOnFailure in [false, true]) {
    for (final exists in [false, true]) {
      test(
        '写${throwOnFailure ? '异常' : 'false'}恢复${exists ? '原JSON' : '缺键'}的缓存及存储，可重试',
        () async {
          const previous = '{"localBook":true,"旧未知项":true}';
          SharedPreferences.setMockInitialValues({
            if (exists) PrefKeys.restoreIgnore: previous,
          });
          final prefs = await SharedPreferences.getInstance();
          final controlled = _ControlledPreferences(prefs)
            ..fail = true
            ..throwOnFailure = throwOnFailure;
          final repository = PreferencesRestoreIgnoreRepository(
            loadPreferences: () async => controlled,
          );
          final changed = RestoreIgnoreConfig({'readConfig': true});
          await expectLater(repository.save(changed), throwsStateError);
          expect(
            prefs.getString(PrefKeys.restoreIgnore),
            exists ? previous : null,
          );
          expect(
            await repository.load(),
            RestoreIgnoreConfig({if (exists) 'localBook': true}),
          );
          await prefs.reload();
          expect(
            prefs.getString(PrefKeys.restoreIgnore),
            exists ? previous : null,
          );
          await repository.save(changed);
          expect(await PreferencesRestoreIgnoreRepository().load(), changed);
        },
      );
    }
  }

  test('两次保存及中间读取顺序执行，读取不越过待保存值', () async {
    final controlled = _ControlledPreferences(
      await SharedPreferences.getInstance(),
    );
    final gate = Completer<void>();
    controlled.gate = gate;
    final repository = PreferencesRestoreIgnoreRepository(
      loadPreferences: () async => controlled,
    );
    final first = RestoreIgnoreConfig({'readConfig': true});
    final second = RestoreIgnoreConfig({'localBook': true});
    final savingFirst = repository.save(first);
    await controlled.started.future;
    var readDone = false;
    final between = repository.load().then((value) {
      readDone = true;
      return value;
    });
    final savingSecond = repository.save(second);
    await Future<void>.delayed(Duration.zero);
    expect(readDone, isFalse);
    gate.complete();
    await savingFirst;
    expect(await between, first);
    await savingSecond;
    expect(await repository.load(), second);
  });

  test('真实getString平台读取异常上抛，恢复后可重试', () async {
    final controlled = _ControlledPreferences(
      await SharedPreferences.getInstance(),
    )..failRead = true;
    final repository = PreferencesRestoreIgnoreRepository(
      loadPreferences: () async => controlled,
    );
    await expectLater(repository.load(), throwsStateError);
    controlled.failRead = false;
    expect(await repository.load(), RestoreIgnoreConfig());
  });
}
