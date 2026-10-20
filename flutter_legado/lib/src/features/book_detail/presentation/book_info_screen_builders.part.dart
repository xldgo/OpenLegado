// book_info_screen.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// extension _BookInfoBuilders 承载：build 之后的各构建方法与菜单/交互处理。
// 同 library 内可访问 State 私有字段；生命周期（initState/dispose/build）留在主类。
part of 'book_info_screen.dart';

// ConsumerState.ref 为 protected 成员，extension 分区无法继承其访问域；
// 本文件所有方法均运行于 State 自身（this），受保护访问语义安全。
// ignore_for_file: invalid_use_of_protected_member

/// [08 元信息区对齐 | 台账 0922 修订] chips 行单项数据（分组/kind/字数）
class _MetaChipSpec {
  const _MetaChipSpec({required this.text, this.onTap, this.onLongPress});
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

/// [08 元信息区对齐 | 台账 0922 修订] chips 行单项（参考 TextCard 观感）：
/// surfaceContainer 底 + onSurfaceVariant 字、圆角 8dp、内边距 横8/纵4、
/// 14sp w500（参考 labelLargeEmphasized=labelLarge+Medium）；
/// 可选点击/长按手势（kind chip 承载原标签行的搜索/JS 回调入口）
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.spec});
  final _MetaChipSpec spec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        spec.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ts.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
    if (spec.onTap == null && spec.onLongPress == null) return chip;
    return GestureDetector(
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}

