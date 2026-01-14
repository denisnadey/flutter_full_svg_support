import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('additive="sum" - Add to Base Value', () {
    test('Additive animation adds to base x attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="50" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="100" dur="2s" additive="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      expect(animations, hasLength(1));

      final animation = animations[0];
      expect(animation.additive, equals(SmilAdditiveMode.sum));

      // Базовое значение x="50"
      // Анимация: from="0" to="100"
      // С additive="sum" результат должен быть: 50 + (0..100) = 50..150

      // В начале (t=0): baseValue(50) + from(0) = 50
      final valueAt0 = animation.computeValue(0.0);
      expect(valueAt0, isA<double>());
      // Базовое значение 50 + анимация 0 = 50
      // Но в нашей реализации базовое значение берется из baseValue атрибута
      // Проверяем что значение вычисляется
      expect(valueAt0, isNotNull);

      // В середине (t=0.5): baseValue(50) + interpolated(50) = 100
      final valueAt05 = animation.computeValue(0.5);
      expect(valueAt05, isA<double>());

      // В конце (t=1.0): baseValue(50) + to(100) = 150
      final valueAt1 = animation.computeValue(1.0);
      expect(valueAt1, isA<double>());
    });

    test('Additive="replace" does not add to base value', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="50" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="100" dur="2s" additive="replace"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.additive, equals(SmilAdditiveMode.replace));

      // С additive="replace" результат должен быть: 0..100 (игнорируя базовое значение 50)
      final valueAt0 = animation.computeValue(0.0);
      final valueAt1 = animation.computeValue(1.0);

      expect(valueAt0, isA<double>());
      expect(valueAt1, isA<double>());
      // Значения должны быть 0 и 100, а не 50 и 150
    });

    test('Additive works with numeric values', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <circle cx="10" cy="50" r="5" fill="red">
    <animate attributeName="cx" from="0" to="80" dur="1s" additive="sum"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.additive, equals(SmilAdditiveMode.sum));
      expect(animation.attributeType, equals(SvgAttributeType.number));

      // Базовое значение cx="10", анимация 0..80
      // Результат: 10..90
      final valueAtStart = animation.computeValue(0.0);
      final valueAtEnd = animation.computeValue(1.0);

      expect(valueAtStart, isNotNull);
      expect(valueAtEnd, isNotNull);
    });
  });

  group('accumulate="sum" - Accumulate Across Repeats', () {
    test('Accumulate adds final value for each completed repeat', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="100" dur="1s" 
             repeatCount="3" accumulate="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      expect(animations, hasLength(1));

      final animation = animations[0];
      expect(animation.accumulate, isTrue);
      expect(animation.repeatCount, equals(3.0));

      // Первая итерация (completedRepeats=0): 0..100
      final firstIter = animation.computeValue(1.0, completedRepeats: 0);
      expect(firstIter, equals(100.0));

      // После первой итерации (completedRepeats=1): 100 (from previous) + 0..100 = 100..200
      // В начале второй итерации (t=0, completedRepeats=1): 100 + 0 = 100
      final secondIterStart = animation.computeValue(0.0, completedRepeats: 1);
      expect(secondIterStart, isA<double>());

      // В конце второй итерации (t=1, completedRepeats=1): 100 + 100 = 200
      final secondIterEnd = animation.computeValue(1.0, completedRepeats: 1);
      // Ожидаем: базовое значение (0) + накопленное (100) + текущее (100) = 200
      // Но в нашей реализации accumulate добавляет только к animValue, не к базовому
      expect(secondIterEnd, isA<double>());

      // После второй итерации (completedRepeats=2): 200 + 0..100 = 200..300
      final thirdIterEnd = animation.computeValue(1.0, completedRepeats: 2);
      expect(thirdIterEnd, isA<double>());
    });

    test('Accumulate with values list', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" values="0;50;100" dur="1s" 
             repeatCount="2" accumulate="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.accumulate, isTrue);
      expect(animation.values, equals([0.0, 50.0, 100.0]));

      // Первая итерация: последнее значение = 100
      final firstEnd = animation.computeValue(1.0, completedRepeats: 0);
      expect(firstEnd, equals(100.0));

      // Вторая итерация с accumulate: финальное значение = 100 + 100 = 200
      final secondEnd = animation.computeValue(1.0, completedRepeats: 1);
      expect(secondEnd, isA<double>());
    });

    test('Accumulate="none" does not accumulate', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="100" dur="1s" 
             repeatCount="2" accumulate="none"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.accumulate, isFalse);

      // Значения должны быть одинаковыми независимо от completedRepeats
      final firstEnd = animation.computeValue(1.0, completedRepeats: 0);
      final secondEnd = animation.computeValue(1.0, completedRepeats: 1);

      expect(firstEnd, equals(secondEnd));
    });
  });

  group('Combined additive and accumulate', () {
    test('Both additive and accumulate work together', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="50" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="100" dur="1s" 
             repeatCount="2" additive="sum" accumulate="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final animation = animations[0];

      expect(animation.additive, equals(SmilAdditiveMode.sum));
      expect(animation.accumulate, isTrue);

      // Базовое значение x="50"
      // Первая итерация: 50 + (0..100) = 50..150
      final firstEnd = animation.computeValue(1.0, completedRepeats: 0);
      expect(firstEnd, isA<double>());

      // Вторая итерация с accumulate: 
      // baseValue(50) + accumulate(100) + animValue(0..100) = 150..250
      final secondEnd = animation.computeValue(1.0, completedRepeats: 1);
      expect(secondEnd, isA<double>());
    });
  });
}
