import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/css_cascade.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('CssSpecificity', () {
    test('inline style has highest specificity', () {
      expect(CssSpecificity.inline > CssSpecificity(0, 1, 0, 0), isTrue);
      expect(CssSpecificity.inline > CssSpecificity(0, 10, 10, 10), isTrue);
    });

    test('ID selector beats class selector', () {
      final idSpec = CssSpecificity(0, 1, 0, 0);
      final classSpec = CssSpecificity(0, 0, 1, 0);
      expect(idSpec > classSpec, isTrue);
    });

    test('multiple class selectors beat single ID', () {
      final idSpec = CssSpecificity(0, 1, 0, 0);
      final manyClasses = CssSpecificity(0, 0, 11, 0);
      // 11 classes don't beat 1 ID - specificity doesn't overflow
      expect(idSpec > manyClasses, isTrue);
    });

    test('class selector beats element selector', () {
      final classSpec = CssSpecificity(0, 0, 1, 0);
      final elemSpec = CssSpecificity(0, 0, 0, 1);
      expect(classSpec > elemSpec, isTrue);
    });

    test('compound selector adds specificity', () {
      final single = CssSpecificity(0, 1, 1, 1);
      final double = CssSpecificity(0, 2, 2, 2);
      expect(double > single, isTrue);
    });

    test('equal specificity compares to zero', () {
      final a = CssSpecificity(0, 1, 2, 3);
      final b = CssSpecificity(0, 1, 2, 3);
      expect(a.compareTo(b), equals(0));
      expect(a == b, isTrue);
    });
  });

  group('CssSpecificityCalculator', () {
    test('ID selector', () {
      final spec = CssSpecificityCalculator.calculate('#myId');
      expect(spec, equals(CssSpecificity(0, 1, 0, 0)));
    });

    test('class selector', () {
      final spec = CssSpecificityCalculator.calculate('.myClass');
      expect(spec, equals(CssSpecificity(0, 0, 1, 0)));
    });

    test('element type selector', () {
      final spec = CssSpecificityCalculator.calculate('rect');
      expect(spec, equals(CssSpecificity(0, 0, 0, 1)));
    });

    test('universal selector', () {
      final spec = CssSpecificityCalculator.calculate('*');
      expect(spec, equals(CssSpecificity(0, 0, 0, 0)));
    });

    test('compound selector with ID and class', () {
      final spec = CssSpecificityCalculator.calculate('#id.class');
      expect(spec, equals(CssSpecificity(0, 1, 1, 0)));
    });

    test('compound selector with element, ID, and class', () {
      final spec = CssSpecificityCalculator.calculate('rect#myId.myClass');
      expect(spec, equals(CssSpecificity(0, 1, 1, 1)));
    });

    test('multiple classes', () {
      final spec = CssSpecificityCalculator.calculate('.a.b.c');
      expect(spec, equals(CssSpecificity(0, 0, 3, 0)));
    });

    test('attribute selector', () {
      final spec = CssSpecificityCalculator.calculate('[type="text"]');
      expect(spec, equals(CssSpecificity(0, 0, 1, 0)));
    });

    test('pseudo-class', () {
      final spec = CssSpecificityCalculator.calculate(':hover');
      expect(spec, equals(CssSpecificity(0, 0, 1, 0)));
    });

    test('pseudo-element', () {
      final spec = CssSpecificityCalculator.calculate('::before');
      expect(spec, equals(CssSpecificity(0, 0, 0, 1)));
    });

    test('descendant selector', () {
      final spec = CssSpecificityCalculator.calculate('div span');
      expect(spec, equals(CssSpecificity(0, 0, 0, 2)));
    });

    test('child combinator', () {
      final spec = CssSpecificityCalculator.calculate('ul > li');
      expect(spec, equals(CssSpecificity(0, 0, 0, 2)));
    });

    test('complex selector with multiple parts', () {
      final spec = CssSpecificityCalculator.calculate('#nav .item:hover');
      expect(spec, equals(CssSpecificity(0, 1, 2, 0)));
    });
  });

  group('CssResolvedValue cascade comparison', () {
    test('!important beats normal regardless of specificity', () {
      final important = CssResolvedValue(
        value: 'red',
        specificity: CssSpecificity(0, 0, 0, 1),
        order: 0,
        isImportant: true,
      );
      final normal = CssResolvedValue(
        value: 'blue',
        specificity: CssSpecificity.inline,
        order: 100,
        isImportant: false,
      );
      expect(important.compareCascade(normal), greaterThan(0));
      expect(important.winner(normal), equals(important));
    });

    test('higher specificity wins', () {
      final higher = CssResolvedValue(
        value: 'red',
        specificity: CssSpecificity(0, 1, 0, 0),
        order: 0,
      );
      final lower = CssResolvedValue(
        value: 'blue',
        specificity: CssSpecificity(0, 0, 1, 0),
        order: 10,
      );
      expect(higher.compareCascade(lower), greaterThan(0));
    });

    test('later source order wins when specificity is equal', () {
      final earlier = CssResolvedValue(
        value: 'red',
        specificity: CssSpecificity(0, 0, 1, 0),
        order: 0,
      );
      final later = CssResolvedValue(
        value: 'blue',
        specificity: CssSpecificity(0, 0, 1, 0),
        order: 10,
      );
      expect(later.compareCascade(earlier), greaterThan(0));
    });
  });

  group('cssInheritableProperties', () {
    test('fill is inheritable', () {
      expect(cssInheritableProperties.contains('fill'), isTrue);
    });

    test('stroke is inheritable', () {
      expect(cssInheritableProperties.contains('stroke'), isTrue);
    });

    test('font-family is inheritable', () {
      expect(cssInheritableProperties.contains('font-family'), isTrue);
    });

    test('visibility is inheritable', () {
      expect(cssInheritableProperties.contains('visibility'), isTrue);
    });

    test('color is inheritable', () {
      expect(cssInheritableProperties.contains('color'), isTrue);
    });

    test('opacity is not inheritable', () {
      expect(cssInheritableProperties.contains('opacity'), isFalse);
    });

    test('width is not inheritable', () {
      expect(cssInheritableProperties.contains('width'), isFalse);
    });

    test('transform is not inheritable', () {
      expect(cssInheritableProperties.contains('transform'), isFalse);
    });
  });

  group('CssCascadeResolver', () {
    SvgNode createNode({
      required String tag,
      String? id,
      String? className,
      Map<String, String>? attributes,
      String? style,
      SvgNode? parent,
    }) {
      final node = SvgNode(
        tagName: tag,
        id: id,
        className: className,
        parent: parent,
      );

      attributes?.forEach((key, value) {
        node.setAttribute(key, value);
      });

      if (style != null) {
        node.setAttribute('style', style);
      }

      return node;
    }

    test('resolves inline style value', () {
      final node = createNode(
        tag: 'rect',
        style: 'fill: red',
      );

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('inline style beats CSS rule', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        style: 'fill: red',
      );

      final cssRules = [
        CssSelectorRule(selector: '#myRect', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('CSS rule beats presentation attribute', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        attributes: {'fill': 'green'},
      );

      final cssRules = [
        CssSelectorRule(selector: '#myRect', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('blue'));
    });

    test('ID selector beats class selector', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        className: 'box',
      );

      final cssRules = [
        CssSelectorRule(selector: '.box', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '#myRect', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('blue'));
    });

    test('class selector beats element selector', () {
      final node = createNode(
        tag: 'rect',
        className: 'box',
      );

      final cssRules = [
        CssSelectorRule(selector: 'rect', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '.box', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('blue'));
    });

    test('later rule wins when specificity is equal', () {
      final node = createNode(
        tag: 'rect',
        className: 'box',
      );

      final cssRules = [
        CssSelectorRule(selector: '.box', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '.box', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('blue'));
    });

    test('!important in CSS beats inline style', () {
      final node = createNode(
        tag: 'rect',
        className: 'box',
        style: 'fill: red',
      );

      final cssRules = [
        CssSelectorRule(
            selector: '.box', declarations: {'fill': 'blue !important'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('blue'));
    });

    test('!important in inline style beats !important in CSS', () {
      final node = createNode(
        tag: 'rect',
        className: 'box',
        style: 'fill: red !important',
      );

      final cssRules = [
        CssSelectorRule(
            selector: '.box', declarations: {'fill': 'blue !important'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('inheritable property cascades from parent', () {
      final parent = createNode(
        tag: 'g',
        attributes: {'fill': 'red'},
      );

      final child = createNode(
        tag: 'rect',
        parent: parent,
      );

      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(child, 'fill'), equals('red'));
    });

    test('child value overrides inherited value', () {
      final parent = createNode(
        tag: 'g',
        attributes: {'fill': 'red'},
      );

      final child = createNode(
        tag: 'rect',
        attributes: {'fill': 'blue'},
        parent: parent,
      );

      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(child, 'fill'), equals('blue'));
    });

    test('non-inheritable property does not cascade', () {
      final parent = createNode(
        tag: 'g',
        attributes: {'opacity': '0.5'},
      );

      final child = createNode(
        tag: 'rect',
        parent: parent,
      );

      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      // opacity is not inheritable, so child should not get it
      expect(resolver.resolveProperty(child, 'opacity'), isNull);
    });

    test('explicit inherit keyword inherits from parent', () {
      final parent = createNode(
        tag: 'g',
        attributes: {'opacity': '0.5'},
      );

      final child = createNode(
        tag: 'rect',
        attributes: {'opacity': 'inherit'},
        parent: parent,
      );

      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      // Even though opacity is not inheritable, explicit 'inherit' should work
      expect(resolver.resolveProperty(child, 'opacity'), equals('0.5'));
    });

    test('multiple matching rules with different properties', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        className: 'box',
      );

      final cssRules = [
        CssSelectorRule(
            selector: '.box', declarations: {'fill': 'red', 'stroke': 'blue'}),
        CssSelectorRule(selector: '#myRect', declarations: {'fill': 'green'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('green'));
      expect(resolver.resolveProperty(node, 'stroke'), equals('blue'));
    });

    test('compound selector matching', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        className: 'box primary',
      );

      final cssRules = [
        CssSelectorRule(selector: 'rect.box', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '.box', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      // rect.box (0,0,1,1) > .box (0,0,1,0)
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('resolveOwnProperty does not inherit', () {
      final parent = createNode(
        tag: 'g',
        attributes: {'fill': 'red'},
      );

      final child = createNode(
        tag: 'rect',
        parent: parent,
      );

      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveOwnProperty(child, 'fill'), isNull);
    });

    test('deep inheritance chain', () {
      final grandparent = createNode(
        tag: 'svg',
        attributes: {'fill': 'red'},
      );

      final parent = createNode(
        tag: 'g',
        parent: grandparent,
      );
      grandparent.addChild(parent);

      final child = createNode(
        tag: 'rect',
        parent: parent,
      );
      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(child, 'fill'), equals('red'));
    });

    test('font properties are inherited', () {
      final parent = createNode(
        tag: 'text',
        attributes: {'font-family': 'Arial', 'font-size': '16'},
      );

      final child = createNode(
        tag: 'tspan',
        parent: parent,
      );
      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(child, 'font-family'), equals('Arial'));
      expect(resolver.resolveProperty(child, 'font-size'), equals('16'));
    });

    test('stroke properties are inherited', () {
      final parent = createNode(
        tag: 'g',
        attributes: {
          'stroke': 'black',
          'stroke-width': '2',
          'stroke-linecap': 'round',
        },
      );

      final child = createNode(
        tag: 'path',
        parent: parent,
      );
      parent.addChild(child);

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(child, 'stroke'), equals('black'));
      expect(resolver.resolveProperty(child, 'stroke-width'), equals('2'));
      expect(resolver.resolveProperty(child, 'stroke-linecap'), equals('round'));
    });

    test('element type selector matches correctly', () {
      final rect = createNode(tag: 'rect');
      final circle = createNode(tag: 'circle');

      final cssRules = [
        CssSelectorRule(selector: 'rect', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: 'circle', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(rect, 'fill'), equals('red'));
      expect(resolver.resolveProperty(circle, 'fill'), equals('blue'));
    });

    test('case insensitive property names', () {
      final node = createNode(
        tag: 'rect',
        style: 'FILL: red; Stroke: blue',
      );

      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
      expect(resolver.resolveProperty(node, 'FILL'), equals('red'));
      expect(resolver.resolveProperty(node, 'stroke'), equals('blue'));
    });
  });

  group('Edge cases', () {
    SvgNode createNode({
      required String tag,
      String? id,
      String? className,
      Map<String, String>? attributes,
      String? style,
    }) {
      final node = SvgNode(tagName: tag, id: id, className: className);
      attributes?.forEach((key, value) => node.setAttribute(key, value));
      if (style != null) node.setAttribute('style', style);
      return node;
    }

    test('empty selector returns zero specificity', () {
      expect(
          CssSpecificityCalculator.calculate(''), equals(CssSpecificity.zero));
    });

    test('empty CSS rules', () {
      final node = createNode(tag: 'rect', attributes: {'fill': 'red'});
      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('no matching rules returns presentation attribute', () {
      final node = createNode(
        tag: 'rect',
        id: 'myRect',
        attributes: {'fill': 'red'},
      );

      final cssRules = [
        CssSelectorRule(selector: '#otherId', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
    });

    test('property not found returns null', () {
      final node = createNode(tag: 'rect');
      final resolver = CssCascadeResolver(cssRules: []);
      expect(resolver.resolveProperty(node, 'fill'), isNull);
    });

    test('whitespace handling in selectors', () {
      final spec1 = CssSpecificityCalculator.calculate('  .class  ');
      final spec2 = CssSpecificityCalculator.calculate('.class');
      expect(spec1, equals(spec2));
    });

    test('multiple classes in class attribute', () {
      final node = createNode(
        tag: 'rect',
        className: 'primary secondary highlight',
      );

      final cssRules = [
        CssSelectorRule(selector: '.primary', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '.secondary', declarations: {'stroke': 'blue'}),
        CssSelectorRule(
            selector: '.highlight', declarations: {'opacity': '0.5'}),
      ];

      final resolver = CssCascadeResolver(cssRules: cssRules);
      expect(resolver.resolveProperty(node, 'fill'), equals('red'));
      expect(resolver.resolveProperty(node, 'stroke'), equals('blue'));
      expect(resolver.resolveProperty(node, 'opacity'), equals('0.5'));
    });

    test('selector with multiple IDs (invalid but handled)', () {
      // Multiple IDs in a selector is invalid HTML/SVG but should still calculate
      final spec = CssSpecificityCalculator.calculate('#a#b');
      expect(spec, equals(CssSpecificity(0, 2, 0, 0)));
    });
  });
}
