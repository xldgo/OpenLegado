import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 已初始化容器只交给一个根节点拥有，卸载时统一释放。— Codex + UI
class ApplicationScope extends StatefulWidget {
  const ApplicationScope({
    super.key,
    required this.container,
    required this.child,
  });
  final ProviderContainer container;
  final Widget child;
  @override
  State<ApplicationScope> createState() => _ApplicationScopeState();
}

class _ApplicationScopeState extends State<ApplicationScope> {
  @override
  void dispose() {
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: widget.container,
    child: widget.child,
  );
}
