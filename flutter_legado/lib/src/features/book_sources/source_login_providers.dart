import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/source_login_factory.dart';
import '../../data/services/source_login_service.dart';
import '../../domain/contracts/source_login_repository.dart';
import '../../providers/providers.dart';

/// 各登录入口分享根实例中的同一份原始凭据存储。— Codex + UI
final sourceLoginRepositoryProvider = Provider<SourceLoginRepository>(
  (ref) => ref.watch(bookApiProvider).sourceLoginRepository,
);

/// 新操作跟随根替换，已发起操作保留取得的服务及存储引用。
final sourceLoginServiceProvider = Provider<SourceLoginService>(
  (ref) => createSourceLoginService(ref.watch(bookApiProvider)),
);
