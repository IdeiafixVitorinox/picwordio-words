import 'package:flutter/material.dart';
import 'draw_point.dart';

class GameCanvasPainter extends CustomPainter {
  final List<DrawPoint> points;

  GameCanvasPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].status != PointStatus.end &&
          points[i + 1].status != PointStatus.start) {
        final paint = Paint()
          ..color = points[i].color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = points[i].strokeWidth;

        canvas.drawLine(
          Offset(points[i].x, points[i].y),
          Offset(points[i + 1].x, points[i + 1].y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
