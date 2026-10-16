import 'package:flutter/foundation.dart';

import '../../../domain/contracts/http_tts_repository.dart';
import '../../../domain/contracts/cloud_tts_repository.dart' show isCloudTts;
import '../../../domain/contracts/read_aloud_selection_repository.dart';
import '../../../domain/contracts/read_aloud_voice_repository.dart';
import '../../../models/book.dart';
import '../../../platform/tts/system_tts.dart';
import '../../audio/services/audio_preferences_host.dart';
import '../../audio/services/audio_book_preferences_service.dart';
import '../http_tts_seed.dart';
import '../http_tts_voice_selection.dart';

/// 朗读引擎 URL 归一：把历史「名称,URL」复合形态还原为裸 URL 模板
///
/// [P0 | 2026-10-03] 朗读条引擎选择器曾把 `'名称,URL'` 复合串写入
/// TtsConfig.engineUrl（read_aloud_bar.dart），而 Rust `tts_speak` 把该值
/// 原样当 URL 模板与缓存键（rust/legado-ffi/src/api/tts_speak_api.rs:57-59），
/// 请求以「名称」开头必然失败 → 选完引擎合成仍报错、朗读落降级提示。
/// 选择器已改为只存裸 URL；本函数是消费端（HTTP 合成前）的向后兼容兜底，
/// 兼容同一进程内残留的旧形态状态。
///
/// 归一策略（测试钉死）：
/// - 整串已以 `http://`/`https://` 开头 → 原样返回（URL 自身含逗号也不拆）；
/// - 否则取「首个其后紧跟 http(s):// 的逗号」之后的部分——名称本身含逗号
///   （`甲,乙,http://…`）时仍能定位真正的 URL 起点；
/// - 逗号后不是 http(s) 开头（如原版 POST 模板 `url,{json}`）→ 原样返回，
///   不做猜测性截断，交由合成管线报错。
///
/// 不采用「首个逗号硬拆」：名称可能含逗号，硬拆会把名称残段混进 URL。
String normalizeTtsEngineUrl(String engineUrl) {
  final trimmed = engineUrl.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  var index = trimmed.indexOf(',');
  while (index >= 0) {
    final rest = trimmed.substring(index + 1).trim();
    if (rest.startsWith('http://') || rest.startsWith('https://')) {
      return rest;
    }
    index = trimmed.indexOf(',', index + 1);
  }
  return trimmed;
}

/// 全局朗读引擎持久化键
///
/// 对齐原版 `PreferKey.ttsEngine = "appTtsEngine"`（app/.../constant/PreferKey.kt:46
/// → `AppConfig.ttsEngine`，app/.../help/config/AppConfig.kt:506-509）：原版
/// 「全局」按钮把所选引擎写入该键，「书」按钮只写书级 `readConfig.ttsEngine`。
/// 本项目全局值经既有 config 存储（ConfigRepository）持久化，书级值经
/// `Book.copyWith(readConfig:)` 经书架仓储落 `books.readConfig` 列。
/// [引擎双持久化 | 2026-10-04]
const String kTtsEngineConfigKey = 'appTtsEngine';

/// 全局稳定 HTTP TTS 引擎 ID 持久化键
const String kTtsEngineIdConfigKey = 'appTtsEngineId';

/// 引擎解析与选择保存；不持有第二份播放或书籍配置。— Codex + UI
final class ReadAloudSelectionService {
  ReadAloudSelectionService({
    required this._host,
    required this._preferences,
    required this._httpTts,
    required this._selections,
  });
  final AudioPreferencesHost _host;
  final AudioBookPreferencesService _preferences;
  final HttpTtsRepository _httpTts;
  final ReadAloudSelectionRepository _selections;
  bool get _disposed => _host.isDisposed();

  Future<Book?> _currentBook() async {
    await _preferences.bindBook(_preferences.currentBookUrl);
    if (_disposed) return null;
    return _preferences.boundBook;
  }

