import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import 'http_tts_seed.dart';
import '../../widgets/app_settings_sheet.dart';
import '../../widgets/app_settings_form.dart';

/// HTTP 编辑保留完整字段，复用固定操作栏的 Sheet。— Codex + UI
class HttpTtsEngineSheet extends StatefulWidget {
  final HttpTts? engine;

  const HttpTtsEngineSheet({super.key, this.engine});

  @override
  State<HttpTtsEngineSheet> createState() => _HttpTtsEngineSheetState();
}

class _HttpTtsEngineSheetState extends State<HttpTtsEngineSheet> {
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
    return AppSettingsSheet(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      title: widget.engine != null ? '编辑 HTTP TTS 引擎' : '添加 HTTP TTS 引擎',
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: AppSettingsForm(
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
            TextFormField(
              controller: _contentTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Content-Type',
                hintText: '可选，例如 audio/mpeg',
                isDense: true,
              ),
            ),
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
                AppSettingsForm(
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
          ],
        ),
      ),
    );
  }
}
