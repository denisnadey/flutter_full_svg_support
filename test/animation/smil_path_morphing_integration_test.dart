import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('SMIL Path Morphing Integration Tests', () {
    test('animate d attribute parses correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <path d="M10,10 L90,10 L90,90 L10,90 Z">
    <animate attributeName="d"
             from="M10,10 L90,10 L90,90 L10,90 Z"
             to="M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z"
             dur="2s"
             repeatCount="indefinite"/>
  </path>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      expect(animations[0].type, equals(SmilAnimationType.animate));
      expect(animations[0].attributeName, equals('d'));
      expect(animations[0].attributeType, equals(SvgAttributeType.path));
      expect(animations[0].dur, equals(const Duration(seconds: 2)));
      expect(animations[0].repeatCount, equals(double.infinity));
    });

    test('path morphing interpolates at t=0', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 L0,100 Z"
  to="M50,50 L150,50 L150,150 L50,150 Z"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAtStart = animation.computeValue(0.0) as String?;

      expect(valueAtStart, isNotNull);
      expect(valueAtStart, contains('M'));
      expect(valueAtStart, contains('0'));
    });

    test('path morphing interpolates at t=0.5', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 L0,100 Z"
  to="M50,50 L150,50 L150,150 L50,150 Z"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAtMid = animation.computeValue(0.5) as String?;

      expect(valueAtMid, isNotNull);
      expect(valueAtMid, contains('M'));
      expect(valueAtMid, contains('Z'));
      // Paths are normalized to cubic curves during interpolation
      expect(valueAtMid, contains('C'));
    });

    test('path morphing interpolates at t=1', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 L0,100 Z"
  to="M50,50 L150,50 L150,150 L50,150 Z"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAtEnd = animation.computeValue(1.0) as String?;

      expect(valueAtEnd, isNotNull);
      expect(valueAtEnd, contains('M'));
    });

    test('path morphing with values and keyTimes', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  values="M0,0 L100,0 L100,100 Z;M50,0 L150,50 L100,100 Z;M0,50 L100,50 L50,150 Z"
  keyTimes="0;0.5;1"
  dur="3s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.values, isNotNull);
      expect(animation.values!.length, equals(3));
      expect(animation.keyTimes, isNotNull);
      expect(animation.keyTimes!.length, equals(3));

      final valueAt0 = animation.computeValue(0.0);
      expect(valueAt0, isNotNull);

      final valueAt05 = animation.computeValue(0.5);
      expect(valueAt05, isNotNull);

      final valueAt1 = animation.computeValue(1.0);
      expect(valueAt1, isNotNull);
    });

    test('path morphing with calcMode discrete', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 Z"
  to="M50,50 L150,50 L150,150 Z"
  dur="1s"
  calcMode="discrete"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.calcMode, equals(SmilCalcMode.discrete));

      final valueAt0 = animation.computeValue(0.0) as String;
      final valueAt05 = animation.computeValue(0.5) as String;
      final valueAt1 = animation.computeValue(1.0) as String;

      // With discrete mode and from/to, value stays at 'from' until t=1.0
      expect(valueAt0, equals(valueAt05));
      // At t=1.0, it should be 'to'
      expect(valueAt1, isNot(equals(valueAt05)));
    });

    test('path morphing handles complex curves', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M10,90 C10,30 90,30 90,90 Z"
  to="M50,10 C90,50 90,90 50,130 Z"
  dur="2s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt0 = animation.computeValue(0.0) as String?;
      final valueAt05 = animation.computeValue(0.5) as String?;
      final valueAt1 = animation.computeValue(1.0) as String?;

      expect(valueAt0, isNotNull);
      expect(valueAt05, isNotNull);
      expect(valueAt1, isNotNull);

      expect(valueAt0, contains('M'));
      expect(valueAt0, contains('C'));
      expect(valueAt0, contains('Z'));

      expect(valueAt05, contains('M'));
      expect(valueAt05, contains('C'));
      expect(valueAt05, contains('Z'));
    });

    test('path morphing with fillMode freeze', () {
      final svgString = '''
<svg><path d="M0,0 L100,0 L100,100 Z"><animate attributeName="d"
  to="M50,50 L150,50 L150,150 Z"
  dur="1s"
  fill="freeze"/></path></svg>
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

    test('path morphing with repeatCount', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 Z"
  to="M50,50 L150,50 L150,150 Z"
  dur="1s"
  repeatCount="3"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.repeatCount, equals(3));
      expect(
        animation.getEffectiveEndTime(),
        equals(const Duration(seconds: 3)),
      );
    });

    test('path morphing handles invalid paths gracefully', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 Z"
  to="INVALID PATH DATA"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final valueAt05 = animation.computeValue(0.5);
      expect(valueAt05, isNotNull);
    });

    test('path morphing preserves path structure through animation', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M10,10 L50,10 L50,50 L10,50 Z"
  to="M20,20 L80,20 L80,80 L20,80 Z"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      for (double t = 0.0; t <= 1.0; t += 0.1) {
        final value = animation.computeValue(t) as String?;
        expect(value, isNotNull);

        // All paths should start with M and end with Z
        expect(value, matches(RegExp(r'^M.*Z$', dotAll: true)));
        // Paths are normalized to cubic curves during interpolation
        expect(value, contains('C'));
      }
    });

    test('path morphing with begin and end times', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M0,0 L100,0 L100,100 Z"
  to="M50,50 L150,50 L150,150 Z"
  dur="2s"
  begin="1s"
  end="5s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.begin, equals(const Duration(seconds: 1)));
      expect(animation.end, equals(const Duration(seconds: 5)));

      animation.updateForTime(const Duration(milliseconds: 500));
      expect(animation.isActive, isFalse);

      animation.updateForTime(const Duration(milliseconds: 2000));
      expect(animation.isActive, isTrue);

      animation.updateForTime(const Duration(seconds: 6));
      expect(animation.isActive, isFalse);
    });

    test('multiple path morphing animations on same element', () {
      final svgString = '''
<svg><path d="M0,0 L100,0 L100,100 Z">
  <animate attributeName="d" to="M50,50 L150,50 L150,150 Z" dur="1s" begin="0s" end="1s"/>
  <animate attributeName="d" to="M25,25 L125,25 L125,125 Z" dur="1s" begin="1s"/>
</path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(2));
      expect(animations[0].begin, equals(Duration.zero));
      expect(animations[1].begin, equals(const Duration(seconds: 1)));
    });

    test('path morphing performance - handles many interpolations', () {
      final svgString = '''
<svg><path><animate attributeName="d"
  from="M50,10 L61,35 L90,35 L67,52 L77,77 L50,60 L23,77 L33,52 L10,35 L39,35 Z"
  to="M50,90 C50,90 20,65 20,45 C20,30 35,20 50,20 C65,20 80,30 80,45 C80,65 50,90 50,90 Z"
  dur="1s"/></path></svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      final stopwatch = Stopwatch()..start();

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
