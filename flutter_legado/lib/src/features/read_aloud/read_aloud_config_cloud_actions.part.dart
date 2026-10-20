part of 'read_aloud_config_screen.dart';

/// 共用页内云端 CRUD/试听动作，不再拥有独立路由或 Scaffold。— Codex + UI
mixin _CloudEngineManagement on ConsumerState<ReadAloudConfigScreen> {
  List<CloudTtsEngine> _cloudEngines = [];
  bool _cloudBusy = false, _cloudEditing = false;
  String? _cloudError;
  GlobalKey<ReadAloudVoicePanelState> get _voicePanelKey;
  Future<void> _loadEngines();
  Future<void> _loadCloudEngines() async {
    try {
      final engines = await ref.read(cloudTtsRepositoryProvider).list();
      if (mounted) {
        setState(() {
          _cloudEngines = engines;
          _cloudError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _cloudError = '$error');
    }
  }

  Future<void> _runCloud(Future<void> Function() operation) async {
    if (_cloudBusy) return;
    setState(() {
      _cloudBusy = true;
      _cloudError = null;
    });
    try {
      await operation();
    } catch (error) {
      // 跨存储清理失败可能已提交元数据，重读实际配置再展示原始结果。
      if (mounted) {
        try {
          await _loadEngines();
        } catch (_) {}
      }
      if (mounted) setState(() => _cloudError = '$error');
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _editCloudEngine([CloudTtsEngine? engine]) async {
    if (_cloudBusy || _cloudEditing) return;
    _cloudEditing = true;
    try {
      final result = await showCloudTtsEngineEditor(context, ref, engine);
      if (result == null || !mounted) return;
      await _runCloud(() async {
        await _voicePanelKey.currentState?.stopPreview();
        if (!mounted) return;
        await ref
            .read(cloudTtsSettingsProvider)
            .save(
              result.engine,
              apiKey: result.key,
              secretKey: result.secretKey,
            );
        if (!mounted) return;
        await _loadEngines();
        if (!mounted) return;
        final notifier = ref.read(audioNotifierProvider.notifier);
        if (notifier.resolveTtsEngineUrl() == result.engine.selection) {
          await notifier.restartCurrentTts();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _cloudError = '$error');
    } finally {
      _cloudEditing = false;
    }
  }

  Future<void> _deleteCloudEngine(CloudTtsEngine engine) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.cloudTtsDelete),
        content: Text(l.cloudTtsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cloudTtsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.cloudTtsDelete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _runCloud(() async {
      await _voicePanelKey.currentState?.stopPreview();
      if (!mounted) return;
      await ref.read(cloudTtsSettingsProvider).delete(engine);
      if (!mounted) return;
      final notifier = ref.read(audioNotifierProvider.notifier);
      if (notifier.resolveTtsEngineUrl() == engine.selection) {
        notifier.pause();
        await notifier.restartCurrentTts();
      }
      if (mounted) await _loadEngines();
    });
  }
}
