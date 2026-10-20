import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/bottom_bar_skin_service.dart';
import '../../../services/bottom_bar_skin_format.dart';

/// 底栏皮肤状态
class BottomBarSkinState {
  const BottomBarSkinState({
    this.skins = const [],
    this.active = '',
    this.loading = false,
    this.error,
    this.revision = 0,
  });

  final List<String> skins;
  final String active;
  final bool loading;
  final String? error;
  final int revision;

  BottomBarSkinState copyWith({
    List<String>? skins,
    String? active,
    bool? loading,
    String? error,
    bool clearError = false,
    int? revision,
  }) {
    return BottomBarSkinState(
      revision: revision ?? this.revision,
      skins: skins ?? this.skins,
      active: active ?? this.active,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BottomBarSkinNotifier extends Notifier<BottomBarSkinState> {
  BottomBarSkinService get _service => ref.read(bottomBarSkinServiceProvider);
  int _generation = 0;

  @override
  BottomBarSkinState build() {
    ref.onDispose(() => _generation++);
    Future.microtask(reload);
    return const BottomBarSkinState(loading: true);
  }

  Future<void> reload() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final skins = await _service.list();
      final active = await _service.getActive();
      if (!ref.mounted || generation != _generation) return;
      state = BottomBarSkinState(
        skins: skins,
        active: active,
        revision: state.revision + 1,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> setActive(String name) async {
    final generation = ++_generation;
    try {
      await _service.setActive(name);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        active: name,
        loading: false,
        revision: state.revision + 1,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<bool> delete(String name) async {
    final ok = await _service.delete(name);
    if (ok) await reload();
    return ok;
  }
}

final bottomBarSkinProvider =
    NotifierProvider<BottomBarSkinNotifier, BottomBarSkinState>(
      BottomBarSkinNotifier.new,
    );

final bottomBarSkinServiceProvider = Provider<BottomBarSkinService>(
  (ref) => BottomBarSkinService.instance,
);

/// 预览只携带槽位及文件路径，不创建界面组件。— Codex + UI
class BottomBarSkinPreview {
  const BottomBarSkinPreview(this.slot, this.path);
  final String slot;
  final String? path;
}

final bottomBarSkinPreviewProvider = FutureProvider<List<BottomBarSkinPreview>>(
  (ref) async {
    final (active, _) = ref.watch(
      bottomBarSkinProvider.select((s) => (s.active, s.revision)),
    );
    if (active.isEmpty) return const [];
    final service = ref.watch(bottomBarSkinServiceProvider);
    return Future.wait([
      for (final slot in BottomBarSkinFormat.mappedSlots)
        service
            .iconsForSlot(active, slot)
            .then(
              (icons) =>
                  BottomBarSkinPreview(slot, icons.selected ?? icons.normal),
            ),
    ]);
  },
);
