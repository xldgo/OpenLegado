// source_edit_screen.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// extension _SourceEditActions 承载：保存 / 登录 / 帮助等交互处理。
// 同 library 内可访问 State 私有字段；生命周期（initState/dispose/build）留在主类。
part of 'source_edit_screen.dart';

// ConsumerState.ref 为 protected 成员，extension 分区无法继承其访问域；
// 本文件所有方法均运行于 State 自身（this），受保护访问语义安全。
// ignore_for_file: invalid_use_of_protected_member

extension _SourceEditActions on _SourceEditScreenState {
  /// 将 [BookSource] 展平为 key→文本 映射，供 [_populateFields] 回填控制器。
  Map<String, String> _sourceToValues(BookSource source) {
    String v(String? value) => value ?? '';
    final sr = source.ruleSearch;
    final er = source.ruleExplore;
    final ir = source.ruleBookInfo;
    final tr = source.ruleToc;
    final cr = source.ruleContent;
    final rr = source.ruleReview;
    return {
      // 基本信息（对齐原版 sourceEntities）
      'bookSourceUrl': source.bookSourceUrl,
      'bookSourceName': source.bookSourceName,
      'bookSourceGroup': v(source.bookSourceGroup),
      'bookSourceComment': v(source.bookSourceComment),
      'loginUrl': v(source.loginUrl),
      'loginUi': v(source.loginUi),
      'loginCheckJs': v(source.loginCheckJs),
      'coverDecodeJs': v(source.coverDecodeJs),
      'bookUrlPattern': v(source.bookUrlPattern),
      'header': v(source.header),
      'variableComment': v(source.variableComment),
      'concurrentRate': v(source.concurrentRate),
      'jsLib': v(source.jsLib),
      // 搜索规则
      'searchUrl': v(source.searchUrl),
      's_checkKeyWord': v(sr?.checkKeyWord),
      's_bookList': v(sr?.bookList),
      's_name': v(sr?.name),
      's_author': v(sr?.author),
      's_kind': v(sr?.kind),
      's_wordCount': v(sr?.wordCount),
      's_lastChapter': v(sr?.lastChapter),
      's_intro': v(sr?.intro),
      's_coverUrl': v(sr?.coverUrl),
      's_bookUrl': v(sr?.bookUrl),
      // 发现规则
      'exploreUrl': v(source.exploreUrl),
      'e_bookList': v(er?.bookList),
      'e_name': v(er?.name),
      'e_author': v(er?.author),
      'e_kind': v(er?.kind),
      'e_wordCount': v(er?.wordCount),
      'e_lastChapter': v(er?.lastChapter),
      'e_intro': v(er?.intro),
      'e_coverUrl': v(er?.coverUrl),
      'e_bookUrl': v(er?.bookUrl),
      // 详情规则
      'i_init': v(ir?.init),
      'i_name': v(ir?.name),
      'i_author': v(ir?.author),
      'i_kind': v(ir?.kind),
      'i_wordCount': v(ir?.wordCount),
      'i_lastChapter': v(ir?.lastChapter),
      'i_intro': v(ir?.intro),
      'i_coverUrl': v(ir?.coverUrl),
      'i_tocUrl': v(ir?.tocUrl),
      'i_canReName': v(ir?.canReName),
      'i_downloadUrls': v(ir?.downloadUrls),
      // 目录规则
      't_preUpdateJs': v(tr?.preUpdateJs),
      't_chapterList': v(tr?.chapterList),
      't_chapterName': v(tr?.chapterName),
      't_chapterUrl': v(tr?.chapterUrl),
      't_formatJs': v(tr?.formatJs),
      't_isVolume': v(tr?.isVolume),
      't_updateTime': v(tr?.updateTime),
      't_isVip': v(tr?.isVip),
      't_isPay': v(tr?.isPay),
      't_nextTocUrl': v(tr?.nextTocUrl),
      // 正文规则
      'c_content': v(cr?.content),
      'c_nextContentUrl': v(cr?.nextContentUrl),
      'c_subContent': v(cr?.subContent),
      'c_replaceRegex': v(cr?.replaceRegex),
      'c_title': v(cr?.title),
      'c_sourceRegex': v(cr?.sourceRegex),
      'c_imageStyle': v(cr?.imageStyle),
      'c_imageDecode': v(cr?.imageDecode),
      'c_webJs': v(cr?.webJs),
      'c_payAction': v(cr?.payAction),
      'c_callBackJs': v(cr?.callBackJs),
      // 段评规则（对齐原版 reviewEntities）
      'r_reviewSummaryUrl': v(rr?.reviewSummaryUrl),
      'r_summaryListRule': v(rr?.summaryListRule),
      'r_summaryParagraphIndexRule': v(rr?.summaryParagraphIndexRule),
      'r_summaryCountRule': v(rr?.summaryCountRule),
      'r_summaryParagraphDataRule': v(rr?.summaryParagraphDataRule),
      'r_reviewDetailUrl': v(rr?.reviewDetailUrl),
      'r_reviewDetailNextPageUrl': v(rr?.reviewDetailNextPageUrl),
      'r_detailListRule': v(rr?.detailListRule),
      'r_detailIdRule': v(rr?.detailIdRule),
      'r_detailAvatarRule': v(rr?.detailAvatarRule),
      'r_detailNameRule': v(rr?.detailNameRule),
      'r_detailBadgeRule': v(rr?.detailBadgeRule),
      'r_detailContentRule': v(rr?.detailContentRule),
      'r_reviewQuoteUrl': v(rr?.reviewQuoteUrl),
      'r_replyListRule': v(rr?.replyListRule),
      'r_replyIdRule': v(rr?.replyIdRule),
      'r_replyAvatarRule': v(rr?.replyAvatarRule),
      'r_replyNameRule': v(rr?.replyNameRule),
      'r_replyBadgeRule': v(rr?.replyBadgeRule),
      'r_replyContentRule': v(rr?.replyContentRule),
    };
  }

