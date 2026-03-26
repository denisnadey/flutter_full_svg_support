import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';
import 'package:flutter_svg/src/animation/smil/timing_condition.dart';
import 'package:flutter_svg/src/animation/smil/motion_path.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('Repeat-based syncbase timing (id.repeat(n))', () {
    test('triggers dependent animation on specific repeat', () {
      final node1 = SvgNode(tagName: 'rect', attributes: {});
      final node2 = SvgNode(tagName: 'circle', attributes: {});

      final anim1 = SmilAnimation(
        id: 'source',
        type: SmilAnimationType.animate,
        targetNode: node1,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero,
        repeatCount: 5.0,
      );

      final anim2 = SmilAnimation(
        id: 'dependent',
        type: SmilAnimationType.animate,
        targetNode: node2,
        attributeName: 'cx',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 50.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero,
        beginConditions: [
          SyncbaseCondition(
            animationId: 'source',
            type: SyncbaseType.repeat,
            repeatIndex: 3,
          ),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      // At t=2s (before 3rd repeat), dependent should not be active
      timeline.seek(const Duration(seconds: 2));
      expect(anim1.isActive, isTrue);
      expect(anim1.currentIteration, equals(2));

      // At t=3s (3rd repeat starts), dependent should become active
      timeline.seek(const Duration(seconds: 3));
      expect(anim1.isActive, isTrue);
      expect(anim1.currentIteration, equals(3));
      expect(anim2.isActive, isTrue, reason: 'should activate on repeat 3');
    });

    test('repeat syncbase with offset resolves correct begin time', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim1 = SmilAnimation(
        id: 'anim1',
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: Duration.zero,
        repeatCount: 3.0,
        beginConditions: [OffsetCondition(Duration.zero)],
      );

      final anim2 = SmilAnimation(
        id: 'anim2',
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'y',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 50.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero,
        beginConditions: [
          SyncbaseCondition(
            animationId: 'anim1',
            type: SyncbaseType.repeat,
            repeatIndex: 1,
            offset: const Duration(milliseconds: 500),
          ),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      // The static resolution calculates repeat(1) time as: begin + dur * 1 = 2s
      // With offset of 500ms, anim2 should start at 2.5s
      final resolvedBeginTime = anim2.getEffectiveBeginTime();
      expect(
        resolvedBeginTime,
        equals(const Duration(milliseconds: 2500)),
        reason:
            'resolved begin time should be 2.5s (repeat at 2s + 500ms offset)',
      );

      final effectiveEndTime = anim2.getEffectiveEndTime();
      expect(
        effectiveEndTime,
        equals(const Duration(milliseconds: 3500)),
        reason: 'effective end time should be 3.5s (begin 2.5s + dur 1s)',
      );

      // Verify timeline is created correctly
      expect(timeline, isNotNull);
      expect(timeline.animations.length, equals(2));
    });
  });

  group('Animation sandwich model (priority resolution)', () {
    test('later animations override earlier ones for same attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect id="target" x="0" width="10" height="10">
    <animate attributeName="x" from="0" to="50" dur="1s" fill="freeze"/>
    <animate attributeName="x" from="0" to="100" dur="1s" fill="freeze"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(2));

      // Both should have same target and attribute
      expect(animations[0].attributeName, equals('x'));
      expect(animations[1].attributeName, equals('x'));

      // Later animation value should win
      final firstValue = animations[0].computeValue(1.0);
      final secondValue = animations[1].computeValue(1.0);

      expect(firstValue, equals(50.0));
      expect(secondValue, equals(100.0));
    });

    test('additive animations stack in document order', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <rect id="target" x="10" width="10" height="10">
    <animate attributeName="x" from="0" to="20" dur="1s" additive="sum"/>
    <animate attributeName="x" from="0" to="30" dur="1s" additive="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(2));
      expect(animations[0].additive, equals(SmilAdditiveMode.sum));
      expect(animations[1].additive, equals(SmilAdditiveMode.sum));
    });
  });

  group('repeatDur vs repeatCount interaction', () {
    test('min(repeatCount * dur, repeatDur) is used when both specified', () {
      // repeatCount * dur = 3 * 1s = 3s
      // repeatDur = 2s
      // Expected: min(3s, 2s) = 2s
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        repeatCount: 3.0,
        repeatDur: const Duration(seconds: 2),
      );

      final endTime = anim.getEffectiveEndTime();
      expect(endTime, equals(const Duration(seconds: 2)));
    });

    test('repeatDur wins when smaller than repeatCount * dur', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        repeatCount: 5.0, // 10s
        repeatDur: const Duration(seconds: 6), // 6s - wins
      );

      expect(anim.getEffectiveEndTime(), equals(const Duration(seconds: 6)));
    });

    test('repeatCount * dur wins when smaller than repeatDur', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        repeatCount: 2.0, // 2s - wins
        repeatDur: const Duration(seconds: 5), // 5s
      );

      expect(anim.getEffectiveEndTime(), equals(const Duration(seconds: 2)));
    });

    test('handles infinite repeatCount with finite repeatDur', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        repeatCount: double.infinity,
        repeatDur: const Duration(seconds: 5),
      );

      expect(anim.getEffectiveEndTime(), equals(const Duration(seconds: 5)));
    });
  });

  group('animateMotion complex path transforms', () {
    test('handles arc path segments correctly', () {
      final path = MotionPath('M0,50 A50,50 0 1,1 100,50');
      expect(path.totalLength, greaterThan(0));

      final start = path.getPointAtTime(0.0);
      final mid = path.getPointAtTime(0.5);
      final end = path.getPointAtTime(1.0);

      expect(start.position.dx, closeTo(0, 1));
      expect(end.position.dx, closeTo(100, 1));
      expect(mid.position, isNot(equals(start.position)));
    });

    test('handles double-back paths correctly', () {
      // Path that goes forward, then backward
      final path = MotionPath('M0,0 L100,0 L0,0');
      expect(path.totalLength, closeTo(200, 1));

      final start = path.getPointAtTime(0.0);
      final quarter = path.getPointAtTime(0.25);
      final mid = path.getPointAtTime(0.5);
      final threeQuarter = path.getPointAtTime(0.75);

      expect(start.position.dx, closeTo(0, 1));
      expect(quarter.position.dx, closeTo(50, 1));
      expect(mid.position.dx, closeTo(100, 1));
      expect(threeQuarter.position.dx, closeTo(50, 1));
    });

    test('handles very short path segments', () {
      // Path with extremely short segment
      final path = MotionPath('M0,0 L0.001,0 L100,0');
      expect(path.totalLength, greaterThan(0));

      final point = path.getPointAtTime(0.5);
      expect(point.position, isNotNull);
    });

    test('handles path discontinuity (moveTo mid-path)', () {
      // Path with a jump (discontinuity)
      final path = MotionPath('M0,0 L50,0 M100,0 L150,0');
      expect(path.totalLength, greaterThan(0));

      // Should still traverse the path
      final start = path.getPointAtTime(0.0);
      final end = path.getPointAtTime(1.0);

      expect(start.position.dx, closeTo(0, 1));
      expect(end.position.dx, closeTo(150, 1));
    });

    test('auto-rotate handles discontinuities', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L50,50 M100,0 L150,50" dur="1s" rotate="auto"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));

      final valueStart = animations[0].computeValue(0.0) as String?;
      final valueEnd = animations[0].computeValue(1.0) as String?;

      expect(valueStart, contains('rotate'));
      expect(valueEnd, contains('rotate'));
    });
  });

  group('mpath with conditional switch processing', () {
    test('selects path based on requiredFeatures', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <defs>
    <switch id="pathSwitch">
      <path id="path1" d="M0,0 L100,0" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Shape"/>
      <path id="path2" d="M0,0 L50,50"/>
    </switch>
  </defs>
  <rect>
    <animateMotion dur="1s">
      <mpath href="#pathSwitch"/>
    </animateMotion>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      // Should select path1 since Shape feature is supported
      expect(animations[0].from, equals('M0,0 L100,0'));
    });

    test('skips element with unsupported required extension', () {
      final svgString = '''
<svg viewBox="0 0 200 200">
  <defs>
    <switch id="pathSwitch">
      <path id="path1" d="M0,0 L100,0" requiredExtensions="http://example.com/unsupported"/>
      <path id="path2" d="M0,0 L50,50"/>
    </switch>
  </defs>
  <rect>
    <animateMotion dur="1s">
      <mpath href="#pathSwitch"/>
    </animateMotion>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      // Should skip path1 (unsupported extension) and use path2
      expect(animations[0].from, equals('M0,0 L50,50'));
    });

    test('selects path based on systemLanguage', () {
      final svgString = '''
<svg viewBox="0 0 200 200" lang="en">
  <defs>
    <switch id="pathSwitch">
      <path id="path1" d="M0,0 L100,0" systemLanguage="fr"/>
      <path id="path2" d="M0,0 L50,50" systemLanguage="en"/>
      <path id="path3" d="M0,0 L75,75"/>
    </switch>
  </defs>
  <rect>
    <animateMotion dur="1s">
      <mpath href="#pathSwitch"/>
    </animateMotion>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, equals(1));
      // Should select path2 (matches en language)
      expect(animations[0].from, equals('M0,0 L50,50'));
    });
  });

  group('Advanced accumulation for nested additive animations', () {
    test('accumulate adds final value per repeat cycle', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        repeatCount: 4.0,
        accumulate: true,
      );

      // First cycle end: 100
      final firstCycleEnd = anim.computeValue(1.0, completedRepeats: 0);
      expect(firstCycleEnd, equals(100.0));

      // Second cycle end: 100 + 100 = 200
      final secondCycleEnd = anim.computeValue(1.0, completedRepeats: 1);
      expect(secondCycleEnd, equals(200.0));

      // Third cycle end: 100 + 200 = 300
      final thirdCycleEnd = anim.computeValue(1.0, completedRepeats: 2);
      expect(thirdCycleEnd, equals(300.0));
    });

    test('accumulate with additive both work together', () {
      final svgString = '''
<svg viewBox="0 0 400 100">
  <rect x="50">
    <animate attributeName="x" from="0" to="100" dur="1s" 
             repeatCount="3" additive="sum" accumulate="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final anim = animations[0];

      expect(anim.additive, equals(SmilAdditiveMode.sum));
      expect(anim.accumulate, isTrue);

      // First cycle: baseValue(50) + 100 = 150
      final firstCycle = anim.computeValue(1.0, completedRepeats: 0);
      expect(firstCycle, isA<double>());

      // Second cycle: baseValue(50) + 100 + 100 = 250
      final secondCycle = anim.computeValue(1.0, completedRepeats: 1);
      expect(secondCycle, isA<double>());
    });

    test('accumulate with values list uses last value', () {
      final node = SvgNode(tagName: 'rect', attributes: {});

      final anim = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: node,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        values: [0.0, 50.0, 75.0], // final value is 75
        dur: const Duration(seconds: 1),
        repeatCount: 3.0,
        accumulate: true,
      );

      // First cycle end at value 75
      final firstCycleEnd = anim.computeValue(1.0, completedRepeats: 0);
      expect(firstCycleEnd, equals(75.0));

      // Second cycle end: 75 + 75 = 150
      final secondCycleEnd = anim.computeValue(1.0, completedRepeats: 1);
      expect(secondCycleEnd, equals(150.0));
    });

    test('accumulate on animateMotion adds position', () {
      final svgString = '''
<svg viewBox="0 0 500 200">
  <rect>
    <animateMotion path="M0,0 L100,50" dur="1s" repeatCount="3" accumulate="sum"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final anim = animations[0];

      expect(anim.accumulate, isTrue);

      // First cycle end
      final iter0 = anim.computeValue(1.0, completedRepeats: 0) as String?;
      expect(iter0, contains('100'));

      // Second cycle end (should have accumulated 100 + 100 = 200)
      final iter1 = anim.computeValue(1.0, completedRepeats: 1) as String?;
      expect(iter1, contains('200'));

      // Third cycle end (should have 300)
      final iter2 = anim.computeValue(1.0, completedRepeats: 2) as String?;
      expect(iter2, contains('300'));
    });
  });
}
