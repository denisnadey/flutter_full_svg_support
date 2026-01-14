import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('SMIL AnimateMotion Integration Tests', () {
    test('animateMotion with path parses correctly', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <circle r="5">
    <animateMotion path="M10,50 Q50,10 90,50 T170,50" dur="5s" repeatCount="indefinite"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      expect(animations[0].type, equals(SmilAnimationType.animateMotion));
      expect(animations[0].attributeName, equals('motion'));
      expect(animations[0].dur, equals(const Duration(seconds: 5)));
      expect(animations[0].repeatCount, equals(double.infinity));
    });

    test('animateMotion interpolates position at t=0', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,100" dur="1s"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt0 = animation.computeValue(0.0) as String?;

      expect(valueAt0, isNotNull);
      expect(valueAt0, contains('translate'));
      expect(valueAt0, contains('0'));
    });

    test('animateMotion interpolates position at t=0.5', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,100" dur="1s"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt05 = animation.computeValue(0.5) as String?;

      expect(valueAt05, isNotNull);
      expect(valueAt05, contains('translate'));
      // Position should be roughly in the middle
      expect(
        valueAt05,
        matches(RegExp(r'translate\([4-6]\d\.\d+,\s*[4-6]\d\.\d+\)')),
      );
    });

    test('animateMotion interpolates position at t=1', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,100" dur="1s"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt1 = animation.computeValue(1.0) as String?;

      expect(valueAt1, isNotNull);
      expect(valueAt1, contains('translate'));
      expect(valueAt1, contains('100'));
    });

    test('animateMotion with rotate="auto" adds rotation', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,0 L100,100" dur="1s" rotate="auto"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt05 = animation.computeValue(0.5) as String?;

      expect(valueAt05, isNotNull);
      expect(valueAt05, contains('translate'));
      expect(valueAt05, contains('rotate'));
    });

    test('animateMotion with rotate="auto-reverse" flips rotation', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,0" dur="1s" rotate="auto-reverse"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt05 = animation.computeValue(0.5) as String?;

      expect(valueAt05, isNotNull);
      expect(valueAt05, contains('translate'));
      expect(valueAt05, contains('rotate'));
      // auto-reverse adds 180 degrees
      expect(valueAt05, contains('180'));
    });

    test('animateMotion with fixed rotate angle', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,100" dur="1s" rotate="45"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt0 = animation.computeValue(0.0) as String?;
      final valueAt05 = animation.computeValue(0.5) as String?;
      final valueAt1 = animation.computeValue(1.0) as String?;

      // All values should have the same rotation angle
      expect(valueAt0, contains('rotate(45'));
      expect(valueAt05, contains('rotate(45'));
      expect(valueAt1, contains('rotate(45'));
    });

    test('animateMotion with keyPoints controls speed', () {
      final svgString = '''
<svg><rect><animateMotion 
  path="M0,0 L100,0 L100,100" 
  dur="1s" 
  keyPoints="0;0.25;1" 
  keyTimes="0;0.8;1"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt0 = animation.computeValue(0.0) as String?;
      final valueAt08 = animation.computeValue(0.8) as String?;

      expect(valueAt0, isNotNull);
      expect(valueAt08, isNotNull);
      // At t=0.8, we should be at keyPoint 0.25 (25% along path)
      expect(valueAt08, contains('translate'));
    });

    test('animateMotion on curved path', () {
      final svgString = '''
<svg><rect><animateMotion 
  path="M50,10 C90,10 90,50 50,50 C10,50 10,10 50,10" 
  dur="4s"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt0 = animation.computeValue(0.0) as String?;
      final valueAt025 = animation.computeValue(0.25) as String?;
      final valueAt05 = animation.computeValue(0.5) as String?;
      final valueAt075 = animation.computeValue(0.75) as String?;

      expect(valueAt0, isNotNull);
      expect(valueAt025, isNotNull);
      expect(valueAt05, isNotNull);
      expect(valueAt075, isNotNull);

      // All positions should be different
      expect(valueAt0, isNot(equals(valueAt025)));
      expect(valueAt025, isNot(equals(valueAt05)));
      expect(valueAt05, isNot(equals(valueAt075)));
    });

    test('animateMotion handles complex path with curves', () {
      final svgString = '''
<svg><rect><animateMotion 
  path="M10,90 C10,30 90,30 90,90 S170,150 170,90" 
  dur="2s"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      for (double t = 0.0; t <= 1.0; t += 0.1) {
        final value = animation.computeValue(t) as String?;
        expect(value, isNotNull);
        expect(value, contains('translate'));
      }
    });

    test('animateMotion with fillMode freeze', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L100,100" dur="1s" fill="freeze"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.fillMode, equals(SmilFillMode.freeze));

      animation.updateForTime(const Duration(seconds: 0));
      expect(animation.isActive, isTrue);

      animation.updateForTime(const Duration(seconds: 2));
      expect(animation.isActive, isFalse);
    });

    test('animateMotion with repeatCount', () {
      final svgString = '''
<svg><rect><animateMotion path="M0,0 L50,50" dur="1s" repeatCount="5"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.repeatCount, equals(5));
      expect(
        animation.getEffectiveEndTime(),
        equals(const Duration(seconds: 5)),
      );
    });

    test('animateMotion performance - handles many position updates', () {
      final svgString = '''
<svg><rect><animateMotion 
  path="M50,10 L61,35 L90,35 L67,52 L77,77 L50,60 L23,77 L33,52 L10,35 L39,35 Z" 
  dur="1s" 
  rotate="auto"/></rect></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final stopwatch = Stopwatch()..start();

      // Simulate 60fps animation
      for (int frame = 0; frame < 60; frame++) {
        final t = frame / 59.0;
        final value = animation.computeValue(t);
        expect(value, isNotNull);
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
