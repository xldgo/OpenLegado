import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/platform/tts/system_tts.dart';

Future<void> showSystemTtsSettings(
  BuildContext context,
  SystemTts service,
  Future<void> Function() onChanged,
) => showDialog<void>(
  context: context,
  builder: (_) => _SystemTtsSettings(service: service, onChanged: onChanged),
);

class _SystemTtsSettings extends StatefulWidget {
  const _SystemTtsSettings({required this.service, required this.onChanged});
  final SystemTts service;
  final Future<void> Function() onChanged;
  @override
  State<_SystemTtsSettings> createState() => _SystemTtsSettingsState();
}

class _SystemTtsSettingsState extends State<_SystemTtsSettings> {
  List<String> _engines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _engines = await widget.service.getEngines();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _save({String? engine}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        await widget.service.saveSettings(
          engine: engine ?? widget.service.selectedEngine,
          voice: engine != null && engine != widget.service.selectedEngine
              ? ''
              : widget.service.selectedVoice,
        );
      } finally {
        await widget.onChanged();
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return AlertDialog(
      title: const Text('系统 TTS 引擎设置'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (service.supportsEngineSelection) ...[
                DropdownMenu<String>(
                  key: ValueKey('engine-${service.selectedEngine}'),
                  label: const Text('设备 TTS 引擎'),
                  width: 300,
                  enabled: !_loading,
                  initialSelection: _engines.contains(service.selectedEngine)
                      ? service.selectedEngine
                      : '',
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: '', label: '跟随系统默认'),
                    for (final engine in _engines)
                      DropdownMenuEntry(value: engine, label: engine),
                  ],
                  onSelected: (value) {
                    if (value != null) _save(engine: value);
                  },
                ),
                const SizedBox(height: 16),
              ],
              const Text('音色选择和试听请在音色页管理。缺少中文语音时，请在系统设置中安装。'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('重试'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
