import 'dart:convert';

import '../../../models/book_chapter.dart';
import '../../../utils/comic_image_utils.dart';

/// 保留正文图片、CBZ条目和章节封面原有解析顺序。— Codex + UI
List<String> parseComicChapterImages(String content, BookChapter chapter) {
  final cbz = content.contains('cbz://')
      ? content
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.startsWith('cbz://'))
            .toList()
      : <String>[];
  var urls = cbz.isNotEmpty ? cbz : parseComicImageUrls(content);
  if (urls.any((url) => !url.startsWith('http') && !url.startsWith('cbz://'))) {
    urls = urls.map((url) => _resolveImageUrl(chapter.url, url)).toList();
  }
  if (chapter.imgUrl?.isNotEmpty ?? false) urls.insert(0, chapter.imgUrl!);
  return urls;
}

String _resolveImageUrl(String chapterUrl, String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  final uri = Uri.tryParse(chapterUrl);
  if (uri == null) return url;
  final base = uri.scheme.isNotEmpty && uri.host.isNotEmpty
      ? '${uri.scheme}://${uri.host}'
      : chapterUrl;
  if (url.startsWith('/')) return '$base$url';
  final path = uri.path;
  final dir = path.substring(0, path.lastIndexOf('/') + 1);
  return '$base$dir$url';
}

/// 书源头支持JSON或逐行键值，不在界面重复解析。— Codex + UI
Map<String, String> parseComicImageHeaders(String header) {
  final trimmed = header.trim();
  if (trimmed.isEmpty) return const {};
  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (_) {
      // JSON解析失败沿用逐行格式。
    }
  }
  final map = <String, String>{};
  for (final line in trimmed.split('\n')) {
    final index = line.indexOf(':');
    if (index > 0) {
      map[line.substring(0, index).trim()] = line.substring(index + 1).trim();
    }
  }
  return map;
}
