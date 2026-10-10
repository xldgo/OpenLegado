import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/cover_palette_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legado_palette_');
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await directory.delete(recursive: true);
  });

  Future<File> writeCover(String name, List<Color> colors) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var index = 0; index < colors.length; index++) {
      canvas.drawRect(
        Rect.fromLTWH(0, index * 128 / colors.length, 128, 128 / colors.length),
        Paint()..color = colors[index],
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(128, 128);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final file = File('${directory.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }

  test('空地址与不存在的封面返回 null，交由调用方回退配色', () async {
    expect(await CoverPaletteService.extractSeed('  '), isNull);
    expect(
      await CoverPaletteService.extractSeed('${directory.path}/missing'),
      isNull,
    );
  });

  test('损坏的本地封面返回 null', () async {
    final file = File('${directory.path}/invalid.png');
    await file.writeAsString('invalid');
    expect(await CoverPaletteService.extractSeed(file.path), isNull);
  });

  test('固定封面的主色与旧版量化结果一致', () async {
    final fixtures = <String, List<Color>>{
      'blue': [const Color(0xff4285f4)],
      'mixed': [
        const Color(0xffc85040),
        const Color(0xffc85040),
        const Color(0xff4080c0),
      ],
      'filtered': [
        const Color(0xffffffff),
        const Color(0xff000000),
        const Color(0xff509850),
      ],
      'transparent': [const Color(0x00000000)],
      'gradient': List.generate(
        96,
        (index) => Color.fromARGB(255, index * 2, 128, 255 - index * 2),
      ),
    };
    // 由 palette_generator 0.3.3+7 在同一组图片上记录的回归基线。
    const expected = <String, int?>{
      'blue': 0xff4080f0,
      'mixed': 0xffc85040,
      'filtered': 0xff509850,
      'transparent': null,
      'gradient': 0xff0060c0,
    };
    for (final fixture in fixtures.entries) {
      final file = await writeCover(fixture.key, fixture.value);
      final seed = await CoverPaletteService.extractSeed(' ${file.path} ');
      expect(seed?.toARGB32(), expected[fixture.key], reason: fixture.key);
    }
  });
}
