import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../domain/models/book_content_result.dart';
import '../../../domain/models/webdav_connection.dart';
import '../../../models/book.dart';
import '../../../services/export_service.dart';
import '../../../utils/error_message.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/settings_widgets.dart';

/// 离线缓存的单本导出表单，共用固定操作栏、滚动内容和键盘避让。— Codex + UI
class BookExportSheet extends StatefulWidget {
  const BookExportSheet({
    super.key,
    required this.book,
    required this.exportService,
    this.webDavConfig,
  });
  final Book book;
  final ExportService exportService;
  final WebDavConnection? webDavConfig;

  static Future<BookExportData?> show({
    required BuildContext context,
    required Book book,
    required ExportService exportService,
    WebDavConnection? webDavConfig,
  }) => AppBottomSheet.showContent<BookExportData>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    builder: (_) => BookExportSheet(
      book: book,
      exportService: exportService,
      webDavConfig: webDavConfig,
    ),
  );

  @override
  State<BookExportSheet> createState() => _BookExportSheetState();
}

class _BookExportSheetState extends State<BookExportSheet> {
  String _selectedFormat = 'txt';
  String _selectedEncoding = 'UTF-8';
  bool _includeToc = true;
  bool _enableWebDav = false;
  String? _exportPath;
  final _fileNameCtrl = TextEditingController(text: '{name}');
  final _startChapterCtrl = TextEditingController();
  final _endChapterCtrl = TextEditingController();
  bool _busy = false;
  String _progressText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.exportService.supportedFormats.contains('epub')) {
      _selectedFormat = 'epub';
    }
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    _startChapterCtrl.dispose();
    _endChapterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppBottomSheet.content(
      title: '导出${widget.book.name}',
      leading: TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      trailing: FilledButton(
        onPressed: _busy ? null : _handleConfirm,
        child: Text(_busy ? '导出中' : '导出'),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormatSelector(),
                const SizedBox(height: 20),
                _buildEncodingSelector(),
                const SizedBox(height: 20),
                _buildFileNameTemplate(),
                const SizedBox(height: 20),
                _buildChapterRange(),
              ],
            ),
          ),
          SettingTile(
            title: '导出目录',
            value: _exportPath ?? '未选择',
            icon: Symbols.folder_open_rounded,
            enabled: !_busy,
            onTap: _busy ? null : _pickExportPath,
          ),
          SettingSwitchRow(
            title: '包含目录',
            subtitle: '导出时包含书籍的目录结构',
            value: _includeToc,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeToc = value),
          ),
          if (widget.webDavConfig?.url.isNotEmpty == true)
            SettingSwitchRow(
              title: '上传到 WebDAV',
              subtitle: '导出完成后自动上传到远程服务器',
              value: _enableWebDav,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _enableWebDav = value),
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_progressText),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

  /// 格式选择器
  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('导出格式', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.exportService.supportedFormats.map((format) {
            return ChoiceChip(
              label: Text(format.toUpperCase()),
              selected: _selectedFormat == format,
              onSelected: _busy
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedFormat = format;
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 字符集选择器
  Widget _buildEncodingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('字符编码', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          initialSelection: _selectedEncoding,
          selectOnly: true,
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: widget.exportService.supportedEncodings.map((
            encoding,
          ) {
            return DropdownMenuEntry<String>(value: encoding, label: encoding);
          }).toList(),
          enabled: !_busy,
          onSelected: (value) {
            setState(() {
              _selectedEncoding = value ?? 'UTF-8';
            });
          },
        ),
      ],
    );
  }

  /// 文件名模板（对齐原版 bookExportFileName：{name}/{author}）
  Widget _buildFileNameTemplate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('文件名模板', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          '可用变量：{name} {author}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fileNameCtrl,
          enabled: !_busy,
          decoration: const InputDecoration(hintText: '{name}', isDense: true),
        ),
      ],
    );
  }

  /// 章节范围（对齐 ExportBookService 范围；空=全部）
  Widget _buildChapterRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('章节范围', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          '索引从 0 起；留空表示全部章节',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startChapterCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '起始',
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            Expanded(
              child: TextField(
                controller: _endChapterCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '结束',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickExportPath() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
    if (mounted && dir != null) setState(() => _exportPath = dir);
  }

  Future<void> _handleConfirm() async {
    if (_busy) return;
    if (!widget.exportService.supportedFormats.contains(_selectedFormat)) {
      setState(() => _error = '不支持的导出格式');
      return;
    }
    if (_exportPath == null && !_enableWebDav) {
      setState(() => _error = '请先选择导出目录');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _progressText = '正在生成导出文件…';
    });
    try {
      final result = await widget.exportService.export(
        bookUrl: widget.book.bookUrl,
        format: _selectedFormat,
        includeToc: _includeToc,
        encoding: _selectedEncoding,
        startChapter: int.tryParse(_startChapterCtrl.text.trim()),
        endChapter: int.tryParse(_endChapterCtrl.text.trim()),
        fileNameTemplate: _fileNameCtrl.text.trim(),
      );
      if (!mounted) return;
      if (_enableWebDav && widget.webDavConfig != null) {
        setState(() => _progressText = '正在上传到 WebDAV…');
        final tmp = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}${result.fileName}',
        );
        await tmp.writeAsBytes(result.bytes);
        try {
          await widget.exportService.webdavUploadFile(
            widget.webDavConfig!,
            '/books/${result.fileName}',
            tmp.path,
          );
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
      } else {
        setState(() => _progressText = '正在写入文件…');
        final file = File(
          '$_exportPath${Platform.pathSeparator}${result.fileName}',
        );
        await file.writeAsBytes(result.bytes);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
