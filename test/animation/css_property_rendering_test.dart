import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/css_cascade.dart';
import 'package:flutter_svg/src/animation/css_variables_calc.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('CSS Math Functions', () {
    group('min() function', () {
      test('min() returns smallest value', () {
        final result = CssCalcEvaluator.evaluate('min(10px, 20px, 5px)');
        expect(result, equals(5.0));
      });

      test('min() with two values', () {
        final result = CssCalcEvaluator.evaluate('min(100px, 50px)');
        expect(result, equals(50.0));
      });

      test('min() with mixed units', () {
        final result = CssCalcEvaluator.evaluate(
          'min(100px, 2em)',
          fontSize: 30.0,
        );
        expect(result, equals(60.0)); // 2em * 30 = 60px < 100px
      });

      test('min() with calc inside', () {
        final result = CssCalcEvaluator.evaluate('min(calc(50 + 10), 40)');
        expect(result, equals(40.0));
      });
    });

    group('max() function', () {
      test('max() returns largest value', () {
        final result = CssCalcEvaluator.evaluate('max(10px, 20px, 5px)');
        expect(result, equals(20.0));
      });

      test('max() with two values', () {
        final result = CssCalcEvaluator.evaluate('max(30, 70)');
        expect(result, equals(70.0));
      });

      test('max() with percentages', () {
        final result = CssCalcEvaluator.evaluate(
          'max(50px, 30%)',
          containerSize: 200.0,
        );
        expect(result, equals(60.0)); // 30% of 200 = 60 > 50
      });
    });

    group('clamp() function', () {
      test('clamp() constrains value within range', () {
        // clamp(min, val, max) - value is within range
        final result = CssCalcEvaluator.evaluate('clamp(10px, 50px, 100px)');
        expect(result, equals(50.0));
      });

      test('clamp() returns min when value too small', () {
        final result = CssCalcEvaluator.evaluate('clamp(20, 10, 100)');
        expect(result, equals(20.0));
      });

      test('clamp() returns max when value too large', () {
        final result = CssCalcEvaluator.evaluate('clamp(10, 150, 100)');
        expect(result, equals(100.0));
      });

      test('clamp() with calc inside', () {
        final result = CssCalcEvaluator.evaluate(
          'clamp(10px, calc(30 + 20), 100px)',
        );
        expect(result, equals(50.0));
      });

      test('clamp() with em units', () {
        final result = CssCalcEvaluator.evaluate(
          'clamp(10px, 2em, 50px)',
          fontSize: 16.0,
        );
        expect(result, equals(32.0)); // 2em = 32px, within 10-50
      });
    });

    group('nested math functions', () {
      test('min() inside max()', () {
        final result = CssCalcEvaluator.evaluate('max(min(100, 50), 30)');
        expect(result, equals(50.0)); // min(100,50)=50, max(50,30)=50
      });

      test('clamp() with min/max inside', () {
        final result = CssCalcEvaluator.evaluate(
          'clamp(min(10, 20), 50, max(80, 100))',
        );
        expect(result, equals(50.0)); // clamp(10, 50, 100) = 50
      });
    });
  });

  group('calc() with complex unit mixing', () {
    test('calc() with percentage and pixels', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% + 10px)',
        containerSize: 200.0,
      );
      expect(result, equals(110.0)); // 100 + 10
    });

    test('calc() with em and pixels', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2em - 5px)',
        fontSize: 16.0,
      );
      expect(result, equals(27.0)); // 32 - 5
    });

    test('calc() with rem units', () {
      final result = CssCalcEvaluator.evaluate('calc(2rem + 10px)');
      expect(result, equals(42.0)); // 32 + 10 (rem uses 16px default)
    });

    test('calc() with ex units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(4ex + 10px)',
        fontSize: 16.0,
      );
      expect(result, equals(42.0)); // 4 * 8 + 10 (ex ≈ 0.5em)
    });

    test('calc() with ch units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(4ch + 10px)',
        fontSize: 16.0,
      );
      expect(result, equals(42.0)); // 4 * 8 + 10 (ch ≈ 0.5em)
    });

    test('calc() with parentFontSize for em in font-size context', () {
      // When computing font-size, em should be relative to parent's font-size
      final result = CssCalcEvaluator.evaluate(
        'calc(1.5em)',
        fontSize: 20.0,
        parentFontSize: 16.0,
      );
      expect(result, equals(24.0)); // 1.5 * 16 = 24 (uses parent font-size)
    });
  });

  group('Advanced var() scoping', () {
    test('nested var() fallback chain', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--fallback2', 'final-value');

      // var(--missing, var(--fallback1, var(--fallback2)))
      final resolved = CssVariableResolver.resolveValue(
        'var(--missing, var(--fallback1, var(--fallback2)))',
        node,
      );
      expect(resolved, equals('final-value'));
    });

    test('inner declaration overrides outer', () {
      final outer = SvgNode(tagName: 'g');
      outer.cssCustomProperties.set('--color', 'red');

      final inner = SvgNode(tagName: 'g', parent: outer);
      outer.addChild(inner);
      inner.cssCustomProperties.set('--color', 'blue');

      final rect = SvgNode(tagName: 'rect', parent: inner);
      inner.addChild(rect);

      final resolved = CssVariableResolver.resolveValue('var(--color)', rect);
      expect(resolved, equals('blue')); // inner overrides outer
    });

    test('fallback with calc expression', () {
      final node = SvgNode(tagName: 'rect');

      final resolved = CssVariableResolver.resolveValue(
        'var(--missing, calc(10 + 5))',
        node,
      );
      expect(resolved, equals('calc(10 + 5)'));

      final numeric = CssValueResolver.resolveToNumber(
        'var(--missing, calc(10 + 5))',
        node,
      );
      expect(numeric, equals(15.0));
    });

    test('variable containing var() reference', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--base', '10px');
      node.cssCustomProperties.set('--derived', 'var(--base)');

      final resolved = CssVariableResolver.resolveValue('var(--derived)', node);
      expect(resolved, equals('10px'));
    });
  });

  group('CssNthPseudoClass An+B formula', () {
    test('parse odd', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'odd');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(2));
      expect(parsed.b, equals(1));
    });

    test('parse even', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, 'even');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(2));
      expect(parsed.b, equals(0));
    });

    test('parse simple number', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '5');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(0));
      expect(parsed.b, equals(5));
      expect(parsed.matches(5), isTrue);
      expect(parsed.matches(3), isFalse);
    });

    test('parse 2n+1', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '2n+1');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(2));
      expect(parsed.b, equals(1));
      expect(parsed.matches(1), isTrue);
      expect(parsed.matches(3), isTrue);
      expect(parsed.matches(5), isTrue);
      expect(parsed.matches(2), isFalse);
      expect(parsed.matches(4), isFalse);
    });

    test('parse 3n', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '3n');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(3));
      expect(parsed.b, equals(0));
      expect(parsed.matches(3), isTrue);
      expect(parsed.matches(6), isTrue);
      expect(parsed.matches(9), isTrue);
      expect(parsed.matches(1), isFalse);
      expect(parsed.matches(2), isFalse);
    });

    test('parse -n+3', () {
      final parsed = CssNthPseudoClass.parse(CssNthType.nthChild, '-n+3');
      expect(parsed, isNotNull);
      expect(parsed!.a, equals(-1));
      expect(parsed.b, equals(3));
      // Matches 3, 2, 1 (first 3 elements)
      expect(parsed.matches(1), isTrue);
      expect(parsed.matches(2), isTrue);
      expect(parsed.matches(3), isTrue);
      expect(parsed.matches(4), isFalse);
    });
  });

  group('Structural pseudo-class matching', () {
    late SvgNode parent;
    late List<SvgNode> children;
    late CssCascadeResolver resolver;

    setUp(() {
      parent = SvgNode(tagName: 'g');
      children = [
        SvgNode(tagName: 'rect', parent: parent),
        SvgNode(tagName: 'circle', parent: parent),
        SvgNode(tagName: 'rect', parent: parent),
        SvgNode(tagName: 'circle', parent: parent),
        SvgNode(tagName: 'rect', parent: parent),
      ];
      for (final child in children) {
        parent.addChild(child);
      }
      resolver = CssCascadeResolver(cssRules: []);
    });

    test(':first-of-type matches first of each type', () {
      // First rect should match :first-of-type
      expect(resolver._isFirstOfType(children[0]), isTrue); // rect
      expect(resolver._isFirstOfType(children[1]), isTrue); // circle
      expect(resolver._isFirstOfType(children[2]), isFalse); // rect (2nd)
      expect(resolver._isFirstOfType(children[3]), isFalse); // circle (2nd)
    });

    test(':last-of-type matches last of each type', () {
      expect(resolver._isLastOfType(children[0]), isFalse); // rect (not last)
      expect(resolver._isLastOfType(children[1]), isFalse); // circle (not last)
      expect(resolver._isLastOfType(children[2]), isFalse); // rect (not last)
      expect(resolver._isLastOfType(children[3]), isTrue); // circle (last)
      expect(resolver._isLastOfType(children[4]), isTrue); // rect (last)
    });

    test(':only-of-type matches when single of type', () {
      final singleChild = SvgNode(tagName: 'rect', parent: parent);
      final singleParent = SvgNode(tagName: 'g');
      singleChild.parent = singleParent;
      singleParent.addChild(singleChild);

      expect(resolver._isOnlyOfType(singleChild), isTrue);
      expect(resolver._isOnlyOfType(children[0]), isFalse); // Multiple rects
    });
  });

  group('CSS selector parsing with nth pseudo-classes', () {
    test('parse :nth-child(2n+1) selector', () {
      final selector = _parseCssSelector('rect:nth-child(2n+1)');
      expect(selector, isNotNull);
      expect(selector!.parts.length, equals(1));
      expect(selector.subject.selector.tagName, equals('rect'));
      expect(selector.subject.selector.nthPseudoClasses.length, equals(1));
      expect(
        selector.subject.selector.nthPseudoClasses[0].type,
        equals(CssNthType.nthChild),
      );
    });

    test('parse :nth-of-type(odd) selector', () {
      final selector = _parseCssSelector('circle:nth-of-type(odd)');
      expect(selector, isNotNull);
      final nthList = selector!.subject.selector.nthPseudoClasses;
      expect(nthList.length, equals(1));
      expect(nthList[0].type, equals(CssNthType.nthOfType));
      expect(nthList[0].a, equals(2));
      expect(nthList[0].b, equals(1));
    });

    test('parse :first-of-type selector', () {
      final selector = _parseCssSelector('rect:first-of-type');
      expect(selector, isNotNull);
      expect(
        selector!.subject.selector.pseudoClasses,
        contains(CssPseudoClass.firstOfType),
      );
    });

    test('parse :last-of-type selector', () {
      final selector = _parseCssSelector('.item:last-of-type');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.classes, contains('item'));
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.lastOfType),
      );
    });
  });

  group('CssValueResolver with math functions', () {
    test('resolves var() with clamp() fallback', () {
      final node = SvgNode(tagName: 'rect');

      final result = CssValueResolver.resolveToNumber(
        'var(--missing, clamp(10, 50, 100))',
        node,
      );
      expect(result, equals(50.0));
    });

    test('resolves nested math functions', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--size', '60');

      final result = CssValueResolver.resolveToNumber(
        'clamp(10, var(--size), 100)',
        node,
      );
      expect(result, equals(60.0));
    });
  });
}

