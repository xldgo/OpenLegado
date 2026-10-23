import '../../app/routing/app_navigation.dart';
import '../../app/routing/route_names.dart';
import 'book_source_repository_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/general_settings_provider.dart';
import '../../providers/source_interaction_provider.dart';
import '../../l10n/app_localization.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/app_snack_bar.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../explore/application/explore_notifier.dart';
import '../search/search.dart';
import 'source_notifier.dart';

import '../../utils/source_login_entry.dart';
import '../../widgets/help/help_assets.dart';
import '../../widgets/help/show_help.dart';
import '../../utils/source_field_code_edit.dart';
import '../../widgets/source_editor.dart';
part 'source_edit_screen_load.part.dart';
part 'source_edit_screen_actions.part.dart';
part 'source_edit_screen_builders.part.dart';
part 'source_edit_screen_dialogs.part.dart';

// ↑ 分域 part 文件（体检 §三.16 超长文件拆分）：非生命周期方法按域拆入 extension，
// 零行为变更（同 library 私有成员可访问）。

/// 书源编辑页面
///
/// 对标 Android `BookSourceEditActivity`，编辑书源的全部规则：
/// 基本、搜索、发现、详情、目录、正文六个页签；设置归入基本，段评归入正文。
/// 各页共享字段控制器，保留输入与滚动位置，保存仍使用完整书源对象。
class SourceEditScreen extends ConsumerStatefulWidget {
  /// 书源 URL（编辑模式），null 表示新建
  final String? sourceUrl;

  /// 书源对象（发现页编辑入口直接传入，避免依赖 notifier 已加载
  /// 内存书源列表导致空表单）— DeepSeek Harness + UI（2026-08-14）
  final BookSource? source;

  const SourceEditScreen({super.key, this.sourceUrl, this.source});

  @override
  ConsumerState<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends ConsumerState<SourceEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _savedSnapshot;
  bool _hasChanges = false;
  bool _confirmingExit = false;
  late final TabController _tabController;

  // 字段 GlobalKey 保留供焦点定位和校验使用。
  final Map<String, GlobalKey> _fieldKeys = {};

  /// 首次帮助已展示标志（对标原版 LocalConfig.ruleHelpVersionIsLast）
  static const _ruleHelpShownKey = 'source_rule_help_shown';

  /// 自动补全开关（对标原版 menu_auto_complete，会话级）
  bool _autoComplete = false;

  /// 所有文本字段控制器（按 key 惰性创建）
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _focusedFieldKey;
  final Map<String, String> _fieldLabels = {};

  // 开关状态（非文本字段，对标原版可折叠「设置」面板）
  bool _settingsExpanded = false;
  bool _enabled = true;
  bool _enabledExplore = true;
  bool _reviewEnabled = false;
  bool _cookieJar = false;
  bool _eventListener = false;
  bool _customButton = false;
  int _bookSourceType = 0;

  /// 被编辑书源既有的自定义变量（评审 C1：表单不含 variable 字段，
  /// 保存时透传此值避免编辑任意书源一次即抹掉已设置的源变量；
  /// 粘贴/扫码/全屏编辑回填时随 _populateFields 同步更新）
  String _preservedVariable = '';

  /// 被编辑书源的原始对象（表单未展示字段透传，保存不丢数据）
  BookSource? _originalSource;

  bool get isNew => widget.sourceUrl == null && widget.source == null;

  /// 按 key 惰性获取控制器
  TextEditingController _ctrl(String key) => _ctrls.putIfAbsent(
    key,
    () => TextEditingController()..addListener(_refreshChanges),
  );

