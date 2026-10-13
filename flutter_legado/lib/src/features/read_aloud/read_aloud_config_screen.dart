import 'http_tts_login.dart';

import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/models.dart';
import '../../providers/audio/audio_notifier.dart';
import 'http_tts_seed.dart';
import 'http_tts_repository_provider.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/system_tts_settings_dialog.dart';

import 'package:flutter_legado/src/platform/tts/system_tts.dart';

import '../../widgets/help/help_assets.dart';
import '../../widgets/help/show_help.dart';

/// 朗读引擎配置页面
///
/// 管理 HTTP TTS 朗读引擎：列表展示、新增、编辑、删除。
class ReadAloudConfigScreen extends ConsumerStatefulWidget {
  const ReadAloudConfigScreen({super.key});

  @override
  ConsumerState<ReadAloudConfigScreen> createState() =>
      _ReadAloudConfigScreenState();
}

class _ReadAloudConfigScreenState extends ConsumerState<ReadAloudConfigScreen> {
  List<HttpTts> _engines = [];
  bool _loading = true;

  /// 当前选中 HTTP TTS 引擎 ID；null = 未选中 HTTP TTS 引擎
  int? _selectedEngineId;

  /// 是否选中系统 TTS
  bool _selectedIsSystem = false;

  /// 是否存在可写书级的当前书（「书」按钮可用性；无书时禁用）
  bool _hasBook = false;

  @override
  void initState() {
    super.initState();
    _loadEngines();
  }

  Future<void> _loadEngines() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(httpTtsRepositoryProvider);
      // [D3 | 2026-10-03] 首启导入原版 httpTTS 种子（版本门控），
      // 与 dict/rss/txtToc 对齐：进入配置页即可见默认数据
      await ensureDefaultHttpTts(api);
      final list = await api.getHttpTts();
      final notifier = ref.read(audioNotifierProvider.notifier);
      // [引擎双持久化 | 2026-10-04] 初始选中态 = 有效引擎（书级优先、空则
      // 全局回退），优先以数值 engineId 匹配，避免同 URL 不同 Header 的引擎串选
      final effectiveUrl = await notifier.loadEffectiveTtsEngineUrl();
      final effectiveId = await notifier.resolveTtsEngineId();

      int? selectedId;
      bool selectedIsSystem = false;
      if (effectiveUrl == systemTtsEngineUrl) {
        selectedIsSystem = true;
      } else if (effectiveId != null && list.any((e) => e.id == effectiveId)) {
        selectedId = effectiveId;
      } else if (effectiveUrl.isNotEmpty) {
        final match = list
            .where(
              (e) =>
                  normalizeTtsEngineUrl(e.url) == effectiveUrl ||
                  e.url == effectiveUrl,
            )
            .firstOrNull;
        selectedId = match?.id;
      }

