// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_transform.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

void main() {
  group('Matrix adjacent negative number parsing', () {
    test('parses matrix(0-1 1 0...) format', () {
      final t1 = SvgTransform.parse("matrix(0-1 1 0 136.353074 431.758938)");
      print("Test 1 (0-1): ${t1.length} transforms, values: ${t1.isNotEmpty ? t1[0].values : "none"}");
      
      expect(t1.length, 1);
      expect(t1[0].values.length, 6);
      expect(t1[0].values[0], closeTo(0.0, 0.001));
      expect(t1[0].values[1], closeTo(-1.0, 0.001)); // This is likely failing
    });
    
    test('parses standard comma format', () {
      final t2 = SvgTransform.parse("matrix(0, -1, 1, 0, 136.353074, 431.758938)");
      print("Test 2 (commas): ${t2.length} transforms, values: ${t2.isNotEmpty ? t2[0].values : "none"}");
      
      expect(t2.length, 1);
      expect(t2[0].values.length, 6);
      expect(t2[0].values[0], closeTo(0.0, 0.001));
      expect(t2[0].values[1], closeTo(-1.0, 0.001));
    });
    
    test('parses matrix(0-.363742...) format', () {
      final t3 = SvgTransform.parse("matrix(0-.363742 0.363742 0 93.814966 511.567068)");
      print("Test 3 (0-.363742): ${t3.length} transforms, values: ${t3.isNotEmpty ? t3[0].values : "none"}");
      
      expect(t3.length, 1);
      expect(t3[0].values.length, 6);
      expect(t3[0].values[0], closeTo(0.0, 0.001));
      expect(t3[0].values[1], closeTo(-0.363742, 0.001));
    });
    
    test('parses adjacent decimal points', () {
      // SVG allows ".5.3" to mean "0.5" followed by "0.3"
      // "1.5.3" means "1.5" followed by "0.3"
      final t4 = SvgTransform.parse("matrix(1.5.3 0 1 0 0)");
      
      expect(t4.length, 1);
      expect(t4[0].values.length, 6);
      expect(t4[0].values[0], closeTo(1.5, 0.001));
      expect(t4[0].values[1], closeTo(0.3, 0.001));
      expect(t4[0].values[2], closeTo(0.0, 0.001));
      expect(t4[0].values[3], closeTo(1.0, 0.001));
    });
    
    test('parses exponent notation correctly', () {
      // Exponent sign should not act as separator
      final t5 = SvgTransform.parse("matrix(1e-5 2e+3 0 0 1 0)");
      
      expect(t5.length, 1);
      expect(t5[0].values.length, 6);
      expect(t5[0].values[0], closeTo(0.00001, 0.0000001));
      expect(t5[0].values[1], closeTo(2000.0, 0.001));
    });
  });

  group('Text rendering with matrix transforms', () {
    testWidgets('text with 90-degree rotation matrix renders', (tester) async {
      // This is the matrix format used in astronaut helmet SVG
      const svg = '''
        <svg viewBox="0 0 200 600" xmlns="http://www.w3.org/2000/svg">
          <text transform="matrix(0-1 1 0 136.353074 431.758938)" font-size="20">VERTICAL</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 600),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with scaled rotation matrix renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 600" xmlns="http://www.w3.org/2000/svg">
          <text transform="matrix(0-.363742 0.363742 0 93.814966 511.567068)" font-size="20">SCALED</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 600),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with letter-spacing attribute renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20">
            <tspan letter-spacing="12">SPACED</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with multiple tspans and different letter-spacing', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16">
            <tspan letter-spacing="12">WIDE</tspan>
            <tspan letter-spacing="0">NORMAL</tspan>
            <tspan letter-spacing="20">WIDER</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 400, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with namespaced font-family falls back gracefully', (tester) async {
      // Embedded fonts with namespaced names should fall back to system fonts
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" font-family="eQVNhIKm4qz1:::Orbitron, sans-serif">FALLBACK</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
