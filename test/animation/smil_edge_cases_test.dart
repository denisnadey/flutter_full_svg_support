import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('SMIL Edge Cases and Error Handling', () {
    test('handles empty SVG gracefully', () {
      final svgString = '<svg></svg>';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, isEmpty);
    });

    test('handles SVG without animations', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="10" y="10" width="80" height="80" fill="blue"/>
  <circle cx="50" cy="50" r="20" fill="red"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, isEmpty);
    });

    test('handles animation without attributeName', () {
      final svgString = '''
<svg>
  <rect>
    <animate from="0" to="100" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should be ignored since attributeName is required
      expect(animations, isEmpty);
    });

    test('handles animation without dur attribute', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" from="10" to="50"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should be ignored since dur is required
      expect(animations, isEmpty);
    });

    test('handles animateMotion without path', () {
      final svgString = '''
<svg>
  <rect>
    <animateMotion dur="2s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should be ignored since path is required for animateMotion
      expect(animations, isEmpty);
    });

    test('handles animateMotion with unresolved mpath reference', () {
      final svgString = '''
<svg>
  <rect>
    <animateMotion dur="2s">
      <mpath href="#missingPath"/>
    </animateMotion>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should be ignored since mpath reference can't be resolved.
      expect(animations, isEmpty);
    });

    test('handles invalid path data in animateMotion', () {
      final svgString = '''
<svg>
  <circle r="5">
    <animateMotion path="invalid path data" dur="1s"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Animation is parsed but computeValue handles invalid path gracefully
      expect(animations.length, equals(1));

      final value = animations[0].computeValue(0.5);
      // Should return null or safe value for invalid path
      expect(value, anyOf(isNull, isA<String>()));
    });

    test('handles invalid path in path morphing', () {
      final svgString = '''
<svg>
  <path d="M10,10 L90,90">
    <animate attributeName="d" 
             from="M10,10 L90,90" 
             to="invalid path" 
             dur="1s"/>
  </path>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Should handle invalid path gracefully with discrete fallback
      final value = animation.computeValue(0.5);
      expect(value, isNotNull);
    });

    test('handles empty path in path morphing', () {
      final svgString = '''
<svg>
  <path d="M10,10 L90,90">
    <animate attributeName="d" 
             from="M10,10 L90,90" 
             to="" 
             dur="1s"/>
  </path>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Should handle empty path gracefully
      final valueAt0 = animation.computeValue(0.0);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, isNotNull);
      expect(valueAt1, isNotNull);
    });

    test('handles mismatched keyTimes and values length', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" 
             values="0;50;100" 
             keyTimes="0;1"
             dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should fail validation and not create animation
      expect(animations, isEmpty);
    });

    test('handles mismatched keySplines and values length', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" 
             values="10;50;100" 
             keyTimes="0;0.5;1"
             keySplines="0.5 0 0.5 1"
             calcMode="spline"
             dur="1s"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should fail validation (need 2 splines for 3 values)
      expect(animations, isEmpty);
    });

    test('handles t values outside [0,1] range', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" from="10" to="100" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // computeValue doesn't clamp t - that's done at higher level
      // But it should handle extreme values without crashing
      final valueAtNegative = animation.computeValue(-1.0);
      final valueAtOver = animation.computeValue(2.0);

      expect(valueAtNegative, isA<double>()); // Should not crash
      expect(valueAtOver, isA<double>()); // Should not crash
    });

    test('handles zero duration', () {
      final svgString = '''
<svg>
  <rect opacity="0">
    <animate attributeName="opacity" from="0" to="1" dur="0s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.dur, equals(Duration.zero));

      // Even with zero duration, should handle gracefully
      final value = animation.computeValue(0.5);
      expect(value, isNotNull);
    });

    test('handles very large repeatCount', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" from="10" to="50" dur="1s" repeatCount="999999"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.repeatCount, equals(999999));

      final endTime = animation.getEffectiveEndTime();
      expect(endTime.inSeconds, equals(999999));
    });

    test('handles negative time values', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" from="0" to="100" begin="1s" dur="2s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Update with negative time
      animation.updateForTime(const Duration(seconds: -1));
      expect(animation.isActive, isFalse);
    });

    test('handles complex nested SVG structure', () {
      final svgString = '''
<svg>
  <g>
    <g>
      <rect>
        <animate attributeName="width" from="10" to="100" dur="1s"/>
      </rect>
    </g>
  </g>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('width'));
    });

    test('handles multiple animations on same element', () {
      final svgString = '''
<svg>
  <rect x="0" y="0" width="10" height="10">
    <animate attributeName="x" from="0" to="100" dur="1s"/>
    <animate attributeName="y" from="0" to="100" dur="1s"/>
    <animate attributeName="width" from="10" to="50" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(3));
      expect(animations[0].attributeName, equals('x'));
      expect(animations[1].attributeName, equals('y'));
      expect(animations[2].attributeName, equals('width'));
    });

    test('handles animateTransform without type', () {
      final svgString = '''
<svg>
  <rect>
    <animateTransform attributeName="transform" from="0" to="360" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should be ignored since type is required for animateTransform
      expect(animations, isEmpty);
    });

    test('handles malformed duration values', () {
      final svgString = '''
<svg>
  <rect opacity="0">
    <animate attributeName="opacity" from="0" to="1" dur="invalid"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should fail to parse and not create animation
      expect(animations, isEmpty);
    });

    test('handles malformed color values', () {
      final svgString = '''
<svg>
  <rect fill="#000">
    <animate attributeName="fill" from="#000" to="notacolor" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Animation is created, but color parsing should handle invalid values
      expect(animation, isNotNull);

      final value = animation.computeValue(0.5);
      expect(value, isNotNull); // Should not crash
    });

    test('handles very small time increments', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" from="10" to="100" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Test with very small increments
      for (double t = 0.0; t <= 1.0; t += 0.001) {
        final value = animation.computeValue(t);
        expect(value, isA<double>());
        expect(value, greaterThanOrEqualTo(10.0));
        expect(value, lessThanOrEqualTo(100.0));
      }
    });

    test('handles path morphing with different command counts', () {
      final svgString = '''
<svg>
  <path d="M10,10 L90,90">
    <animate attributeName="d" 
             from="M10,10 L90,90" 
             to="M10,10 L50,50 L90,90 L90,10 Z" 
             dur="1s"/>
  </path>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // PathNormalizer should handle different command counts
      final valueAt0 = animation.computeValue(0.0) as String;
      final valueAt05 = animation.computeValue(0.5) as String;
      final valueAt1 = animation.computeValue(1.0) as String;

      expect(valueAt0, contains('M'));
      expect(valueAt05, contains('M'));
      expect(valueAt1, contains('M'));
    });

    test('handles concurrent animation updates', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" from="0" to="100" dur="1s" begin="0s"/>
  </rect>
  <circle cx="0">
    <animate attributeName="cx" from="0" to="100" dur="2s" begin="0s"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(2));

      // Update both animations at same time
      final time = const Duration(milliseconds: 500);
      for (final anim in animations) {
        anim.updateForTime(time);
        expect(anim.isActive, isTrue);
      }
    });

    test('handles animation with from but no to or by', () {
      final svgString = '''
<svg>
  <rect width="50">
    <animate attributeName="width" from="10" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Should use base value as 'to' if available
      final value = animation.computeValue(0.5);
      expect(value, isNotNull);
    });

    test('handles animation with to but no from', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" to="100" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Should use base value as 'from'
      final valueAt0 = animation.computeValue(0.0);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, isNotNull);
      expect(valueAt1, equals(100.0));
    });

    test('handles animation with by instead of to', () {
      final svgString = '''
<svg>
  <rect x="10">
    <animate attributeName="x" from="10" by="50" dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // 'by' means additive: to = from + by
      final valueAt0 = animation.computeValue(0.0);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, equals(10.0));
      expect(valueAt1, equals(60.0)); // 10 + 50
    });
  });
}
