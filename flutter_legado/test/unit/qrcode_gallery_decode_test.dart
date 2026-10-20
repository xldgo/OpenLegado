import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_legado/src/features/tools/application/qr_image_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart'
    show EncodeHintType, EncodeHints, Encoder, ErrorCorrectionLevel;
import 'package:zxing2/zxing2.dart' show CharacterSetECI;

/// 用 zxing2 [Encoder] 把 [content] 编码为 QR 并渲染成 PNG 字节流
/// （8 倍放大 + 4 模块静区，提升 HybridBinarizer 检测稳定性）。
///
/// 注：Encoder 默认 byte 模式字符集为 ISO8859_1（非 UTF-8），非 Latin-1
/// 内容（如中文口令）需显式指定 UTF-8 编码提示。
Uint8List _renderQrPng(String content) {
  final hints = EncodeHints()
    ..put(EncodeHintType.characterSet, CharacterSetECI.UTF8);
  final qr = Encoder.encode(content, ErrorCorrectionLevel.m, hints: hints);
  final matrix = qr.matrix;
  expect(matrix, isNotNull, reason: 'Encoder 应产出矩阵');
  const quiet = 4;
  const scale = 8;
  final size = (matrix!.width + quiet * 2) * scale;
  final image = img.Image(width: size, height: size, numChannels: 4);
  // 白底（静区 + 模块间隙）
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: size,
    y2: size,
    color: img.ColorUint8.rgba(255, 255, 255, 255),
  );
  // 暗模块（ByteMatrix.get 返回 1 = 暗）
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      final px = (x + quiet) * scale;
      final py = (y + quiet) * scale;
      img.fillRect(
        image,
        x1: px,
        y1: py,
        x2: px + scale,
        y2: py + scale,
        color: img.ColorUint8.rgba(0, 0, 0, 255),
      );
    }
  }
  return img.encodePng(image);
}

void main() {
  group('[PARITY A1] 图库本地解码管线（zxing2 + image）', () {
    test('图库后台解码：编码URL为PNG后经compute返回原文', () async {
      const content = 'https://legado.example.com/book-source.json';
      final png = _renderQrPng(content);
      expect(await compute(decodeQrImage, png), content);
    });

    // 回归测试：zxing2 0.2.4 带符号字节段缺陷（DecodedBitStreamParser 将
    // 字节段读入 Int8List，UTF-8 高字节为负被逐字节替换为 U+FFFD）。未加
    // UTF-8恢复时本用例会得到一串 U+FFFD。
    test('回环：中文口令内容（非 URL 文本，回归 CJK 乱码缺陷）', () {
      const content = 'legado://import?data=测试口令';
      final png = _renderQrPng(content);
      expect(decodeQrImage(png), content);
    });

    test('非二维码图片：解码返回 null（不抛异常）', () {
      final image = img.Image(width: 64, height: 64, numChannels: 4);
      img.fillRect(
        image,
        x1: 0,
        y1: 0,
        x2: 64,
        y2: 64,
        color: img.ColorUint8.rgba(200, 30, 30, 255),
      );
      expect(decodeQrImage(img.encodePng(image)), isNull);
    });

    test('非图片字节流：解码返回 null（不抛异常）', () {
      expect(
        decodeQrImage(Uint8List.fromList([0x01, 0x02, 0x03, 0x04])),
        isNull,
      );
    });
  });
}
