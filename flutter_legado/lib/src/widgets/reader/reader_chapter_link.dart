import '../../app/routing/route_arguments.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:url_launcher/url_launcher.dart';

import '../../models/book_chapter.dart';
import '../../features/reader/application/reader_settings_provider.dart';
import '../../app/routing/route_names.dart';

/// 章节导航只接受网页地址；相对路径使用章节目录的原始地址补全。
String? resolveReaderChapterWebUrl(BookChapter chapter) {
  if (chapter.isVolume || chapter.url.trim().isEmpty) return null;
  var uri = Uri.tryParse(chapter.url.trim());
  if (uri == null) return null;
  if (!uri.hasScheme) {
    final base = Uri.tryParse(chapter.baseUrl.trim());
    if (base != null &&
        (base.scheme == 'http' || base.scheme == 'https') &&
        base.host.isNotEmpty) {
      uri = base.resolveUri(uri);
    } else if (uri.hasAuthority) {
      uri = uri.replace(scheme: 'https');
    } else {
      return null;
    }
  }
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty
      ? uri.toString()
      : null;
}

/// 阅读菜单共用阅读仓储中的浏览器偏好；显式方式只覆盖本次打开。— Codex + UI
Future<void> openReaderChapterUrl(
  BuildContext context,
  String url, {
  bool? inSystemBrowser,
}) async {
  var useSystemBrowser = inSystemBrowser ?? false;
  if (inSystemBrowser == null) {
    try {
      final repository = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(readerSettingsRepositoryProvider);
      useSystemBrowser = (await repository.load()).chapterInSystemBrowser;
    } catch (error) {
      // 读取失败时保留默认的内置浏览器入口。
      debugPrint('章节打开方式读取失败：$error');
    }
  }
  if (!context.mounted) return;
  if (!useSystemBrowser) {
    Navigator.of(context).pushNamed(
      AppRoutes.browser,
      arguments: BrowserRouteArgs(url: url, title: '章节链接'),
    );
    return;
  }

  var opened = false;
  try {
    final uri = Uri.tryParse(url);
    opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // 平台打开失败也应给出反馈，不让插件异常中断阅读页面。
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
  }
}
