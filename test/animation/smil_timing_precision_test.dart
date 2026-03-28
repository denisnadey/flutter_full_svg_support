import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';
import 'package:flutter_svg/src/animation/smil/timing_condition.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('SMIL Timing Precision', () {
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
