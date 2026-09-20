import 'package:flutter/material.dart';

/// A heart-shaped painter that fills from bottom (positive pleasantness)
/// or from top (negative pleasantness) based on energy level.
class MoodHeartPainter extends CustomPainter {
  final Color color;
  final double fillLevel; // 0.0 (empty) to 1.0 (full)
  final bool fillFromTop; // true = fill downward (negative pleasantness)

  MoodHeartPainter({
    required this.color,
    required this.fillLevel,
    this.fillFromTop = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final heartPath = _buildHeartPath(size);
    final fillHeight = size.height * fillLevel;

    // Draw filled portion
    canvas.save();
    if (fillFromTop) {
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, fillHeight));
    } else {
      canvas.clipRect(Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight));
    }
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, fillPaint);
    canvas.restore();

    // Draw heart outline
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(heartPath, outlinePaint);
  }

  Path _buildHeartPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.06;
    final s = size.width / 24;
    final path = Path();
    path.moveTo(cx, cy + (-2.5) * s);
    path.cubicTo(cx + (-6) * s, cy + (-7) * s, cx + (-10) * s, cy + (-1) * s, cx + (-5) * s, cy + 3 * s);
    path.cubicTo(cx + (-2) * s, cy + 6 * s, cx, cy + 7.5 * s, cx, cy + 7.5 * s);
    path.cubicTo(cx, cy + 7.5 * s, cx + 2 * s, cy + 6 * s, cx + 5 * s, cy + 3 * s);
    path.cubicTo(cx + 10 * s, cy + (-1) * s, cx + 6 * s, cy + (-7) * s, cx, cy + (-2.5) * s);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant MoodHeartPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.fillLevel != fillLevel ||
        oldDelegate.fillFromTop != fillFromTop;
  }
}
