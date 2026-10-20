/// 内置引擎只参与选择，不进入 HTTP TTS 的增删改存储。
class TtsEngineOption {
  const TtsEngineOption({required this.name, required this.url, this.id});
  final String name;
  final String url;
  final int? id;
}
