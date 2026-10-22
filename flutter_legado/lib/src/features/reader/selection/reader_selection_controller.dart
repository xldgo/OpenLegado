import 'package:flutter/foundation.dart';

import '../layout/paragraph_layout_engine.dart';

/// 选区位置统一使用章节原文的 UTF-16 区间，与阅读页索引分开。
@immutable
class ReaderTextSelection {
  final int start;
  final int end;
  final String text;

  const ReaderTextSelection(this.start, this.end, this.text);
}

/// 将 Flutter 跨行选区的显示偏移映射到章节原文，排除虚拟缩进。
class ReaderSelectionController extends ChangeNotifier
    implements ValueListenable<bool> {
  String _source = '';
  List<LineInfo> _lines = const [];
  ReaderTextSelection? _selection;
  VoidCallback? _clearNative;
  bool _consumeTap = false;

  ReaderTextSelection? get selection => _selection;

  @override
  bool get value => _selection != null;

  void configure(String source, List<PageInfo> pages) {
    _source = source;
    _lines = pages
        .expand((page) => page.paragraphs)
        .where((paragraph) => !paragraph.isTitle)
        .expand((paragraph) => paragraph.lines)
        .toList();
    _setSelection(null);
  }

  void attachClear(VoidCallback callback) => _clearNative = callback;

  void detachClear(VoidCallback callback) {
    if (_clearNative == callback) _clearNative = null;
  }

  void updateRange(int start, int end) {
    if (start == end || _lines.isEmpty) {
      _setSelection(null);
      return;
    }
    final first = start < end ? start : end;
    final last = start < end ? end : start;
    final rawStart = _mapOffset(first, isEnd: false).clamp(0, _source.length);
    final rawEnd = _mapOffset(
      last,
      isEnd: true,
    ).clamp(rawStart, _source.length);
    _setSelection(
      rawStart == rawEnd
          ? null
          : ReaderTextSelection(
              rawStart,
              rawEnd,
              _source.substring(rawStart, rawEnd),
            ),
    );
  }

  int _mapOffset(int offset, {required bool isEnd}) {
    var displayed = 0;
    for (final line in _lines) {
      final length = line.selectableText.length;
      if (length == 0) continue;
      if (offset < displayed + length ||
          (isEnd && offset == displayed + length)) {
        return line.sourceOffset((offset - displayed).clamp(0, length));
      }
      displayed += length;
    }
    return _lines.last.endIndex;
  }

  void _setSelection(ReaderTextSelection? next) {
    if (next?.start == _selection?.start && next?.end == _selection?.end) {
      return;
    }
    _selection = next;
    notifyListeners();
  }

  /// 选区存在时的点按只收起选区，不能同时触发阅读九宫格。
  void onPointerDown() => _consumeTap = value;

  bool consumeTap() {
    final consume = _consumeTap || value;
    _consumeTap = false;
    if (consume) clear();
    return consume;
  }

  void clear() {
    _clearNative?.call();
    _setSelection(null);
  }
}