  /// 忽略惰性创建的空字段及光标变化，只比较可保存内容。— Codex + UI
  String _snapshot() => jsonEncode([
    Map.fromEntries(
      (_ctrls.entries.where((entry) => entry.value.text.isNotEmpty).toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((entry) => MapEntry(entry.key, entry.value.text)),
    ),
    _enabled,
    _enabledExplore,
    _reviewEnabled,
    _cookieJar,
    _eventListener,
    _customButton,
    _bookSourceType,
    _preservedVariable,
    _originalSource?.toJson(),
  ]);

  void _refreshChanges() {
    final changed = _savedSnapshot != null && _snapshot() != _savedSnapshot;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  void _markSaved() {
    _savedSnapshot = _snapshot();
    _refreshChanges();
  }

  Future<void> _tryExit() async {
    if (_saving || _confirmingExit) return;
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    _confirmingExit = true;
    try {
      final discard = await showConfirmDialog(
        context,
        title: context.l10n.unsavedChanges,
        content: context.l10n.discardSourceChanges,
        confirmText: context.l10n.discard,
        isDestructive: true,
      );
      if (discard && mounted) Navigator.of(context).pop();
    } finally {
      _confirmingExit = false;
    }
  }

  FocusNode _focus(String key) => _focusNodes.putIfAbsent(
    key,
    () => FocusNode()
      ..addListener(() {
        // [B2-C2 2-8] 扁平化后无字段导航条，仅记录焦点字段 key
        if (_focusNodes[key]?.hasFocus == true) {
          _focusedFieldKey = key;
        }
      }),
  );

  /// 书源类型（对标原版 sp_type / @array/source_type）
  static List<String> _typeLabels(AppLocalizations l10n) => [
    l10n.editorText,
    l10n.editorAudio,
    l10n.editorImage,
    l10n.editorFile,
    l10n.editorVideo,
  ];

  // ─── 基本信息字段（对齐原版 BookSourceEditActivity sourceEntities 顺序/标签） ───
  static List<SourceEditorFieldSpec> _basicFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'bookSourceUrl',
      l10n.editorFieldLabel(l10n.editorSourceUrl, 'sourceUrl'),
      required: true,
      singleLine: true,
    ),
    SourceEditorFieldSpec(
      'bookSourceName',
      l10n.editorFieldLabel(l10n.editorSourceName, 'sourceName'),
      required: true,
      singleLine: true,
    ),
    SourceEditorFieldSpec(
      'bookSourceGroup',
      l10n.editorFieldLabel(l10n.editorSourceGroup, 'sourceGroup'),
      singleLine: true,
    ),
    SourceEditorFieldSpec(
      'bookSourceComment',
      l10n.editorFieldLabel(l10n.editorSourceComment, 'sourceComment'),
    ),
    SourceEditorFieldSpec(
      'loginUrl',
      l10n.editorFieldLabel(l10n.editorLoginUrl, 'loginUrl'),
    ),
    SourceEditorFieldSpec(
      'loginUi',
      l10n.editorFieldLabel(l10n.editorLoginUi, 'loginUi'),
    ),
    SourceEditorFieldSpec(
      'loginCheckJs',
      l10n.editorFieldLabel(l10n.editorLoginCheckJs, 'loginCheckJs'),
    ),
    SourceEditorFieldSpec(
      'coverDecodeJs',
      l10n.editorFieldLabel(l10n.editorCoverDecode, 'coverDecodeJs'),
    ),
    SourceEditorFieldSpec(
      'bookUrlPattern',
      l10n.editorFieldLabel(l10n.editorBookUrlPattern, 'bookUrlPattern'),
    ),
    SourceEditorFieldSpec(
      'header',
      l10n.editorFieldLabel(l10n.editorHeader, 'header'),
      hint: l10n.editorJsonHint,
    ),
    SourceEditorFieldSpec(
      'variableComment',
      l10n.editorFieldLabel(l10n.editorVariableComment, 'variableComment'),
    ),
    SourceEditorFieldSpec(
      'concurrentRate',
      l10n.editorFieldLabel(l10n.editorConcurrentRate, 'concurrentRate'),
      singleLine: true,
    ),
    SourceEditorFieldSpec('jsLib', 'jsLib'),
  ];

