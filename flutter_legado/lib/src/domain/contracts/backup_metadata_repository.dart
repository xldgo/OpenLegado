import '../models/backup_metadata.dart';

abstract interface class BackupMetadataRepository {
  Future<BackupMetadata> load();
  Future<void> save(BackupMetadata value);
}
