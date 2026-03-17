import 'dart:ui' as ui;

import 'package:flutter_svg/src/animation/animated_svg_controller.dart';
import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/css_cascade.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CSS Pseudo-class Parsing', () {
    test('parses :hover pseudo-class', () {
      final selector = _parseCssSelector('#btn:hover');
      expect(selector, isNotNull);
      expect(selector!.parts.length, 1);
      expect(selector.subject.selector.id, 'btn');
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.hover),
      );
    });

    test('parses :active pseudo-class', () {
      final selector = _parseCssSelector('.button:active');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.classes, contains('button'));
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.active),
      );
    });

    test('parses :focus pseudo-class', () {
      final selector = _parseCssSelector('input:focus');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.tagName, 'input');
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.focus),
      );
    });

    test('parses multiple pseudo-classes', () {
      final selector = _parseCssSelector('#elem:hover:focus');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.id, 'elem');
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.hover),
      );
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.focus),
      );
    });

    test('parses :not() pseudo-class with class selector', () {
      final selector = _parseCssSelector('rect:not(.hidden)');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.tagName, 'rect');
      expect(selector.subject.selector.notSelectors.length, 1);
      expect(
        selector.subject.selector.notSelectors.first.classes,
        contains('hidden'),
      );
    });

    test('parses :not() pseudo-class with id selector', () {
      final selector = _parseCssSelector('circle:not(#special)');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.tagName, 'circle');
      expect(selector.subject.selector.notSelectors.length, 1);
      expect(selector.subject.selector.notSelectors.first.id, 'special');
    });

    test('parses :first-child pseudo-class', () {
      final selector = _parseCssSelector('li:first-child');
      expect(selector, isNotNull);
      expect(selector!.subject.selector.tagName, 'li');
      expect(
        selector.subject.selector.pseudoClasses,
        contains(CssPseudoClass.firstChild),
      );
    });

    test('parses :last-child pseudo-class', () {
      final selector = _parseCssSelector('li:last-child');
      expect(selector, isNotNull);
      expect(
        selector!.subject.selector.pseudoClasses,
        contains(CssPseudoClass.lastChild),
      );
    });

    test('parses :empty pseudo-class', () {
      final selector = _parseCssSelector('div:empty');
      expect(selector, isNotNull);
      expect(
        selector!.subject.selector.pseudoClasses,
        contains(CssPseudoClass.empty),
      );
    });

    test('parses :root pseudo-class', () {
      final selector = _parseCssSelector(':root');
      expect(selector, isNotNull);
      expect(
        selector!.subject.selector.pseudoClasses,
        contains(CssPseudoClass.root),
      );
    });
  });

  group('SvgPseudoClassState', () {
    late SvgPseudoClassState state;

    setUp(() {
      state = SvgPseudoClassState();
    });

    test('tracks hover state', () {
      expect(state.isHovered('elem1'), isFalse);

      state.setHovered('elem1', true);
      expect(state.isHovered('elem1'), isTrue);
      expect(state.hoveredIds, contains('elem1'));

      state.setHovered('elem1', false);
      expect(state.isHovered('elem1'), isFalse);
    });

    test('tracks active state', () {
      expect(state.isActive('btn'), isFalse);

      state.setActive('btn', true);
      expect(state.isActive('btn'), isTrue);
      expect(state.activeIds, contains('btn'));

      state.setActive('btn', false);
      expect(state.isActive('btn'), isFalse);
    });

    test('tracks focus state', () {
      expect(state.isFocused('input'), isFalse);
      expect(state.focusedId, isNull);

      state.setFocus('input');
      expect(state.isFocused('input'), isTrue);
      expect(state.focusedId, 'input');

      // Setting focus to another element clears previous focus
      state.setFocus('input2');
      expect(state.isFocused('input'), isFalse);
      expect(state.isFocused('input2'), isTrue);

      state.setFocus(null);
      expect(state.focusedId, isNull);
    });

    test('clearHover removes all hover states', () {
      state.setHovered('a', true);
      state.setHovered('b', true);

      state.clearHover();

      expect(state.isHovered('a'), isFalse);
      expect(state.isHovered('b'), isFalse);
    });

    test('clearActive removes all active states', () {
      state.setActive('a', true);
      state.setActive('b', true);

      state.clearActive();

      expect(state.isActive('a'), isFalse);
      expect(state.isActive('b'), isFalse);
    });

    test('clear removes all states', () {
      state.setHovered('a', true);
      state.setActive('b', true);
      state.setFocus('c');

      state.clear();

      expect(state.isHovered('a'), isFalse);
      expect(state.isActive('b'), isFalse);
      expect(state.focusedId, isNull);
    });
  });

  group('CSS Cascade with Pseudo-classes', () {
    test('matches :hover selector when element is hovered', () {
      final rules = [
        CssSelectorRule(selector: '#btn:hover', declarations: {'fill': 'red'}),
        CssSelectorRule(selector: '#btn', declarations: {'fill': 'blue'}),
      ];

      final resolver = CssCascadeResolver(cssRules: rules);
      resolver.pseudoClassState = SvgPseudoClassState();

      final node = SvgNode(tagName: 'rect', id: 'btn');

      // Not hovered - should get default fill
      var fill = resolver.resolveProperty(node, 'fill');
      expect(fill, 'blue');

      // Set hover state
      resolver.pseudoClassState!.setHovered('btn', true);
      resolver.clearCache();

      fill = resolver.resolveProperty(node, 'fill');
      expect(fill, 'red');
    });

    test('matches :active selector when element is active', () {
      final rules = [
        CssSelectorRule(
          selector: '#btn:active',
          declarations: {'stroke': 'green'},
        ),
        CssSelectorRule(selector: '#btn', declarations: {'stroke': 'black'}),
      ];

      final resolver = CssCascadeResolver(cssRules: rules);
      resolver.pseudoClassState = SvgPseudoClassState();

      final node = SvgNode(tagName: 'rect', id: 'btn');

      // Not active
      var stroke = resolver.resolveProperty(node, 'stroke');
      expect(stroke, 'black');

      // Set active state
      resolver.pseudoClassState!.setActive('btn', true);
      resolver.clearCache();

      stroke = resolver.resolveProperty(node, 'stroke');
      expect(stroke, 'green');
    });

    test('matches :focus selector when element is focused', () {
      final rules = [
        CssSelectorRule(
          selector: '#input:focus',
          declarations: {'stroke-width': '2'},
        ),
        CssSelectorRule(
          selector: '#input',
          declarations: {'stroke-width': '1'},
        ),
      ];

      final resolver = CssCascadeResolver(cssRules: rules);
      resolver.pseudoClassState = SvgPseudoClassState();

      final node = SvgNode(tagName: 'rect', id: 'input');

      // Not focused
      var strokeWidth = resolver.resolveProperty(node, 'stroke-width');
      expect(strokeWidth, '1');

      // Set focus state
      resolver.pseudoClassState!.setFocus('input');
      resolver.clearCache();

      strokeWidth = resolver.resolveProperty(node, 'stroke-width');
      expect(strokeWidth, '2');
    });

    test(':not() selector excludes matching elements', () {
      final rules = [
        CssSelectorRule(
          selector: 'rect:not(.hidden)',
          declarations: {'fill': 'visible'},
        ),
      ];

      final resolver = CssCascadeResolver(cssRules: rules);
      resolver.pseudoClassState = SvgPseudoClassState();

      final visibleNode = SvgNode(tagName: 'rect', id: 'vis');
      final hiddenNode = SvgNode(
        tagName: 'rect',
        id: 'hid',
        className: 'hidden',
      );

      // Visible node should match
      final visFill = resolver.resolveProperty(visibleNode, 'fill');
      expect(visFill, 'visible');

      // Hidden node should not match
      final hidFill = resolver.resolveProperty(hiddenNode, 'fill');
      expect(hidFill, isNull);
    });
  });

  group('SVG View Element Parsing', () {
    test('parses single view element', () {
      const svg = '''
        <svg viewBox="0 0 100 100">
          <view id="view1" viewBox="0 0 50 50"/>
          <rect width="100" height="100"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);

      expect(document.viewIds, contains('view1'));

      final view = document.getView('view1');
      expect(view, isNotNull);
      expect(view!.viewBox, equals(const ui.Rect.fromLTWH(0, 0, 50, 50)));
    });

    test('parses multiple view elements', () {
      const svg = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <view id="topLeft" viewBox="0 0 50 50"/>
            <view id="bottomRight" viewBox="50 50 50 50"/>
          </defs>
          <rect width="100" height="100"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);

      expect(document.viewIds, containsAll(['topLeft', 'bottomRight']));

      final topLeft = document.getView('topLeft');
      expect(topLeft?.viewBox, equals(const ui.Rect.fromLTWH(0, 0, 50, 50)));

      final bottomRight = document.getView('bottomRight');
      expect(
        bottomRight?.viewBox,
        equals(const ui.Rect.fromLTWH(50, 50, 50, 50)),
      );
    });

    test('parses view with preserveAspectRatio', () {
      const svg = '''
        <svg viewBox="0 0 100 100">
          <view id="stretch" viewBox="0 0 50 50" preserveAspectRatio="none"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);
      final view = document.getView('stretch');

      expect(view, isNotNull);
      expect(view!.preserveAspectRatio, 'none');
    });
  });

  group('SVG View Switching', () {
    test('switchToView changes active viewBox', () {
      const svg = '''
        <svg viewBox="0 0 100 100">
          <view id="zoomed" viewBox="25 25 50 50"/>
          <rect width="100" height="100"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);

      // Default viewBox
      expect(
        document.activeViewBox,
        equals(const ui.Rect.fromLTWH(0, 0, 100, 100)),
      );
      expect(document.activeViewId, isNull);

      // Switch to zoomed view
      final success = document.switchToView('zoomed');
      expect(success, isTrue);
      expect(document.activeViewId, 'zoomed');
      expect(
        document.activeViewBox,
        equals(const ui.Rect.fromLTWH(25, 25, 50, 50)),
      );

      // Switch back to default
      document.switchToView(null);
      expect(document.activeViewId, isNull);
      expect(
        document.activeViewBox,
        equals(const ui.Rect.fromLTWH(0, 0, 100, 100)),
      );
    });

    test('switchToView returns false for non-existent view', () {
      const svg = '''
        <svg viewBox="0 0 100 100">
          <view id="exists" viewBox="0 0 50 50"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);

      final success = document.switchToView('nonexistent');
      expect(success, isFalse);
      expect(document.activeViewId, isNull); // Unchanged
    });
  });

  group('AnimatedSvgController View Switching', () {
    test('controller can request view switch', () {
      final controller = AnimatedSvgController();

      expect(controller.currentViewId, isNull);
      expect(controller.pendingViewId, isNull);

      controller.switchToView('myView');

      expect(controller.currentViewId, 'myView');
      expect(controller.pendingViewId, 'myView');

      controller.clearPendingViewChange();
      expect(controller.pendingViewId, isNull);
      expect(
        controller.currentViewId,
        'myView',
      ); // Still remembers current view
    });

    test('controller can switch back to default view', () {
      final controller = AnimatedSvgController();

      controller.switchToView('view1');
      expect(controller.currentViewId, 'view1');

      controller.switchToView(null);
      expect(controller.currentViewId, isNull);
    });
  });

  group('CSS Selector toString', () {
    test('renders pseudo-classes correctly', () {
      final selector = _parseCssSelector('#btn:hover:active');
      expect(selector.toString(), contains(':hover'));
      expect(selector.toString(), contains(':active'));
    });

    test('renders :not() correctly', () {
      final selector = _parseCssSelector('rect:not(.hidden)');
      expect(selector.toString(), contains(':not('));
    });
  });
}

/// Helper to parse CSS selector using internal function
CssSelector? _parseCssSelector(String selectorStr) {
  // We need to access the internal parser through a CssSelectorRule
  final rule = CssSelectorRule(selector: selectorStr, declarations: {});
  return rule.parsedSelector;
}