      if (!mounted) return;
      setState(() {
        _engines = list;
        _selectedEngineId = selectedId;
        _selectedIsSystem = selectedIsSystem;
        _hasBook = notifier.hasCurrentBook;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载朗读引擎失败: $e')));
      }
    }
  }

  Future<void> _loginEngine(HttpTts engine) async {
    try {
      await showHttpTtsLogin(context, ref, engine);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登录失败：$error')));
      }
    }
  }

  Future<void> _deleteEngine(HttpTts engine) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(httpTtsRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除朗读引擎'),
        content: Text('确定要删除「${engine.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await api.deleteHttpTts(engine.id);
      await _loadEngines();
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _addOrEditEngine([HttpTts? existing]) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(httpTtsRepositoryProvider);

    final result = await showDialog<HttpTts>(
      context: context,
      builder: (ctx) => _TtsEditDialog(engine: existing),
    );

    if (result == null) return;

    try {
      if (existing != null) {
        await api.updateHttpTts(result);
      } else {
        await api.addHttpTts(result);
      }
      await _loadEngines();
      messenger.showSnackBar(
        SnackBar(content: Text(existing != null ? '已更新' : '已添加')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  bool get _hasSelection => _selectedIsSystem || _selectedEngineId != null;

  /// 「书」按钮：只写当前书 readConfig.ttsEngine
  ///
  /// 对齐原版 SpeakEngineDialog.kt:164-170（`ReadBook.book?.setTtsEngine(...)`，
  /// 不改全局值）；无当前书时不写并如实提示（原版空安全 no-op，本项目页面
  /// 需要可见反馈）。
  Future<void> _applyBookEngine() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(audioNotifierProvider.notifier);
    bool ok = false;
    if (_selectedIsSystem) {
      ok = await notifier.setBookTtsEngine(systemTtsEngineUrl);
    } else if (_selectedEngineId != null) {
      final selected = _engines
          .where((e) => e.id == _selectedEngineId)
          .firstOrNull;
      if (selected == null) return;
      ok = await notifier.setBookTtsEngine(selected.url, engineId: selected.id);
    } else {
      return;
    }
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('未打开书籍，无法设为本书引擎')));
      return;
    }
    setState(() => _hasBook = true);
    messenger.showSnackBar(const SnackBar(content: Text('已设为本书引擎')));
  }

  /// 「全局」按钮：先清书级覆盖再写全局
  ///
  /// 对齐原版 SpeakEngineDialog.kt:171-177（`setTtsEngine(null)` +
  /// `AppConfig.ttsEngine = ttsEngine`）。
  Future<void> _applyGlobalEngine() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (_selectedIsSystem) {
      await notifier.setGlobalTtsEngine(systemTtsEngineUrl);
    } else if (_selectedEngineId != null) {
      final selected = _engines
          .where((e) => e.id == _selectedEngineId)
          .firstOrNull;
      if (selected == null) return;
      await notifier.setGlobalTtsEngine(selected.url, engineId: selected.id);
    } else {
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('已设为全局引擎')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSystem = ref.read(systemTtsServiceProvider).isSupported;

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: const Text('朗读引擎'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.help_rounded),
            tooltip: '帮助',
            onPressed: () => showHelp(context, HelpAssets.httpTtsHelp),
          ),
          IconButton(
            icon: const Icon(Symbols.refresh_rounded),
            tooltip: '刷新',
            onPressed: _loadEngines,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditEngine(),
        icon: const Icon(Symbols.add_rounded),
        label: const Text('添加引擎'),
      ),
      // [引擎双持久化 | 2026-10-04] 底部双按钮对齐原版 SpeakEngineDialog
      // 页脚（dialog_recycler_view.xml:94-141 左侧「书」/ 右侧「全局」）与
      // 文案（values-zh/strings.xml：book=书:264、general=全局:1207）。
      // 「取消」在页面形态下由系统返回承担，这里只呈现双持久化按钮。
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TextButton(
                onPressed: (!_hasSelection || !_hasBook)
                    ? null
                    : _applyBookEngine,
                child: const Text('书'),
              ),
              const Spacer(),
              TextButton(
                onPressed: !_hasSelection ? null : _applyGlobalEngine,
                child: const Text('全局'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          // [STAGE-UI-P43UNIFY2 B3] 裸环换接统一封装（默认参数视觉等价）
          ? const Center(child: AppCircularProgressIndicator())
          : _engines.isEmpty && !hasSystem
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.record_voice_over_rounded,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无朗读引擎',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加 HTTP TTS 引擎',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          // [LAYOUT_PLAN P1] 本页无开关行（SwitchListTile），无需 showChevron；
          // 引擎行无箭头（仅编辑/删除动作）；卡片分组间距 12dp
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _engines.length + (hasSystem ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasSystem && index == 0) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      selected: _selectedIsSystem,
                      leading: Icon(
                        _selectedIsSystem
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: const Text('系统 TTS'),
                      subtitle: const Text('使用设备语音，支持已安装的中文音色'),
                      onTap: () => setState(() {
                        _selectedIsSystem = true;
                        _selectedEngineId = null;
                      }),
                      trailing: IconButton(
                        icon: const Icon(Symbols.settings_rounded),
                        tooltip: '系统语音设置',
                        onPressed: () => showSystemTtsSettings(
                          context,
                          ref.read(systemTtsServiceProvider),
                          ref
                              .read(audioNotifierProvider.notifier)
                              .refreshSystemTtsSettings,
                        ),
                      ),
                    ),
                  );
                }
                final engine = _engines[index - (hasSystem ? 1 : 0)];
                final isSelected =
                    !_selectedIsSystem && _selectedEngineId == engine.id;
                return Card(
                  // [LAYOUT_PLAN P1] 分组间距 12dp
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    // [引擎双持久化 | 2026-10-04] 行点击仅更新选中态
                    // （对齐原版 SpeakEngineDialog.kt:315-326 的 upTts：
                    // 不持久化、不关闭），持久化交底部「书」/「全局」。
                    selected: isSelected,
                    onTap: () => setState(() {
                      _selectedIsSystem = false;
                      _selectedEngineId = engine.id;
                    }),
                    // 选中控件对齐原版行布局的 ThemeRadioButton
                    // （item_http_tts.xml:14-20），替代纯装饰性头像
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    title: Text(
                      engine.name,
                      // [LAYOUT_PLAN P1] 列表行字级走 M3 Type Scale
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      engine.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // [LAYOUT_PLAN P1] 列表行字级走 M3 Type Scale
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((engine.loginUrl ?? '').isNotEmpty ||
                            (engine.loginUi ?? '').isNotEmpty)
                          IconButton(
                            icon: const Icon(Symbols.login_rounded, size: 20),
                            tooltip: '登录',
                            onPressed: () => _loginEngine(engine),
                          ),
                        IconButton(
                          icon: const Icon(Symbols.edit_rounded, size: 20),
                          tooltip: '编辑',
                          onPressed: () => _addOrEditEngine(engine),
                        ),
                        IconButton(
                          icon: Icon(
                            Symbols.delete_rounded,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: '删除',
                          onPressed: () => _deleteEngine(engine),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// TTS 引擎编辑对话框
class _TtsEditDialog extends StatefulWidget {
  final HttpTts? engine;

  const _TtsEditDialog({this.engine});

  @override
  State<_TtsEditDialog> createState() => _TtsEditDialogState();
}

class _TtsEditDialogState extends State<_TtsEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _headerCtrl;
  late TextEditingController _contentTypeCtrl;
  late Map<String, TextEditingController> _advanced;
  bool _cookieJar = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.engine;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _urlCtrl = TextEditingController(text: e?.url ?? '');
    _headerCtrl = TextEditingController(text: e?.header ?? '');
    _contentTypeCtrl = TextEditingController(text: e?.contentType ?? '');
    _cookieJar = e?.enabledCookieJar ?? false;
    _advanced = {
      '源级语速': TextEditingController(text: e?.speed?.toString() ?? ''),
      '合成线程数': TextEditingController(
        text: (e?.synthesisThreadCount ?? 1).toString(),
      ),
      '并发率': TextEditingController(text: e?.concurrentRate ?? ''),
      '登录地址或脚本': TextEditingController(text: e?.loginUrl ?? ''),
      '登录表单': TextEditingController(text: e?.loginUi ?? ''),
      '登录响应校验': TextEditingController(text: e?.loginCheckJs ?? ''),
      'JS 库': TextEditingController(text: e?.jsLib ?? ''),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _headerCtrl.dispose();
    _contentTypeCtrl.dispose();
    for (final controller in _advanced.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    String? value(String key) {
      final v = _advanced[key]!.text.trim();
      return v.isEmpty ? null : v;
    }

    final base = widget.engine ?? const HttpTts();
    final tts = base.copyWith(
      speed: int.tryParse(_advanced['源级语速']!.text.trim()),
      synthesisThreadCount: int.parse(_advanced['合成线程数']!.text.trim()),
      concurrentRate: value('并发率'),
      loginUrl: value('登录地址或脚本'),
      loginUi: value('登录表单'),
      loginCheckJs: value('登录响应校验'),
      jsLib: value('JS 库'),
      enabledCookieJar: _cookieJar,
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      header: _headerCtrl.text.trim().isNotEmpty
          ? _headerCtrl.text.trim()
          : null,
      contentType: _contentTypeCtrl.text.trim().isNotEmpty
          ? _contentTypeCtrl.text.trim()
          : null,
    );

    Navigator.pop(context, tts);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.engine != null ? '编辑朗读引擎' : '添加朗读引擎'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名称 *',
                    hintText: '例如：Edge TTS',
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL *',
                    hintText: 'http://localhost:1234/tts?text={{text}}',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入 URL';
                    if (!isCompatibleHttpTtsEngineUrl(v)) {
                      return '请输入 HTTP URL 或 JS 请求规则';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Content-Type',
                    hintText: '可选，例如 audio/mpeg',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headerCtrl,
                  decoration: const InputDecoration(
                    labelText: '请求头 (JSON)',
                    hintText: '可选，例如 {"Authorization":"Bearer xxx"}',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                ExpansionTile(
                  title: const Text('高级配置'),
                  children: [
                    for (final entry in _advanced.entries)
                      TextFormField(
                        controller: entry.value,
                        decoration: InputDecoration(labelText: entry.key),
                        maxLines:
                            entry.key == '源级语速' ||
                                entry.key == '合成线程数' ||
                                entry.key == '并发率'
                            ? 1
                            : 3,
                        validator: (value) {
                          if (entry.key == '合成线程数') {
                            final count = int.tryParse(value?.trim() ?? '');
                            if (count == null || count < 1 || count > 8) {
                              return '请输入 1 到 8';
                            }
                          }
                          if (entry.key == '源级语速' &&
                              (value ?? '').trim().isNotEmpty) {
                            final speed = int.tryParse(value!.trim());
                            if (speed == null || speed < 0 || speed > 80) {
                              return '请输入 0 到 80，留空使用默认';
                            }
                          }
                          return null;
                        },
                      ),
                    SwitchListTile(
                      title: const Text('保存响应 Cookie'),
                      value: _cookieJar,
                      onChanged: (value) => setState(() => _cookieJar = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
