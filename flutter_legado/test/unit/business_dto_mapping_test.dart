import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/bridge/business_dto_mapping.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/bridge/business_dto.dart';

void main() {
  test('RSS可空Cookie、显式false与字符串文档不互换，i32边界拒绝溢出', () {
    const base = RssSource(
      sourceUrl: 'source',
      sourceName: '源',
      enabledCookieJar: null,
      enabled: false,
      header: '{}',
      loginUi: '[]',
      ruleArticles: '@js:result',
      articleStyle: 2147483647,
      customOrder: -2147483648,
      rssType: 0,
      lastUpdateTime: 9007199254740993,
    );
    expect(rssSourceFromDto(rssSourceToDto(base)), base);
    expect(
      rssSourceFromDto(rssSourceToDto(base.copyWith(enabledCookieJar: false)))
          .enabledCookieJar,
      isFalse,
    );
    for (final v in [
      base.copyWith(articleStyle: 2147483648),
      base.copyWith(customOrder: -2147483649),
      base.copyWith(rssType: 2147483648),
    ]) {
      expect(() => rssSourceToDto(v), throwsRangeError);
    }
  });
  test('订阅直传保留既有空隐藏字段行为和未知业务类型，不丢64位时间', () {
    const v = RuleSub(
      id: 9007199254740993,
      url: 'url',
      name: '名称',
      subType: 'unknown',
      lastUpdate: 9007199254740993,
      createdAt: 4,
      version: 'v',
      isEnabled: false,
      customOrder: 2147483647,
      autoUpdate: true,
      updateInterval: -2147483648,
      silentUpdate: true,
    );
    final encoded = ruleSubscriptionToDto(v);
    expect(
      [encoded.js, encoded.showRule, encoded.sourceUrl],
      [null, null, null],
    );
    expect(ruleSubscriptionFromDto(encoded).toJson(), v.toJson());
    expect(
      () => ruleSubscriptionToDto(v.copyWith(customOrder: 2147483648)),
      throwsRangeError,
    );
    expect(
      () => ruleSubscriptionToDto(v.copyWith(updateInterval: -2147483649)),
      throwsRangeError,
    );
  });
  test('收藏可空链接和原生时间别名直接映射到领域字段', () {
    final v = rssStarFromDto(
      const RssStarSnapshotDto(
        origin: 'feed',
        sort: '排序',
        title: '标题',
        starTime: 9007199254740993,
        link: null,
        pubDate: '日期',
        description: '摘要',
        content: '内容',
        image: '封面',
        variable: '变量',
      ),
    );
    expect(v.link, '');
    expect(v.starTime, 9007199254740993);
    expect(v.pubDate, '日期');
    expect(v.group, '默认分组');
  });
  test('所有日志枚举保持级别、Unicode消息和毫秒时间', () {
    for (final level in LogLevelDto.values) {
      final v = appLogFromDto(
        AppLogDto(
          timestamp: 9007199254740993,
          level: level,
          message: '中文😀\n第二行',
        ),
      );
      expect(v.level, level.name);
      expect(v.timestamp, 9007199254740993);
      expect(v.message, '中文😀\n第二行');
    }
  });
}
