import 'dart:math';
import 'package:flutter/material.dart';

class CircularExportIndicator extends StatelessWidget {
  final double progress;

  const CircularExportIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percentText = '${(progress * 100).toInt()}%';

    return CustomPaint(
      painter: _CircularProgressPainter(progress),
      child: Center(
        child: Text(
          percentText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black, // hitam bold
          ),
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;

  _CircularProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = min(size.width, size.height) / 2 - 4;

    // Gambar background lingkaran penuh (fill)
    final Paint backgroundPaint =
        Paint()
          ..color = const Color(0x4D0E5C36) // 30% opacity fill
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Gambar lingkaran progress (stroke)
    final Paint progressPaint =
        Paint()
          ..color = const Color(0xFF0E5C36)
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final double startAngle = -pi / 2;
    final double sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
