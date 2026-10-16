import 'dart:convert';

import '../../domain/contracts/login_v2_session.dart';
import '../../domain/contracts/source_login_session.dart';
import '../../domain/contracts/source_login_v2_service.dart';
import '../../domain/models/login_v2.dart';
import '../../models/book_source.dart';
import '../bridge/login_v2_json.dart';

/// 动态登录的两种输入适配，共享控件只接收类型化协议。— Codex + Bridge
class BookSourceLoginV2Session implements LoginV2Session {
  BookSourceLoginV2Session(this.service, this.source);
  final SourceLoginV2Service service;
  final BookSource source;
  @override
  String get name => source.bookSourceName;
  @override
  Future<LoginUiDescription> loadUi(Map<String, dynamic> state) =>
      service.loadUi(source, state);
  @override
  Future<LoginActionResult> execute({
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  }) => service.execute(source, action: action, state: state, form: form);
}

/// 只适配已有TTS字符串协议，不改变其操作名、ID或持久化。
class HttpTtsLoginV2Session implements LoginV2Session {
  HttpTtsLoginV2Session(this.session);
  final SourceLoginSession session;
  @override
  String get name => session.name;
  @override
  Future<LoginUiDescription> loadUi(Map<String, dynamic> state) async =>
      decodeLoginUi(await session.loadUi(jsonEncode(state)));
  @override
  Future<LoginActionResult> execute({
    required String action,
    required Map<String, dynamic> state,
    required Map<String, dynamic> form,
  }) async => decodeLoginAction(
    await session.executeV2(
      encodeLoginAction(action: action, state: state, form: form),
    ),
  );
}
