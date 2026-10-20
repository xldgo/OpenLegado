import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('图片失败占位素材能从Flutter资产包加载并解码', () async {
    final data = await rootBundle.load('assets/images/image_loading_error.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });
}
