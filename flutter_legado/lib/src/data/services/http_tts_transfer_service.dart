import 'dart:convert';

import '../../domain/contracts/http_tts_repository.dart';
import '../../domain/contracts/network_service.dart';
import '../../models/models.dart';

enum HttpTtsImportStatus { added, updated, existing }

/// 预览保留完整文档，目录字段不经配置模型截断。— Codex + Bridge
final class HttpTtsImportItem {
  HttpTtsImportItem(this.engine, Map<String, dynamic> raw, this.status)
    : raw = Map.unmodifiable(raw);
  final HttpTts engine;
  final Map<String, dynamic> raw;
  final HttpTtsImportStatus status;
  bool get selectedByDefault => status != HttpTtsImportStatus.existing;
}

/// 只编排文档解析、共享网络与仓库，不接触页面或播放会话。— Codex + Bridge
final class HttpTtsTransferService {
  const HttpTtsTransferService(this.repository, this.network);
  final HttpTtsRepository repository;
  final NetworkService network;

  Future<List<HttpTtsImportItem>> preview(String input) async {
    final document = await _resolve(input.trim(), <String>{});
    final decoded = jsonDecode(document);
    final List<dynamic> entries = switch (decoded) {
      List<dynamic> value => value,
      Map<String, dynamic> value => [value],
      _ => throw const FormatException('请选择 HTTP TTS JSON 对象或数组'),
    };
    if (entries.isEmpty) throw const FormatException('没有可导入的 HTTP TTS 引擎');
    final local = {for (final e in await repository.getHttpTts()) e.id: e};
    final ids = <int>{};
    return [
      for (var i = 0; i < entries.length; i++)
        _previewItem(entries[i], i, local, ids),
    ];
  }

  HttpTtsImportItem _previewItem(
    dynamic value,
    int index,
    Map<int, HttpTts> local,
    Set<int> ids,
  ) {
    try {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('不是 JSON 对象');
      }
      final engine = HttpTts.fromJson(value);
      if (engine.name.trim().isEmpty || engine.url.trim().isEmpty) {
        throw const FormatException('名称和 URL 不能为空');
      }
      if (engine.id != 0 && !ids.add(engine.id)) {
        throw FormatException('ID ${engine.id} 重复，请保留一条规则');
      }
      final previous = engine.id == 0 ? null : local[engine.id];
      final status = previous == null
          ? HttpTtsImportStatus.added
          : engine.lastUpdateTime > previous.lastUpdateTime
          ? HttpTtsImportStatus.updated
          : HttpTtsImportStatus.existing;
      return HttpTtsImportItem(engine, value, status);
    } catch (e) {
      throw FormatException('第 ${index + 1} 项无效：$e');
    }
  }

  Future<String> _resolve(String input, Set<String> seen) async {
    if (input.startsWith('{') || input.startsWith('[')) return input;
    if (seen.length >= 8 || !seen.add(input)) {
      throw const FormatException('导入链接循环或嵌套过深');
    }
    final uri = Uri.tryParse(input);
    if (uri == null) throw const FormatException('导入内容无效');
    if ({'legado', 'yuedu'}.contains(uri.scheme) &&
        uri.host == 'import' &&
        uri.path.toLowerCase() == '/httptts') {
      final source = uri.queryParameters['src'];
      if (source == null) throw const FormatException('导入链接缺少 src');
      return _resolve(source.trim(), seen);
    }
    if (uri.scheme == 'data') {
      return _resolve(UriData.fromUri(uri).contentAsString().trim(), seen);
    }
    if (!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('请输入 JSON 或 HTTP(S) 导入链接');
    }
    if (uri.fragment == 'requestWithoutUA') {
      final response = await network.httpGetBytes(
        uri.removeFragment().toString(),
        headers: {'User-Agent': 'null'},
      );
      if (!response.isSuccess) {
        throw FormatException('下载失败：HTTP ${response.statusCode}');
      }
      return _resolve(utf8.decode(response.bytes).trim(), seen);
    }
    final response = await network.httpGet(input);
    if (!response.isSuccess) {
      throw FormatException('下载失败：HTTP ${response.statusCode}');
    }
    return _resolve(response.body.trim(), seen);
  }

  Future<int> save(Iterable<HttpTtsImportItem> selected) async {
    final items = selected.toList(growable: false);
    if (items.isEmpty) return 0;
    return repository.importHttpTts(
      jsonEncode(items.map((e) => e.raw).toList()),
    );
  }

  Future<String> export({Set<int>? ids}) async {
    final entries = jsonDecode(await repository.exportHttpTts()) as List;
    final available = {for (final item in entries) (item as Map)['id']};
    if (ids != null && !available.containsAll(ids)) {
      throw StateError('部分 HTTP TTS 引擎已被删除，请重新打开导出');
    }
    return const JsonEncoder.withIndent('  ').convert([
      for (final item in entries)
        if (ids == null || ids.contains((item as Map)['id'])) item,
    ]);
  }
}