  Future<void> ensureDefaultEngine() async {
    final token = _host.currentToken();
    try {
      // [D3 | 2026-10-03] 首启/升级导入原版 httpTTS 种子（版本门控；
      // 失败不阻塞，仍按无引擎降级估算）。
      final engines = _httpTts;
      await ensureDefaultHttpTts(engines);
      final list = await engines.getHttpTts();
      if (_disposed || token != _host.currentToken()) return;
      if (list.isEmpty) return;
      // 规则语法能力已接入 POST/JS；远程可用性由合成响应和登录状态判断。
      final compatible = list.where((e) => isCompatibleHttpTtsEngineUrl(e.url));
      if (compatible.isEmpty) return;
      final defaultEngine = compatible.first;
      final url = defaultEngine.url.trim();
      if (url.isNotEmpty) {
        _host.updateConfig(engineUrl: url, engineId: defaultEngine.id);
      }
    } catch (e) {
      debugPrint('获取默认朗读引擎失败: $e');
    }
  }

  // ===== 朗读引擎双持久化（书级 / 全局）=====
  //
  // 对齐原版 SpeakEngineDialog（app/.../ui/book/read/config/SpeakEngineDialog.kt）：
  // - 解析：书级 `Book.getTtsEngine()` 优先、空则全局 `AppConfig.ttsEngine`
  //   （ReadAloud.kt:41 → AppConfig.kt:506-509）；
  // - 「书」按钮:164-170 = 只写书级（`ReadBook.book?.setTtsEngine(ttsEngine)`），
  //   不改全局；
  // - 「全局」按钮:171-177 = 先清书级（`setTtsEngine(null)`）再写全局；
  // - 行点击:315-326 = 仅对话框内选中态（upTts），不持久化。

  /// 当前生效朗读引擎 URL：书级优先、空则全局回退（**单点解析**）
  ///
  /// 书级值取当前绑定书籍的 `readConfig.ttsEngine`（原版 Book.setTtsEngine，
  /// Book.kt:267-272 / 字段 :501）；全局值取 [AudioState.config] 的 engineUrl
  /// （用户经朗读条/管理页选择，见 [setGlobalTtsEngine]）。两个来源都经
  /// [normalizeTtsEngineUrl] 归一，历史「名称,URL」形态不会破坏解析。
  /// 播放链与默认引擎判定共用此处，不重复判断层级。
  String resolveTtsEngineUrl() {
    final bookLevel = normalizeTtsEngineUrl(
      _preferences.boundBook?.readConfig?.ttsEngine ?? '',
    );
    if (bookLevel.isNotEmpty) return bookLevel;
    return normalizeTtsEngineUrl(_host.readState().config.engineUrl);
  }

  /// 解析当前生效的 HTTP TTS 引擎 ID（数值标识稳定，支持合法非零负数）
  Future<int?> resolveTtsEngineId() async {
    final engineUrl = resolveTtsEngineUrl();
    if (engineUrl.isEmpty ||
        engineUrl == systemTtsEngineUrl ||
        isCloudTts(engineUrl)) {
      return null;
    }
    // 1. 如果 URL 是纯数字 ID（兼容存 ID 场景）
    final parsedId = int.tryParse(engineUrl);
    if (parsedId != null && parsedId != 0) {
      try {
        final repo = _httpTts;
        final list = await repo.getHttpTts();
        if (list.any((item) => item.id == parsedId)) {
          return parsedId;
        }
      } catch (e) {
        debugPrint('resolveTtsEngineId 校验 ID 失败: $e');
      }
      debugPrint('resolveTtsEngineId: 未在仓库中找到 ID 为 $parsedId 的引擎');
      return null;
    }
    // 2. 如果 config 中已显式配置合法 engineId，且匹配当前生效引擎 URL
    if (_host.readState().config.engineId != null &&
        _host.readState().config.engineId != 0 &&
        (normalizeTtsEngineUrl(_host.readState().config.engineUrl) ==
                engineUrl ||
            _host.readState().config.engineUrl == engineUrl ||
            engineUrl.isEmpty)) {
      return _host.readState().config.engineId;
    }
    // 3. 从 HTTP TTS 仓库匹配 URL 获取 ID
    try {
      final repo = _httpTts;
      final list = await repo.getHttpTts();
      final normalized = normalizeTtsEngineUrl(engineUrl);
      for (final item in list) {
        if (item.id != 0 &&
            (normalizeTtsEngineUrl(item.url) == normalized ||
                item.url == engineUrl)) {
          return item.id;
        }
      }
    } catch (e) {
      debugPrint('resolveTtsEngineId 查找引擎失败: $e');
    }
    debugPrint('resolveTtsEngineId: 未在仓库中找到匹配引擎 (url: $engineUrl)');
    return null;
  }

