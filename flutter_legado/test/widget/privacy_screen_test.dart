import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';
import 'package:flutter_legado/src/features/privacy/privacy_screen.dart';
import 'package:flutter_legado/src/features/privacy/privacy_gate.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/models/misc.dart';

import '../unit/privacy_controller_test.dart'
    show privacyContainer, TestCredentials;
import '../unit/privacy_platform_test.dart' show TestPrivacyPlatform;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('私密分组锁定时保留切组操作，逐次授权离组后撤销', (tester) async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final controller = c.read(privacyControllerProvider.notifier);
    await controller.initialize();
    await controller.update(
      const PrivacySettings(enabled: true, scope: PrivacyUnlockScope.everyTime),
    );
    BookGroup? group = const BookGroup(groupId: 2, isPrivate: true);
    late StateSetter update;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => group = null),
                      child: const Text('切回全部'),
                    ),
                    Expanded(
                      child: PrivacyGroupGate(
                        group: group,
                        child: Text(group == null ? '全部书籍' : '组内正文'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('组内正文'), findsNothing);
    expect(find.text('切回全部'), findsOneWidget);
    await tester.tap(find.text('验证后查看私密分组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '口令');
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    expect(find.text('组内正文'), findsOneWidget);
    update(() => group = null);
    await tester.pumpAndSettle();
    expect(c.read(privacyControllerProvider).groupGrants, isEmpty);
    expect(find.text('全部书籍'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('默认显示凭据与验证设置，Firebase和未接入的空开关不展示', (tester) async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('解锁凭据'), findsOneWidget);
    expect(find.text('验证时机'), findsOneWidget);
    expect(find.text('修改隐私密码'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.text('离开后重新验证'), findsNothing);
    await tester.tap(find.text('验证有效期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离开应用前有效'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('离开后重新验证'), 120);
    expect(find.text('离开后重新验证'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('没有密码时总开关禁用，设置入口保留', (tester) async {
    final credentials = TestCredentials()..password = '';
    final c = privacyContainer(credentials: credentials);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置隐私密码'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.first.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('生物识别取消不打开开关，iOS能力只显示通知权限', (tester) async {
    final platform = TestPrivacyPlatform()..accepted = false;
    final c = privacyContainer(platform: platform);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生物识别快捷解锁'));
    await tester.pumpAndSettle();
    expect(
      c.read(privacyControllerProvider).settings.biometricEnabled,
      isFalse,
    );
    expect(find.text('生物识别设置未完成'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('通知权限'), 180);
    expect(find.text('已允许'), findsOneWidget);
    expect(find.text('后台运行权限'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('进入启用状态的设置页只验证，不解锁书籍', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrivacyController.settingsKey: jsonEncode(
        const PrivacySettings(enabled: true).toJson(),
      ),
    });
    final c = privacyContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('解锁凭据'), findsNothing);
    await tester.tap(find.text('验证后进入隐私设置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '错误');
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    expect(find.text('密码不正确'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '口令');
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    expect(find.text('解锁凭据'), findsOneWidget);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('锁定正文不创建，验证后可进入，回锁后立即移除正文', (tester) async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(const PrivacySettings(enabled: true));
    var builds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: PrivacyBookGate(
            book: const Book(bookUrl: 'private'),
            builder: (_) {
              builds++;
              return const Text('小说正文');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(builds, 0);
    expect(find.text('小说正文'), findsNothing);
    await tester.tap(find.text('验证后阅读'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '口令');
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    expect(find.text('小说正文'), findsOneWidget);
    n.lock();
    await tester.pumpAndSettle();
    expect(find.text('小说正文'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('私密列表不暴露原文或语义，公开内容正常显示', (tester) async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(const PrivacySettings(enabled: true));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PrivacyMaskedContent(
                  bookName: '私密书名',
                  author: '作者',
                  child: Text('秘密正文与封面'),
                ),
                PrivacyMaskedContent(
                  book: Book(bookUrl: 'public'),
                  child: Text('公开书'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('秘密正文与封面'), findsNothing);
    expect(find.bySemanticsLabel('秘密正文与封面'), findsNothing);
    expect(find.text('公开书'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
