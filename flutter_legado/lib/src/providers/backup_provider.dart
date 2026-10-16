import '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
export '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
import '../features/bookshelf/bookshelf_repositories.dart';
import '../features/book_sources/book_source_repository_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup_service.dart';
import 'restore_ignore_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    repository: ref.watch(backupRepositoryProvider),
    webDav: ref.watch(webDavServiceProvider),
    bookshelf: ref.watch(bookshelfRepositoryProvider),
    sources: ref.watch(bookSourceRepositoryProvider),
    ignore: ref.watch(restoreIgnoreRepositoryProvider),
  );
});