// Helper to access private parsing function
CssSelector? _parseCssSelector(String selector) {
  // Create a rule and extract the parsed selector
  final rule = CssSelectorRule(
    selector: selector,
    declarations: {},
  );
  return rule.parsedSelector;
}

// Extension to access private methods for testing
extension CssCascadeResolverTestAccess on CssCascadeResolver {
  bool _isFirstOfType(SvgNode node) {
    final parent = node.parent;
    if (parent == null) return true;
    final tagName = node.tagName.toLowerCase();
    for (final sibling in parent.children) {
      if (sibling.tagName.toLowerCase() == tagName) {
        return sibling == node;
      }
    }
    return true;
  }

  bool _isLastOfType(SvgNode node) {
    final parent = node.parent;
    if (parent == null) return true;
    final tagName = node.tagName.toLowerCase();
    for (var i = parent.children.length - 1; i >= 0; i--) {
      final sibling = parent.children[i];
      if (sibling.tagName.toLowerCase() == tagName) {
        return sibling == node;
      }
    }
    return true;
  }

  bool _isOnlyOfType(SvgNode node) {
    final parent = node.parent;
    if (parent == null) return true;
    final tagName = node.tagName.toLowerCase();
    var count = 0;
    for (final sibling in parent.children) {
      if (sibling.tagName.toLowerCase() == tagName) {
        count++;
        if (count > 1) return false;
      }
    }
    return count == 1;
  }
}
