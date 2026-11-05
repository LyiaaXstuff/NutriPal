import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiquidBlob extends StatefulWidget {
  final double size;

  const LiquidBlob({
    super.key,
    this.size = 340,
  });

  @override
  State<LiquidBlob> createState() => _LiquidBlobState();
}

class _LiquidBlobState extends State<LiquidBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(
            widget.size,
            widget.size,
          ),
          painter: LiquidBlobPainter(
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class LiquidBlobPainter extends CustomPainter {
  final double animationValue;

  LiquidBlobPainter({
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final baseRadius =
        math.min(size.width, size.height) * 0.42;

    final paint = Paint()
      ..color = const Color(0xFFF0E8FF)
      ..style = PaintingStyle.fill;

    final path = Path();

    const points = 60;

    for (int i = 0; i <= points; i++) {
      final angle =
          (i / points) * math.pi * 2;

      final wave1 = math.sin(
            angle * 3 +
                animationValue *
                    math.pi *
                    2,
          ) *
          12;

      final wave2 = math.sin(
            angle * 5 -
                animationValue *
                    math.pi *
                    2,
          ) *
          7;

      final radius =
          baseRadius + wave1 + wave2;

      final x =
          center.dx + radius * math.cos(angle);

      final y =
          center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant LiquidBlobPainter oldDelegate,
  ) {
    return oldDelegate.animationValue !=
        animationValue;
  }
}