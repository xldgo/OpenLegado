export '../domain/models/eye_protection_settings.dart';

const eyeProtectionIdentityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

/// 使用上游 EyeProtection 的 5500–2596 K 色温及 RGB 多项式系数。
List<double> eyeProtectionMatrix(int intensity) {
  if (intensity <= 0) return eyeProtectionIdentityMatrix;
  final temperature = (5500 - (5500 - 2596) * intensity.clamp(0, 100) / 100)
      .truncateToDouble();
  final squared = temperature * temperature;
  final green =
      squared * -9.623533e-9 + temperature * 1.5304548e-4 + 0.39078277;
  final blue = squared * -1.8935904e-8 + temperature * 3.024122e-4 - 0.1986509;
  return [1, 0, 0, 0, 0, 0, green, 0, 0, 0, 0, 0, blue, 0, 0, 0, 0, 0, 1, 0];
}
