import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/preferences_webdav_connection_repository.dart';
import '../domain/contracts/webdav_connection_repository.dart';

final webDavConnectionRepositoryProvider = Provider<WebDavConnectionRepository>(
  (ref) => PreferencesWebDavConnectionRepository(),
);
