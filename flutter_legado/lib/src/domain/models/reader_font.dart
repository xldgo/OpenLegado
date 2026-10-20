/// 自定义字体的原目录条目；文件内容不进入偏好。— Codex + UI
final class ReaderFont {
  const ReaderFont({required this.family, required this.path});

  final String family;
  final String path;
  String get label => family.replaceFirst('Custom_', '');
  String encode() => '$family|$path';

  static ReaderFont? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 2 || parts.any((part) => part.isEmpty)) return null;
    return ReaderFont(family: parts[0], path: parts[1]);
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderFont && family == other.family && path == other.path;
  @override
  int get hashCode => Object.hash(family, path);
}
