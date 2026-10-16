import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/config_repository.dart';
import 'providers.dart';

/// 底层配置只供设置存储和领域适配器装配。— Codex + UI
final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ref.watch(bookApiProvider).configRepository,
);
