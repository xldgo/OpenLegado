import 'package:material_ui/material_ui.dart';

import 'md3_loading_indicator.dart';

/// 居中加载动画组件
///
/// 默认使用 MD3 波浪加载指示器，减少动画时显示静态弧。
/// 页面可通过 [indicator] 替换指示器，并负责其动画偏好适配。
class LoadingIndicator extends StatelessWidget {
  final String? message;

  /// 页面可提供专用指示器，消息布局与其他页面的默认样式保持共用。
  final Widget? indicator;

  /// 消息行下方的自定义子内容（如等待时长计时文本），可选
  final Widget? subMessage;

  const LoadingIndicator({
    super.key,
    this.message,
    this.subMessage,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator ?? Md3LoadingIndicator(color: colorScheme.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (subMessage != null) ...[const SizedBox(height: 8), subMessage!],
        ],
      ),
    );
  }
}
