import 'app_menu.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../providers/source_interaction_provider.dart';
import '../domain/contracts/verification_service.dart';
import '../domain/models/verification_request.dart';
import '../features/book_sources/book_sources.dart';

/// 全局验证码请求监听器（对标 Kotlin SourceVerificationHelp 全局监听）
///
/// 挂载于 MaterialApp.builder：订阅 VerificationService.verificationRequestStream，
/// 书源 JS 经 getVerificationCode 钩子挂起等待时弹出验证码对话框；
/// 多个请求按到达顺序队列化，逐个弹出（原版同一时刻仅一个对话框）。
///
/// 职责边界（对齐 UI_RESTRUCTURE_PLAN.md §0.2 铁律）：
/// 本组件仅消费类型化验证码事件流与 SourceNotifier，不触 bridge。
class VerificationCodeListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const VerificationCodeListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<VerificationCodeListener> createState() =>
      _VerificationCodeListenerState();
}

class _VerificationCodeListenerState
    extends ConsumerState<VerificationCodeListener> {
  StreamSubscription<VerificationRequest>? _subscription;
  late final VerificationService _service;

  /// 待处理请求队列（订阅时会回放进行中请求，需按 key 去重）
  final List<VerificationRequest> _queue = [];

  /// 正在展示对话框的 key（null 表示空闲）
  String? _showingKey;

  @override
  void initState() {
    super.initState();
    _service = ref.read(verificationServiceProvider);
    _subscription = _service.verificationRequestStream().listen(
      _onRequest,
      onError: (Object _) {
        // 单条流错误不终止对后续请求的监听。
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final keys = {..._queue.map((e) => e.key), ?_showingKey};
    _queue.clear();
    for (final key in keys) {
      unawaited(_cancel(key));
    }
    super.dispose();
  }

  void _onRequest(VerificationRequest event) {
    if (!mounted) return;
    final key = event.key;
    if (key.isEmpty) return;
    // 去重：正在展示或队列中已有同 key 请求（回放场景）
    if (key == _showingKey) return;
    if (_queue.any((e) => e.key == key)) return;
    _queue.add(event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showNext());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showNext() async {
    if (_showingKey != null || _queue.isEmpty || !mounted) return;
    final event = _queue.removeAt(0);
    final key = event.key;
    _showingKey = key;

    // 应用builder位于Navigator上方，使用宿主显式提供的Navigator挂载点。
    final submitted = await showDialog<bool>(
      context: widget.navigatorKey?.currentContext ?? context,
      barrierDismissible: false,
      builder: (_) => _VerificationCodeDialog(
        service: _service,
        requestKey: key,
        sourceName: event.sourceName,
        title: event.title,
        imageUrl: event.imageUrl,
        sourceUrl: event.sourceUrl,
      ),
    );

    if (!mounted) return;
    if (submitted != true) {
      // 关闭未提交：以空结果唤醒等待方（对齐 Kotlin checkResult 语义）
      await _cancel(key);
    }

    _showingKey = null;
    if (mounted) _showNext();
  }

  Future<void> _cancel(String key) async {
    try {
      await _service.cancelVerificationRequest(key);
    } catch (error) {
      debugPrint('验证码取消失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 验证码对话框内容（对标原版 VerificationCodeDialog：
/// 图片 + 输入框 + 确定/取消，溢出菜单含禁用书源/删除书源）
///
/// controller 由对话框内容 StatefulWidget 自持（随子树卸载释放，
/// 避免退场动画期间 dispose 引发框架断言）。
class _VerificationCodeDialog extends ConsumerStatefulWidget {
  final VerificationService service;
  final String requestKey;
  final String sourceName;
  final String title;
  final String imageUrl;
  final String sourceUrl;

  const _VerificationCodeDialog({
    required this.service,
    required this.requestKey,
    required this.sourceName,
    required this.title,
    required this.imageUrl,
    required this.sourceUrl,
  });

  @override
  ConsumerState<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

class _VerificationCodeDialogState
    extends ConsumerState<_VerificationCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final accepted = await widget.service.submitVerificationResult(
        widget.requestKey,
        code,
      );
      if (mounted) Navigator.pop(context, accepted);
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('验证码提交失败：$error')));
      }
    }
  }

  /// 溢出菜单：禁用书源/删除书源（对标原版 VerificationCodeDialog 菜单）
  Future<void> _handleSourceMenu(String action) async {
    if (!mounted) return;
    final notifier = ref.read(sourceNotifierProvider.notifier);
    switch (action) {
      case 'disable':
        await notifier.toggleSource(widget.sourceUrl);
      case 'delete':
        await notifier.deleteSource(widget.sourceUrl);
    }
    // 处置书源后关闭对话框（对齐原版处置后 finish 语义）
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final header = widget.title.isNotEmpty
        ? widget.title
        : (widget.sourceName.isNotEmpty
              ? '「${widget.sourceName}」需要验证码'
              : '请输入验证码');
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(header, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          AppMenuButton<String>(
            tooltip: '更多选项',
            icon: const Icon(Symbols.more_vert_rounded, size: 20),
            itemBuilder: (_) => const [
              AppMenuItem(value: 'disable', child: Text('禁用书源')),
              AppMenuItem(value: 'delete', child: Text('删除书源')),
            ],
            onSelected: _handleSourceMenu,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.imageUrl,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  color: colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    '验证码图片加载失败',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入验证码'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确定'),
        ),
      ],
    );
  }
}
