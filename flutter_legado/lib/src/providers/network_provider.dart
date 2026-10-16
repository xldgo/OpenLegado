import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/network_service.dart';
import 'providers.dart';

/// 导入和二进制下载仅依赖共享网络能力。— Codex + UI
final networkServiceProvider = Provider<NetworkService>(
  (ref) => ref.watch(bookApiProvider).networkService,
);
