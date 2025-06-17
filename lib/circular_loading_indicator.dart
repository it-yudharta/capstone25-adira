import 'dart:math';
import 'package:flutter/material.dart';

class CircularExportIndicator extends StatelessWidget {
  final double progress;

  const CircularExportIndicator({required this.progress, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentText = '${(progress * 100).toInt()}%';

    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white, // Latar belakang putih
        borderRadius: BorderRadius.circular(12), // Sudut membulat
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _CircularProgressPainter(progress),
              child: Center(
                child: Text(
                  percentText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Exporting Data',
            style: TextStyle(fontSize: 12, color: Colors.black),
          ),
        ],
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
    final Paint backgroundPaint =
        Paint()
          ..color = const Color(0x4D0E5C36)
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

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
