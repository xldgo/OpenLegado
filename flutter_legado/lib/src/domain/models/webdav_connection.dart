/// WebDAV 连接快照，不含同步偏好或同步结果。— connection_migration + UI
final class WebDavConnection {
  const WebDavConnection({
    this.url = '',
    this.username = '',
    this.password = '',
    this.remoteDir = '/legado/',
    this.deviceName = '',
  });

  final String url;
  final String username;
  final String password;
  final String remoteDir;
  final String deviceName;

  /// 沿用原保存规则，密码中的首尾空白也是凭据的一部分。
  WebDavConnection get normalized => WebDavConnection(
    url: url.trim(),
    username: username.trim(),
    password: password,
    remoteDir: remoteDir.trim().isEmpty ? '/legado/' : remoteDir.trim(),
    deviceName: deviceName.trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is WebDavConnection &&
      url == other.url &&
      username == other.username &&
      password == other.password &&
      remoteDir == other.remoteDir &&
      deviceName == other.deviceName;

  @override
  int get hashCode =>
      Object.hash(url, username, password, remoteDir, deviceName);
}
