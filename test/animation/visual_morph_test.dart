import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/path_parser.dart';
import 'package:flutter_svg/src/animation/path_normalizer.dart';
import 'package:flutter_svg/src/animation/path_interpolation.dart';

void main() {
  testWidgets('Visual test of path morphing', (WidgetTester tester) async {
    final parser = PathParser();
    final normalizer = PathNormalizer();

    const squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
    const circlePath =
        'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

    final squareCommands = parser.parse(squarePath);
    final circleCommands = parser.parse(circlePath);

    final normalized = normalizer.normalize(squareCommands, circleCommands);
    final morpher = PathMorpher(
      fromCommands: normalized.from,
      toCommands: normalized.to,
    );

    // Test widget that shows morphing
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomPaint(
              painter: _TestPathPainter(morpher.getPathAt(0.5)),
              size: const Size(300, 300),
            ),
          ),
        ),
      ),
    );

    // Just verify it doesn't crash
    expect(find.byType(CustomPaint), findsWidgets);

    print('\n=== Visual test successful ===');
    print('The widget builds without errors');
    print('PathMorpher.getPathAt(0.5) produces a valid path');
  });
}

class _TestPathPainter extends CustomPainter {
  _TestPathPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TestPathPainter oldDelegate) => true;
}
