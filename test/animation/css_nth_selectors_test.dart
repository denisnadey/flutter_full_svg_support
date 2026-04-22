import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/css_animations.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';

void main() {
  group('CssNthPseudoClass parsing', () {
    group('keyword parsing', () {
      test('parses "odd" keyword', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'odd');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(1));
      });

      test('parses "even" keyword', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'even');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(0));
      });

      test('parses "ODD" case-insensitive', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'ODD');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(1));
      });

      test('parses "EVEN" case-insensitive', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'EVEN');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(0));
      });
    });

    group('simple number parsing', () {
      test('parses "1"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '1');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(0));
        expect(parsed.b, equals(1));
      });

      test('parses "3"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '3');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(0));
        expect(parsed.b, equals(3));
      });

      test('parses "10"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '10');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(0));
        expect(parsed.b, equals(10));
      });
    });

    group('An+B formula parsing', () {
      test('parses "n"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'n');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(1));
        expect(parsed.b, equals(0));
      });

      test('parses "2n"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '2n');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(0));
      });

      test('parses "2n+1"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '2n+1');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(1));
      });

      test('parses "3n+2"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '3n+2');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(3));
        expect(parsed.b, equals(2));
      });

      test('parses "n+3"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'n+3');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(1));
        expect(parsed.b, equals(3));
      });

      test('parses "-n+3" (first 3)', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '-n+3');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(-1));
        expect(parsed.b, equals(3));
      });

      test('parses "2n-1"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '2n-1');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(-1));
      });

      test('parses "-2n+6"', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '-2n+6');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(-2));
        expect(parsed.b, equals(6));
      });
    });

    group('whitespace handling', () {
      test('trims leading/trailing whitespace', () {
        final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '  2n+1  ');
        expect(parsed, isNotNull);
        expect(parsed!.a, equals(2));
        expect(parsed.b, equals(1));
      });
    });
  });

  group('CssNthPseudoClass.matches()', () {
    group('simple number matching', () {
      test(':nth-child(1) matches first child', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '1')!;
        expect(nth.matches(1), isTrue);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isFalse);
      });

      test(':nth-child(3) matches third child', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '3')!;
        expect(nth.matches(1), isFalse);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isTrue);
        expect(nth.matches(4), isFalse);
      });
    });

    group('odd/even matching', () {
      test(':nth-child(odd) matches 1, 3, 5, 7...', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, 'odd')!;
        expect(nth.matches(1), isTrue);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isTrue);
        expect(nth.matches(4), isFalse);
        expect(nth.matches(5), isTrue);
        expect(nth.matches(100), isFalse);
        expect(nth.matches(101), isTrue);
      });

      test(':nth-child(even) matches 2, 4, 6, 8...', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, 'even')!;
        expect(nth.matches(1), isFalse);
        expect(nth.matches(2), isTrue);
        expect(nth.matches(3), isFalse);
        expect(nth.matches(4), isTrue);
        expect(nth.matches(5), isFalse);
        expect(nth.matches(100), isTrue);
        expect(nth.matches(101), isFalse);
      });
    });

    group('An+B formula matching', () {
      test(':nth-child(n) matches all elements', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, 'n')!;
        for (var i = 1; i <= 10; i++) {
          expect(nth.matches(i), isTrue, reason: 'Should match element $i');
        }
      });

      test(':nth-child(2n) matches every even element', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '2n')!;
        expect(nth.matches(1), isFalse);
        expect(nth.matches(2), isTrue);
        expect(nth.matches(3), isFalse);
        expect(nth.matches(4), isTrue);
      });

      test(':nth-child(2n+1) matches odd elements', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '2n+1')!;
        expect(nth.matches(1), isTrue);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isTrue);
        expect(nth.matches(4), isFalse);
      });

      test(':nth-child(3n) matches 3, 6, 9, 12...', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '3n')!;
        expect(nth.matches(1), isFalse);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isTrue);
        expect(nth.matches(4), isFalse);
        expect(nth.matches(5), isFalse);
        expect(nth.matches(6), isTrue);
        expect(nth.matches(9), isTrue);
      });

      test(':nth-child(3n+1) matches 1, 4, 7, 10...', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '3n+1')!;
        expect(nth.matches(1), isTrue);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isFalse);
        expect(nth.matches(4), isTrue);
        expect(nth.matches(7), isTrue);
        expect(nth.matches(10), isTrue);
      });

      test(':nth-child(n+4) matches from 4th onward', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, 'n+4')!;
        expect(nth.matches(1), isFalse);
        expect(nth.matches(2), isFalse);
        expect(nth.matches(3), isFalse);
        expect(nth.matches(4), isTrue);
        expect(nth.matches(5), isTrue);
        expect(nth.matches(100), isTrue);
      });

      test(':nth-child(-n+3) matches first 3', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '-n+3')!;
        expect(nth.matches(1), isTrue);
        expect(nth.matches(2), isTrue);
        expect(nth.matches(3), isTrue);
        expect(nth.matches(4), isFalse);
        expect(nth.matches(5), isFalse);
      });

      test(':nth-child(-2n+6) matches 6, 4, 2', () {
        final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '-2n+6')!;
        expect(nth.matches(2), isTrue);
        expect(nth.matches(4), isTrue);
        expect(nth.matches(6), isTrue);
        expect(nth.matches(1), isFalse);
        expect(nth.matches(3), isFalse);
        expect(nth.matches(5), isFalse);
        expect(nth.matches(8), isFalse);
      });
    });
  });

  group('CSS Selector Parser - nth pseudo-classes', () {
    test('parses :nth-child(2n+1)', () {
      final rules = CssParser.parseSelectorRules(
        'rect:nth-child(2n+1) { fill: red; }',
      );
      expect(rules, hasLength(1));
      final sel = rules.first.parsedSelector!.parts.first.selector;
      expect(sel.tagName, equals('rect'));
      expect(sel.nthPseudoClasses, hasLength(1));
      expect(sel.nthPseudoClasses.first.type, equals(CssNthType.nthChild));
      expect(sel.nthPseudoClasses.first.a, equals(2));
      expect(sel.nthPseudoClasses.first.b, equals(1));
    });

    test('parses :nth-last-child(3)', () {
      final rules = CssParser.parseSelectorRules(
        ':nth-last-child(3) { fill: red; }',
      );
      expect(rules, hasLength(1));
      final sel = rules.first.parsedSelector!.parts.first.selector;
      expect(sel.nthPseudoClasses, hasLength(1));
      expect(sel.nthPseudoClasses.first.type, equals(CssNthType.nthLastChild));
      expect(sel.nthPseudoClasses.first.a, equals(0));
      expect(sel.nthPseudoClasses.first.b, equals(3));
    });

    test('parses :nth-of-type(odd)', () {
      final rules = CssParser.parseSelectorRules(
        'circle:nth-of-type(odd) { fill: red; }',
      );
      expect(rules, hasLength(1));
      final sel = rules.first.parsedSelector!.parts.first.selector;
      expect(sel.nthPseudoClasses, hasLength(1));
      expect(sel.nthPseudoClasses.first.type, equals(CssNthType.nthOfType));
      expect(sel.nthPseudoClasses.first.a, equals(2));
      expect(sel.nthPseudoClasses.first.b, equals(1));
    });

    test('parses :nth-last-of-type(even)', () {
      final rules = CssParser.parseSelectorRules(
        'rect:nth-last-of-type(even) { fill: red; }',
      );
      expect(rules, hasLength(1));
      final sel = rules.first.parsedSelector!.parts.first.selector;
      expect(sel.nthPseudoClasses, hasLength(1));
      expect(sel.nthPseudoClasses.first.type, equals(CssNthType.nthLastOfType));
      expect(sel.nthPseudoClasses.first.a, equals(2));
      expect(sel.nthPseudoClasses.first.b, equals(0));
    });

    test('parses multiple nth pseudo-classes', () {
      final rules = CssParser.parseSelectorRules(
        'rect:nth-child(n+2):nth-child(-n+5) { fill: red; }',
      );
      expect(rules, hasLength(1));
      final sel = rules.first.parsedSelector!.parts.first.selector;
      expect(sel.nthPseudoClasses, hasLength(2));
    });
  });

  group('CSS Selector Matching - :nth-child', () {
    test(':nth-child(1) matches first child', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect1'));
    });

    test(':nth-child(2) matches second child', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(2) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect2'));
    });

    test(':nth-child(odd) matches 1st, 3rd, 5th children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(3));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect1', 'rect3', 'rect5']));
      expect(animatedIds, isNot(contains('rect2')));
      expect(animatedIds, isNot(contains('rect4')));
    });

    test(':nth-child(even) matches 2nd, 4th children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(even) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect2', 'rect4']));
    });

    test(':nth-child(3n) matches 3rd, 6th children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(3n) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
    <rect id="rect6" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect3', 'rect6']));
    });

    test(':nth-child(n+3) matches from 3rd child onward', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(n+3) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(3));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect3', 'rect4', 'rect5']));
      expect(animatedIds, isNot(contains('rect1')));
      expect(animatedIds, isNot(contains('rect2')));
    });

    test(':nth-child(-n+3) matches first 3 children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(-n+3) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(3));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect1', 'rect2', 'rect3']));
      expect(animatedIds, isNot(contains('rect4')));
      expect(animatedIds, isNot(contains('rect5')));
    });
  });

  group('CSS Selector Matching - :nth-last-child', () {
    test(':nth-last-child(1) matches last child', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-child(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect3'));
    });

    test(':nth-last-child(2) matches second from last', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-child(2) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect2'));
    });

    test(':nth-last-child(odd) matches from end: 1st, 3rd, 5th', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-child(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(3));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      // Positions from end: rect5=1, rect4=2, rect3=3, rect2=4, rect1=5
      // Odd from end: 1, 3, 5 -> rect5, rect3, rect1
      expect(animatedIds, containsAll(['rect1', 'rect3', 'rect5']));
    });

    test(':nth-last-child(-n+2) matches last 2 children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-child(-n+2) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect3', 'rect4']));
    });
  });

  group('CSS Selector Matching - :nth-of-type', () {
    test(':nth-of-type(1) matches first element of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-of-type(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect1" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect2" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect1'));
    });

    test(':nth-of-type(2) matches second element of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-of-type(2) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect1" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect2'));
    });

    test(':nth-of-type(odd) matches odd elements of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-of-type(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect1" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect1', 'rect3']));
    });

    test(':nth-of-type(2n) matches even elements of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-of-type(2n) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect1" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect2', 'rect4']));
    });
  });

  group('CSS Selector Matching - :nth-last-of-type', () {
    test(':nth-last-of-type(1) matches last element of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-of-type(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect2" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect3'));
    });

    test(':nth-last-of-type(2) matches second from last of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-of-type(2) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect2" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect2'));
    });

    test(':nth-last-of-type(odd) matches odd positions from end', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-of-type(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <circle id="circle2" cx="20" cy="20" r="5" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // rect4 is 1st from end, rect3 is 2nd, rect2 is 3rd, rect1 is 4th
      // Odd positions: 1, 3 -> rect4, rect2
      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect2', 'rect4']));
    });
  });

  group('Edge Cases', () {
    test('single child matches :nth-child(1)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect1'));
    });

    test('single child matches :nth-last-child(1)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-last-child(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect1'));
    });

    test(':nth-child(100) does not match when fewer children exist', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(100) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, isEmpty);
    });

    test(':nth-of-type works with only one element of type', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-of-type(1) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle1" cx="10" cy="10" r="5" />
    <circle id="circle2" cx="20" cy="20" r="5" />
    <rect id="rect1" width="10" height="10" />
    <circle id="circle3" cx="30" cy="30" r="5" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect1'));
    });
  });

  group('Integration with other selectors', () {
    test('tag:nth-child(n).class selector', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(2).active { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" class="active" width="10" height="10" />
    <rect id="rect2" class="active" width="10" height="10" />
    <rect id="rect3" class="active" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('rect2'));
    });

    test('g > rect:nth-child(odd) with child combinator', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    g > rect:nth-child(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect1', 'rect3']));
    });

    test(':nth-child combined with attribute selector', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(n+2)[fill=red] { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" fill="red" width="10" height="10" />
    <rect id="rect2" fill="blue" width="10" height="10" />
    <rect id="rect3" fill="red" width="10" height="10" />
    <rect id="rect4" fill="red" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // rect1 is excluded by n+2, rect2 is excluded by fill!=red
      // rect3 and rect4 match both conditions
      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect3', 'rect4']));
    });

    test(':nth-child combined with :not()', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(odd):not(.excluded) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" class="excluded" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Odd: rect1, rect3, rect5
      // rect3 is excluded by :not(.excluded)
      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect1', 'rect5']));
      expect(animatedIds, isNot(contains('rect3')));
    });
  });

  group('Multiple nth-pseudo-classes', () {
    test(':nth-child(n+2):nth-child(-n+4) matches range 2-4', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(n+2):nth-child(-n+4) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(3));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect2', 'rect3', 'rect4']));
    });

    test(':nth-child(3n):nth-of-type(odd) combined matching', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect:nth-child(3n):nth-of-type(odd) { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <rect id="rect2" width="10" height="10" />
    <rect id="rect3" width="10" height="10" />
    <rect id="rect4" width="10" height="10" />
    <rect id="rect5" width="10" height="10" />
    <rect id="rect6" width="10" height="10" />
    <rect id="rect7" width="10" height="10" />
    <rect id="rect8" width="10" height="10" />
    <rect id="rect9" width="10" height="10" />
  </g>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // nth-child(3n): rect3, rect6, rect9 (positions 3, 6, 9)
      // nth-of-type(odd): rect1, rect3, rect5, rect7, rect9 (odd among rects)
      // Intersection: rect3, rect9
      expect(animations, hasLength(2));
      final animatedIds = animations.map((a) => a.targetNode.id).toSet();
      expect(animatedIds, containsAll(['rect3', 'rect9']));
    });
  });

  group('CSS nth toString representation', () {
    test(':nth-child(2n+1) toString', () {
      final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '2n+1')!;
      expect(nth.toString(), equals(':nth-child(2n+1)'));
    });

    test(':nth-child(3) toString', () {
      final nth = CssNthPseudoClass.parse(CssNthType.nthChild, '3')!;
      expect(nth.toString(), equals(':nth-child(3)'));
    });

    test(':nth-last-child(2n-1) toString', () {
      final nth = CssNthPseudoClass.parse(CssNthType.nthLastChild, '2n-1')!;
      expect(nth.toString(), equals(':nth-last-child(2n-1)'));
    });

    test(':nth-of-type(n+0) toString', () {
      final nth = CssNthPseudoClass.parse(CssNthType.nthOfType, 'n')!;
      expect(nth.toString(), equals(':nth-of-type(1n+0)'));
    });
  });
}
