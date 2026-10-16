import '../domain_config_provider.dart';
import '../dictionary_provider.dart';
import '../replace_rule_repository_provider.dart';
import '../rss_repository_provider.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../bridge/ffi.dart';
import '../../models/book_source.dart';
import '../../models/misc.dart';
import '../../models/rss_source.dart';
import '../../services/book_api.dart';
import '../../features/read_aloud/http_tts_repository_provider.dart';
import '../network_provider.dart';
import '../../app/bootstrap/source_import_factory.dart';
import '../../data/services/source_import_service.dart';
import '../../domain/models/import_result.dart';
import '../providers.dart';
import '../reader/reader_settings_provider.dart';
import 'association_state.dart';

export 'association_state.dart';

/// 关联导入 Riverpod Notifier
///
/// 对齐原版 BaseAssociationViewModel.importJson 流程：
/// - 加载内容（URL / 文件 / 剪贴板）→ JSON 解析 → 类型自动识别
/// - 拉取本地快照，逐条计算新/更新/已存在状态
/// - 确认导入按类型走对应仓储；TXT规则配置沿用现有合并。
class AssociationNotifier extends Notifier<AssociationState> {
  @override
  AssociationState build() => const AssociationState();

  BookApi get _api => ref.read(bookApiProvider);

  /// 书源导入服务（逐条校验 + FFI 批量导入）
  SourceImportService get importService => createSourceImportService(_api);

  // ===== 加载阶段（对应原版各 ImportXxxViewModel.importSource）=====

  /// 深链 / 扫码预填：设置 URL，有内容时自动拉取并解析
  Future<void> bootstrapFromDeepLink({
    ImportType? type,
    required String srcUrl,
  }) async {
    state = state.copyWith(
      urlInput: srcUrl,
      items: [],
      error: null,
      lastResult: null,
    );
    if (srcUrl.isNotEmpty) {
      await loadFromUrl(srcUrl, typeHint: type);
    }
  }

  /// 从 URL 加载（对应原版 importSource → httpGet）
  Future<void> loadFromUrl(String url, {ImportType? typeHint}) async {
    state = state.copyWith(isLoading: true, error: null, items: []);
    try {
      final response = await ref
          .read(networkServiceProvider)
          .httpGet(url, timeout: const Duration(seconds: 30));
      if (!response.isSuccess) {
        state = state.copyWith(
          error: 'HTTP 请求失败：状态码 ${response.statusCode}',
          isLoading: false,
        );
        return;
      }
      await _parseAndSet(response.body, typeHint);
    } catch (e) {
      final msg = e is BridgeError ? e.message : '$e';
      state = state.copyWith(error: '从 URL 加载失败：$msg', isLoading: false);
    }
  }

  /// 从文件加载
  Future<void> loadFromFile(String path, {ImportType? typeHint}) async {
    state = state.copyWith(isLoading: true, error: null, items: []);
    try {
      final file = File(path);
      if (!await file.exists()) {
        state = state.copyWith(error: '文件不存在：$path', isLoading: false);
        return;
      }
      final content = await file.readAsString(encoding: utf8);
      await _parseAndSet(content, typeHint);
    } catch (e) {
      final msg = e is BridgeError ? e.message : '$e';
      state = state.copyWith(error: '读取文件失败：$msg', isLoading: false);
    }
  }

