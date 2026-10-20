import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show SelectionStatus, SelectionGeometry;
import 'package:flutter/services.dart';

import '../paragraph_layout_engine.dart';
import 'reader_selection_controller.dart';
import 'reader_selection_toolbar.dart';
import 'reader_menu_theme.dart';

/// 复用 Flutter 选区的高亮和跨行手柄，原生锚点交给阅读菜单定位。
class ReaderSelectionRegion extends StatefulWidget {
  final ReaderSelectionController? controller;
  final List<PageInfo> pages;
  final String source;
  final Widget child;
  final ValueChanged<TapUpDetails>? onTapUp;

  const ReaderSelectionRegion({
    super.key,
    this.controller,
    required this.pages,
    required this.source,
    required this.child,
    this.onTapUp,
  });

  @override
  State<ReaderSelectionRegion> createState() => _ReaderSelectionRegionState();
}

class _ReaderSelectionRegionState extends State<ReaderSelectionRegion> {
  final _focusNode = FocusNode();
  final _areaKey = GlobalKey<SelectionAreaState>();
  final _listener = SelectionListenerNotifier();
  late ReaderSelectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ReaderSelectionController();
    _controller.configure(widget.source, widget.pages);
    _controller.attachClear(_clearNative);
    _listener.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(ReaderSelectionRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source ||
        !listEquals(widget.pages, oldWidget.pages)) {
      // 先清除旧文本上的原生选区，再替换映射，避免旧手柄落到新正文。
      _controller.clear();
      _controller.configure(widget.source, widget.pages);
    }
  }

  void _clearNative() =>
      _areaKey.currentState?.selectableRegion.clearSelection();

  void _onSelectionChanged() {
    if (!_listener.registered) return;
    final selection = _listener.selection;
    final range = selection.range;
    if (selection.status != SelectionStatus.uncollapsed || range == null) {
      _controller.updateRange(0, 0);
    } else {
      _controller.updateRange(range.startOffset, range.endOffset);
    }
  }

  @override
  void dispose() {
    _listener.removeListener(_onSelectionChanged);
    _listener.dispose();
    _focusNode.dispose();
    _controller.detachClear(_clearNative);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderSelectionScope(
      controller: _controller,
      child: Actions(
        actions: {
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (_) {
              final selected = _controller.selection;
              if (selected != null) {
                Clipboard.setData(ClipboardData(text: selected.text));
              }
              return null;
            },
          ),
        },
        child: SelectionArea(
          key: _areaKey,
          focusNode: _focusNode,
          contextMenuBuilder: (_, region) {
            _onSelectionChanged();
            final selected = _controller.selection;
            if (selected == null) return const SizedBox.shrink();
            final anchors = region.contextMenuAnchors;
            final menuContext = readerMenuContextOf(context);
            return InheritedTheme.captureAll(
              menuContext,
              ReaderSelectionToolbar(
                actionContext: menuContext,
                anchor: anchors.primaryAnchor,
                anchorBelow: anchors.secondaryAnchor,
                selectionFocusNode: _focusNode,
                text: selected.text,
                chapterPos: selected.start,
                onDismiss: () {
                  region.hideToolbar();
                  _controller.clear();
                },
              ),
            );
          },
          child: Listener(
            onPointerDown: (_) => _controller.onPointerDown(),
            child: SelectionListener(
              selectionNotifier: _listener,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: widget.onTapUp == null
                    ? null
                    : (details) {
                        if (!_controller.consumeTap()) widget.onTapUp!(details);
                      },
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 将一页正文作为整体参与选择排序，双页时先读完左页再进入右页。
class ReaderSelectionTextGroup extends StatefulWidget {
  final Widget child;

  const ReaderSelectionTextGroup({super.key, required this.child});

  @override
  State<ReaderSelectionTextGroup> createState() =>
      _ReaderSelectionTextGroupState();
}

class _ReaderSelectionTextGroupState extends State<ReaderSelectionTextGroup> {
  final _delegate = _ReaderPageSelectionDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) {
      return SelectionContainer.disabled(child: widget.child);
    }
    return SelectionContainer(
      registrar: registrar,
      delegate: _delegate,
      child: widget.child,
    );
  }
}

/// 完整正文页作为一个可选单元先注册，再接收异步挂载的行。
/// 避免多层容器在同一帧末依次注册，导致父级未看到正文内容。
class _ReaderPageSelectionDelegate extends StaticSelectionContainerDelegate {
  @override
  SelectionGeometry get value => super.value.copyWith(hasContent: true);
}

class ReaderSelectionScope extends InheritedWidget {
  final ReaderSelectionController controller;

  const ReaderSelectionScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static ReaderSelectionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReaderSelectionScope>()
      ?.controller;

  @override
  bool updateShouldNotify(ReaderSelectionScope oldWidget) =>
      controller != oldWidget.controller;
}
