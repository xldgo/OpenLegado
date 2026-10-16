import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/local_server_service.dart';
import 'providers.dart';

/// 本地服务控制与设置存储分别注入。— Codex + UI
final localServerServiceProvider = Provider<LocalServerService>(
  (ref) => ref.watch(bookApiProvider).localServerService,
);
