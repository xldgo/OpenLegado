import '../../bridge/media_dto.dart' as dto;
import '../../models/models.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/tts_cache_repository.dart';
import '../../domain/models/audio_media.dart';

// 媒体快照逐字段映射；配置文档保留原格式，取消与租约由执行层持有。— Codex + Bridge
int _i32(int v, String field) {
  if (v < -2147483648 || v > 2147483647) {
    throw RangeError.range(v, -2147483648, 2147483647, field);
  }
  return v;
}

int _u32(int v, String field) {
  if (v < 0 || v > 4294967295) {
    throw RangeError.range(v, 0, 4294967295, field);
  }
  return v;
}

dto.CloudTtsProviderDto cloudProviderToDto(String v) => switch (v) {
  'openai_speech' => dto.CloudTtsProviderDto.openAiSpeech,
  'mimo' => dto.CloudTtsProviderDto.mimo,
  'alibaba_cloud' => dto.CloudTtsProviderDto.alibabaCloud,
  _ => throw FormatException('不支持的云端供应商：$v'),
};
String cloudProviderFromDto(dto.CloudTtsProviderDto v) => switch (v) {
  dto.CloudTtsProviderDto.openAiSpeech => 'openai_speech',
  dto.CloudTtsProviderDto.mimo => 'mimo',
  dto.CloudTtsProviderDto.alibabaCloud => 'alibaba_cloud',
};
HttpTts httpTtsFromDto(dto.HttpTtsConfigDto v) => HttpTts(
  id: v.id,
  name: v.name,
  url: v.url,
  contentType: v.contentType,
  pauseDuration: v.pauseDuration,
  concurrentRate: v.concurrentRate,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  header: v.header,
  jsLib: v.jsLib,
  enabledCookieJar: v.enabledCookieJar,
  loginCheckJs: v.loginCheckJs,
  speed: v.speed,
  synthesisThreadCount: v.synthesisThreadCount,
  lastUpdateTime: v.lastUpdateTime,
  isEnabled: v.isEnabled,
);
dto.HttpTtsConfigDto httpTtsToDto(HttpTts v) => dto.HttpTtsConfigDto(
  id: v.id,
  name: v.name,
  url: v.url,
  contentType: v.contentType,
  pauseDuration: _i32(v.pauseDuration, 'pauseDuration'),
  concurrentRate: v.concurrentRate,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  header: v.header,
  jsLib: v.jsLib,
  enabledCookieJar: v.enabledCookieJar,
  loginCheckJs: v.loginCheckJs,
  speed: v.speed == null ? null : _i32(v.speed!, 'speed'),
  synthesisThreadCount: v.synthesisThreadCount.clamp(
    1,
    kMaxHttpTtsSynthesisThreadCount,
  ),
  lastUpdateTime: v.lastUpdateTime,
  isEnabled: v.isEnabled,
);
CloudTtsEngine cloudEngineFromDto(dto.CloudTtsMetadataDto v) => CloudTtsEngine(
  id: v.id,
  name: v.name,
  provider: cloudProviderFromDto(v.provider),
  baseUrl: v.baseUrl,
  model: v.model,
  optionsJson: v.optionsJson,
  region: v.region,
  appId: v.appId,
  enabled: v.enabled,
  createdAt: v.createdAt,
  updatedAt: v.updatedAt,
  credentialKey: v.credentialKey,
);
dto.CloudTtsMetadataDto cloudEngineToDto(CloudTtsEngine v) =>
    dto.CloudTtsMetadataDto(
      id: v.id,
      name: v.name,
      provider: cloudProviderToDto(v.provider),
      baseUrl: v.baseUrl,
      model: v.model,
      optionsJson: v.optionsJson,
      region: v.region,
      appId: v.appId,
      enabled: v.enabled,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
      credentialKey: v.credentialKey,
    );
