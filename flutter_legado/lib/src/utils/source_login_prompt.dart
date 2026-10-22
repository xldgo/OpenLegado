import '../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';

import '../domain/errors/app_exception.dart';
import '../models/book_source.dart';
import '../features/book_sources/presentation/source_login_screen.dart';

/// 是否为 loginCheckJs 判定的「书源需要登录」错误（错误码 1012 / 文案对齐）。
bool isSourceLoginRequiredError(Object? error) {
  if (error == null) return false;
  final msg = error is AppException ? error.message : error.toString();
  return msg.contains('书源需要登录') ||
      msg.contains('LoginRequired') ||
      msg.contains('login_required') ||
      msg.contains('1012');
}

String sourceLoginRequiredMessage(Object? error, {String? fallback}) {
  if (error is AppException && error.message.isNotEmpty) {
    return error.message;
  }
  final s = error?.toString() ?? '';
  if (s.contains('书源需要登录')) return s;
  return fallback ?? '书源需要登录，请先在书源菜单中登录后重试';
}

/// 弹出登录提示并可选跳转 [SourceLoginScreen]（对齐原版 LoginSourceException 引导）。
Future<void> promptSourceLoginIfNeeded(
  BuildContext context, {
  required Object? error,
  required BookSource? source,
}) async {
  if (!isSourceLoginRequiredError(error) || source == null) return;
  if (!context.mounted) return;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.loginRequiredTitle),
      content: Text(
        sourceLoginRequiredMessage(
          error,
          fallback: ctx.l10n.sourceLoginRetryHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.goToLogin),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  await SourceLoginScreen.open(
    context,
    sourceUrl: source.bookSourceUrl,
    sourceName: source.bookSourceName,
    loginUrl: source.loginUrl,
  );
}