  /// 从剪贴板加载（内容为 URL 时按 URL 拉取，否则直接解析）
  Future<void> loadFromClipboard({ImportType? typeHint}) async {
    state = state.copyWith(isLoading: true, error: null, items: []);
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text == null || text.trim().isEmpty) {
        state = state.copyWith(error: '剪贴板为空', isLoading: false);
        return;
      }
      final trimmed = text.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        state = state.copyWith(urlInput: trimmed);
        await loadFromUrl(trimmed, typeHint: typeHint);
        return;
      }
      await _parseAndSet(trimmed, typeHint);
    } catch (e) {
      final msg = e is BridgeError ? e.message : '$e';
      state = state.copyWith(error: '读取剪贴板失败：$msg', isLoading: false);
    }
  }

  /// 解析内容：JSON 解码 → 类型自动识别（原版 importJson 字段规则）→ 本地快照 → 条目列表
  Future<void> _parseAndSet(String content, ImportType? hint) async {
    final List<Map<String, dynamic>> maps;
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        maps = [
          for (final e in decoded)
            if (e is Map<String, dynamic>) Map<String, dynamic>.of(e),
        ];
      } else if (decoded is Map) {
        maps = [Map<String, dynamic>.from(decoded)];
      } else {
        state = state.copyWith(error: '格式错误：期望 JSON 数组或对象', isLoading: false);
        return;
      }
    } on FormatException catch (e) {
      state = state.copyWith(error: 'JSON 解析错误：${e.message}', isLoading: false);
      return;
    }

    if (maps.isEmpty) {
      // 对应原版 successLiveData(0) → wrong_format
      state = state.copyWith(
        error: '格式错误，未解析到有效条目',
        items: [],
        isLoading: false,
      );
      return;
    }

    final type = hint ?? _detectType(maps.first);
    if (type == null) {
      // 对应原版「格式不对」
      state = state.copyWith(error: '格式不对', isLoading: false);
      return;
    }

    // 本地快照用于新/更新判定；获取失败按空处理（不阻塞导入）
    final locals = await _fetchLocals(type);

    final items = [
      for (final m in maps)
        AssociationItem(
          raw: m,
          name: type.nameFieldOf(m),
          group: type.groupFieldOf(m),
          comment: type.commentFieldOf(m),
          lastUpdateTime: type.lastUpdateTimeFieldOf(m) ?? 0,
          status: _statusOf(type, m, locals),
        ),
    ];

    state = state.copyWith(
      type: type,
      items: items,
      isLoading: false,
      error: null,
    );
  }

  /// 自动识别导入类型（对应原版 BaseAssociationViewModel.importJson 的字段规则）
  static ImportType? _detectType(Map<String, dynamic> map) {
    if (map.containsKey('bookSourceUrl')) return ImportType.bookSource;
    if (map.containsKey('sourceUrl')) return ImportType.rssSource;
    if (map.containsKey('pattern')) return ImportType.replaceRule;
    if (map.containsKey('themeName')) return ImportType.theme;
    if (map.containsKey('showRule')) return ImportType.dictRule;
    if (map.containsKey('name') && map.containsKey('rule')) {
      return ImportType.txtTocRule;
    }
    if (map.containsKey('name') && map.containsKey('url')) {
      return ImportType.httpTts;
    }
    return null;
  }

  /// 拉取本地快照（按类型返回键值映射或列表；失败返回 null）
  Future<Object?> _fetchLocals(ImportType type) async {
    try {
      switch (type) {
        case ImportType.bookSource:
          final map = <String, BookSource>{};
          for (final s in await _api.bookSourceRepository.getBookSources()) {
            map[s.bookSourceUrl] = s;
          }
          return map;
        case ImportType.rssSource:
          final map = <String, RssSource>{};
          for (final s
              in await ref.read(rssSourceRepositoryProvider).getRssSources()) {
            map[s.sourceUrl] = s;
          }
          return map;
        case ImportType.replaceRule:
          final map = <String, ReplaceRule>{};
          for (final r
              in await ref
                  .read(replaceRuleRepositoryProvider)
                  .getReplaceRules()) {
            map[r.name] = r;
          }
          return map;
        case ImportType.httpTts:
          final map = <String, HttpTts>{};
          for (final t
              in await ref.read(httpTtsRepositoryProvider).getHttpTts()) {
            map[t.name] = t;
          }
          return map;
        case ImportType.dictRule:
          return (await ref.read(dictRuleRepositoryProvider).dictRuleList())
              .map((rule) => rule.toJson())
              .toList();
        case ImportType.txtTocRule:
          return (await ref.read(txtTocRuleRepositoryProvider).getRules())
              .map((r) => r.toJson())
              .toList();
        case ImportType.theme:
          // Flutter 端无具名主题仓库，状态按 none 处理（默认全选）
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// 逐条计算状态（对应原版各对话框 tvSourceState 规则）
  ImportItemStatus _statusOf(
    ImportType type,
    Map<String, dynamic> item,
    Object? locals,
  ) {
    switch (type) {
      case ImportType.bookSource:
        // 按 URL 匹配；lastUpdateTime 更新 → 更新
        final url = item['bookSourceUrl']?.toString() ?? '';
        final local = (locals as Map<String, BookSource>?)?[url];
        if (local == null) return ImportItemStatus.isNew;
        final lu = type.lastUpdateTimeFieldOf(item);
        return ((lu ?? 0) > local.lastUpdateTime)
            ? ImportItemStatus.isUpdate
            : ImportItemStatus.exists;

      case ImportType.rssSource:
        // 按 URL 匹配；lastUpdateTime 更新 → 更新
        final url = item['sourceUrl']?.toString() ?? '';
        final local = (locals as Map<String, RssSource>?)?[url];
        if (local == null) return ImportItemStatus.isNew;
        final lu = type.lastUpdateTimeFieldOf(item);
        return ((lu ?? 0) > local.lastUpdateTime)
            ? ImportItemStatus.isUpdate
            : ImportItemStatus.exists;

      case ImportType.replaceRule:
        // 按名称匹配；pattern/replacement/isRegex/scope 任一不同 → 更新
        final name = item['name']?.toString() ?? '';
        final local = (locals as Map<String, ReplaceRule>?)?[name];
        if (local == null) return ImportItemStatus.isNew;
        bool eq(v, String localValue) => (v?.toString() ?? '') == localValue;
        return !eq(item['pattern'], local.pattern) ||
                !eq(item['replacement'], local.replacement) ||
                !eq(item['isRegex'], _boolStr(local.isRegex)) ||
                !eq(item['scope'], local.scope ?? '')
            ? ImportItemStatus.isUpdate
            : ImportItemStatus.exists;

      case ImportType.theme:
        // 无本地快照 → none（默认全选）
        return ImportItemStatus.none;

      case ImportType.httpTts:
        // 按名称匹配；lastUpdateTime 更新 → 更新
        final name = item['name']?.toString() ?? '';
        final local = (locals as Map<String, HttpTts>?)?[name];
        if (local == null) return ImportItemStatus.isNew;
        final lu = type.lastUpdateTimeFieldOf(item);
        return ((lu ?? 0) > local.lastUpdateTime)
            ? ImportItemStatus.isUpdate
            : ImportItemStatus.exists;

      case ImportType.dictRule:
        // 仅新/已存在（无更新概念）
        final name = item['name']?.toString() ?? '';
        final exists =
            (locals as List<Map<String, dynamic>>?)?.any(
              (e) => e['name'] == name,
            ) ??
            false;
        return exists ? ImportItemStatus.exists : ImportItemStatus.isNew;

      case ImportType.txtTocRule:
        // 按名称匹配；rule/replacement/example 任一不同 → 更新
        final name = item['name']?.toString() ?? '';
        Map<String, dynamic>? local;
        final list = locals as List<Map<String, dynamic>>?;
        if (list != null) {
          for (final e in list) {
            if (e['name'] == name) {
              local = e;
              break;
            }
          }
        }
        if (local == null) return ImportItemStatus.isNew;
        String v(dynamic x) => x?.toString() ?? '';
        return v(item['rule']) != v(local['rule']) ||
                v(item['replacement']) != v(local['replacement']) ||
                v(item['example']) != v(local['example'])
            ? ImportItemStatus.isUpdate
            : ImportItemStatus.exists;
    }
  }

  static String _boolStr(bool b) => b.toString();

  /// 结果汇总单位名（按类型区分，避免规则类导入显示「书源」）
  static String _unitName(ImportType type) => switch (type) {
    ImportType.bookSource => '书源',
    ImportType.rssSource => 'RSS 源',
    ImportType.replaceRule => '替换规则',
    ImportType.theme => '主题配置',
    ImportType.httpTts => 'HTTP TTS',
    ImportType.dictRule => '字典规则',
    ImportType.txtTocRule => 'TXT 目录规则',
  };

  // ===== 导入阶段（对应原版各 importSelect）=====

  /// 确认导入：[items] 为勾选行的原始 JSON（书源/替换规则的覆盖项由 UI 层先行应用）
  Future<ImportResult> confirmImport(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = switch (type) {
        ImportType.bookSource => await importService.importFromJson(
          jsonEncode(items),
        ),
        ImportType.rssSource => await _importRss(type, items),
        ImportType.replaceRule => await _importReplaceRules(type, items),
        ImportType.theme => await _importTheme(type, items),
        ImportType.httpTts => await _importHttpTts(type, items),
        ImportType.dictRule => await _importDictRules(type, items),
        ImportType.txtTocRule => await _importTxtTocRules(type, items),
      };
      state = state.copyWith(lastResult: result, isLoading: false);
      return result;
    } catch (e) {
      final msg = e is BridgeError ? e.message : '$e';
      state = state.copyWith(isLoading: false, error: msg);
      return ImportResult(
        total: items.length,
        success: 0,
        failed: items.length,
        skipped: 0,
        errors: [msg],
        unit: _unitName(type),
      );
    }
  }

  /// 导入 RSS 源（FFI importRssSources 批量）
  Future<ImportResult> _importRss(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    final n = await ref
        .read(rssSourceRepositoryProvider)
        .importRssSources(jsonEncode(items));
    return ImportResult(
      total: items.length,
      success: n.clamp(0, items.length),
      failed: items.length - n.clamp(0, items.length),
      skipped: 0,
      errors: const [],
      unit: _unitName(type),
    );
  }

  /// 导入替换规则（按名称 upsert，对应原版 importSelect）
  Future<ImportResult> _importReplaceRules(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    final locals = <String, ReplaceRule>{};
    try {
      for (final r
          in await ref.read(replaceRuleRepositoryProvider).getReplaceRules()) {
        locals[r.name] = r;
      }
    } catch (_) {}
    var success = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        final rule = ReplaceRule.fromJson(item);
        if (rule.name.isEmpty) throw Exception('缺少名称');
        final local = locals[rule.name];
        if (local == null) {
          await ref.read(replaceRuleRepositoryProvider).addReplaceRule(rule);
        } else {
          await ref
              .read(replaceRuleRepositoryProvider)
              .updateReplaceRule(rule.copyWith(id: local.id));
        }
        success++;
      } catch (e) {
        errors.add('导入替换规则「${item['name']}」失败：$e');
      }
    }
    return ImportResult(
      total: items.length,
      success: success,
      failed: errors.length,
      skipped: 0,
      errors: errors,
      unit: _unitName(type),
    );
  }

  /// 导入主题配置（写入 SharedPreferences，沿用既有映射）
  Future<ImportResult> _importTheme(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    var success = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (item.containsKey('themeMode')) {
          await prefs.setString(
            'app_theme_mode',
            item['themeMode']?.toString() ?? 'system',
          );
        }
        if (item.containsKey('fontSize')) {
          final size = (item['fontSize'] as num?)?.toDouble();
          if (size != null && size > 0) {
            await ref
                .read(readerSettingsRepositoryProvider)
                .update(fontSize: size);
          }
        }
        if (item.containsKey('lineHeight')) {
          final height = (item['lineHeight'] as num?)?.toDouble();
          if (height != null && height > 0) {
            await ref
                .read(readerSettingsRepositoryProvider)
                .update(lineHeight: height);
          }
        }
        if (item.containsKey('bgColorIndex')) {
          final index = (item['bgColorIndex'] as num?)?.toInt();
          if (index != null && index >= 0) {
            await prefs.setInt('reader_bg_color_index', index);
          }
        }
        if (item.containsKey('brightness')) {
          final brightness = (item['brightness'] as num?)?.toDouble();
          if (brightness != null) {
            await prefs.setDouble('reader_brightness', brightness);
          }
        }
        success++;
      } catch (e) {
        errors.add('导入主题配置失败：$e');
      }
    }
    return ImportResult(
      total: items.length,
      success: success,
      failed: errors.length,
      skipped: 0,
      errors: errors,
      unit: _unitName(type),
    );
  }

  /// 导入 HTTP TTS（FFI importHttpTts 批量）
  Future<ImportResult> _importHttpTts(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    final n = await ref
        .read(httpTtsRepositoryProvider)
        .importHttpTts(jsonEncode(items));
    return ImportResult(
      total: items.length,
      success: n.clamp(0, items.length),
      failed: items.length - n.clamp(0, items.length),
      skipped: 0,
      errors: const [],
      unit: _unitName(type),
    );
  }

  /// 通过同一仓储按名称导入，查询与管理可立即重新读取。
  Future<ImportResult> _importDictRules(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    var success = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        final rule = DictRule.fromJson(item);
        if (rule.name.isEmpty) throw Exception('缺少名称');
        success += await ref
            .read(dictRuleRepositoryProvider)
            .dictRuleImport(jsonOrUrl: jsonEncode(rule.toJson()), kind: 'text');
      } catch (e) {
        errors.add('导入字典规则「${item['name']}」失败：$e');
      }
    }
    return ImportResult(
      total: items.length,
      success: success,
      failed: errors.length,
      skipped: 0,
      errors: errors,
      unit: _unitName(type),
    );
  }

  /// 导入 TXT 目录规则（按名称 upsert 合并写入配置键 txt_toc_rules）
  Future<ImportResult> _importTxtTocRules(
    ImportType type,
    List<Map<String, dynamic>> items,
  ) async {
    final repository = ref.read(txtTocRuleRepositoryProvider);
    final existing = (await repository.getRules())
        .map((r) => r.toJson())
        .toList();
    var nextId = existing.fold<int>(
      0,
      (m, e) =>
          ((e['id'] as num?)?.toInt() ?? 0) > m ? (e['id'] as num).toInt() : m,
    );
    var success = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        var rule = TxtTocRule.fromJson(item);
        if (rule.name.isEmpty || rule.rule.isEmpty) {
          throw Exception('缺少名称或正则');
        }
        final idx = existing.indexWhere((e) => e['name'] == rule.name);
        if (idx >= 0) {
          rule = rule.copyWith(id: (existing[idx]['id'] as num?)?.toInt() ?? 1);
          existing[idx] = rule.toJson(); // 同名覆盖（对应原版 importSelect）
        } else {
          if (rule.id <= 0) nextId++;
          rule = rule.copyWith(
            id: rule.id > 0 ? rule.id : nextId++,
            serialNumber: existing.length,
          );
          existing.add(rule.toJson());
        }
        success++;
      } catch (e) {
        errors.add('导入 TXT 规则「${item['name']}」失败：$e');
      }
    }
    await repository.saveRules(existing.map(TxtTocRule.fromJson).toList());
    return ImportResult(
      total: items.length,
      success: success,
      failed: errors.length,
      skipped: 0,
      errors: errors,
      unit: _unitName(type),
    );
  }

  // ===== 其他操作 =====

  /// 设置 URL 输入
  void setUrlInput(String url) {
    state = state.copyWith(urlInput: url);
  }

  /// 重置到初始状态
  void reset() {
    state = const AssociationState();
  }
}

/// 关联导入 Notifier 全局 Provider
final associationNotifierProvider =
    NotifierProvider<AssociationNotifier, AssociationState>(
      AssociationNotifier.new,
    );
