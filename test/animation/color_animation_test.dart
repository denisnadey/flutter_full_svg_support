import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart' as painting;

void main() {
  group('Color Animations', () {
    test('parses fill color animation', () {
      const svgXml = '''
        <svg>
          <rect x="10" y="10" width="50" height="50" fill="red">
            <animate attributeName="fill" from="red" to="blue" dur="1s"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('fill'));
      expect(animations[0].attributeType, equals(SvgAttributeType.color));
      expect(animations[0].from, equals('red'));
      expect(animations[0].to, equals('blue'));
    });

    test('parses stroke color animation', () {
      const svgXml = '''
        <svg>
          <circle cx="50" cy="50" r="25" stroke="green">
            <animate attributeName="stroke" from="#00ff00" to="#ff0000" dur="2s"/>
          </circle>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('stroke'));
      expect(animations[0].attributeType, equals(SvgAttributeType.color));
      expect(animations[0].from, equals('#00ff00'));
      expect(animations[0].to, equals('#ff0000'));
    });

    test('interpolates fill colors at t=0.5', () {
      final rectNode = SvgNode(tagName: 'rect');
      rectNode.setAttribute(
        'fill',
        const painting.Color(0xFFFF0000),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'fill',
        attributeType: SvgAttributeType.color,
        from: '#ff0000', // red
        to: '#0000ff', // blue
        dur: const Duration(seconds: 1),
      );

      // At t=0.5, should be purple-ish (#800080 или около того)
      final value = anim.computeValue(0.5);

      expect(value, isA<painting.Color>());
      final color = value as painting.Color;

      // Red channel: 255 → 0, at 0.5 = 127
      // Green channel: 0 → 0, at 0.5 = 0
      // Blue channel: 0 → 255, at 0.5 = 127
      expect((color.r * 255).round(), closeTo(127, 1));
      expect((color.g * 255).round(), closeTo(0, 1));
      expect((color.b * 255).round(), closeTo(127, 1));
    });

    test('interpolates stroke colors', () {
      final circleNode = SvgNode(tagName: 'circle');
      circleNode.setAttribute(
        'stroke',
        const painting.Color(0xFF00FF00),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: circleNode,
        attributeName: 'stroke',
        attributeType: SvgAttributeType.color,
        from: '#00ff00', // green in hex
        to: '#ff0000', // red in hex
        dur: const Duration(seconds: 2),
      );

      final value = anim.computeValue(0.25);

      expect(value, isA<painting.Color>());
      final color = value as painting.Color;

      // At t=0.25:
      // Red: 0 → 255, at 0.25 = 63
      // Green: 255 → 0, at 0.25 = 191
      // Blue: 0 → 0, at 0.25 = 0
      expect((color.r * 255).round(), closeTo(63, 2));
      expect((color.g * 255).round(), closeTo(191, 2));
      expect((color.b * 255).round(), equals(0));
    });

    test('animates fill with values + keyTimes', () {
      final rectNode = SvgNode(tagName: 'rect');
      rectNode.setAttribute(
        'fill',
        const painting.Color(0xFFFF0000),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'fill',
        attributeType: SvgAttributeType.color,
        values: ['red', 'green', 'blue'],
        keyTimes: [0.0, 0.5, 1.0],
        dur: const Duration(seconds: 3),
      );

      // At t=0.25 (between red and green)
      final value1 = anim.computeValue(0.25);
      expect(value1, isA<painting.Color>());

      // At t=0.75 (between green and blue)
      final value2 = anim.computeValue(0.75);
      expect(value2, isA<painting.Color>());
    });

    test('applies animated fill color to node', () {
      final rectNode = SvgNode(tagName: 'rect');
      rectNode.setAttribute(
        'fill',
        const painting.Color(0xFFFF0000),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'fill',
        attributeType: SvgAttributeType.color,
        from: 'red',
        to: 'blue',
        dur: const Duration(seconds: 1),
      );

      // Simulate animation at t=0.5s
      anim.updateForTime(const Duration(milliseconds: 500));

      // Check that fill attribute was updated
      final fillAttr = rectNode.getAttribute('fill');
      expect(fillAttr, isNotNull);
      expect(fillAttr!.isAnimated, isTrue);
      expect(fillAttr.effectiveValue, isA<painting.Color>());
    });

    test('applies animated stroke color to node', () {
      final circleNode = SvgNode(tagName: 'circle');
      circleNode.setAttribute(
        'stroke',
        const painting.Color(0xFF00FF00),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: circleNode,
        attributeName: 'stroke',
        attributeType: SvgAttributeType.color,
        from: 'green',
        to: 'yellow',
        dur: const Duration(seconds: 1),
      );

      anim.updateForTime(const Duration(milliseconds: 500));

      final strokeAttr = circleNode.getAttribute('stroke');
      expect(strokeAttr, isNotNull);
      expect(strokeAttr!.isAnimated, isTrue);
      expect(strokeAttr.effectiveValue, isA<painting.Color>());
    });
  });
}
