import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 整行向上滚动切换，复用 Flutter 弹簧与位移动画。— Codex + UI
class AppAnimatedTextLine extends StatefulWidget {
  const AppAnimatedTextLine(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  State<AppAnimatedTextLine> createState() => _AppAnimatedTextLineState();
}

class _AppAnimatedTextLineState extends State<AppAnimatedTextLine>
    with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1500,
    ratio: 1,
  );
  final _entries = <_TextEntry>[];
  late _TextEntry _current;
  bool _disableAnimations = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _current = _createEntry(widget.text, 0);
  }

  _TextEntry _createEntry(String text, double offset) {
    final entry = _TextEntry(
      text,
      AnimationController.unbounded(vsync: this, value: offset),
    );
    _entries.add(entry);
    return entry;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations) _finishImmediately();
  }

  @override
  void didUpdateWidget(AppAnimatedTextLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    if (_disableAnimations) {
      _current = _createEntry(widget.text, 0);
      _finishImmediately();
      return;
    }
    final outgoing = _current;
    _current = _createEntry(widget.text, 1);
    _move(outgoing, -1);
    _move(_current, 0);
  }

  void _finishImmediately() {
    for (final entry in _entries.toList()) {
      if (entry != _current) {
        _entries.remove(entry);
        entry.controller.dispose();
      }
    }
    _current.controller.value = 0;
  }

  void _move(_TextEntry entry, double target) {
    final controller = entry.controller;
    // 中断时保留当前位移与速度，不从整行边界重新起步。
    controller
        .animateWith(
          SpringSimulation(
            _spring,
            controller.value,
            target,
            controller.velocity,
          ),
        )
        .whenCompleteOrCancel(() {
          if (_disposed ||
              !mounted ||
              !_entries.contains(entry) ||
              entry == _current ||
              target != -1) {
            return;
          }
          setState(() => _entries.remove(entry));
          controller.dispose();
        });
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _entries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        for (final entry in _entries)
          ExcludeSemantics(
            key: ObjectKey(entry),
            excluding: entry != _current,
            child: AnimatedBuilder(
              animation: entry.controller,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(0, entry.controller.value),
                child: child,
              ),
              child: Text(
                entry.text,
                style: widget.style,
                maxLines: widget.maxLines,
                softWrap: widget.maxLines != 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    ),
  );
}

class _TextEntry {
  _TextEntry(this.text, this.controller);

  final String text;
  final AnimationController controller;
}
