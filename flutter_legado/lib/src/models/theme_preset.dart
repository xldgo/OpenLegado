/// 本地命名主题，保留已存条目的原始字段，读取时不改写旧数据。
class ThemePreset {
  ThemePreset.fromJson(Map<String, dynamic> json)
    : _json = Map.unmodifiable(json);

  ThemePreset({
    required String name,
    required bool isNight,
    int? primary,
    int? accent,
    int? background,
    int? bottomBackground,
  }) : _json = Map.unmodifiable({
         'name': name,
         'isNight': isNight,
         'primary': primary,
         'accent': accent,
         'background': background,
         'bottomBackground': bottomBackground,
       });

  final Map<String, dynamic> _json;

  String get name => '${_json['name'] ?? '未命名'}';
  bool get isNight => _json['isNight'] == true;
  int? get primary => _json['primary'] as int?;
  int? get accent => _json['accent'] as int?;
  int? get background => _json['background'] as int?;
  int? get bottomBackground => _json['bottomBackground'] as int?;

  Map<String, dynamic> toJson() => Map.of(_json);
}
