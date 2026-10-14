import 'dart:convert';

const systemTtsEngineUrl = 'system://default';

enum SystemTtsOutcome { completed, paused, cancelled }

class SystemTtsVoice {
  final String name;
  final String locale;
  final String? identifier;
  final bool networkRequired;

  const SystemTtsVoice({
    required this.name,
    required this.locale,
    this.identifier,
    this.networkRequired = false,
  });

  factory SystemTtsVoice.fromMap(Map<dynamic, dynamic> value) => SystemTtsVoice(
    name: value['name']?.toString() ?? '',
    locale: value['locale']?.toString() ?? '',
    identifier: value['identifier']?.toString(),
    networkRequired:
        value['network_required'] == true ||
        value['network_required']?.toString() == 'true',
  );

  String get key => jsonEncode(toMap());
  Map<String, String> toMap() => {
    'name': name,
    'locale': locale,
    'identifier': ?identifier,
  };
}

/// 系统插件的可替换平台能力，生命周期由播放会话持有。— Codex + UI
abstract interface class SystemTts {
  bool get isSupported;
  bool get supportsEngineSelection;
  bool get isPaused;
  String get selectedEngine;
  String get selectedVoice;
  void Function(int start, int end)? get onProgress;
  set onProgress(void Function(int start, int end)? callback);
  Future<void> initialize();
  Future<List<String>> getEngines();
  Future<List<SystemTtsVoice>> getVoices();
  Future<void> saveSettings({required String engine, required String voice});
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  });
  Future<SystemTtsOutcome> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}