  /// 是否存在可写书级的当前书（UI「书」按钮可用性判定）
  bool get hasCurrentBook => _preferences.currentBookUrl.isNotEmpty;

  /// 书级引擎写入（对齐原版「书」按钮，SpeakEngineDialog.kt:164-170）
  ///
  /// 只写当前书的 `readConfig.ttsEngine`，不改全局值；写库复用既有
  /// 偏好服务的字段合并链路，Rust 侧 `update_book` 全行
  /// 回写 readConfig 列（rust/legado-ffi/src/api/bookshelf.rs:68，
  /// rust/legado-db/.../book_repository.rs update）。无当前书返回 false
  /// （对齐原版 `ReadBook.book?.` 空安全语义，不静默假装成功）。
  Future<bool> setBookTtsEngine(String engineUrl, {int? engineId}) async {
    final url = normalizeTtsEngineUrl(engineUrl);
    if (url.isEmpty && (engineId == null || engineId == 0)) return false;
    final book = await _currentBook();
    if (book == null) return false;
    try {
      final selection = engineId != null && engineId != 0
          ? engineId.toString()
          : url;
      final updated = await _preferences.updateReadConfig(
        book.bookUrl,
        (config) => config.copyWith(ttsEngine: selection),
        fallback: book,
      );
      if (updated == null || _disposed) return false;
      if (_preferences.currentBookUrl == book.bookUrl) {
        await _host.restartReadAloud();
      }
      return true;
    } catch (e) {
      debugPrint('保存书级朗读引擎失败: $e');
      return false;
    }
  }

  /// 清书级引擎（对齐原版「全局」按钮的 `ReadBook.book?.setTtsEngine(null)`）
  ///
  /// 书级值本就为空时跳过写库（避免无意义 IO）；无当前书时静默跳过。
  Future<void> clearBookTtsEngine() async {
    final book = await _currentBook();
    if (book == null) return;
    if ((book.readConfig?.ttsEngine ?? '').isEmpty) return;
    try {
      await _preferences.updateReadConfig(
        book.bookUrl,
        (config) => config.copyWith(ttsEngine: null),
        fallback: book,
      );
    } catch (e) {
      debugPrint('清除书级朗读引擎失败: $e');
    }
  }

  /// 全局引擎写入（对齐原版「全局」按钮，SpeakEngineDialog.kt:171-177）
  ///
  /// 同步策略照原版：先清当前书书级覆盖，再把所选引擎写全局。全局值双写——
  /// 内存 [AudioState.config].engineUrl（既有消费路径不变）+ config 存储
  /// [kTtsEngineConfigKey] 与稳定 [kTtsEngineIdConfigKey]（重启后由
  /// [restoreGlobalEngine] 读回，对齐原版 AppConfig.ttsEngine 持久化语义）。
  Future<void> setGlobalTtsEngine(String engineUrl, {int? engineId}) async {
    final url = normalizeTtsEngineUrl(engineUrl);
    if (url.isEmpty && (engineId == null || engineId == 0)) return;
    await clearBookTtsEngine();
    if (_disposed) return;
    _host.updateConfig(
      engineUrl: url,
      engineId: engineId,
      restartPlayback: false,
    );
    try {
      await _selections.setEngine(url, httpEngineId: engineId);
    } catch (e) {
      debugPrint('持久化全局朗读引擎失败: $e');
    }
    if (!_disposed) await _host.restartReadAloud();
  }

