import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/book_chapter.dart';
import '../../routes.dart';

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

/// 新旧阅读菜单共用既有浏览器偏好；显式打开方式可覆盖该偏好。
Future<void> openReaderChapterUrl(
  BuildContext context,
  String url, {
  bool? inSystemBrowser,
}) async {
  var useSystemBrowser = inSystemBrowser ?? false;
  if (inSystemBrowser == null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      useSystemBrowser = prefs.getBool('readUrlInBrowser') ?? false;
    } catch (_) {
      // 读取失败时保留默认的内置浏览器入口。
    }
  }
  if (!context.mounted) return;
  if (!useSystemBrowser) {
    Navigator.of(context).pushNamed(
      AppRoutes.browser,
      arguments: <String, String>{'url': url, 'title': '章节链接'},
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
