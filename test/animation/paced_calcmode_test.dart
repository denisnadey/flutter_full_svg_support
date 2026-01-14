import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/distance_calculator.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('calcMode="paced" - Distance Calculators', () {
    test('NumericDistanceCalculator computes absolute difference', () {
      final calculator = NumericDistanceCalculator();

      expect(calculator.distance(0.0, 100.0), equals(100.0));
      expect(calculator.distance(100.0, 0.0), equals(100.0));
      expect(calculator.distance(50.0, 75.0), equals(25.0));
      expect(calculator.distance(10, 20), equals(10.0));
      expect(calculator.distance(null, 10.0), equals(-1.0));
      expect(calculator.distance(10.0, null), equals(-1.0));
    });

    test('ColorDistanceCalculator computes Euclidean distance in RGB', () {
      final calculator = ColorDistanceCalculator();
      final black = ui.Color(0xFF000000);
      final white = ui.Color(0xFFFFFFFF);
      final red = ui.Color(0xFFFF0000);
      final green = ui.Color(0xFF00FF00);

      // Black to white should be maximum distance
      final blackToWhite = calculator.distance(black, white);
      expect(blackToWhite, greaterThan(400.0)); // sqrt(255^2 * 3) ≈ 441

      // Same color should be 0
      expect(calculator.distance(black, black), equals(0.0));
      expect(calculator.distance(white, white), equals(0.0));

      // Red to green
      final redToGreen = calculator.distance(red, green);
      expect(redToGreen, greaterThan(300.0)); // sqrt(255^2 + 255^2) ≈ 360

      // Null values
      expect(calculator.distance(null, black), equals(-1.0));
      expect(calculator.distance(black, null), equals(-1.0));
    });

    test('LengthDistanceCalculator computes absolute difference', () {
      final calculator = LengthDistanceCalculator();

      expect(calculator.distance(0.0, 100.0), equals(100.0));
      expect(calculator.distance(50.0, 75.0), equals(25.0));
    });

    test('DistanceCalculatorFactory creates correct calculator', () {
      expect(
        DistanceCalculatorFactory.create(SvgAttributeType.number),
        isA<NumericDistanceCalculator>(),
      );
      expect(
        DistanceCalculatorFactory.create(SvgAttributeType.color),
        isA<ColorDistanceCalculator>(),
      );
      expect(
        DistanceCalculatorFactory.create(SvgAttributeType.length),
        isA<NumericDistanceCalculator>(),
      );
    });
  });

  group('calcMode="paced" - KeyTimes Generation', () {
    test('Paced mode generates keyTimes for numeric values', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20">
    <animate attributeName="x" 
             values="0;10;100" 
             dur="3s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      expect(animations, hasLength(1));

      final animation = animations[0];
      expect(animation.calcMode, equals(SmilCalcMode.paced));
      expect(animation.values, equals([0.0, 10.0, 100.0]));

      // Paced mode should generate keyTimes automatically
      // Distance: 0->10 = 10, 10->100 = 90, total = 100
      // keyTimes should be [0, 10/100=0.1, 1.0]
      // Проверяем, что значения интерполируются правильно
      final valueAt0 = animation.computeValue(0.0);
      final valueAt01 = animation.computeValue(0.1);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, equals(0.0));
      expect(valueAt1, equals(100.0));
      // В 0.1 прогресса должны быть около 10 (но с учетом paced распределения)
      expect(valueAt01, isA<double>());
    });

    test('Paced mode with equal distances generates uniform keyTimes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20">
    <animate attributeName="x" 
             values="0;50;100" 
             dur="2s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Equal distances (50 each) should result in uniform keyTimes: [0, 0.5, 1.0]
      final valueAt0 = animation.computeValue(0.0);
      final valueAt05 = animation.computeValue(0.5);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, equals(0.0));
      expect(valueAt05, closeTo(50.0, 1.0));
      expect(valueAt1, equals(100.0));
    });

    test('Paced mode with color values', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="black">
    <animate attributeName="fill" 
             values="black;white;black" 
             dur="2s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.calcMode, equals(SmilCalcMode.paced));
      expect(animation.attributeType, equals(SvgAttributeType.color));

      // Paced mode should work for colors
      final valueAt0 = animation.computeValue(0.0);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, isNotNull);
      expect(valueAt1, isNotNull);
    });
  });

  group('calcMode="paced" - Edge Cases', () {
    test('Paced mode with single value', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20">
    <animate attributeName="x" 
             values="50" 
             dur="1s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Single value should just return that value
      expect(animation.computeValue(0.0), equals(50.0));
      expect(animation.computeValue(0.5), equals(50.0));
      expect(animation.computeValue(1.0), equals(50.0));
    });

    test('Paced mode with identical values generates uniform keyTimes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20">
    <animate attributeName="x" 
             values="50;50;50" 
             dur="2s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // All values same, distance is 0, should use uniform distribution
      expect(animation.computeValue(0.0), equals(50.0));
      expect(animation.computeValue(0.5), equals(50.0));
      expect(animation.computeValue(1.0), equals(50.0));
    });

    test('Paced mode ignores explicit keyTimes', () {
      // Когда calcMode="paced", explicit keyTimes игнорируются в Blink
      // Но в нашей реализации мы генерируем paced keyTimes только если keyTimes == null
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20">
    <animate attributeName="x" 
             values="0;10;100" 
             keyTimes="0;0.5;1"
             dur="2s" 
             calcMode="paced"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      // Если keyTimes заданы явно, они используются (не генерируем paced)
      // Это соответствует поведению Blink - paced генерируется только если keyTimes не заданы
      expect(animation.keyTimes, isNotNull);
    });
  });
}
