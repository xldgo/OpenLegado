import 'dart:convert';

import '../../bridge/transfer_dto.dart' as dto;

/// 领域接口仍接受用户提供的校验 JSON；跨 FFI 前转换为字段快照。— Codex + Bridge
/// 单次校验错误向上报告，批量校验沿用既有配置错误回落默认值的规则。
dto.SourceCheckConfigDto sourceCheckConfig(
  String? raw, {
  bool fallbackOnError = false,
}) {
  try {
    final value = (raw?.trim().isEmpty ?? true)
        ? <String, dynamic>{}
        : jsonDecode(raw!);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('校验配置必须是对象');
    }
    final timeout = value['step_timeout_ms'] as int?;
    if (timeout != null && timeout < 0) {
      throw const FormatException('校验超时不能为负数');
    }
    return dto.SourceCheckConfigDto(
      keyword: value['keyword'] as String?,
      stepTimeoutMs: timeout == null ? null : BigInt.from(timeout),
      checkSearch: value['check_search'] as bool?,
      checkToc: value['check_toc'] as bool?,
      checkContent: value['check_content'] as bool?,
      detectCaptcha: value['detect_captcha'] as bool?,
      detectRedirect: value['detect_redirect'] as bool?,
    );
  } catch (_) {
    if (fallbackOnError) {
      return const dto.SourceCheckConfigDto();
    }
    rethrow;
  }
}

Map<String, dynamic> platformActionToMap(dto.PlatformActionDto value) => {
  'action': value.action.name,
  if (value.url != null) 'url': value.url,
  if (value.html != null) 'html': value.html,
  if (value.js != null) 'js': value.js,
  if (value.title != null) 'title': value.title,
  if (value.mimeType != null) 'mimeType': value.mimeType,
  if (value.text != null) 'text': value.text,
  if (value.message != null) 'message': value.message,
  if (value.result != null) 'result': value.result,
  if (value.cookie != null) 'cookie': value.cookie,
  if (value.sourceRegex != null) 'sourceRegex': value.sourceRegex,
  if (value.overrideUrlRegex != null)
    'overrideUrlRegex': value.overrideUrlRegex,
  if (value.sourceKey != null) 'sourceKey': value.sourceKey,
  if (value.tag != null) 'tag': value.tag,

  'isFloat': value.isFloat,
  'isRule': value.isRule,
  'cacheFirst': value.cacheFirst,
  'delayTime': value.delayTimeMs,
};
Future<String> resolveTextResponse(
  dto.TextResponseDto response,
  Future<String> Function(Map<String, dynamic>) dispatch,
) => switch (response) {
  dto.TextResponseDto_Text(:final field0) => Future.value(field0),
  dto.TextResponseDto_PlatformAction(:final field0) => dispatch(
    platformActionToMap(field0),
  ),
};
