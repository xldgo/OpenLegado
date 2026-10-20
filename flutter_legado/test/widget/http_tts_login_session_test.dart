import 'package:flutter_legado/src/app/bootstrap/login_v2_session_factory.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_session.dart';
import 'package:flutter_legado/src/widgets/classic_login_dialog.dart';
import 'package:flutter_legado/src/widgets/login_v2_dialog.dart';

/// 同一登录控件消费 TTS 窄会话，不构造 BookSource 或写入书源配置。— Codex + UI
final class _Session implements SourceLoginSession {
  _Session({this.isV2 = false});
  @override
  final bool isV2;
  @override
  String get key => 'httpTts:-900';
  @override
  String get name => '测试 TTS';
  @override
  bool get hasLoginScript => true;
  String info = '{"账号":"已保存账号"}';
  final scripts = <String>[];
  final inputs = <String>[];
  @override
  Future<String> loadUi(String state) async => isV2
      ? '{"rows":[{"name":"账号","type":"text","key":"account"},{"name":"登录","type":"button","action":"login"}]}'
      : '[{"name":"账号","type":"text"}]';
  @override
  Future<String> executeV2(String input) async {
    inputs.add(input);
    return '{"login":{"account":"new"},"close":true}';
  }

  @override
  Future<Map<String, dynamic>> execute(String script) async {
    scripts.add(script);
    return {'result': '', 'actions': <dynamic>[]};
  }

  @override
  Future<String> getInfo() async => info;
  @override
  Future<void> putInfo(String value) async {
    info = value;
  }

  @override
  Future<String> getHeader() async => '';
  @override
  Future<void> putHeader(String value) async {}
  @override
  Future<String> requestHeaders() async => '{}';
}

void main() {
  testWidgets('经典 TTS 登录预填与确认写回独立会话', (tester) async {
    final session = _Session();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ClassicLoginDialog.session(session: session),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('已保存账号'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '新账号');
    final confirm = find.byTooltip('确认');
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(jsonDecode(session.info)['账号'], '新账号');
    expect(session.scripts.single, contains('login.apply(this)'));
    expect(find.byType(ClassicLoginDialog), findsNothing);
  });

  testWidgets('V2 TTS 登录复用动态表单与动作命令', (tester) async {
    final session = _Session(isV2: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => LoginV2Dialog(
                  session: createHttpTtsLoginV2Session(session),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '账号甲');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    final request = jsonDecode(session.inputs.single);
    expect(request['action'], 'login');
    expect(request['formJson']['account'], '账号甲');
    expect(find.byType(LoginV2Dialog), findsNothing);
  });
}
