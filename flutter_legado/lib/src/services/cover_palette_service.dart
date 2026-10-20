import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';

/// [UI_SYNC_REFACTOR B4] 封面取色服务（对齐参考仓 rememberImageSeedColor）
///
/// 参考链路：Coil 请求 128px → 缩至 ≤64px → QuantizerCelebi(64) → Score，
/// fallback 0xFF4285F4。Flutter 侧沿用既有 median-cut 量化与 dominantColor，
/// 128px 采样、颜色上限 64；本次依赖替换保留原有取色结果。
class CoverPaletteService {
  CoverPaletteService._();

  /// 提取封面 seed 主色；失败返回 null（调用方回退默认配色）
  static Future<Color?> extractSeed(String coverUrl) async {
    ImageProvider? provider;
    final url = coverUrl.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      provider = NetworkImage(url);
    } else {
      // 本地文件路径（import_local_book 落库约定）
      final file = File(url);
      if (await file.exists()) provider = FileImage(file);
    }
    if (provider == null) return null;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(128, 128),
        maximumColorCount: 64,
        quantizer: const LegacyQuantizer(),
      );
      return palette.dominantColor?.color;
    } catch (_) {
      return null;
    }
  }
}
