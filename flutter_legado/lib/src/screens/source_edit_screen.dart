import '../widgets/app_menu.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/explore/explore_notifier.dart';
import '../providers/providers.dart';
import '../providers/search/search_notifier.dart';
import '../providers/source/source_notifier.dart';
import '../routes.dart';
import '../utils/source_login_entry.dart';
import '../widgets/help/help_assets.dart';
import '../widgets/help/show_help.dart';
import '../utils/source_field_code_edit.dart';
import '../widgets/source_editor.dart';
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
  TextEditingController _ctrl(String key) =>
      _ctrls.putIfAbsent(key, () => TextEditingController());

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
  static const _typeLabels = ['文本', '音频', '图片', '文件', '视频'];

  // ─── 基本信息字段（对齐原版 BookSourceEditActivity sourceEntities 顺序/标签） ───
  static const _basicFields = [
    SourceEditorFieldSpec(
      'bookSourceUrl',
      '源 URL（sourceUrl）',
      required: true,
      maxLines: 1,
    ),
    SourceEditorFieldSpec(
      'bookSourceName',
      '源名称（sourceName）',
      required: true,
      maxLines: 1,
    ),
    SourceEditorFieldSpec('bookSourceGroup', '源分组（sourceGroup）', maxLines: 1),
    SourceEditorFieldSpec(
      'bookSourceComment',
      '源注释（sourceComment）',
      maxLines: 3,
    ),
    SourceEditorFieldSpec('loginUrl', '登录 URL(loginUrl)', maxLines: 3),
    SourceEditorFieldSpec('loginUi', '登录 UI（loginUi）', maxLines: 4),
    SourceEditorFieldSpec('loginCheckJs', '登录检查 JS（loginCheckJs）', maxLines: 4),
    SourceEditorFieldSpec('coverDecodeJs', '封面解密（coverDecodeJs）', maxLines: 4),
    SourceEditorFieldSpec(
      'bookUrlPattern',
      '书籍 URL 正则（bookUrlPattern）',
      maxLines: 2,
    ),
    SourceEditorFieldSpec(
      'header',
      '请求头（header）',
      hint: 'JSON 格式',
      maxLines: 3,
    ),
    SourceEditorFieldSpec(
      'variableComment',
      '变量说明(variableComment)',
      maxLines: 2,
    ),
    SourceEditorFieldSpec('concurrentRate', '并发率（concurrentRate）', maxLines: 1),
    SourceEditorFieldSpec('jsLib', 'jsLib', maxLines: 8),
  ];

  // ─── 搜索规则字段（对齐原版 searchEntities 顺序/标签） ──────────
  static const _searchFields = [
    SourceEditorFieldSpec(
      'searchUrl',
      '搜索地址（url）',
      maxLines: 1,
      hint: '例如：https://example.com/search?q=searchKey',
    ),
    SourceEditorFieldSpec('s_checkKeyWord', '校验关键字（checkKeyWord）'),
    SourceEditorFieldSpec('s_bookList', '书籍列表规则（bookList）'),
    SourceEditorFieldSpec('s_name', '书名规则（name）'),
    SourceEditorFieldSpec('s_author', '作者规则（author）'),
    SourceEditorFieldSpec('s_kind', '分类规则（kind）'),
    SourceEditorFieldSpec('s_wordCount', '字数规则（wordCount）'),
    SourceEditorFieldSpec('s_lastChapter', '最新章节规则（lastChapter）'),
    SourceEditorFieldSpec('s_intro', '简介规则（intro）'),
    SourceEditorFieldSpec('s_coverUrl', '封面规则（coverUrl）'),
    SourceEditorFieldSpec('s_bookUrl', '详情页 URL 规则（bookUrl）'),
  ];

  // ─── 发现规则字段（对齐原版 exploreEntities 顺序/标签） ──────────
  static const _exploreFields = [
    SourceEditorFieldSpec(
      'exploreUrl',
      '发现地址规则（url）',
      maxLines: 3,
      hint: '例如：分类名::https://example.com/sort\n或 url 形式',
    ),
    SourceEditorFieldSpec('e_bookList', '书籍列表规则（bookList）'),
    SourceEditorFieldSpec('e_name', '书名规则（name）'),
    SourceEditorFieldSpec('e_author', '作者规则（author）'),
    SourceEditorFieldSpec('e_kind', '分类规则（kind）'),
    SourceEditorFieldSpec('e_wordCount', '字数规则（wordCount）'),
    SourceEditorFieldSpec('e_lastChapter', '最新章节规则（lastChapter）'),
    SourceEditorFieldSpec('e_intro', '简介规则（intro）'),
    SourceEditorFieldSpec('e_coverUrl', '封面规则（coverUrl）'),
    SourceEditorFieldSpec('e_bookUrl', '详情页 URL 规则（bookUrl）'),
  ];

  // ─── 详情规则字段（对齐原版 infoEntities 顺序/标签） ─────────────
  static const _infoFields = [
    SourceEditorFieldSpec('i_init', '预处理规则（bookInfoInit）'),
    SourceEditorFieldSpec('i_name', '书名规则（name）'),
    SourceEditorFieldSpec('i_author', '作者规则（author）'),
    SourceEditorFieldSpec('i_kind', '分类规则（kind）'),
    SourceEditorFieldSpec('i_wordCount', '字数规则（wordCount）'),
    SourceEditorFieldSpec('i_lastChapter', '最新章节规则（lastChapter）'),
    SourceEditorFieldSpec('i_intro', '简介规则（intro）'),
    SourceEditorFieldSpec('i_coverUrl', '封面规则（coverUrl）'),
    SourceEditorFieldSpec('i_tocUrl', '目录 URL 规则（tocUrl）'),
    SourceEditorFieldSpec('i_canReName', '允许修改书名作者（canReName）'),
    SourceEditorFieldSpec('i_downloadUrls', '下载URL规则(downloadUrls)'),
  ];

  // ─── 目录规则字段（对齐原版 tocEntities 顺序/标签） ─────────────
  static const _tocFields = [
    SourceEditorFieldSpec('t_preUpdateJs', '更新之前 JS（preUpdateJs）'),
    SourceEditorFieldSpec('t_chapterList', '目录列表规则（chapterList）'),
    SourceEditorFieldSpec('t_chapterName', '章节名称规则（ChapterName）'),
    SourceEditorFieldSpec('t_chapterUrl', '章节 URL 规则（chapterUrl）'),
    SourceEditorFieldSpec('t_formatJs', '格式化规则(formatJs)'),
    SourceEditorFieldSpec('t_isVolume', 'Volume 标识（isVolume）'),
    SourceEditorFieldSpec('t_updateTime', '章节信息（ChapterInfo）'),
    SourceEditorFieldSpec('t_isVip', 'VIP 标识（isVip）'),
    SourceEditorFieldSpec('t_isPay', '购买标识（isPay）'),
    SourceEditorFieldSpec('t_nextTocUrl', '目录下一页规则（nextTocUrl）'),
  ];

  // ─── 正文规则字段（对齐原版 contentEntities 顺序/标签） ──────────
  static const _contentFields = [
    SourceEditorFieldSpec('c_content', '正文规则（content）', maxLines: 3),
    SourceEditorFieldSpec('c_nextContentUrl', '正文下一页 URL 规则（nextContentUrl）'),
    SourceEditorFieldSpec('c_subContent', '副文规则（subContent）'),
    SourceEditorFieldSpec('c_replaceRegex', '替换规则（replaceRegex）', maxLines: 4),
    SourceEditorFieldSpec('c_title', '标题（title）'),
    SourceEditorFieldSpec('c_sourceRegex', '资源正则（sourceRegex）'),
    SourceEditorFieldSpec('c_imageStyle', '图片样式（imageStyle）'),
    SourceEditorFieldSpec('c_imageDecode', '图片解密（imageDecode）'),
    SourceEditorFieldSpec('c_webJs', 'WebView JS（webJs）', maxLines: 4),
    SourceEditorFieldSpec('c_payAction', '购买操作（payAction）'),
    SourceEditorFieldSpec('c_callBackJs', '回调操作（callBackJs）'),
  ];

  // ─── 段评规则字段（对齐原版 reviewEntities 顺序/标签） ───────────
  static const _reviewFields = [
    SourceEditorFieldSpec('r_reviewSummaryUrl', '段评统计 URL（reviewSummaryUrl）'),
    SourceEditorFieldSpec('r_summaryListRule', '段评统计列表（summaryListRule）'),
    SourceEditorFieldSpec(
      'r_summaryParagraphIndexRule',
      '段落索引（summaryParagraphIndexRule）',
    ),
    SourceEditorFieldSpec('r_summaryCountRule', '段评数量（summaryCountRule）'),
    SourceEditorFieldSpec(
      'r_summaryParagraphDataRule',
      '段落数据（summaryParagraphDataRule）',
    ),
    SourceEditorFieldSpec('r_reviewDetailUrl', '段评详情 URL（reviewDetailUrl）'),
    SourceEditorFieldSpec(
      'r_reviewDetailNextPageUrl',
      '段评下一页 URL（reviewDetailNextPageUrl）',
    ),
    SourceEditorFieldSpec('r_detailListRule', '段评详情列表（detailListRule）'),
    SourceEditorFieldSpec('r_detailIdRule', '段评 ID（detailIdRule）'),
    SourceEditorFieldSpec('r_detailAvatarRule', '头像（detailAvatarRule）'),
    SourceEditorFieldSpec('r_detailNameRule', '昵称（detailNameRule）'),
    SourceEditorFieldSpec('r_detailBadgeRule', '徽章（detailBadgeRule）'),
    SourceEditorFieldSpec(
      'r_detailContentRule',
      '评论内容协议（detailContentRule）',
      maxLines: 3,
    ),
    SourceEditorFieldSpec('r_reviewQuoteUrl', '段评回复URL（reviewQuoteUrl）'),
    SourceEditorFieldSpec('r_replyListRule', '子评论列表（replyListRule）'),
    SourceEditorFieldSpec('r_replyIdRule', '子评论 ID（replyIdRule）'),
    SourceEditorFieldSpec('r_replyAvatarRule', '子评论头像（replyAvatarRule）'),
    SourceEditorFieldSpec('r_replyNameRule', '子评论昵称（replyNameRule）'),
    SourceEditorFieldSpec('r_replyBadgeRule', '子评论徽章（replyBadgeRule）'),
    SourceEditorFieldSpec(
      'r_replyContentRule',
      '子评论内容协议（replyContentRule）',
      maxLines: 3,
    ),
  ];

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
    return AppScaffold(
      topBar: LegadoAppBar(
        // 标题字号 20sp 与原版 ToolbarTitle 一致；防极端设备字号缩放截断
        title: Text(
          isNew ? '新建书源' : '编辑书源',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (_) => FocusScope.of(context).unfocus(),
          tabs: const [
            Tab(text: '基本'),
            Tab(text: '搜索'),
            Tab(text: '发现'),
            Tab(text: '详情'),
            Tab(text: '目录'),
            Tab(text: '正文'),
          ],
        ),
        actions: [
          // 全屏代码编辑（对齐原版 menu_fullscreen_edit → 编辑内容，图标位）
          IconButton(
            icon: const Icon(Symbols.code_rounded),
            tooltip: '编辑内容',
            // 压缩触控区 48→40dp：给标题留出更多空间（字体放大时标题
            // 保持原版字号完整显示，避免截断/缩放）
            visualDensity: VisualDensity.compact,
            onPressed: _showFullscreenEdit,
          ),
          // 保存（对齐原版 menu_save：仅图标，无文字）
          IconButton(
            icon: const Icon(Symbols.save_rounded),
            tooltip: '保存',
            visualDensity: VisualDensity.compact,
            onPressed: _saving ? null : _save,
          ),
          // 调试源（对齐原版 menu_debug_source，图标位）
          IconButton(
            icon: const Icon(Symbols.bug_report_rounded),
            tooltip: '调试源',
            visualDensity: VisualDensity.compact,
            onPressed: _saving ? null : _debugSource,
          ),
          AppMenuButton<String>(
            tooltip: '更多选项',
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
              _buildFormSection(_basicFields),
            ]),
            _buildEditTab('search', [_buildFormSection(_searchFields)]),
            _buildEditTab('explore', [_buildFormSection(_exploreFields)]),
            _buildEditTab('info', [_buildFormSection(_infoFields)]),
            _buildEditTab('toc', [_buildFormSection(_tocFields)]),
            _buildEditTab('content', [
              _buildFormSection(_contentFields),
              _buildFormSection(_reviewFields, title: '段评规则'),
            ]),
          ],
        ),
      ),
    );
  }
}
