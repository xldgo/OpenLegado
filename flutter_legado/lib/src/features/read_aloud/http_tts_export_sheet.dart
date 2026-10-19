import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../utils/error_message.dart';
import '../../widgets/bottom_sheet_widget.dart';
import 'http_tts_transfer_provider.dart';

/// 单条与批量导出共用完整文档，取消文件选择不报告成功。— Codex + UI
class HttpTtsExportSheet extends ConsumerStatefulWidget {
  const HttpTtsExportSheet({super.key, required this.engines, this.initialIds});
  final List<HttpTts> engines;
  final Set<int>? initialIds;

  @override
  ConsumerState<HttpTtsExportSheet> createState() => _HttpTtsExportSheetState();
}

class _HttpTtsExportSheetState extends ConsumerState<HttpTtsExportSheet> {
  late final _selected = {
    ...?widget.initialIds,
    if (widget.initialIds == null) ...widget.engines.map((e) => e.id),
  };
  bool _busy = false;
  String? _error;

  Future<void> _export({required bool copy}) async {
    if (_busy || _selected.isEmpty) return;
    final transfer = ref.read(httpTtsTransferProvider);
    final files = ref.read(httpTtsFileServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final document = await transfer.export(ids: Set.of(_selected));
      if (!mounted) return;
      final bool saved;
      if (copy) {
        await Clipboard.setData(ClipboardData(text: document));
        saved = true;
      } else {
        saved = await files.write(document);
      }
      if (mounted && saved) Navigator.pop(context, copy ? '已复制规则' : '导出成功');
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppBottomSheet.content(
      title: '导出 HTTP TTS',
      leading: TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      trailing: Text('${_selected.length}/${widget.engines.length}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('全选'),
            value:
                _selected.length == widget.engines.length &&
                _selected.isNotEmpty,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _selected.clear();
                    if (value == true) {
                      _selected.addAll(widget.engines.map((e) => e.id));
                    }
                  }),
          ),
          for (final engine in widget.engines)
            CheckboxListTile(
              title: Text(engine.name),
              value: _selected.contains(engine.id),
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _selected.add(engine.id);
                      } else {
                        _selected.remove(engine.id);
                      }
                    }),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _export(copy: true),
                  child: const Text('复制规则'),
                ),
                FilledButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _export(copy: false),
                  child: const Text('导出文件'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
