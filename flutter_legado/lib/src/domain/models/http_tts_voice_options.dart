import 'dart:convert';

/// 目录标签与用户预设共用解析，保存时不丢失已有参数。— Codex + Bridge
final class HttpTtsVoiceOptions {
  HttpTtsVoiceOptions(String json) : values = _decode(json);
  final Map<String, dynamic> values;

  static Map<String, dynamic> _decode(String json) =>
      switch (jsonDecode(json)) {
        List<dynamic> tags => {'tags': tags},
        Map<String, dynamic> fields => Map.of(fields),
        _ => throw const FormatException('HTTP 音色参数必须为标签数组或对象'),
      };

  String? get emotionTag {
    final value = (values['emotionTag'] as String?)?.trim();
    return value?.isEmpty == true ? null : value;
  }

  List<dynamic> get tags => values['tags'] as List<dynamic>? ?? const [];

  Map<String, dynamic> withEmotion(String? tag) => {
    ...values,
    'emotionTag': tag?.trim().isEmpty == true ? null : tag?.trim(),
  };
}
