import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/services/http_tts_transfer_service.dart';
import '../../utils/error_message.dart';
import '../../widgets/bottom_sheet_widget.dart';
import 'http_tts_transfer_provider.dart';

/// 预览与勾选仅在弹层内存中，确认时才提交整批文档。— Codex + UI
class HttpTtsImportSheet extends ConsumerStatefulWidget {
  const HttpTtsImportSheet({super.key});

  @override
  ConsumerState<HttpTtsImportSheet> createState() => _HttpTtsImportSheetState();
}

class _HttpTtsImportSheetState extends ConsumerState<HttpTtsImportSheet> {
  final _input = TextEditingController();
  List<HttpTtsImportItem>? _items;
  final _selected = <int>{};
  String? _error;
  bool _loading = false, _saving = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _preview(Future<String?> Function() read) async {
    if (_loading || _saving) return;
    final transfer = ref.read(httpTtsTransferProvider);
    setState(() {
      _loading = true;
      _error = null;
      _items = null;
      _selected.clear();
    });
    try {
      final input = await read();
      if (!mounted || input == null) return;
      final items = await transfer.preview(input);
      if (!mounted) return;
      setState(() {
        _items = items;
        _selected.addAll([
          for (var i = 0; i < items.length; i++)
            if (items[i].selectedByDefault) i,
        ]);
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _selected.isEmpty) return;
    final items = _items!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await ref.read(httpTtsTransferProvider).save([
        for (var i = 0; i < items.length; i++)
          if (_selected.contains(i)) items[i],
      ]);
      if (mounted) Navigator.pop(context, count);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _saving;
    return PopScope(
      canPop: !_saving,
      child: AppBottomSheet.content(
        title: '导入 HTTP TTS',
        leading: TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        trailing: FilledButton(
          onPressed: busy || _selected.isEmpty ? null : _save,
          child: Text('导入（${_selected.length}）'),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _input,
                    enabled: !busy,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '规则 JSON 或导入链接',
                    ),
                    onChanged: (_) => setState(() {
                      _items = null;
                      _selected.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _preview(
                                () async =>
                                    (await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    ))?.text ??
                                    '',
                              ),
                        child: const Text('从剪贴板导入'),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _preview(
                                ref.read(httpTtsFileServiceProvider).read,
                              ),
                        child: const Text('从文件导入'),
                      ),
                      FilledButton.tonal(
                        onPressed: busy
                            ? null
                            : () => _preview(() async => _input.text),
                        child: const Text('预览规则'),
                      ),
                    ],
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
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
            if (_items case final items?) ...[
              CheckboxListTile(
                title: Text('全选（${_selected.length}/${items.length}）'),
                value: _selected.length == items.length,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        _selected.clear();
                        if (value == true) {
                          _selected.addAll(
                            List.generate(items.length, (i) => i),
                          );
                        }
                      }),
              ),
              for (var i = 0; i < items.length; i++)
                CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        }),
                  title: Text(items[i].engine.name),
                  subtitle: Text(switch (items[i].status) {
                    HttpTtsImportStatus.added => '新增',
                    HttpTtsImportStatus.updated => '更新已有引擎',
                    HttpTtsImportStatus.existing => '已有 · 勾选后覆盖',
                  }),
                  secondary: IconButton(
                    tooltip: '查看规则',
                    icon: const Icon(Icons.code),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(items[i].engine.name),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(items[i].raw),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
