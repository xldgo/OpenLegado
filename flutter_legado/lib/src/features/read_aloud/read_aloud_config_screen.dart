import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_provider.dart';
import '../../l10n/app_localization.dart';
import 'cloud_tts_engine_sheet.dart';
import 'cloud_tts_providers.dart';
import 'http_tts_engine_sheet.dart';
import '../../widgets/bottom_sheet_widget.dart';
import 'read_aloud_voice_panel.dart';
import 'read_aloud_voice_provider.dart';
import 'http_tts_login.dart';
import 'http_tts_import_sheet.dart';
import 'http_tts_export_sheet.dart';
import '../../widgets/app_menu.dart';

import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import '../../models/models.dart';
import '../audio/application/audio_notifier.dart';
import 'http_tts_seed.dart';
import 'http_tts_repository_provider.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/system_tts_settings_dialog.dart';

import 'package:flutter_legado/src/platform/tts/system_tts.dart';

import '../../widgets/help/help_assets.dart';
import '../../widgets/help/show_help.dart';

part 'read_aloud_config_cloud_actions.part.dart';

/// 音色与系统/HTTP/云端引擎共用入口。— Codex + UI
class ReadAloudConfigScreen extends ConsumerStatefulWidget {
  const ReadAloudConfigScreen({super.key, this.initialTab = 0})
    : assert(initialTab >= 0 && initialTab < 2);
  final int initialTab;

  @override
  ConsumerState<ReadAloudConfigScreen> createState() =>
      _ReadAloudConfigScreenState();
}

