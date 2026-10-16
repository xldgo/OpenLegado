import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/features/search/search.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi api;
  late ProviderContainer container;
  late StreamController<SearchBatch> events;
  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    events = StreamController<SearchBatch>();
    when(
      () => api.searchHistoryRepository.getSearchHistory(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.bookSourceRepository.getEnabledBookSources())
        .thenAnswer((_) async => []);
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => events.stream);
    when(() => api.searchService.cancelSearch()).thenAnswer((_) async {});
    when(() => api.searchService.pauseSearch()).thenAnswer((_) async {});
    when(() => api.searchService.resumeSearch()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });
  Widget wrap(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: child),
  );

  testWidgets('前台恢复接住尚未完成的后台暂停', (tester) async {
    await tester.pumpWidget(wrap(SearchScreen(initialQuery: '甲')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(searchNotifierProvider).isLoading, isTrue);
    final pause = Completer<void>();
    when(() => api.searchService.pauseSearch()).thenAnswer((_) => pause.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    pause.complete();
    await tester.pump();
    verify(() => api.searchService.pauseSearch()).called(1);
    verify(() => api.searchService.resumeSearch()).called(1);
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump();
    await tester.runAsync(events.close);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页面移除在监听解绑后停止，不产生销毁期 Provider 异常', (tester) async {
    await tester.pumpWidget(wrap(SearchScreen(initialQuery: '甲')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    clearInteractions(api.searchService);
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump();
    expect(container.read(searchNotifierProvider).isLoading, isFalse);
    expect(container.read(searchNotifierProvider).isManualStop, isTrue);
    verify(() => api.searchService.cancelSearch()).called(1);
    await tester.runAsync(events.close);
    expect(tester.takeException(), isNull);
  });
}