  /// 有效引擎读回（管理页/朗读条对话框初始化选中态用）
  ///
  /// 顺序与 [resolveTtsEngineUrl] 一致；仅当书级与内存全局都为空时，才读回
  /// 持久化全局值（读到则同步应用到内存）。
  Future<String> loadEffectiveTtsEngineUrl() async {
    await _preferences.bindBook(_preferences.currentBookUrl);
    if (_disposed) return '';
    final resolved = resolveTtsEngineUrl();
    if (resolved.isNotEmpty) return resolved;
    return restoreGlobalEngine();
  }

  /// 读回持久化全局引擎并应用到内存（空/失败不改状态）
  Future<String> restoreGlobalEngine() async {
    final token = _host.currentToken();
    try {
      final parsedId = await _selections.getHttpEngineId();
      if (parsedId != null && parsedId != 0) {
        try {
          final repo = _httpTts;
          final list = await repo.getHttpTts();
          final matched = list.where((e) => e.id == parsedId).firstOrNull;
          if (matched != null) {
            if (_disposed || token != _host.currentToken()) return '';
            final url = normalizeTtsEngineUrl(matched.url);
            _host.updateConfig(
              engineUrl: url,
              engineId: matched.id,
              restartPlayback: false,
            );
            return url;
          }
        } catch (error) {
          debugPrint('读取已保存的朗读引擎失败，保留 ID：$error');
        }
        // 保留失效身份，让后续校验明确报错；不得按相同 URL 换成另一引擎。
        if (_disposed || token != _host.currentToken()) return '';
        _host.updateConfig(
          engineUrl: parsedId.toString(),
          engineId: parsedId,
          restartPlayback: false,
        );
        return parsedId.toString();
      }
      final raw = await _selections.getEngineUrl();
      if (_disposed || token != _host.currentToken()) return '';
      final url = normalizeTtsEngineUrl(raw ?? '');
      if (url.isEmpty) return '';
      _host.updateConfig(engineUrl: url, restartPlayback: false);
      return url;
    } catch (e) {
      debugPrint('读取持久化朗读引擎失败: $e');
      return '';
    }
  }

  Future<void> setCloudTtsVoice(String engineId, ReadAloudVoice? voice) async {
    if (voice != null &&
        (voice.engineType != 'cloud_tts' ||
            voice.engineId != engineId ||
            !voice.selectable)) {
      throw StateError('该音色不能用于此引擎');
    }
    await _selections.setCloudVoice(engineId, voice?.id);
    if (!_disposed && resolveTtsEngineUrl() == 'cloud://$engineId') {
      await _host.restartReadAloud();
    }
  }

  Future<void> setHttpTtsVoice(
    int id,
    ReadAloudVoice? voice, {
    String? emotionTag,
  }) async {
    if (voice != null &&
        (voice.engineType != 'http' ||
            voice.engineId != '$id' ||
            !voice.selectable)) {
      throw StateError('该音色不能用于此引擎');
    }
    if (voice != null) {
      final resolution = resolveHttpTtsVoice(id, [
        voice,
      ], HttpTtsVoiceSelection(voice.id, emotionTag: emotionTag));
      if (resolution.warning != null) throw StateError(resolution.warning!);
    }
    await _selections.setHttpVoice(
      id,
      voice == null
          ? null
          : HttpTtsVoiceSelection(voice.id, emotionTag: emotionTag),
    );
    if (_disposed ||
        _host.readState().isStreamMode ||
        resolveTtsEngineUrl() == systemTtsEngineUrl) {
      return;
    }
    final token = _host.currentToken();
    if (await resolveTtsEngineId() == id &&
        !_disposed &&
        token == _host.currentToken()) {
      await _host.restartReadAloud();
    }
  }
}
