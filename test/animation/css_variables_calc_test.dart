import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/css_variables_calc.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('CSS Custom Properties', () {
    test('Parse custom property declarations from style string', () {
      const style = '--primary-color: #ff0000; --spacing: 10px; fill: blue;';
      final props = parseCustomProperties(style);

      expect(props, hasLength(2));
      expect(props['--primary-color'], equals('#ff0000'));
      expect(props['--spacing'], equals('10px'));
    });

    test('CssCustomProperties store and retrieve values', () {
      final store = CssCustomProperties();
      store.set('--color', 'red');
      store.set('--size', '20px');

      expect(store.get('--color'), equals('red'));
      expect(store.get('--size'), equals('20px'));
      expect(store.get('--undefined'), isNull);
      expect(store.has('--color'), isTrue);
      expect(store.has('--undefined'), isFalse);
    });

    test('SvgNode can store and retrieve custom properties', () {
      final node = SvgNode(tagName: 'rect');
      node.parseAndSetCustomProperties('--my-fill: green; --my-width: 100');

      expect(node.cssCustomProperties.get('--my-fill'), equals('green'));
      expect(node.cssCustomProperties.get('--my-width'), equals('100'));
    });
  });

  group('CSS var() Resolution', () {
    test('Resolve simple var() reference', () {
      final parent = SvgNode(tagName: 'svg');
      parent.cssCustomProperties.set('--color', 'blue');

      final child = SvgNode(tagName: 'rect', parent: parent);
      parent.addChild(child);

      final resolved = CssVariableResolver.resolveValue('var(--color)', child);
      expect(resolved, equals('blue'));
    });

    test('Resolve var() with fallback when variable is missing', () {
      final node = SvgNode(tagName: 'rect');

      final resolved = CssVariableResolver.resolveValue(
        'var(--undefined, red)',
        node,
      );
      expect(resolved, equals('red'));
    });

    test('Resolve var() without fallback returns empty when missing', () {
      final node = SvgNode(tagName: 'rect');

      final resolved = CssVariableResolver.resolveValue(
        'var(--undefined)',
        node,
      );
      expect(resolved, equals(''));
    });

    test('Resolve nested var() references', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--inner', 'green');
      node.cssCustomProperties.set('--outer', 'var(--inner)');

      final resolved = CssVariableResolver.resolveValue('var(--outer)', node);
      expect(resolved, equals('green'));
    });

    test('Variable inheritance through element tree', () {
      final root = SvgNode(tagName: 'svg');
      root.cssCustomProperties.set('--root-var', 'root-value');

      final group = SvgNode(tagName: 'g', parent: root);
      root.addChild(group);
      group.cssCustomProperties.set('--group-var', 'group-value');

      final rect = SvgNode(tagName: 'rect', parent: group);
      group.addChild(rect);

      // rect should inherit from parent nodes
      expect(
        CssVariableResolver.resolveValue('var(--root-var)', rect),
        equals('root-value'),
      );
      expect(
        CssVariableResolver.resolveValue('var(--group-var)', rect),
        equals('group-value'),
      );
    });

    test('Child variable overrides parent variable', () {
      final parent = SvgNode(tagName: 'g');
      parent.cssCustomProperties.set('--color', 'red');

      final child = SvgNode(tagName: 'rect', parent: parent);
      parent.addChild(child);
      child.cssCustomProperties.set('--color', 'blue');

      final resolved = CssVariableResolver.resolveValue('var(--color)', child);
      expect(resolved, equals('blue'));
    });

    test('Resolve var() in complex value', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--offset', '10');

      final resolved = CssVariableResolver.resolveValue(
        'translate(var(--offset)px, var(--offset)px)',
        node,
      );
      expect(resolved, equals('translate(10px, 10px)'));
    });
  });

  group('CSS calc() Evaluation', () {
    test('Simple addition', () {
      final result = CssCalcEvaluator.evaluate('calc(10 + 5)');
      expect(result, equals(15.0));
    });

    test('Simple subtraction', () {
      final result = CssCalcEvaluator.evaluate('calc(20 - 8)');
      expect(result, equals(12.0));
    });

    test('Simple multiplication', () {
      final result = CssCalcEvaluator.evaluate('calc(6 * 7)');
      expect(result, equals(42.0));
    });

    test('Simple division', () {
      final result = CssCalcEvaluator.evaluate('calc(100 / 4)');
      expect(result, equals(25.0));
    });

    test('Division by zero returns zero', () {
      final result = CssCalcEvaluator.evaluate('calc(10 / 0)');
      expect(result, equals(0.0));
    });

    test('Mixed operations with correct precedence', () {
      // 10 + 5 * 2 = 10 + 10 = 20 (multiplication first)
      final result = CssCalcEvaluator.evaluate('calc(10 + 5 * 2)');
      expect(result, equals(20.0));
    });

    test('calc() with px units', () {
      final result = CssCalcEvaluator.evaluate('calc(100px - 20px)');
      expect(result, equals(80.0));
    });

    test('calc() with em units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2em + 1em)',
        fontSize: 16.0,
      );
      expect(result, equals(48.0)); // 3em * 16px = 48px
    });

    test('calc() with rem units', () {
      final result = CssCalcEvaluator.evaluate('calc(2rem)');
      expect(result, equals(32.0)); // 2 * 16px (default font size) = 32px
    });

    test('calc() with percentage', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50%)',
        containerSize: 200.0,
      );
      expect(result, equals(100.0));
    });

    test('calc() with mixed units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(100px + 2em)',
        fontSize: 16.0,
      );
      expect(result, equals(132.0)); // 100 + 32 = 132
    });

    test('Nested calc()', () {
      final result = CssCalcEvaluator.evaluate('calc(100 - calc(20 + 30))');
      expect(result, equals(50.0));
    });

    test('Complex nested calc()', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(200 - calc(50 + calc(10 * 2)))',
      );
      expect(result, equals(130.0)); // 200 - (50 + 20) = 130
    });

    test('calc() with pt units', () {
      final result = CssCalcEvaluator.evaluate('calc(12pt)');
      expect(result, closeTo(16.0, 0.01)); // 12pt * 1.333 ≈ 16px
    });

    test('Plain numeric value without calc()', () {
      final result = CssCalcEvaluator.evaluate('42');
      expect(result, equals(42.0));
    });

    test('Plain numeric value with units', () {
      final result = CssCalcEvaluator.evaluate('2em', fontSize: 16.0);
      expect(result, equals(32.0));
    });
  });

  group('Combined var() and calc()', () {
    test('var() inside calc()', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--size', '50');

      final resolved = CssValueResolver.resolve('calc(var(--size) * 2)', node);
      expect(resolved, equals('calc(50 * 2)'));

      final numeric = CssValueResolver.resolveToNumber(
        'calc(var(--size) * 2)',
        node,
      );
      expect(numeric, equals(100.0));
    });

    test('Multiple var() in calc()', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--width', '100');
      node.cssCustomProperties.set('--padding', '20');

      final numeric = CssValueResolver.resolveToNumber(
        'calc(var(--width) - var(--padding) * 2)',
        node,
      );
      expect(numeric, equals(60.0)); // 100 - 40 = 60
    });

    test('var() with unit inside calc()', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--base-size', '16px');

      final numeric = CssValueResolver.resolveToNumber(
        'calc(var(--base-size) * 2)',
        node,
      );
      expect(numeric, equals(32.0));
    });
  });

  group('Utility Functions', () {
    test('containsVarReference detects var()', () {
      expect(containsVarReference('var(--color)'), isTrue);
      expect(containsVarReference('red'), isFalse);
      expect(containsVarReference('calc(10 + 5)'), isFalse);
    });

    test('containsCalcExpression detects calc()', () {
      expect(containsCalcExpression('calc(10 + 5)'), isTrue);
      expect(containsCalcExpression('CALC(10 + 5)'), isTrue);
      expect(containsCalcExpression('10px'), isFalse);
    });

    test('isCustomProperty detects -- prefix', () {
      expect(isCustomProperty('--color'), isTrue);
      expect(isCustomProperty('color'), isFalse);
      expect(isCustomProperty('-color'), isFalse);
    });
  });

  group('SVG Integration', () {
    test('Parse SVG with CSS variables in style block', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    :root {
      --main-color: red;
    }
    #myRect {
      --rect-width: 50;
    }
  </style>
  <rect id="myRect" width="var(--rect-width)" style="fill: var(--main-color)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.root, isNotNull);

      // The CSS rules should be parsed
      expect(document.cssSelectorRules, isNotNull);
    });

    test('Parse SVG with inline CSS variables', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <g style="--group-color: blue">
    <rect style="fill: var(--group-color)"/>
  </g>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.root, isNotNull);

      // Find the group element
      final groups = document.getElementsByTag('g');
      expect(groups, hasLength(1));
    });

    test('Parse SVG with calc() in style', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect style="width: calc(100px - 20px)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.root, isNotNull);
    });

    test('CSS variables with calc() combined', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <g style="--base-size: 20">
    <rect style="width: calc(var(--base-size) * 3)"/>
  </g>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.root, isNotNull);
    });
  });

  group('Edge Cases', () {
    test('Empty var() fallback', () {
      final node = SvgNode(tagName: 'rect');
      final resolved = CssVariableResolver.resolveValue(
        'var(--missing, )',
        node,
      );
      expect(resolved, equals(''));
    });

    test('Deeply nested fallback with var()', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--fallback', 'green');

      final resolved = CssVariableResolver.resolveValue(
        'var(--undefined, var(--fallback))',
        node,
      );
      expect(resolved, equals('green'));
    });

    test('calc() with negative numbers', () {
      final result = CssCalcEvaluator.evaluate('calc(-10 + 30)');
      expect(result, equals(20.0));
    });

    test('calc() with decimal numbers', () {
      final result = CssCalcEvaluator.evaluate('calc(10.5 + 4.5)');
      expect(result, equals(15.0));
    });

    test('calc() with whitespace variations', () {
      final result = CssCalcEvaluator.evaluate('calc(  10   +   5  )');
      expect(result, equals(15.0));
    });

    test('Invalid calc() returns null', () {
      final result = CssCalcEvaluator.evaluate('calc(abc)');
      expect(result, isNull);
    });

    test('Unmatched parentheses in calc() returns null', () {
      final result = CssCalcEvaluator.evaluate('calc((10 + 5)');
      expect(result, isNull);
    });

    test('Max iterations prevents infinite loop in var() resolution', () {
      final node = SvgNode(tagName: 'rect');
      // Create a circular reference (shouldn't happen in practice)
      node.cssCustomProperties.set('--a', 'var(--b)');
      node.cssCustomProperties.set('--b', 'var(--a)');

      // Should not hang, will just keep resolving until max iterations
      final resolved = CssVariableResolver.resolveValue('var(--a)', node);
      expect(resolved, isNotEmpty);
    });
  });
}
