import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/cloud_tts_provider.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../l10n/app_localization.dart';
import 'cloud_tts_settings.dart';
import 'cloud_tts_providers.dart';
import 'cloud_tts_provider_labels.dart';
import '../../widgets/app_settings_sheet.dart';
import '../../widgets/app_settings_form.dart';
import '../../widgets/bottom_sheet_widget.dart';

typedef CloudTtsEditResult = ({
  CloudTtsEngine engine,
  String? key,
  String? secretKey,
});

/// 引擎仅管理连接和凭据，音色参数在独立音色 Sheet 配置。— Codex + UI
Future<CloudTtsEditResult?> showCloudTtsEngineEditor(
  BuildContext context,
  WidgetRef ref, [
  CloudTtsEngine? engine,
]) async {
  final capabilities = await ref
      .read(cloudTtsRepositoryProvider)
      .providerCapabilities();
  if (!context.mounted) return null;
  return AppBottomSheet.showContent<CloudTtsEditResult>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        CloudTtsEngineSheet(engine: engine, capabilities: capabilities),
  );
}

class CloudTtsEngineSheet extends StatefulWidget {
  const CloudTtsEngineSheet({
    super.key,
    this.engine,
    required this.capabilities,
  });
  final Map<String, CloudTtsCapabilities> capabilities;
  final CloudTtsEngine? engine;
  @override
  State<CloudTtsEngineSheet> createState() => _CloudTtsEngineSheetState();
}

class _CloudTtsEngineSheetState extends State<CloudTtsEngineSheet> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _inputs;
  bool _enabled = true;
  late String _provider;
  @override
  void initState() {
    super.initState();
    final engine = widget.engine;
    _provider = engine?.provider ?? 'openai_speech';
    final profile = widget.capabilities[_provider]!;
    _enabled = engine?.enabled ?? true;
    _inputs = {
      for (final entry in <String, String>{
        'name': engine?.name ?? cloudTtsProviderLabels[_provider]!.name,
        'baseUrl': engine?.baseUrl ?? '',
        'model': engine?.model ?? profile.defaultModel,
        'appId': engine?.appId ?? '',
        'region': engine?.region ?? '',
        'apiKey': '',
        'secretKey': '',
      }.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  void _changeProvider(String? provider) {
    if (provider == null || provider == _provider || widget.engine != null) {
      return;
    }
    final old = cloudTtsProviderLabels[_provider]!,
        next = cloudTtsProviderLabels[provider]!;
    setState(() {
      _provider = provider;
      if (_inputs['name']!.text == old.name) _inputs['name']!.text = next.name;
      _inputs['model']!.text = widget.capabilities[provider]!.defaultModel;
      _inputs['apiKey']!.clear();
      _inputs['secretKey']!.clear();
      _inputs['baseUrl']!.clear();
      _inputs['region']!.clear();
      _inputs['appId']!.clear();
    });
  }

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = widget.capabilities[_provider]!;
    final labels = {
      'name': l.cloudTtsName,
      'baseUrl': l.cloudTtsBaseUrl,
      'model': cloudTtsProviderLabels[_provider]!.modelLabel ?? l.cloudTtsModel,
      'appId': 'App ID',
      'apiKey':
          cloudTtsProviderLabels[_provider]!.apiKeyLabel ??
          (profile.usesSecretKey ? 'Access Key ID' : l.cloudTtsApiKey),
      'secretKey': 'Secret Access Key',
      'region': '区域',
    };
    return AppSettingsSheet(
      title: widget.engine == null ? l.cloudTtsAdd : l.cloudTtsEdit,
      onSave: () {
        if (!_form.currentState!.validate()) return;
        final old = widget.engine;
        Navigator.pop(context, (
          engine: CloudTtsEngine(
            id: old?.id ?? randomCloudTtsId(),
            provider: _provider,
            name: _inputs['name']!.text.trim(),
            baseUrl: _inputs['baseUrl']!.text.trim(),
            model: _inputs['model']!.text.trim(),
            enabled: _enabled,
            createdAt: old?.createdAt ?? 0,
            updatedAt: old?.updatedAt ?? 0,
            credentialKey: old?.credentialKey ?? '',
            region: _inputs['region']!.text.trim(),
            appId: _inputs['appId']!.text.trim(),
            optionsJson: old?.optionsJson ?? '{}',
          ),
          secretKey: _inputs['secretKey']!.text.trim().isEmpty
              ? null
              : _inputs['secretKey']!.text,
          key: _inputs['apiKey']!.text.trim().isEmpty
              ? null
              : _inputs['apiKey']!.text,
        ));
      },
      child: Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppSettingsForm(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('cloud-provider'),
                      initialValue: _provider,
                      decoration: InputDecoration(
                        labelText: l.cloudTtsProvider,
                      ),
                      items: [
                        for (final e in cloudTtsProviderLabels.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value.name),
                          ),
                      ],
                      onChanged: widget.engine == null ? _changeProvider : null,
                    ),
                    for (final e in _inputs.entries.where(
                      (e) =>
                          (e.key != 'secretKey' || profile.usesSecretKey) &&
                          (e.key != 'appId' || profile.requiresAppId) &&
                          (e.key != 'region' || profile.requiresRegion) &&
                          (e.key != 'model' || profile.usesModel),
                    ))
                      TextFormField(
                        key: ValueKey('cloud-${e.key}'),
                        controller: e.value,
                        decoration: InputDecoration(labelText: labels[e.key]),
                        obscureText: {'apiKey', 'secretKey'}.contains(e.key),
                        enableSuggestions: !{
                          'apiKey',
                          'secretKey',
                        }.contains(e.key),
                        autocorrect: !{'apiKey', 'secretKey'}.contains(e.key),
                        enableIMEPersonalizedLearning: !{
                          'apiKey',
                          'secretKey',
                        }.contains(e.key),
                        validator: (v) =>
                            ({'name', 'model', 'appId'}.contains(e.key) ||
                                    e.key == 'region' &&
                                        (profile.usesSecretKey ||
                                            _inputs['baseUrl']!.text
                                                .trim()
                                                .isEmpty) ||
                                    {'apiKey', 'secretKey'}.contains(e.key) &&
                                        widget.engine == null) &&
                                (v ?? '').trim().isEmpty
                            ? labels[e.key]
                            : null,
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                title: Text(l.cloudTtsEnabled),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
