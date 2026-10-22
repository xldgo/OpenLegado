import '../../../widgets/app_snack_bar.dart';
import '../../../app/routing/app_navigation.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/rss_repository_provider.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:share_plus/share_plus.dart';

import '../../../models/models.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/help/help_assets.dart';
import '../../../widgets/help/show_help.dart';
import '../../../utils/source_field_code_edit.dart';
import '../../../widgets/source_editor.dart';

/// RSS 源编辑器页面（对标原版 RssSourceEditActivity）
///
/// - 可折叠选项面板：启用 / 单 URL / Cookie / 预加载 + 源类型 + 文章样式
/// - 4 Tab：基本（15 字段）/ 预处理（4）/ 列表规则（7）/ WEB_VIEW（10）
/// - 菜单：调试源 / 复制源 / 粘贴源 / 分享文本 / 帮助
/// - 编辑走 updateRssSource，新建走 addRssSource；退出时未保存提示
class RssSourceEditScreen extends ConsumerStatefulWidget {
  /// 编辑模式时传入已有源，null 表示新建
  final RssSource? source;

  const RssSourceEditScreen({super.key, this.source});

  @override
  ConsumerState<RssSourceEditScreen> createState() =>
      _RssSourceEditScreenState();
}

class _RssSourceEditScreenState extends ConsumerState<RssSourceEditScreen> {
  // ===== 字段定义（对标原版 sourceEntities 4 Tab 分组） =====

