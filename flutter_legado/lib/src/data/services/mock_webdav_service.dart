import '../../domain/models/webdav_sync_result.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../domain/models/webdav_connection.dart';
import '../../domain/models/webdav_probe_result.dart';

/// 保留原Mock远程能力，不执行真实网络请求。— Codex + Bridge
final class MockWebDavService implements WebDavService {
  const MockWebDavService();
  @override
  Future<WebDavProbeResult> webdavProbe(WebDavConnection connection) async =>
      const WebDavProbeResult(WebDavProbeStatus.success, statusCode: 207);
  @override
  Future<List<Map<String, dynamic>>> webdavListDir(
    WebDavConnection connection,
    String path,
  ) async => const [];
  @override
  Future<void> webdavUpload(
    WebDavConnection connection,
    String path,
    String data,
  ) async {}
  @override
  Future<void> webdavUploadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<String> webdavDownload(
    WebDavConnection connection,
    String path,
  ) async => '';
  @override
  Future<void> webdavDownloadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> webdavMkdir(WebDavConnection connection, String path) async {}

  @override
  Future<void> webdavDelete(WebDavConnection connection, String path) async {}
  @override
  Future<WebDavSyncResult> webdavFullSync(
    WebDavConnection connection,
    String localBooks,
    String localSources,
  ) async => WebDavSyncResult(books: localBooks, sources: localSources);
}
