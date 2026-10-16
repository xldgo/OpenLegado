import '../../domain/contracts/login_v2_session.dart';
import '../../domain/contracts/source_login_session.dart';
import '../../domain/contracts/source_login_v2_service.dart';
import '../../models/book_source.dart';
import '../../data/services/login_v2_sessions.dart';

/// 装配有界会话，控件只消费类型化表单与动作。— Codex + UI
LoginV2Session createSourceLoginV2Session(
  SourceLoginV2Service service,
  BookSource source,
) => BookSourceLoginV2Session(service, source);
LoginV2Session createHttpTtsLoginV2Session(SourceLoginSession session) =>
    HttpTtsLoginV2Session(session);
