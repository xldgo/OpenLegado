import 'dart:async';

/// 统计快照订阅存储成功变更，避免依赖记录页的搜索和排序状态。
abstract interface class ReadRecordChangeSource {
  Stream<void> get changes;
}

/// 通知只在持久化成功后发送；订阅者随 Provider 生命周期取消订阅。— Codex + UI
mixin ReadRecordChangeNotifications implements ReadRecordChangeSource {
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  void notifyReadRecordChanged() => _changes.add(null);
}