ReadAloudVoice readAloudVoiceFromDto(dto.ReadAloudVoiceDto v) => ReadAloudVoice(
  id: v.id,
  engineType: v.engineType,
  engineId: v.engineId,
  speakerId: v.speakerId,
  displayName: v.displayName,
  traitsJson: v.traitsJson,
  emotionCatalogJson: v.emotionCatalogJson,
  managedBy: v.managedBy,
  enabled: v.enabled,
  available: v.available,
  excluded: v.excluded,
  revision: v.revision,
  createdAt: v.createdAt,
  updatedAt: v.updatedAt,
);
dto.ReadAloudVoiceDto readAloudVoiceToDto(ReadAloudVoice v) =>
    dto.ReadAloudVoiceDto(
      id: v.id,
      engineType: v.engineType,
      engineId: v.engineId,
      speakerId: v.speakerId,
      displayName: v.displayName,
      traitsJson: v.traitsJson,
      emotionCatalogJson: v.emotionCatalogJson,
      managedBy: v.managedBy,
      enabled: v.enabled,
      available: v.available,
      excluded: v.excluded,
      revision: v.revision,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
    );
SystemVoiceCatalogEntry systemVoiceFromDto(dto.SystemVoiceEntryDto v) =>
    SystemVoiceCatalogEntry(
      speakerId: v.speakerId,
      displayName: v.displayName,
      traitsJson: v.traitsJson,
    );
dto.SystemVoiceEntryDto systemVoiceToDto(SystemVoiceCatalogEntry v) =>
    dto.SystemVoiceEntryDto(
      speakerId: v.speakerId,
      displayName: v.displayName,
      traitsJson: v.traitsJson,
    );
TtsCacheContext ttsCacheContextFromDto(dto.TtsCacheContextDto v) =>
    TtsCacheContext(
      bookUrl: v.bookUrl,
      bookName: v.bookName,
      chapterIndex: v.chapterIndex,
      chapterTitle: v.chapterTitle,
      paragraphIndex: v.paragraphIndex,
      text: v.text,
    );
dto.TtsCacheContextDto ttsCacheContextToDto(TtsCacheContext v) =>
    dto.TtsCacheContextDto(
      bookUrl: v.bookUrl,
      bookName: v.bookName,
      chapterIndex: _u32(v.chapterIndex, 'chapterIndex'),
      chapterTitle: v.chapterTitle,
      paragraphIndex: _u32(v.paragraphIndex, 'paragraphIndex'),
      text: v.text,
    );
TtsCacheEntry ttsCacheEntryFromDto(dto.TtsCacheEntryDto v) => TtsCacheEntry(
  name: v.name,
  sizeBytes: v.sizeBytes.toInt(),
  modifiedAtMs: v.modifiedAtMs.toInt(),
  protected: v.protected,
  contexts: List.unmodifiable(v.contexts.map(ttsCacheContextFromDto)),
);
TtsCacheClearResult ttsCacheClearResultFromDto(dto.TtsCacheClearResultDto v) =>
    TtsCacheClearResult(
      removedFiles: v.removedFiles.toInt(),
      removedBytes: v.removedBytes.toInt(),
      skippedFiles: v.skippedFiles.toInt(),
    );
AudioChapterMedia audioChapterMediaFromDto(dto.AudioChapterMediaDto v) =>
    AudioChapterMedia(
      chapterIndex: v.chapterIndex,
      title: v.title,
      mediaUrl: v.mediaUrl,
      url: v.chapterUrl,
      resourceUrl: v.resourceUrl,
      isVolume: v.isVolume,
      fromCache: v.fromCache,
      lyric: v.lyric,
      sourceUrl: v.sourceUrl,
    );
dto.CloudVoiceOptionsDto cloudVoiceOptionsToDto(Map<String, dynamic> value) {
  const allowed = {
    'voiceId',
    'locale',
    'style',
    'role',
    'instructions',
    'speed',
    'pitch',
    'volume',
    'format',
    'sampleRate',
  };
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('云端试听参数包含未知字段');
  }
  double? number(String key) {
    final number = (value[key] as num?)?.toDouble();
    if (number != null && !number.isFinite) {
      throw ArgumentError.value(number, key, '音色数值必须为有限值');
    }
    return number;
  }

  final sampleRate = value['sampleRate'] as int?;
  return dto.CloudVoiceOptionsDto(
    voiceId: value['voiceId'] as String?,
    locale: value['locale'] as String?,
    style: value['style'] as String?,
    role: value['role'] as String?,
    instructions: value['instructions'] as String?,
    speed: number('speed'),
    pitch: number('pitch'),
    volume: number('volume'),
    format: value['format'] as String?,
    sampleRate: sampleRate == null ? null : _u32(sampleRate, 'sampleRate'),
  );
}