extension _BookInfoBuilders on _BookInfoScreenState {
  /// P2-2 自定义按钮：SourceCallBack.callBackBtn + 中途 UI 回放
  Future<void> _onCustomButton() async {
    final book = _loadedBook;
    if (book == null) return;
    try {
      final r = await ref
          .read(sourceActionServiceProvider)
          .sourceCallBackBtn(
            event: 'clickCustomButton',
            bookUrl: book.bookUrl,
            bookType: book.bookType,
          );
      if (!r.handled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('未配置回调或回调未接管')));
        }
      }
    } catch (e) {
      debugPrint('自定义按钮失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('自定义按钮执行失败: $e')));
      }
    }
  }

  /// 溢出菜单处理（对标原版 BookInfoActivity.onOptionsItemSelected）
  Future<void> _handleMenu(String value) async {
    final book = _loadedBook;
    switch (value) {
      case 'customBtn':
        await _onCustomButton();
        break;
      case 'refresh':
        // 对齐原版：刷新即含目录更新（在线书走 refreshToc，本地书仅重加载）
        if (book != null && _isOnlineBook(book)) {
          await _refreshToc();
        } else {
          _reload();
        }
        break;
      case 'copyBookUrl':
        if (book != null) {
          final callback = await ref
              .read(sourceActionServiceProvider)
              .sourceCallBackBtn(
                event: 'clickCopyBookUrl',
                bookUrl: book.bookUrl,
                bookType: book.bookType,
                result: book.bookUrl,
              );
          if (callback.handled) break;
          await Clipboard.setData(ClipboardData(text: book.bookUrl));
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已拷贝书籍URL')));
          }
        }
        break;
      case 'copyTocUrl':
        if (book != null) {
          final callback = await ref
              .read(sourceActionServiceProvider)
              .sourceCallBackBtn(
                event: 'clickCopyTocUrl',
                bookUrl: book.bookUrl,
                bookType: book.bookType,
                result: book.tocUrl,
              );
          if (callback.handled) break;
          await Clipboard.setData(ClipboardData(text: book.tocUrl));
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已拷贝目录URL')));
          }
        }
        break;
      case 'canUpdate':
        if (book == null) return;
        // 对齐原版 menu_can_update：内存切换，在架时 saveBook；关闭时清除 updateError
        // — Cursor UI
        final toggledCanUpdate = applyBookInfoCanUpdateToggle(
          book,
          inBookshelf: _inBookshelf,
        );
        _detailNotifier.updateBook(toggledCanUpdate);
        if (_inBookshelf) {
          await ref
              .read(bookshelfRepositoryProvider)
              .updateBook(toggledCanUpdate);
          if (mounted) _reload();
        }
        break;
      case 'splitLongChapter':
        if (book == null) return;
        // splitLongChapter 存于 ReadConfig；对齐原版 toggle 后 loadBookInfo 重载目录
        // — Cursor UI
        final cfg = book.readConfig ?? const ReadConfig();
        final toggledSplit = book.copyWith(
          readConfig: cfg.copyWith(splitLongChapter: !cfg.splitLongChapter),
        );
        if (_inBookshelf) {
          await ref.read(bookshelfRepositoryProvider).updateBook(toggledSplit);
        } else {
          _detailNotifier.updateBook(toggledSplit);
        }
        if (mounted) {
          if (!_inBookshelf) {
            _snack('拆分长章节将在加入书架后生效');
          } else {
            _reload();
          }
        }
        break;
      case 'log':
        // [UI-fix v2.0.1 | 2026-08-06] 日志菜单接通 AppLogScreen（对标原版 menu_log → AppLogDialog） — Qoder
        GoRouter.of(context).pushAppRoute(AppRoutes.appLog);
        break;
      case 'login':
        // [UI-fix v2.0.2 | 2026-08-06] 登录接通书源登录链路（V2 动态协议/旧版凭据页） — Qoder
        await _loginSource();
        break;
      case 'top':
        // [UI-fix v2.0.2 | 2026-08-06] 置顶接通 topBook FFI（对标原版 topBook） — Qoder
        await _topBook();
        break;
      case 'clearCache':
        // [UI-fix v2.0.2 | 2026-08-06] 清缓存接通 clearCache FFI — Qoder
        await _clearCache();
        break;
      case 'cacheDownloads':
        // [UI-fix v2.0.16 | 2026-08-10] 缓存下载队列页（对齐原版 CacheActivity）— Reasonix
        if (!context.mounted) break;
        await GoRouter.of(context).pushAppRoute(AppRoutes.cacheDownloads);
        break;
      case 'deleteAlert':
        // [UI-fix v2.0.3 | 2026-08-08] 删除提醒开关持久化（对齐原版
        // LocalConfig.deleteBookAlert：删除/移出书籍时是否弹确认框） — Qoder
        final next = !_deleteBookAlert;
        try {
          await ref
              .read(bookshelfSettingsRepositoryProvider)
              .update(deleteBookAlert: next);
        } catch (error) {
          if (mounted) _snack('删除提醒设置保存失败，请重试');
        }
        break;
      case 'bookVariable':
        // [UI-fix v2.0.3 | 2026-08-09] 设置书籍变量接通保存链路（Task #39
        // §5.11-4，对齐原版 BookInfoActivity.setBookVariable + setVariable
        // 的 bookUrl 分支：putCustomVariable + saveBook） — Qoder
        await _setBookVariable();
        break;
      case 'sourceVariable':
        // [Task #63 冻结 / #64-65 实现 | 2026-08-10] 设置源变量接通（台账 §5.11-3，对齐原版
        // BookInfoActivity.bookSourceRepository.setSourceVariable + setVariable 的 source 分支：
        // bookSource.setVariable 后保存） — Qoder
        await _setSourceVariable();
        break;
      case 'updateTask':
        // [UI-fix v2.0.3 | 2026-08-09] 创建书籍更新任务接通（Task #39
        // §5.11-2，对齐原版 BookInfoActivity.openBookUpdateTask：
        // findBookUpdateTask 已存在→编辑，否则 buildBookUpdateTask 新建） — Qoder
        await _openBookUpdateTask();
        break;
      case 'upload':
        // [Task #52 | 2026-08-10] §5.11-1：上传至远程接通（对齐原版
        // BookInfoActivity.menu_upload → RemoteBookWebDav.upload：
        // WebDav PUT 本地书籍文件 → book.origin = webDavTag+putUrl → update） — Qoder
        await _uploadToRemote();
        break;
      case 'private':
        if (book == null) return;
        try {
          await ref
              .read(privacyControllerProvider.notifier)
              .setBookPrivate(book, !book.isPrivate);
          if (!mounted) return;
          _detailNotifier.updateBook(book.copyWith(isPrivate: !book.isPrivate));
          await ref.read(bookshelfNotifierProvider.notifier).refresh();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('私密标记保存失败，请重试')));
          }
        }
        break;
      case 'group':
        // [B1 形态对齐 | full-stack-engineer + UI]「分组」由操作宫格收纳进
        // 顶栏 ⋮ 菜单，复用既有 _showChangeGroup（行为不变）
        await _showChangeGroup();
        break;
      default:
        _todo(value);
        break;
    }
  }

  /// 未移植功能提示（占位项，待后续版本对齐原版）
  void _todo(String value) {
    final feature = value;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('「$feature」后续版本支持')));
  }

  /// 设置源变量（Task #63 冻结 / #64-65 实现，台账 §5.11-3，对齐原版 BookInfoActivity
  /// setSourceVariable + setVariable 的 source 分支）
  ///
  /// 原版语义：
  /// - 书源不存在时 toast「书源不存在」直接返回（菜单层已按 hasSource 隐藏，
  ///   此处为二次防护，对齐原版 setSourceVariable 的 source==null 分支）
  /// - 说明文案对齐 getDisplayVariableComment：书源 variableComment
  ///   非空优先展示，否则用默认文案
  /// - 输入框预填当前书源 variable；确认后 setSourceVariable（空串=清除）
  ///   单列 UPDATE 写库，成功后 Toast + 刷新本地书源状态
  Future<void> _setSourceVariable() async {
    final source = _bookSource;
    if (source == null) {
      _snack('书源不存在');
      return;
    }
    // 说明文案（对齐原版 getDisplayVariableComment：书源注释优先）
    final srcComment = (source.variableComment ?? '').trim();
    final comment = srcComment.isNotEmpty
        ? srcComment
        : '源变量可在js中通过source.getVariable()获取';
    // 输入框预填当前书源 variable（对齐原版 source.getVariable 初值；
    // 评审 C1 后 variable 为非空串，无需 ?? 兼容）
    // [Task #70 D1 修复 | 2026-08-10] 重构为自持 StatefulWidget 对话框
    //（_TextPromptDialog 范式）：原实现 controller 在外部作用域创建 +
    // pop 后立即 dispose，退场动画期间触发 _dependents.isEmpty 断言 +
    // OverlayEntry Duplicate GlobalKey 红屏；现 controller 生命周期
    // 绑定对话框子树，确定按钮先取值再 pop 回传 — Qoder
    final input = await showDialog<String>(
      context: _pageContext,
      builder: (ctx) => BookVariableDialog(
        title: '设置源变量',
        comment: comment,
        initialText: source.variable,
      ),
    );
    // 取消（pop 无值）不保存；确定恒保存，空串=清除（对齐原版 setVariable）
    if (input == null || !mounted) return;
    try {
      // 单列 UPDATE 语义（契约 §2.3）：仅改 variable 列，空串=清除；
      // 规避 updateBookSource 全行更新覆盖其它字段的风险
      await ref
          .read(bookSourceRepositoryProvider)
          .setSourceVariable(source.bookSourceUrl, input);
      if (!mounted) return;
      // 刷新本地书源状态（重载页面数据，书源查询自然带出新 variable；
      // 评审 C1：variable 非空串语义，空串即已清除，不再传 null）
      _detailNotifier.updateSource(source.copyWith(variable: input));
      _reload();
      _snack(input.isEmpty ? '源变量已清除' : '源变量已保存');
    } catch (e) {
      debugPrint('设置源变量失败: $e');
      if (mounted) _snack('设置源变量失败: ${errorMessage(e)}');
    }
  }

  /// 上传至远程（Task #52 §5.11-1，对齐原版 RemoteBookWebDav.upload）
  ///
  /// 原版语义（BookInfoActivity.menu_upload → upLoadBook）：
  /// - 仅本地书可见（isLocal = localTag 或 webDavTag，菜单已限定）
  /// - 已有远程地址时先确认（sure_upload），否则直接上传
  /// - WebDav PUT 本地书籍文件到远程 books 目录（rootBookUrl + originName）
  /// - 成功后 book.origin = webDavTag + 远程地址，并刷新 lastCheckTime
  Future<void> _uploadToRemote() async {
    final book = _loadedBook;
    if (book == null) return;
    // 防御：仅本地书支持上传（在线书无本地文件，按原版语义不支持）
    if (_isOnlineBook(book)) {
      _snack('上传至远程仅支持本地书籍');
      return;
    }
    // 前置：读取已保存的 WebDAV 配置（复用 SyncNotifier 既有配置链路）
    final syncNotifier = ref.read(syncNotifierProvider.notifier);
    try {
      await syncNotifier.loadConfig();
    } catch (_) {
      if (mounted) _snack('WebDAV 配置读取失败，请重试');
      return;
    }
    if (!mounted) return;
    final sync = ref.read(syncNotifierProvider);
    if (!sync.isConfigured) {
      // 未配置 → 提示并引导跳转 WebDAV 设置（对齐原版「未配置webDav」异常提示）
      await _showWebDavNotConfiguredDialog();
      return;
    }
    // 已有远程地址 → 确认是否覆盖（对齐原版 sure_upload 对话框）
    if (book.origin.startsWith(BookType.webDavTag)) {
      final confirmed = await showDialog<bool>(
        context: _pageContext,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('已存在远程 webDav 地址，继续上传？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    // 本地书 bookUrl 即本地文件路径（对齐 Rust import_local_book 落库约定）
    final localPath = book.bookUrl;
    final fileName = book.originName.isNotEmpty
        ? book.originName
        : localPath.split(Platform.pathSeparator).last;
    // 远程路径规则对齐原版 RemoteBookWebDav：rootBookUrl(books/) + originName；
    // path 相对 remote_dir，Rust 侧 full_url = url + remote_dir + path
    final remotePath = 'books/$fileName';
    _snack('正在上传至远程…');
    // [Task #55 F9 | 2026-08-10] 上传与 origin 回写分两段 try/catch：
    // 回写失败时提示「上传成功但保存记录失败」而非误报「上传失败」 — Qoder
    try {
      await ref
          .read(webDavServiceProvider)
          .webdavUploadFile(syncNotifier.connection, remotePath, localPath);
    } catch (e) {
      debugPrint('上传至远程失败: $e');
      if (mounted) _snack('上传失败: ${errorMessage(e)}');
      return;
    }
    if (!mounted) return;
    try {
      // 回写 book.origin（webDav 标记 + 远程完整地址）；从库中读回完整 Book
      // 再 copyWith，防全行覆盖（与 _setBookVariable 同模式）
      final full =
          await ref.read(bookshelfRepositoryProvider).getBook(book.bookUrl) ??
          book;
      final remoteUrl =
          '${sync.webDavUrl}${syncNotifier.normalizedRemoteDir}$remotePath';
      await ref
          .read(bookshelfRepositoryProvider)
          .updateBook(
            full.copyWith(
              origin: BookType.webDavTag + remoteUrl,
              // 对齐原版：刷新最后检查时间，使之比远程书籍的时间新
              lastCheckTime: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      if (!mounted) return;
      _reload();
      _snack('上传至远程成功');
    } catch (e) {
      debugPrint('上传成功但保存记录失败: $e');
      if (mounted) _snack('上传成功但保存记录失败，请重试');
    }
  }

  /// WebDAV 未配置引导对话框（确认后跳转 WebDAV 设置页）
  Future<void> _showWebDavNotConfiguredDialog() async {
    final goSettings = await showDialog<bool>(
      context: _pageContext,
      builder: (ctx) => AlertDialog(
        title: const Text('未配置 WebDAV'),
        content: const Text('上传至远程需要先配置 WebDAV 服务器信息'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    // 异步对话框返回后先检查 mounted，再跳转
    if (goSettings == true && mounted) {
      GoRouter.of(context).pushAppRoute(AppRoutes.webdavSettings);
    }
  }

  /// SnackBar 轻提示（统一入口）
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 设置书籍变量（对齐原版 setBookVariable + setVariable 的 bookUrl 分支）
  ///
  /// 弹输入对话框（含说明文案，对齐原版 VariableDialog 的 comment 展示：
  /// 书源 variableComment 非空优先，否则用默认提示），确认后把变量
  /// 写入 Book 并经 update_book 保存。
  ///
  /// [fix Task#45 | 2026-08-09] 对齐原版 BaseBook.putCustomVariable /
  /// getCustomVariable 语义（M4）：variable 为 JSON Map 串，自定义变量
  /// 挂 "custom" 键；输入框初值取 map['custom']，保存时回写该键
  /// （空输入移除键）后 jsonEncode 整体写回。另补原版 inBookshelf
  /// 守卫（M5）：非在架时不 saveBook，避免 upsert 进 books 表 — Qoder
  ///
  /// 防坑：update_book 为全行 UPDATE，保存前必须基于从库中读回的完整
  /// Book 对象（含 readConfig 等字段）仅修改 variable 后回写，
  /// 禁止用页面缓存的不完整对象覆盖。
  Future<void> _setBookVariable() async {
    final book = _loadedBook;
    final source = _bookSource;
    if (book == null || source == null) {
      _snack('书源不存在');
      return;
    }
    // 说明文案（对齐原版 getDisplayVariableComment：书源注释优先）
    final srcComment = (source.variableComment ?? '').trim();
    final comment = srcComment.isNotEmpty
        ? srcComment
        : '书籍变量可在js中通过book.getVariable("custom")获取';
    // 输入框初值：解析 variable JSON Map 取 custom 键（解析失败视为空 Map）
    final customInit = _parseVariableMap(book.variable)['custom'];
    // [Task #70 D1 修复 | 2026-08-10] 同 _setSourceVariable：重构为自持
    // StatefulWidget 对话框，消除外部 controller 提前 dispose 隐患 — Qoder
    final input = await showDialog<String>(
      context: _pageContext,
      builder: (ctx) => BookVariableDialog(
        title: '设置书籍变量',
        comment: comment,
        initialText: customInit?.toString() ?? '',
      ),
    );
    if (input == null || !mounted) return;
    // 原版 inBookshelf 守卫：仅在架时 saveBook，否则无条件 updateBook
    // 会把非在架书 upsert 进 books 表（M5）
    if (!_inBookshelf) {
      _snack('请先加入书架');
      return;
    }
    try {
      // 从库中读回完整 Book（含 readConfig 等）仅改 variable 后回写
      final full =
          await ref.read(bookshelfRepositoryProvider).getBook(book.bookUrl) ??
          book;
      // putCustomVariable 语义：其余键原样保留，仅回写 custom 键
      final varMap = _parseVariableMap(full.variable);
      if (input.isEmpty) {
        varMap.remove('custom');
      } else {
        varMap['custom'] = input;
      }
      await ref
          .read(bookshelfRepositoryProvider)
          .updateBook(full.copyWith(variable: jsonEncode(varMap)));
      if (!mounted) return;
      _reload();
      _snack('书籍变量已保存');
    } catch (e) {
      debugPrint('保存书籍变量失败: $e');
      if (mounted) _snack('保存书籍变量失败');
    }
  }

  /// 解析 variable 为可变 Map（非法/空串视为空 Map，
  /// 对齐原版 getVariableMap 解析失败回落空表的容错）
  Map<String, dynamic> _parseVariableMap(String? variable) {
    final raw = (variable ?? '').trim();
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 解析失败视为空 Map
    }
    return <String, dynamic>{};
  }

  /// 创建书籍更新任务（对齐原版 openBookUpdateTask）
  ///
  /// 先经 findBookUpdateTask 查该书是否已有更新任务：
  /// - 已存在 → 携 editTaskId 跳转 AutoTaskScreen 定位并进入该任务编辑；
  /// - 不存在 → 用 buildBookUpdateTask 构建默认任务（任务名对齐原版
  ///   auto_task_book_update_name：更新 %s），携 newTask 进入创建流程。
  Future<void> _openBookUpdateTask() async {
    final book = _loadedBook;
    if (book == null) return;
    final notifier = ref.read(autoTaskNotifierProvider.notifier);
    // findBookUpdateTask 基于 notifier 内任务列表匹配，先静默加载确保最新
    await notifier.loadTasks(silent: true);
    if (!mounted) return;
    final existing = await notifier.findBookUpdateTask(
      bookUrl: book.bookUrl,
      bookName: book.name,
      bookAuthor: book.author,
    );
    if (!mounted) return;
    if (existing != null) {
      final id = existing.id;
      await GoRouter.of(context).pushAppRoute(
        AppRoutes.autoTasks,
        extra: AutoTaskRouteArgs(editTaskId: id),
      );
      return;
    }
    final built = await notifier.buildBookUpdateTask(
      bookUrl: book.bookUrl,
      bookName: book.name,
      bookAuthor: book.author,
      // [fix Task#45 | 2026-08-09] 文案对齐原版 auto_task_book_update_name
      // （「更新 %s」含空格）— Qoder
      name: '更新 ${book.name}',
    );
    if (!mounted) return;
    if (built == null) {
      _snack('创建任务失败');
      return;
    }
    await GoRouter.of(context).pushAppRoute(
      AppRoutes.autoTasks,
      extra: AutoTaskRouteArgs(newTask: built.toJson()),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Book book,
    List<BookChapter> chapters,
  ) {
    final cs = Theme.of(context).colorScheme;
    // [08 元信息区元素集对齐 | 台账 0922 修订] 版块顺序对齐参考 08：
    // ① chips 行（分组 chip 条件显示 + kind chips + 字数，TextCard 观感）→
    // ②四按钮卡 → ③在读/最新/共N章三行块 → ④简介（面板内）。
    // 参考 08 无独立「目录：」行、「分组：」行、「🏷️ 标签行」——三行均已
    // 移除/收编：分组信息入 ① chips 行（仅当书有非空分组；无分组不显示
    // 「未分组」，参考 groupNames 非空才渲染分组 chip）；目录入口保留于
    // ②「查看目录」卡；kind 信息即 ① chips 行逐项（原 🏷️ 行承载的逐 tag
    // 点击搜索/长按 JS 回调迁至 chip 手势，功能不丢）。章数不入 chips，
    // 由 ③「共 N 章」行承载（参考同源：章数只出现在共 N 章行）。
    final kinds = _buildKindLabels(book);
    // [UI-fix v2.0.6 | 2026-08-08] 移除详情页内嵌「搜索章节」框与完整章节列表，
    // 对齐原版 activity_book_info（详情页不含目录列表，目录由 tv_toc_view 跳转
    // 独立 TocActivity 查看）。详情页仅保留封面卡 + 信息面板（含目录行显示当前
    // 章节名 + 查看目录按钮）。封面虚化背景层（见 _buildPage）仅透过顶部透明的
    // _buildHeader 封面区显现；信息面板起铺不透明 cs.surface 盖住虚化，底部用
    // SliverFillRemaining 续铺纯色，避免短内容时下方透出虚化封面。 — Qoder
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // [UI_SYNC_REFACTOR B4] 折叠顶栏（对标参考仓 BookInfoTransparentTopAppBar
        // 双态：顶部全透明 / 下滑 surfaceContainer 玻璃色；collapsedFraction 由
        // 滚动监听驱动，actions 经 TopBarActionStyler 统一注入样式）
        ValueListenableBuilder<double>(
          valueListenable: _topCollapse,
          builder: (context, t, _) {
            final ui = UiSettingsScope.of(context, UiSettingsAspect.topBar);
            final topStyle = ui.topBarButtonStyle;
            final topMerge = ui.mergeTopBarActions;
            final barColor = Color.lerp(
              Colors.transparent,
              cs.surfaceContainer,
              t,
            );
            final fg = Color.lerp(cs.onPrimary, cs.onSurface, t);
            // [PARITY C1 D10] 三钮裸图标：参考 08 顶栏铅笔/分享/⋮ 为 hero 图上
            // 的裸图标（无圆形容器底，深色描边）；我方原为 tonal 圆钮
            // （surfaceContainerHigh 底）。→ 动作区强制 plain（复用书架页
            // actionsStyle: plain 机制，仅本详情页），并单独注入 onSurface
            // 前景：顶栏透明期 foregroundColor=onPrimary（近白）在浅色 hero
            // 上不可见，参考为深色图标。leading 返回钮仍走 glass 圆底（参考同）。
            final actionsFg = cs.onSurface;
            return SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: barColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: fg,
              iconTheme: IconThemeData(color: fg),
              actionsIconTheme: IconThemeData(color: actionsFg),
              leading: LegadoAppBar.shouldShowBack(context)
                  ? TopBarActionStyler.styleActions(
                      context,
                      [
                        IconButton(
                          icon: const Icon(Symbols.arrow_back_rounded),
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ],
                      style: t < 0.5 ? TopBarButtonStyle.glass : topStyle,
                      merge: false,
                    ).first
                  : null,
              // 折叠后展示书名（对齐参考仓 TransparentTopAppBar title=书名）
              title: t > 0.5
                  ? Text(
                      book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              // [PARITY C1 D10] 动作三钮固定 plain（参考=裸图标）；merge 仍随
              // 用户设置（与书架页 plain 机制一致）
              actions: TopBarActionStyler.styleActions(
                context,
                _buildTopBarActions(context),
                style: TopBarButtonStyle.plain,
                merge: topMerge,
              ),
            );
          },
        ),
        // 头部两栏（封面左置 110×160 + 信息右置；[U10-U12] 版块顺序重排后
        // 头部仅保留两栏，标签行/在读最新块/聚合行按参考序独立成 sliver）
        SliverToBoxAdapter(
          child: BookMetaCard(
            book: book,
            onChangeCover: () => _openChangeCover(book),
            onPreviewCover: () => _previewCover(book),
            onNameTap: () => _openSearch(book.name, event: 'clickBookName'),
            onNameLongPress: () =>
                _sourceCallBackSearch('longClickBookName', book.name),
            onAuthorTap: () => _openSearch(book.author, event: 'clickAuthor'),
            onAuthorLongPress: () =>
                _sourceCallBackSearch('longClickAuthor', book.author),
            onSourceTap: _isOnlineBook(book)
                ? () => _openSourceEdit(book)
                : null,
            onChangeSource: () => _showChangeSourceDialog(book),
          ),
        ),
        // [08 元信息区对齐 | 台账 0922 修订] ① chips 行：分组 chip（条件）+
        // kind chips + 字数 chip（对标参考 BookInfoHeader LazyRow/TextCard；
        // 整行无数据不渲染；章数项已去除——由 ③「共 N 章」行承载）
        SliverToBoxAdapter(child: _buildKindChipRow(context, book, kinds)),
        // 操作区：加入书架、查看目录、书源和设置分组。
        SliverToBoxAdapter(
          child: BookActionButtons(
            inBookshelf: _inBookshelf,
            onToggleShelf: () => _toggleShelf(book),
            onOpenToc: _openTocScreen,
            onChangeSource: () => _showChangeSourceDialog(book),
            onChangeGroup: _showChangeGroup,
          ),
        ),
        // [U10 | 台账 0917 批三] ③ 在读/最新/共N章 三行块（原置于四按钮
        // 之前，参考 08 排在四按钮之后；U9 在读/最新行 + D4 共N章单行，
        // 缺数据行不渲染，共N章行恒渲染）
        SliverToBoxAdapter(
          child: Column(
            // 原头部 Column 为 start 对齐，此处保持逐行自带左距 13dp
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BookReadingStatus(book: book, chapters: chapters)],
          ),
        ),
        // [UI_SYNC_REFACTOR S3] Characters/RelatedBooks 区块骨架（已授权；
        // 数据链需后端调研——见 UI_ONE_TO_ONE_CLONE_PLAN_20260905.md §〇，
        // 无数据时整段隐藏=缺省降级）
        ..._buildCharactersSection(context, book),
        ..._buildRelatedBooksSection(context, book),
        // ④ 简介面板（[08 元信息区对齐 | 台账 0922 修订] 原 ④ 标签行 /
        // ⑥ 分组行 / 目录行已移除或收编入 ① chips 行，面板内仅余简介；
        // 书名/作者/来源两栏区在 BookMetaCard）
        SliverToBoxAdapter(child: _buildSummaryPanel(context, book)),
        // 底部续铺纯色：内容不足一屏时填满剩余视口，避免透出封面虚化层
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(color: cs.surface),
        ),
        // [LAYOUT_MOTION_AUDIT L3] 底部避让 88dp（FAB）+ 120dp：内容尾部留白防遮挡
        const SliverToBoxAdapter(child: SizedBox(height: 88 + 120)),
      ],
    );
  }

  /// 顶部头部区（B1 形态对齐：参考版「封面左置 + 信息右置」两栏）
  /// - 左：110×160 圆角 3 封面卡（点击换封面 / 长按预览大图行为不变）
  /// - 右：信息列（书名 titleLarge 加粗 / 作者 / 来源=书源名，交互行为不变）
  /// - [U10-U12 | 台账 0917 批三] 标签行/在读最新块/聚合行不再置于头部，
  ///   按参考 08 版块序独立成 sliver（_buildBody 中 ①③④ 位）
  /// — full-stack-engineer + UI

  /// [PARITY C1 D4][P2-21] 章节信息单行：「共 N 章 | 未读 / 已读 N 章 /
  /// 已读完」（对齐参考 08 BookInfoSummary 行；替代原两态绿字版式）。
  /// 章数取 book.totalChapterNum 优先、回落实际章节数；
  /// 状态三态（与参考 Kotlin when 分支同源，durChapterIndex 为 0 基）：
  /// - 未读：durChapterIndex == 0 且 durChapterPos == 0（与书架页未读判据
  ///   bookshelf_screen.dart 同源）
  /// - 已读完：durChapterIndex + 1 == 章数 且 章数 > 0（参考版 Kotlin
  ///   内字面量「已读完」）
  /// - 已读 N 章：N = durChapterIndex + 1（0 基 +1，参考 read_chapter_index）
  /// 排版对齐参考 Row(spacedBy(8.dp))：章数 primary + w700（PIL 取样
  /// 共字首形墨量 0.185 > 已字 0.160，与参考 Bold 判定一致），分隔「|」
  /// 与状态词 secondary（原绿色字面量 0xFF4CAF50 与实机取样
  /// (181,204,186) 不符，改主题角色色，随激活调色板渲染——与参考版同源
  /// 行为）。

  /// [08 元信息区对齐 | 台账 0922 修订] chips 行（对标参考 08
  /// BookInfoHeader 的 LazyRow/TextCard chips 行）：
  /// - 分组 chip：仅当书有非空分组时渲染（参考 groupNames 非空才渲染；
  ///   无分组不显示、不显「未分组」——参考 dump 全书无分组即无该 chip）；
  ///   分组名取值复用原 `_groupText` 掩码过滤逻辑（bookshelfNotifier 分组
  ///   ∩ book.group 位掩码），多组以 ',' 连排单 chip（参考 joinToString(",")）
  /// - kind chips：每个分类标签独立一 chip（参考 kindLabels itemsIndexed，
  ///   逐 chip 与参考一致；原「评分/类型/完结态」特殊解析取消——参考对
  ///   kind 原样逐项渲染，如「9.9分」「已完结」亦为普通 chip）；
  ///   逐 chip 保留原 🏷️ 标签行手势（点击→按 kind 搜索、长按→JS 回调，
  ///   功能迁自移除的标签行，功能不丢；参考 chip 无手势，此为保留既有
  ///   入口的等价实现）
  /// - 字数 chip：Rust 预格式化 wordCount（「142.20万字」形态，参考
  ///   upKind 将 wordCount 并入 kind 列表成 chip），isMeaningfulText 守卫
  /// - 章数 chip：去除（参考章数只出现在「共 N 章」行，由 ③ 三行块承载，
  ///   chips 不再重复）
  /// chip 形态（参考 TextCard 默认量值）：surfaceContainer 底 +
  /// onSurfaceVariant 字、圆角 8dp、内边距 横8/纵4、chip 间距 8dp、
  /// 行左右 13dp（与封面左缘对齐）、超宽横向滚动（参考 LazyRow）
  Widget _buildKindChipRow(
    BuildContext context,
    Book book,
    List<String> kinds,
  ) {
    final groupNames = _groupNamesFor(book);
    final chips = <_MetaChipSpec>[
      if (groupNames.isNotEmpty) _MetaChipSpec(text: groupNames.join(',')),
      for (final kind in kinds)
        _MetaChipSpec(
          text: kind,
          onTap: () => _openSearch(
            kind,
            sourceUrl: book.origin,
            event: 'clickBookLabel',
          ),
          onLongPress: () => _sourceCallBackLabel('longClickBookLabel', kind),
        ),
      if (isMeaningfulText(book.wordCount))
        _MetaChipSpec(text: book.wordCount!.trim()),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final chip in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MetaChip(spec: chip),
              ),
          ],
        ),
      ),
    );
  }

  /// 分组名（book.group 位掩码 ∩ 书架分组）——原 `_groupText` 的取值逻辑
  /// 抽出复用；空列表 = 无分组（chips 行不渲染分组 chip，不显示「未分组」）
  List<String> _groupNamesFor(Book book) {
    final groups = ref.read(bookshelfNotifierProvider).groups;
    return groups
        .where((g) => g.groupId > 0 && (book.group & g.groupId) != 0)
        .map((g) => g.groupName)
        .toList();
  }

  /// [UI_SYNC_REFACTOR S3] Characters 区块骨架（已授权；数据链后端调研中，
  /// 无数据隐藏=缺省降级）
  List<Widget> _buildCharactersSection(BuildContext context, Book book) {
    // 数据源（参考 BookInfoViewModel.characters）后端调研登记：
    // UI_ONE_TO_ONE_CLONE_PLAN_20260905.md §〇；接通前恒为空
    const List<({String name, String role})> characters = [];
    if (characters.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('角色', style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in characters)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(label: Text(c.name)),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// [UI_SYNC_REFACTOR S3] RelatedBooks 区块骨架（同上，后端调研中）
  List<Widget> _buildRelatedBooksSection(BuildContext context, Book book) {
    const List<Book> relatedBooks = [];
    if (relatedBooks.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('相关书籍', style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    ];
  }

  /// 信息面板（[08 元信息区对齐 | 台账 0922 修订] 对标参考 08
  /// BookInfoSummary：面板内仅「简介」（参考 08 面板无标签行、无独立
  /// 分组行/目录行——标签信息已收编进 chips 行、分组信息入 chips 行
  /// 条件 chip、目录入口保留于四按钮「查看目录」卡）；
  /// 书名/作者/来源两栏区在 BookMetaCard，B1 形态对齐）
  Widget _buildSummaryPanel(BuildContext context, Book book) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        // iOS sheet 风格大圆角顶部
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // [LAYOUT_MOTION_AUDIT L3] 内容边距 18→16（全局水平边距统一 16dp）
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [08 元信息区对齐 | 台账 0922 修订] ④ 简介（对标参考 BookInfoSummary
          // 简介段；原「🏷️ 标签行 / 分组：行 / 目录：行」已按参考 08 元素集
          // 移除/收编——见 _buildKindChipRow 注释与台账 0922 修订节）
          _buildIntro(context, book),
        ],
      ),
    );
  }

  /// 分类标签（本地书追加文件大小，对齐原版 upKinds）— Cursor UI
  List<String> _buildKindLabels(Book book) {
    final kinds = (book.kind ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        // [U4 | 台账 0917] 未渲染模板残留（{{$.xxx}}）/ NaN 脏数据视为
        // 无数据不渲染（Rust 解析层 normalize_js_rule_result 已同源拒收，
        // 此处为渲染层兜底：第三方书源 JS 字符串拼接产物可绕过清洗到达 UI）
        .where(isMeaningfulText)
        .toList();
    if (!_isOnlineBook(book)) {
      final stat = ref
          .watch(fileMetadataProvider(LocalBookStore.resolveSync(book.bookUrl)))
          .value;
      if (stat != null && stat.size > 0) kinds.add(_formatFileSize(stat.size));
    }
    return kinds;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 跳转搜索（对齐原版 SearchActivity.start；JS 回调接管时不执行默认搜索）
  Future<void> _openSearch(
    String query, {
    String? sourceUrl,
    String event = 'clickBookName',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final book = _loadedBook;
    final handled = await _sourceCallBackSearch(event, q);
    if (handled || !mounted) return;
    final resolvedSource = sourceUrl != null && sourceUrl.isNotEmpty
        ? sourceUrl
        : book != null && _isOnlineBook(book)
        ? book.origin
        : null;
    final args = SearchRouteArgs(
      query: q,
      sourceUrls: resolvedSource == null ? null : [resolvedSource],
    );
    await GoRouter.of(context).pushAppRoute(AppRoutes.search, extra: args);
  }

  /// 返回 true 表示 JS 回调已接管，不应再执行默认动作
  Future<bool> _sourceCallBackSearch(String event, String result) async {
    final book = _loadedBook;
    if (book == null || result.trim().isEmpty) return false;
    try {
      final r = await ref
          .read(sourceActionServiceProvider)
          .sourceCallBackBtn(
            event: event,
            bookUrl: book.bookUrl,
            bookType: book.bookType,
            result: result,
          );
      return r.handled;
    } catch (e) {
      debugPrint('SourceCallBack $event 失败: $e');
      return false;
    }
  }

  Future<void> _sourceCallBackLabel(String event, String kind) async {
    await _sourceCallBackSearch(event, kind);
  }

  /// 编辑书源（对齐原版 tvOrigin → BookSourceEditActivity）
  Future<void> _openSourceEdit(Book book) async {
    if (!_isOnlineBook(book)) return;

    BookSource? source = _bookSource;
    if (source == null || source.bookSourceUrl != book.origin) {
      source = await _findSourceByOrigin(book.origin);
    }
    if (source == null) {
      _snack('书源不存在');
      return;
    }
    if (!mounted) return;
    await GoRouter.of(context)
        .pushAppRoute(AppRoutes.sourceEdit, extra: source);
    if (mounted) _reload();
  }

  /// 更换封面（对齐原版 ivCover → ChangeCoverDialog.coverChangeTo）
  Future<void> _openChangeCover(Book book) async {
    final result = await GoRouter.of(context)
        .pushAppRoute(AppRoutes.changeCover, extra: book);
    if (result is! String || result.isEmpty || !mounted) return;
    final updated = book.copyWith(customCoverUrl: result);
    _detailNotifier.updateBook(updated);
    if (_inBookshelf) {
      try {
        await ref.read(bookshelfRepositoryProvider).updateBook(updated);
      } catch (e) {
        debugPrint('保存封面失败: $e');
      }
    }
  }

  /// 封面长按预览（对齐原版 PhotoDialog）
  Future<void> _previewCover(Book book) async {
    final url = book.customCoverUrl ?? book.coverUrl;
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    await showDialog<void>(
      context: _pageContext,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: url.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: url,
                  cacheManager: CoverCache.instance.manager,
                  cacheKey: url,
                  fit: BoxFit.contain,
                )
              : Image.file(File(url), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context, Book book) {
    final raw = book.customIntro ?? book.intro;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    // [UI-fix v2.0.7 | 2026-08-08] 展示层清洗：剥离书源 intro 自带的「简介：」前缀
    // （原版直接显示正文无前缀），清洗后为空则不渲染简介区 — Qoder
    final intro = _cleanIntro(raw);
    if (intro.isEmpty) return const SizedBox.shrink();
    return BookExpandableText(text: intro);
  }

  /// 清洗简介正文：剥离开头的「简介：」「简介 :」等前缀
  /// （兼容全/半角冒号及前后空白，仅剥离一次；对齐原版无前缀直接显示正文）
  /// [UI-fix v2.0.7 | 2026-08-08] — Qoder
  String _cleanIntro(String raw) {
    return raw.replaceFirst(
      RegExp(r'^[\s\u3000]*简介[\s\u3000]*[：:][\s\u3000]*'),
      '',
    );
  }

  // [B1 形态对齐 | full-stack-engineer + UI] 底部固定双按钮栏（加书架/阅读）已移除：
  // 阅读入口改右下浮动胶囊（_buildReadFab）；加书架/移出书架入口保留在四宫格第一格
  //（_buildActionCards），功能不丢失（原版 fl_action 双钮为参考版已替换形态）。

  /// 更新目录（对标原版 refreshToc；从底部按钮迁入溢出菜单）
  Future<void> _refreshToc() async {
    final book = _loadedBook;
    if (book == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final chapters = await _detailNotifier.refreshChapters();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('目录已更新，共 ${chapters.length} 章')));
      if (_inBookshelf) {
        _reload();
      }
    } catch (e) {
      if (!mounted) return;
      BookSource? source;
      try {
        final sources = await ref
            .read(bookSourceRepositoryProvider)
            .getBookSources();
        for (final s in sources) {
          if (s.bookSourceUrl == book.origin) {
            source = s;
            break;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      if (isSourceLoginRequiredError(e)) {
        await promptSourceLoginIfNeeded(_pageContext, error: e, source: source);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 打开独立目录页（对齐原版 tv_toc_view → TocActivityResult），
  /// 未在架时先 saveBook（对齐原版点击目录会保存 book）— Cursor UI
  Future<void> _openTocScreen() async {
    final book = _loadedBook;
    if (book == null) return;
    if (_chapters.isEmpty) {
      _snack('目录为空');
      return;
    }
    if (!_inBookshelf) {
      try {
        await ref
            .read(bookshelfRepositoryProvider)
            .addBook(
              book.copyWith(bookType: book.bookType | BookType.notShelf),
            );
      } catch (e) {
        debugPrint('打开目录前保存书籍失败: $e');
      }
    }
    if (!mounted) return;
    final result = await GoRouter.of(context)
        .pushAppRoute(AppRoutes.toc, extra: book);
    if (!mounted) return;
    if (result is int) {
      await _openReader(context, book, result);
    }
  }

  /// 加入书架 / 移出书架（对标原版 tv_shelf 切换逻辑）
  Future<void> _toggleShelf(Book book) async {
    final notifier = ref.read(bookshelfNotifierProvider.notifier);
    if (_inBookshelf) {
      // [UI-fix v2.0.3 | 2026-08-08] 移出书架按「删除提醒」开关弹确认框
      // （对齐原版 deleteBook + LocalConfig.deleteBookAlert） — Qoder
      if (_deleteBookAlert) {
        final confirmed = await showDialog<bool>(
          context: _pageContext,
          builder: (ctx) => AlertDialog(
            title: const Text('移出书架'),
            content: Text('确定将《${book.name}》移出书架吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      // [F1-hunt F3 | 2026-09-24] 按 notifier 返回结果分支：DB 写失败时
      // 不翻 _inBookshelf、不弹成功提示，改弹失败提示（项目规则：用户
      // 可见的失败必须有提示；修复前无论成败都提示「已移出书架」）
      final ok = await notifier.removeBook(book.bookUrl);
      if (!mounted) return;
      if (!ok) {
        final err = ref.read(bookshelfNotifierProvider).error;
        _snack(err != null ? '移出书架失败：$err' : '移出书架失败');
        return;
      }
      _detailNotifier.updateShelfMembership(false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('《${book.name}》已移出书架')));
    } else {
      // 清除 notShelf 位转正：之前阅读时可能已以 notShelf 临时落库，
      // addBook 走原地 UPDATE 安全 upsert（不会级联删章节），同时清掉标记进书架。
      // [F1-hunt F3 | 2026-09-24] 按结果分支：写库失败不得提示「已加入
      // 书架」、不得翻 _inBookshelf（假成功根因），改弹失败提示
      final ok = await notifier.addBook(
        book.copyWith(bookType: book.bookType & ~BookType.notShelf),
      );
      if (!mounted) return;
      if (!ok) {
        final err = ref.read(bookshelfNotifierProvider).error;
        _snack(err != null ? '加入书架失败：$err' : '加入书架失败');
        return;
      }
      _detailNotifier.updateShelfMembership(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('《${book.name}》已加入书架')));
    }
  }

  /// 换组（对标原版 tv_change_group → BookGroupDialog，单选菜单实现）
  Future<void> _showChangeGroup() async {
    final book = _loadedBook;
    if (book == null) return;
    final groups = ref
        .read(bookshelfNotifierProvider)
        .groups
        .where((g) => g.groupId > 0)
        .toList();
    if (!mounted) return;
    final selected = await showDialog<int>(
      context: _pageContext,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择分组'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('未分组'),
          ),
          for (final g in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g.groupId),
              child: Text(g.groupName),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final updated = book.copyWith(group: selected);
    // 对齐原版 upGroup：在架 saveBook；未在架且 groupId>0 则 addToBookshelf — Cursor UI
    if (_inBookshelf) {
      await ref.read(bookshelfRepositoryProvider).updateBook(updated);
    } else if (selected > 0) {
      // [F1-hunt F3 | 2026-09-24] 同 _toggleShelf：写库失败不得把本地
      // 状态翻成在架（假成功），改弹失败提示
      final ok = await ref
          .read(bookshelfNotifierProvider.notifier)
          .addBook(
            updated.copyWith(bookType: updated.bookType & ~BookType.notShelf),
          );
      if (!mounted) return;
      if (ok) {
        _detailNotifier.updateShelfMembership(true);
      } else {
        final err = ref.read(bookshelfNotifierProvider).error;
        _snack(err != null ? '加入书架失败：$err' : '加入书架失败');
      }
    } else if (mounted) {
      _detailNotifier.updateBook(updated);
    }
    if (mounted) _reload();
  }

  // ===== [UI-fix v2.0.2 | 2026-08-06] 登录 / 置顶 / 清缓存 — Qoder =====

  /// 书源登录（对标 Kotlin BookInfoActivity menu_login）：
  /// 统一入口 showSourceLogin（V2 动态对话框 / 旧版手动凭据页）
  /// — 2026-08-14 发现页修复 R2 提取公共入口
  Future<void> _loginSource() async {
    final book = _loadedBook;
    if (book == null) return;
    if (book.origin == BookType.localTag ||
        book.origin.startsWith(BookType.webDavTag)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('本地书籍不支持书源登录')));
      return;
    }

    BookSource? source;
    try {
      final sources = await ref
          .read(bookSourceRepositoryProvider)
          .getBookSources();
      for (final s in sources) {
        if (s.bookSourceUrl == book.origin) {
          source = s;
          break;
        }
      }
    } catch (e) {
      debugPrint('获取书源失败: $e');
    }
    if (!mounted) return;
    if (source == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未找到本书对应的书源')));
      return;
    }
    final ok = await showSourceLogin(_pageContext, ref, source);
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('登录成功')));
    }
  }

  /// 置顶（对标 Kotlin BookInfoViewModel.topBook；原版仅置顶无取消）
  Future<void> _topBook() async {
    final book = _loadedBook;
    if (book == null) return;
    try {
      await ref.read(bookshelfRepositoryProvider).topBook(book.bookUrl);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已置顶')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('置顶失败: $e')));
      }
    }
  }

  /// 清除缓存（对标 Kotlin BookInfoViewModel.clearCache；原版无确认框）
  Future<void> _clearCache() async {
    final book = _loadedBook;
    if (book == null) return;
    try {
      final callback = await ref
          .read(sourceActionServiceProvider)
          .sourceCallBackBtn(
            event: 'clickClearCache',
            bookUrl: book.bookUrl,
            bookType: book.bookType,
          );
      if (callback.handled) return;
      final deleted = await ref
          .read(chapterCacheRepositoryProvider)
          .clearBookCache(book.bookUrl);
      await CacheService.clearSameTitleRemovedFlags();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已清除 $deleted 条章节缓存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清除缓存失败: $e')));
      }
    }
  }

  // ===== 操作 =====

  Future<void> _openReader(
    BuildContext context,
    Book book,
    int chapterIndex,
  ) async {
    if (_openingReader) return;
    _openingReader = true;
    try {
      final prepared = await ref
          .read(bookDetailServiceProvider)
          .prepareReading(book, chapterIndex);
      if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final container = ProviderScope.containerOf(context);
      final bookToRead = prepared.book;
      final route = BookOpenUtils.routeForTypeBits(prepared.typeBits);
      if (BookOpenUtils.needsReaderNotifier(route)) {
        container.read(readerNotifierProvider.notifier).openBook(bookToRead);
        // [UI-fix v2.0.11 | 2026-08-10] 阅读返回后重新加载详情数据 — Reasonix
        if (!context.mounted) return;
        await GoRouter.of(context).pushAppRoute(
          route,
          extra:
              BookCoverHero.originFor(context, bookToRead.bookUrl) ??
              bookToRead,
        );
      } else {
        if (!context.mounted) return;
        await GoRouter.of(context).pushAppRoute(
          route,
          extra: BookOpenUtils.argumentsForRoute(route, bookToRead),
        );
      }
      if (mounted) {
        _reload();
      }
    } finally {
      _openingReader = false;
    }
  }

  /// 打开换源页面，换源成功后用新的 bookUrl 重新加载详情页
  Future<void> _showChangeSourceDialog(Book book) async {
    // 关闭换源面板后按新地址替换详情页，保留原结果语义。— Codex + UI
    final result = await GoRouter.of(context)
        .pushAppRoute(AppRoutes.changeSource, extra: book);
    if (!mounted) return;
    final newBookUrl = result is String ? result : null;
    // 换源成功后 bookUrl 会变化，需要用新 URL 替换当前详情页
    if (newBookUrl != null && newBookUrl.isNotEmpty) {
      GoRouter.of(context).replaceAppRoute(
        AppRoutes.bookInfo,
        extra: book.copyWith(bookUrl: newBookUrl),
      );
    }
  }
}
