import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../providers/theme/system_bar_controller.dart';

/// 监听主题，全局同步 SystemChrome / Android Window
class SystemBarBinder extends ConsumerStatefulWidget {
  final Widget child;

  const SystemBarBinder({super.key, required this.child});

  @override
  ConsumerState<SystemBarBinder> createState() => _SystemBarBinderState();
}

class _SystemBarBinderState extends ConsumerState<SystemBarBinder>
    with WidgetsBindingObserver {
  bool _applyScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleApply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _scheduleApply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleApply();
      ref.read(systemBarControllerProvider).reapply();
    }
  }

  void _scheduleApply() {
    if (_applyScheduled) return;
    _applyScheduled = true;
    // 等当前 Theme 完成重建，再读取配色，合并同帧的设置与主题变化。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScheduled = false;
      if (mounted) _apply();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _apply() {
    if (!mounted) return;
    final theme = Theme.of(context);
    final appBarColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final navBarColor =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;

    ref.read(systemBarControllerProvider).updateApplication((
      appBarColor: appBarColor,
      navigationBarColor: navBarColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
