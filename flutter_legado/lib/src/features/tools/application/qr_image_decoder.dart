import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart' show QRCodeReader;
import 'package:zxing2/zxing2.dart'
    show
        BinaryBitmap,
        HybridBinarizer,
        Result,
        ResultMetadataType,
        RGBLuminanceSource;

/// 图库图片解码入口；页面通过compute调用，测试直接验证同一实现。
/// 非图片、截断数据或未识别到二维码时统一返回null。
/// — Codex + UI
String? decodeQrImage(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final rgba = image.convert(numChannels: 4);
    final pixels = rgba
        .getBytes(order: img.ChannelOrder.rgba)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(rgba.width, rgba.height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return _recoverUtf8Text(QRCodeReader().decode(bitmap));
  } catch (_) {
    // 图片格式探测也可能抛出Error，按图库未识别处理。
    return null;
  }
}

/// 修复zxing2带符号字节段导致的中文替换符；无法修复时保留原结果。
String _recoverUtf8Text(Result result) {
  final text = result.text;
  if (!text.contains('\uFFFD')) return text;
  final segments =
      result.resultMetadata[ResultMetadataType.byteSegments] as List<Int8List>?;
  if (segments == null || segments.isEmpty) return text;
  const utf8 = Utf8Codec(allowMalformed: true);
  final rebuilt = segments.map((segment) {
    final unsigned = Uint8List(segment.length);
    for (var i = 0; i < segment.length; i++) {
      unsigned[i] = segment[i] & 0xFF;
    }
    return utf8.decode(unsigned);
  }).join();
  return rebuilt.contains('\uFFFD') ? text : rebuilt;
}
