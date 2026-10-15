import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup_service.dart';
import '../domain/contracts/backup_repository.dart';
import '../domain/contracts/webdav_service.dart';
import 'providers.dart';
import 'restore_ignore_provider.dart';

final webDavServiceProvider = Provider<WebDavService>(
  (ref) => ref.watch(bookApiProvider).webDavService,
);
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => ref.watch(bookApiProvider).backupRepository,
);
final backupServiceProvider = Provider<BackupService>((ref) {
  final api = ref.watch(bookApiProvider);
  return BackupService(
    repository: ref.watch(backupRepositoryProvider),
    webDav: ref.watch(webDavServiceProvider),
    bookshelf: api.bookshelfRepository,
    sources: api.bookSourceRepository,
    ignore: ref.watch(restoreIgnoreRepositoryProvider),
  );
});
