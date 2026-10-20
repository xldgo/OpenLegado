import 'dart:convert';

/// 当前累计表使用的作者集合编码；真实每日明细始终保存单一作者。— Codex + UI
Set<String> readRecordAuthors(String value) {
  const prefix = '\u001eauthors:';
  if (!value.startsWith(prefix)) return {value};
  return (jsonDecode(value.substring(prefix.length)) as List)
      .cast<String>()
      .toSet();
}

String mergeReadRecordAuthors(String previous, String author) {
  final authors = {...readRecordAuthors(previous), author}
    ..removeWhere((a) => a.trim().isEmpty);
  if (authors.isEmpty) return '';
  if (authors.length == 1) return authors.single;
  return '\u001eauthors:${jsonEncode(authors.toList()..sort())}';
}