  /// 从控制器收集字段，构建 [BookSource]。
  ///
  /// 对齐原版 BookSourceEditActivity.getSource：
  /// - 表单字段按 key 覆盖（空串 → null，即清空字段保存）；
  /// - 表单未展示的字段（updateTime 等）从 [_originalSource] 透传，
  ///   避免保存一次编辑即丢失既有规则数据。
  BookSource _buildSource() {
    // 文本（trim 后）
    String t(String key) => _ctrl(key).text.trim();
    // 可空文本：空串归一为 null（对齐原版 takeIf { isNotBlank }）
    String? n(String key) => t(key).isEmpty ? null : t(key);

    final orig = _originalSource;
    final oSr = orig?.ruleSearch;
    final oEr = orig?.ruleExplore;
    final oIr = orig?.ruleBookInfo;
    final oCr = orig?.ruleContent;
    final oRr = orig?.ruleReview;

    return BookSource(
      bookSourceUrl: t('bookSourceUrl'),
      bookSourceName: t('bookSourceName'),
      bookSourceGroup: n('bookSourceGroup'),
      bookSourceType: _bookSourceType,
      enabled: _enabled,
      enabledCookieJar: _cookieJar,
      eventListener: _eventListener,
      customButton: _customButton,
      header: n('header'),
      loginUrl: n('loginUrl'),
      loginUi: n('loginUi'),
      loginCheckJs: n('loginCheckJs'),
      coverDecodeJs: n('coverDecodeJs'),
      bookUrlPattern: n('bookUrlPattern'),
      bookSourceComment: n('bookSourceComment'),
      variableComment: n('variableComment'),
      concurrentRate: n('concurrentRate'),
      jsLib: n('jsLib'),
      // 评审 C1：透传被编辑书源既有 variable（表单不编辑此字段，
      // 避免保存时把已设置的源变量抹掉为空串）
      variable: _preservedVariable,
      enabledExplore: _enabledExplore,
      // 搜索规则
      searchUrl: n('searchUrl'),
      ruleSearch: SearchRule(
        checkKeyWord: n('s_checkKeyWord'),
        bookList: n('s_bookList'),
        name: n('s_name'),
        author: n('s_author'),
        kind: n('s_kind'),
        wordCount: n('s_wordCount'),
        lastChapter: n('s_lastChapter'),
        intro: n('s_intro'),
        coverUrl: n('s_coverUrl'),
        bookUrl: n('s_bookUrl'),
        // 表单未展示字段透传（原版编辑页同样不展示 updateTime）
        updateTime: oSr?.updateTime,
      ),
      // 发现规则
      exploreUrl: n('exploreUrl'),
      ruleExplore: ExploreRule(
        bookList: n('e_bookList'),
        name: n('e_name'),
        author: n('e_author'),
        kind: n('e_kind'),
        wordCount: n('e_wordCount'),
        lastChapter: n('e_lastChapter'),
        intro: n('e_intro'),
        coverUrl: n('e_coverUrl'),
        bookUrl: n('e_bookUrl'),
        updateTime: oEr?.updateTime,
      ),
      // 详情规则
      ruleBookInfo: BookInfoRule(
        init: n('i_init'),
        name: n('i_name'),
        author: n('i_author'),
        kind: n('i_kind'),
        wordCount: n('i_wordCount'),
        lastChapter: n('i_lastChapter'),
        intro: n('i_intro'),
        coverUrl: n('i_coverUrl'),
        tocUrl: n('i_tocUrl'),
        canReName: n('i_canReName'),
        downloadUrls: n('i_downloadUrls'),
        updateTime: oIr?.updateTime,
      ),
      // 目录规则
      ruleToc: TocRule(
        preUpdateJs: n('t_preUpdateJs'),
        chapterList: n('t_chapterList'),
        chapterName: n('t_chapterName'),
        chapterUrl: n('t_chapterUrl'),
        formatJs: n('t_formatJs'),
        isVolume: n('t_isVolume'),
        updateTime: n('t_updateTime'),
        isVip: n('t_isVip'),
        isPay: n('t_isPay'),
        nextTocUrl: n('t_nextTocUrl'),
      ),
      // 正文规则
      ruleContent: ContentRule(
        content: n('c_content'),
        nextContentUrl: n('c_nextContentUrl'),
        subContent: n('c_subContent'),
        replaceRegex: n('c_replaceRegex'),
        title: n('c_title'),
        sourceRegex: n('c_sourceRegex'),
        imageStyle: n('c_imageStyle'),
        imageDecode: n('c_imageDecode'),
        webJs: n('c_webJs'),
        payAction: n('c_payAction'),
        callBackJs: n('c_callBackJs'),
        // 表单未展示的批量配置保留原值，编辑其他规则时不清空。
        contentBatch: oCr?.contentBatch,
        maxBatchSize: oCr?.maxBatchSize,
      ),
      // 段评规则（对齐原版：仅编辑 reviewEntities 展示字段，其余透传）
      ruleReview: ReviewRule(
        enabled: _reviewEnabled,
        reviewUrl: oRr?.reviewUrl,
        avatarRule: oRr?.avatarRule,
        contentRule: oRr?.contentRule,
        postTimeRule: oRr?.postTimeRule,
        voteUpUrl: oRr?.voteUpUrl,
        voteDownUrl: oRr?.voteDownUrl,
        postReviewUrl: oRr?.postReviewUrl,
        postQuoteUrl: oRr?.postQuoteUrl,
        deleteUrl: oRr?.deleteUrl,
        reviewSummaryUrl: n('r_reviewSummaryUrl'),
        summaryListRule: n('r_summaryListRule'),
        summaryParagraphIndexRule: n('r_summaryParagraphIndexRule'),
        summaryCountRule: n('r_summaryCountRule'),
        summaryParagraphDataRule: n('r_summaryParagraphDataRule'),
        reviewDetailUrl: n('r_reviewDetailUrl'),
        reviewDetailNextPageUrl: n('r_reviewDetailNextPageUrl'),
        detailListRule: n('r_detailListRule'),
        detailIdRule: n('r_detailIdRule'),
        detailAvatarRule: n('r_detailAvatarRule'),
        detailNameRule: n('r_detailNameRule'),
        detailBadgeRule: n('r_detailBadgeRule'),
        detailContentRule: n('r_detailContentRule'),
        reviewQuoteUrl: n('r_reviewQuoteUrl'),
        replyListRule: n('r_replyListRule'),
        replyIdRule: n('r_replyIdRule'),
        replyAvatarRule: n('r_replyAvatarRule'),
        replyNameRule: n('r_replyNameRule'),
        replyBadgeRule: n('r_replyBadgeRule'),
        replyContentRule: n('r_replyContentRule'),
      ),
    );
  }

