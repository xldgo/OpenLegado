import 'dart:convert';

import '../../domain/contracts/rss_source_repository.dart';
import '../../models/models.dart';

/// 订阅Mock使用装配实例内的同一份数据。— Codex + Bridge
final class MockRssSourceRepository implements RssSourceRepository {
  final List<RssSource> _rssSources = [];

  MockRssSourceRepository({bool withDefaultSources = false}) {
    if (!withDefaultSources) return;
    // ── RSS 订阅源（来源：app/src/main/assets/defaultData/rssSources.json）──
    _rssSources.addAll([
      RssSource(
        sourceUrl: 'https://www.yuque.com/legado',
        sourceName: '使用说明',
        sourceIcon: 'https://cdn.jsdelivr.net/gh/gedoor/legado@master/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        sourceGroup: 'legado',
        enabled: true,
        singleUrl: true,
        enableJs: true,
        customOrder: 2,
      ),
      RssSource(
        sourceUrl: 'snssdk1128://user/profile/562564899806367',
        sourceName: '小说拾遗',
        sourceIcon: 'http://mmbiz.qpic.cn/mmbiz_png/hpfMV8hEuL2eS6vnCxvTzoOiaCAibV6exBzJWq9xMic9xDg3YXAick87tsfafic0icRwkQ5ibV0bJ84JtSuxhPuEDVquA/0?wx_fmt=png',
        sourceGroup: 'legado',
        enabled: true,
        singleUrl: true,
        enableJs: true,
        customOrder: 3,
      ),
      RssSource(
        sourceUrl: 'https://pan.miaogongzi.net',
        sourceName: 'Meow云',
        sourceIcon: 'https://cdn.jsdelivr.net/gh/mgz0227/meowcloud/icon.png',
        sourceGroup: 'legado',
        enabled: true,
        singleUrl: true,
        enableJs: true,
        customOrder: 4,
      ),
      RssSource(
        sourceUrl: 'https://www.lanzout.com/b0bw8jwoh',
        sourceName: '烏雲净化',
        sourceIcon: 'https://cdn.jsdelivr.net/gh/gedoor/legado@master/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        sourceGroup: 'legado',
        enabled: true,
        singleUrl: true,
        enableJs: true,
        customOrder: 5,
      ),
    ]);
  }

  @override
  Future<List<RssSource>> getRssSources() async => List.from(_rssSources);

  @override
  Future<RssSource> addRssSource(RssSource source) async {
    _rssSources.add(source);
    return source;
  }

  @override
  Future<void> updateRssSource(RssSource source) async {
    // 对齐 rssUpdateSource FFI 语义：源不存在时报错（不再静默忽略） — QoderCN
    final idx = _rssSources.indexWhere((s) => s.sourceUrl == source.sourceUrl);
    if (idx < 0) {
      throw StateError(
        'updateRssSource: RSS 源不存在（sourceUrl=${source.sourceUrl}）',
      );
    }
    _rssSources[idx] = source;
  }

  @override
  Future<void> deleteRssSource(String sourceUrl) async {
    _rssSources.removeWhere((s) => s.sourceUrl == sourceUrl);
  }

  @override
  Future<void> enableRssSource(String sourceUrl) async {
    await _setEnabled(sourceUrl, true);
  }

  @override
  Future<void> disableRssSource(String sourceUrl) async {
    await _setEnabled(sourceUrl, false);
  }

  Future<void> _setEnabled(String sourceUrl, bool enabled) async {
    final idx = _rssSources.indexWhere((s) => s.sourceUrl == sourceUrl);
    if (idx < 0) throw StateError('RSS 源不存在（sourceUrl=$sourceUrl）');
    _rssSources[idx] = _rssSources[idx].copyWith(enabled: enabled);
  }

  @override
  Future<int> importRssSources(String jsonArray) async {
    final list = jsonDecode(jsonArray) as List<dynamic>;
    var count = 0;
    for (final item in list) {
      if (item is! Map) continue;
      await addRssSource(RssSource.fromJson(Map<String, dynamic>.from(item)));
      count++;
    }
    return count;
  }

  @override
  Future<String> exportRssSources() async =>
      jsonEncode(_rssSources.map((s) => s.toJson()).toList());
}
