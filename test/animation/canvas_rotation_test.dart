import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('canvas rotation works', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: _TestRotationPainter(angle: 0)),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/canvas_rotation_0deg.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: _TestRotationPainter(angle: 90)),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/canvas_rotation_90deg.png'),
    );
  });
}

class _TestRotationPainter extends CustomPainter {
  _TestRotationPainter({required this.angle});

  final double angle;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Scale canvas to match SVG viewBox (0-100)
    canvas.save();
    canvas.scale(2.0, 2.0); // 200px / 100 viewBox = 2.0 scale

    // Apply rotation transform around center (50, 50)
    canvas.save();
    canvas.translate(50.0, 50.0);
    canvas.rotate(angle * 3.14159 / 180.0);
    canvas.translate(-50.0, -50.0);

    // Draw rect at (40, 40) with size 20x20
    final paint = ui.Paint()
      ..color = const Color(0xFFFF0000)
      ..style = ui.PaintingStyle.fill;

    canvas.drawRect(const ui.Rect.fromLTWH(40, 40, 20, 20), paint);

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TestRotationPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
