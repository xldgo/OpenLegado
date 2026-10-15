import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/webdav_service.dart';
import '../../domain/models/webdav_connection.dart';

/// 配置字段保持Rust原协议，空目录用于自定义服务器根目录。— Codex + Bridge
String encodeWebDavConfig(WebDavConnection connection) => jsonEncode({
  'url': connection.url,
  'username': connection.username,
  'password': connection.password,
  'remote_dir': connection.directoryPrefix,
});

final class RustWebDavService implements WebDavService {
  const RustWebDavService();
  @override
  Future<List<Map<String, dynamic>>> webdavListDir(
    WebDavConnection connection,
    String path,
  ) async => decodeWebDavDirectory(
    await bridge.webdavListDir(
      configJson: encodeWebDavConfig(connection),
      path: path,
    ),
  );
  @override
  Future<void> webdavUpload(
    WebDavConnection connection,
    String path,
    String data,
  ) => bridge.webdavUpload(
    configJson: encodeWebDavConfig(connection),
    path: path,
    data: data,
  );
  @override
  Future<void> webdavUploadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) => bridge.webdavUploadFile(
    configJson: encodeWebDavConfig(connection),
    path: path,
    localFilePath: localFilePath,
  );
  @override
  Future<String> webdavDownload(WebDavConnection connection, String path) =>
      bridge.webdavDownload(
        configJson: encodeWebDavConfig(connection),
        path: path,
      );
  @override
  Future<void> webdavDownloadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) => bridge.webdavDownloadFile(
    configJson: encodeWebDavConfig(connection),
    path: path,
    localFilePath: localFilePath,
  );
  @override
  Future<void> webdavDelete(WebDavConnection connection, String path) => bridge
      .webdavDelete(configJson: encodeWebDavConfig(connection), path: path);
  @override
  Future<String> webdavFullSync(
    WebDavConnection connection,
    String localBooks,
    String localSources,
  ) => bridge.webdavFullSync(
    configJson: encodeWebDavConfig(connection),
    localBooks: localBooks,
    localSources: localSources,
  );
}

/// 目录协议在数据边界解码；保留原非对象条目跳过语义。
List<Map<String, dynamic>> decodeWebDavDirectory(String payload) {
  final decoded = jsonDecode(payload);
  if (decoded is! List) throw const FormatException('目录列表格式错误');
  return decoded.whereType<Map<String, dynamic>>().toList();
}
