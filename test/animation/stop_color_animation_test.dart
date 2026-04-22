import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart' as painting;

void main() {
  group('Gradient Stop Color CSS Animation', () {
    test('CSS selector matches stop elements inside defs/gradient', () {
      // Test that CSS rules with #id selectors match <stop> elements inside
      // <defs> > <radialGradient> hierarchy
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes stopColorAnim {
      0% { stop-color: #56fea5; }
      50% { stop-color: #d9ff52; }
      100% { stop-color: #56fea5; }
    }
    #stop1 {
      animation: stopColorAnim 3000ms linear infinite;
    }
  </style>
  <defs>
    <radialGradient id="grad1">
      <stop id="stop1" offset="0%" stop-color="#56fea5"/>
      <stop id="stop2" offset="100%" stop-color="#000000"/>
    </radialGradient>
  </defs>
  <rect width="100" height="100" fill="url(#grad1)"/>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      // Should have one animation targeting the stop element
      expect(animations, hasLength(1));
      expect(animations[0].attributeName, equals('stop-color'));
      expect(animations[0].attributeType, equals(SvgAttributeType.color));
      expect(animations[0].targetNode.tagName, equals('stop'));
      expect(animations[0].targetNode.id, equals('stop1'));
    });

    test('stop-color animation values are correctly parsed', () {
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes stopColorAnim {
      0% { stop-color: #ff0000; }
      100% { stop-color: #0000ff; }
    }
    #myStop {
      animation: stopColorAnim 1s linear;
    }
  </style>
  <defs>
    <linearGradient id="grad">
      <stop id="myStop" offset="50%" stop-color="#ff0000"/>
    </linearGradient>
  </defs>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations, hasLength(1));
      final anim = animations[0];

      expect(anim.values, isNotNull);
      expect(anim.values, hasLength(2));
      expect(anim.values![0], equals('#ff0000'));
      expect(anim.values![1], equals('#0000ff'));
      expect(anim.keyTimes, hasLength(2));
      expect(anim.keyTimes![0], equals(0.0));
      expect(anim.keyTimes![1], equals(1.0));
    });

    test('stop-color animation interpolates colors correctly', () {
      final stopNode = SvgNode(tagName: 'stop', id: 'testStop');
      stopNode.setAttribute(
        'stop-color',
        const painting.Color(0xFFFF0000), // red
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: stopNode,
        attributeName: 'stop-color',
        attributeType: SvgAttributeType.color,
        from: '#ff0000', // red
        to: '#0000ff', // blue
        dur: const Duration(seconds: 1),
      );

      // At t=0.5, should be purple (127, 0, 127)
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

    test('stop-color animation applies animated value to stop node', () {
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes stopAnim {
      0% { stop-color: #ff0000; }
      100% { stop-color: #00ff00; }
    }
    #animatedStop {
      animation: stopAnim 2s linear;
    }
  </style>
  <defs>
    <linearGradient id="testGrad">
      <stop id="animatedStop" offset="0%" stop-color="#ff0000"/>
      <stop offset="100%" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations, hasLength(1));
      final anim = animations[0];
      final stopNode = anim.targetNode;

      // Simulate animation at t=1s (50% of 2s duration)
      anim.updateForTime(const Duration(seconds: 1));

      // Check that stop-color attribute was updated
      final stopColorAttr = stopNode.getAttribute('stop-color');
      expect(stopColorAttr, isNotNull);
      expect(stopColorAttr!.isAnimated, isTrue);
      expect(stopColorAttr.effectiveValue, isA<painting.Color>());

      // At 50% between red (#ff0000) and green (#00ff00)
      final color = stopColorAttr.effectiveValue as painting.Color;
      expect((color.r * 255).round(), closeTo(127, 2)); // red: 255 → 0
      expect((color.g * 255).round(), closeTo(127, 2)); // green: 0 → 255
      expect((color.b * 255).round(), closeTo(0, 1)); // blue: 0 → 0
    });

    test('stop-color animation with keyTimes works correctly', () {
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes colorCycle {
      0% { stop-color: #ff0000; }
      50% { stop-color: #00ff00; }
      100% { stop-color: #0000ff; }
    }
    #cycleStop {
      animation: colorCycle 4s linear;
    }
  </style>
  <defs>
    <linearGradient id="cycleGrad">
      <stop id="cycleStop" offset="50%"/>
    </linearGradient>
  </defs>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations, hasLength(1));

      final anim = animations[0];

      // Check keyTimes
      expect(anim.keyTimes, hasLength(3));
      expect(anim.keyTimes![0], equals(0.0));
      expect(anim.keyTimes![1], equals(0.5));
      expect(anim.keyTimes![2], equals(1.0));

      // At t=1s (25% of 4s) - between 0% (red) and 50% (green) keyframes
      // Local t within first segment: 0.25/0.5 = 0.5
      anim.updateForTime(const Duration(seconds: 1));
      var color =
          anim.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color.r * 255).round(), closeTo(127, 2)); // red: 255 → 0
      expect((color.g * 255).round(), closeTo(127, 2)); // green: 0 → 255
      expect((color.b * 255).round(), closeTo(0, 1));

      // At t=3s (75% of 4s) - between 50% (green) and 100% (blue) keyframes
      // Local t within second segment: (0.75-0.5)/0.5 = 0.5
      anim.updateForTime(const Duration(seconds: 3));
      color =
          anim.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color.r * 255).round(), closeTo(0, 1));
      expect((color.g * 255).round(), closeTo(127, 2)); // green: 255 → 0
      expect((color.b * 255).round(), closeTo(127, 2)); // blue: 0 → 255
    });

    test('multiple stop elements can have independent CSS animations', () {
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes stopAnim1 {
      0% { stop-color: #ff0000; }
      100% { stop-color: #00ff00; }
    }
    @keyframes stopAnim2 {
      0% { stop-color: #0000ff; }
      100% { stop-color: #ffff00; }
    }
    #stop1 {
      animation: stopAnim1 1s linear;
    }
    #stop2 {
      animation: stopAnim2 2s linear;
    }
  </style>
  <defs>
    <linearGradient id="multiGrad">
      <stop id="stop1" offset="0%"/>
      <stop id="stop2" offset="100%"/>
    </linearGradient>
  </defs>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations, hasLength(2));

      final anim1 = animations.firstWhere((a) => a.targetNode.id == 'stop1');
      final anim2 = animations.firstWhere((a) => a.targetNode.id == 'stop2');

      expect(anim1.attributeName, equals('stop-color'));
      expect(anim2.attributeName, equals('stop-color'));
      expect(anim1.dur, equals(const Duration(seconds: 1)));
      expect(anim2.dur, equals(const Duration(seconds: 2)));

      // Update both at t=0.5s
      anim1.updateForTime(const Duration(milliseconds: 500));
      anim2.updateForTime(const Duration(milliseconds: 500));

      // anim1: 50% through 1s duration → 50% between red and green
      final color1 =
          anim1.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color1.r * 255).round(), closeTo(127, 2));
      expect((color1.g * 255).round(), closeTo(127, 2));

      // anim2: 25% through 2s duration → 25% between blue and yellow
      final color2 =
          anim2.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color2.r * 255).round(), closeTo(63, 2)); // 0 → 255
      expect((color2.g * 255).round(), closeTo(63, 2)); // 0 → 255
      expect((color2.b * 255).round(), closeTo(191, 2)); // 255 → 0
    });

    test('stop-color animation with infinite iteration count', () {
      const svgXml = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes infiniteStop {
      0% { stop-color: #000000; }
      100% { stop-color: #ffffff; }
    }
    #infiniteStopElem {
      animation: infiniteStop 1s linear infinite;
    }
  </style>
  <defs>
    <radialGradient id="infGrad">
      <stop id="infiniteStopElem" offset="50%"/>
    </radialGradient>
  </defs>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);
      expect(animations, hasLength(1));

      final anim = animations[0];
      expect(anim.repeatCount, equals(double.infinity));

      // At t=0.5s (50% of 1s cycle)
      anim.updateForTime(const Duration(milliseconds: 500));
      var color =
          anim.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color.r * 255).round(), closeTo(127, 2));
      expect((color.g * 255).round(), closeTo(127, 2));
      expect((color.b * 255).round(), closeTo(127, 2));

      // At t=1.5s (50% into second cycle)
      anim.updateForTime(const Duration(milliseconds: 1500));
      color =
          anim.targetNode.getAttribute('stop-color')!.effectiveValue
              as painting.Color;
      expect((color.r * 255).round(), closeTo(127, 2));
    });

    test('effectiveValue returns animated color for gradient resolution', () {
      final stopNode = SvgNode(tagName: 'stop', id: 'gradStop');

      // Set initial base value
      stopNode.setAttribute(
        'stop-color',
        const painting.Color(0xFFFF0000), // red
        type: SvgAttributeType.color,
      );

      // Verify baseValue
      expect(
        stopNode.getAttributeValue('stop-color'),
        equals(const painting.Color(0xFFFF0000)),
      );

      // Create and apply animation
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: stopNode,
        attributeName: 'stop-color',
        attributeType: SvgAttributeType.color,
        from: '#ff0000',
        to: '#00ff00',
        dur: const Duration(seconds: 1),
      );

      // Apply animation at 50%
      anim.updateForTime(const Duration(milliseconds: 500));

      // getAttributeValue should now return the animated value
      final effectiveColor = stopNode.getAttributeValue('stop-color');
      expect(effectiveColor, isA<painting.Color>());

      final color = effectiveColor as painting.Color;
      // At 50% between red and green
      expect((color.r * 255).round(), closeTo(127, 2));
      expect((color.g * 255).round(), closeTo(127, 2));
      expect((color.b * 255).round(), closeTo(0, 1));
    });

    test('CSS animation with SVGator-style ID selector', () {
      // Test with SVGator-generated ID naming convention
      const svgXml = '''
<svg viewBox="0 0 200 200">
  <style>
    #eQVNhIKm4qz3-fill-0 {
      animation: eQVNhIKm4qz3-fill-0__c 3000ms linear infinite normal forwards
    }
    @keyframes eQVNhIKm4qz3-fill-0__c {
      0% { stop-color: #56fea5 }
      50% { stop-color: #d9ff52 }
      100% { stop-color: #56fea5 }
    }
  </style>
  <defs>
    <radialGradient id="eQVNhIKm4qz3-fill">
      <stop id="eQVNhIKm4qz3-fill-0" offset="0%" stop-color="#56fea5"/>
      <stop id="eQVNhIKm4qz3-fill-1" offset="100%" stop-color="#000000"/>
    </radialGradient>
  </defs>
  <ellipse fill="url(#eQVNhIKm4qz3-fill)" cx="100" cy="100" rx="50" ry="50"/>
</svg>
''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations, hasLength(1));
      expect(animations[0].targetNode.id, equals('eQVNhIKm4qz3-fill-0'));
      expect(animations[0].attributeName, equals('stop-color'));
      expect(animations[0].dur, equals(const Duration(milliseconds: 3000)));
      expect(animations[0].repeatCount, equals(double.infinity));

      // Verify values
      expect(animations[0].values, hasLength(3));
      expect(animations[0].values![0], equals('#56fea5'));
      expect(animations[0].values![1], equals('#d9ff52'));
      expect(animations[0].values![2], equals('#56fea5'));
    });

    test('stop-color animation clears properly on animation end', () {
      final stopNode = SvgNode(tagName: 'stop', id: 'clearStop');
      stopNode.setAttribute(
        'stop-color',
        const painting.Color(0xFFFF0000),
        type: SvgAttributeType.color,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: stopNode,
        attributeName: 'stop-color',
        attributeType: SvgAttributeType.color,
        from: '#ff0000',
        to: '#00ff00',
        dur: const Duration(seconds: 1),
        fillMode: SmilFillMode.remove, // Animation should be removed after
        repeatCount: 1,
      );

      // During animation
      anim.updateForTime(const Duration(milliseconds: 500));
      expect(stopNode.getAttribute('stop-color')!.isAnimated, isTrue);

      // After animation ends (with remove fill mode, the attribute clears)
      anim.updateForTime(const Duration(seconds: 2));
      expect(stopNode.getAttribute('stop-color')!.isAnimated, isFalse);

      // effectiveValue should now be baseValue
      expect(
        stopNode.getAttributeValue('stop-color'),
        equals(const painting.Color(0xFFFF0000)),
      );
    });
  });
}
