import '../models/webdav_sync_result.dart';
import '../models/webdav_connection.dart';

/// 远程传输能力，连接持久化和同步编排由各自入口管理。— Codex + Bridge
abstract interface class WebDavService {
  Future<List<Map<String, dynamic>>> webdavListDir(
    WebDavConnection connection,
    String path,
  );
  Future<void> webdavUpload(
    WebDavConnection connection,
    String path,
    String data,
  );
  Future<void> webdavUploadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  );
  Future<String> webdavDownload(WebDavConnection connection, String path);
  Future<void> webdavDownloadFile(
    WebDavConnection connection,
    String path,
    String localFilePath,
  );
  Future<void> webdavDelete(WebDavConnection connection, String path);
  Future<WebDavSyncResult> webdavFullSync(
    WebDavConnection connection,
    String localBooks,
    String localSources,
  );
}
