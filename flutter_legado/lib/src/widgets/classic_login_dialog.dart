import '../domain/contracts/source_login_session.dart';
import '../domain/models/explore_action_result.dart';
import '../l10n/app_localization.dart';
import 'app_menu.dart';

import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import '../routes.dart';
import '../domain/contracts/source_login_repository.dart';
import '../services/platform_bridge_service.dart';
import '../utils/error_message.dart';

/// 经典 loginUi 表单登录对话框（对标 Kotlin `SourceLoginDialog`）
///
/// 书源 `loginUi` 为经典 JSON 行协议（非 V2）时渲染：
/// - `text` / `password`：文本输入，预填已保存登录信息；
/// - `select`：下拉（chars 选项）；
/// - `button`：动作按钮，点击执行 `loginUrl JS + action`（`result` 绑定
///   当前表单 JSON，对齐原版 handleButtonClick）；
/// - `toggle`：点击循环 chars。
///
/// 顶栏：✓ 保存登录信息并执行 `login.apply(this)`（对齐原版 menu_ok →
/// login(source)）；⋮ 查看登录头/删除登录头/清除登录信息/日志。
/// 关闭时按原版 onDismiss 语义持久化表单（非空且变化时 putLoginInfo）。
///
/// 动作求值复用发现页 `exploreEvalAction`（jsLib + 书源上下文 setup +
/// ui_action_queue），`java.toast` 等提示经 actions 回放为 SnackBar。
/// — DeepSeek Harness + UI（2026-08-14 登录表单对齐）
class ClassicLoginDialog extends StatefulWidget {
  final SourceLoginRepository? repository;
  final Future<ExploreActionResult> Function({
    required String sourceJson,
    required String actionJs,
  })?
  evaluateAction;
  final BookSource? source;
  final SourceLoginSession? session;

  const ClassicLoginDialog({
    super.key,
    required SourceLoginRepository this.repository,
    required this.evaluateAction,
    required BookSource this.source,
  }) : session = null;
  const ClassicLoginDialog.session({
    super.key,
    required SourceLoginSession this.session,
  }) : repository = null,
       evaluateAction = null,
       source = null;

  @override
  State<ClassicLoginDialog> createState() => ClassicLoginDialogState();
}

/// 经典表单行（对齐 Kotlin RowUi）
class LoginRowUi {
  final String name;
  final String type; // text/password/select/button/toggle
  final String action;
  final String defaultValue;
  final String viewName;
  final List<String> chars;
  final double flexBasisPercent; // style.layout_flexBasisPercent（默认 0.4）
  final double flexGrow; // style.layout_flexGrow（默认 1）

  LoginRowUi.fromJson(Map<String, dynamic> json)
    : name = (json['name'] ?? '').toString(),
      type = (json['type'] ?? 'text').toString(),
      action = (json['action'] ?? '').toString(),
      defaultValue = (json['default'] ?? '').toString(),
      viewName = (json['viewName'] ?? '').toString(),
      chars = (json['chars'] is List)
          ? (json['chars'] as List)
                .whereType<dynamic>()
                .map((e) => e.toString())
                .toList()
          : const [],
      flexBasisPercent = _numOr(json['style']?['layout_flexBasisPercent'], 0.4),
      flexGrow = _numOr(json['style']?['layout_flexGrow'], 1);

  static double _numOr(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n.toDouble();
    }
    return fallback;
  }

  /// 按原版布局规则：basis 占比约 >= 0.9 时整行独占，否则按比例分行
  bool get fullWidth => flexBasisPercent >= 0.9;
}

class ClassicLoginDialogState extends State<ClassicLoginDialog> {
  List<LoginRowUi> _rows = [];
  final Map<String, TextEditingController> _controllers = {};

  /// select/toggle 当前值（key = row name）
  final Map<String, String> _picked = {};
  bool _busy = false;
  bool _loading = true;
  String? _loadError;

