import '../domain/errors/app_exception.dart';

/// 领域错误消息为空白时的兜底文案。
///
/// 避免 UI 出现「XX 失败: 」这类只有前缀、没有任何信息的空文案。
const String kUnknownErrorMessage = '未知错误';

/// 提取异常的可读错误信息，供 UI 层展示。
///
/// 桥接异常由数据层转换；此处只消费领域消息，不探测任意对象的message字段。
/// 普通异常保留toString，调用方自己的操作前缀保持原位。— Codex + UI
String errorMessage(Object e) {
  if (e is AppException) {
    final message = e.message;
    return message.trim().isEmpty ? kUnknownErrorMessage : message;
  }
  return e.toString();
}
