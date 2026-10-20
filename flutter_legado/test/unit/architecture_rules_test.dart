import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_architecture.dart';

void main() {
  test('解析真正指令，注释和字符串中的import不会误报', () {
    final code =
        "// import '../bridge/frb_generated.dart';\nconst example = \"import '../bridge/x.dart';\";";
    expect(checkDependencies('src/features/view.dart', code), isEmpty);
  });
  test('相对路径、包路径和条件转导出都不能绕过界面桥接边界', () {
    for (final code in [
      "import '../bridge/frb_generated.dart';",
      "export 'package:flutter_legado/src/data/../bridge/x.dart';",
      "import 'ok.dart' if (dart.library.io) 'package:flutter_rust_bridge/flutter_rust_bridge.dart';",
      "part '../bridge/x.dart';",
    ]) {
      expect(checkDependencies('src/features/view.dart', code), hasLength(1));
    }
  });
  test('领域只依赖契约和模型，拒绝界面与数据实现', () {
    expect(
      checkDependencies(
        'src/domain/contracts/books.dart',
        "import '../models/book.dart'; import 'dart:async';",
      ),
      isEmpty,
    );
    expect(
      checkDependencies(
        'src/domain/contracts/books.dart',
        "import '../../data/store.dart'; import 'package:material_ui/material_ui.dart';",
      ),
      hasLength(2),
    );
  });
  test('数据适配器可以使用生成桥接', () {
    expect(
      checkDependencies(
        'src/data/repositories/books.dart',
        "import '../../bridge/book_api.dart';",
      ),
      isEmpty,
    );
  });
}