  BookSource get source => widget.source!;
  String get _sourceName => widget.session?.name ?? source.bookSourceName;
  Future<String> _getInfo() =>
      widget.session?.getInfo() ??
      widget.repository!.getLoginInfo(source.bookSourceUrl);
  Future<void> _putInfo(String value) =>
      widget.session?.putInfo(value) ??
      widget.repository!.putLoginInfo(source.bookSourceUrl, value);
  Future<String> _getHeader() =>
      widget.session?.getHeader() ??
      widget.repository!.getLoginHeader(source.bookSourceUrl);
  Future<void> _putHeader(String value) =>
      widget.session?.putHeader(value) ??
      widget.repository!.putLoginHeader(source.bookSourceUrl, value);

  /// loginUrl JS（对齐 Kotlin BaseSource.getLoginJs：剥离 `<js>` / `@js:` 包裹）
  String get _loginJs {
    if (widget.session != null) return '';
    final t = (source.loginUrl ?? '').trim();
    if (t.isEmpty) return '';
    final lower = t.toLowerCase();
    if (lower.startsWith('<js>')) {
      final end = t.lastIndexOf('</js>');
      return end > 0 ? t.substring(4, end) : t.substring(4);
    }
    if (lower.startsWith('@js:')) return t.substring(4);
    return t;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 解析 loginUi 行并预填已保存登录信息（对齐 SourceLoginDialog
  /// viewModel.loginInfo → rowUiBuilder 回填）
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loginUi = widget.session != null
          ? await widget.session!.loadUi('{}')
          : source.loginUi?.trim() ?? '';
      List<LoginRowUi> rows;
      if (loginUi.isEmpty || loginUi == '[]') {
        rows = const [];
      } else {
        final decoded = jsonDecode(loginUi);
        if (decoded is! List) throw const FormatException('loginUi 不是数组');
        rows = [
          for (final e in decoded)
            if (e is Map) LoginRowUi.fromJson(Map<String, dynamic>.from(e)),
        ];
      }

      // 预填已保存登录信息（userInfo_<url> JSON）
      var saved = const <String, String>{};
      try {
        final infoJson = await _getInfo();
        if (infoJson.isNotEmpty) {
          final info = jsonDecode(infoJson);
          if (info is Map) {
            saved = {
              for (final e in info.entries)
                if (e.value != null) e.key.toString(): e.value.toString(),
            };
          }
        }
      } catch (_) {}

      for (final row in rows) {
        final savedValue = saved[row.name] ?? '';
        switch (row.type) {
          case 'text' || 'password':
            final ctrl = _controllers.putIfAbsent(
              row.name,
              TextEditingController.new,
            );
            if (ctrl.text.isEmpty &&
                (savedValue.isNotEmpty || row.defaultValue.isNotEmpty)) {
              ctrl.text = savedValue.isNotEmpty ? savedValue : row.defaultValue;
            }
          case 'select':
            _picked[row.name] = savedValue.isNotEmpty
                ? savedValue
                : (row.defaultValue.isNotEmpty
                      ? row.defaultValue
                      : (row.chars.isNotEmpty ? row.chars.first : ''));
          case 'toggle':
            _picked[row.name] = savedValue.isNotEmpty
                ? savedValue
                : (row.defaultValue.isNotEmpty
                      ? row.defaultValue
                      : (row.chars.isNotEmpty ? row.chars.first : ''));
        }
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(e);
        _loading = false;
      });
    }
  }

  /// 表单数据（对齐原版 getLoginData：text/password 行 name→value，
  /// 再并入 select/toggle 当前值）
  Map<String, String> _loginData() {
    final data = <String, String>{};
    for (final row in _rows) {
      switch (row.type) {
        case 'text' || 'password':
          final ctrl = _controllers[row.name];
          data[row.name] = ctrl != null && ctrl.text.isNotEmpty
              ? ctrl.text
              : row.defaultValue;
        case 'select' || 'toggle':
          final v = _picked[row.name];
          if (v != null && v.isNotEmpty) data[row.name] = v;
      }
    }
    return data;
  }

  /// 组合执行脚本：result 绑定表单 JSON + loginUrl JS + 动作
  /// （对齐原版 `evalJS("$loginJS\n$buttonFunctionJS") { put("result", result) }`）
  String _composeScript(String action) {
    final form = jsonEncode(_loginData());
    final loginJs = _loginJs;
    final buffer = StringBuffer('globalThis.result = $form;');
    if (loginJs.isNotEmpty) {
      buffer.write('\n$loginJs');
    }
    if (action.trim().isNotEmpty) {
      buffer.write('\n$action');
    }
    return buffer.toString();
  }

  /// 执行动作 JS 并回放中途 UI（toast/浏览器等，对齐 handleButtonClick）
  Future<bool> _runAction(String action) async {
    final script = _composeScript(action);
    final List<dynamic> actions;
    final session = widget.session;
    if (session != null) {
      final result = await session.execute(script);
      final values = result['actions'];
      actions = values is List ? values : const [];
    } else {
      final result = await widget.evaluateAction!(
        sourceJson: jsonEncode(source.toJson()),
        actionJs: script,
      );
      actions = result.actions;
    }
    if (actions.isNotEmpty) {
      await PlatformBridgeService.instance.dispatchActions(actions);
    }
    return true;
  }

  /// 按钮点击（对齐原版 handleButtonClick：绝对 URL 打开浏览器，否则执行 JS）
  Future<void> _onButtonTap(LoginRowUi row) async {
    final l10n = context.l10n;
    if (_busy) return;
    final action = row.action.trim();
    if (action.isEmpty) return;
    if (_isAbsUrl(action)) {
      await PlatformBridgeService.instance.dispatchActions([
        {'action': 'openUrl', 'url': action},
      ]);
      return;
    }
    setState(() => _busy = true);
    try {
      await _runAction(action);
    } catch (e) {
      _snack(l10n.loginActionFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 顶栏 ✓：保存登录信息 + 执行 login.apply(this)（对齐原版 login(source)）
  Future<void> _onConfirm() async {
    final l10n = context.l10n;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = _loginData();
      if (data.isEmpty) {
        // 空表单 → 清除登录信息（对齐原版 loginData.isEmpty → removeLoginInfo）
        await _putInfo('{}');
      } else {
        await _putInfo(jsonEncode(data));
      }
      if (widget.session?.hasLoginScript ?? _loginJs.isNotEmpty) {
        await _runAction(
          "if (typeof login=='function'){ login.apply(this); } else { throw('Function login not implements!!!') }",
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _snack(l10n.sourceLoginFailed(e.toString()));
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 关闭时持久化（对齐原版 onDismiss：变化且非空 → putLoginInfo）
  Future<void> _close({bool ok = false}) async {
    try {
      final data = _loginData();
      if (data.isNotEmpty) {
        await _putInfo(jsonEncode(data));
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _isAbsUrl(String s) {
    return s.startsWith('http://') || s.startsWith('https://');
  }

  // ─── 菜单项（对齐原版 source_login 菜单） ──────────────────────────

  Future<void> _menuAction(String value) async {
    final l10n = context.l10n;
    switch (value) {
      case 'view_header':
        final header = await _getHeader();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.loginHeader),
            content: SingleChildScrollView(
              child: Text(header.isEmpty ? ctx.l10n.loginNoValue : header),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.close),
              ),
            ],
          ),
        );
      case 'del_header':
        await _putHeader('');
        _snack(l10n.loginHeaderDeleted);
      case 'clear_info':
        await _putInfo('');
        await _putHeader('');
        _snack(l10n.loginInfoCleared);
      case 'log':
        await Navigator.of(context).pushNamed(AppRoutes.appLog);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      // 返回键/手势关闭时持久化登录信息（对齐原版 onDismiss）
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            // 对齐原版 SourceLoginDialog 标题「登录 <源名>」；
            // 无左上关闭按钮（原版仅右上 确认 + 更多选项）
            automaticallyImplyLeading: false,
            title: Text(context.l10n.loginToSource(_sourceName)),
            actions: [
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Symbols.check_rounded),
                // 对齐原版顶栏「确认」
                tooltip: context.l10n.confirmLoginAction,
                onPressed: _busy ? null : _onConfirm,
              ),
              AppMenuButton<String>(
                tooltip: context.l10n.moreOptions,
                onSelected: _menuAction,
                itemBuilder: (ctx) => [
                  AppMenuItem(
                    value: 'view_header',
                    child: Text(ctx.l10n.viewLoginHeader),
                  ),
                  AppMenuItem(
                    value: 'del_header',
                    child: Text(ctx.l10n.deleteLoginHeader),
                  ),
                  AppMenuItem(
                    value: 'clear_info',
                    child: Text(ctx.l10n.clearLoginInfo),
                  ),
                  AppMenuItem(value: 'log', child: Text(ctx.l10n.logs)),
                ],
              ),
            ],
          ),
          body: _buildBody(colorScheme),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.loginFormParseFailed(_loadError!),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(child: Text(context.l10n.sourceLoginFormMissing));
    }

    // 对齐原版 SourceLoginV2Delegate：按 loginUi 数组原序逐行渲染，
    // 文本框/下拉全宽独占一行，按钮按 basisPercent 比例同行（Flexbox
    // 换行语义），按钮不后置收集（否则顺序错乱、被推到视口外）；
    // toggle 行原版 when 无分支直接跳过，此处同样不渲染
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final maxWidth = constraints.maxWidth;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (final row in _rows)
                  if (row.type == 'button')
                    SizedBox(
                      width: row.fullWidth
                          ? maxWidth
                          : (maxWidth - gap) *
                                row.flexBasisPercent.clamp(0.2, 0.9),
                      child: _buildGridButton(row, colorScheme),
                    )
                  else if (row.type != 'toggle')
                    SizedBox(
                      width: maxWidth,
                      child: _buildRow(row, colorScheme),
                    ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 网格按钮（button / toggle）
  Widget _buildGridButton(LoginRowUi row, ColorScheme colorScheme) {
    if (row.type == 'toggle') {
      final current = _picked[row.name] ?? '';
      final name = _displayName(row);
      // Semantics：按钮名进无障碍树（对齐原版原生按钮，uiautomator 可感知）
      return Semantics(
        label: current.isEmpty ? name : '$current $name',
        button: true,
        child: FilledButton.tonal(
          onPressed: _busy
              ? null
              : () {
                  final chars = row.chars.isNotEmpty
                      ? row.chars
                      : const ['开', '关'];
                  final idx = chars.indexOf(current);
                  final next = chars[(idx + 1) % chars.length];
                  setState(() => _picked[row.name] = next);
                  if (row.action.trim().isNotEmpty) {
                    _onButtonTap(row);
                  }
                },
          child: Text(current.isEmpty ? name : '$current $name'),
        ),
      );
    }
    return Semantics(
      label: _displayName(row),
      button: true,
      child: FilledButton.tonal(
        onPressed: _busy ? null : () => _onButtonTap(row),
        child: Text(
          _displayName(row),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildRow(LoginRowUi row, ColorScheme colorScheme) {
    switch (row.type) {
      case 'text':
      case 'password':
        return Semantics(
          label: _displayName(row),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _controllers.putIfAbsent(
                row.name,
                TextEditingController.new,
              ),
              obscureText: row.type == 'password',
              decoration: InputDecoration(labelText: _displayName(row)),
            ),
          ),
        );
      case 'select':
        return Semantics(
          label: _displayName(row),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownMenuFormField<String>(
              initialSelection: _picked[row.name],
              selectOnly: true,
              expandedInsets: EdgeInsets.zero,
              label: Text(_displayName(row)),
              dropdownMenuEntries: [
                for (final c in row.chars)
                  DropdownMenuEntry(value: c, label: c),
              ],
              onSelected: (v) {
                if (v == null) return;
                setState(() => _picked[row.name] = v);
                if (row.action.trim().isNotEmpty) {
                  _onButtonTap(row);
                }
              },
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 显示名（对齐原版 viewName 字面量 `'xxx'` 剥离）
  String _displayName(LoginRowUi row) {
    final v = row.viewName;
    if (v.length >= 3 &&
        v.length <= 19 &&
        v.startsWith("'") &&
        v.endsWith("'")) {
      return v.substring(1, v.length - 1);
    }
    return row.name;
  }
}
