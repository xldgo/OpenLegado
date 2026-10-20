import 'package:material_ui/material_ui.dart';

import '../../../../theme/app_motion.dart';

class BookExpandableText extends StatefulWidget {
  final String text;

  const BookExpandableText({super.key, required this.text});

  @override
  State<BookExpandableText> createState() => BookExpandableTextState();
}

class BookExpandableTextState extends State<BookExpandableText> {
  // [UI-fix v2.0.11 | 2026-08-10] 简介默认全部显示（用户反馈），
  // 保留「收起」按钮供手动折叠；短简介仍由 showToggle 自适应隐藏切换控件 — Reasonix
  bool _expanded = true;

  /// 折叠态显示行数（对齐原版折叠约 3 行）
  static const int _collapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      // [UI-fix v2.0.7 | 2026-08-08] 用 TextPainter 预测折叠态是否真的截断正文：
      // 仅在超过 _collapsedLines 行时才显示「展开/收起」控件，短简介整段直接显示
      // （按内容自适应，替代此前 length>100 的粗略字数阈值——后者会漏判「刚好
      // 超 3 行但不足百字」的简介，导致尾部被省略号截断却无展开入口） — Qoder
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: _collapsedLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final showToggle = painter.didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [UI-fix v2.0.7 | 2026-08-08] 移除「简介」标题 heading：对齐原版
              // 无标签、直接显示简介正文 — Qoder
              AnimatedCrossFade(
                firstChild: Text(
                  widget.text,
                  maxLines: _collapsedLines,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
                secondChild: Text(widget.text, style: style),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 200),
                ),
              ),
              // [UI-fix v2.0.7 | 2026-08-08] 展开/收起：右对齐 + 主题色文字，
              // 对齐原版底部右下角切换控件（省略号硬截断改为可展开/收起） — Qoder
              if (showToggle)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _expanded ? '收起' : '展开',
                        style: TextStyle(color: cs.primary, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 变量设置对话框（供设置源变量/设置书籍变量复用）
///
/// [Task #70 D1 修复 | 2026-08-10] 照 source_screen.dart 的
/// _TextPromptDialog 范式实现自持 StatefulWidget：controller 在 State
/// 内 late final 创建、dispose 随子树卸载统一释放，确定按钮先取值再
/// Navigator.pop(ctx, value)，规避外部作用域 controller 在退场动画期间
/// 提前 dispose 引发的 framework.dart '_dependents.isEmpty' 断言 +
/// OverlayEntry Duplicate GlobalKey 红屏 — Qoder
///
/// 回传约定：确定 → pop 输入值（可为空串，空串=清除语义由调用方保持）；
/// 取消/系统关闭 → pop 无值（null），调用方不保存。
