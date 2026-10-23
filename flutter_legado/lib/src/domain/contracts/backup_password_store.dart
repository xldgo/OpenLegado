/// 本地备份密码由平台凭据存储拥有，不进入普通设置或备份文件。
abstract interface class BackupPasswordStore {
  Future<String?> read();
  Future<void> write(String? password);
}
