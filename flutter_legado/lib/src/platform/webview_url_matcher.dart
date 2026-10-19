/// 嗅探使用整串URL匹配；锚定整体表达式，保留分支回溯。— Codex + Bridge
class WebViewUrlMatcher {
  WebViewUrlMatcher(String pattern) : _pattern = RegExp('^(?:$pattern)\$');

  final RegExp _pattern;

  bool matches(String url) => _pattern.firstMatch(url)?.end == url.length;
}
