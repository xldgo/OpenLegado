/// 默认服务器使用备份设置中的WebDAV连接。— connection_migration + UI
const defaultRemoteServerId = -1;

/// 远程书库自定义服务器（对齐原版 Server + WebDavConfig）
final class RemoteServerConfig {
  final int id;
  final String name;
  final String url;
  final String username;
  final String password;

  const RemoteServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.username = '',
    this.password = '',
  });

  factory RemoteServerConfig.fromJson(Map<String, dynamic> json) {
    return RemoteServerConfig(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
  };

  RemoteServerConfig copyWith({
    int? id,
    String? name,
    String? url,
    String? username,
    String? password,
  }) => RemoteServerConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    username: username ?? this.username,
    password: password ?? this.password,
  );
}

/// 服务器目录与选中项的不可变已保存快照。— connection_migration + UI
final class RemoteServerSnapshot {
  RemoteServerSnapshot({
    Iterable<RemoteServerConfig> servers = const [],
    this.selectedId = defaultRemoteServerId,
  }) : servers = List.unmodifiable(servers);

  final List<RemoteServerConfig> servers;
  final int selectedId;
}