  // ─── 搜索规则字段（对齐原版 searchEntities 顺序/标签） ──────────
  static List<SourceEditorFieldSpec> _searchFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'searchUrl',
      l10n.editorFieldLabel(l10n.editorSearchUrl, 'url'),
      singleLine: true,
      hint: l10n.editorSearchUrlHint,
    ),
    SourceEditorFieldSpec(
      's_checkKeyWord',
      l10n.editorFieldLabel(l10n.editorCheckKeyword, 'checkKeyWord'),
    ),
    SourceEditorFieldSpec(
      's_bookList',
      l10n.editorFieldLabel(l10n.editorBookList, 'bookList'),
    ),
    SourceEditorFieldSpec(
      's_name',
      l10n.editorFieldLabel(l10n.editorBookName, 'name'),
    ),
    SourceEditorFieldSpec(
      's_author',
      l10n.editorFieldLabel(l10n.editorAuthor, 'author'),
    ),
    SourceEditorFieldSpec(
      's_kind',
      l10n.editorFieldLabel(l10n.editorKind, 'kind'),
    ),
    SourceEditorFieldSpec(
      's_wordCount',
      l10n.editorFieldLabel(l10n.editorWordCount, 'wordCount'),
    ),
    SourceEditorFieldSpec(
      's_lastChapter',
      l10n.editorFieldLabel(l10n.editorLastChapter, 'lastChapter'),
    ),
    SourceEditorFieldSpec(
      's_intro',
      l10n.editorFieldLabel(l10n.editorIntro, 'intro'),
    ),
    SourceEditorFieldSpec(
      's_coverUrl',
      l10n.editorFieldLabel(l10n.editorCoverUrl, 'coverUrl'),
    ),
    SourceEditorFieldSpec(
      's_bookUrl',
      l10n.editorFieldLabel(l10n.editorBookUrl, 'bookUrl'),
    ),
  ];

  // ─── 发现规则字段（对齐原版 exploreEntities 顺序/标签） ──────────
  static List<SourceEditorFieldSpec> _exploreFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'exploreUrl',
      l10n.editorFieldLabel(l10n.editorExploreUrl, 'url'),
      hint: l10n.editorExploreUrlHint,
    ),
    SourceEditorFieldSpec(
      'e_bookList',
      l10n.editorFieldLabel(l10n.editorBookList, 'bookList'),
    ),
    SourceEditorFieldSpec(
      'e_name',
      l10n.editorFieldLabel(l10n.editorBookName, 'name'),
    ),
    SourceEditorFieldSpec(
      'e_author',
      l10n.editorFieldLabel(l10n.editorAuthor, 'author'),
    ),
    SourceEditorFieldSpec(
      'e_kind',
      l10n.editorFieldLabel(l10n.editorKind, 'kind'),
    ),
    SourceEditorFieldSpec(
      'e_wordCount',
      l10n.editorFieldLabel(l10n.editorWordCount, 'wordCount'),
    ),
    SourceEditorFieldSpec(
      'e_lastChapter',
      l10n.editorFieldLabel(l10n.editorLastChapter, 'lastChapter'),
    ),
    SourceEditorFieldSpec(
      'e_intro',
      l10n.editorFieldLabel(l10n.editorIntro, 'intro'),
    ),
    SourceEditorFieldSpec(
      'e_coverUrl',
      l10n.editorFieldLabel(l10n.editorCoverUrl, 'coverUrl'),
    ),
    SourceEditorFieldSpec(
      'e_bookUrl',
      l10n.editorFieldLabel(l10n.editorBookUrl, 'bookUrl'),
    ),
  ];

  // ─── 详情规则字段（对齐原版 infoEntities 顺序/标签） ─────────────
  static List<SourceEditorFieldSpec> _infoFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'i_init',
      l10n.editorFieldLabel(l10n.editorInfoInit, 'bookInfoInit'),
    ),
    SourceEditorFieldSpec(
      'i_name',
      l10n.editorFieldLabel(l10n.editorBookName, 'name'),
    ),
    SourceEditorFieldSpec(
      'i_author',
      l10n.editorFieldLabel(l10n.editorAuthor, 'author'),
    ),
    SourceEditorFieldSpec(
      'i_kind',
      l10n.editorFieldLabel(l10n.editorKind, 'kind'),
    ),
    SourceEditorFieldSpec(
      'i_wordCount',
      l10n.editorFieldLabel(l10n.editorWordCount, 'wordCount'),
    ),
    SourceEditorFieldSpec(
      'i_lastChapter',
      l10n.editorFieldLabel(l10n.editorLastChapter, 'lastChapter'),
    ),
    SourceEditorFieldSpec(
      'i_intro',
      l10n.editorFieldLabel(l10n.editorIntro, 'intro'),
    ),
    SourceEditorFieldSpec(
      'i_coverUrl',
      l10n.editorFieldLabel(l10n.editorCoverUrl, 'coverUrl'),
    ),
    SourceEditorFieldSpec(
      'i_tocUrl',
      l10n.editorFieldLabel(l10n.editorTocUrl, 'tocUrl'),
    ),
    SourceEditorFieldSpec(
      'i_canReName',
      l10n.editorFieldLabel(l10n.editorCanRename, 'canReName'),
    ),
    SourceEditorFieldSpec(
      'i_downloadUrls',
      l10n.editorFieldLabel(l10n.editorDownloadUrls, 'downloadUrls'),
    ),
  ];

  // ─── 目录规则字段（对齐原版 tocEntities 顺序/标签） ─────────────
  static List<SourceEditorFieldSpec> _tocFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      't_preUpdateJs',
      l10n.editorFieldLabel(l10n.editorPreUpdateJs, 'preUpdateJs'),
    ),
    SourceEditorFieldSpec(
      't_chapterList',
      l10n.editorFieldLabel(l10n.editorChapterList, 'chapterList'),
    ),
    SourceEditorFieldSpec(
      't_chapterName',
      l10n.editorFieldLabel(l10n.editorChapterName, 'ChapterName'),
    ),
    SourceEditorFieldSpec(
      't_chapterUrl',
      l10n.editorFieldLabel(l10n.editorChapterUrl, 'chapterUrl'),
    ),
    SourceEditorFieldSpec(
      't_formatJs',
      l10n.editorFieldLabel(l10n.editorFormatJs, 'formatJs'),
    ),
    SourceEditorFieldSpec(
      't_isVolume',
      l10n.editorFieldLabel(l10n.editorIsVolume, 'isVolume'),
    ),
    SourceEditorFieldSpec(
      't_updateTime',
      l10n.editorFieldLabel(l10n.editorChapterInfo, 'ChapterInfo'),
    ),
    SourceEditorFieldSpec(
      't_isVip',
      l10n.editorFieldLabel(l10n.editorIsVip, 'isVip'),
    ),
    SourceEditorFieldSpec(
      't_isPay',
      l10n.editorFieldLabel(l10n.editorIsPay, 'isPay'),
    ),
    SourceEditorFieldSpec(
      't_nextTocUrl',
      l10n.editorFieldLabel(l10n.editorNextTocUrl, 'nextTocUrl'),
    ),
  ];

  // ─── 正文规则字段（对齐原版 contentEntities 顺序/标签） ──────────
  static List<SourceEditorFieldSpec> _contentFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'c_content',
      l10n.editorFieldLabel(l10n.editorContent, 'content'),
    ),
    SourceEditorFieldSpec(
      'c_nextContentUrl',
      l10n.editorFieldLabel(l10n.editorNextContentUrl, 'nextContentUrl'),
    ),
    SourceEditorFieldSpec(
      'c_subContent',
      l10n.editorFieldLabel(l10n.editorSubContent, 'subContent'),
    ),
    SourceEditorFieldSpec(
      'c_replaceRegex',
      l10n.editorFieldLabel(l10n.editorReplaceRegex, 'replaceRegex'),
    ),
    SourceEditorFieldSpec(
      'c_title',
      l10n.editorFieldLabel(l10n.editorTitle, 'title'),
    ),
    SourceEditorFieldSpec(
      'c_sourceRegex',
      l10n.editorFieldLabel(l10n.editorSourceRegex, 'sourceRegex'),
    ),
    SourceEditorFieldSpec(
      'c_imageStyle',
      l10n.editorFieldLabel(l10n.editorImageStyle, 'imageStyle'),
    ),
    SourceEditorFieldSpec(
      'c_imageDecode',
      l10n.editorFieldLabel(l10n.editorImageDecode, 'imageDecode'),
    ),
    SourceEditorFieldSpec(
      'c_webJs',
      l10n.editorFieldLabel(l10n.editorWebJs, 'webJs'),
    ),
    SourceEditorFieldSpec(
      'c_payAction',
      l10n.editorFieldLabel(l10n.editorPayAction, 'payAction'),
    ),
    SourceEditorFieldSpec(
      'c_callBackJs',
      l10n.editorFieldLabel(l10n.editorCallbackJs, 'callBackJs'),
    ),
  ];

  // ─── 段评规则字段（对齐原版 reviewEntities 顺序/标签） ───────────
  static List<SourceEditorFieldSpec> _reviewFields(AppLocalizations l10n) => [
    SourceEditorFieldSpec(
      'r_reviewSummaryUrl',
      l10n.editorFieldLabel(l10n.editorReviewSummaryUrl, 'reviewSummaryUrl'),
    ),
    SourceEditorFieldSpec(
      'r_summaryListRule',
      l10n.editorFieldLabel(l10n.editorSummaryList, 'summaryListRule'),
    ),
    SourceEditorFieldSpec(
      'r_summaryParagraphIndexRule',
      l10n.editorFieldLabel(
        l10n.editorParagraphIndex,
        'summaryParagraphIndexRule',
      ),
    ),
    SourceEditorFieldSpec(
      'r_summaryCountRule',
      l10n.editorFieldLabel(l10n.editorSummaryCount, 'summaryCountRule'),
    ),
    SourceEditorFieldSpec(
      'r_summaryParagraphDataRule',
      l10n.editorFieldLabel(
        l10n.editorParagraphData,
        'summaryParagraphDataRule',
      ),
    ),
    SourceEditorFieldSpec(
      'r_reviewDetailUrl',
      l10n.editorFieldLabel(l10n.editorReviewDetailUrl, 'reviewDetailUrl'),
    ),
    SourceEditorFieldSpec(
      'r_reviewDetailNextPageUrl',
      l10n.editorFieldLabel(
        l10n.editorReviewNextPage,
        'reviewDetailNextPageUrl',
      ),
    ),
    SourceEditorFieldSpec(
      'r_detailListRule',
      l10n.editorFieldLabel(l10n.editorDetailList, 'detailListRule'),
    ),
    SourceEditorFieldSpec(
      'r_detailIdRule',
      l10n.editorFieldLabel(l10n.editorCommentId, 'detailIdRule'),
    ),
    SourceEditorFieldSpec(
      'r_detailAvatarRule',
      l10n.editorFieldLabel(l10n.editorAvatar, 'detailAvatarRule'),
    ),
    SourceEditorFieldSpec(
      'r_detailNameRule',
      l10n.editorFieldLabel(l10n.editorNickname, 'detailNameRule'),
    ),
    SourceEditorFieldSpec(
      'r_detailBadgeRule',
      l10n.editorFieldLabel(l10n.editorBadge, 'detailBadgeRule'),
    ),
    SourceEditorFieldSpec(
      'r_detailContentRule',
      l10n.editorFieldLabel(l10n.editorCommentContent, 'detailContentRule'),
    ),
    SourceEditorFieldSpec(
      'r_reviewQuoteUrl',
      l10n.editorFieldLabel(l10n.editorReviewQuoteUrl, 'reviewQuoteUrl'),
    ),
    SourceEditorFieldSpec(
      'r_replyListRule',
      l10n.editorFieldLabel(l10n.editorReplyList, 'replyListRule'),
    ),
    SourceEditorFieldSpec(
      'r_replyIdRule',
      l10n.editorFieldLabel(l10n.editorReplyId, 'replyIdRule'),
    ),
    SourceEditorFieldSpec(
      'r_replyAvatarRule',
      l10n.editorFieldLabel(l10n.editorReplyAvatar, 'replyAvatarRule'),
    ),
    SourceEditorFieldSpec(
      'r_replyNameRule',
      l10n.editorFieldLabel(l10n.editorReplyName, 'replyNameRule'),
    ),
    SourceEditorFieldSpec(
      'r_replyBadgeRule',
      l10n.editorFieldLabel(l10n.editorReplyBadge, 'replyBadgeRule'),
    ),
    SourceEditorFieldSpec(
      'r_replyContentRule',
      l10n.editorFieldLabel(l10n.editorReplyContent, 'replyContentRule'),
    ),
  ];

  static final _typeCount = _typeLabels(
    lookupAppLocalizations(const Locale('zh')),
  ).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // 直接传入书源对象（发现页编辑入口）时立即回填，不走内存列表查找
    final source = widget.source;
    if (source != null) {
      _populateFields(source);
      setState(() {});
    } else if (!isNew) {
      _loadSource();
    }
    _markSaved();
    // 对标原版 BookSourceEditActivity.onPostCreate：
    // if (!LocalConfig.ruleHelpVersionIsLast) showHelp("ruleHelp")
    _maybeShowFirstHelp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _ctrls.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return PopScope(
      canPop: !_hasChanges && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryExit();
      },
      child: AppScaffold(
        topBar: LegadoAppBar(
          leading: BackButton(onPressed: _tryExit),
          // 标题字号 20sp 与原版 ToolbarTitle 一致；防极端设备字号缩放截断
          title: Text(
            isNew ? context.l10n.newBookSource : context.l10n.editBookSource,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (_) => FocusScope.of(context).unfocus(),
            tabs: [
              Tab(text: context.l10n.editorBasic),
              Tab(text: context.l10n.search),
              Tab(text: context.l10n.discover),
              Tab(text: context.l10n.editorDetails),
              Tab(text: context.l10n.editorChapters),
              Tab(text: context.l10n.editorBookContent),
            ],
          ),
          actions: [
            // 全屏代码编辑（对齐原版 menu_fullscreen_edit → 编辑内容，图标位）
            IconButton(
              icon: const Icon(Symbols.code_rounded),
              tooltip: context.l10n.editSourceContent,
              // 压缩触控区 48→40dp：给标题留出更多空间（字体放大时标题
              // 保持原版字号完整显示，避免截断/缩放）
              visualDensity: VisualDensity.compact,
              onPressed: _showFullscreenEdit,
            ),
            // 保存（对齐原版 menu_save：仅图标，无文字）
            IconButton(
              icon: const Icon(Symbols.save_rounded),
              tooltip: context.l10n.save,
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : _save,
            ),
            // 调试源（对齐原版 menu_debug_source，图标位）
            IconButton(
              icon: const Icon(Symbols.bug_report_rounded),
              tooltip: context.l10n.debugSource,
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : _debugSource,
            ),
            AppMenuButton<String>(
              tooltip: context.l10n.moreOptions,
              itemBuilder: (_) => _buildMenuItems(),
              onSelected: _handleMenu,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEditTab('basic', [
                _buildSettingsSection(),
                _buildFormSection(_basicFields(context.l10n)),
              ]),
              _buildEditTab('search', [
                _buildFormSection(_searchFields(context.l10n)),
              ]),
              _buildEditTab('explore', [
                _buildFormSection(_exploreFields(context.l10n)),
              ]),
              _buildEditTab('info', [
                _buildFormSection(_infoFields(context.l10n)),
              ]),
              _buildEditTab('toc', [
                _buildFormSection(_tocFields(context.l10n)),
              ]),
              _buildEditTab('content', [
                _buildFormSection(_contentFields(context.l10n)),
                _buildFormSection(
                  _reviewFields(context.l10n),
                  title: context.l10n.editorReviewRules,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
