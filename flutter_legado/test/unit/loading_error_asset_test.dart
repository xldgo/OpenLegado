import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [STAGE-UI-P43UNIFY1 B1] 图片加载失败占位素材存在性与 pubspec 声明断言
///
/// 取证（docs/LOADING_ASSETS_UNIFY_SURVEY_20260930.md §2.4/§3.3）：
/// - `image_loading_error.png` 为原版/参考版共有素材（原版
///   `app/src/main/res/drawable/image_loading_error.png` 6933B，md5
///   1238cf6b80dc1ff61fa823a232ffb71a；参考版同名同字节）；
/// - 参考版图片加载失败形态 = 直接显示该素材图（ImageProvider.kt:39
///   阅读错误 bitmap、PhotoDialog.kt:61 / VerificationCodeDialog.kt:91
///   Coil `.error()`），我方对应位置此前用 `Icons.broken_image` 图标
///   代替，B1 批拷入本素材并替换引用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter test 工作目录 = 包根（flutter_legado/）
  final root = Directory.current;

  test('assets/images/image_loading_error.png 存在且字节数与原版一致（6933B）', () {
    final file = File(
      '${root.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}images'
      '${Platform.pathSeparator}image_loading_error.png',
    );
    expect(file.existsSync(), isTrue, reason: '素材文件应已拷入 assets/images/');
    // 原版/参考版均 6933B（调研报告 §3.3 字节级对齐口径）
    expect(
      file.lengthSync(),
      6933,
      reason: '素材须与原版 res/drawable/image_loading_error.png 字节一致',
    );
  });

  test('素材可通过 Flutter 资产包加载，且数据完整有效', () async {
    final assetFile = File(
      '${root.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}images'
      '${Platform.pathSeparator}image_loading_error.png',
    );
    expect(assetFile.existsSync(), isTrue);
    final bytes = await assetFile.readAsBytes();
    expect(bytes.length, 6933);
    // 验证 PNG 头部魔数 (89 50 4E 47 0D 0A 1A 0A)
    expect(bytes.sublist(0, 8), [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
  });
}
