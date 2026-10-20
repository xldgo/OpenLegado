import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// 仅测试替换现有插件的平台实现，沿用项目的平台替身方式。
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:flutter_legado/src/features/reader_comic/data/plugin_comic_image_actions_platform.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const platform = PluginComicImageActionsPlatform();
  late Directory directory;
  final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2]);
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('comic-export-');
    final originalPaths = PathProviderPlatform.instance;
    final originalShare = SharePlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    SharePlatform.instance = MethodChannelShare();
    addTearDown(() {
      PathProviderPlatform.instance = originalPaths;
      SharePlatform.instance = originalShare;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
  });
  tearDown(() => directory.delete(recursive: true));

  test('文档目录异步写入完整字节，返回实际路径', () async {
    final path = await platform.writeDocuments('saved.png', bytes);
    expect(File(path).parent.path, directory.path);
    expect(await File(path).readAsBytes(), bytes);
  });

  test('分享调用前临时文件已经完整写入，传递原主题和图片路径', () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      final args = call.arguments as Map;
      final path = (args['paths'] as List).single as String;
      expect(await File(path).readAsBytes(), bytes);
      expect(args['subject'], '漫画图片');
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    await platform.shareImage('shared.png', bytes);
    expect(calls.single.method, 'share');
    expect(File('${directory.path}/shared.png').existsSync(), true);
  });
}
