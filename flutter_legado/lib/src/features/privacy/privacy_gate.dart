import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import 'privacy_controller.dart';
import 'privacy_unlock_dialog.dart';

/// 在子页面创建前验证，关闭或取消不会初始化正文。— Codex + UI
class PrivacyBookGate extends ConsumerStatefulWidget {
  const PrivacyBookGate({super.key, required this.book, required this.builder});
  final Book? book;
  final WidgetBuilder builder;
  @override
  ConsumerState<PrivacyBookGate> createState() => _PrivacyBookGateState();
}

class _PrivacyBookGateState extends ConsumerState<PrivacyBookGate> {
  PrivacyController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ref.read(privacyControllerProvider.notifier);
  }

  @override
  void didUpdateWidget(covariant PrivacyBookGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book?.bookUrl != widget.book?.bookUrl) {
      final controller = _controller;
      final url = oldWidget.book?.bookUrl;
      Future.microtask(() => controller?.revoke(bookUrl: url));
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    final url = widget.book?.bookUrl;
    Future.microtask(() => controller?.revoke(bookUrl: url));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    final book = state.find(widget.book?.bookUrl ?? '') ?? widget.book;
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                ref.read(privacyControllerProvider.notifier).retry(),
            child: Text(state.error!),
          ),
        ),
      );
    }
    if (book == null ||
        !state.locked(book) ||
        !state.settings.verifyOnOpenBook) {
      return widget.builder(context);
    }
    return AppScaffold(
      collapsibleTopBar: false,
      topBar: const LegadoAppBar(title: Text('私密书籍'), showBack: true),
      body: Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.lock_outline),
          label: const Text('验证后阅读'),
          onPressed: () =>
              showPrivacyUnlock(context, ref, bookUrl: book.bookUrl),
        ),
      ),
    );
  }
}

/// 私密分组授权可覆盖组内书籍，离开分组时撤销逐次授权。
class PrivacyGroupGate extends ConsumerStatefulWidget {
  const PrivacyGroupGate({
    super.key,
    required this.group,
    required this.child,
    this.lockedBuilder,
  });
  final BookGroup? group;
  final Widget child;
  final Widget Function(BuildContext, Widget)? lockedBuilder;
  @override
  ConsumerState<PrivacyGroupGate> createState() => _PrivacyGroupGateState();
}

class _PrivacyGroupGateState extends ConsumerState<PrivacyGroupGate> {
  PrivacyController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ref.read(privacyControllerProvider.notifier);
  }

  @override
  void didUpdateWidget(covariant PrivacyGroupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group?.groupId != widget.group?.groupId) {
      final id = oldWidget.group?.groupId;
      final controller = _controller;
      Future.microtask(() => controller?.revoke(groupId: id));
    }
  }

  @override
  void dispose() {
    final id = widget.group?.groupId;
    final controller = _controller;
    Future.microtask(() => controller?.revoke(groupId: id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    final group =
        state.groups
            .where((g) => g.groupId == widget.group?.groupId)
            .firstOrNull ??
        widget.group;
    if (group == null ||
        !group.isPrivate ||
        !state.settings.enabled ||
        !state.settings.verifyOnEnterGroup ||
        state.unlocked ||
        state.groupGrants.contains(group.groupId)) {
      return widget.child;
    }
    final locked = Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.lock_outline),
        label: const Text('验证后查看私密分组'),
        onPressed: state.loading || state.error != null
            ? null
            : () => showPrivacyUnlock(context, ref, groupId: group.groupId),
      ),
    );
    return widget.lockedBuilder?.call(context, locked) ?? locked;
  }
}

/// 启动验证与书籍授权分离，后台回锁时同时遮住已打开的私密正文。
class PrivacyAppGate extends ConsumerWidget {
  const PrivacyAppGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privacyControllerProvider);
    if (state.loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.settings.enabled &&
        (state.error != null ||
            state.settings.verifyOnAppStart && !state.startVerified)) {
      return Material(
        child: Center(
          child: state.error != null
              ? TextButton(
                  onPressed: () =>
                      ref.read(privacyControllerProvider.notifier).retry(),
                  child: Text(state.error!),
                )
              : FilledButton(
                  onPressed: () =>
                      showPrivacyUnlock(context, ref, appStart: true),
                  child: const Text('验证后进入应用'),
                ),
        ),
      );
    }
    return child;
  }
}

/// 管理入口只验证身份，不自动授予私密内容访问。
class PrivacyVerificationGate extends ConsumerStatefulWidget {
  const PrivacyVerificationGate({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  ConsumerState<PrivacyVerificationGate> createState() =>
      _PrivacyVerificationGateState();
}

class _PrivacyVerificationGateState
    extends ConsumerState<PrivacyVerificationGate> {
  bool _verified = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.settings.enabled || !state.hasPassword || _verified) {
      return widget.builder(context);
    }
    return AppScaffold(
      collapsibleTopBar: false,
      topBar: const LegadoAppBar(title: Text('隐私验证'), showBack: true),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final accepted = await showPrivacyUnlock(
              context,
              ref,
              verifyOnly: true,
            );
            if (mounted) setState(() => _verified = accepted);
          },
          child: const Text('验证后管理'),
        ),
      ),
    );
  }
}

/// 锁定内容不创建真实子组件，避免图像、语义和长按菜单泄露。
class PrivacyMaskedContent extends ConsumerWidget {
  const PrivacyMaskedContent({
    super.key,
    required this.child,
    this.book,
    this.bookName,
    this.author,
    this.onTap,
  });
  final Widget child;
  final Book? book;
  final String? bookName, author;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privacyControllerProvider);
    if (state.loading) {
      return const SizedBox(
        height: 88,
        child: Center(child: Icon(Icons.lock_outline)),
      );
    }
    if (state.settings.enabled && state.error != null) {
      return const SizedBox(height: 88, child: Center(child: Text('隐私状态不可用')));
    }
    final target = book == null
        ? state.books
              .where(
                (b) =>
                    b.name == bookName && b.author == author && state.locked(b),
              )
              .firstOrNull
        : state.find(book!.bookUrl) ?? book;
    if (target == null || !state.locked(target)) return child;
    return Semantics(
      label: '私密书籍',
      button: true,
      child: InkWell(
        onTap: () async {
          if (!state.settings.verifyOnOpenBook) {
            onTap?.call();
            return;
          }
          if (await showPrivacyUnlock(context, ref, bookUrl: target.bookUrl)) {
            onTap?.call();
          }
        },
        child: LayoutBuilder(
          builder: (context, limits) => SizedBox(
            height: limits.hasBoundedHeight ? limits.maxHeight : 88,
            child: Center(
              child:
                  limits.hasBoundedHeight && limits.maxHeight < 64 ||
                      limits.maxWidth < 80
                  ? const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Icon(Icons.lock_outline),
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline),
                        Text(
                          '私密书籍',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
