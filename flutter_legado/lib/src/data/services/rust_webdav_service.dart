import '../bridge/rust_errors.dart';
import '../../domain/models/webdav_sync_result.dart';

import 'dart:convert';

import '../bridge/file_dto_mapping.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/webdav_service.dart';
import '../../domain/models/webdav_connection.dart';
import '../../domain/models/webdav_probe_result.dart';
import '../../bridge/file_dto.dart' as dto;

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
  Future<WebDavProbeResult> webdavProbe(WebDavConnection connection) async {
    final result = await rustFuture(
      () => bridge.webdavProbe(configJson: encodeWebDavConfig(connection)),
      operation: 'webdavProbe',
    );
    return WebDavProbeResult(switch (result.status) {
      dto.WebDavProbeStatusDto.success => WebDavProbeStatus.success,
      dto.WebDavProbeStatusDto.authenticationFailed =>
        WebDavProbeStatus.authenticationFailed,
      dto.WebDavProbeStatusDto.httpFailed => WebDavProbeStatus.httpFailed,
      dto.WebDavProbeStatusDto.timedOut => WebDavProbeStatus.timedOut,
      dto.WebDavProbeStatusDto.networkFailed => WebDavProbeStatus.networkFailed,
      dto.WebDavProbeStatusDto.invalidUrl => WebDavProbeStatus.invalidUrl,
    }, statusCode: result.statusCode);
  }

  @override
  Future<List<Map<String, dynamic>>> webdavListDir(
    WebDavConnection connection,
    String path,
  ) async => (await rustFuture(
    () => bridge.webdavListDir(
      configJson: encodeWebDavConfig(connection),
      path: path,
    ),
    operation: 'webdavListDir',
  )).map(webDavFileFromDto).toList();
  @override
  Future<void> webdavUpload(
    WebDavConnection connection,
    String path,
    String data,
  ) => rustFuture(
    () => bridge.webdavUpload(
      configJson: encodeWebDavConfig(connection),
      path: path,
      data: data,
    ),
    operation: 'webdavUpload',
  );
  @override
  Future<void> webdavUploadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) => rustFuture(
    () => bridge.webdavUploadFile(
      configJson: encodeWebDavConfig(connection),
      path: path,
      localFilePath: localFilePath,
    ),
    operation: 'webdavUploadFile',
  );
  @override
  Future<String> webdavDownload(WebDavConnection connection, String path) =>
      rustFuture(
        () => bridge.webdavDownload(
          configJson: encodeWebDavConfig(connection),
          path: path,
        ),
        operation: 'webdavDownload',
      );
  @override
  Future<void> webdavDownloadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) => rustFuture(
    () => bridge.webdavDownloadFile(
      configJson: encodeWebDavConfig(connection),
      path: path,
      localFilePath: localFilePath,
    ),
    operation: 'webdavDownloadFile',
  );
  @override
  Future<void> webdavMkdir(WebDavConnection connection, String path) =>
      rustFuture(
        () => bridge.webdavMkdir(
          configJson: encodeWebDavConfig(connection),
          path: path,
        ),
        operation: 'webdavMkdir',
      );

  @override
  Future<void> webdavDelete(WebDavConnection connection, String path) =>
      rustFuture(
        () => bridge.webdavDelete(
          configJson: encodeWebDavConfig(connection),
          path: path,
        ),
        operation: 'webdavDelete',
      );
  @override
  Future<WebDavSyncResult> webdavFullSync(
    WebDavConnection connection,
    String localBooks,
    String localSources,
  ) async {
    final value = await rustFuture(
      () => bridge.webdavFullSync(
        configJson: encodeWebDavConfig(connection),
        localBooks: localBooks,
        localSources: localSources,
      ),
      operation: 'webdavFullSync',
    );
    return WebDavSyncResult(books: value.books, sources: value.sources);
  }
}
