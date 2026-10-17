import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/book_chapter.dart';

/// 目录查询与展示顺序；章节实体索引不随过滤、倒序变化。— Codex + UI
class TocFilterController extends ChangeNotifier {
  String _query = '';
  bool _reversed = false;
  Timer? _debounce;

  String get query => _query;
  bool get reversed => _reversed;

  List<MapEntry<int, BookChapter>> entries(List<BookChapter> chapters) {
    final query = _query.trim().toLowerCase();
    var entries = chapters.asMap().entries.toList();
    if (query.isNotEmpty) {
      entries = entries
          .where((e) => e.value.title.toLowerCase().contains(query))
          .toList();
    }
    return _reversed ? entries.reversed.toList() : entries;
  }

  void search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = text;
      notifyListeners();
    });
  }

  void clear() {
    _debounce?.cancel();
    if (_query.isEmpty) return;
    _query = '';
    notifyListeners();
  }

  void toggleOrder() {
    _reversed = !_reversed;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
