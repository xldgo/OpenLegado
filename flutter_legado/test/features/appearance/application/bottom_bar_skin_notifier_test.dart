import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/appearance/application/bottom_bar_skin_notifier.dart';
import 'package:flutter_legado/src/services/bottom_bar_skin_service.dart';

class _SkinService implements BottomBarSkinService {
  String active = 'a';
  int reads = 0;
  bool fail = false;
  final Map<String, Completer<BottomBarSkinIcons>> pending = {};
  @override
  Future<List<String>> list() async => ['a', 'b'];
  @override
  Future<String> getActive() async => active;
  @override
  Future<void> setActive(String name) async {
    active = name;
  }

  @override
  Future<BottomBarSkinIcons> iconsForSlot(String skin, String slot) async {
    reads++;
    if (fail) throw StateError('读取失败');
    if (pending[skin] case final completer?) return completer.future;
    return BottomBarSkinIcons(selected: '$skin/$slot/$reads.png');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SkinService service;
  late ProviderContainer container;
  setUp(() {
    service = _SkinService();
    container = ProviderContainer(
      overrides: [bottomBarSkinServiceProvider.overrideWithValue(service)],
    );
  });
  tearDown(() => container.dispose());
  Future<void> loaded() async {
    container.read(bottomBarSkinProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(bottomBarSkinPreviewProvider.future);
  }

  test('重复读取不重新扫描，同名编辑刷新重新读取', () async {
    await loaded();
    final first = container.read(bottomBarSkinPreviewProvider).requireValue;
    final count = service.reads;
    await container.read(bottomBarSkinPreviewProvider.future);
    expect(service.reads, count);
    await container.read(bottomBarSkinProvider.notifier).reload();
    final next = await container.read(bottomBarSkinPreviewProvider.future);
    expect(service.reads, count * 2);
    expect(next.first.path, isNot(first.first.path));
  });
  test('皮肤快速切换，旧扫描结果不能覆盖新皮肤', () async {
    await loaded();
    service.pending['a'] = Completer();
    await container.read(bottomBarSkinProvider.notifier).setActive('a');
    final old = container.read(bottomBarSkinPreviewProvider.future);
    await container.read(bottomBarSkinProvider.notifier).setActive('b');
    final next = await container.read(bottomBarSkinPreviewProvider.future);
    service.pending['a']!.complete(
      const BottomBarSkinIcons(selected: 'old.png'),
    );
    await old;
    expect(next.first.path, startsWith('b/'));
    expect(
      container.read(bottomBarSkinPreviewProvider).requireValue.first.path,
      startsWith('b/'),
    );
  });
  test('预览失败可重试，默认皮肤不读取图标', () async {
    await loaded();
    service.fail = true;
    container.invalidate(bottomBarSkinPreviewProvider);
    await expectLater(
      container.read(bottomBarSkinPreviewProvider.future),
      throwsStateError,
    );
    service.fail = false;
    container.invalidate(bottomBarSkinPreviewProvider);
    expect(
      await container.read(bottomBarSkinPreviewProvider.future),
      isNotEmpty,
    );
    final count = service.reads;
    await container.read(bottomBarSkinProvider.notifier).setActive('');
    expect(await container.read(bottomBarSkinPreviewProvider.future), isEmpty);
    expect(service.reads, count);
  });
}