class _ReadAloudConfigScreenState extends ConsumerState<ReadAloudConfigScreen>
    with SingleTickerProviderStateMixin, _CloudEngineManagement {
  @override
  final _voicePanelKey = GlobalKey<ReadAloudVoicePanelState>();
  late final TabController _tabs;
  late int _activeTab;
  int _voiceRevision = 0;
  String? _selectedCloudId;
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
    _activeTab = widget.initialTab;
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    )..addListener(_tabChanged);
    unawaited(_loadEngines());
  }

  void _tabChanged() {
    if (!mounted || _activeTab == _tabs.index) return;
    _activeTab = _tabs.index;
    if (_activeTab == 0) {
      _voiceRevision++;
      ref.invalidate(readAloudVoicesProvider);
    }
    if (_activeTab == 1) {
      unawaited(
        _voicePanelKey.currentState?.stopPreview() ?? Future<void>.value(),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Future<void> _loadEngines() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(httpTtsRepositoryProvider);
      // [D3 | 2026-10-03] 首启导入原版 httpTTS 种子（版本门控），
      // 与 dict/rss/txtToc 对齐：进入配置页即可见默认数据
      await ensureDefaultHttpTts(api);
      final list = await api.getHttpTts();
      await _loadCloudEngines();
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
        _selectedCloudId = isCloudTts(effectiveUrl)
            ? cloudTtsId(effectiveUrl)
            : null;
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

    await _voicePanelKey.currentState?.stopPreview();
    if (!mounted) return;
    final result = await AppBottomSheet.showContent<HttpTts>(
      context: context,
      showDragHandle: true,
      builder: (_) => HttpTtsEngineSheet(engine: existing),
    );

    if (result == null || !mounted) return;

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

  Future<void> _importEngines() async {
    await _voicePanelKey.currentState?.stopPreview();
    if (!mounted) return;
    final count = await AppBottomSheet.showContent<int>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const HttpTtsImportSheet(),
    );
    if (!mounted || count == null) return;
    ref.invalidate(readAloudVoicesProvider);
    await _loadEngines();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导入 $count 个 HTTP TTS 引擎')));
    }
  }

  Future<void> _exportEngines([int? id]) async {
    final message = await AppBottomSheet.showContent<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => HttpTtsExportSheet(
        engines: List.of(_engines),
        initialIds: id == null ? null : {id},
      ),
    );
    if (mounted && message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
    } else if (_selectedCloudId != null) {
      ok = await notifier.setBookTtsEngine('cloud://$_selectedCloudId');
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
    } else if (_selectedCloudId != null) {
      await notifier.setGlobalTtsEngine('cloud://$_selectedCloudId');
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

  Future<void> _chooseEngine({
    HttpTts? http,
    CloudTtsEngine? cloud,
    bool system = false,
  }) async {
    if (_loading || _cloudBusy) return;
    final scope = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(cloud?.name ?? http?.name ?? '系统 TTS'),
        content: const Text('选择朗读引擎的应用范围'),
        actions: [
          TextButton(
            onPressed: _hasBook ? () => Navigator.pop(c, true) : null,
            child: const Text('书'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('全局'),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;
    await _voicePanelKey.currentState?.stopPreview();
    if (!mounted) return;
    setState(() {
      _selectedIsSystem = system;
      _selectedEngineId = http?.id;
      _selectedCloudId = cloud?.id;
    });
    try {
      if (scope) {
        await _applyBookEngine();
      } else {
        await _applyGlobalEngine();
      }
      if (mounted) await _loadEngines();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('设置失败：$error')));
      }
    }
  }

  Future<void> _addEngine() async {
    final type = await AppBottomSheet.showContent<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => AppBottomSheet.content(
        title: '添加引擎',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('云 TTS'),
              subtitle: const Text('选择云端服务商并配置凭据'),
              onTap: () => Navigator.pop(c, 'cloud'),
            ),
            ListTile(
              leading: const Icon(Icons.http),
              title: const Text('HTTP TTS'),
              subtitle: const Text('自定义 URL 或 JS 请求规则'),
              onTap: () => Navigator.pop(c, 'http'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    if (type == 'cloud') {
      await _editCloudEngine();
    } else {
      await _addOrEditEngine();
    }
  }

  Widget _httpTile(HttpTts engine) {
    final selected =
        !_selectedIsSystem &&
        _selectedCloudId == null &&
        _selectedEngineId == engine.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        selected: selected,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
        title: Text(engine.name),
        subtitle: Text(
          engine.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: engine.isEnabled && !_cloudBusy
            ? () => _chooseEngine(http: engine)
            : null,
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
              onPressed: _cloudBusy ? null : () => _addOrEditEngine(engine),
            ),
            AppMenuButton<String>(
              tooltip: '${engine.name}更多操作',
              enabled: !_cloudBusy,
              itemBuilder: (_) => const [
                AppMenuItem(value: 'export', child: Text('复制或导出规则')),
                AppMenuItem(value: 'delete', child: Text('删除')),
              ],
              onSelected: (value) {
                if (value == 'export') {
                  unawaited(_exportEngines(engine.id));
                }
                if (value == 'delete') {
                  unawaited(_deleteEngine(engine));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cloudTile(CloudTtsEngine engine) {
    final l = context.l10n;
    final selected = _selectedCloudId == engine.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: ValueKey('cloud-engine-${engine.id}'),
        selected: selected,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
        title: Text(engine.name),
        subtitle: Text(
          '${cloudTtsProfile(engine.provider).name} · ${engine.model}',
        ),
        onTap: engine.enabled && !_cloudBusy
            ? () => _chooseEngine(cloud: engine)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '编辑云端引擎',
              icon: const Icon(Symbols.edit_rounded, size: 20),
              onPressed: _cloudBusy ? null : () => _editCloudEngine(engine),
            ),
            IconButton(
              tooltip: l.cloudTtsDelete,
              icon: const Icon(Symbols.delete_rounded, size: 20),
              onPressed: _cloudBusy ? null : () => _deleteCloudEngine(engine),
            ),
          ],
        ),
      ),
    );
  }

  /// 分类顺序与上游 EngineSectionTitle 一致，卡片保持现有交互。— Codex + UI
  Widget _engineSectionTitle(String category, String title) => Padding(
    key: ValueKey('engine-section-$category'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Semantics(
      headingLevel: 2,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _engineList() {
    final hasSystem = ref.read(systemTtsServiceProvider).isSupported;
    final l = context.l10n;
    if (_loading) return const Center(child: AppCircularProgressIndicator());
    return ListView(
      key: const ValueKey('read-aloud-engine-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _engineSectionTitle('cloud', l.readAloudCloudEngines),
        if (_cloudBusy) const LinearProgressIndicator(),
        if (_cloudError != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_cloudError!)),
        ..._cloudEngines.map(_cloudTile),
        _engineSectionTitle('http', l.readAloudHttpEngines),
        ..._engines.map(_httpTile),
        _engineSectionTitle('system', l.readAloudSystemEngines),
        if (hasSystem)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: const Text('系统 TTS'),
              subtitle: const Text('使用设备已安装的语音'),
              selected: _selectedIsSystem,
              leading: Icon(
                _selectedIsSystem
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => _chooseEngine(system: true),
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
          ),
        if (_engines.isEmpty && _cloudEngines.isEmpty && !hasSystem)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('暂无朗读引擎', textAlign: TextAlign.center),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    topBar: LegadoAppBar(
      title: Text(context.l10n.readAloudEngines),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '音色'),
          Tab(text: '引擎'),
        ],
      ),
      actions: [
        if (_activeTab == 1)
          AppMenuButton<String>(
            tooltip: 'HTTP TTS 导入导出',
            enabled: !_loading && !_cloudBusy && !_cloudEditing,
            itemBuilder: (_) => [
              const AppMenuItem(value: 'import', child: Text('导入 HTTP TTS')),
              AppMenuItem(
                value: 'export',
                enabled: _engines.isNotEmpty,
                child: const Text('导出 HTTP TTS'),
              ),
            ],
            onSelected: (value) => unawaited(
              value == 'import' ? _importEngines() : _exportEngines(),
            ),
          ),
        IconButton(
          icon: const Icon(Symbols.help_rounded),
          tooltip: '帮助',
          onPressed: () => showHelp(context, HelpAssets.httpTtsHelp),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      tooltip: _tabs.index == 1 ? '添加引擎' : '添加音色',
      onPressed: _cloudBusy || _cloudEditing || _loading
          ? null
          : _tabs.index == 1
          ? _addEngine
          : () => _voicePanelKey.currentState?.addVoice(),
      icon: const Icon(Symbols.add_rounded),
      label: Text(_tabs.index == 1 ? '添加引擎' : '添加音色'),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        ReadAloudVoicePanel(key: _voicePanelKey, revision: _voiceRevision),
        _engineList(),
      ],
    ),
  );
}
