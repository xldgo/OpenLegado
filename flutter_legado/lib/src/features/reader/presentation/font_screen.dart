import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../application/reader_settings_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

/// 字体管理页面
///
/// 功能：显示当前阅读字体、切换系统字体、导入自定义 .ttf/.otf 字体、实时预览。
/// 自定义字体通过统一平台入口动态加载，字体文件复制到应用文档目录持久化。
class FontScreen extends ConsumerStatefulWidget {
  /// 字体设置目标：`body` = 正文字体（既有 `reader_font_family` 链路，
  /// 默认值用于既有正文入口）；`title` = 标题字体（原版 #1072 titleFont，
  /// 空值=跟随正文，写 `reader_title_font_family` 键）— full-stack-engineer
  final String target;

  const FontScreen({super.key, this.target = 'body'});

  @override
  ConsumerState<FontScreen> createState() => _FontScreenState();
}

class _FontScreenState extends ConsumerState<FontScreen> {
  /// 内置/系统字体候选列表
  static const List<_FontOption> _systemFonts = [
    _FontOption(family: null, label: '默认字体'),
    _FontOption(family: 'serif', label: '衬线体 (Serif)'),
    _FontOption(family: 'monospace', label: '等宽体 (Monospace)'),
    _FontOption(family: 'Microsoft YaHei', label: '微软雅黑'),
    _FontOption(family: 'SimSun', label: '宋体'),
    _FontOption(family: 'KaiTi', label: '楷体'),
    _FontOption(family: 'SimHei', label: '黑体'),
    _FontOption(family: 'Source Han Serif SC', label: '思源宋体'),
    _FontOption(family: 'Source Han Sans SC', label: '思源黑体'),
    _FontOption(family: 'Noto Serif SC', label: 'Noto 宋体'),
    _FontOption(family: 'Georgia', label: 'Georgia'),
    _FontOption(family: 'Times New Roman', label: 'Times New Roman'),
    _FontOption(family: 'Consolas', label: 'Consolas'),
  ];

  String? get _currentFamily {
    final settings = ref.read(readerSettingsRepositoryProvider).current;
    if (widget.target != 'title') return settings.fontFamily;
    return settings.titleFontFamily.isEmpty ? null : settings.titleFontFamily;
  }

  List<_FontOption> _customFonts = [];
  bool _importing = false;

  static const _previewText =
      '天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。\n'
      'The quick brown fox jumps over the lazy dog. 0123456789';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
      if (!mounted) return;
      final available = await ref
          .read(readerFontServiceProvider)
          .loadAvailable();
      if (!mounted) return;
      setState(
        () => _customFonts = [
          for (final font in available.fonts)
            _FontOption(family: font.family, label: font.label),
        ],
      );
      if (available.missing.isNotEmpty) {
        _showError('部分自定义字体文件缺失，未加载：${available.missing.join('、')}');
      }
    } catch (error) {
      _showError('字体读取失败：$error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectFont(String? family) async {
    try {
      await ref
          .read(readerSettingsRepositoryProvider)
          .update(
            fontFamily: widget.target == 'title' ? null : family ?? '',
            titleFontFamily: widget.target == 'title' ? family ?? '' : null,
          );
    } catch (error) {
      _showError('字体选择保存失败，请重试');
    }
  }

  Future<void> _importFont() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (picked == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final label = await ref
          .read(readerFontServiceProvider)
          .importFont(picked.name, bytes, title: widget.target == 'title');
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导入字体「$label」')));
      }
    } catch (error) {
      _showError('字体导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  String get _currentLabel {
    final family = _currentFamily;
    if (widget.target == 'title') {
      // 标题字体：null/空 = 跟随正文（对齐原版 titleFont 语义）
      if (family == null || family.isEmpty) return '跟随正文';
    } else if (family == null) {
      return '默认字体';
    }
    for (final f in [..._systemFonts, ..._customFonts]) {
      if (f.family == family) return f.label;
    }
    return family;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readerSettingsProvider);
    ref.listen(readerFontsProvider, (previous, next) {
      if (previous?.value != next.value) unawaited(_load());
    });
    final theme = Theme.of(context);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(widget.target == 'title' ? '标题字体' : '字体管理'),
        actions: [
          IconButton(
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.file_download_rounded),
            tooltip: '导入 .ttf / .otf 字体',
            onPressed: _importing ? null : _importFont,
          ),
        ],
      ),
      // 预览固定在顶部，仅字体列表滚动；选中字体仍通过 setState 实时刷新。
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== 当前字体 + 预览 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              widget.target == 'title'
                  ? '当前标题字体：$_currentLabel'
                  : '当前字体：$_currentLabel',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _previewText,
                style: TextStyle(
                  fontFamily: widget.target == 'title' && _currentFamily == null
                      ? ref
                            .read(readerSettingsRepositoryProvider)
                            .current
                            .fontFamily
                      : _currentFamily,
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const Divider(),

          Expanded(
            child: ListView(
              children: [
                // ===== 自定义字体 =====
                if (_customFonts.isNotEmpty) ...[
                  _buildSectionHeader(theme, '自定义字体'),
                  ..._customFonts.map((f) => _buildFontTile(theme, f)),
                  const Divider(),
                ],

                // ===== 系统字体 =====
                _buildSectionHeader(theme, '系统字体'),
                ..._systemFonts.map((f) => _buildFontTile(theme, f)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    // [LAYOUT_PLAN P1] 分组标题走 SettingsSectionHeader 规范
    //（labelMedium/onSurfaceVariant，padding 16,24,16,8）
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFontTile(ThemeData theme, _FontOption font) {
    final selected = _currentFamily == font.family;
    return ListTile(
      leading: Icon(
        selected
            ? Symbols.radio_button_checked_rounded
            : Symbols.radio_button_unchecked_rounded,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(
        font.label,
        style: TextStyle(fontFamily: font.family, fontSize: 16),
      ),
      subtitle: Text(
        '阅读字体预览 Aa 汉',
        style: TextStyle(fontFamily: font.family, fontSize: 13),
      ),
      selected: selected,
      onTap: () => _selectFont(font.family),
    );
  }
}

class _FontOption {
  final String? family;
  final String label;

  const _FontOption({required this.family, required this.label});
}
