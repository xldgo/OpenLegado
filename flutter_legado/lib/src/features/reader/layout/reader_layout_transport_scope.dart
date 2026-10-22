import 'package:flutter/widgets.dart';

import '../../../domain/contracts/reader_layout_transport.dart';

/// 测试与宿主可注入传输层，生产缺省仍只调用 Rust；不提供 Dart 算法回退。
class ReaderLayoutTransportScope extends InheritedWidget {
  final ReaderLayoutTransport transport;
  const ReaderLayoutTransportScope({
    super.key,
    required this.transport,
    required super.child,
  });
  static ReaderLayoutTransport? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReaderLayoutTransportScope>()
      ?.transport;
  @override
  bool updateShouldNotify(ReaderLayoutTransportScope oldWidget) =>
      transport != oldWidget.transport;
}
