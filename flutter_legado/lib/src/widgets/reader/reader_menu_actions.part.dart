part of 'reader_menu_panel.dart';

/// 当前菜单复用的交互接线；数据处理继续委托现有 Provider 与 Bridge。
mixin _ReaderMenuActions on ConsumerState<ReaderMenuPanel> {
  final _sourceActionMenuController = MenuController();
  BookSource? _sourceMenuSource;
  static const int _hTag = 2;
  static const int _rubyTag = 4;
  bool _sameTitleRemoved = true;
  int? _effectiveReplaceCount;
  String? _flagsLoadedKey;
  bool _paying = false;

  bool _isCurrentChapter(String bookUrl, int index) {
    if (!mounted) return false;
    final state = ref.read(readerNotifierProvider);
    return state.currentBook?.bookUrl == bookUrl &&
        state.currentChapterIndex == index;
  }

  Future<void> _refreshMenuFlags() async {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    if (book == null) return;
    _flagsLoadedKey = '${book.bookUrl}#${state.currentChapterIndex}';
    await _loadLocalFlags(book.bookUrl, state.currentChapterIndex);
  }

  Future<void> _loadLocalFlags(String bookUrl, int chapterIndex) async {
    try {
      // 权威态：caches KV（getSameTitleRemoved）；失败保持默认开启
      final removed = await ref
          .read(readingContentServiceProvider)
          .getSameTitleRemoved(bookUrl, chapterIndex);
      if (mounted && _flagsLoadedKey == '$bookUrl#$chapterIndex') {
        setState(() => _sameTitleRemoved = removed);
      }
    } catch (_) {
      // FFI 不可用时保持默认开启（不再以 SP 镜像为权威态）
    }
    try {
      final rules = await ref
          .read(replaceRuleRepositoryProvider)
          .getEnabledReplaceRules();
      if (mounted) setState(() => _effectiveReplaceCount = rules.length);
    } catch (_) {
      // 替换规则 API 不可用时不展示计数
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _getCloudProgress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final reader = ref.read(readerNotifierProvider);
    final book = reader.currentBook;
    if (book == null) return;
    final syncNotifier = ref.read(syncNotifierProvider.notifier);
    final liveBook = book.copyWith(
      durChapterIndex: reader.currentChapterIndex,
      durChapterPos: reader.currentChapterPos,
      durChapterTitle: reader.currentChapter?.title,
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await syncNotifier.loadConfig();
      final result = await syncNotifier.syncBookProgressForBook(
        liveBook,
        onCloudNewer: (progress) async {
          if (!context.mounted) return;
          final go = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.l10n.readerSyncProgress),
              content: Text(
                '云端进度更新（第 ${progress.durChapterIndex + 1} 章'
                '${progress.durChapterTitle != null && progress.durChapterTitle!.isNotEmpty ? '「${progress.durChapterTitle}」' : ''}）。'
                '\n是否跳转到云端进度？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('跳转'),
                ),
              ],
            ),
          );
          if (go == true &&
              context.mounted &&
              ref.read(readerNotifierProvider).currentBook?.bookUrl ==
                  book.bookUrl) {
            await ref
                .read(readerNotifierProvider.notifier)
                .applyBookProgress(chapterIndex: progress.durChapterIndex);
          }
        },
      );
      if (!context.mounted) return;
      switch (result) {
        case 'uploaded':
          messenger.showSnackBar(
            const SnackBar(content: Text('本地进度较新，已上传到云端')),
          );
        case 'same':
          messenger.showSnackBar(const SnackBar(content: Text('进度已与云端一致')));
        case 'skipped':
          messenger.showSnackBar(
            const SnackBar(content: Text('请先在 WebDAV 设置中开启「同步书籍进度」')),
          );
        case 'cloud':
          break; // 已弹确认框
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('同步进度失败：$e')));
    }
  }

  Future<void> _coverCloudProgress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final reader = ref.read(readerNotifierProvider);
    final book = reader.currentBook;
    if (book == null) return;
    final syncNotifier = ref.read(syncNotifierProvider.notifier);
    final liveBook = book.copyWith(
      durChapterIndex: reader.currentChapterIndex,
      durChapterPos: reader.currentChapterPos,
      durChapterTitle: reader.currentChapter?.title,
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await syncNotifier.loadConfig();
      await syncNotifier.uploadBookProgress(liveBook);
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('进度上传成功')));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('上传进度失败：$e')));
    }
  }

  void _showChangeSourceMenu(BuildContext context, Book book) {
    final state = ref.read(readerNotifierProvider);
    final chapter = state.currentChapter;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(context.l10n.readerChapterChangeSource),
                subtitle: Text(
                  chapter?.title.isNotEmpty == true
                      ? chapter!.title
                      : '仅替换当前章正文',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showChangeChapterSourceSheet(
                    context,
                    bookUrl: book.bookUrl,
                    bookName: book.name,
                    author: book.author,
                    chapterIndex: state.currentChapterIndex,
                    chapterTitle: chapter?.title ?? '',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(context.l10n.readerChangeBookSource),
                subtitle: const Text('切换整本书的书源'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  // [P2-9 | 2026-09-24] 换源改为 await 导航：换源路由
                  // pop 新 bookUrl（发生切换）后重载书/目录并强制刷新
                  // 正文（见 _changeBookSource）；取消（pop null）不做
                  // 任何事。原实现未 await，换源后正文/目录不刷新
                  //（缺陷根因 B）
                  unawaited(_changeBookSource(context, book));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeBookSource(BuildContext context, Book book) =>
      runChangeSourceFlow(ref, context, book);

  Future<void> _updateBookConfig(
    BuildContext context,
    WidgetRef ref,
    ReadConfig Function(ReadConfig config) transform,
  ) async {
    final book = ref.read(readerNotifierProvider).currentBook;
    if (book == null) return;
    final updated = book.copyWith(
      readConfig: transform(book.readConfig ?? const ReadConfig()),
    );
    try {
      await ref.read(bookApiProvider).bookshelfRepository.updateBook(updated);
      final notifier = ref.read(readerNotifierProvider.notifier);
      if (!mounted ||
          ref.read(readerNotifierProvider).currentBook?.bookUrl !=
              book.bookUrl) {
        return;
      }
      notifier.updateCurrentBook(updated);
      await notifier.reloadChapterContent();
    } catch (e) {
      if (context.mounted) _snack(context, '设置保存失败: $e');
    }
  }

  void _toggleReplaceRule(BuildContext context, WidgetRef ref) {
    final book = ref.read(readerNotifierProvider).currentBook;
    final enabled = book?.readConfig?.useReplaceRule ?? true;
    unawaited(
      _updateBookConfig(
        context,
        ref,
        (c) => c.copyWith(useReplaceRule: !enabled),
      ),
    );
    if (context.mounted) {
      _snack(context, enabled ? '已关闭替换规则' : '已开启替换规则');
    }
  }

  void _toggleReSegment(BuildContext context, WidgetRef ref) {
    final book = ref.read(readerNotifierProvider).currentBook;
    final enabled = book?.readConfig?.reSegment ?? false;
    unawaited(
      _updateBookConfig(context, ref, (c) => c.copyWith(reSegment: !enabled)),
    );
    if (context.mounted) {
      _snack(context, enabled ? '已关闭重新分段' : '已开启重新分段');
    }
  }

  void _showImageStyleDialog(BuildContext context, WidgetRef ref) {
    final current = ref
        .read(readerNotifierProvider)
        .currentBook
        ?.readConfig
        ?.imageStyle;
    const options = <String?, String>{
      null: '默认（文字旁显示图片）',
      'full': '图片铺满宽度',
      'text': '仅显示文字',
      'single': '单独成页显示图片',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.editorImageStyle),
        children: [
          RadioGroup<String?>(
            groupValue: current,
            onChanged: (v) {
              Navigator.pop(dialogContext);
              if (v != current) {
                unawaited(
                  _updateBookConfig(
                    context,
                    ref,
                    (c) => c.copyWith(imageStyle: v),
                  ),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in options.entries)
                  RadioListTile<String?>(
                    title: Text(entry.value),
                    value: entry.key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateToc(BuildContext context, WidgetRef ref) async {
    final book = ref.read(readerNotifierProvider).currentBook;
    if (book == null) return;
    if (book.origin == BookType.localTag) {
      _snack(context, '本地书籍无需更新目录');
      return;
    }
    _snack(context, '正在更新目录…');
    try {
      await ref
          .read(bookApiProvider)
          .readingRepository
          .refreshToc(book.bookUrl, book.origin);
      if (!mounted ||
          ref.read(readerNotifierProvider).currentBook?.bookUrl !=
              book.bookUrl) {
        return;
      }
      await ref.read(readerNotifierProvider.notifier).openBook(book);
      if (context.mounted) _snack(context, '目录已更新');
    } catch (e) {
      if (context.mounted) _snack(context, '更新目录失败: $e');
    }
  }

  Future<void> _showEditContentDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    if (book == null) return;
    final chapterIndex = state.currentChapterIndex;
    final title = state.currentChapter?.title ?? '';
    final content = await showDialog<String>(
      context: context,
      builder: (_) => ReaderContentEditDialog(
        chapterTitle: title,
        content: state.chapterContent,
      ),
    );
    if (content == null || !context.mounted) return;
    try {
      final ok = await ref
          .read(bookApiProvider)
          .readingRepository
          .saveChapterContent(
            bookUrl: book.bookUrl,
            chapterIndex: chapterIndex,
            title: title,
            content: content,
          );
      if (!context.mounted) return;
      if (ok && _isCurrentChapter(book.bookUrl, chapterIndex)) {
        await ref.read(readerNotifierProvider.notifier).reloadChapterContent();
      }
      if (context.mounted) _snack(context, ok ? '章节内容已保存' : '章节内容保存失败');
    } catch (e) {
      if (context.mounted) _snack(context, '章节内容保存失败：$e');
    }
  }

  Future<void> _reverseContent(BuildContext context, WidgetRef ref) async {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    if (book == null) return;
    final chapterIndex = state.currentChapterIndex;
    try {
      final content = await ref
          .read(bookApiProvider)
          .readingRepository
          .getChapterContentFull(book.bookUrl, chapterIndex);
      if (content.isEmpty) {
        if (context.mounted) _snack(context, '暂无正文可反转');
        return;
      }
      // 码点级倒序（runes 反转保证 emoji 等补充平面字符安全）
      final reversed = String.fromCharCodes(content.runes.toList().reversed);
      final ok = await ref
          .read(bookApiProvider)
          .readingRepository
          .saveChapterContent(
            bookUrl: book.bookUrl,
            chapterIndex: chapterIndex,
            title: state.currentChapter?.title ?? '',
            content: reversed,
          );
      if (!context.mounted) return;
      if (ok && _isCurrentChapter(book.bookUrl, chapterIndex)) {
        await ref.read(readerNotifierProvider.notifier).reloadChapterContent();
        if (context.mounted) _snack(context, '内容已反转');
      } else {
        _snack(context, '反转内容保存失败');
      }
    } catch (e) {
      if (context.mounted) _snack(context, '反转内容失败: $e');
    }
  }

  static const List<String> _charsets = [
    'UTF-8',
    'GB2312',
    'GB18030',
    'GBK',
    'Unicode',
    'UTF-16',
    'UTF-16LE',
    'ASCII',
  ];

  void _showCharsetDialog(BuildContext context, WidgetRef ref) {
    final book = ref.read(readerNotifierProvider).currentBook;
    if (book == null) return;
    final ctrl = TextEditingController(text: book.charset ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.readerSetCharset),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'charset',
                  hintText: '如 UTF-8 / GBK',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final cs in _charsets)
                    ChoiceChip(
                      label: Text(cs),
                      selected: ctrl.text == cs,
                      onSelected: (_) => setDialogState(() => ctrl.text = cs),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final charset = ctrl.text.trim();
                Navigator.pop(dialogContext);
                if (charset.isEmpty) {
                  _snack(context, '编码不能为空');
                  return;
                }
                unawaited(_applyCharset(context, ref, charset));
              },
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyCharset(
    BuildContext context,
    WidgetRef ref,
    String charset,
  ) async {
    final book = ref.read(readerNotifierProvider).currentBook;
    if (book == null) return;
    final updated = book.copyWith(charset: charset);
    try {
      await ref.read(bookApiProvider).bookshelfRepository.updateBook(updated);
      final notifier = ref.read(readerNotifierProvider.notifier);
      if (!mounted ||
          ref.read(readerNotifierProvider).currentBook?.bookUrl !=
              book.bookUrl) {
        return;
      }
      notifier.updateCurrentBook(updated);
      await notifier.reloadChapterContent();
      if (context.mounted) _snack(context, '已设置编码：$charset');
    } catch (e) {
      if (context.mounted) _snack(context, '设置编码失败: $e');
    }
  }

  void _showHelpDialog(BuildContext context) {
    showHelp(context, HelpAssets.readMenuHelp);
  }

  Future<void> _showSourceMenu(BuildContext context, Book book) async {
    final api = ref.read(bookApiProvider);
    final sourceUrl = book.origin;
    // 查找当前书籍对应书源（失败时仍提供编辑/禁用入口）
    BookSource? source;
    try {
      final sources = await api.bookSourceRepository.getBookSources();
      for (final s in sources) {
        if (s.bookSourceUrl == sourceUrl) {
          source = s;
          break;
        }
      }
    } catch (_) {
      // 书源列表不可用时降级：登录项隐藏，其余入口保留
    }
    if (!context.mounted ||
        !mounted ||
        ref.read(readerNotifierProvider).currentBook?.origin != sourceUrl) {
      return;
    }
    if (source == null) {
      _snack(context, '未找到当前书源');
      return;
    }
    setState(() => _sourceMenuSource = source);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.visible) _sourceActionMenuController.open();
    });
  }

  List<AppMenuEntry<String>> _sourceActionMenuItems(Book book) => [
    if ((_sourceMenuSource?.loginUrl ?? '').trim().isNotEmpty)
      const AppMenuItem(value: 'login', child: Text('登录源')),
    if ((_sourceMenuSource?.ruleContent?.payAction ?? '').trim().isNotEmpty)
      AppMenuItem(
        value: 'chapterPay',
        child: Text(context.l10n.readerPurchaseChapter),
      ),
    AppMenuItem(value: 'editSource', child: Text(context.l10n.editSource)),
    AppMenuItem(
      value: 'disableSource',
      child: Text(context.l10n.readerDisableSource),
    ),
  ];

  Future<void> _handleSourceAction(
    BuildContext context,
    Book book,
    String action,
  ) async {
    final api = ref.read(bookApiProvider);
    final sourceUrl = book.origin;
    final sourceName = (_sourceMenuSource?.bookSourceName ?? book.originName)
        .trim();
    if (!context.mounted) return;
    switch (action) {
      case 'login':
        final source = _sourceMenuSource;
        if (source == null) return;
        final chapterIndex = ref
            .read(readerNotifierProvider)
            .currentChapterIndex;
        // 与书源管理共用表单/V2/WebView 分流及登录信息保存。
        final loggedIn = await showSourceLogin(context, ref, source);
        if (loggedIn && _isCurrentChapter(book.bookUrl, chapterIndex)) {
          await ref
              .read(readerNotifierProvider.notifier)
              .reloadChapterContent();
        }
      case 'chapterPay':
        // [UI-fix v2.0.3 | 2026-08-08] 章节购买接线（契约 §2.43.2） — Qoder
        await _chapterPay(context, book);
      case 'editSource':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SourceEditScreen(sourceUrl: sourceUrl),
          ),
        );
      case 'disableSource':
        try {
          await api.bookSourceRepository.disableBookSource(sourceUrl);
          if (!mounted) return;
          await ref.read(sourceNotifierProvider.notifier).loadSources();
          if (context.mounted) {
            _snack(context, '已禁用书源：$sourceName');
          }
        } catch (e) {
          if (context.mounted) _snack(context, '禁用书源失败: $e');
        }
    }
  }

  Future<void> _chapterPay(BuildContext context, Book book) async {
    if (_paying) return;
    final state = ref.read(readerNotifierProvider);
    final source = _sourceMenuSource;
    final chapter = state.currentChapter;
    if (source == null || chapter == null) {
      _snack(context, '当前章节不可用');
      return;
    }
    final chapterIndex = state.currentChapterIndex;
    _paying = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.readerPurchaseChapter),
          content: Text('是否执行「${chapter.title}」的购买操作？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !context.mounted ||
          !_isCurrentChapter(book.bookUrl, chapterIndex)) {
        return;
      }
      final api = ref.read(bookApiProvider);
      final result = await ref
          .read(sourceActionServiceProvider)
          .chapterPayAction(bookUrl: book.bookUrl, chapterIndex: chapterIndex);
      if (!context.mounted || !_isCurrentChapter(book.bookUrl, chapterIndex)) {
        return;
      }
      switch (result.kind) {
        case ChapterPurchaseKind.url:
          // 购买网页保留书源身份、请求头与 Cookie 接线，不使用无来源的浏览器。
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WebViewLoginScreen(
                repository: api.sourceLoginRepository,
                sourceUrl: source.bookSourceUrl,
                sourceName: source.bookSourceName,
                loginUrl: result.value,
                header: source.header,
                title: '章节购买',
                showLoginActions: false,
              ),
            ),
          );
        case ChapterPurchaseKind.success:
          // Bridge 已失效本章缓存；重新读取后显示已购买的正文。
          await ref
              .read(readerNotifierProvider.notifier)
              .reloadChapterContent();
          if (context.mounted) _snack(context, '购买成功');
        default:
          break;
      }
    } catch (e) {
      if (context.mounted) _snack(context, '章节购买失败：$e');
    } finally {
      _paying = false;
    }
  }

  bool _isEpub(Book? book) {
    if (book == null || book.origin != BookType.localTag) return false;
    final name = (book.originName.isNotEmpty ? book.originName : book.bookUrl)
        .toLowerCase();
    return name.endsWith('.epub');
  }

  bool _hasDelTag(Book? book, int tag) =>
      ((book?.readConfig?.delTag ?? 0) & tag) != 0;

  void _toggleDelTag(BuildContext context, int tag, String label) {
    final book = ref.read(readerNotifierProvider).currentBook;
    final enabled = _hasDelTag(book, tag);
    unawaited(
      _updateBookConfig(
        context,
        ref,
        (c) =>
            c.copyWith(delTag: enabled ? (c.delTag & ~tag) : (c.delTag | tag)),
      ),
    );
    if (context.mounted) {
      _snack(context, enabled ? '已关闭$label' : '已开启$label');
    }
  }

  Future<void> _toggleSameTitleRemoved(BuildContext context) async {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    if (book == null) return;
    final chapterIndex = state.currentChapterIndex;
    final chapterTitle = state.currentChapter?.title ?? '';
    final next = !_sameTitleRemoved;

    // 对齐原版：开启去除且正文无可移除重复标题时提示（权威试算走 FFI）
    if (next && chapterTitle.isNotEmpty) {
      try {
        final raw = await ref
            .read(chapterCacheRepositoryProvider)
            .getCachedChapter(book.bookUrl, chapterIndex);
        final canRemove = await ref
            .read(readingContentServiceProvider)
            .canRemoveSameTitle(chapterTitle, raw);
        if (!canRemove && context.mounted) {
          _snack(context, '未找到可移除的重复标题');
        }
      } catch (_) {
        // 无缓存时跳过提示，仍执行切换
      }
    }

    try {
      await ref
          .read(readingContentServiceProvider)
          .toggleSameTitleRemoved(book.bookUrl, chapterIndex, next);
      if (!mounted || !_isCurrentChapter(book.bookUrl, chapterIndex)) return;
      setState(() => _sameTitleRemoved = next);
      await ref.read(readerNotifierProvider.notifier).reloadChapterContent();
      if (context.mounted) {
        _snack(context, next ? '已去除重复标题' : '该章已保留原标题');
      }
    } catch (e) {
      if (context.mounted) _snack(context, '设置失败: $e');
    }
  }

  void _showEffectiveReplacesDialog(BuildContext context) {
    final count = _effectiveReplaceCount;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('已启用替换规则'),
        content: Text(count != null ? '当前共启用 $count 条替换规则' : '替换规则数据暂不可用'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyChapterUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) _snack(context, '章节链接已复制');
  }

  Future<void> _openUrlInSystemBrowser(BuildContext context, String url) =>
      openReaderChapterUrl(context, url, inSystemBrowser: true);

  Future<void> _showChapterUrlMenu(BuildContext context, String url) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.readerOpenFun),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'inner'),
            child: const Text('内置浏览器打开'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'system'),
            child: const Text('系统浏览器打开'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'copy'),
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'inner':
      case 'system':
        try {
          await ref
              .read(readerSettingsRepositoryProvider)
              .update(chapterInSystemBrowser: choice == 'system');
        } catch (error) {
          debugPrint('章节打开方式保存失败：$error');
          if (context.mounted) {
            _snack(context, '打开方式保存失败，本次仍按所选方式打开');
          }
        }
        if (!context.mounted) return;
        if (choice == 'system') {
          await _openUrlInSystemBrowser(context, url);
        } else {
          Navigator.of(context).pushNamed(
            AppRoutes.browser,
            arguments: <String, String>{'url': url, 'title': '章节链接'},
          );
        }
      case 'copy':
        await _copyChapterUrl(context, url);
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'addBookmark':
        widget.onAddBookmark();
      case 'highlightRule':
        Navigator.pushNamed(context, AppRoutes.highlightRules);
      case 'replace':
        widget.onOpenReplaceRules();
      case 'editContent':
        unawaited(_showEditContentDialog(context, ref));
      case 'getProgress':
        unawaited(_getCloudProgress(context));
      case 'coverProgress':
        unawaited(_coverCloudProgress(context));
      case 'reverseContent':
        unawaited(_reverseContent(context, ref));
      case 'enableReplace':
        _toggleReplaceRule(context, ref);
      case 'sameTitleRemoved':
        unawaited(_toggleSameTitleRemoved(context));
      case 'reSegment':
        _toggleReSegment(context, ref);
      case 'delRubyTag':
        _toggleDelTag(context, _rubyTag, '删除 Ruby 标签');
      case 'delHTag':
        _toggleDelTag(context, _hTag, '删除 H 标签');
      case 'imageStyle':
        _showImageStyleDialog(context, ref);
      case 'updateToc':
        unawaited(_updateToc(context, ref));
      case 'effectiveReplaces':
        _showEffectiveReplacesDialog(context);
      case 'charset':
        _showCharsetDialog(context, ref);
      case 'log':
        Navigator.pushNamed(context, AppRoutes.appLog);
      case 'help':
        _showHelpDialog(context);
    }
  }

  List<AppMenuEntry<String>> _menuItems(Book? book, bool isOnline) => [
    AppMenuItem(
      value: 'addBookmark',
      child: Text(context.l10n.readerBookmarkAdd),
    ),
    AppMenuItem(
      value: 'editContent',
      child: Text(context.l10n.editSourceContent),
    ),
    AppMenuItem(
      value: 'highlightRule',
      child: Text(context.l10n.readerHighlightRuleConfig),
    ),
    AppMenuItem(
      value: 'replace',
      child: Text(context.l10n.readerReplaceRuleTitleSetting),
    ),
    if (ref.watch(syncNotifierProvider).isConfigured) ...[
      const AppMenuDivider(),
      AppMenuItem(
        value: 'getProgress',
        child: Text(context.l10n.readerSyncProgress),
      ),
      AppMenuItem(
        value: 'coverProgress',
        child: Text(context.l10n.readerCoverBookProgress),
      ),
    ],
    const AppMenuDivider(),
    if (isOnline)
      AppMenuItem(
        value: 'reverseContent',
        child: Text(context.l10n.readerReverseContent),
      ),
    AppMenuItem(
      value: 'enableReplace',
      checked: book?.readConfig?.useReplaceRule ?? true,
      child: const Text('启用替换规则'),
    ),
    AppMenuItem(
      value: 'sameTitleRemoved',
      checked: _sameTitleRemoved,
      child: Text(context.l10n.readerRemoveDuplicateTitle),
    ),
    AppMenuItem(
      value: 'reSegment',
      checked: book?.readConfig?.reSegment ?? false,
      child: Text(context.l10n.readerReSegment),
    ),
    if (_isEpub(book)) ...[
      AppMenuItem(
        value: 'delRubyTag',
        checked: _hasDelTag(book, _rubyTag),
        child: const Text('删除 Ruby 标签'),
      ),
      AppMenuItem(
        value: 'delHTag',
        checked: _hasDelTag(book, _hTag),
        child: const Text('删除 H 标签'),
      ),
    ],
    AppMenuItem(
      value: 'imageStyle',
      child: Text(context.l10n.editorImageStyle),
    ),
    if (isOnline)
      AppMenuItem(value: 'updateToc', child: Text(context.l10n.updateToc)),
    if (book != null && !isOnline && !_isEpub(book))
      AppMenuItem(value: 'charset', child: Text(context.l10n.readerSetCharset)),
    const AppMenuItem(value: 'effectiveReplaces', child: Text('已启用替换规则')),
    const AppMenuDivider(),
    AppMenuItem(value: 'log', child: Text(context.l10n.logs)),
    AppMenuItem(value: 'help', child: Text(context.l10n.help)),
  ];
}
