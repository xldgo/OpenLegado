import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/preferences_sync_metadata_repository.dart';
import '../domain/contracts/sync_metadata_repository.dart';

final syncMetadataRepositoryProvider = Provider<SyncMetadataRepository>(
  (ref) => PreferencesSyncMetadataRepository(),
);
