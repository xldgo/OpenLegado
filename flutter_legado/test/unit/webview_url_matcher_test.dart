import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/webview_url_matcher.dart';

void main() {
  test('拒绝仅在URL中间命中的子串', () {
    final matcher = WebViewUrlMatcher(r'https://site\.test/target');
    expect(matcher.matches('https://site.test/target'), isTrue);
    expect(
      matcher.matches('https://other.test/?next=https://site.test/target'),
      isFalse,
    );
    expect(matcher.matches('https://site.test/target/more'), isFalse);
  });
  test('表达式分支仍能回溯到覆盖整个URL的匹配', () {
    expect(WebViewUrlMatcher(r'a|ab').matches('ab'), isTrue);
    expect(WebViewUrlMatcher(r'a|ab').matches('abc'), isFalse);
  });
  test('已有锚点和通配表达式仍有效', () {
    expect(
      WebViewUrlMatcher(r'^https?://.+/stream\?.*$')
          .matches('https://site.test/stream?x=1'),
      isTrue,
    );
  });
  test('末尾换行不是隐式完整匹配', () {
    expect(WebViewUrlMatcher('url').matches('url\n'), isFalse);
    expect(WebViewUrlMatcher(r'url\n').matches('url\n'), isTrue);
  });
  test('保留大小写和非ASCII匹配语义', () {
    expect(
      WebViewUrlMatcher('https://site.test/中文').matches('https://site.test/中文'),
      isTrue,
    );
    expect(
      WebViewUrlMatcher('https://site.test/中文').matches('https://SITE.test/中文'),
      isFalse,
    );
  });
  test('坏正则在创建时失败', () {
    expect(() => WebViewUrlMatcher('['), throwsFormatException);
  });
}
