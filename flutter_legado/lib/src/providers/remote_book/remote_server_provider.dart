import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/preferences_remote_server_repository.dart';
import '../../domain/contracts/remote_server_repository.dart';

final remoteServerRepositoryProvider = Provider<RemoteServerRepository>(
  (ref) => PreferencesRemoteServerRepository(),
);
