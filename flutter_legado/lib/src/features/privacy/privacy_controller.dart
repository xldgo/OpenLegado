import '../../app/bootstrap/application_dependencies.dart'
    show privacyCredentialProvider;
export '../../app/bootstrap/application_dependencies.dart'
    show privacyCredentialProvider;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/privacy_credential_repository.dart';
import '../../models/models.dart';
import '../bookshelf/bookshelf_repositories.dart';
import 'privacy_settings.dart';
import '../../platform/privacy/privacy_platform.dart';

final privacyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final privacyControllerProvider =
    NotifierProvider<PrivacyController, PrivacyState>(PrivacyController.new);

class PrivacyState {
  const PrivacyState({
    this.settings = const PrivacySettings(),
    this.loading = true,
    this.hasPassword = false,
    this.unlocked = false,
    this.startVerified = false,
    this.books = const [],
    this.groups = const [],
    this.bookGrants = const {},
    this.groupGrants = const {},
    this.biometricStatus = "unavailable",
    this.biometricEnrolled = false,
    this.error,
  });
  final PrivacySettings settings;
  final bool loading, hasPassword, unlocked, startVerified;
  final List<Book> books;
  final List<BookGroup> groups;
  final Set<String> bookGrants;
  final Set<int> groupGrants;
  final String biometricStatus;
  final bool biometricEnrolled;
  final String? error;
  bool privateBook(Book book) =>
      book.isPrivate ||
      groups.any(
        (g) => g.isPrivate && g.groupId > 0 && (book.group & g.groupId) != 0,
      );
  bool locked(Book book) =>
      privateBook(book) &&
      (loading ||
          error != null ||
          (settings.enabled &&
              !unlocked &&
              !bookGrants.contains(book.bookUrl) &&
              !groupGrants.any((g) => (book.group & g) != 0)));
  Book? find(String url) => books.where((b) => b.bookUrl == url).firstOrNull;
  bool lockedIdentity(String name, String author) =>
      books.any((b) => b.name == name && b.author == author && locked(b));
}

