import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/smil/interpolators.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_timeline.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

int _colorChannelToInt(double channel) {
  return (channel * 255.0).round().clamp(0, 255);
}

void main() {
  group('Interpolators', () {
    test('interpolates numbers linearly', () {
      expect(Interpolators.interpolateNumber(0.0, 100.0, 0.0), equals(0.0));
      expect(Interpolators.interpolateNumber(0.0, 100.0, 0.5), equals(50.0));
      expect(Interpolators.interpolateNumber(0.0, 100.0, 1.0), equals(100.0));
    });

    test('interpolates colors in RGB space', () {
      const red = ui.Color(0xFFFF0000);
      const blue = ui.Color(0xFF0000FF);

      final mid = Interpolators.interpolateColor(red, blue, 0.5);

      expect(_colorChannelToInt(mid.r), closeTo(127, 1));
      expect(_colorChannelToInt(mid.g), equals(0));
      expect(_colorChannelToInt(mid.b), closeTo(127, 1));
    });

    test('parses hex colors', () {
      final color = Interpolators.interpolateColor('#FF0000', '#00FF00', 0.5);

      expect(_colorChannelToInt(color.r), closeTo(127, 1));
      expect(_colorChannelToInt(color.g), closeTo(127, 1));
      expect(_colorChannelToInt(color.b), equals(0));
    });

    test('parses named colors', () {
      final color = Interpolators.interpolateColor('red', 'blue', 0.5);

      expect(_colorChannelToInt(color.r), closeTo(127, 1));
      expect(_colorChannelToInt(color.b), closeTo(127, 1));
    });

    test('parses extended CSS named colors', () {
      final color = Interpolators.interpolateColor(
        'rebeccapurple',
        'rebeccapurple',
        0.5,
      );

      expect(color, equals(const ui.Color(0xFF663399)));
    });

    test('parses rgb() colors', () {
      final color = Interpolators.interpolateColor(
        'rgb(255, 0, 0)',
        'rgb(0, 0, 255)',
        0.5,
      );

      expect(_colorChannelToInt(color.r), closeTo(127, 1));
      expect(_colorChannelToInt(color.b), closeTo(127, 1));
    });

    test('interpolates lists of numbers', () {
      final result = Interpolators.interpolateList(
        [0.0, 0.0, 0.0],
        [100.0, 200.0, 300.0],
        0.5,
      );

      expect(result, equals([50.0, 100.0, 150.0]));
    });

    test('adds numbers for additive mode', () {
      final result = Interpolators.add(10.0, 5.0, SvgAttributeType.number);
      expect(result, equals(15.0));
    });
  });

  group('CubicBezier', () {
    test('linear ease (0 0 1 1) is identity', () {
      const linear = CubicBezier(0, 0, 1, 1);

      expect(linear.transform(0.0), closeTo(0.0, 0.01));
      expect(linear.transform(0.5), closeTo(0.5, 0.01));
      expect(linear.transform(1.0), closeTo(1.0, 0.01));
    });

    test('ease-in-out (0.42 0 0.58 1) curve', () {
      const easeInOut = CubicBezier(0.42, 0, 0.58, 1);

      // Slower at the beginning
      expect(easeInOut.transform(0.1), lessThan(0.1));

      // Also slower at the end
      expect(easeInOut.transform(0.9), greaterThan(0.9));
    });
  });

  group('SmilAnimation', () {
    late SvgNode testNode;

    setUp(() {
      testNode = SvgNode(tagName: 'rect');
      testNode.setAttribute('x', 0.0, type: SvgAttributeType.number);
    });

    test('simple from/to animation', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
      );

      expect(anim.computeValue(0.0), equals(0.0));
      expect(anim.computeValue(0.5), equals(50.0));
      expect(anim.computeValue(1.0), equals(100.0));
    });

    test('values-based animation with keyTimes', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        values: [0.0, 50.0, 100.0],
        keyTimes: [0.0, 0.25, 1.0],
        dur: const Duration(seconds: 4),
      );

      expect(anim.computeValue(0.0), equals(0.0));
      expect(
        anim.computeValue(0.125),
        closeTo(25.0, 1.0),
      ); // Halfway to keyTime 0.25
      expect(anim.computeValue(0.25), closeTo(50.0, 1.0));
      expect(anim.computeValue(1.0), equals(100.0));
    });

    test('discrete calc mode', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        values: [0.0, 50.0, 100.0],
        dur: const Duration(seconds: 3),
        calcMode: SmilCalcMode.discrete,
      );

      // Discrete - no interpolation, step changes
      expect(anim.computeValue(0.0), equals(0.0));
      expect(anim.computeValue(0.4), equals(50.0)); // floor(0.4 * 3) = 1
      expect(anim.computeValue(0.7), equals(100.0)); // floor(0.7 * 3) = 2
    });

    test('by attribute adds to from', () {
      testNode.setAttribute('x', 10.0, type: SvgAttributeType.number);

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        by: 50.0, // Add 50 to base value
        dur: const Duration(seconds: 1),
      );

      final result = anim.computeValue(1.0);
      expect(result, equals(60.0)); // 10 + 50
    });

    test('updateForTime activates/deactivates correctly', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: const Duration(seconds: 1),
      );

      // Before begin
      anim.updateForTime(Duration.zero);
      expect(anim.isActive, isFalse);

      // During animation
      anim.updateForTime(const Duration(milliseconds: 1500));
      expect(anim.isActive, isTrue);
      expect(testNode.getAttribute('x')?.isAnimated, isTrue);

      // After end
      anim.updateForTime(const Duration(seconds: 5));
      expect(anim.isActive, isFalse);
    });

    test('fill=freeze preserves last value', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        fillMode: SmilFillMode.freeze,
      );

      // During animation
      anim.updateForTime(const Duration(milliseconds: 500));
      expect(testNode.getAttribute('x')?.isAnimated, isTrue);

      // After animation ends
      anim.updateForTime(const Duration(seconds: 2));
      expect(anim.isActive, isFalse);
      expect(testNode.getAttribute('x')?.isAnimated, isTrue);
      expect(testNode.getAttribute('x')?.effectiveValue, equals(100.0));
    });

    test('repeatCount repeats animation', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: testNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        repeatCount: 2.0,
      );

      expect(anim.getEffectiveEndTime(), equals(const Duration(seconds: 2)));
    });
  });

  group('SvgTimeline', () {
    late SvgNode rootNode;
    late SvgNode rectNode;

    setUp(() {
      rootNode = SvgNode(tagName: 'svg');
      rectNode = SvgNode(tagName: 'rect');
      rectNode.setAttribute('x', 0.0, type: SvgAttributeType.number);
      rootNode.addChild(rectNode);
    });

    test('tick updates animation time', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
      );

      final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

      timeline.tick(const Duration(seconds: 1));
      expect(timeline.currentTime, equals(const Duration(seconds: 1)));
      expect(rectNode.getAttribute('x')?.effectiveValue, equals(50.0));
    });

    test('seek jumps to specific time', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
      );

      final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

      timeline.seek(const Duration(milliseconds: 1500));
      expect(timeline.currentTime, equals(const Duration(milliseconds: 1500)));
      expect(rectNode.getAttribute('x')?.effectiveValue, equals(75.0));
    });

    test('playbackRate affects tick speed', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        fillMode:
            SmilFillMode.freeze, // freeze is needed to preserve the final value
      );

      final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

      timeline.playbackRate = 2.0; // 2x speed
      timeline.tick(const Duration(seconds: 1));

      // With 2x speed, 1 second tick = 2 seconds of animation time
      expect(timeline.currentTime, equals(const Duration(seconds: 2)));
      expect(rectNode.getAttribute('x')?.effectiveValue, equals(100.0));
    });

    test('computes total duration correctly', () {
      final anim1 = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
      );

      final anim2 = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'y',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 3),
        begin: const Duration(seconds: 1),
      );

      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      // anim2 ends at 1 + 3 = 4 seconds
      expect(timeline.totalDuration, equals(const Duration(seconds: 4)));
    });

    test('hasActiveAnimations returns correct state', () {
      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: rectNode,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: const Duration(seconds: 1),
      );

      final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

      // Before begin
      timeline.tick(const Duration(milliseconds: 500));
      expect(timeline.hasActiveAnimations(), isFalse);

      // During animation
      timeline.tick(const Duration(milliseconds: 600));
      expect(timeline.hasActiveAnimations(), isTrue);

      // After end
      timeline.seek(const Duration(seconds: 5));
      expect(timeline.hasActiveAnimations(), isFalse);
    });
  });

  group('SmilParser', () {
    test('parses simple animate element', () {
      const svgXml = '''
        <svg>
          <rect id="myRect" x="0" y="0">
            <animate attributeName="x" from="0" to="100" dur="2s"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('x'));
      expect(animations[0].from, equals(0.0));
      expect(animations[0].to, equals(100.0));
      expect(animations[0].dur, equals(const Duration(seconds: 2)));
    });

    test('infers textLength animation as numeric attribute', () {
      const svgXml = '''
        <svg>
          <text id="label" textLength="20">AB
            <animate attributeName="textLength" from="20" to="80" dur="2s"/>
          </text>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('textLength'));
      expect(animations[0].attributeType, equals(SvgAttributeType.number));
      expect(animations[0].from, equals(20.0));
      expect(animations[0].to, equals(80.0));
    });

    test('parses values and keyTimes', () {
      const svgXml = '''
        <svg>
          <rect>
            <animate attributeName="opacity" 
                     values="0;1;0" 
                     keyTimes="0;0.5;1" 
                     dur="3s"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].values, equals([0.0, 1.0, 0.0]));
      expect(animations[0].keyTimes, equals([0.0, 0.5, 1.0]));
    });

    test('parses duration formats', () {
      const svgXml = '''
        <svg>
          <rect id="r1">
            <animate attributeName="x" dur="2s"/>
          </rect>
          <rect id="r2">
            <animate attributeName="x" dur="500ms"/>
          </rect>
          <rect id="r3">
            <animate attributeName="x" dur="0:02"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(3));
      expect(animations[0].dur, equals(const Duration(seconds: 2)));
      expect(animations[1].dur, equals(const Duration(milliseconds: 500)));
      expect(animations[2].dur, equals(const Duration(seconds: 2)));
    });

    test('parses repeatCount indefinite', () {
      const svgXml = '''
        <svg>
          <rect>
            <animate attributeName="x" dur="1s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations[0].repeatCount, equals(double.infinity));
    });

    test('parses fill mode', () {
      const svgXml = '''
        <svg>
          <rect>
            <animate attributeName="x" dur="1s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations[0].fillMode, equals(SmilFillMode.freeze));
    });

    test('parses calc mode', () {
      const svgXml = '''
        <svg>
          <rect>
            <animate attributeName="x" dur="1s" calcMode="discrete"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations[0].calcMode, equals(SmilCalcMode.discrete));
    });

    test('marks parent nodes as having animations', () {
      const svgXml = '''
        <svg>
          <g id="group">
            <rect id="rect">
              <animate attributeName="x" dur="1s"/>
            </rect>
          </g>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      SmilParser.parseAnimations(doc);

      final rect = doc.getElementById('rect');

      expect(rect?.hasAnimations, isTrue);
    });
  });
}
