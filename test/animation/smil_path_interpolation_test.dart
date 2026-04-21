import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/smil/interpolators.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('Path Interpolation Tests', () {
    test('interpolatePath with simple shapes', () {
      // Square to circle
      const square = 'M10,10 L90,10 L90,90 L10,90 Z';
      const circle =
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

      // At t=0, should be square
      final result0 = Interpolators.interpolatePath(square, circle, 0.0);
      expect(result0, isNotEmpty);
      expect(result0, contains('M'));

      // At t=1, should be circle
      final result1 = Interpolators.interpolatePath(square, circle, 1.0);
      expect(result1, isNotEmpty);
      expect(result1, contains('M'));

      // With incompatible segment lists, interpolation falls back to discrete
      // switching and snaps to `to` at t >= 0.5.
      final result05 = Interpolators.interpolatePath(square, circle, 0.5);
      expect(result05, isNotEmpty);
      expect(result05, contains('M'));
      expect(result05, equals(circle));

      // Results should respect discrete switch behavior.
      expect(result0, isNot(equals(result05)));
      expect(result05, equals(result1));
    });

    test('interpolatePath with empty paths', () {
      const path1 = 'M10,10 L90,90';
      const emptyPath = '';

      // Empty "to" path - should return fromPath when t < 0.5
      final result1 = Interpolators.interpolatePath(path1, emptyPath, 0.3);
      expect(result1, equals(path1));

      // Empty "to" path - should return emptyPath when t >= 0.5
      final result2 = Interpolators.interpolatePath(path1, emptyPath, 0.7);
      expect(result2, equals(emptyPath));

      // Empty "from" path
      final result3 = Interpolators.interpolatePath(emptyPath, path1, 0.3);
      expect(result3, equals(emptyPath));

      final result4 = Interpolators.interpolatePath(emptyPath, path1, 0.7);
      expect(result4, equals(path1));
    });

    test('interpolatePath clamps t to [0, 1]', () {
      const path1 = 'M0,0 L100,100';
      const path2 = 'M50,50 L150,150';

      // Negative t should behave like 0 (return interpolation at t=0)
      final resultNeg = Interpolators.interpolatePath(path1, path2, -1.0);
      final result0 = Interpolators.interpolatePath(path1, path2, 0.0);

      // Both should be similar (clamped to 0)
      expect(resultNeg, contains('M0.00'));
      expect(result0, contains('M0.00'));

      // t > 1 should behave like 1 (return interpolation at t=1)
      final resultOver = Interpolators.interpolatePath(path1, path2, 2.0);
      final result1 = Interpolators.interpolatePath(path1, path2, 1.0);

      // Both should be similar (clamped to 1)
      expect(resultOver, contains('M50.00'));
      expect(result1, contains('M50.00'));
    });

    test('interpolatePath handles star to heart', () {
      const star =
          'M50,10 L61,35 L90,35 L67,52 L78,85 L50,65 L22,85 L33,52 L10,35 L39,35 Z';
      const heart =
          'M50,90 C50,90 20,65 20,45 C20,30 27,20 40,20 C47,20 50,25 50,25 C50,25 53,20 60,20 C73,20 80,30 80,45 C80,65 50,90 50,90 Z';

      final result = Interpolators.interpolatePath(star, heart, 0.5);
      expect(result, isNotEmpty);
      expect(result, contains('M'));
      expect(result, contains('C'));
      expect(result, contains('Z'));
    });

    test('interpolatePath preserves path structure', () {
      const path1 = 'M10,10 L50,10 L50,50 Z';
      const path2 = 'M20,20 L60,20 L60,60 Z';

      for (double t = 0.0; t <= 1.0; t += 0.1) {
        final result = Interpolators.interpolatePath(path1, path2, t);

        // Should always start with M (MoveTo)
        expect(result, startsWith('M'));

        // Should always end with Z (ClosePath)
        expect(result.trim(), endsWith('Z'));

        // Should contain numeric values
        expect(result, matches(RegExp(r'\d+')));
      }
    });

    test('interpolatePath returns valid SVG path syntax', () {
      const path1 = 'M0,0 L100,0 L100,100 L0,100 Z';
      const path2 = 'M50,0 L100,50 L50,100 L0,50 Z';

      final result = Interpolators.interpolatePath(path1, path2, 0.3);

      // Should be valid path string
      expect(result, isNotEmpty);

      // Should have proper command letters
      expect(result, contains(RegExp(r'[MCZ]')));

      // Should have numbers
      expect(result, contains(RegExp(r'\d+\.?\d*')));

      // Should not have consecutive spaces
      expect(result, isNot(contains('  ')));
    });

    test('interpolatePath handles invalid paths gracefully', () {
      const validPath = 'M10,10 L50,50 Z';
      const invalidPath = 'not a valid path';

      // Should not throw, should fallback to discrete interpolation
      expect(
        () => Interpolators.interpolatePath(validPath, invalidPath, 0.5),
        returnsNormally,
      );

      // At t < 0.5 should return validPath (discrete interpolation)
      final result1 = Interpolators.interpolatePath(
        validPath,
        invalidPath,
        0.3,
      );
      expect(result1, equals(validPath));

      // At t >= 0.5 should return invalidPath (discrete interpolation)
      final result2 = Interpolators.interpolatePath(
        validPath,
        invalidPath,
        0.7,
      );
      expect(result2, equals(invalidPath));
    });
  });

  group('Interpolate with SvgAttributeType.path', () {
    test('uses path interpolation for path type', () {
      const square = 'M10,10 L90,10 L90,90 L10,90 Z';
      const circle =
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

      final result = Interpolators.interpolate(
        square,
        circle,
        0.5,
        SvgAttributeType.path,
      );

      expect(result, isA<String>());
      expect(result, isNotEmpty);
      expect(result, contains('M'));
      expect(result, equals(circle));
    });

    test('path interpolation at extremes', () {
      const path1 = 'M0,0 L100,100 Z';
      const path2 = 'M50,50 L150,150 Z';

      // At t=0, should be close to path1
      final result0 = Interpolators.interpolate(
        path1,
        path2,
        0.0,
        SvgAttributeType.path,
      );
      expect(result0, contains('M0'));

      // At t=1, should be close to path2
      final result1 = Interpolators.interpolate(
        path1,
        path2,
        1.0,
        SvgAttributeType.path,
      );
      expect(result1, contains('M50'));
    });
  });
}
