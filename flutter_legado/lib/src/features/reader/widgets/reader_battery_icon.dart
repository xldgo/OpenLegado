import 'package:flutter/widgets.dart';

/// 对照上游28×12横向电池：外框固定，内部17宽的槽位按真实电量填充。— Codex + UI
class ReaderBatteryIcon extends StatelessWidget {
  const ReaderBatteryIcon({
    super.key,
    required this.level,
    required this.color,
  });

  final int? level;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '电量',
    value: level == null ? '未知' : '$level%',
    child: SizedBox(
      width: 28,
      height: 12,
      child: CustomPaint(painter: _BatteryPainter(level, color)),
    ),
  );
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter(this.level, this.color);
  final int? level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 28, size.height / 12);
    // 与上游ic_battery缩放到28宽、垂直裁成12高后的外框对应。
    final outline = Paint()
      ..color = color.withValues(alpha: color.a * .76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1667;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(2.9167, .75, 22.6153, 11.25),
        const Radius.circular(2.2),
      ),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(24.365, 3.55, 25.667, 8.47),
        const Radius.circular(.7),
      ),
      Paint()..color = outline.color,
    );
    if (level == null) {
      // 未知不能画成空电或满电，用外框内短横与独立语义区分。
      canvas.drawLine(const Offset(9, 6), const Offset(16, 6), outline);
    } else if (level! > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4.2, 2, 17 * level!.clamp(0, 100) / 100, 8),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BatteryPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.color != color;
}
