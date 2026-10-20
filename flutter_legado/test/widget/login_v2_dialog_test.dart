// LoginV2Dialog widget 测试
//
// 覆盖：V2 rows 渲染（text/password/select/button/label）、countdown、
// action 命令处理（state/error/login/close）、渲染异常防御
// （V2 书源登录红屏排查，2026-08-14）。
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/widgets/login_v2_dialog.dart';

import 'package:flutter_legado/src/domain/contracts/login_v2_session.dart';
import 'package:flutter_legado/src/data/bridge/login_v2_json.dart';
import 'package:flutter_legado/src/domain/models/login_v2.dart';

class _Session extends Mock implements LoginV2Session {}

void main() {
  late _Session session;

  setUp(() {
    session = _Session();
    when(() => session.name).thenReturn('测试源');
  });

  Future<void> pumpDialog(WidgetTester tester, {required String uiJson}) async {
    when(() => session.loadUi(any()))
        .thenAnswer((_) async => decodeLoginUi(uiJson));
    when(
      () => session.execute(
        action: any(named: 'action'),
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer((_) async => decodeLoginAction('{"state":{}}'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => LoginV2Dialog(session: session),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('全类型 rows 渲染无异常（text/password/label/select/button）', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      uiJson: jsonEncode({
        'rows': [
          {'key': 'phone', 'name': '手机号', 'type': 'text'},
          {'key': 'pwd', 'name': '密码', 'type': 'password'},
          {'name': '提示', 'type': 'label', 'value': '请输入手机号'},
          {
            'key': 'gender',
            'name': '性别',
            'type': 'select',
            'options': ['男', '女'],
          },
          {'name': '发送验证码', 'type': 'button', 'action': 'sendCode'},
        ],
      }),
    );

    expect(find.text('登录 - 测试源'), findsOneWidget);
    expect(find.text('手机号'), findsWidgets);
    expect(find.text('密码'), findsWidgets);
    expect(find.text('提示'), findsOneWidget);
    // select 行显示当前选中值（options.first）
    expect(find.text('男'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空 options 的 select 渲染无异常（防御 options.first）', (tester) async {
    await pumpDialog(
      tester,
      uiJson: jsonEncode({
        'rows': [
          {
            'key': 'empty',
            'name': '空选择',
            'type': 'select',
            'options': <String>[],
          },
        ],
      }),
    );

    expect(find.text('空选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺 key 的 text 行渲染无异常（防御 putIfAbsent('
      ')）', (tester) async {
    await pumpDialog(
      tester,
      uiJson: jsonEncode({
        'rows': [
          {'name': '无key输入', 'type': 'text'},
        ],
      }),
    );

    expect(find.text('无key输入'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loginUiV2 返回非法 JSON 时显示错误不崩溃', (tester) async {
    when(() => session.loadUi(any()))
        .thenAnswer((_) async => decodeLoginUi('not-json{'));
    when(
      () => session.execute(
        action: any(named: 'action'),
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer((_) async => decodeLoginAction('{}'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => LoginV2Dialog(session: session),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 对话框仍在（错误显示在框内），无红屏
    expect(find.text('登录 - 测试源'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('state命令重载表单并保留输入，按钮倒计时结束后恢复', (tester) async {
    final rows = [
      {'type': 'text', 'key': 'account', 'name': '账号'},
      {'type': 'button', 'action': 'send', 'name': '发送', 'countdown': 2},
    ];
    await pumpDialog(tester, uiJson: jsonEncode({'rows': rows}));
    await tester.enterText(find.byType(TextField), '账号甲');
    when(
      () => session.execute(
        action: 'send',
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer((call) async {
      expect(call.namedArguments[#form], {'account': '账号甲'});
      return LoginActionResult(state: {'step': 2});
    });
    when(() => session.loadUi({'step': 2})).thenAnswer(
      (_) async => decodeLoginUi(
        jsonEncode({
          'rows': [
            ...rows,
            {'type': 'label', 'name': '第二步'},
          ],
        }),
      ),
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('第二步'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '账号甲',
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    expect(find.text('发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('error命令保留表单；login与error同时返回时按原优先级关闭', (tester) async {
    await pumpDialog(
      tester,
      uiJson: '{"rows":[{"type":"text","key":"account","name":"账号"},{"type":"button","action":"login","name":"登录"}]}',
    );
    await tester.enterText(find.byType(TextField), '账号甲');
    when(
      () => session.execute(
        action: 'login',
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer((_) async => LoginActionResult(errors: {'account': '账号错误'}));
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.text('账号错误'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '账号甲',
    );
    when(
      () => session.execute(
        action: 'login',
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer(
      (_) async => LoginActionResult(login: {}, errors: {'account': '不应显示'}),
    );
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginV2Dialog), findsNothing);
    expect(find.text('不应显示'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
