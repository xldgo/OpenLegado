import '../models/remote_server_config.dart';

/// 服务器集合与选中项独立保存，修改以最新持久值为准。— connection_migration + UI
abstract interface class RemoteServerRepository {
  Future<RemoteServerSnapshot> load();
  Future<RemoteServerSnapshot> save(RemoteServerConfig server);
  Future<RemoteServerSnapshot> select(int id);
  Future<RemoteServerSnapshot> delete(int id);
}
