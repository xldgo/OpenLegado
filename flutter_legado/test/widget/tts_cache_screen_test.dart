import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_cache_screen.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_cache_provider.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';

import '../mocks/mocks.dart';

class _Cache extends Fake implements TtsCacheRepository {
  int lists = 0, clears = 0;
  bool fail = false;
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<List<TtsCacheEntry>> list() async {
    lists++;
    return [
      TtsCacheEntry(
        name: 'tts_a.wav',
        sizeBytes: 1024,
        modifiedAtMs: 1,
        protected: true,
        contexts: const [],
      ),
      TtsCacheEntry(
        name: 'tts_b.wav',
        sizeBytes: 2048,
        modifiedAtMs: 1,
        protected: false,
        contexts: const [
          TtsCacheContext(
            bookUrl: 'book',
            bookName: '测试书',
            chapterIndex: 0,
            chapterTitle: '第一章',
            paragraphIndex: 0,
            text: '甲😀乙',
          ),
        ],
      ),
    ];
  }

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async {
    clears++;
    if (fail) throw StateError('删除失败');
    return const TtsCacheClearResult(removedFiles: 1, skippedFiles: 1);
  }
}

void main() {
  testWidgets('缓存管理显示关联正文和大小，活动文件禁止删除；全清保留活动项', (tester) async {
    final cache = _Cache();
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...MockRustApi().overrides,
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
          ttsCacheRepositoryProvider.overrideWithValue(cache),
        ]),
        child: const MaterialApp(home: TtsCacheScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试书 · 第一章'), findsOneWidget);
    final disabled = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline).first,
    );
    expect(disabled.onPressed, isNull);
    await tester.tap(find.text('测试书 · 第一章'));
    await tester.pumpAndSettle();
    expect(find.textContaining('甲😀乙'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('清空缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(cache.clears, 1);
    expect(cache.lists, 2);
    expect(find.textContaining('保留 1 个活动缓存'), findsOneWidget);
  });
  test('缓存删除失败原异常传播，不刷新成成功状态', () async {
    final cache = _Cache()..fail = true;
    final container = ProviderContainer(
      overrides: [ttsCacheRepositoryProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);
    await container.read(ttsCacheProvider.future);
    await expectLater(
      container.read(ttsCacheProvider.notifier).clear(),
      throwsStateError,
    );
    expect(cache.lists, 1);
  });
}
