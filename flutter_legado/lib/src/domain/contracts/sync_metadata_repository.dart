/// 同步结果元数据独立于用户同步策略。— connection_migration + UI
abstract interface class SyncMetadataRepository {
  Future<DateTime?> load();
  Future<void> save(DateTime time);
}