/// 会话授权只在内存生效；持久设置写入失败时不发布新状态。— Codex + UI
class PrivacyController extends Notifier<PrivacyState>
    with WidgetsBindingObserver {
  static const settingsKey = 'privacySettings';
  Future<void>? _ready;
  DateTime? _backgroundAt;
  Timer? _timer;
  int _generation = 0;
  @override
  PrivacyState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    Future.microtask(initialize);
    return const PrivacyState();
  }

  Future<void> initialize() => _ready ??= _load();
  PrivacyCredentialRepository get _credentials =>
      ref.read(privacyCredentialProvider);
  void _replace({
    PrivacySettings? settings,
    bool? hasPassword,
    bool? unlocked,
    bool? startVerified,
    List<Book>? books,
    List<BookGroup>? groups,
    Set<String>? bookGrants,
    Set<int>? groupGrants,
    bool clearError = false,
    String? biometricStatus,
    bool? biometricEnrolled,
  }) {
    state = PrivacyState(
      settings: settings ?? state.settings,
      biometricStatus: biometricStatus ?? state.biometricStatus,
      biometricEnrolled: biometricEnrolled ?? state.biometricEnrolled,
      loading: false,
      error: clearError ? null : state.error,
      hasPassword: hasPassword ?? state.hasPassword,
      unlocked: unlocked ?? state.unlocked,
      startVerified: startVerified ?? state.startVerified,
      books: books ?? state.books,
      groups: groups ?? state.groups,
      bookGrants: bookGrants ?? state.bookGrants,
      groupGrants: groupGrants ?? state.groupGrants,
    );
  }

  Future<void> _load() async {
    var restored = const PrivacySettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(settingsKey);
      final settings = raw == null
          ? const PrivacySettings()
          : PrivacySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      restored = settings;
      final has = await _credentials.hasPassword();
      final books = await ref.read(bookshelfRepositoryProvider).getBooks();
      final groups = await ref
          .read(bookGroupRepositoryProvider)
          .getBookGroups();
      if (!ref.mounted) return;
      _replace(
        clearError: true,
        settings: has ? settings : settings.copyWith(enabled: false),
        hasPassword: has,
        books: books,
        groups: groups,
      );
      await refreshCapabilities();
    } catch (_) {
      if (ref.mounted) {
        state = PrivacyState(
          settings: restored,
          loading: false,
          error: '隐私状态读取失败，请重试',
        );
      }
    }
  }

  Future<void> retry() async {
    _ready = null;
    await initialize();
  }

  void syncBooks(List<Book> books) {
    if (ref.mounted && !state.loading) _replace(books: books);
  }

  void syncGroups(List<BookGroup> groups) {
    if (ref.mounted && !state.loading) _replace(groups: groups);
  }

  Future<void> refreshFacts() async {
    final books = await ref.read(bookshelfRepositoryProvider).getBooks();
    final groups = await ref.read(bookGroupRepositoryProvider).getBookGroups();
    if (ref.mounted) _replace(books: books, groups: groups);
  }

  Future<void> update(PrivacySettings settings) async {
    if (settings.enabled && !state.hasPassword) throw StateError('请先设置隐私密码');
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(settingsKey, jsonEncode(settings.toJson()))) {
      throw StateError('隐私设置保存失败');
    }
    if (!ref.mounted) return;
    _generation++;
    _timer?.cancel();
    _replace(
      settings: settings,
      unlocked: false,
      startVerified: false,
      bookGrants: {},
      groupGrants: {},
    );
  }

  Future<bool> verifyOnly(String password) async {
    await initialize();
    if (state.error != null) return false;
    return _credentials.verify(password);
  }

  Future<bool> changePassword(String current, String password) async {
    if (state.hasPassword && !await _credentials.verify(current)) return false;
    final settings = state.settings.copyWith(biometricEnabled: false);
    await update(settings);
    if (!await ref.read(privacyPlatformProvider).clearBiometric()) {
      throw StateError("撤销生物凭据失败");
    }
    final changed = await _credentials.change(current, password);
    if (!changed || !ref.mounted) return false;
    _generation++;
    _replace(
      hasPassword: password.isNotEmpty,
      unlocked: false,
      startVerified: false,
      bookGrants: {},
      groupGrants: {},
    );
    if (password.isEmpty) await update(state.settings.copyWith(enabled: false));
    return true;
  }

  Future<bool> unlock(
    String password, {
    String? bookUrl,
    int? groupId,
    bool appStart = false,
  }) async {
    final generation = _generation;
    final valid = await verifyOnly(password);
    if (!valid || !ref.mounted || generation != _generation) return false;
    if (appStart) {
      _replace(startVerified: true);
      return true;
    }
    if (state.settings.scope == PrivacyUnlockScope.everyTime) {
      _replace(
        bookGrants: {...state.bookGrants, ?bookUrl},
        groupGrants: {...state.groupGrants, ?groupId},
      );
    } else {
      _replace(unlocked: true);
    }
    return true;
  }

  Future<void> refreshCapabilities() async {
    try {
      final capabilities = await ref
          .read(privacyPlatformProvider)
          .capabilities();
      if (ref.mounted) {
        _replace(
          biometricStatus:
              capabilities['biometric'] as String? ?? 'unavailable',
          biometricEnrolled: capabilities['enrolled'] == true,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        _replace(biometricStatus: 'unavailable', biometricEnrolled: false);
      }
    }
  }

  bool _systemAuthenticating = false;
  Future<void> setBiometric(bool enabled) async {
    if (!enabled) {
      await update(state.settings.copyWith(biometricEnabled: false));
      if (!await ref.read(privacyPlatformProvider).clearBiometric()) {
        throw StateError('快捷凭据清理失败');
      }
      await refreshCapabilities();
      return;
    }
    if (_systemAuthenticating) throw StateError("已有验证正在进行");
    if (!state.hasPassword || state.biometricStatus != 'available') {
      throw StateError('设备生物识别不可用');
    }
    final generation = _generation;
    _systemAuthenticating = true;
    try {
      final enrolled = await ref
          .read(privacyPlatformProvider)
          .enrollBiometric();
      if (!ref.mounted || generation != _generation) {
        await ref.read(privacyPlatformProvider).clearBiometric();
        throw StateError("认证会话已失效");
      }
      if (!enrolled) throw StateError('生物识别未完成');
      try {
        await update(state.settings.copyWith(biometricEnabled: true));
      } catch (_) {
        await ref.read(privacyPlatformProvider).clearBiometric();
        rethrow;
      }
      await refreshCapabilities();
    } finally {
      _systemAuthenticating = false;
    }
  }

  Future<bool> unlockBiometric({
    String? bookUrl,
    int? groupId,
    bool appStart = false,
    bool verifyOnly = false,
  }) async {
    if (_systemAuthenticating) return false;
    if (!state.hasPassword ||
        !state.settings.biometricEnabled ||
        !state.biometricEnrolled) {
      return false;
    }
    final generation = _generation;
    _systemAuthenticating = true;
    try {
      final accepted = await ref
          .read(privacyPlatformProvider)
          .authenticateBiometric();
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (!accepted ||
          !ref.mounted ||
          generation != _generation ||
          lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.hidden ||
          lifecycle == AppLifecycleState.detached) {
        return false;
      }
      if (verifyOnly) return true;
      if (appStart) {
        _replace(startVerified: true);
        return true;
      }
      if (state.settings.scope == PrivacyUnlockScope.everyTime) {
        _replace(
          bookGrants: {...state.bookGrants, ?bookUrl},
          groupGrants: {...state.groupGrants, ?groupId},
        );
      } else {
        _replace(unlocked: true);
      }
      return true;
    } finally {
      _systemAuthenticating = false;
    }
  }

  void revoke({String? bookUrl, int? groupId}) {
    if (!ref.mounted || state.settings.scope != PrivacyUnlockScope.everyTime) {
      return;
    }
    _generation++;
    _replace(
      bookGrants: {...state.bookGrants}..remove(bookUrl),
      groupGrants: {...state.groupGrants}..remove(groupId),
    );
  }

  void lock() {
    _generation++;
    if (ref.mounted) _replace(unlocked: false, bookGrants: {}, groupGrants: {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_backgroundAt != null) return;
      _backgroundAt = ref.read(privacyClockProvider)();
      if (!_systemAuthenticating) _generation++;
      if (this.state.settings.scope == PrivacyUnlockScope.untilBackground &&
          !_systemAuthenticating) {
        _timer?.cancel();
        if (this.state.settings.graceSeconds == 0) {
          lock();
        } else {
          _timer = Timer(
            Duration(seconds: this.state.settings.graceSeconds),
            lock,
          );
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      final left = _backgroundAt;
      _backgroundAt = null;
      _timer?.cancel();
      ref.invalidate(privacyPermissionsProvider);
      unawaited(refreshCapabilities());
      if (!_systemAuthenticating &&
          left != null &&
          this.state.settings.scope == PrivacyUnlockScope.untilBackground &&
          ref.read(privacyClockProvider)().difference(left).inSeconds >=
              this.state.settings.graceSeconds) {
        lock();
      }
    }
  }

  Future<void> setBookPrivate(Book book, bool value) async {
    await ref
        .read(bookshelfRepositoryProvider)
        .updateBook(book.copyWith(isPrivate: value));
    if (ref.mounted) {
      _replace(
        books: [
          for (final current in state.books)
            if (current.bookUrl == book.bookUrl)
              current.copyWith(isPrivate: value)
            else
              current,
        ],
      );
    }
    lock();
    await refreshFacts();
  }

  Future<void> setGroupPrivate(BookGroup group, bool value) async {
    await ref
        .read(bookGroupRepositoryProvider)
        .updateBookGroup(group.copyWith(isPrivate: value));
    if (ref.mounted) {
      _replace(
        groups: [
          for (final current in state.groups)
            if (current.groupId == group.groupId)
              current.copyWith(isPrivate: value)
            else
              current,
        ],
      );
    }
    lock();
    await refreshFacts();
  }
}
