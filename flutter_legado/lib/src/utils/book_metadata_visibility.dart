/// 搜索与详情共用的元信息显示策略。— Codex + UI
/// 这不是通用解析规则；合法正文中的NaN或模板语法必须保留。
final _unrenderedTemplateRe = RegExp(r'\{\{|\{\$');

/// 第三方书源占位串（无数据文案，非真实内容）
const Set<String> _placeholderTexts = {'暂无专辑', '暂无简介'};

/// 字符串是否含未渲染模板变量残留（`{{...}}` / `{$...}`）
bool _hasUnrenderedTemplate(String v) => _unrenderedTemplateRe.hasMatch(v);

/// "NaN" 拼接形判定（如 "NaN : NaN"：全部分隔符切分后每段均为 NAN）
///
/// 注意：`toUpperCase` 产物为全大写 'NAN'（非 'NaN'），判据必须与
/// 'NAN' 比（[R-NaN 2.0.273 核图复修] 同源逻辑）。
bool _isNanJoined(String v) {
  final parts = v
      .split(RegExp(r'[\s:：,，;；、/|+&·~\-_]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return false;
  return parts.every((p) => p.toUpperCase() == 'NAN');
}

/// 仅决定搜索/详情元信息是否显示，不修改模型或参与正文规则求值。
bool isVisibleBookMetadata(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return false;
  if (v.toUpperCase() == 'NAN') return false;
  if (_isNanJoined(v)) return false;
  if (_placeholderTexts.contains(v)) return false;
  return !_hasUnrenderedTemplate(v);
}
