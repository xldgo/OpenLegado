import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/device_name.dart';

/// 设置展示和备份命名共用本次应用运行的自动名称。— Codex + UI
final systemDeviceNameProvider = FutureProvider<String>(
  (ref) => readSystemDeviceName(),
);
