import 'package:material_ui/material_ui.dart';

import '../features/tools/presentation/code_edit_screen.dart';

/// 将当前字段与光标交给代码编辑页，返回后回填并恢复焦点。
Future<void> editSourceFieldCode(
  BuildContext context, {
  required String title,
  required TextEditingController controller,
  required FocusNode focusNode,
}) async {
  final result = await CodeEditScreen.open(
    context,
    title: title,
    initialText: controller.text,
    cursorPosition: controller.selection.baseOffset.clamp(
      0,
      controller.text.length,
    ),
  );
  if (!context.mounted) return;
  if (result != null) {
    controller.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
  focusNode.requestFocus();
}
