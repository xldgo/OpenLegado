import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/web_keep_alive_service.dart';

/// 页面消费可替换的保活能力，生产仍共享应用实例。— Codex + UI
final webKeepAliveServiceProvider = Provider<WebKeepAliveService>(
  (ref) => WebKeepAliveService.instance,
);
