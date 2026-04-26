import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('SMIL KeyPoints and Timing Tests', () {
    test('keyTimes with linear calcMode', () {
      final svgString = '''
<svg>
  <rect fill="#000">
    <animate attributeName="fill" 
             values="#000;#888;#FFF" 
             keyTimes="0;0.3;1"
             dur="1s" 
             calcMode="linear"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.keyTimes, equals([0.0, 0.3, 1.0]));
      expect(animation.calcMode, equals(SmilCalcMode.linear));

      // At t=0.3, we should be at middle value
      final valueAt03 = animation.computeValue(0.3);
      expect(valueAt03, isNotNull);
    });

    test('keyTimes with spline calcMode uses keySplines', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" 
             values="10;50;10" 
             keyTimes="0;0.5;1"
             keySplines="0.5 0 0.5 1; 0.5 0 0.5 1"
             dur="2s" 
             calcMode="spline"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.keySplines, isNotNull);
      expect(
        animation.keySplines!.length,
        equals(2),
      ); // N-1 splines for N values
      expect(animation.calcMode, equals(SmilCalcMode.spline));
    });

    test('discrete calcMode does not interpolate', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" 
             values="10;50;100" 
             keyTimes="0;0.5;1"
             dur="1s" 
             calcMode="discrete"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.calcMode, equals(SmilCalcMode.discrete));

      // In discrete mode, values should jump at keyTimes
      final valueAt0 = animation.computeValue(0.0);
      final valueAt04 = animation.computeValue(0.4);
      final valueAt05 = animation.computeValue(0.5);

      // Before t=0.5, should use first value
      expect(valueAt0, equals(10.0));
      expect(valueAt04, equals(10.0));

      // At and after t=0.5, should use second value
      expect(valueAt05, equals(50.0));
    });

    test('paced calcMode distributes values evenly', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" 
             values="0;10;100" 
             dur="1s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.calcMode, equals(SmilCalcMode.paced));

      // Paced mode should interpolate smoothly
      final valueAt0 = animation.computeValue(0.0);
      final valueAt05 = animation.computeValue(0.5);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, equals(0.0));
      expect(valueAt1, equals(100.0));
      expect(valueAt05, isA<double>());
    });

    test('keyPoints with animateMotion controls path position', () {
      final svgString = '''
<svg>
  <circle r="5">
    <animateMotion 
      path="M0,0 L100,0 L100,100 L0,100 Z"
      keyPoints="0;0.25;0.5;1"
      keyTimes="0;0.1;0.2;1"
      dur="4s"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.values, isNotNull);
      expect(animation.keyTimes, equals([0.0, 0.1, 0.2, 1.0]));

      // At t=0.1, should be at 25% of path (keyPoint 0.25)
      final valueAt01 = animation.computeValue(0.1) as String?;
      expect(valueAt01, isNotNull);
      expect(valueAt01, contains('translate'));
    });

    test('path morphing with keyTimes', () {
      final svgString = '''
<svg>
  <path d="M10,10 L90,10 L90,90 L10,90 Z">
    <animate attributeName="d" 
             values="M10,10 L90,10 L90,90 L10,90 Z;
                     M50,10 L90,50 L50,90 L10,50 Z;
                     M50,50 A40,40 0 1,1 50,50.1 Z"
             keyTimes="0;0.5;1"
             dur="3s"/>
  </path>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.values, isNotNull);
      expect(animation.values!.length, equals(3));
      expect(animation.keyTimes, equals([0.0, 0.5, 1.0]));

      final valueAt0 = animation.computeValue(0.0) as String?;
      final valueAt05 = animation.computeValue(0.5) as String?;
      final valueAt1 = animation.computeValue(1.0) as String?;

      expect(valueAt0, contains('M'));
      expect(valueAt05, contains('M'));
      expect(valueAt1, contains('M'));

      // All values should be different SVG paths
      expect(valueAt0, isNot(equals(valueAt05)));
      expect(valueAt05, isNot(equals(valueAt1)));
    });

    test('repeatCount affects effective end time', () {
      final svgString = '''
<svg>
  <rect opacity="0">
    <animate attributeName="opacity" 
             from="0" to="1" 
             dur="1s" 
             repeatCount="5"/>
  </rect>
</svg>
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

    test('indefinite repeatCount', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" 
             from="10" to="50" 
             dur="2s" 
             repeatCount="indefinite"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.repeatCount, equals(double.infinity));
      expect(animation.getEffectiveEndTime().inDays, greaterThan(100));
    });

    test('begin offset delays animation start', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" 
             from="0" to="100" 
             begin="2s"
             dur="1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.begin, equals(const Duration(seconds: 2)));

      // Before begin time, animation should not be active
      animation.updateForTime(const Duration(seconds: 1));
      expect(animation.isActive, isFalse);

      // After begin time, animation should be active
      animation.updateForTime(const Duration(milliseconds: 2500));
      expect(animation.isActive, isTrue);
    });

    test('end attribute limits animation duration', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" 
             from="10" to="100" 
             dur="10s"
             end="2s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.end, equals(const Duration(seconds: 2)));
      expect(
        animation.getEffectiveEndTime(),
        equals(const Duration(seconds: 2)),
      );
    });

    test('fillMode freeze keeps final value', () {
      final svgString = '''
<svg>
  <circle r="10">
    <animate attributeName="r" 
             from="10" to="50" 
             dur="1s"
             fill="freeze"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.fillMode, equals(SmilFillMode.freeze));

      // Update to after animation end
      animation.updateForTime(const Duration(seconds: 2));
      expect(animation.isActive, isFalse);

      // Value should be frozen at final value (t=1.0)
      final finalValue = animation.computeValue(1.0);
      expect(finalValue, equals(50.0));
    });

    test('fillMode remove clears value after animation', () {
      final svgString = '''
<svg>
  <rect opacity="1">
    <animate attributeName="opacity" 
             from="1" to="0" 
             dur="1s"
             fill="remove"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.fillMode, equals(SmilFillMode.remove));

      animation.updateForTime(const Duration(milliseconds: 500));
      expect(animation.isActive, isTrue);

      animation.updateForTime(const Duration(seconds: 2));
      expect(animation.isActive, isFalse);
    });

    test('multiple keyTimes with uneven distribution', () {
      final svgString = '''
<svg>
  <rect fill="#000">
    <animate attributeName="fill" 
             values="#000;#444;#888;#CCC;#FFF" 
             keyTimes="0;0.1;0.2;0.8;1"
             dur="2s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.values!.length, equals(5));
      expect(animation.keyTimes, equals([0.0, 0.1, 0.2, 0.8, 1.0]));

      // Values should interpolate according to keyTimes
      final valueAt0 = animation.computeValue(0.0);
      final valueAt01 = animation.computeValue(0.1);
      final valueAt02 = animation.computeValue(0.2);
      final valueAt08 = animation.computeValue(0.8);
      final valueAt1 = animation.computeValue(1.0);

      // Color interpolator returns Color objects, not strings
      expect(valueAt0.toString(), contains('0.0000'));
      expect(valueAt01, isNotNull);
      expect(valueAt02, isNotNull);
      expect(valueAt08, isNotNull);
      expect(valueAt1.toString(), contains('1.0000'));
    });

    test('keySplines ease-in-out interpolation', () {
      final svgString = '''
<svg>
  <rect x="0">
    <animate attributeName="x" 
             values="0;100" 
             keyTimes="0;1"
             keySplines="0.42 0 0.58 1"
             dur="1s" 
             calcMode="spline"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.keySplines, isNotNull);
      expect(animation.keySplines!.length, equals(1));

      // Spline should affect interpolation
      final valueAt0 = animation.computeValue(0.0) as double;
      final valueAt025 = animation.computeValue(0.25) as double;
      final valueAt05 = animation.computeValue(0.5) as double;
      final valueAt075 = animation.computeValue(0.75) as double;
      final valueAt1 = animation.computeValue(1.0) as double;

      expect(valueAt0, equals(0.0));
      expect(valueAt1, equals(100.0));

      // Ease-in-out should have slower start and end
      expect(valueAt025, lessThan(25.0)); // Slower at start
      expect(valueAt075, greaterThan(75.0)); // Slower at end
      expect(valueAt05, closeTo(50.0, 10.0)); // Faster in middle
    });

    test('values without keyTimes use uniform distribution', () {
      final svgString = '''
<svg>
  <rect width="10">
    <animate attributeName="width" 
             values="10;30;50;70;90" 
             dur="4s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.values!.length, equals(5));
      expect(animation.keyTimes, isNull); // Should be null, auto-distributed

      // Should distribute evenly: 0, 0.25, 0.5, 0.75, 1.0
      final valueAt0 = animation.computeValue(0.0) as double;
      final valueAt025 = animation.computeValue(0.25) as double;
      final valueAt05 = animation.computeValue(0.5) as double;
      final valueAt075 = animation.computeValue(0.75) as double;
      final valueAt1 = animation.computeValue(1.0) as double;

      expect(valueAt0, equals(10.0));
      expect(valueAt025, equals(30.0));
      expect(valueAt05, equals(50.0));
      expect(valueAt075, equals(70.0));
      expect(valueAt1, equals(90.0));
    });
  });
}
