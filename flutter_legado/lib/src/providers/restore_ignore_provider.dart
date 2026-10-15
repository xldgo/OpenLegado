import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/preferences_restore_ignore_repository.dart';
import '../domain/contracts/restore_ignore_repository.dart';

final restoreIgnoreRepositoryProvider = Provider<RestoreIgnoreRepository>(
  (ref) => PreferencesRestoreIgnoreRepository(),
);
