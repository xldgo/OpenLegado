import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/display/screen_awake.dart';

/// 同一应用内页面共享平台写入队列。— Codex + UI
final screenAwakeProvider = Provider<ScreenAwake>((ref) => ScreenAwake());
