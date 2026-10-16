import 'dart:convert';

import '../../domain/models/login_v2.dart';
import 'rust_json_decode.dart';

/// 书源和TTS共用现有V2协议，不在控件处理JSON。— Codex + Bridge
LoginUiDescription decodeLoginUi(String raw) {
  final map = decodeRustJsonMap(raw, 'loginUiV2');
  final rows = map['rows'];
  if (rows is! List) throw const FormatException('loginUiV2缺少rows数组');
  return LoginUiDescription(
    rows: [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          LoginUiRow(
            type: row['type']?.toString() ?? '',
            key: row['key']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            value: row['value']?.toString() ?? '',
            hint: row['hint']?.toString() ?? row['name']?.toString() ?? '',
            options: row['options'] is List
                ? List<String>.unmodifiable(
                    (row['options'] as List).map((v) => v.toString()),
                  )
                : const [],
            action: row['action']?.toString() ?? '',
            countdown: int.tryParse(row['countdown']?.toString() ?? ''),
          ),
    ],
  );
}

LoginActionResult decodeLoginAction(String raw) {
  final map = decodeRustJsonMap(raw, 'loginActionV2');
  return LoginActionResult(
    close: map['close'] == true,
    login: map['login'] is Map<String, dynamic>
        ? map['login'] as Map<String, dynamic>
        : null,
    errors: map['error'] is Map<String, dynamic>
        ? map['error'] as Map<String, dynamic>
        : null,
    state: map['state'] is Map<String, dynamic>
        ? map['state'] as Map<String, dynamic>
        : null,
  );
}

String encodeLoginAction({
  required String action,
  required Map<String, dynamic> state,
  required Map<String, dynamic> form,
}) => jsonEncode({
  'action': action,
  'stateJson': jsonEncode(state),
  'formJson': form,
});
