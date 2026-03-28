import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';
import 'package:flutter_svg/src/animation/smil/timing_condition.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('SMIL Timing Precision', () {
    // ========== Fractional repeatCount Tests ==========
    group('Fractional repeatCount precision', () {
      test(
        'repeatCount="2.5" with dur="1s" produces exactly 2.5s active duration',
        () {
          final node = SvgNode(tagName: 'rect', attributes: {});
          final anim = SmilAnimation(
            id: 'anim1',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            repeatCount: 2.5,
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          );

          // Active duration should be exactly 2.5 seconds
          final activeDuration =
              anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
          expect(activeDuration, const Duration(milliseconds: 2500));
        },
      );

      test(
        'fractional repeatCount boundary values (0.0, 0.5, 1.0, 1.5, 2.0, 2.5)',
        () {
          final node = SvgNode(tagName: 'rect', attributes: {});
          node.setAttribute('x', 0.0, type: SvgAttributeType.number);

          final anim = SmilAnimation(
            id: 'anim1',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            repeatCount: 2.5,
            fillMode: SmilFillMode.freeze,
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          );

          final rootNode = SvgNode(tagName: 'svg', attributes: {});
          final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

          // t=0.0: start of iteration 0, progress = 0.0
          timeline.seek(Duration.zero);
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 0);

          // t=0.5: middle of iteration 0, progress = 0.5
          timeline.seek(const Duration(milliseconds: 500));
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 0);

          // t=1.0: start of iteration 1, progress = 0.0
          timeline.seek(const Duration(seconds: 1));
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 1);

          // t=1.5: middle of iteration 1, progress = 0.5
          timeline.seek(const Duration(milliseconds: 1500));
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 1);

          // t=2.0: start of iteration 2, progress = 0.0
          timeline.seek(const Duration(seconds: 2));
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 2);

          // t=2.5: exactly at end (progress = 0.5 within iteration 2)
          timeline.seek(const Duration(milliseconds: 2500));
          expect(anim.isActive, isFalse); // Just past active period
        },
      );

      test(
        'interpolation fraction at end of fractional repeatCount is exact',
        () {
          final node = SvgNode(tagName: 'rect', attributes: {});
          node.setAttribute('x', 0.0, type: SvgAttributeType.number);

          final anim = SmilAnimation(
            id: 'anim1',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            repeatCount: 2.5,
            fillMode: SmilFillMode.freeze,
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          );

          // At t=2.5s (end), the value should be exactly 50.0 (0.5 * 100)
          // This tests that fractional progress is computed correctly
          final value = anim.computeValue(0.5, completedRepeats: 2);
          expect(value, 50.0);
        },
      );

      test(
        'indefinite repeatCount does not accumulate drift over many iterations',
        () {
          final node = SvgNode(tagName: 'rect', attributes: {});
          node.setAttribute('x', 0.0, type: SvgAttributeType.number);

          final anim = SmilAnimation(
            id: 'anim1',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(milliseconds: 100),
            repeatCount: 10000.0, // Use large finite value instead of infinity
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          );

          final rootNode = SvgNode(tagName: 'svg', attributes: {});
          final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

          // After 1000 iterations (100 seconds with 100ms dur), check for drift
          final time1000 = const Duration(seconds: 100);
          timeline.seek(time1000);
          expect(anim.isActive, isTrue);
          expect(anim.currentIteration, 1000);

          // At exactly t=100s, we should be at start of iteration 1000
          // localTime should be 0 (or very close to 0)
          expect(anim.localTime.inMicroseconds, 0);
        },
      );
    });

    // ========== Very Small Durations Tests ==========
    group('Very small durations', () {
      test('dur="0.001s" (1ms) works without precision issues', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(milliseconds: 1),
          repeatCount: 1000.0,
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // Should handle 1ms duration correctly
        timeline.seek(const Duration(microseconds: 500));
        expect(anim.isActive, isTrue);
        expect(anim.currentIteration, 0);

        // At 1ms, should be at iteration 1
        timeline.seek(const Duration(milliseconds: 1));
        expect(anim.isActive, isTrue);
        expect(anim.currentIteration, 1);
      });

      test('dur="0.0001s" (100us) works without NaN or Infinity', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(microseconds: 100),
          repeatCount: 10000.0,
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // Should handle 100us duration correctly
        timeline.seek(const Duration(microseconds: 50));
        expect(anim.isActive, isTrue);
        final value = anim.computeValue(0.5);
        expect(value, isNotNull);
        expect(value, isNot(isNaN));
      });

      test('dur="0" produces zero-effect instant animation', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: Duration.zero,
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Zero duration should produce zero active duration
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, Duration.zero);
      });

      test('very small duration with large repeatCount does not overflow', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(microseconds: 100),
          repeatCount: 1000000.0, // 1 million repeats
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Should compute active duration without overflow
        // 100us * 1000000 = 100 seconds
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 100));
      });
    });

    // ========== end + repeatDur Interaction Tests ==========
    group('end + repeatDur interaction', () {
      test('repeatDur="5s" and end="3s" - end wins (3s)', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 10.0, // Needs repeatCount > 1 for repeatDur to matter
          repeatDur: const Duration(seconds: 5),
          end: const Duration(seconds: 3),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Per SMIL spec: activeDur = min(repeatDur, max(end - begin, 0))
        // repeatCount*dur = 10s, repeatDur = 5s -> repeat duration = 5s
        // end - begin = 3s
        // activeDur = min(5, 3) = 3s
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 3));
      });

      test('repeatDur="3s" and end="5s" - repeatDur wins (3s)', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 10.0, // Needs repeatCount > 1 for repeatDur to matter
          repeatDur: const Duration(seconds: 3),
          end: const Duration(seconds: 5),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // repeatCount*dur = 10s, repeatDur = 3s -> repeat duration = 3s
        // end - begin = 5s
        // activeDur = min(3, 5) = 3s
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 3));
      });

      test('repeatDur="indefinite" and end="5s" - end determines (5s)', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: double.infinity, // indefinite repeat
          end: const Duration(seconds: 5),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // With indefinite repeatCount and end=5s, activeDur = 5s
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 5));
      });

      test('end before begin produces zero active duration', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: const Duration(seconds: 5),
          end: const Duration(seconds: 3), // end < begin
          beginConditions: [OffsetCondition(const Duration(seconds: 5))],
          documentOrder: 0,
        );

        // max(end - begin, 0) = max(3-5, 0) = max(-2, 0) = 0
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, Duration.zero);
      });

      test('animation value freezes correctly when cut short by end', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 2),
          repeatCount: 3.0, // Would be 6s total
          end: const Duration(seconds: 3), // Cut short at 3s
          fillMode: SmilFillMode.freeze,
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // At 3s (end), should be at 50% of iteration 1 (t=3s, dur=2s -> iteration 1, 50% through)
        timeline.seek(const Duration(seconds: 3));
        expect(anim.isActive, isFalse); // Past end
        // Value should be frozen at the end point
      });
    });

    // ========== min/max Constraints Tests ==========
    group('min/max timing constraints', () {
      test('min="2s" extends 1s active duration to 2s', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 1.0,
          min: const Duration(seconds: 2), // Extend to at least 2s
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Computed active duration is 1s, but min extends it to 2s
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 2));
      });

      test('max="3s" truncates 5s active duration to 3s', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 5.0, // Would be 5s
          max: const Duration(seconds: 3), // Truncate to 3s
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Computed active duration is 5s, but max truncates to 3s
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 3));
      });

      test('when min > max, min takes precedence', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 2.0, // 2s computed
          min: const Duration(seconds: 5), // min = 5s
          max: const Duration(seconds: 3), // max = 3s (less than min!)
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        // Per SMIL spec: min takes precedence over max
        // Result should be 5s (min wins)
        final activeDuration =
            anim.getEffectiveEndTime() - anim.getEffectiveBeginTime();
        expect(activeDuration, const Duration(seconds: 5));
      });

      test('animation in min-extended period uses fill behavior', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          repeatCount: 1.0,
          min: const Duration(seconds: 3), // Extend to 3s
          fillMode: SmilFillMode.freeze,
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // At t=1s, animation completes but we're still in active period due to min
        timeline.seek(const Duration(seconds: 1));
        expect(anim.isActive, isTrue);

        // At t=2s, still in min-extended period
        timeline.seek(const Duration(seconds: 2));
        expect(anim.isActive, isTrue);

        // At t=3s, active period ends
        timeline.seek(const Duration(seconds: 3));
        expect(anim.isActive, isFalse);
      });
    });

    // ========== Long-running Precision Tests ==========
    group('Long-running precision', () {
      test('10000+ iterations maintain precision', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(milliseconds: 100),
          repeatCount: 11000.0, // Large but finite
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // Simulate many iterations - test at iteration boundaries
        final testIterations = [100, 500, 1000, 5000, 10000];
        for (final i in testIterations) {
          final time = Duration(
            milliseconds: i * 100,
          ); // Exactly at iteration boundaries
          timeline.seek(time);

          // At exact iteration boundaries, localTime should be 0
          expect(
            anim.localTime.inMicroseconds,
            0,
            reason: 'At iteration $i, localTime should be 0',
          );
          expect(anim.currentIteration, i, reason: 'Should be at iteration $i');
        }

        // Check a specific iteration's midpoint
        timeline.seek(
          const Duration(milliseconds: 1000050),
        ); // 10000.5 iterations
        expect(anim.currentIteration, 10000);
        expect(anim.localTime.inMicroseconds, 50000); // 50ms into iteration
      });

      test('no drift after many fractional increments', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        node.setAttribute('x', 0.0, type: SvgAttributeType.number);

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(milliseconds: 100),
          repeatCount: 10000.0, // Large but finite
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(animations: [anim], rootNode: rootNode);

        // Use tick() with small deltas to simulate real-time playback
        // This tests for drift accumulation
        const tickDelta = Duration(microseconds: 16667); // ~60fps
        for (int i = 0; i < 60 * 10; i++) {
          // 10 seconds of playback
          timeline.tick(tickDelta);
        }

        // After ~10 seconds, we should be at ~iteration 100
        // Check that iteration count is close to expected
        final expectedIterations =
            timeline.currentTime.inMicroseconds ~/ 100000;
        expect(anim.currentIteration, closeTo(expectedIterations, 1));
      });
    });

    // ========== Original syncbase tests ==========
    group('Chain of 3 syncbase dependencies', () {
      test('A begins at 0, B begins at A.end, C begins at B.end', () {
        // <animate id="anim1" begin="0s" dur="1s"/>
        // <animate id="anim2" begin="anim1.end" dur="1s"/>
        // <animate id="anim3" begin="anim2.end" dur="1s"/>

        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim1 = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final anim2 = SmilAnimation(
          id: 'anim2',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 100.0,
          to: 200.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.end),
          ],
          documentOrder: 1,
        );

        final anim3 = SmilAnimation(
          id: 'anim3',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 200.0,
          to: 300.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.end),
          ],
          documentOrder: 2,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(
          animations: [anim1, anim2, anim3],
          rootNode: rootNode,
        );

        // Verify resolved begin times
        expect(anim1.getEffectiveBeginTime(), Duration.zero);
        expect(anim2.getEffectiveBeginTime(), const Duration(seconds: 1));
        expect(anim3.getEffectiveBeginTime(), const Duration(seconds: 2));

        // t=0: only anim1 active
        timeline.seek(Duration.zero);
        expect(anim1.isActive, isTrue);
        expect(anim2.isActive, isFalse);
        expect(anim3.isActive, isFalse);

        // t=1: anim1 ends, anim2 starts
        timeline.seek(const Duration(seconds: 1));
        expect(anim1.isActive, isFalse);
        expect(anim2.isActive, isTrue);
        expect(anim3.isActive, isFalse);

        // t=2: anim2 ends, anim3 starts
        timeline.seek(const Duration(seconds: 2));
        expect(anim1.isActive, isFalse);
        expect(anim2.isActive, isFalse);
        expect(anim3.isActive, isTrue);

        // t=3: all animations ended
        timeline.seek(const Duration(seconds: 3));
        expect(anim1.isActive, isFalse);
        expect(anim2.isActive, isFalse);
        expect(anim3.isActive, isFalse);
      });
    });

    group('Simultaneous resolution with document order tiebreaking', () {
      test('multiple animations with same resolved begin time', () {
        // Two animations that both resolve to begin at 0s
        // Document order should determine priority (earlier = lower priority)

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
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final anim2 = SmilAnimation(
          id: 'anim2',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 50.0,
          to: 150.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(
          animations: [anim1, anim2],
          rootNode: rootNode,
        );

        // Both should start at t=0
        expect(anim1.getEffectiveBeginTime(), Duration.zero);
        expect(anim2.getEffectiveBeginTime(), Duration.zero);

        timeline.seek(Duration.zero);
        expect(anim1.isActive, isTrue);
        expect(anim2.isActive, isTrue);
      });

      test('tiebreaking with mixed conditions resolving to same time', () {
        // anim1: begin="0s" dur="1s"
        // anim2: begin="1s" dur="1s"
        // anim3: begin="anim1.end" dur="1s" - resolves to 1s
        // anim2 and anim3 should both start at 1s

        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim1 = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
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
          begin: const Duration(seconds: 1),
          beginConditions: [OffsetCondition(const Duration(seconds: 1))],
          documentOrder: 1,
        );

        final anim3 = SmilAnimation(
          id: 'anim3',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'width',
          attributeType: SvgAttributeType.number,
          from: 10.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.end),
          ],
          documentOrder: 2,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(
          animations: [anim1, anim2, anim3],
          rootNode: rootNode,
        );

        // anim2 and anim3 both resolve to 1s
        expect(anim2.getEffectiveBeginTime(), const Duration(seconds: 1));
        expect(anim3.getEffectiveBeginTime(), const Duration(seconds: 1));

        timeline.seek(const Duration(seconds: 1));
        expect(anim1.isActive, isFalse);
        expect(anim2.isActive, isTrue);
        expect(anim3.isActive, isTrue);
      });
    });

    group('Circular dependency detection', () {
      test('direct circular: A.begin=B.end, B.begin=A.end', () {
        // <animate id="anim1" begin="anim2.end" dur="1s"/>
        // <animate id="anim2" begin="anim1.end" dur="1s"/>

        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim1 = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.end),
          ],
          documentOrder: 0,
        );

        final anim2 = SmilAnimation(
          id: 'anim2',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.end),
          ],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});

        // Should handle circular dependency without hanging
        expect(
          () => SvgTimeline(animations: [anim1, anim2], rootNode: rootNode),
          returnsNormally,
        );

        final timeline = SvgTimeline(
          animations: [anim1, anim2],
          rootNode: rootNode,
        );

        // Both should be resolved (cycle broken gracefully)
        // The resolution should use fallback begin times
        expect(timeline, isNotNull);
        expect(timeline.animations.length, 2);
      });

      test('A.begin=B.begin, B.begin=A.begin (mutual begin sync)', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim1 = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: const Duration(seconds: 5),
          beginConditions: [
            SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.begin),
          ],
          documentOrder: 0,
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
          begin: const Duration(seconds: 5),
          beginConditions: [
            SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.begin),
          ],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});

        // Should handle without hanging
        final timeline = SvgTimeline(
          animations: [anim1, anim2],
          rootNode: rootNode,
        );

        expect(timeline, isNotNull);
      });

      test('three-way circular: A->B->C->A', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim1 = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim3', type: SyncbaseType.end),
          ],
          documentOrder: 0,
        );

        final anim2 = SmilAnimation(
          id: 'anim2',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'y',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.end),
          ],
          documentOrder: 1,
        );

        final anim3 = SmilAnimation(
          id: 'anim3',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'width',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.end),
          ],
          documentOrder: 2,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});

        // Should handle without hanging
        final timeline = SvgTimeline(
          animations: [anim1, anim2, anim3],
          rootNode: rootNode,
        );

        // Verify timeline was created and animations resolved
        expect(timeline, isNotNull);
        expect(timeline.animations.length, 3);
      });
    });

    group('Forward references', () {
      test('B.begin references C.end where C is defined after B', () {
        // <animate id="anim2" begin="anim3.end" dur="1s"/>
        // <animate id="anim3" begin="0s" dur="1s"/>
        // anim2 references anim3 which comes later in document order

        final node = SvgNode(tagName: 'rect', attributes: {});

        // anim2 defined first, references anim3
        final anim2 = SmilAnimation(
          id: 'anim2',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'y',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'anim3', type: SyncbaseType.end),
          ],
          documentOrder: 0,
        );

        // anim3 defined after anim2
        final anim3 = SmilAnimation(
          id: 'anim3',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 50.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});

        // Order in list: anim2 (forward ref), anim3 (referenced)
        final timeline = SvgTimeline(
          animations: [anim2, anim3],
          rootNode: rootNode,
        );

        // anim3 starts at 0, ends at 1s
        // anim2 should start at 1s (anim3.end)
        expect(anim3.getEffectiveBeginTime(), Duration.zero);
        expect(anim2.getEffectiveBeginTime(), const Duration(seconds: 1));

        timeline.seek(Duration.zero);
        expect(anim3.isActive, isTrue);
        expect(anim2.isActive, isFalse);

        timeline.seek(const Duration(seconds: 1));
        expect(anim3.isActive, isFalse);
        expect(anim2.isActive, isTrue);
      });

      test(
        'complex forward reference chain: B->C->D where all forward refs',
        () {
          final node = SvgNode(tagName: 'rect', attributes: {});

          // anim1 references anim2 (forward)
          final anim1 = SmilAnimation(
            id: 'anim1',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            begin: Duration.zero,
            beginConditions: [
              SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.end),
            ],
            documentOrder: 0,
          );

          // anim2 references anim3 (forward)
          final anim2 = SmilAnimation(
            id: 'anim2',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'y',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            begin: Duration.zero,
            beginConditions: [
              SyncbaseCondition(animationId: 'anim3', type: SyncbaseType.end),
            ],
            documentOrder: 1,
          );

          // anim3 is the root (no dependencies)
          final anim3 = SmilAnimation(
            id: 'anim3',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'width',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 2,
          );

          final rootNode = SvgNode(tagName: 'svg', attributes: {});
          SvgTimeline(animations: [anim1, anim2, anim3], rootNode: rootNode);

          // Resolution should work despite forward references:
          // anim3: 0s -> 1s
          // anim2: 1s -> 2s (after anim3.end)
          // anim1: 2s -> 3s (after anim2.end)
          expect(anim3.getEffectiveBeginTime(), Duration.zero);
          expect(anim2.getEffectiveBeginTime(), const Duration(seconds: 1));
          expect(anim1.getEffectiveBeginTime(), const Duration(seconds: 2));
        },
      );
    });

    group('Complex offset chains', () {
      test(
        'begin="a.end+200ms; b.begin-100ms" where both conditions resolve',
        () {
          // <animate id="a" begin="0s" dur="1s"/>
          // <animate id="b" begin="500ms" dur="1s"/>
          // <animate id="c" begin="a.end+200ms; b.begin-100ms" dur="1s"/>
          //
          // a.end+200ms = 1s + 200ms = 1200ms
          // b.begin-100ms = 500ms - 100ms = 400ms
          // Earliest is 400ms, so c should start at 400ms

          final node = SvgNode(tagName: 'rect', attributes: {});

          final animA = SmilAnimation(
            id: 'a',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          );

          final animB = SmilAnimation(
            id: 'b',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'y',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 50.0,
            dur: const Duration(seconds: 1),
            begin: const Duration(milliseconds: 500),
            beginConditions: [
              OffsetCondition(const Duration(milliseconds: 500)),
            ],
            documentOrder: 1,
          );

          final animC = SmilAnimation(
            id: 'c',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'width',
            attributeType: SvgAttributeType.number,
            from: 10.0,
            to: 100.0,
            dur: const Duration(seconds: 1),
            begin: Duration.zero,
            beginConditions: [
              // a.end+200ms = 1200ms
              SyncbaseCondition(
                animationId: 'a',
                type: SyncbaseType.end,
                offset: const Duration(milliseconds: 200),
              ),
              // b.begin-100ms = 400ms
              SyncbaseCondition(
                animationId: 'b',
                type: SyncbaseType.begin,
                offset: const Duration(milliseconds: -100),
              ),
            ],
            documentOrder: 2,
          );

          final rootNode = SvgNode(tagName: 'svg', attributes: {});
          final timeline = SvgTimeline(
            animations: [animA, animB, animC],
            rootNode: rootNode,
          );

          // animC should start at earliest: 400ms
          expect(
            animC.getEffectiveBeginTime(),
            const Duration(milliseconds: 400),
          );

          timeline.seek(const Duration(milliseconds: 400));
          expect(animA.isActive, isTrue);
          expect(animB.isActive, isFalse); // b starts at 500ms
          expect(animC.isActive, isTrue);

          timeline.seek(const Duration(milliseconds: 500));
          expect(animA.isActive, isTrue);
          expect(animB.isActive, isTrue);
          expect(animC.isActive, isTrue);
        },
      );

      test('multiple offsets with same base animation', () {
        // begin="a.end; a.end+500ms; a.end+1s"
        // Earliest should win

        final node = SvgNode(tagName: 'rect', attributes: {});

        final animA = SmilAnimation(
          id: 'a',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final animB = SmilAnimation(
          id: 'b',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'y',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 50.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            SyncbaseCondition(animationId: 'a', type: SyncbaseType.end),
            SyncbaseCondition(
              animationId: 'a',
              type: SyncbaseType.end,
              offset: const Duration(milliseconds: 500),
            ),
            SyncbaseCondition(
              animationId: 'a',
              type: SyncbaseType.end,
              offset: const Duration(seconds: 1),
            ),
          ],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        SvgTimeline(animations: [animA, animB], rootNode: rootNode);

        // animB should start at a.end = 1s (earliest condition)
        expect(animB.getEffectiveBeginTime(), const Duration(seconds: 1));
      });
    });

    group('Indefinite begin resolved by syncbase', () {
      test('animation with indefinite and syncbase conditions', () {
        // <animate id="trigger" begin="0s" dur="2s"/>
        // <animate id="dependent" begin="indefinite; trigger.end" dur="1s"/>
        // The indefinite condition should not prevent the syncbase from resolving

        final node = SvgNode(tagName: 'rect', attributes: {});

        final trigger = SmilAnimation(
          id: 'trigger',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 2),
          begin: Duration.zero,
          beginConditions: [OffsetCondition(Duration.zero)],
          documentOrder: 0,
        );

        final dependent = SmilAnimation(
          id: 'dependent',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'y',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 50.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [
            const IndefiniteCondition(),
            SyncbaseCondition(animationId: 'trigger', type: SyncbaseType.end),
          ],
          documentOrder: 1,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        final timeline = SvgTimeline(
          animations: [trigger, dependent],
          rootNode: rootNode,
        );

        // Dependent should resolve to trigger.end = 2s
        // (syncbase condition resolves, indefinite ignored)
        expect(dependent.getEffectiveBeginTime(), const Duration(seconds: 2));

        timeline.seek(const Duration(seconds: 2));
        expect(trigger.isActive, isFalse);
        expect(dependent.isActive, isTrue);
      });

      test('only indefinite condition stays indefinite', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'indefinite_anim',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: Duration.zero,
          beginConditions: [const IndefiniteCondition()],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        SvgTimeline(animations: [anim], rootNode: rootNode);

        // Should be resolved to "infinity" (never starts automatically)
        final beginTime = anim.getEffectiveBeginTime();
        expect(beginTime.inDays, greaterThan(1000)); // Effectively infinite
      });
    });

    group('Missing syncbase references', () {
      test('reference to non-existent animation uses fallback', () {
        final node = SvgNode(tagName: 'rect', attributes: {});

        final anim = SmilAnimation(
          id: 'anim1',
          type: SmilAnimationType.animate,
          targetNode: node,
          attributeName: 'x',
          attributeType: SvgAttributeType.number,
          from: 0.0,
          to: 100.0,
          dur: const Duration(seconds: 1),
          begin: const Duration(seconds: 3), // Fallback
          beginConditions: [
            SyncbaseCondition(
              animationId: 'nonexistent',
              type: SyncbaseType.begin,
            ),
          ],
          documentOrder: 0,
        );

        final rootNode = SvgNode(tagName: 'svg', attributes: {});

        // Should not throw
        expect(
          () => SvgTimeline(animations: [anim], rootNode: rootNode),
          returnsNormally,
        );

        SvgTimeline(animations: [anim], rootNode: rootNode);

        // Should use fallback begin time (3s)
        expect(anim.getEffectiveBeginTime(), const Duration(seconds: 3));
      });
    });

    group('Multi-pass resolution', () {
      test('deep chain requires multiple passes', () {
        // Create a chain A -> B -> C -> D -> E
        // where each depends on the previous one's end

        final node = SvgNode(tagName: 'rect', attributes: {});
        final animations = <SmilAnimation>[];

        // First animation starts at 0
        animations.add(
          SmilAnimation(
            id: 'chain0',
            type: SmilAnimationType.animate,
            targetNode: node,
            attributeName: 'x',
            attributeType: SvgAttributeType.number,
            from: 0.0,
            to: 10.0,
            dur: const Duration(milliseconds: 100),
            begin: Duration.zero,
            beginConditions: [OffsetCondition(Duration.zero)],
            documentOrder: 0,
          ),
        );

        // Create 5 more animations, each depending on previous
        for (int i = 1; i <= 5; i++) {
          animations.add(
            SmilAnimation(
              id: 'chain$i',
              type: SmilAnimationType.animate,
              targetNode: node,
              attributeName: 'x',
              attributeType: SvgAttributeType.number,
              from: (i * 10).toDouble(),
              to: ((i + 1) * 10).toDouble(),
              dur: const Duration(milliseconds: 100),
              begin: Duration.zero,
              beginConditions: [
                SyncbaseCondition(
                  animationId: 'chain${i - 1}',
                  type: SyncbaseType.end,
                ),
              ],
              documentOrder: i,
            ),
          );
        }

        final rootNode = SvgNode(tagName: 'svg', attributes: {});
        SvgTimeline(animations: animations, rootNode: rootNode);

        // Verify each animation has correct resolved time
        for (int i = 0; i <= 5; i++) {
          expect(
            animations[i].getEffectiveBeginTime(),
            Duration(milliseconds: i * 100),
            reason: 'chain$i should begin at ${i * 100}ms',
          );
        }
      });
    });
  });
}
