import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Visibility Animation', () {
    test('set element changes visibility attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="blue" visibility="hidden">
            <set attributeName="visibility" to="visible" begin="1s" dur="10s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations.length, equals(1), reason: 'Should parse 1 animation');

      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // Initially visibility is hidden (base value)
      expect(rect.getAttributeValue('visibility'), equals('hidden'));

      // Before animation starts (t=0.5s)
      timeline.tick(const Duration(milliseconds: 500));
      expect(rect.getAttributeValue('visibility'), equals('hidden'));

      // After animation starts (t=1.5s)
      timeline.tick(const Duration(milliseconds: 1000));
      expect(rect.getAttributeValue('visibility'), equals('visible'));
    });

    test('animate element changes visibility with discrete calcMode', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="red" visibility="visible">
            <animate attributeName="visibility" 
                     values="visible;hidden;visible" 
                     dur="3s" 
                     calcMode="discrete" 
                     fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // At t=0, visibility should be 'visible' (first value)
      timeline.seek(Duration.zero);
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('visible'),
      );

      // At t=1.2s, visibility should be 'hidden' (second value)
      timeline.seek(const Duration(milliseconds: 1200));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('hidden'),
      );

      // At t=2.5s, visibility should be 'visible' (third value)
      timeline.seek(const Duration(milliseconds: 2500));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('visible'),
      );
    });

    test('visibility animation with freeze preserves final value', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="green" visibility="visible">
            <set attributeName="visibility" to="hidden" begin="0s" dur="1s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations.length, equals(1), reason: 'Should parse 1 animation');

      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // During animation (t=0.5s)
      timeline.seek(const Duration(milliseconds: 500));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('hidden'),
      );

      // After animation ends (t=2s), freeze keeps the value
      timeline.seek(const Duration(seconds: 2));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('hidden'),
      );
    });

    test('visibility animation resets after remove fill mode', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="green" visibility="visible">
            <set attributeName="visibility" to="hidden" begin="0s" dur="1s" fill="remove"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations.length, equals(1), reason: 'Should parse 1 animation');

      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // During animation (t=0.5s)
      timeline.seek(const Duration(milliseconds: 500));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('hidden'),
      );

      // After animation ends (t=2s), remove restores base value
      timeline.seek(const Duration(seconds: 2));
      expect(
        rect.getAttributeValue('visibility')?.toString(),
        equals('visible'),
      );
    });
  });

  group('Display Animation', () {
    test('set element changes display attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="blue" display="none">
            <set attributeName="display" to="inline" begin="1s" dur="10s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations.length, equals(1), reason: 'Should parse 1 animation');

      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // Initially display is none
      expect(rect.getAttributeValue('display'), equals('none'));

      // Before animation starts
      timeline.tick(const Duration(milliseconds: 500));
      expect(rect.getAttributeValue('display'), equals('none'));

      // After animation starts
      timeline.tick(const Duration(milliseconds: 1000));
      expect(rect.getAttributeValue('display'), equals('inline'));
    });

    test('animate element changes display with discrete calcMode', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" 
                fill="red" display="inline">
            <animate attributeName="display" 
                     values="inline;none;inline" 
                     dur="3s" 
                     calcMode="discrete" 
                     fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      final timeline = SvgTimeline(animations: animations, rootNode: doc.root);

      final rect = doc.getElementById('target')!;

      // At t=0, display should be 'inline' (first value)
      timeline.seek(Duration.zero);
      expect(rect.getAttributeValue('display')?.toString(), equals('inline'));

      // At t=1.2s, display should be 'none' (second value)
      timeline.seek(const Duration(milliseconds: 1200));
      expect(rect.getAttributeValue('display')?.toString(), equals('none'));

      // At t=2.5s, display should be 'inline' (third value)
      timeline.seek(const Duration(milliseconds: 2500));
      expect(rect.getAttributeValue('display')?.toString(), equals('inline'));
    });
  });

  group('Animated attribute effectiveValue', () {
    test('effectiveValue returns animated value when animation is active', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute('visibility', 'hidden', type: SvgAttributeType.string);

      final attr = node.getAttribute('visibility')!;

      // Base value
      expect(attr.effectiveValue, equals('hidden'));
      expect(attr.isAnimated, isFalse);

      // Set animated value
      attr.setAnimatedValue('visible');
      expect(attr.effectiveValue, equals('visible'));
      expect(attr.isAnimated, isTrue);

      // Clear animation
      attr.clearAnimation();
      expect(attr.effectiveValue, equals('hidden'));
      expect(attr.isAnimated, isFalse);
    });

    test('getAttributeValue returns effectiveValue', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute('visibility', 'hidden', type: SvgAttributeType.string);

      // Base value through getAttributeValue
      expect(node.getAttributeValue('visibility'), equals('hidden'));

      // Animate the attribute
      node.getAttribute('visibility')!.setAnimatedValue('visible');
      expect(node.getAttributeValue('visibility'), equals('visible'));
    });
  });

  group('SmilAnimation visibility/display integration', () {
    test('SmilAnimation applies visibility value to target node', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute('visibility', 'hidden', type: SvgAttributeType.string);

      final animation = SmilAnimation(
        type: SmilAnimationType.set,
        targetNode: node,
        attributeName: 'visibility',
        attributeType: SvgAttributeType.string,
        to: 'visible',
        dur: const Duration(seconds: 1),
        fillMode: SmilFillMode.freeze,
      );

      // Before animation
      expect(node.getAttributeValue('visibility'), equals('hidden'));

      // During animation
      animation.updateForTime(const Duration(milliseconds: 500));
      expect(animation.isActive, isTrue);
      expect(node.getAttributeValue('visibility'), equals('visible'));

      // After animation (freeze mode)
      animation.updateForTime(const Duration(seconds: 2));
      expect(animation.isActive, isFalse);
      expect(node.getAttributeValue('visibility'), equals('visible'));
    });

    test('SmilAnimation applies display value to target node', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute('display', 'none', type: SvgAttributeType.string);

      final animation = SmilAnimation(
        type: SmilAnimationType.set,
        targetNode: node,
        attributeName: 'display',
        attributeType: SvgAttributeType.string,
        to: 'inline',
        dur: const Duration(seconds: 1),
        fillMode: SmilFillMode.freeze,
      );

      // Before animation
      expect(node.getAttributeValue('display'), equals('none'));

      // During animation
      animation.updateForTime(const Duration(milliseconds: 500));
      expect(node.getAttributeValue('display'), equals('inline'));
    });
  });
}
