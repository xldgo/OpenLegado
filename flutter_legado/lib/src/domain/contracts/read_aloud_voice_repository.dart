import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 独立音色目录，不拥有播放或平台插件。— Codex + Bridge
final class ReadAloudVoice {
  const ReadAloudVoice({
    required this.id,
    required this.engineType,
    required this.engineId,
    required this.speakerId,
    required this.displayName,
    this.traitsJson = '[]',
    this.emotionCatalogJson = '[]',
    this.managedBy = '',
    this.enabled = true,
    this.available = true,
    this.excluded = false,
    this.revision = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });
  final String id,
      engineType,
      engineId,
      speakerId,
      displayName,
      traitsJson,
      emotionCatalogJson,
      managedBy;
  final bool enabled, available, excluded;
  final int revision, createdAt, updatedAt;
  bool get selectable => enabled && available && !excluded;
  Map<String, dynamic> toJson() => {
    'id': id,
    'engineType': engineType,
    'engineId': engineId,
    'speakerId': speakerId,
    'displayName': displayName,
    'traitsJson': traitsJson,
    'emotionCatalogJson': emotionCatalogJson,
    'managedBy': managedBy,
    'enabled': enabled,
    'available': available,
    'excluded': excluded,
    'revision': revision,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
  factory ReadAloudVoice.fromJson(Map<String, dynamic> j) => ReadAloudVoice(
    id: j['id'] as String,
    engineType: j['engineType'] as String,
    engineId: j['engineId'] as String,
    speakerId: j['speakerId'] as String,
    displayName: j['displayName'] as String,
    traitsJson: j['traitsJson'] as String,
    emotionCatalogJson: j['emotionCatalogJson'] as String,
    managedBy: j['managedBy'] as String,
    enabled: j['enabled'] as bool,
    available: j['available'] as bool,
    excluded: j['excluded'] as bool,
    revision: j['revision'] as int,
    createdAt: j['createdAt'] as int,
    updatedAt: j['updatedAt'] as int,
  );
  ReadAloudVoice copyWith({
    String? displayName,
    String? traitsJson,
    String? emotionCatalogJson,
    bool? enabled,
    bool? available,
    bool? excluded,
  }) => ReadAloudVoice(
    id: id,
    engineType: engineType,
    engineId: engineId,
    speakerId: speakerId,
    displayName: displayName ?? this.displayName,
    traitsJson: traitsJson ?? this.traitsJson,
    emotionCatalogJson: emotionCatalogJson ?? this.emotionCatalogJson,
    managedBy: managedBy,
    enabled: enabled ?? this.enabled,
    available: available ?? this.available,
    excluded: excluded ?? this.excluded,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

final class SystemVoiceCatalogEntry {
  const SystemVoiceCatalogEntry({
    required this.speakerId,
    required this.displayName,
    required this.traitsJson,
  });
  final String speakerId, displayName, traitsJson;
  Map<String, String> toJson() => {
    'speakerId': speakerId,
    'displayName': displayName,
    'traitsJson': traitsJson,
  };
}

abstract interface class ReadAloudVoiceRepository {
  bool get supportsCatalog;
  Future<List<ReadAloudVoice>> list();
  Future<void> save(ReadAloudVoice voice);
  Future<void> delete(String id);
  Future<void> syncSystem(
    String engineId,
    List<SystemVoiceCatalogEntry> entries,
  );
  Future<void> setFlags(
    String id, {
    required bool enabled,
    required bool excluded,
  });
}

/// 与 Rust/upstream 使用相同的引擎+音色稳定身份。— Codex + Bridge
String readAloudVoiceId(String kind, String engine, String speaker) =>
    'voice:${sha256.convert(utf8.encode('$kind\u0000$engine\u0000$speaker')).toString().substring(0, 32)}';
