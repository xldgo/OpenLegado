/// RustApi 调用异常
class RustApiException implements Exception {
  final String message;
  final String? operation;

  const RustApiException(this.message, {this.operation});

  @override
  String toString() =>
      'RustApiException: $message${operation != null ? ' (operation: $operation)' : ''}';
}