  static List<SourceEditorFieldSpec> _baseFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec('sourceName', l10n.editorSourceName, maxLines: 1),
    SourceEditorFieldSpec(
      'sourceUrl',
      l10n.editorSourceUrl,
      hint: 'https://example.com/feed',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'sourceIcon',
      l10n.editorIcon,
      hint: l10n.editorIconUrl,
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'sourceGroup',
      l10n.editorSourceGroup,
      hint: l10n.editorGroupHint,
      maxLines: 1,
    ),
    SourceEditorFieldSpec('sourceComment', l10n.editorSourceComment),
    SourceEditorFieldSpec('searchUrl', l10n.editorSearchUrl, maxLines: 1),
    SourceEditorFieldSpec(
      'sortUrl',
      l10n.editorSortUrl,
      hint: l10n.editorSortHint,
    ),
    SourceEditorFieldSpec('loginUrl', l10n.editorLoginUrl, maxLines: 1),
    SourceEditorFieldSpec('loginUi', l10n.editorLoginUi, maxLines: 1),
    SourceEditorFieldSpec(
      'loginCheckJs',
      l10n.editorLoginDetectionJs,
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'coverDecodeJs',
      l10n.editorCoverDecodeJs,
      maxLines: 1,
    ),
    SourceEditorFieldSpec('header', l10n.editorHeader, maxLines: 1),
    SourceEditorFieldSpec(
      'variableComment',
      l10n.editorRssVariableComment,
      hint: 'variableComment',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'concurrentRate',
      l10n.editorConcurrentRate,
      hint: l10n.editorRateHint,
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'jsLib',
      l10n.editorJsLibrary,
      hint: l10n.editorJsLibraryHint,
      maxLines: 1,
    ),
  ];

  static List<SourceEditorFieldSpec> _preFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'startHtml',
      l10n.editorStartHtml,
      hint: 'startHtml',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'startStyle',
      l10n.editorStartStyle,
      hint: 'startStyle',
    ),
    SourceEditorFieldSpec(
      'startJs',
      l10n.editorStartJs,
      hint: 'startJs',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'preloadJs',
      l10n.editorPreloadJs,
      hint: 'preloadJs',
      maxLines: 1,
    ),
  ];

  static List<SourceEditorFieldSpec> _listFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'ruleArticles',
      l10n.editorArticleList,
      hint: l10n.editorArticlesHint,
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'ruleNextPage',
      l10n.editorNextPage,
      hint: 'ruleNextPage',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'ruleTitle',
      l10n.editorTitleRule,
      hint: 'ruleTitle',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'rulePubDate',
      l10n.editorDateRule,
      hint: 'rulePubDate',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'ruleDescription',
      l10n.editorDescriptionRule,
      hint: 'ruleDescription',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'ruleImage',
      l10n.editorImageRule,
      hint: 'ruleImage',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'ruleLink',
      l10n.editorLinkRule,
      hint: 'ruleLink',
      maxLines: 1,
    ),
  ];

  static List<SourceEditorFieldSpec> _webFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'ruleContent',
      l10n.editorContentRule,
      hint: 'ruleContent',
      maxLines: 1,
    ),
    SourceEditorFieldSpec('style', l10n.editorStyle, hint: l10n.editorCssHint),
    SourceEditorFieldSpec(
      'injectJs',
      l10n.editorInjectJs,
      hint: 'injectJs',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'contentWhitelist',
      l10n.editorContentWhitelist,
      hint: 'contentWhitelist',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'contentBlacklist',
      l10n.editorContentBlacklist,
      hint: 'contentBlacklist',
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'shouldOverrideUrlLoading',
      l10n.editorOverrideUrl,
      hint: 'shouldOverrideUrlLoading',
      maxLines: 1,
    ),
  ];

  static List<SourceEditorFieldSpec> _allFieldSpecs(AppLocalizations l10n) => [
    ..._baseFields(l10n),
    ..._preFields(l10n),
    ..._listFields(l10n),
    ..._webFields(l10n),
  ];

  /// 源类型（对标原版 sp_type / @array/rss_type）
  static List<String> _typeLabels(AppLocalizations l10n) => [
    l10n.editorWeb,
    l10n.editorImage,
    l10n.editorVideo,
  ];

  /// 文章样式（对标原版 ly_type / @array/layout_type）
  static List<String> _styleLabels(AppLocalizations l10n) => [
    l10n.editorList,
    l10n.editorSingleColumn,
    l10n.editorTwoColumns,
    l10n.editorWaterfall,
    l10n.editorThreeColumns,
  ];

  // 初始化与快照只使用字段键，不读取页面的语言上下文。
  static final _allFieldKeys = _allFieldSpecs(
    lookupAppLocalizations(const Locale('zh')),
  ).map((field) => field.key).toList(growable: false);

  static final _typeCount = _typeLabels(
    lookupAppLocalizations(const Locale('zh')),
  ).length;

  static final _styleCount = _styleLabels(
    lookupAppLocalizations(const Locale('zh')),
  ).length;

  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _focusedFieldKey;

  // 选项面板开关（对标原版 cb_is_enable 等）
  late bool _enabled;
  late bool _singleUrl;
  late bool _cookieJar;
  late bool _preload;

  // WEB_VIEW 页开关
  late bool _enableJs;
  late bool _loadWithBaseUrl;
  late bool _showWebLog;
  late bool _cacheFirst;

  late int _type;
  late int _articleStyle;

  bool _saving = false;
  bool _testing = false;
  String Function(AppLocalizations)? _testResult;
  String Function(AppLocalizations)? _testError;

  bool get _isEdit => widget.source != null;

  /// 进入时的字段快照（用于退出未保存提示）
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    // 初始值直接取源 JSON（key 与字段定义一致）
    final initial = s?.toJson() ?? const <String, dynamic>{};
    for (final key in _allFieldKeys) {
      final v = initial[key];
      _ctrls[key] = TextEditingController(text: v == null ? '' : v.toString());
    }
    _enabled = s?.enabled ?? true;
    _singleUrl = s?.singleUrl ?? false;
    _cookieJar = s?.enabledCookieJar ?? false;
    _preload = s?.preload ?? false;
    _enableJs = s?.enableJs ?? true;
    _loadWithBaseUrl = s?.loadWithBaseUrl ?? true;
    _showWebLog = s?.showWebLog ?? false;
    _cacheFirst = s?.cacheFirst ?? false;
    // 越界归零（对标原版 spType/lyType selection 校验）
    _type = (s?.rssType ?? 0).clamp(0, _typeCount - 1);
    _articleStyle = (s?.articleStyle ?? 0).clamp(0, _styleCount - 1);
    _initialSnapshot = _snapshot();
  }

  FocusNode _focusNodeFor(String key) => _focusNodes.putIfAbsent(
    key,
    () => FocusNode()
      ..addListener(() {
        if (_focusNodes[key]?.hasFocus == true) {
          _focusedFieldKey = key;
        }
      }),
  );

  Future<void> _openCodeEdit(String key, String title) async {
    await editSourceFieldCode(
      context,
      title: title,
      controller: _ctrls[key]!,
      focusNode: _focusNodeFor(key),
    );
  }

  Future<void> _fullscreenCodeEdit() async {
    final l10n = context.l10n;
    final key = _focusedFieldKey;
    if (key == null || !_ctrls.containsKey(key)) {
      showAppSnackBar(context, l10n.focusSourceFieldFirst);
      return;
    }
    final label = _allFieldSpecs(context.l10n)
        .where((s) => s.key == key)
        .map((s) => s.label)
        .firstOrNull;
    await _openCodeEdit(key, label ?? key);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  // ===== 快照与构建 =====

  String _snapshot() {
    return jsonEncode({
      for (final key in _allFieldKeys) key: _ctrls[key]!.text,
      'enabled': _enabled,
      'singleUrl': _singleUrl,
      'enabledCookieJar': _cookieJar,
      'preload': _preload,
      'enableJs': _enableJs,
      'loadWithBaseUrl': _loadWithBaseUrl,
      'showWebLog': _showWebLog,
      'cacheFirst': _cacheFirst,
      'type': _type,
      'articleStyle': _articleStyle,
    });
  }

  String? _opt(String key) {
    final v = _ctrls[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  /// 组装完整源（显式构造全部字段，避免 copyWith 无法清空可空字段）
  RssSource _buildSource() {
    final old = widget.source;
    return RssSource(
      sourceName: _ctrls['sourceName']!.text.trim(),
      sourceUrl: _ctrls['sourceUrl']!.text.trim(),
      sourceIcon: _opt('sourceIcon') ?? '',
      sourceGroup: _opt('sourceGroup'),
      sourceComment: _opt('sourceComment'),
      enabled: _enabled,
      variableComment: _opt('variableComment'),
      jsLib: _opt('jsLib'),
      enabledCookieJar: _cookieJar,
      concurrentRate: _opt('concurrentRate'),
      header: _opt('header'),
      loginUrl: _opt('loginUrl'),
      loginUi: _opt('loginUi'),
      loginCheckJs: _opt('loginCheckJs'),
      coverDecodeJs: _opt('coverDecodeJs'),
      sortUrl: _opt('sortUrl'),
      singleUrl: _singleUrl,
      articleStyle: _articleStyle,
      ruleArticles: _opt('ruleArticles'),
      ruleNextPage: _opt('ruleNextPage'),
      ruleTitle: _opt('ruleTitle'),
      rulePubDate: _opt('rulePubDate'),
      ruleDescription: _opt('ruleDescription'),
      ruleImage: _opt('ruleImage'),
      ruleLink: _opt('ruleLink'),
      ruleContent: _opt('ruleContent'),
      contentWhitelist: _opt('contentWhitelist'),
      contentBlacklist: _opt('contentBlacklist'),
      shouldOverrideUrlLoading: _opt('shouldOverrideUrlLoading'),
      style: _opt('style'),
      enableJs: _enableJs,
      loadWithBaseUrl: _loadWithBaseUrl,
      injectJs: _opt('injectJs'),
      preloadJs: _opt('preloadJs'),
      startHtml: _opt('startHtml'),
      startStyle: _opt('startStyle'),
      startJs: _opt('startJs'),
      showWebLog: _showWebLog,
      // 编辑模式保留排序与更新时间（对标原版 viewModel.save 语义）
      lastUpdateTime: old?.lastUpdateTime ?? 0,
      customOrder: old?.customOrder ?? 0,
      rssType: _type,
      preload: _preload,
      cacheFirst: _cacheFirst,
      searchUrl: _opt('searchUrl'),
    );
  }

  // ===== 保存 / 测试 =====

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _ctrls['sourceName']!.text.trim();
    final url = _ctrls['sourceUrl']!.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, l10n.enterSourceName);
      return;
    }
    if (url.isEmpty) {
      showAppSnackBar(context, l10n.enterSourceUrl);
      return;
    }

    setState(() => _saving = true);
    try {
      final source = _buildSource();
      if (_isEdit) {
        await ref.read(rssSourceRepositoryProvider).updateRssSource(source);
      } else {
        await ref.read(rssSourceRepositoryProvider).addRssSource(source);
      }
      if (!mounted) return;
      // 保存成功后更新快照，退出不再提示未保存
      _initialSnapshotMark = _snapshot();
      showAppSnackBar(
        context,
        _isEdit ? l10n.rssSourceUpdated : l10n.rssSourceAdded,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, l10n.sourceSaveFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 保存成功后覆盖初始快照的可变标记（late final 无法重赋值，独立持有）
  String? _savedSnapshot;
  String get _initialSnapshotMark => _savedSnapshot ?? _initialSnapshot;
  set _initialSnapshotMark(String v) => _savedSnapshot = v;

  bool get _dirty => _snapshot() != _initialSnapshotMark;

  /// 退出拦截：未保存时确认放弃（对标原版 exit 提示）
  Future<void> _tryExit({Object? result}) async {
    final l10n = context.l10n;
    if (!_dirty) {
      Navigator.of(context).pop(result);
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: l10n.unsavedChanges,
      content: l10n.discardSourceChanges,
      confirmText: l10n.discard,
      isDestructive: true,
    );
    if (discard && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _test() async {
    final url = _ctrls['sourceUrl']!.text.trim();
    if (url.isEmpty) {
      setState(() => _testError = (l10n) => l10n.testSourceUrlRequired);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _testError = null;
    });
    try {
      final articles = await ref
          .read(rssArticleRepositoryProvider)
          .getRssArticles(url);
      if (!mounted) return;
      if (articles.isEmpty) {
        setState(() => _testResult = (l10n) => l10n.sourceTestNoArticles);
      } else {
        final titles = articles
            .take(5)
            .map((e) => e.title)
            .toList(growable: false);
        setState(
          () => _testResult = (l10n) => l10n.sourceTestArticles(
            articles.length,
            titles
                .map((title) => title.isEmpty ? l10n.untitledArticle : title)
                .join('\n'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final error = e.toString();
      setState(() => _testError = (l10n) => l10n.sourceTestFailed(error));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ===== 菜单操作 =====

  Future<void> _handleMenu(String action) async {
    final l10n = context.l10n;
    switch (action) {
      case 'debug':
        final url = _ctrls['sourceUrl']!.text.trim();
        GoRouter.of(context).pushAppRoute(
          AppRoutes.rssSourceDebug,
          extra: url.isEmpty ? null : url,
        );
      case 'copy':
        final json = const JsonEncoder.withIndent('  ')
            .convert(_buildSource().toJson());
        await Clipboard.setData(ClipboardData(text: json));
        if (mounted) {
          showAppSnackBar(context, l10n.copiedRssSource);
        }
      case 'paste':
        await _pasteSource();
      case 'clear_cookie':
        await _clearCookie();
      case 'share':
        final json = jsonEncode(_buildSource().toJson());
        await SharePlus.instance.share(
          ShareParams(
            text: json,
            subject: l10n.rssSourceShareSubject(
              _ctrls['sourceName']!.text.trim(),
            ),
          ),
        );
      case 'help':
        _showHelpSheet();
    }
  }

  /// 清除 Cookie（对标原版 RssSourceEdit menu_clear_cookie）
  Future<void> _clearCookie() async {
    final l10n = context.l10n;
    final url = _ctrls['sourceUrl']!.text.trim();
    if (url.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, l10n.enterSourceUrlFirst);
      }
      return;
    }
    try {
      await ref.read(networkServiceProvider).clearCookie(url);
      if (!mounted) return;
      showAppSnackBar(context, l10n.cookiesCleared);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, l10n.clearCookiesFailed(e.toString()));
      }
    }
  }

  /// 粘贴源（对标原版 menu_paste_source：剪贴板 JSON 回填字段）
  Future<void> _pasteSource() async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, l10n.clipboardEmpty);
      }
      return;
    }
    try {
      final decoded = jsonDecode(text);
      final map = decoded is List && decoded.isNotEmpty
          ? decoded.first
          : decoded;
      if (map is! Map) throw const FormatException('不是订阅源 JSON');
      setState(() {
        for (final key in _allFieldKeys) {
          final v = map[key];
          _ctrls[key]!.text = v == null ? '' : v.toString();
        }
        _enabled = map['enabled'] == true;
        _singleUrl = map['singleUrl'] == true;
        _cookieJar = map['enabledCookieJar'] == true;
        _preload = map['preload'] == true;
        _enableJs = map['enableJs'] != false;
        _loadWithBaseUrl = map['loadWithBaseUrl'] != false;
        _showWebLog = map['showWebLog'] == true;
        _cacheFirst = map['cacheFirst'] == true;
        final type = map['type'];
        _type = type is int ? type.clamp(0, _typeCount - 1) : 0;
        final style = map['articleStyle'];
        _articleStyle = style is int ? style.clamp(0, _styleCount - 1) : 0;
      });
      if (mounted) {
        showAppSnackBar(context, l10n.pastedRssSource);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, l10n.pasteRssSourceFailed(e.toString()));
      }
    }
  }

  void _showHelpSheet() {
    showHelp(context, HelpAssets.rssRuleHelp);
  }

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryExit();
      },
      child: DefaultTabController(
        length: 4,
        child: AppScaffold(
          // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
          topBar: LegadoAppBar(
            leading: IconButton(
              icon: const Icon(Symbols.arrow_back_rounded),
              onPressed: _tryExit,
            ),
            title: Text(
              _isEdit ? context.l10n.editRssSource : context.l10n.newRssSource,
            ),
            bottom: TabBar(
              // 多项规则标签沿用可滚动、左侧起始对齐。
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: context.l10n.editorBasic),
                Tab(text: context.l10n.editorPreprocess),
                Tab(text: context.l10n.editorListRules),
                Tab(text: context.l10n.editorWeb),
              ],
            ),
            actions: [
              IconButton(
                tooltip: context.l10n.editSourceContent,
                icon: const Icon(Symbols.code_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: _fullscreenCodeEdit,
              ),
              IconButton(
                tooltip: context.l10n.save,
                icon: const Icon(Symbols.save_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : _save,
              ),
              // 测试（快速验证源 URL 可用性）
              IconButton(
                tooltip: context.l10n.testSource,
                visualDensity: VisualDensity.compact,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.science_rounded),
                onPressed: _testing ? null : _test,
              ),
              // 溢出菜单（对标原版 source_edit.xml 精简版）
              AppMenuButton<String>(
                tooltip: context.l10n.moreOptions,
                onSelected: _handleMenu,
                itemBuilder: (_) => [
                  AppMenuItem(
                    value: 'debug',
                    child: Text(context.l10n.debugSource),
                  ),
                  AppMenuItem(
                    value: 'copy',
                    child: Text(context.l10n.copySource),
                  ),
                  AppMenuItem(
                    value: 'paste',
                    child: Text(context.l10n.pasteSource),
                  ),
                  AppMenuItem(
                    value: 'clear_cookie',
                    child: Text(context.l10n.clearCookies),
                  ),
                  AppMenuItem(
                    value: 'share',
                    child: Text(context.l10n.shareSourceText),
                  ),
                  AppMenuItem(value: 'help', child: Text(context.l10n.help)),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 可折叠选项面板（对标原版选项区：4 开关 + 类型 + 样式）
              _buildOptionPanel(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFieldList(
                      'basic',
                      _baseFields(context.l10n),
                      withTestResult: true,
                    ),
                    _buildFieldList('pre', _preFields(context.l10n)),
                    _buildFieldList('list', _listFields(context.l10n)),
                    _buildWebViewTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选项面板（对标原版 cb_is_enable/cb_single_url/cb_is_enable_cookie/
  /// cb_is_enable_preload + sp_type + ly_type）
  Widget _buildOptionPanel() {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        context.l10n.editorOptions,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            children: [
              _checkChip(
                context.l10n.editorEnable,
                _enabled,
                (v) => _enabled = v,
              ),
              _checkChip(
                context.l10n.editorSingleUrl,
                _singleUrl,
                (v) => _singleUrl = v,
              ),
              _checkChip('Cookie', _cookieJar, (v) => _cookieJar = v),
              _checkChip(
                context.l10n.editorPreload,
                _preload,
                (v) => _preload = v,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              DropdownMenu<int>(
                initialSelection: _type,
                selectOnly: true,
                label: Text(context.l10n.editorType),
                onSelected: (v) => setState(() => _type = v ?? 0),
                dropdownMenuEntries: [
                  for (var i = 0; i < _typeCount; i++)
                    DropdownMenuEntry(
                      value: i,
                      label: _typeLabels(context.l10n)[i],
                    ),
                ],
              ),
              DropdownMenu<int>(
                initialSelection: _articleStyle,
                selectOnly: true,
                label: Text(context.l10n.editorStyle),
                onSelected: (v) => setState(() => _articleStyle = v ?? 0),
                dropdownMenuEntries: [
                  for (var i = 0; i < _styleCount; i++)
                    DropdownMenuEntry(
                      value: i,
                      label: _styleLabels(context.l10n)[i],
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _checkChip(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 112,
      child: CheckboxListTile(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: (v) => setState(() => onChanged(v ?? false)),
      ),
    );
  }

  Widget _buildFieldList(
    String name,
    List<SourceEditorFieldSpec> fields, {
    bool withTestResult = false,
  }) {
    return SourceEditorTab(
      storageKey: 'rss_source_edit_$name',
      padding: const EdgeInsets.all(16),
      children: [
        for (final spec in fields) _field(spec),
        if (withTestResult && (_testResult != null || _testError != null)) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _testError != null
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (_testError ?? _testResult)!(context.l10n),
              style: TextStyle(
                fontSize: 13,
                color: _testError != null
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _field(SourceEditorFieldSpec spec) {
    return SourceEditorField(
      spec: spec,
      controller: _ctrls[spec.key]!,
      focusNode: _focusNodeFor(spec.key),
    );
  }

  /// WEB_VIEW Tab：4 开关 + 6 文本字段（对标原版 WEB_VIEW 页 10 项）
  Widget _buildWebViewTab() {
    return SourceEditorTab(
      storageKey: 'rss_source_edit_web',
      padding: const EdgeInsets.all(16),
      children: [
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.editorEnableJs),
          value: _enableJs,
          onChanged: (v) => setState(() => _enableJs = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.editorLoadBaseUrl),
          value: _loadWithBaseUrl,
          onChanged: (v) => setState(() => _loadWithBaseUrl = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.editorShowWebLog),
          value: _showWebLog,
          onChanged: (v) => setState(() => _showWebLog = v ?? false),
        ),
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.editorCacheFirst),
          value: _cacheFirst,
          onChanged: (v) => setState(() => _cacheFirst = v ?? false),
        ),
        const SizedBox(height: 8),
        for (final spec in _webFields(context.l10n)) _field(spec),
        const SizedBox(height: 24),
      ],
    );
  }
}
