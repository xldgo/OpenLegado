import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/providers/reading_provider.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/app_content_processing_settings_repository.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/content_processing_provider.dart';

import '../fixtures/config_repository.dart';

class _ReadingRepository extends Mock implements ReadingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('净化默认值写入Rust配置，跨装配恢复；失败保留原值', () async {
    SharedPreferences.setMockInitialValues({});
    final values = <String, String>{};
    var fail = false;
    final config = TestConfigRepository(
      read: (key) async => values[key],
      write: (key, value) async {
        if (fail) throw StateError('写入失败');
        values[key] = value;
      },
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppContentProcessingSettingsRepository(service);
    expect(await repository.load(), isTrue);
    await repository.update((_) => false);
    expect(values['replaceEnableDefault'], 'false');
    final rebuilt = createAppSettingsService(configRepository: () => config);
    addTearDown(rebuilt.dispose);
    expect(
      await AppContentProcessingSettingsRepository(rebuilt).load(),
      isFalse,
    );
    fail = true;
    await expectLater(repository.update((_) => true), throwsStateError);
    expect(repository.current, isFalse);
    expect(values['replaceEnableDefault'], 'false');
  });

  test('正文消费者只接收已写入Rust的设置，不以乐观快照提前重载', () async {
    SharedPreferences.setMockInitialValues({});
    var saved = 'true';
    final gate = Completer<void>();
    final writing = Completer<void>();
    final config = TestConfigRepository(
      read: (_) async => saved,
      write: (_, value) async {
        writing.complete();
        await gate.future;
        saved = value;
      },
    );
    final service = createAppSettingsService(configRepository: () => config);
    const book = Book(bookUrl: 'menu-book');
    final reading = _ReadingRepository();
    when(() => reading.resolveReplaceRule(book, true))
        .thenAnswer((_) async => true);
    when(() => reading.resolveReplaceRule(book, false))
        .thenAnswer((_) async => false);
    final container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        readingRepositoryProvider.overrideWithValue(reading),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.dispose();
    });
    final observed = <bool>[];
    container.listen(replaceEnableDefaultProvider, (_, next) {
      if (next.hasValue) observed.add(next.requireValue);
    }, fireImmediately: true);
    container.listen(effectiveReplaceRuleProvider(book), (_, _) {});
    expect(
      await container.read(effectiveReplaceRuleProvider(book).future),
      isTrue,
    );
    expect(await container.read(replaceEnableDefaultProvider.future), isTrue);
    final repository = container.read(
      contentProcessingSettingsRepositoryProvider,
    );
    final change = repository.update((_) => false);
    await writing.future;
    expect(observed, isNot(contains(false)));
    expect(saved, 'true');
    final delivered = Completer<void>();
    container.listen(replaceEnableDefaultProvider, (_, next) {
      if (next.value == false && !delivered.isCompleted) delivered.complete();
    });
    gate.complete();
    await change;
    await delivered.future;
    expect(saved, 'false');
    expect(observed.last, isFalse);
    expect(
      await container.read(effectiveReplaceRuleProvider(book).future),
      isFalse,
    );
  });
}
