import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// 正文滚动只影响展示与跟随，不改变朗读位置。— Codex + UI
class ReadAloudChapterText extends StatefulWidget {
  const ReadAloudChapterText({
    super.key,
    required this.paragraphs,
    required this.activeIndex,
    this.onSeek,
    required this.active,
    required this.onUserScrollChanged,
  });
  final List<String> paragraphs;
  final int activeIndex;
  final ValueChanged<int>? onSeek;
  final bool active;
  final ValueChanged<bool> onUserScrollChanged;

  @override
  State<ReadAloudChapterText> createState() => ReadAloudChapterTextState();
}

class ReadAloudChapterTextState extends State<ReadAloudChapterText> {
  final _scroll = ScrollController();
  final List<double> _tops = [8];
  final List<double> _heights = [];
  Object? _metricsKey;
  bool _pending = false;
  bool _dragging = false;
  int? _lastFollowed;
  Timer? _restoreTimer;

  @override
  void didUpdateWidget(covariant ReadAloudChapterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _restoreTimer?.cancel();
      _dragging = false;
    }
    if (oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.active != widget.active) {
      _scheduleFollow();
    }
  }

  void _scheduleFollow() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted ||
          !widget.active ||
          _dragging ||
          !_scroll.hasClients ||
          widget.activeIndex < 0 ||
          _tops.length <= widget.activeIndex) {
        return;
      }
      if (_lastFollowed == widget.activeIndex) return;
      _lastFollowed = widget.activeIndex;
      final position = _scroll.position;
      final target =
          (_tops[widget.activeIndex] - position.viewportDimension * 0.32).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        // 跨越很远时先靠近目标，避免整章高速掠过。
        if ((target - _scroll.offset).abs() > position.viewportDimension * 2) {
          _scroll.jumpTo(
            (target + position.viewportDimension * 0.08).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        }
        unawaited(
          _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 520),
            curve: Curves.fastOutSlowIn,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleLarge!.copyWith(
      height: 1.4,
      fontWeight: FontWeight.w500,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final key = (
          widget.paragraphs,
          constraints.maxWidth,
          style,
          scaler,
          direction,
          locale,
        );
        if (_metricsKey != key) {
          _metricsKey = key;
          _tops
            ..clear()
            ..add(8);
          _heights.clear();
          final painter = TextPainter(
            textDirection: direction,
            locale: locale,
            textScaler: scaler,
          );
          for (final text in widget.paragraphs) {
            painter.text = TextSpan(text: text, style: style);
            painter.layout(
              maxWidth: (constraints.maxWidth - 56).clamp(1, double.infinity),
            );
            final height = painter.height + 32;
            _heights.add(height);
            _tops.add(_tops.last + height);
          }
          painter.dispose();
          _lastFollowed = null;
        }
        _scheduleFollow();
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0 || !widget.active) return false;
            if ((notification is ScrollStartNotification &&
                    notification.dragDetails != null) ||
                (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle)) {
              _restoreTimer?.cancel();
              _dragging = true;
              widget.onUserScrollChanged(true);
            } else if (notification is ScrollEndNotification && _dragging) {
              // 等待惯性滚动结束；新拖动会撤销旧恢复计时器。
              _restoreTimer?.cancel();
              _restoreTimer = Timer(const Duration(milliseconds: 650), () {
                if (!mounted || !widget.active) return;
                _dragging = false;
                widget.onUserScrollChanged(false);
                _scheduleFollow();
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: widget.paragraphs.length,
            itemExtentBuilder: (index, _) => _heights[index],
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onSeek == null
                      ? null
                      : () => widget.onSeek!(index),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.paragraphs[index],
                      style: style.copyWith(
                        color: index == widget.activeIndex
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
