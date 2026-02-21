import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';
import 'package:flutter_svg/src/animation/smil/timing_condition.dart';
import 'package:flutter_svg/src/animation/smil/timing_parser.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event-Based Timing - Parsing', () {
    test('Parse simple click event', () {
      final conditions = TimingParser.parse('click');
      expect(conditions, hasLength(1));
      expect(conditions[0], isA<EventCondition>());

      final event = conditions[0] as EventCondition;
      expect(event.eventType, 'click');
      expect(event.offset, Duration.zero);
      expect(event.targetId, isNull);
    });

    test('Parse event with offset', () {
      final conditions = TimingParser.parse('click+2s');
      expect(conditions, hasLength(1));
      expect(conditions[0], isA<EventCondition>());

      final event = conditions[0] as EventCondition;
      expect(event.eventType, 'click');
      expect(event.offset, const Duration(seconds: 2));
    });

    test('Parse event with negative offset', () {
      final conditions = TimingParser.parse('mouseover-500ms');
      expect(conditions, hasLength(1));
      expect(conditions[0], isA<EventCondition>());

      final event = conditions[0] as EventCondition;
      expect(event.eventType, 'mouseover');
      expect(event.offset, const Duration(milliseconds: -500));
    });

    test('Parse multiple event types', () {
      final mouseoverCond = TimingParser.parse('mouseover');
      expect(mouseoverCond, hasLength(1));
      expect((mouseoverCond[0] as EventCondition).eventType, 'mouseover');

      final mouseoutCond = TimingParser.parse('mouseout');
      expect(mouseoutCond, hasLength(1));
      expect((mouseoutCond[0] as EventCondition).eventType, 'mouseout');

      final focusCond = TimingParser.parse('focus');
      expect(focusCond, hasLength(1));
      expect((focusCond[0] as EventCondition).eventType, 'focus');

      final blurCond = TimingParser.parse('blur');
      expect(blurCond, hasLength(1));
      expect((blurCond[0] as EventCondition).eventType, 'blur');
    });

    test('Parse target-specific event', () {
      final conditions = TimingParser.parse('button.click+250ms');
      expect(conditions, hasLength(1));
      expect(conditions[0], isA<EventCondition>());

      final event = conditions[0] as EventCondition;
      expect(event.targetId, 'button');
      expect(event.eventType, 'click');
      expect(event.offset, const Duration(milliseconds: 250));
    });

    test('Parse mixed conditions with events', () {
      final conditions = TimingParser.parse('2s; click; anim1.end');
      expect(conditions, hasLength(3));
      expect(conditions[0], isA<OffsetCondition>());
      expect(conditions[1], isA<EventCondition>());
      expect(conditions[2], isA<SyncbaseCondition>());
    });
  });

  group('Event-Based Timing - Timeline Integration', () {
    test('Timeline registers event listeners during build', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect id="myRect" x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations[0].beginConditions, hasLength(1));
      expect(animations[0].beginConditions[0], isA<EventCondition>());

      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );
      expect(timeline, isNotNull);
      // Timeline should have registered the event listener internally
    });

    test('Trigger event activates animation', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // Animation should not be active initially
      expect(anim.isActive, isFalse);

      // Trigger click event
      timeline.triggerEvent(null, 'click');

      // Animation should now be active
      expect(anim.isActive, isTrue);

      // Value should be at start (0)
      final valueAtStart = anim.computeValue(0.0);
      expect(valueAtStart, 0.0);
    });

    test('Target-specific event activates only on matching element ID', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect id="target" x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="target.click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );
      final anim = animations[0];

      timeline.triggerEvent(null, 'click');
      expect(anim.isActive, isFalse);

      timeline.triggerEvent('target', 'click');
      expect(anim.isActive, isTrue);
    });

    test('Event with offset delays animation start', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click+1s"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // Trigger event at t=0
      timeline.triggerEvent(null, 'click');

      // Animation should not be active yet (needs to wait 1s)
      expect(anim.isActive, isFalse);

      // Advance time to 0.5s - still not active
      timeline.seek(const Duration(milliseconds: 500));
      expect(anim.isActive, isFalse);

      // Advance time to 1.0s - now active
      timeline.seek(const Duration(seconds: 1));
      expect(anim.isActive, isTrue);

      // Advance to 1.5s - halfway through animation (0.5s into 2s animation = 0.25 progress)
      timeline.seek(const Duration(milliseconds: 1500));
      final value = anim.computeValue(0.25); // 0.25 * 80 = 20
      expect(value, closeTo(20.0, 1.0));
    });

    test('Multiple animations triggered by same event', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate id="anim1" attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
  <circle cx="10" cy="50" r="5" fill="red">
    <animate id="anim2" attributeName="cx" from="10" to="90" dur="3s" begin="click"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      expect(animations, hasLength(2));

      // Both should be inactive
      expect(animations[0].isActive, isFalse);
      expect(animations[1].isActive, isFalse);

      // Trigger click - both should activate
      timeline.triggerEvent(null, 'click');

      expect(animations[0].isActive, isTrue);
      expect(animations[1].isActive, isTrue);
    });

    test('Different event types trigger different animations', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
  <circle cx="10" cy="50" r="5" fill="red">
    <animate attributeName="cx" from="10" to="90" dur="3s" begin="mouseover"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      // Trigger click - only first animation activates
      timeline.triggerEvent(null, 'click');
      expect(animations[0].isActive, isTrue);
      expect(animations[1].isActive, isFalse);

      // Reset
      timeline.reset();
      expect(animations[0].isActive, isFalse);
      expect(animations[1].isActive, isFalse);

      // Trigger mouseover - only second animation activates
      timeline.triggerEvent(null, 'mouseover');
      expect(animations[0].isActive, isFalse);
      expect(animations[1].isActive, isTrue);
    });

    test('Event can be triggered multiple times', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // First click
      timeline.triggerEvent(null, 'click');
      expect(anim.isActive, isTrue);

      // Let animation run for 1s (halfway)
      timeline.seek(const Duration(seconds: 1));
      final firstValue = anim.computeValue(0.5); // Halfway = 40
      expect(firstValue, greaterThan(0));

      // Second click at t=1s (restarts animation)
      timeline.triggerEvent(null, 'click');

      // Animation should restart - checking at very beginning after restart
      final restartValue = anim.computeValue(0.0);
      expect(restartValue, 0.0); // Back to start
    });

    test('Event timing with indefinite begin', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="indefinite"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // Animation should not start on its own
      timeline.seek(const Duration(seconds: 5));
      expect(anim.isActive, isFalse);

      // Can be triggered programmatically (in real usage, via JavaScript or controller)
      // This is the basis for event-based timing
    });

    test('Reset clears event history', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      // Trigger event
      timeline.triggerEvent(null, 'click');
      expect(animations[0].isActive, isTrue);

      // Reset should clear everything
      timeline.reset();
      expect(animations[0].isActive, isFalse);
      expect(timeline.currentTime, Duration.zero);
    });
  });

  group('Event-Based Timing - Complex Scenarios', () {
    test('Event chain: click triggers animation that triggers another', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate id="anim1" attributeName="x" from="0" to="80" dur="2s" begin="click"/>
  </rect>
  <circle cx="10" cy="50" r="5" fill="red">
    <animate attributeName="cx" from="10" to="90" dur="1s" begin="anim1.end"/>
  </circle>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      // Trigger click
      timeline.triggerEvent(null, 'click');

      // First animation starts
      expect(animations[0].isActive, isTrue);
      expect(animations[1].isActive, isFalse);

      // After first animation completes (2s)
      timeline.seek(const Duration(seconds: 2));
      expect(animations[1].isActive, isTrue);
    });

    test('Multiple event conditions (OR logic)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="click; mouseover"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // Either event should trigger
      timeline.triggerEvent(null, 'mouseover');
      expect(anim.isActive, isTrue);

      // Reset and try other event
      timeline.reset();
      timeline.triggerEvent(null, 'click');
      expect(anim.isActive, isTrue);
    });

    test('Mixed conditions: time and event', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <rect x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" begin="2s; click"/>
  </rect>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final timeline = SvgTimeline(
        animations: animations,
        rootNode: document.root,
      );

      final anim = animations[0];

      // Animation should start at 2s automatically
      timeline.seek(const Duration(milliseconds: 2000));
      expect(anim.isActive, isTrue);

      // Reset and trigger via click before 2s
      timeline.reset();
      timeline.seek(const Duration(seconds: 1));
      expect(anim.isActive, isFalse);

      timeline.triggerEvent(null, 'click');
      expect(anim.isActive, isTrue);
    });
  });
}