  /// 保存成功后刷新发现页书源缓存（对齐原版 setResult(RESULT_OK) 语义：
  /// 上层页面感知书源变更，立即反映新名称/开关等，避免内存旧对象
  /// 再次打开编辑页把已保存修改回退）
  void _afterSaveRefresh() {
    try {
      ref.read(exploreNotifierProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _saving = true);
    try {
      final source = _buildSource();
      final notifier = ref.read(sourceNotifierProvider.notifier);
      await notifier.saveSource(source);
      _afterSaveRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew ? l10n.bookSourceCreated : l10n.bookSourceSaved,
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sourceSaveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 菜单保留原有顺序与条件，超长内容由标准菜单滚动展示。
  List<AppMenuEntry<String>> _buildMenuItems() {
    return [
      // 登录（对齐 menu_login：仅在配置了登录 URL 时显示）
      if (_ctrl('loginUrl').text.trim().isNotEmpty)
        AppMenuItem(value: 'login', child: Text(context.l10n.login)),
      AppMenuItem(value: 'search', child: Text(context.l10n.search)),
      AppMenuItem(
        value: 'clear_cookie',
        child: Text(context.l10n.clearCookies),
      ),
      AppMenuItem(
        value: 'auto_complete',
        checked: _autoComplete,
        child: Text(context.l10n.autoComplete),
      ),
      AppMenuItem(value: 'copy_source', child: Text(context.l10n.copySource)),
      AppMenuItem(value: 'paste_source', child: Text(context.l10n.pasteSource)),
      AppMenuItem(
        value: 'set_source_variable',
        child: Text(context.l10n.setSourceVariable),
      ),
      AppMenuItem(value: 'import_qr', child: Text(context.l10n.importSourceQr)),
      AppMenuItem(value: 'share_qr', child: Text(context.l10n.shareSourceQr)),
      AppMenuItem(
        value: 'share_str',
        child: Text(context.l10n.shareSourceText),
      ),
      AppMenuItem(value: 'log', child: Text(context.l10n.appLog)),
      AppMenuItem(value: 'help', child: Text(context.l10n.help)),
    ];
  }

  /// overflow 菜单分流（对标原版 source_edit.xml 折叠项）
  Future<void> _handleMenu(String value) async {
    final l10n = context.l10n;
    switch (value) {
      case 'login':
        _openLogin();
      case 'search':
        await _searchWithSource();
      case 'clear_cookie':
        await _clearCookie();
      case 'auto_complete':
        setState(() => _autoComplete = !_autoComplete);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _autoComplete
                  ? l10n.autoCompleteEnabled
                  : l10n.autoCompleteDisabled,
            ),
          ),
        );
      case 'copy_source':
        await _copySource();
      case 'paste_source':
        await _pasteSource();
      case 'set_source_variable':
        await _setSourceVariable();
      case 'import_qr':
        await _importFromQr();
      case 'share_qr':
        await _shareQr();
      case 'share_str':
        await _shareSource();
      case 'log':
        // [UI-FIX v2.0.1 | 2026-08-06] 日志菜单接通 AppLogScreen（对标原版 menu_log → AppLogDialog） — Qoder
        GoRouter.of(context).pushAppRoute(AppRoutes.appLog);
      case 'help':
        _showHelp();
    }
  }

