/// 同一设置入口按用户操作顺序保存，单次失败不阻塞后续操作。
class SettingsWriteQueue {
  Future<void> _pending = Future<void>.value();

  Future<void> run(Future<void> Function() save) {
    final result = _pending.then((_) => save());
    // 调用方仍收到本次错误；队列尾部只负责让后续写入继续执行。
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
