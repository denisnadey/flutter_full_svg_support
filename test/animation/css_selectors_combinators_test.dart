import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

void main() {
  group('CSS Selector Parser', () {
    group('Simple selectors', () {
      test('parses tag selector', () {
        final rules = CssParser.parseSelectorRules('rect { fill: red; }');
        expect(rules, hasLength(1));
        expect(rules.first.selector, equals('rect'));
        expect(rules.first.parsedSelector, isNotNull);
        expect(rules.first.parsedSelector!.parts, hasLength(1));
        expect(
          rules.first.parsedSelector!.parts.first.selector.tagName,
          equals('rect'),
        );
      });

      test('parses id selector', () {
        final rules = CssParser.parseSelectorRules('#myId { fill: red; }');
        expect(rules, hasLength(1));
        expect(rules.first.isIdSelector, isTrue);
        expect(
          rules.first.parsedSelector!.parts.first.selector.id,
          equals('myId'),
        );
      });

      test('parses class selector', () {
        final rules = CssParser.parseSelectorRules('.myClass { fill: red; }');
        expect(rules, hasLength(1));
        expect(rules.first.isClassSelector, isTrue);
        expect(
          rules.first.parsedSelector!.parts.first.selector.classes,
          contains('myClass'),
        );
      });

      test('parses compound selector (tag.class#id)', () {
        final rules = CssParser.parseSelectorRules(
          'rect.myClass#myId { fill: red; }',
        );
        expect(rules, hasLength(1));
        final sel = rules.first.parsedSelector!.parts.first.selector;
        expect(sel.tagName, equals('rect'));
        expect(sel.id, equals('myId'));
        expect(sel.classes, contains('myClass'));
      });

      test('parses multiple classes', () {
        final rules = CssParser.parseSelectorRules(
          '.class1.class2.class3 { fill: red; }',
        );
        expect(rules, hasLength(1));
        final sel = rules.first.parsedSelector!.parts.first.selector;
        expect(sel.classes, containsAll(['class1', 'class2', 'class3']));
      });
    });

    group('Attribute selectors', () {
      test('parses [attr] existence', () {
        final rules = CssParser.parseSelectorRules(
          '[data-test] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attrs =
            rules.first.parsedSelector!.parts.first.selector.attributes;
        expect(attrs, hasLength(1));
        expect(attrs.first.attribute, equals('data-test'));
        expect(attrs.first.matchType, equals(CssAttributeMatch.exists));
      });

      test('parses [attr=value] exact match', () {
        final rules = CssParser.parseSelectorRules(
          '[fill=red] { stroke: blue; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.attribute, equals('fill'));
        expect(attr.matchType, equals(CssAttributeMatch.exact));
        expect(attr.value, equals('red'));
      });

      test('parses [attr="quoted value"]', () {
        final rules = CssParser.parseSelectorRules(
          '[title="hello world"] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.value, equals('hello world'));
      });

      test('parses [attr~=value] includes', () {
        final rules = CssParser.parseSelectorRules(
          '[class~=active] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.matchType, equals(CssAttributeMatch.includes));
      });

      test('parses [attr|=value] dash prefix', () {
        final rules = CssParser.parseSelectorRules('[lang|=en] { fill: red; }');
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.matchType, equals(CssAttributeMatch.dashPrefix));
      });

      test('parses [attr^=value] prefix', () {
        final rules = CssParser.parseSelectorRules(
          '[href^=https] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.matchType, equals(CssAttributeMatch.prefix));
      });

      test(r'parses [attr$=value] suffix', () {
        final rules = CssParser.parseSelectorRules(
          r'[href$=".pdf"] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.matchType, equals(CssAttributeMatch.suffix));
        expect(attr.value, equals('.pdf'));
      });

      test('parses [attr*=value] substring', () {
        final rules = CssParser.parseSelectorRules(
          '[title*=example] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.matchType, equals(CssAttributeMatch.substring));
      });

      test('parses case-insensitive [attr=value i]', () {
        final rules = CssParser.parseSelectorRules(
          '[type=TEXT i] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attr =
            rules.first.parsedSelector!.parts.first.selector.attributes.first;
        expect(attr.caseInsensitive, isTrue);
      });

      test('parses multiple attributes', () {
        final rules = CssParser.parseSelectorRules(
          '[data-x][data-y=5] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final attrs =
            rules.first.parsedSelector!.parts.first.selector.attributes;
        expect(attrs, hasLength(2));
        expect(attrs[0].attribute, equals('data-x'));
        expect(attrs[1].attribute, equals('data-y'));
      });
    });

    group('Combinator selectors', () {
      test('parses descendant combinator (space)', () {
        final rules = CssParser.parseSelectorRules('g rect { fill: red; }');
        expect(rules, hasLength(1));
        expect(rules.first.hasCombinators, isTrue);
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[0].selector.tagName, equals('g'));
        expect(parts[0].combinator, equals(CssCombinator.none));
        expect(parts[1].selector.tagName, equals('rect'));
        expect(parts[1].combinator, equals(CssCombinator.descendant));
      });

      test('parses child combinator (>)', () {
        final rules = CssParser.parseSelectorRules('g > rect { fill: red; }');
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[1].combinator, equals(CssCombinator.child));
      });

      test('parses adjacent sibling combinator (+)', () {
        final rules = CssParser.parseSelectorRules(
          'rect + circle { fill: red; }',
        );
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[0].selector.tagName, equals('rect'));
        expect(parts[1].selector.tagName, equals('circle'));
        expect(parts[1].combinator, equals(CssCombinator.adjacentSibling));
      });

      test('parses general sibling combinator (~)', () {
        final rules = CssParser.parseSelectorRules(
          'rect ~ circle { fill: red; }',
        );
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[1].combinator, equals(CssCombinator.generalSibling));
      });

      test('parses chained combinators', () {
        final rules = CssParser.parseSelectorRules(
          'svg > g rect { fill: red; }',
        );
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(3));
        expect(parts[0].selector.tagName, equals('svg'));
        expect(parts[1].selector.tagName, equals('g'));
        expect(parts[1].combinator, equals(CssCombinator.child));
        expect(parts[2].selector.tagName, equals('rect'));
        expect(parts[2].combinator, equals(CssCombinator.descendant));
      });
    });

    group('Compound selectors with combinators', () {
      test('parses g.container > rect.item', () {
        final rules = CssParser.parseSelectorRules(
          'g.container > rect.item { fill: red; }',
        );
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[0].selector.tagName, equals('g'));
        expect(parts[0].selector.classes, contains('container'));
        expect(parts[1].selector.tagName, equals('rect'));
        expect(parts[1].selector.classes, contains('item'));
        expect(parts[1].combinator, equals(CssCombinator.child));
      });

      test('parses #parent .child[data-x]', () {
        final rules = CssParser.parseSelectorRules(
          '#parent .child[data-x] { fill: red; }',
        );
        expect(rules, hasLength(1));
        final parts = rules.first.parsedSelector!.parts;
        expect(parts, hasLength(2));
        expect(parts[0].selector.id, equals('parent'));
        expect(parts[1].selector.classes, contains('child'));
        expect(parts[1].selector.attributes, hasLength(1));
      });
    });
  });

  group('Attribute Selector Matching', () {
    test('[attr] matches when attribute exists', () {
      final sel = CssAttributeSelector(
        attribute: 'data-test',
        matchType: CssAttributeMatch.exists,
      );
      expect(sel.matches('any-value'), isTrue);
      expect(sel.matches(''), isTrue);
      expect(sel.matches(null), isFalse);
    });

    test('[attr=value] exact match', () {
      final sel = CssAttributeSelector(
        attribute: 'fill',
        matchType: CssAttributeMatch.exact,
        value: 'red',
      );
      expect(sel.matches('red'), isTrue);
      expect(sel.matches('RED'), isFalse);
      expect(sel.matches('red '), isFalse);
      expect(sel.matches('blue'), isFalse);
    });

    test('[attr~=value] includes in space-separated list', () {
      final sel = CssAttributeSelector(
        attribute: 'class',
        matchType: CssAttributeMatch.includes,
        value: 'active',
      );
      expect(sel.matches('active'), isTrue);
      expect(sel.matches('foo active bar'), isTrue);
      expect(sel.matches('inactive'), isFalse);
    });

    test('[attr|=value] dash prefix', () {
      final sel = CssAttributeSelector(
        attribute: 'lang',
        matchType: CssAttributeMatch.dashPrefix,
        value: 'en',
      );
      expect(sel.matches('en'), isTrue);
      expect(sel.matches('en-US'), isTrue);
      expect(sel.matches('en-GB'), isTrue);
      expect(sel.matches('english'), isFalse);
      expect(sel.matches('fr'), isFalse);
    });

    test('[attr^=value] prefix', () {
      final sel = CssAttributeSelector(
        attribute: 'href',
        matchType: CssAttributeMatch.prefix,
        value: 'https',
      );
      expect(sel.matches('https://example.com'), isTrue);
      expect(sel.matches('http://example.com'), isFalse);
    });

    test(r'[attr$=value] suffix', () {
      final sel = CssAttributeSelector(
        attribute: 'href',
        matchType: CssAttributeMatch.suffix,
        value: '.pdf',
      );
      expect(sel.matches('document.pdf'), isTrue);
      expect(sel.matches('document.doc'), isFalse);
    });

    test('[attr*=value] substring', () {
      final sel = CssAttributeSelector(
        attribute: 'title',
        matchType: CssAttributeMatch.substring,
        value: 'example',
      );
      expect(sel.matches('This is an example text'), isTrue);
      expect(sel.matches('example'), isTrue);
      expect(sel.matches('no match here'), isFalse);
    });

    test('case-insensitive matching', () {
      final sel = CssAttributeSelector(
        attribute: 'type',
        matchType: CssAttributeMatch.exact,
        value: 'text',
        caseInsensitive: true,
      );
      expect(sel.matches('text'), isTrue);
      expect(sel.matches('TEXT'), isTrue);
      expect(sel.matches('Text'), isTrue);
    });
  });

  group('CSS Selector Matching in SVG', () {
    group('Descendant combinator (space)', () {
      test('g rect matches rect inside g at any depth', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    g rect { animation: fadeIn 1s linear; }
  </style>
  <g id="group1">
    <rect id="rect1" width="10" height="10" />
    <g id="group2">
      <rect id="rect2" width="10" height="10" />
    </g>
  </g>
  <rect id="rect3" width="10" height="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // rect1 and rect2 should match (inside g)
        // rect3 should NOT match (not inside g)
        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('rect1'));
        expect(animatedIds, contains('rect2'));
        expect(animatedIds, isNot(contains('rect3')));
      });
    });

    group('Child combinator (>)', () {
      test('g > rect matches only direct children', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    g > rect { animation: fadeIn 1s linear; }
  </style>
  <g id="group1">
    <rect id="rect1" width="10" height="10" />
    <g id="group2">
      <rect id="rect2" width="10" height="10" />
    </g>
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // rect1 should match (direct child of g)
        // rect2 should also match (direct child of group2 which is g)
        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('rect1'));
        expect(animatedIds, contains('rect2'));
      });

      test('svg > rect matches only direct children of svg', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    svg > rect { animation: fadeIn 1s linear; }
  </style>
  <rect id="rect1" width="10" height="10" />
  <g>
    <rect id="rect2" width="10" height="10" />
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations, hasLength(1));
        expect(animations.first.targetNode.id, equals('rect1'));
      });
    });

    group('Adjacent sibling combinator (+)', () {
      test('rect + circle matches circle immediately after rect', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect + circle { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <circle id="circle1" cx="50" cy="50" r="10" />
    <circle id="circle2" cx="60" cy="60" r="10" />
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // Only circle1 should match (immediately after rect)
        expect(animations, hasLength(1));
        expect(animations.first.targetNode.id, equals('circle1'));
      });

      test('adjacent sibling does not match with element in between', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect + circle { animation: fadeIn 1s linear; }
  </style>
  <g>
    <rect id="rect1" width="10" height="10" />
    <ellipse cx="30" cy="30" rx="5" ry="5" />
    <circle id="circle1" cx="50" cy="50" r="10" />
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // circle1 should NOT match (ellipse is between)
        expect(animations, isEmpty);
      });
    });

    group('General sibling combinator (~)', () {
      test('rect ~ circle matches any circle after rect', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect ~ circle { animation: fadeIn 1s linear; }
  </style>
  <g>
    <circle id="circle0" cx="20" cy="20" r="10" />
    <rect id="rect1" width="10" height="10" />
    <ellipse cx="30" cy="30" rx="5" ry="5" />
    <circle id="circle1" cx="50" cy="50" r="10" />
    <circle id="circle2" cx="60" cy="60" r="10" />
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // circle1 and circle2 should match (after rect)
        // circle0 should NOT match (before rect)
        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('circle1'));
        expect(animatedIds, contains('circle2'));
        expect(animatedIds, isNot(contains('circle0')));
      });
    });

    group('Attribute selectors', () {
      test('[fill=red] matches elements with fill=red', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    [fill=red] { animation: fadeIn 1s linear; }
  </style>
  <rect id="rect1" fill="red" width="10" height="10" />
  <rect id="rect2" fill="blue" width="10" height="10" />
  <circle id="circle1" fill="red" cx="50" cy="50" r="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('rect1'));
        expect(animatedIds, contains('circle1'));
        expect(animatedIds, isNot(contains('rect2')));
      });

      test('[data-animate] matches elements with attribute', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    [data-animate] { animation: fadeIn 1s linear; }
  </style>
  <rect id="rect1" data-animate="true" width="10" height="10" />
  <rect id="rect2" width="10" height="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations, hasLength(1));
        expect(animations.first.targetNode.id, equals('rect1'));
      });

      test('[id^=item] matches elements with id starting with "item"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    [id^=item] { animation: fadeIn 1s linear; }
  </style>
  <rect id="item1" width="10" height="10" />
  <rect id="item2" width="10" height="10" />
  <rect id="other" width="10" height="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('item1'));
        expect(animatedIds, contains('item2'));
      });
    });

    group('Compound selectors', () {
      test('g.container > rect.item matches compound selector', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    g.container > rect.item { animation: fadeIn 1s linear; }
  </style>
  <g class="container">
    <rect id="rect1" class="item" width="10" height="10" />
    <rect id="rect2" class="other" width="10" height="10" />
  </g>
  <g class="other">
    <rect id="rect3" class="item" width="10" height="10" />
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // Only rect1 matches (inside g.container with class item)
        expect(animations, hasLength(1));
        expect(animations.first.targetNode.id, equals('rect1'));
      });

      test('rect[fill=red].highlighted matches compound with attribute', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    rect[fill=red].highlighted { animation: fadeIn 1s linear; }
  </style>
  <rect id="rect1" class="highlighted" fill="red" width="10" height="10" />
  <rect id="rect2" class="highlighted" fill="blue" width="10" height="10" />
  <rect id="rect3" fill="red" width="10" height="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // Only rect1 matches (fill=red AND class highlighted)
        expect(animations, hasLength(1));
        expect(animations.first.targetNode.id, equals('rect1'));
      });
    });

    group('Complex selector chains', () {
      test('svg > g.container rect.item matches chain', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    svg > g.container rect.item { animation: fadeIn 1s linear; }
  </style>
  <g class="container">
    <rect id="rect1" class="item" width="10" height="10" />
    <g>
      <rect id="rect2" class="item" width="10" height="10" />
    </g>
  </g>
  <g>
    <g class="container">
      <rect id="rect3" class="item" width="10" height="10" />
    </g>
  </g>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // rect1 and rect2 match (inside g.container which is direct child of svg)
        // rect3 does NOT match (g.container is not direct child of svg)
        expect(animations, hasLength(2));

        final animatedIds = animations.map((a) => a.targetNode.id).toSet();
        expect(animatedIds, contains('rect1'));
        expect(animatedIds, contains('rect2'));
        expect(animatedIds, isNot(contains('rect3')));
      });
    });
  });

  group('Backward compatibility', () {
    test('existing id selectors still work', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0); }
      to { transform: rotate(360); }
    }
    #myRect {
      animation: spin 2s linear infinite;
    }
  </style>
  <rect id="myRect" width="10" height="10" />
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.targetNode.id, equals('myRect'));
    });

    test('existing class selectors still work', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .fadeMe {
      animation: fade 1s ease both;
    }
  </style>
  <circle class="fadeMe" cx="50" cy="50" r="10" />
  <ellipse class="fadeMe otherClass" cx="20" cy="20" rx="5" ry="5" />
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
    });

    test('existing element selectors still work', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    circle {
      animation: fadeIn 1s linear;
    }
  </style>
  <circle id="circle1" cx="50" cy="50" r="10" />
  <circle id="circle2" cx="60" cy="60" r="10" />
  <rect id="rect1" width="10" height="10" />
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
      expect(animations.every((a) => a.targetNode.tagName == 'circle'), isTrue);
    });
  });
}
