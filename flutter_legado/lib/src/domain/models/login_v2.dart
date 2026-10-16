/// 动态登录表单的行定义，不携带JSON传输细节。— Codex + Bridge
class LoginUiRow {
  const LoginUiRow({
    this.type = '',
    this.key = '',
    this.name = '',
    this.value = '',
    this.hint = '',
    this.options = const [],
    this.action = '',
    this.countdown,
  });
  final String type;
  final String key;
  final String name;
  final String value;
  final String hint;
  final List<String> options;
  final String action;
  final int? countdown;
}

class LoginUiDescription {
  LoginUiDescription({required List<LoginUiRow> rows})
    : rows = List.unmodifiable(rows);
  final List<LoginUiRow> rows;
}

/// 保留命令组合，控件按close/login、error、state的原优先级处理。
class LoginActionResult {
  LoginActionResult({
    this.close = false,
    Map<String, dynamic>? login,
    Map<String, dynamic>? errors,
    Map<String, dynamic>? state,
  }) : login = login == null ? null : Map.unmodifiable(login),
       errors = errors == null ? null : Map.unmodifiable(errors),
       state = state == null ? null : Map.unmodifiable(state);
  final bool close;
  final Map<String, dynamic>? login;
  final Map<String, dynamic>? errors;
  final Map<String, dynamic>? state;
}
