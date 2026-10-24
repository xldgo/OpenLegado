import '../../../utils/error_message.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/highlight_repository_provider.dart';
import '../../reader/highlight/reader_highlight_resources.dart';
import '../../reader/highlight/reader_highlights_provider.dart';
import '../../reader/layout/paragraph_layout_engine.dart';
import '../../reader/widgets/reader_text_content.dart';

import 'package:file_picker/file_picker.dart';

import '../../../platform/highlight_rule_files.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../domain/models/highlight_rule.dart';
import '../../../widgets/app_settings_form.dart';
import '../../../widgets/app_settings_sheet.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/settings_widgets.dart';

Future<HighlightRule?> showHighlightRuleEditor(
  BuildContext context, {
  HighlightRule? rule,
  required Future<bool> Function(HighlightRule) onSave,
}) => AppBottomSheet.showContent<HighlightRule>(
  context: context,
  builder: (_) => _HighlightRuleEditSheet(rule: rule, onSave: onSave),
);

/// 字段编辑不执行正则；保存失败保留输入，校验交由Rust统一实现。
class _HighlightRuleEditSheet extends ConsumerStatefulWidget {
  const _HighlightRuleEditSheet({this.rule, required this.onSave});
  final HighlightRule? rule;
  final Future<bool> Function(HighlightRule) onSave;
  @override
  ConsumerState<_HighlightRuleEditSheet> createState() =>
      _HighlightRuleEditSheetState();
}

