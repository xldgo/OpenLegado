import '../../../../utils/error_message.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/source_login_credentials.dart';
import '../../source_login_providers.dart';
import '../../../../models/misc.dart' show LoginKeyValue;
import 'source_login_state.dart';

export 'source_login_state.dart';

/// 按书源 URL 隔离的手动凭据编辑状态。— Codex + UI
class SourceLoginNotifier extends Notifier<SourceLoginState> {
  SourceLoginNotifier(this.sourceUrl);
  final String sourceUrl;
  int _loadGeneration = 0;
  int _editGeneration = 0;
  Future<void>? _saving;

  /// 页面回填输入框前核对是否仍是同一次草稿加载。
  int get editGeneration => _editGeneration;

  @override
  SourceLoginState build() => const SourceLoginState();

  /// 空记录清空当前草稿；过期结果和销毁后的结果不回写。
  Future<void> load() async {
    if (!ref.mounted || _saving != null) return;
    final generation = ++_loadGeneration;
    state = const SourceLoginState(isLoading: true);
    try {
      final service = ref.read(sourceLoginServiceProvider);
      final value = await service.load(sourceUrl);
      if (!ref.mounted || generation != _loadGeneration) return;
      state = SourceLoginState(
        token: value.token,
        cookies: value.cookies,
        headers: value.headers,
      );
    } catch (error) {
      if (!ref.mounted || generation != _loadGeneration) return;
      state = SourceLoginState(error: errorMessage(error));
    }
  }

  void _invalidateLoad() {
    _loadGeneration++;
    _editGeneration++;
    state = state.copyWith(isLoading: false);
  }

  /// 设置 Token
  void setToken(String token) {
    _invalidateLoad();
    state = state.copyWith(token: token);
  }

  /// 添加 Cookie
  void addCookie(String name, String value) {
    _invalidateLoad();
    state = state.copyWith(
      cookies: [
        ...state.cookies,
        LoginKeyValue(name: name, value: value),
      ],
    );
  }

  /// 删除指定下标的 Cookie
  void removeCookie(int index) {
    if (index < 0 || index >= state.cookies.length) return;
    _invalidateLoad();
    final list = [...state.cookies]..removeAt(index);
    state = state.copyWith(cookies: list);
  }

  /// 添加 Header
  void addHeader(String name, String value) {
    _invalidateLoad();
    state = state.copyWith(
      headers: [
        ...state.headers,
        LoginKeyValue(name: name, value: value),
      ],
    );
  }

  /// 删除指定下标的 Header
  void removeHeader(int index) {
    if (index < 0 || index >= state.headers.length) return;
    _invalidateLoad();
    final list = [...state.headers]..removeAt(index);
    state = state.copyWith(headers: list);
  }

  /// 清空所有凭据（仅清状态，需配合 [save] 持久化）
  void clear() {
    _invalidateLoad();
    state = state.copyWith(token: '', cookies: [], headers: []);
  }

  /// 重复调用共用在途结果；URL 与两份 JSON 来自开始时的固定快照。
  Future<void> save() {
    final pending = _saving;
    if (pending != null) return pending;
    if (!ref.mounted) return Future.error(StateError('登录页面已关闭'));
    if (state.isLoading) return Future.error(StateError('登录信息正在加载'));
    final service = ref.read(sourceLoginServiceProvider);
    final snapshot = SourceLoginCredentials(
      token: state.token,
      cookies: state.cookies,
      headers: state.headers,
    );
    _loadGeneration++;
    state = state.copyWith(isSaving: true, error: null);
    final task = () async {
      try {
        await service.save(sourceUrl, snapshot);
        if (ref.mounted) state = state.copyWith(isSaving: false);
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(isSaving: false, error: errorMessage(error));
        }
        rethrow;
      } finally {
        _saving = null;
      }
    }();
    _saving = task;
    return task;
  }
}

/// 每个源拥有独立草稿，页面无消费者时释放，不持有另一源的凭据。
final sourceLoginNotifierProvider = NotifierProvider.autoDispose
    .family<SourceLoginNotifier, SourceLoginState, String>(
      SourceLoginNotifier.new,
    );