  /// 保存当前书源后，以该源为搜索范围打开搜索页
  /// （对标原版 menu_search → SearchActivity.start(this, source)）
  Future<void> _searchWithSource() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final source = _buildSource();
      await ref.read(sourceNotifierProvider.notifier).saveSource(source);
      _afterSaveRefresh();
      if (!mounted) return;
      final search = ref.read(searchNotifierProvider.notifier);
      search.clearAllFilter();
      search.toggleSource(source.bookSourceUrl);
      await GoRouter.of(context).pushAppRoute(AppRoutes.search);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sourceSearchOpenFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 清除 Cookie（对标原版 menu_clear_cookie → CookieStore.removeCookie）
  Future<void> _clearCookie() async {
    final l10n = context.l10n;
    final url = _ctrl('bookSourceUrl').text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterBookSourceUrlFirst)));
      return;
    }
    try {
      await ref.read(networkServiceProvider).clearCookie(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.cookiesCleared)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.clearCookiesFailed(e.toString()))),
        );
      }
    }
  }

  /// 设置源变量（对标原版 menu_set_source_variable + VariableDialog）
  Future<void> _setSourceVariable() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final source = _buildSource();
      await ref.read(sourceNotifierProvider.notifier).saveSource(source);
      _afterSaveRefresh();
      if (!mounted) return;
      final srcComment = (source.variableComment ?? '').trim();
      final input = await showDialog<String>(
        context: context,
        builder: (ctx) => _SourceVariableDialog(
          title: ctx.l10n.setSourceVariable,
          comment: srcComment.isNotEmpty
              ? srcComment
              : ctx.l10n.sourceVariableHint,
          initialText: _preservedVariable,
        ),
      );
      if (input == null || !mounted) return;
      await ref
          .read(bookSourceRepositoryProvider)
          .setSourceVariable(source.bookSourceUrl, input);
      if (!mounted) return;
      setState(() => _preservedVariable = input);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            input.isEmpty
                ? l10n.sourceVariableCleared
                : l10n.sourceVariableSaved,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sourceVariableSaveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 二维码分享（对标原版 menu_share_qr → shareWithQr）
  Future<void> _shareQr() async {
    final l10n = context.l10n;
    final json = jsonEncode(_buildSource().toJson());
    if (json.length > 2000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.qrTooLong)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) =>
          _QrShareDialog(title: ctx.l10n.shareBookSource, payload: json),
    );
  }

  /// 登录（对标原版 menu_login → SourceLoginActivity：
  /// hasLoginForm → 登录表单对话框；否则 WebView/手动凭据页）
  void _openLogin() {
    final loginUrl = _ctrl('loginUrl').text.trim();
    if (loginUrl.isEmpty && _ctrl('loginUi').text.trim().isEmpty) return;
    // 统一登录入口（V2 动态对话框 / 经典 loginUi 表单 / 手动凭据页）
    // — DeepSeek Harness + UI（2026-08-14 登录表单对齐）
    showSourceLogin(context, ref, _buildSource());
  }

  /// 拷贝源（对标原版 menu_copy_source：JSON 写入剪贴板）
  Future<void> _copySource() async {
    final l10n = context.l10n;
    final json = const JsonEncoder.withIndent('  ')
        .convert(_buildSource().toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
  }

  /// 粘贴源（对标原版 menu_paste_source：解析剪贴板 JSON 回填表单）
  ///
  /// [SOURCE-PARSE-FFI-20261022] 解析统一走 Rust `sourceParse`（与导入同一实现），
  /// Dart 侧不再 `jsonDecode` 预检——两套语法接受范围会导致「导入能过、粘贴过不了」。
  Future<void> _pasteSource() async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.clipboardEmpty)));
      return;
    }
    final source = await _parseSourceJson(text);
    if (!mounted) return;
    if (source == null) return; // 具体错误已由解析入口提示，不再排队显示泛化错误。
    _populateFields(source);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.pastedBookSource(source.bookSourceName))),
    );
  }

  /// 解析书源 JSON 并回填表单；失败时返回 null（错误已就地提示）。
  ///
  /// 粘贴源与二维码导入共用本方法，保证同一份 JSON 在两条入口得到同一结果。
  Future<BookSource?> _parseSourceJson(String json) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      return await ref.read(bookSourceEditServiceProvider).parseSource(json);
    } catch (e) {
      if (!mounted) return null;
      // 错误信息由 Rust 给出（语法 / 结构 / 字段类型可定位），不吞成「不是有效 JSON」
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceParseFailed(e.toString()))),
      );
      return null;
    }
  }

  /// 字符串分享（对标原版 menu_share_str：写缓存文件再分享）
  Future<void> _shareSource() async {
    final l10n = context.l10n;
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(_buildSource().toJson());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bookSource_share.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: l10n.bookSourceShareSubject,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shareFailed(e.toString()))));
    }
  }

  /// 二维码导入（对标原版 menu_qr_code_camera：扫码内容解析回填表单）
  Future<void> _importFromQr() async {
    final l10n = context.l10n;
    // [fix Task#24 | 2026-08-08] 去掉 <String> 泛型，避免 routes 表
    // MaterialPageRoute<dynamic> 运行时强转崩溃 — Qoder
    final raw = await GoRouter.of(context).pushAppRoute(AppRoutes.qrcode);
    final content = raw is String ? raw : null;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (content == null || content.trim().isEmpty) return;

    final trimmed = content.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      // [SOURCE-PARSE-FFI-20261022] 与粘贴源共用同一 Rust 解析回填流程
      final source = await _parseSourceJson(trimmed);
      if (!mounted) return;
      if (source == null) return; // 错误已由 _parseSourceJson 就地提示
      _populateFields(source);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importedBookSource(source.bookSourceName))),
      );
      return;
    }

    if (trimmed.startsWith('legado://')) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sourceProtocolImportHint)),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(l10n.sourceUrlImportHint)));
  }

  /// 显示规则帮助（对标原版 showHelp("ruleHelp")）
  void _showHelp() {
    showHelp(context, HelpAssets.ruleHelp);
  }

  /// 调试源（对标原版 menu_debug_source：保存后进入源调试页）
  Future<void> _debugSource() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final source = _buildSource();
      final notifier = ref.read(sourceNotifierProvider.notifier);
      await notifier.saveSource(source);
      _afterSaveRefresh();
      if (!mounted) return;
      GoRouter.of(context)
          .pushAppRoute(AppRoutes.sourceDebug, extra: source.bookSourceUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sourceDebugFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 全屏代码编辑（对标原版 menu_fullscreen_edit → CodeEditActivity）
  ///
  /// 需当前聚焦某一表单字段；无焦点时提示。JSON 整体编辑见 [_showJsonEdit]。
  Future<void> _showFullscreenEdit() async {
    final l10n = context.l10n;
    final key = _focusedFieldKey;
    if (key == null || !_ctrls.containsKey(key)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.focusSourceFieldFirst)));
      return;
    }
    await _openCodeEditForField(key, title: _fieldLabels[key] ?? key);
  }

  Future<void> _openCodeEditForField(
    String key, {
    required String title,
  }) async {
    await editSourceFieldCode(
      context,
      title: title,
      controller: _ctrl(key),
      focusNode: _focus(key),
    );
  }
}
