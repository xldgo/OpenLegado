import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../widgets/settings_widgets.dart';

import '../../../../services/system_brightness.dart';

/// 设置页与阅读底栏共用的亮度控件。
class ReaderBrightnessControl extends StatefulWidget {
  /// 胶囊宽度与端部区域同宽，使图标圆心与端部圆角圆心重合。
  static const double verticalWidth = 56;

  const ReaderBrightnessControl({
    super.key,
    this.compact = false,
    this.vertical = false,
    this.onSwitchSide,
  });

  final bool compact;
  final bool vertical;
  final VoidCallback? onSwitchSide;

  @override
  State<ReaderBrightnessControl> createState() =>
      _ReaderBrightnessControlState();
}

class _ReaderBrightnessControlState extends State<ReaderBrightnessControl>
    with WidgetsBindingObserver {
  StreamSubscription<double>? _subscription;
  bool? _supported;
  bool _followSystem = true;
  bool _busy = false;
  bool _dragging = false;
  double _brightness = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final supported = await SystemBrightness.isSupported();
    if (!mounted) return;
    setState(() => _supported = supported);
    if (!supported) return;
    _subscription = SystemBrightness.changes.listen(
      (_) => unawaited(_refresh()),
      onError: (Object error) => debugPrint('亮度变化通知不可用: $error'),
    );
    await _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _supported == true) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final followSystem = await SystemBrightness.isFollowingSystem();
      final brightness = await SystemBrightness.getBrightness();
      if (!mounted) return;
      setState(() {
        _followSystem = followSystem;
        if (!_dragging) _brightness = brightness;
      });
    } catch (e) {
      debugPrint('读取阅读亮度失败: $e');
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('亮度调节失败，请重试')));
  }

  Future<void> _setFollowSystem(bool followSystem) async {
    setState(() => _busy = true);
    try {
      await SystemBrightness.setFollowSystem(followSystem);
      await _refresh();
    } catch (e) {
      debugPrint('切换阅读亮度模式失败: $e');
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBrightness(double brightness) async {
    setState(() {
      _brightness = brightness;
      _followSystem = false;
    });
    try {
      await SystemBrightness.setBrightness(brightness);
    } catch (e) {
      debugPrint('设置阅读亮度失败: $e');
      _showError();
      await _refresh();
    }
  }

  Widget _slider() => Slider(
    padding: widget.vertical ? const EdgeInsets.symmetric(horizontal: 8) : null,
    value: _brightness,
    label: '${(_brightness * 100).round()}%',
    onChangeStart: _busy ? null : (_) => _dragging = true,
    onChangeEnd: _busy
        ? null
        : (_) {
            _dragging = false;
            unawaited(_refresh());
          },
    onChanged: _busy ? null : (value) => unawaited(_setBrightness(value)),
  );

  @override
  Widget build(BuildContext context) {
    if (_supported == null) {
      return widget.compact
          ? const SizedBox.shrink()
          : const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            );
    }
    if (_supported == false) {
      return widget.compact
          ? const SizedBox.shrink()
          : const Text('此设备不支持亮度调节');
    }

    if (widget.compact) {
      final autoButton = IconButton(
        icon: Icon(
          _followSystem
              ? Icons.brightness_auto
              : Icons.brightness_auto_outlined,
        ),
        tooltip: _followSystem ? '改为手动亮度' : '跟随系统亮度',
        onPressed: _busy
            ? null
            : () => unawaited(_setFollowSystem(!_followSystem)),
      );
      if (widget.vertical) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: ReaderBrightnessControl.verticalWidth,
              child: Center(child: autoButton),
            ),
            Expanded(child: RotatedBox(quarterTurns: 3, child: _slider())),
            SizedBox.square(
              dimension: ReaderBrightnessControl.verticalWidth,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: '切换亮度控件位置',
                  onPressed: widget.onSwitchSide,
                ),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          autoButton,
          Expanded(child: _slider()),
        ],
      );
    }

    return Column(
      children: [
        SettingSwitchRow(
          title: '跟随系统亮度',
          subtitle: '关闭后可单独调节阅读亮度',
          value: _followSystem,
          onChanged: _busy
              ? null
              : (value) => unawaited(_setFollowSystem(value)),
        ),
        if (!_followSystem)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.brightness_low, size: 20),
                Expanded(child: _slider()),
                const Icon(Icons.brightness_high, size: 20),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(_brightness * 100).round()}%',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
