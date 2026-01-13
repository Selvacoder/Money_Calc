import 'package:flutter/material.dart';

class ArrowTabPainter extends CustomPainter {
  final Color color;
  final double arrowSize;
  final double radius;

  ArrowTabPainter({
    required this.color,
    this.arrowSize = 8.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Main rectangle
    final rect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height - arrowSize,
      Radius.circular(radius),
    );
    path.addRRect(rect);

    // Arrow triangle
    path.moveTo(size.width / 2 - arrowSize, size.height - arrowSize);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + arrowSize, size.height - arrowSize);
    path.close();

    // Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 2.0, true);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
