import '../../domain/models/read_aloud_content.dart';

import 'dart:convert';

import '../../domain/contracts/read_aloud_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/read_aloud_settings.dart';
import '../services/app_settings_service.dart';

/// 朗读偏好的编码、默认值和迁移实现；持久化队列由 AppSettingsService 统一拥有。
final class AppReadAloudSettingsRepository
    implements ReadAloudSettingsRepository {
  AppReadAloudSettingsRepository(this._service);

  final AppSettingsService _service;
  Future<ReadAloudSettings>? _loading;
  bool _initialized = false;
  bool _legacyCleanupPending = false;

  static const _splitMode = (
    storage: SettingsStorageKind.rustConfig,
    key: 'contentSplitMode',
  );
  static const _splitSymbols = (
    storage: SettingsStorageKind.rustConfig,
    key: 'contentSplitSymbols',
  );

  static const _follow = (
    storage: SettingsStorageKind.rustConfig,
    key: 'ttsFollowSys',
  );
  static const _rate = (
    storage: SettingsStorageKind.rustConfig,
    key: 'ttsSpeechRate',
  );
  static const _interval = (
    storage: SettingsStorageKind.rustConfig,
    key: 'ttsParagraphInterval',
  );
  static const _detach = (
    storage: SettingsStorageKind.rustConfig,
    key: 'readAloudDetachReminderEnabled',
  );
  static const _mediaButtons = (
    storage: SettingsStorageKind.rustConfig,
    key: 'mediaButtonPerNext',
  );
  static const _preDownload = (
    storage: SettingsStorageKind.rustConfig,
    key: 'audioPreDownloadNum',
  );
  static const _concurrency = (
    storage: SettingsStorageKind.rustConfig,
    key: 'ttsPreSynthesisConcurrency',
  );
  static const _cleanTime = (
    storage: SettingsStorageKind.rustConfig,
    key: 'audioCacheCleanTime',
  );
  static const _legacyFollow = (
    storage: SettingsStorageKind.preferences,
    key: 'read_aloud_follow_system_speed',
  );

  static const _addresses = {
    _splitMode,
    _splitSymbols,
    _follow,
    _rate,
    _interval,
    _detach,
    _mediaButtons,
    _preDownload,
    _concurrency,
    _cleanTime,
  };

  ReadAloudSettings _decode(AppSettingsSnapshot snapshot) {
    final follow = snapshot[_follow] as String?;
    final rawRate = snapshot[_rate] as String?;
    final rate = int.tryParse(rawRate ?? '') ?? 5;
    final rawSymbols = snapshot[_splitSymbols] as String?;
    final decoded = rawSymbols == null ? null : jsonDecode(rawSymbols);
    final symbols = decoded is List
        ? decoded
              .whereType<String>()
              .where(readAloudSplitSymbols.contains)
              .join()
        : '';
    return ReadAloudSettings(
      splitMode:
          ReadAloudSplitMode.values
              .where((m) => m.name == snapshot[_splitMode])
              .firstOrNull ??
          ReadAloudSplitMode.paragraph,
      splitSymbols: symbols.isEmpty ? defaultReadAloudSplitSymbols : symbols,
      followSystem:
          follow == null || follow.isEmpty || follow == 'true' || follow == '1',
      detachReminder: snapshot[_detach] != 'false' && snapshot[_detach] != '0',
      mediaButtonPerNext:
          snapshot[_mediaButtons] != 'false' && snapshot[_mediaButtons] != '0',
      manualSpeed: ((rate + 5) / 10).clamp(0.5, 3),
      paragraphIntervalMs:
          (int.tryParse(snapshot[_interval] as String? ?? '') ?? 0).clamp(
            0,
            5000,
          ),
      audioPreDownloadNum:
          (int.tryParse(snapshot[_preDownload] as String? ?? '') ?? 10).clamp(
            0,
            100,
          ),
      ttsPreSynthesisConcurrency:
          (int.tryParse(snapshot[_concurrency] as String? ?? '') ?? 3).clamp(
            1,
            8,
          ),
      audioCacheCleanTime:
          (int.tryParse(snapshot[_cleanTime] as String? ?? '') ?? 10).clamp(
            0,
            1440,
          ),
      hasStoredManualSpeed: rawRate != null && rawRate.isNotEmpty,
    );
  }

  Map<SettingsAddress, Object?> _encode(ReadAloudSettings settings) => {
    _splitMode: settings.splitMode.name,
    _splitSymbols: jsonEncode(
      settings.splitSymbols.split('').toSet().toList()..sort(),
    ),
    // 同时切入手动倍率时先保存数值，避免后续写失败却已关闭跟随模式。
    _rate: (settings.manualSpeed * 10 - 5).round().toString(),
    _follow: settings.followSystem ? 'true' : 'false',
    _interval: settings.paragraphIntervalMs.toString(),
    _detach: settings.detachReminder ? 'true' : 'false',
    _mediaButtons: settings.mediaButtonPerNext ? 'true' : 'false',
    _preDownload: settings.audioPreDownloadNum.toString(),
    _concurrency: settings.ttsPreSynthesisConcurrency.toString(),
    _cleanTime: settings.audioCacheCleanTime.toString(),
  };

  @override
  ReadAloudSettings get current => _decode(_service.current);

  @override
  Stream<ReadAloudSettings> watch() => _service.watch().map(_decode).distinct();

  @override
  Future<ReadAloudSettings> load() {
    if (_initialized) return Future.value(current);
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<ReadAloudSettings> _load() async {
    await _service.load(_addresses);
    await _migrateLegacyFollowSetting();
    _initialized = true;
    return current;
  }

  Future<void> _migrateLegacyFollowSetting({bool reloadLegacy = false}) async {
    final follow = _service.current[_follow] as String?;
    // 已有配置优先；清理失败时只重试本次迁移留下的旧键。
    if (follow != null && follow.isNotEmpty && !_legacyCleanupPending) return;
    if (reloadLegacy) {
      await _service.reload({_legacyFollow});
    } else {
      await _service.load({_legacyFollow});
    }
    final legacy = _service.current[_legacyFollow] as bool?;
    if (legacy == null) {
      _legacyCleanupPending = false;
      return;
    }
    _legacyCleanupPending = true;
    final values = <SettingsAddress, Object?>{};
    if (follow == null || follow.isEmpty) {
      values[_follow] = legacy ? 'true' : 'false';
    }
    values[_legacyFollow] = null;
    await _service.update(values);
    _legacyCleanupPending = false;
  }

  @override
  Future<void> update(
    ReadAloudSettings Function(ReadAloudSettings) transform,
  ) async {
    await load();
    final previous = current;
    final requested = transform(previous);
    if (!requested.manualSpeed.isFinite) {
      throw ArgumentError('朗读语速必须是有限数值');
    }
    final rate = (requested.manualSpeed.clamp(0.5, 3) * 10 - 5).round();
    final next = requested.copyWith(
      manualSpeed: (rate + 5) / 10,
      paragraphIntervalMs: requested.paragraphIntervalMs.clamp(0, 5000),
      audioPreDownloadNum: requested.audioPreDownloadNum.clamp(0, 100),
      ttsPreSynthesisConcurrency: requested.ttsPreSynthesisConcurrency.clamp(
        1,
        8,
      ),
      audioCacheCleanTime: requested.audioCacheCleanTime.clamp(0, 1440),
    );
    final before = _encode(previous);
    final after = _encode(next);
    await _service.update({
      for (final entry in after.entries)
        if (before[entry.key] != entry.value ||
            (entry.key == _rate &&
                !previous.hasStoredManualSpeed &&
                next.hasStoredManualSpeed))
          entry.key: entry.value,
    });
  }

  @override
  Future<void> reload() async {
    await load();
    await _service.reload(_addresses);
    await _migrateLegacyFollowSetting(reloadLegacy: true);
  }

  @override
  Future<void> settled() => _service.settled();
}
