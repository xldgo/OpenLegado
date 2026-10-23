import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  group('formatDuring', () {
    test('0 与负数显示 0秒', () {
      expect(formatDuring(0), '0秒');
      expect(formatDuring(-1), '0秒');
    });

    test('组合天时分秒', () {
      // 1天 + 2小时 + 3分钟 + 4秒
      final ms = (1 * 86400 + 2 * 3600 + 3 * 60 + 4) * 1000;
      expect(formatDuring(ms), '1天2小时3分钟4秒');
    });
  });

  test('搜索状态与共享偏好可保存恢复，不再查询原始列表', () async {
    SharedPreferences.setMockInitialValues({});
    final records = _Records();
    ProviderContainer create() => ProviderContainer(
      overrides: [readRecordRepositoryProvider.overrideWithValue(records)],
    );
    final container = create();
    addTearDown(container.dispose);
    final notifier = container.read(readRecordNotifierProvider.notifier);
    await notifier.load();
    notifier.setSearchQuery('  作者  ');
    await notifier.setSortMode(ReadRecordSortMode.lastRead);
    await notifier.setDisplayMode(ReadRecordDisplayMode.latest);
    await notifier.toggleEnableRecord();
    final state = container.read(readRecordNotifierProvider);
    expect(state.searchQuery, '作者');
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    final replacement = create();
    addTearDown(replacement.dispose);
    await replacement.read(readRecordNotifierProvider.notifier).load();
    final restored = replacement.read(readRecordNotifierProvider);
    expect(restored.sortMode, ReadRecordSortMode.lastRead);
    expect(restored.displayMode, ReadRecordDisplayMode.latest);
    expect(restored.enableRecord, isFalse);
    verifyZeroInteractions(records);
  });
}
