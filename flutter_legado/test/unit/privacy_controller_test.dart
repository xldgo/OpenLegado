import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/privacy_credential_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';
import 'package:flutter_legado/src/platform/privacy/privacy_platform.dart';
import 'package:flutter_legado/src/models/models.dart';

class TestCredentials implements PrivacyCredentialRepository {
  String password = '口令';
  Completer<bool>? pending;
  @override
  Future<bool> hasPassword() async => password.isNotEmpty;
  @override
  Future<bool> verify(String value) async =>
      pending == null ? value == password : await pending!.future;
  @override
  Future<bool> change(String current, String next) async {
    if (password.isNotEmpty && current != password) return false;
    password = next;
    return true;
  }
}

class TestShelf extends Fake implements BookshelfRepository {
  List<Book> books = [
    const Book(bookUrl: 'private', name: '私密书名', author: '作者', isPrivate: true),
    const Book(bookUrl: 'group', name: '组内书', group: 2),
    const Book(bookUrl: 'public', name: '公开书'),
  ];
  @override
  Future<List<Book>> getBooks() async => books;
  @override
  Future<void> updateBook(Book value) async {
    books = books.map((b) => b.bookUrl == value.bookUrl ? value : b).toList();
  }
}

class TestGroups extends Fake implements BookGroupRepository {
  List<BookGroup> groups = [
    const BookGroup(groupId: 2, groupName: '私密分组', isPrivate: true),
  ];
  @override
  Future<List<BookGroup>> getBookGroups() async => groups;
  @override
  Future<void> updateBookGroup(BookGroup value) async {
    groups = groups.map((g) => g.groupId == value.groupId ? value : g).toList();
  }
}

ProviderContainer privacyContainer({
  TestCredentials? credentials,
  TestShelf? shelf,
  DateTime Function()? clock,
  PrivacyPlatform? platform,
}) => ProviderContainer(
  overrides: [
    privacyCredentialProvider.overrideWithValue(
      credentials ?? TestCredentials(),
    ),
    bookshelfRepositoryProvider.overrideWithValue(shelf ?? TestShelf()),
    bookGroupRepositoryProvider.overrideWithValue(TestGroups()),
    if (clock != null) privacyClockProvider.overrideWithValue(clock),
    if (platform != null) privacyPlatformProvider.overrideWithValue(platform),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('默认关闭；打开后同时锁定单书和私密分组，公开书不受影响', () async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    expect(c.read(privacyControllerProvider).settings.enabled, isFalse);
    await n.update(const PrivacySettings(enabled: true));
    final s = c.read(privacyControllerProvider);
    expect(s.locked(s.books[0]), isTrue);
    expect(s.locked(s.books[1]), isTrue);
    expect(s.locked(s.books[2]), isFalse);
    expect(await n.unlock('错误', bookUrl: 'private'), isFalse);
    expect(await n.unlock('口令', bookUrl: 'private'), isTrue);
    expect(c.read(privacyControllerProvider).locked(s.books[1]), isFalse);
  });
  test('设置验证和启动验证不授予私密内容访问', () async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(
      const PrivacySettings(enabled: true, verifyOnAppStart: true),
    );
    expect(await n.verifyOnly('口令'), isTrue);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
    expect(await n.unlock('口令', appStart: true), isTrue);
    expect(c.read(privacyControllerProvider).startVerified, isTrue);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
  });
  test('每次验证按目标授权，分组覆盖组内书籍，撤销后恢复锁定', () async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(
      const PrivacySettings(enabled: true, scope: PrivacyUnlockScope.everyTime),
    );
    await n.unlock('口令', groupId: 2);
    var s = c.read(privacyControllerProvider);
    expect(s.locked(s.books[0]), isTrue);
    expect(s.locked(s.books[1]), isFalse);
    n.revoke(groupId: 2);
    s = c.read(privacyControllerProvider);
    expect(s.locked(s.books[1]), isTrue);
  });
  test('后台宽限以内保留授权，超时返回重新锁定', () async {
    var now = DateTime(2026, 10, 14);
    final c = privacyContainer(clock: () => now);
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(
      const PrivacySettings(
        enabled: true,
        scope: PrivacyUnlockScope.untilBackground,
        graceSeconds: 30,
      ),
    );
    await n.unlock('口令', bookUrl: 'private');
    n.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 29));
    n.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.read(privacyControllerProvider).unlocked, isTrue);
    n.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 31));
    n.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
  });
  test('锁定之后的迟到验证结果不能重新授权', () async {
    final credentials = TestCredentials();
    final c = privacyContainer(credentials: credentials);
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(const PrivacySettings(enabled: true));
    credentials.pending = Completer<bool>();
    final verification = n.unlock('口令', bookUrl: 'private');
    await Future<void>.delayed(Duration.zero);
    n.lock();
    credentials.pending!.complete(true);
    expect(await verification, isFalse);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
  });
  test('重启只恢复设置，关闭总开关保留私密标记', () async {
    SharedPreferences.setMockInitialValues({
      PrivacyController.settingsKey: jsonEncode(
        const PrivacySettings(enabled: true).toJson(),
      ),
    });
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
    await n.update(const PrivacySettings(enabled: false));
    final s = c.read(privacyControllerProvider);
    expect(s.books.first.isPrivate, isTrue);
    expect(s.hasPassword, isTrue);
    expect(s.locked(s.books.first), isFalse);
  });
  test('清除密码需要旧凭据，并同步关闭私密功能', () async {
    final c = privacyContainer();
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(const PrivacySettings(enabled: true));
    expect(await n.changePassword('错误', ''), isFalse);
    expect(c.read(privacyControllerProvider).hasPassword, isTrue);
    expect(await n.changePassword('口令', ''), isTrue);
    expect(c.read(privacyControllerProvider).settings.enabled, isFalse);
  });
}
