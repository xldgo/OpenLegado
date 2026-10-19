import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../features/imports/presentation/association_import_dialog.dart';
import '../utils/legado_deep_link.dart';

/// 监听 Android `legado://` / `yuedu://` 深链并导航到关联导入页
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _channel = MethodChannel('legado/deep_link');

  GlobalKey<NavigatorState>? navigatorKey;
  bool _attached = false;
  int _generation = 0;
  VoidCallback? _onImport;
  String? _lastHandled;
  StreamSubscription<Uri>? _iosLinkSub;

  /// 在 [LegadoApp] 首帧后调用；重复调用安全
  Future<void> attach(
    GlobalKey<NavigatorState> key, {
    VoidCallback? onImport,
  }) async {
    _onImport = onImport;
    navigatorKey = key;
    if (_attached) return;
    _attached = true;
    final generation = ++_generation;
    // [iOS 轨 P2] iOS 走 app_links（Info.plist 已注册 legado/yuedu scheme）；
    // Android 保持 DeepLinkService 通道
    if (Platform.isIOS) {
      final links = AppLinks();
      try {
        final initial = await links.getInitialLink();
        if (generation != _generation || !_attached) return;
        if (initial != null && initial.toString().isNotEmpty) {
          await handleUrl(initial.toString());
        }
      } catch (e) {
        debugPrint('[DeepLink] 初始链路失败：$e');
      }
      if (generation != _generation || !_attached) return;
      _iosLinkSub = links.uriLinkStream.listen(
        (uri) => handleUrl(uri.toString()),
        onError: (e) => debugPrint('[DeepLink] 链路流错误：$e'),
      );
      return;
    }
    _channel.setMethodCallHandler(_onMethodCall);
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (generation != _generation || !_attached) return;
      if (initial != null && initial.isNotEmpty) {
        await handleUrl(initial);
      }
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink 失败：$e');
    }
  }

  /// 取消 iOS 链路流订阅（进程级单例一般不调用；保留以备测试与热重载）
  Future<void> detach() async {
    _generation++;
    _attached = false;
    _channel.setMethodCallHandler(null);
    navigatorKey = null;
    _onImport = null;
    _lastHandled = null;
    final subscription = _iosLinkSub;
    _iosLinkSub = null;
    await subscription?.cancel();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onLink') {
      final url = call.arguments as String?;
      if (url != null && url.isNotEmpty) {
        await handleUrl(url);
      }
    }
  }

  /// 处理深链或平台桥 openUrl 转来的 legado/yuedu URI
  Future<void> handleUrl(String url) async {
    if (!LegadoDeepLink.isImportScheme(url)) return;
    final generation = _generation;
    if (_lastHandled == url) return;
    _onImport?.call();
    _lastHandled = url;

    final parsed = LegadoDeepLink.tryParse(url);
    final nav = navigatorKey?.currentState;
    if (nav == null && !_attached) {
      _lastHandled = null;
      return;
    }
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != _generation) return;
        _lastHandled = null;
        handleUrl(url);
      });
      return;
    }

    final type = parsed?.importType;
    final src = parsed?.srcUrl ?? '';
    // [UI-fix v2.0.174] 同链接去重仅在弹窗存续期生效：弹窗关闭（手动关/
    // 导入完成自动 pop）即清标志，避免同一链接再次点击永远不弹（用户报障
    // 「关联导入无法弹出」根因之一）
    showAssociationImportDialog(
      nav.context,
      url: src.isEmpty ? null : src,
      type: type,
    ).whenComplete(() => _lastHandled = null);
  }
}
