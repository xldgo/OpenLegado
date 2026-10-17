import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/platform_bridge_service.dart';
import '../application/comic_image_actions_service.dart';

/// 漫画导出所用的平台插件适配，沿用现有原生通道。— Codex + UI
class PluginComicImageActionsPlatform implements ComicImageActionsPlatform {
  const PluginComicImageActionsPlatform();

  @override
  bool get useMediaStoreDownloads =>
      PlatformBridgeService.instance.useMediaStoreDownloads;
  @override
  Future<String?> saveDownloads(String name, Uint8List bytes) =>
      PlatformBridgeService.instance.saveImageToDownloads(name, bytes);
  @override
  Future<Uri?> chooseFile(String name, Uint8List bytes) =>
      FilePicker.saveFile(dialogTitle: '保存图片', fileName: name, bytes: bytes);
  @override
  Future<String> writeDocuments(String name, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<void> shareImage(String name, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: '漫画图片'),
    );
  }

  @override
  Future<void> copyLink(String url) =>
      Clipboard.setData(ClipboardData(text: url));
}
