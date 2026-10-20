// 类型化请求的默认值、错误与平台动作行为。— Codex + Bridge
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/bridge/transport_request_mapping.dart';

void main() {
  test('校验配置保留空值、显式false、超时与默认语义', () {
    expect(sourceCheckConfig(null), const SourceCheckConfigDto());
    final config = sourceCheckConfig(
      '{"keyword":"","step_timeout_ms":17,"check_search":false,"check_toc":true}',
    );
    expect(config.keyword, '');
    expect(config.stepTimeoutMs, BigInt.from(17));
    expect(config.checkSearch, false);
    expect(config.checkToc, true);
    expect(config.checkContent, isNull);
  });
  for (final raw in [
    '[]',
    '{',
    '{"step_timeout_ms":-1}',
    '{"check_search":"false"}',
  ]) {
    test('单次配置错误$raw不伪装成成功，批量配置保留默认回落', () {
      expect(() => sourceCheckConfig(raw), throwsA(anything));
      expect(
        sourceCheckConfig(raw, fallbackOnError: true),
        const SourceCheckConfigDto(),
      );
    });
  }
  test('正文不会进入动作处理器，包括普通JSON正文', () async {
    final body = '{"action":"非平台动作","text":"小说😀"}';
    var called = false;
    expect(
      await resolveTextResponse(TextResponseDto.text(body), (_) async {
        called = true;
        return '';
      }),
      body,
    );
    expect(called, false);
  });
  test('动作参数直接分发，保留WebView结果、Cookie和等待语义', () async {
    const action = PlatformActionDto(
      action: PlatformActionKind.webView,
      url: 'https://example.test',
      html: '正文😀',
      js: 'document.title',
      cookie: 'a=b',
      sourceRegex: 'audio',
      sourceKey: '源',
      isFloat: false,
      isRule: true,
      cacheFirst: true,
      delayTimeMs: 900,
    );
    Map<String, dynamic>? dispatched;
    final text = await resolveTextResponse(
      const TextResponseDto.platformAction(action),
      (payload) async {
        dispatched = payload;
        return '执行结果';
      },
    );
    expect(text, '执行结果');
    expect(dispatched, {
      'action': 'webView',
      'url': 'https://example.test',
      'html': '正文😀',
      'js': 'document.title',
      'cookie': 'a=b',
      'sourceRegex': 'audio',
      'sourceKey': '源',
      'isFloat': false,
      'isRule': true,
      'cacheFirst': true,
      'delayTime': 900,
    });
  });
}