class _HighlightRuleEditSheetState
    extends ConsumerState<_HighlightRuleEditSheet> {
  final _controllers = <String, TextEditingController>{};
  late Map<String, dynamic> _style;
  late bool _regex;
  bool _saving = false;
  String? _error;
  bool _previewing = false;
  Widget? _preview;
  final _resources = ReaderHighlightResources();
  final _invalidColors = <String>{};

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _style = rule == null || rule.style.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(rule.style) as Map);
    _style.putIfAbsent('targetScope', () => rule?.applyToTitle == true ? 0 : 2);
    _regex = rule?.isRegex ?? true;
    for (final entry in {
      'name': rule?.name ?? '',
      'pattern': rule?.pattern ?? '',
      'scope': rule?.scope ?? '',
    }.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _resources.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_invalidColors.isNotEmpty) {
      setState(() => _error = '颜色需为8位ARGB十六进制');
      return;
    }
    if (_controllers['pattern']!.text.trim().isEmpty) {
      setState(() => _error = '匹配模式不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final rule = _draft();
    try {
      final success = await widget.onSave(rule);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, rule);
      } else {
        setState(() {
          _saving = false;
          _error = '保存失败，请检查规则后重试';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  HighlightRule _draft() => (widget.rule ?? const HighlightRule()).copyWith(
    name: _controllers['name']!.text.trim(),
    pattern: _controllers['pattern']!.text.trim(),
    scope: _controllers['scope']!.text.trim(),
    isRegex: _regex,
    applyToTitle: _style['targetScope'] != 2,
    style: jsonEncode(_style),
  );

  Future<void> _showPreview(double width) async {
    final text = _controllers['sampleText']!.text;
    if (text.trim().isEmpty) {
      setState(() => _error = '请先填写示例文本');
      return;
    }
    final colors = Theme.of(context).colorScheme;
    final base = _draft();
    // 预览当前规则效果，不受它在书籍或阅读配置中的绑定限制。
    final rule = base.copyWith(
      isEnabled: true,
      style: jsonEncode({..._style, 'configName': null}),
    );
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final matches = await ref
          .read(highlightRuleRepositoryProvider)
          .matchText([rule], text, isTitle: _style['targetScope'] == 1);
      if (!mounted) return;
      await _resources.prepare(matches);
      if (!mounted) return;
      Widget preview = Text(text);
      if (matches.isNotEmpty) {
        final engine = ParagraphLayoutEngine(
          config: ParagraphConfig(
            fontSize: 18,
            textColor: colors.onSurface,
            backgroundColor: colors.surface,
            indentCount: 0,
            justify: false,
          ),
          context: context,
          resources: _resources,
          highlights: ReaderHighlights(body: matches),
        );
        final pages = await engine.paginateChapter(
          text,
          width,
          double.infinity,
        );
        if (!mounted) return;
        preview = ReaderHighlightResourceScope(
          resources: _resources,
          child: ReaderTextContent(
            pageInfo: pages.single,
            fontSize: 18,
            lineHeight: 1.2,
            paragraphSpacing: 2,
            textColor: colors.onSurface,
            selectText: false,
            justify: false,
          ),
        );
      }
      setState(() {
        _preview = preview;
        _previewing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorMessage(e);
          _previewing = false;
        });
      }
    }
  }

  Widget _field(
    String key,
    String label, {
    bool number = false,
    String? hint,
    Widget? suffix,
  }) {
    final controller = _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: _style[key]?.toString() ?? ''),
    );
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
      onChanged: (text) {
        if (key == 'name' || key == 'pattern' || key == 'scope') return;
        if (text.isEmpty) {
          _style.remove(key);
        } else if (number) {
          _style[key] = num.tryParse(text) ?? text;
        } else {
          _style[key] = text;
        }
      },
    );
  }

  Widget _asset(String key, String label) => _field(
    key,
    label,
    suffix: IconButton(
      tooltip: '选择$label',
      icon: const Icon(Icons.folder_open),
      onPressed: () async {
        try {
          final picked = await FilePicker.pickFile();
          if (picked?.path == null) return;
          final destination = await HighlightRuleFiles.install(picked!.path!);
          if (!mounted) return;
          setState(() {
            _style[key] = destination;
            _controllers[key]!.text = destination;
          });
        } catch (e) {
          if (mounted) setState(() => _error = '资源导入失败：$e');
        }
      },
    ),
  );

  Widget _choice(
    String key,
    String label,
    List<String> options,
    int fallback,
  ) => DropdownButtonFormField<int>(
    initialValue: (_style[key] as int?) ?? fallback,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var i = 0; i < options.length; i++)
        DropdownMenuItem(value: i, child: Text(options[i])),
    ],
    onChanged: (v) => setState(() => _style[key] = v),
  );

  Widget _color(String key, String label) {
    final cs = Theme.of(context).colorScheme;
    final colors = [
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.errorContainer,
      cs.primaryFixedDim,
      cs.secondaryFixedDim,
      cs.tertiaryFixedDim,
      cs.inversePrimary,
    ];
    return Column(
      key: ValueKey('highlight-color-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            TextButton(
              onPressed: () => setState(() {
                _style.remove(key);
                _invalidColors.remove(key);
              }),
              child: const Text('不设置'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in colors)
              Semantics(
                label: '$label ${color.toARGB32().toRadixString(16)}',
                button: true,
                selected:
                    (_style[key] as num?)?.toInt().toUnsigned(32) ==
                    color.toARGB32(),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _style[key] = color.toARGB32();
                    _invalidColors.remove(key);
                  }),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            (_style[key] as num?)?.toInt().toUnsigned(32) ==
                                color.toARGB32()
                            ? cs.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        TextFormField(
          key: ValueKey((key, _style[key])),
          initialValue: (_style[key] as num?)
              ?.toInt()
              .toUnsigned(32)
              .toRadixString(16)
              .padLeft(8, '0'),
          decoration: const InputDecoration(labelText: '自定义 ARGB（8位十六进制）'),
          onChanged: (v) {
            final text = v.replaceFirst('#', '');
            final color = int.tryParse(text, radix: 16);
            if (text.isEmpty) {
              _style.remove(key);
              _invalidColors.remove(key);
            } else if (color != null && text.length == 8) {
              _style[key] = color;
              _invalidColors.remove(key);
            } else {
              _invalidColors.add(key);
            }
          },
        ),
      ],
    );
  }

  Widget _group(
    String title,
    List<Widget> fields, {
    bool open = false,
    List<Widget> rows = const [],
  }) => ExpansionTile(
    title: Text(title),
    initiallyExpanded: open,
    children: [
      ...rows,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: AppSettingsForm(children: fields),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: widget.rule == null ? '新增高亮规则' : '编辑高亮规则',
    onSave: _saving ? null : _save,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppSettingsForm(
            children: [
              _field('name', '规则名称（可选）'),
              _field('pattern', '匹配模式 *'),
              _field('scope', '生效范围（可选）', hint: '书名或书源名，留空为全局'),
              _choice('targetScope', '作用内容', ['标题与正文', '仅标题', '仅正文'], 2),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        SettingSwitchRow(
          title: '使用正则表达式',
          value: _regex,
          onChanged: (v) => setState(() => _regex = v),
        ),
        _group('颜色与示例', [
          _field('sampleText', '示例文本'),
          LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: _previewing
                      ? null
                      : () => _showPreview(constraints.maxWidth),
                  child: Text(_previewing ? '预览中…' : '预览匹配效果'),
                ),
                ?_preview,
              ],
            ),
          ),
          _color('textColor', '文字颜色'),
          _color('bgColor', '背景颜色'),
        ], open: true),
        _group('线条', [
          _choice('underlineMode', '线条样式', [
            '无',
            '实线',
            '虚线',
            '波浪线',
            '双线',
            '自定义 SVG 路径',
            '删除线',
            '荧光笔',
          ], 0),
          _color('underlineColor', '线条颜色'),
          _field('underlineWidth', '线宽（0.1–10）', number: true),
          _field('underlineOffset', '偏移（0–20）', number: true),
          _field('underlineSvgPath', 'SVG 路径数据'),
        ]),
        _group(
          '字体与间距',
          [
            _asset('fontPath', '字体文件'),
            _field('fontWeight', '字重（300–700）', number: true),
            _field('fontSizeOffset', '字号偏移（−10–10）', number: true),
            _field('letterSpacingBefore', '命中前间距（0–40）', number: true),
            _field('letterSpacingAfter', '命中后间距（0–40）', number: true),
            _field('lineSpacingTop', '行上间距（0–40）', number: true),
            _field('lineSpacingBottom', '行下间距（0–40）', number: true),
            _field('configName', '阅读配置名称（留空不限）'),
          ],
          rows: [
            SettingSwitchRow(
              title: '斜体',
              value: _style['isItalic'] == true,
              onChanged: (v) => setState(() => _style['isItalic'] = v),
            ),
          ],
        ),
        _group(
          '背景图片',
          [
            _asset('bgImage', '背景图片'),
            _choice('bgImageFit', '适配', ['平铺', '拉伸', '裁剪', '九宫格'], 0),
            _field('bgImageScale', '缩放（0.1–5）', number: true),
            for (final entry in {
              'npLeft': '左',
              'npRight': '右',
              'npTop': '上',
              'npBottom': '下',
            }.entries)
              _field(entry.key, '${entry.value}切片比例（0–1）', number: true),
            _field('bgLengthOffsetLeft', '背景左侧长度偏移（−40–40）', number: true),
            _field('bgLengthOffsetRight', '背景右侧长度偏移（−40–40）', number: true),
          ],
          rows: [
            SettingSwitchRow(
              title: '手动九宫格切片',
              value: _style['manualNineSlice'] != false,
              onChanged: (v) => setState(() => _style['manualNineSlice'] = v),
            ),
          ],
        ),
      ],
    ),
  );
}
