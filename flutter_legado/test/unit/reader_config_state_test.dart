import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/preferences_reader_config_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reader_config_repository.dart';
import 'package:flutter_legado/src/models/reader_advanced_config.dart';
import 'package:flutter_legado/src/providers/reader/reader_config_provider.dart';

class _ControlledRepository implements ReaderConfigRepository {
  final loads = <Completer<ReaderAdvancedConfig>>[];
  final saved = <ReaderAdvancedConfig>[];
  bool failSave = false;

  @override
  Future<ReaderAdvancedConfig> load() {
    final result = Completer<ReaderAdvancedConfig>();
    loads.add(result);
    return result.future;
  }

  @override
  Future<void> save(ReaderAdvancedConfig config) async {
    if (failSave) throw StateError('模拟保存失败');
    saved.add(config);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor(_ControlledRepository repository) =>
      ProviderContainer(
        overrides: [
          readerConfigRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('多个消费者共用加载，等待期间的新操作不会被旧读取覆盖', () async {
    final repository = _ControlledRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final notifier = container.read(readerAdvConfigProvider.notifier);
    final first = notifier.ensureLoaded();
    final second = notifier.ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(repository.loads, hasLength(1));

    await notifier.commit(ReaderAdvancedConfig(paragraphSpacing: 12));
    repository.loads.single.complete(ReaderAdvancedConfig(paragraphSpacing: 4));
    expect((await first).paragraphSpacing, 12);
    expect((await second).paragraphSpacing, 12);
    expect(container.read(readerAdvConfigProvider)!.paragraphSpacing, 12);
    expect(repository.saved, hasLength(1));
  });

  test('销毁作用域后加载结果不再访问共享状态', () async {
    final repository = _ControlledRepository();
    final container = containerFor(repository);
    final pending = container
        .read(readerAdvConfigProvider.notifier)
        .ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    repository.loads.single.complete(ReaderAdvancedConfig(titleSize: 16));
    expect((await pending).titleSize, 16);
    await Future<void>.delayed(Duration.zero);
  });

  test('加载失败后允许重新加载', () async {
    final repository = _ControlledRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final notifier = container.read(readerAdvConfigProvider.notifier);
    final first = notifier.ensureLoaded();
    final failure = expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    repository.loads.single.completeError(StateError('模拟读取失败'));
    await failure;
    final retry = notifier.ensureLoaded();
    expect(repository.loads, hasLength(2));
    repository.loads.last.complete(ReaderAdvancedConfig(titleSize: 14));
    expect((await retry).titleSize, 14);
  });

  test('提交持有独立快照，保存失败不回退新界面且后续操作可重试', () async {
    final repository = _ControlledRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final notifier = container.read(readerAdvConfigProvider.notifier);
    final edited = ReaderAdvancedConfig(paragraphSpacing: 6);
    await notifier.commit(edited);
    edited.paragraphSpacing = 48;
    edited.tapActions[0] = TapAction.none;
    expect(container.read(readerAdvConfigProvider)!.paragraphSpacing, 6);
    expect(repository.saved.single.tapActions[0], TapAction.prevPage);

    repository.failSave = true;
    await expectLater(
      notifier.commit(ReaderAdvancedConfig(paragraphSpacing: 8)),
      throwsStateError,
    );
    expect(container.read(readerAdvConfigProvider)!.paragraphSpacing, 8);
    repository.failSave = false;
    await notifier.commit(ReaderAdvancedConfig(paragraphSpacing: 10));
    expect(repository.saved.last.paragraphSpacing, 10);
  });

  test('偏好读写串行，等待保存时不会读到半份配置或可变输入', () async {
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<SharedPreferences>();
    var accesses = 0;
    final repository = PreferencesReaderConfigRepository(
      preferences: () {
        accesses++;
        return accesses == 1 ? gate.future : Future.value(prefs);
      },
    );
    final input = ReaderAdvancedConfig(paragraphSpacing: 6, titleFont: '第一份');
    final first = repository.save(input);
    input.paragraphSpacing = 48;
    final second = repository.save(
      ReaderAdvancedConfig(paragraphSpacing: 10, titleFont: '最后一份'),
    );
    final reading = repository.load();
    await Future<void>.delayed(Duration.zero);
    expect(accesses, 1);
    gate.complete(prefs);
    await first;
    expect(prefs.getDouble('reader_adv_paragraph_spacing'), 6);
    await second;
    final result = await reading;
    expect(result.paragraphSpacing, 10);
    expect(result.titleFont, '最后一份');
  });

  test('一次偏好访问失败不阻断后续保存', () async {
    final prefs = await SharedPreferences.getInstance();
    var accesses = 0;
    final repository = PreferencesReaderConfigRepository(
      preferences: () async {
        if (++accesses == 1) throw StateError('模拟偏好访问失败');
        return prefs;
      },
    );
    await expectLater(
      repository.save(ReaderAdvancedConfig(titleSize: 8)),
      throwsStateError,
    );
    await repository.save(ReaderAdvancedConfig(titleSize: 16));
    expect((await repository.load()).titleSize, 16);
  });
}
