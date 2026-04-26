import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_timeline.dart';
import 'package:full_svg_flutter/src/animation/smil/timing_condition.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';

void main() {
  group('Syncbase Timing Integration', () {
    test('simple syncbase - anim2 begins when anim1 begins', () {
      // <animate id="anim1" begin="0s" dur="2s"/>
      // <animate id="anim2" begin="anim1.begin" dur="1s"/>

      final node1 = SvgNode(tagName: 'rect', attributes: {});
      final node2 = SvgNode(tagName: 'circle', attributes: {});

      final anim1 = SmilAnimation(
        id: 'anim1',
        type: SmilAnimationType.animate,
        targetNode: node1,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: Duration.zero,
        beginConditions: [OffsetCondition(Duration.zero)],
      );

      final anim2 = SmilAnimation(
        id: 'anim2',
        type: SmilAnimationType.animate,
        targetNode: node2,
        attributeName: 'cx',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 50.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero, // Will be overridden by syncbase
        beginConditions: [
          SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.begin),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      // Both should start at the same time
      expect(timeline, isNotNull);

      // Check that anim2's begin was resolved to anim1's begin
      // This is internal state, but we can verify behavior by checking
      // when animations become active
      timeline.seek(Duration.zero);
      expect(anim1.isActive, isTrue, reason: 'anim1 should be active at t=0');
      expect(
        anim2.isActive,
        isTrue,
        reason: 'anim2 should be active at t=0 (synced to anim1.begin)',
      );
    });

    test('syncbase with offset - anim2 begins 1s after anim1 begins', () {
      // <animate id="anim1" begin="0s" dur="2s"/>
      // <animate id="anim2" begin="anim1.begin+1s" dur="1s"/>

      final node1 = SvgNode(tagName: 'rect', attributes: {});
      final node2 = SvgNode(tagName: 'circle', attributes: {});

      final anim1 = SmilAnimation(
        id: 'anim1',
        type: SmilAnimationType.animate,
        targetNode: node1,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: Duration.zero,
        beginConditions: [OffsetCondition(Duration.zero)],
      );

      final anim2 = SmilAnimation(
        id: 'anim2',
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
            animationId: 'anim1',
            type: SyncbaseType.begin,
            offset: const Duration(seconds: 1),
          ),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      timeline.seek(Duration.zero);
      expect(anim1.isActive, isTrue);
      expect(anim2.isActive, isFalse, reason: 'anim2 should not be active yet');

      timeline.seek(const Duration(milliseconds: 500));
      expect(anim1.isActive, isTrue);
      expect(anim2.isActive, isFalse);

      timeline.seek(const Duration(seconds: 1));
      expect(anim1.isActive, isTrue);
      expect(anim2.isActive, isTrue, reason: 'anim2 should start at t=1s');
    });

    test('syncbase end - anim2 begins when anim1 ends', () {
      // <animate id="anim1" begin="0s" dur="2s"/>
      // <animate id="anim2" begin="anim1.end" dur="1s"/>

      final node1 = SvgNode(tagName: 'rect', attributes: {});
      final node2 = SvgNode(tagName: 'circle', attributes: {});

      final anim1 = SmilAnimation(
        id: 'anim1',
        type: SmilAnimationType.animate,
        targetNode: node1,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 2),
        begin: Duration.zero,
        beginConditions: [OffsetCondition(Duration.zero)],
      );

      final anim2 = SmilAnimation(
        id: 'anim2',
        type: SmilAnimationType.animate,
        targetNode: node2,
        attributeName: 'cx',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 50.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero,
        beginConditions: [
          SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.end),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      timeline.seek(const Duration(seconds: 1));
      expect(anim1.isActive, isTrue);
      expect(
        anim2.isActive,
        isFalse,
        reason: 'anim2 should not start until anim1 ends',
      );

      timeline.seek(const Duration(seconds: 2));
      expect(anim1.isActive, isFalse, reason: 'anim1 should have ended');
      expect(
        anim2.isActive,
        isTrue,
        reason: 'anim2 should start when anim1 ends',
      );
    });

    test('chained syncbase - anim3 syncs to anim2 which syncs to anim1', () {
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
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2, anim3],
        rootNode: rootNode,
      );

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
    });

    test('syncbase repeat - anim2 begins on anim1 second repeat', () {
      // <animate id="anim1" begin="0s" dur="1s" repeatCount="3"/>
      // <animate id="anim2" begin="anim1.repeat(2)" dur="1s"/>

      final node1 = SvgNode(tagName: 'rect', attributes: {});
      final node2 = SvgNode(tagName: 'circle', attributes: {});

      final anim1 = SmilAnimation(
        id: 'anim1',
        type: SmilAnimationType.animate,
        targetNode: node1,
        attributeName: 'x',
        attributeType: SvgAttributeType.number,
        from: 0.0,
        to: 100.0,
        dur: const Duration(seconds: 1),
        begin: Duration.zero,
        repeatCount: 3.0,
        beginConditions: [OffsetCondition(Duration.zero)],
      );

      final anim2 = SmilAnimation(
        id: 'anim2',
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
            animationId: 'anim1',
            type: SyncbaseType.repeat,
            repeatIndex: 2,
          ),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});
      final timeline = SvgTimeline(
        animations: [anim1, anim2],
        rootNode: rootNode,
      );

      timeline.seek(const Duration(seconds: 1));
      expect(anim1.isActive, isTrue);
      expect(
        anim2.isActive,
        isFalse,
        reason: 'anim2 should not start until repeat 2',
      );

      // At t=2s, anim1 is on its 3rd iteration (repeat index 2)
      timeline.seek(const Duration(seconds: 2));
      expect(anim1.isActive, isTrue);
      expect(anim2.isActive, isTrue, reason: 'anim2 should start at repeat 2');
    });

    test('missing syncbase reference - gracefully handled', () {
      // <animate id="anim1" begin="nonexistent.begin" dur="1s"/>

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
        begin: const Duration(seconds: 5), // Fallback
        beginConditions: [
          SyncbaseCondition(
            animationId: 'nonexistent',
            type: SyncbaseType.begin,
          ),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});

      // Should not throw, should use fallback begin time
      expect(
        () => SvgTimeline(animations: [anim1], rootNode: rootNode),
        returnsNormally,
      );
    });

    test('circular dependency - handled gracefully', () {
      // <animate id="anim1" begin="anim2.begin" dur="1s"/>
      // <animate id="anim2" begin="anim1.begin" dur="1s"/>

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
          SyncbaseCondition(animationId: 'anim2', type: SyncbaseType.begin),
        ],
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
          SyncbaseCondition(animationId: 'anim1', type: SyncbaseType.begin),
        ],
      );

      final rootNode = SvgNode(tagName: 'svg', attributes: {});

      // Should handle circular dependency without hanging
      expect(
        () => SvgTimeline(animations: [anim1, anim2], rootNode: rootNode),
        returnsNormally,
      );
    });
  });
}
