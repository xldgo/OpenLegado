import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/services/media_artwork_loader.dart';

/// 不触发网络或图片解码，允许确定性控制迟到结果。
class FakeMediaArtworkLoader extends Fake implements MediaArtworkLoader {
  final requests = <({Book? book, bool hidden})>[];
  Future<Uint8List?> Function(Book? book, bool hidden)? resolve;
  @override
  Future<Uint8List?> load(Book? book, {bool hidden = false}) {
    requests.add((book: book, hidden: hidden));
    return resolve?.call(book, hidden) ?? Future.value(null);
  }
}
