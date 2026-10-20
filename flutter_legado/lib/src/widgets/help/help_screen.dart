import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/tools/presentation/code_edit_screen.dart';
import '../legado_app_bar.dart';
import 'help_markdown_builders.dart';
import 'help_markdown_styles.dart';
import 'help_sections.dart';

/// Markdown 阅读内容，外层尺寸与关闭手势由共用 Sheet 入口管理。
///
/// 顶栏固定目录/源码/关闭操作，正文独立滚动。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, required this.assetPath, this.title = '帮助'});

  /// 资产路径，如 `assets/web/help/md/appHelp.md`
  final String assetPath;
  final String title;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _scrollCtrl = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _markdown;
  String? _error;
  List<HelpSection> _sections = const [];
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() {
        _markdown = text;
        _sections = parseHelpSections(text);
        _selectedSection = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  String get _displayMarkdown {
    final full = _markdown ?? '';
    if (_selectedSection == 0 || _sections.isEmpty) return full;
    return _sections[_selectedSection - 1].markdown;
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法打开链接：$href')));
      }
    }
  }

  void _selectSection(int index) {
    setState(() => _selectedSection = index);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  Future<void> _openSourceView() async {
    final content = _markdown;
    if (content == null) return;
    await CodeEditScreen.open(
      context,
      title: widget.title,
      initialText: content,
      writable: false,
    );
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final background =
        theme.bottomSheetTheme.backgroundColor ?? cs.surfaceContainerLow;

    return SafeArea(
      top: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: background,
        endDrawer: _sections.isEmpty ? null : _buildTocDrawer(theme, cs),
        appBar: LegadoAppBar(
          showBack: false,
          primary: false,
          backgroundColor: background,
          foregroundColor: cs.onSurface,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (_sections.isNotEmpty)
              IconButton(
                icon: const Icon(Symbols.list_alt_rounded),
                tooltip: '目录',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            IconButton(
              icon: const Icon(Symbols.code_rounded),
              tooltip: '源码',
              onPressed: _markdown == null ? null : _openSourceView,
            ),
            IconButton(
              icon: const Icon(Symbols.close_rounded),
              tooltip: '关闭',
              onPressed: _close,
            ),
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载帮助失败：$_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_markdown == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Markdown(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      data: _displayMarkdown,
      onTapLink: (_, href, linkText) {
        if (href != null) _openLink(href);
      },
      styleSheet: helpMarkdownStyleSheet(theme),
      builders: helpMarkdownBuilders(theme),
    );
  }

  Widget _buildTocDrawer(ThemeData theme, ColorScheme cs) {
    final labels = ['全部', ..._sections.map((s) => s.title)];
    return Drawer(
      width: 264,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '目录',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: labels.length,
                itemBuilder: (context, index) {
                  final selected = _selectedSection == index;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: cs.primaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    title: Text(
                      labels[index],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => _selectSection(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
