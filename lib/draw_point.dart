import 'package:flutter/material.dart';

enum PointStatus { start, move, end }

class DrawPoint {
  final double x;
  final double y;
  final PointStatus status;
  final Color color;
  final double strokeWidth;

  DrawPoint({
    required this.x,
    required this.y,
    required this.status,
    this.color = Colors.black,
    this.strokeWidth = 4.0,
  });
}
