import '../models/webdav_connection.dart';

/// 连接读取与保存独立于普通设置和同步编排。— connection_migration + UI
abstract interface class WebDavConnectionRepository {
  Future<WebDavConnection> load();

  /// 返回已保存的规范化连接；写入失败向调用方报告。
  Future<WebDavConnection> save(WebDavConnection connection);
}
