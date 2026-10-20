import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/data/repositories/app_search_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/search_settings.dart';

void main() {
  group('AppSettingsService', () {
    late _MemoryStorage storage;
    late AppSettingsService service;
    const address = (storage: SettingsStorageKind.rustConfig, key: 'example');

    setUp(() {
      storage = _MemoryStorage();
      service = AppSettingsService(
        storages: {SettingsStorageKind.rustConfig: storage},
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('加载一次后复用快照，reload 会读取外部变更', () async {
      storage.values[address.key] = 'before';

      await service.load({address});
      await service.load({address});
      expect(storage.readCount, 1);
      expect(service.current[address], 'before');

      storage.values[address.key] = 'after';
      await service.reload({address});
      expect(storage.readCount, 2);
      expect(service.current[address], 'after');
    });

    test('并发初始化复用读取，读取失败后允许重试', () async {
      storage.beforeRead = (_) async => throw StateError('模拟读取失败');
      await expectLater(service.load({address}), throwsStateError);
      expect(service.current.values.containsKey(address), isFalse);

      storage.beforeRead = null;
      storage.values[address.key] = 'retried';
      await Future.wait([
        service.load({address}),
        service.load({address}),
      ]);
      expect(storage.readCount, 2);
      expect(service.current[address], 'retried');
    });

    test('初始化迟到结果不会覆盖已生效的用户更新', () async {
      final entered = Completer<void>();
      final release = Completer<Object?>();
      storage.beforeRead = (_) {
        entered.complete();
        return release.future;
      };
      final loading = service.load({address});
      await entered.future;

      final saving = service.update({address: 'user-value'});
      expect(service.current[address], 'user-value');
      release.complete('stored-value');
      await loading;
      expect(service.current[address], 'user-value');
      await saving;
      expect(storage.values[address.key], 'user-value');
    });

    test('更新立即通知，失败回退且旧快照不可修改', () async {
      storage.values[address.key] = 'before';
      await service.load({address});
      final snapshots = <AppSettingsSnapshot>[];
      final subscription = service.watch().listen(snapshots.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      final original = service.current;
      expect(() => original.values.clear(), throwsUnsupportedError);

      storage.beforeWrite = (_, _) async => throw StateError('模拟保存失败');
      final saving = service.update({address: 'pending'});
      expect(service.current[address], 'pending');
      await expectLater(saving, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.map((snapshot) => snapshot[address]), [
        'before',
        'pending',
        'before',
      ]);
      expect(original[address], 'before');
    });

    test('StringList读取冻结外部列表，写入只接受不可变配置值', () async {
      final input = ['before'];
      storage.values[address.key] = input;
      await service.load({address});
      final original = service.current[address] as SettingsStringList;
      input[0] = 'external';
      expect(original.values, ['before']);
      expect(() => original.values[0] = 'changed', throwsUnsupportedError);
      expect(
        () => service.update({
          address: ['mutable'],
        }),
        throwsArgumentError,
      );
      final changed = ['after'];
      final saving = service.update({address: SettingsStringList(changed)});
      changed[0] = 'caller-changed';
      await saving;
      expect((service.current[address] as SettingsStringList).values, [
        'after',
      ]);
      expect(original.values, ['before']);
    });

    test('不可变StringList保存失败回退并可重试，旧快照不改变', () async {
      storage.values[address.key] = ['before'];
      await service.load({address});
      final original = service.current;
      storage.beforeWrite = (_, _) async => throw StateError('模拟保存失败');
      await expectLater(
        service.update({
          address: SettingsStringList(['pending']),
        }),
        throwsStateError,
      );
      expect((service.current[address] as SettingsStringList).values, [
        'before',
      ]);
      storage.beforeWrite = null;
      await service.update({
        address: SettingsStringList(['after']),
      });
      expect((service.current[address] as SettingsStringList).values, [
        'after',
      ]);
      expect((original[address] as SettingsStringList).values, ['before']);
    });

    test('后提交的同键更新不会被先提交的失败覆盖', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.beforeWrite = (key, value) async {
        if (value == 'first') {
          entered.complete();
          await release.future;
          throw StateError('模拟首次写入失败');
        }
      };

      final first = service.update({address: 'first'});
      await entered.future;
      final second = service.update({address: 'second'});
      expect(service.current[address], 'second');

      release.complete();
      await expectLater(first, throwsStateError);
      await second;
      expect(storage.values[address.key], 'second');
      expect(service.current[address], 'second');
    });

    test('多键写入部分成功时保留已落盘键并报告失败', () async {
      const first = (storage: SettingsStorageKind.rustConfig, key: 'first');
      const second = (storage: SettingsStorageKind.rustConfig, key: 'second');
      storage.values[first.key] = 'old-first';
      storage.values[second.key] = 'old-second';
      storage.beforeWrite = (key, value) async {
        if (key == second.key) throw StateError('模拟第二个键失败');
      };

      await service.load({first, second});
      await expectLater(
        service.update({first: 'new-first', second: 'new-second'}),
        throwsStateError,
      );

      expect(storage.values[first.key], 'new-first');
      expect(storage.values[second.key], 'old-second');
      expect(service.current[first], 'new-first');
      expect(service.current[second], 'old-second');
    });

    test('reload 期间的修改保持即时可见，随后按顺序落盘', () async {
      await service.load({address});
      final entered = Completer<void>();
      final release = Completer<Object?>();
      storage.beforeRead = (_) {
        entered.complete();
        return release.future;
      };
      final reloading = service.reload({address});
      await entered.future;
      final saving = service.update({address: 'new'});
      release.complete('external');

      await reloading;
      expect(service.current[address], 'new');
      await saving;
      expect(storage.values[address.key], 'new');
    });

    test('释放时排空在途任务，拒绝后续写入', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.beforeWrite = (_, _) async {
        entered.complete();
        await release.future;
      };
      final saving = service.update({address: 'last'});
      await entered.future;
      final disposing = service.dispose();
      expect(() => service.update({address: 'late'}), throwsStateError);
      release.complete();
      await saving;
      await disposing;
      expect(storage.values[address.key], 'last');
    });
  });

  test('AppSearchSettingsRepository 负责默认值和类型编码', () async {
    final config = _MemoryStorage(
      values: {
        'precisionSearch': 'true',
        'searchResultFilter': '  屏蔽词  ',
        'searchScope': '玄幻,历史',
        'searchGroup': '玄幻',
      },
    );
    final preferences = _MemoryStorage(values: {'showSearchReadRecord': true});
    final service = AppSettingsService(
      storages: {
        SettingsStorageKind.rustConfig: config,
        SettingsStorageKind.preferences: preferences,
      },
    );
    addTearDown(service.dispose);
    final repository = AppSearchSettingsRepository(service);

    expect(
      await repository.load(),
      const SearchSettings(
        precisionSearch: true,
        resultFilter: '屏蔽词',
        scope: '玄幻,历史',
        searchGroup: '玄幻',
        showReadRecord: true,
      ),
    );

    await repository.update(
      (current) => current.copyWith(
        precisionSearch: false,
        resultFilter: '',
        showReadRecord: false,
      ),
    );
    await repository.settled();
    expect(config.values['precisionSearch'], 'false');
    expect(config.values['searchResultFilter'], '');
    expect(preferences.values['showSearchReadRecord'], false);
    expect(repository.current.scope, '玄幻,历史');
  });

  test('运行时设置加载不访问显示偏好，字段无关更新不重复通知', () async {
    final config = _MemoryStorage();
    final preferences = _MemoryStorage();
    final service = AppSettingsService(
      storages: {
        SettingsStorageKind.rustConfig: config,
        SettingsStorageKind.preferences: preferences,
      },
    );
    addTearDown(service.dispose);
    final repository = AppSearchSettingsRepository(service);
    final snapshots = <SearchSettings>[];
    final subscription = repository.watch().listen(snapshots.add);
    addTearDown(subscription.cancel);
    await repository.loadRuntime();
    await Future<void>.delayed(Duration.zero);
    expect(preferences.readCount, 0);
    expect(snapshots, [const SearchSettings()]);

    await service.update({
      (storage: SettingsStorageKind.rustConfig, key: 'unrelated'): 'value',
    });
    await Future<void>.delayed(Duration.zero);
    expect(snapshots, [const SearchSettings()]);
    config.values['precisionSearch'] = 'true';
    await repository.reloadRuntime();
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.precisionSearch, isTrue);
    expect(preferences.readCount, 0);

    preferences.values['showSearchReadRecord'] = true;
    await repository.reload();
    expect(repository.current.showReadRecord, isTrue);
  });
}

final class _MemoryStorage implements SettingsStorage {
  _MemoryStorage({Map<String, Object?>? values}) : values = {...?values};

  final Map<String, Object?> values;
  int readCount = 0;
  Future<Object?> Function(String key)? beforeRead;
  Future<void> Function(String key, Object? value)? beforeWrite;

  @override
  Future<Object?> read(String key) async {
    readCount++;
    if (beforeRead case final callback?) return callback(key);
    return values[key];
  }

  @override
  Future<void> write(String key, Object? value) async {
    await beforeWrite?.call(key, value);
    values[key] = value;
  }
}
